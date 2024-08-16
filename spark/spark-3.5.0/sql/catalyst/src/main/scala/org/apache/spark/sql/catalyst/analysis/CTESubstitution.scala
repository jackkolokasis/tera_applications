/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.sql.catalyst.analysis

import scala.collection.mutable.ArrayBuffer

import org.apache.spark.sql.catalyst.expressions.SubqueryExpression
import org.apache.spark.sql.catalyst.plans.logical.{Command, CTERelationDef, CTERelationRef, InsertIntoDir, LogicalPlan, ParsedStatement, SubqueryAlias, UnresolvedWith, WithCTE}
import org.apache.spark.sql.catalyst.rules.Rule
import org.apache.spark.sql.catalyst.trees.TreePattern._
import org.apache.spark.sql.catalyst.util.TypeUtils._
import org.apache.spark.sql.errors.QueryCompilationErrors
import org.apache.spark.sql.internal.LegacyBehaviorPolicy
import org.apache.spark.sql.internal.SQLConf.LEGACY_CTE_PRECEDENCE_POLICY

/**
 * Analyze WITH nodes and substitute child plan with CTE references or CTE definitions depending
 * on the conditions below:
 * 1. If in legacy mode, or if the query is a SQL command or DML statement, replace with CTE
 *    definitions, i.e., inline CTEs.
 * 2. Otherwise, replace with CTE references `CTERelationRef`s. The decision to inline or not
 *    inline will be made later by the rule `InlineCTE` after query analysis.
 *
 * All the CTE definitions that are not inlined after this substitution will be grouped together
 * under one `WithCTE` node for each of the main query and the subqueries. Any of the main query
 * or the subqueries that do not contain CTEs or have had all CTEs inlined will obviously not have
 * any `WithCTE` nodes. If any though, the `WithCTE` node will be in the same place as where the
 * outermost `With` node once was.
 *
 * The CTE definitions in a `WithCTE` node are kept in the order of how they have been resolved.
 * That means the CTE definitions are guaranteed to be in topological order base on their
 * dependency for any valid CTE query (i.e., given CTE definitions A and B with B referencing A,
 * A is guaranteed to appear before B). Otherwise, it must be an invalid user query, and an
 * analysis exception will be thrown later by relation resolving rules.
 */
object CTESubstitution extends Rule[LogicalPlan] {
  def apply(plan: LogicalPlan): LogicalPlan = {
    if (!plan.containsPattern(UNRESOLVED_WITH)) {
      return plan
    }
    val isCommand = plan.exists {
      case _: Command | _: ParsedStatement | _: InsertIntoDir => true
      case _ => false
    }
    val cteDefs = ArrayBuffer.empty[CTERelationDef]
    val (substituted, firstSubstituted) =
      LegacyBehaviorPolicy.withName(conf.getConf(LEGACY_CTE_PRECEDENCE_POLICY)) match {
        case LegacyBehaviorPolicy.EXCEPTION =>
          assertNoNameConflictsInCTE(plan)
          traverseAndSubstituteCTE(plan, isCommand, Seq.empty, cteDefs)
        case LegacyBehaviorPolicy.LEGACY =>
          (legacyTraverseAndSubstituteCTE(plan, cteDefs), None)
        case LegacyBehaviorPolicy.CORRECTED =>
          traverseAndSubstituteCTE(plan, isCommand, Seq.empty, cteDefs)
    }
    if (cteDefs.isEmpty) {
      substituted
    } else if (substituted eq firstSubstituted.get) {
      WithCTE(substituted, cteDefs.toSeq)
    } else {
      var done = false
      substituted.resolveOperatorsWithPruning(_ => !done) {
        case p if p eq firstSubstituted.get =>
          // `firstSubstituted` is the parent of all other CTEs (if any).
          done = true
          WithCTE(p, cteDefs.toSeq)
        case p if p.children.count(_.containsPattern(CTE)) > 1 =>
          // This is the first common parent of all CTEs.
          done = true
          WithCTE(p, cteDefs.toSeq)
      }
    }
  }

  /**
   * Spark 3.0 changes the CTE relations resolution, and inner relations take precedence. This is
   * correct but we need to warn users about this behavior change under EXCEPTION mode, when we see
   * CTE relations with conflicting names.
   *
   * Note that, before Spark 3.0 the parser didn't support CTE in the FROM clause. For example,
   * `WITH ... SELECT * FROM (WITH ... SELECT ...)` was not supported. We should not fail for this
   * case, as Spark versions before 3.0 can't run it anyway. The parameter `startOfQuery` is used
   * to indicate where we can define CTE relations before Spark 3.0, and we should only check
   * name conflicts when `startOfQuery` is true.
   */
  private def assertNoNameConflictsInCTE(
      plan: LogicalPlan,
      outerCTERelationNames: Seq[String] = Nil,
      startOfQuery: Boolean = true): Unit = {
    val resolver = conf.resolver
    plan match {
      case UnresolvedWith(child, relations) =>
        val newNames = ArrayBuffer.empty[String]
        newNames ++= outerCTERelationNames
        relations.foreach {
          case (name, relation) =>
            if (startOfQuery && outerCTERelationNames.exists(resolver(_, name))) {
              throw QueryCompilationErrors.ambiguousRelationAliasNameInNestedCTEError(name)
            }
            // CTE relation is defined as `SubqueryAlias`. Here we skip it and check the child
            // directly, so that `startOfQuery` is set correctly.
            assertNoNameConflictsInCTE(relation.child, newNames.toSeq)
            newNames += name
        }
        assertNoNameConflictsInCTE(child, newNames.toSeq, startOfQuery = false)

      case other =>
        other.subqueries.foreach(assertNoNameConflictsInCTE(_, outerCTERelationNames))
        other.children.foreach(
          assertNoNameConflictsInCTE(_, outerCTERelationNames, startOfQuery = false))
    }
  }

  private def legacyTraverseAndSubstituteCTE(
      plan: LogicalPlan,
      cteDefs: ArrayBuffer[CTERelationDef]): LogicalPlan = {
    plan.resolveOperatorsUp {
      case UnresolvedWith(child, relations) =>
        val resolvedCTERelations =
          resolveCTERelations(relations, isLegacy = true, isCommand = false, Seq.empty, cteDefs)
        substituteCTE(child, alwaysInline = true, resolvedCTERelations)
    }
  }

  /**
   * Traverse the plan and expression nodes as a tree and replace matching references with CTE
   * references if `isCommand` is false, otherwise with the query plans of the corresponding
   * CTE definitions.
   * - If the rule encounters a WITH node then it substitutes the child of the node with CTE
   *   definitions of the node right-to-left order as a definition can reference to a previous
   *   one.
   *   For example the following query is valid:
   *   WITH
   *     t AS (SELECT 1),
   *     t2 AS (SELECT * FROM t)
   *   SELECT * FROM t2
   * - If a CTE definition contains an inner WITH node then substitution of inner should take
   *   precedence because it can shadow an outer CTE definition.
   *   For example the following query should return 2:
   *   WITH
   *     t AS (SELECT 1),
   *     t2 AS (
   *       WITH t AS (SELECT 2)
   *       SELECT * FROM t
   *     )
   *   SELECT * FROM t2
   * - If a CTE definition contains a subquery expression that contains an inner WITH node then
   *   substitution of inner should take precedence because it can shadow an outer CTE
   *   definition.
   *   For example the following query should return 2:
   *   WITH t AS (SELECT 1)
   *   SELECT (
   *     WITH t AS (SELECT 2)
   *     SELECT * FROM t
   *   )
   * @param plan the plan to be traversed
   * @param isCommand if this is a command
   * @param outerCTEDefs already resolved outer CTE definitions with names
   * @param cteDefs all accumulated CTE definitions
   * @return the plan where CTE substitution is applied and optionally the last substituted `With`
   *         where CTE definitions will be gathered to
   */
  private def traverseAndSubstituteCTE(
      plan: LogicalPlan,
      isCommand: Boolean,
      outerCTEDefs: Seq[(String, CTERelationDef)],
      cteDefs: ArrayBuffer[CTERelationDef]): (LogicalPlan, Option[LogicalPlan]) = {
    var firstSubstituted: Option[LogicalPlan] = None
    val newPlan = plan.resolveOperatorsDownWithPruning(
        _.containsAnyPattern(UNRESOLVED_WITH, PLAN_EXPRESSION)) {
      case UnresolvedWith(child: LogicalPlan, relations) =>
        val resolvedCTERelations =
          resolveCTERelations(relations, isLegacy = false, isCommand, outerCTEDefs, cteDefs) ++
            outerCTEDefs
        val substituted = substituteCTE(
          traverseAndSubstituteCTE(child, isCommand, resolvedCTERelations, cteDefs)._1,
          isCommand,
          resolvedCTERelations)
        if (firstSubstituted.isEmpty) {
          firstSubstituted = Some(substituted)
        }
        substituted

      case other =>
        other.transformExpressionsWithPruning(_.containsPattern(PLAN_EXPRESSION)) {
          case e: SubqueryExpression => e.withNewPlan(apply(e.plan))
        }
    }
    (newPlan, firstSubstituted)
  }

  private def resolveCTERelations(
      relations: Seq[(String, SubqueryAlias)],
      isLegacy: Boolean,
      isCommand: Boolean,
      outerCTEDefs: Seq[(String, CTERelationDef)],
      cteDefs: ArrayBuffer[CTERelationDef]): Seq[(String, CTERelationDef)] = {
    var resolvedCTERelations = if (isLegacy || isCommand) {
      Seq.empty
    } else {
      outerCTEDefs
    }
    for ((name, relation) <- relations) {
      val innerCTEResolved = if (isLegacy) {
        // In legacy mode, outer CTE relations take precedence. Here we don't resolve the inner
        // `With` nodes, later we will substitute `UnresolvedRelation`s with outer CTE relations.
        // Analyzer will run this rule multiple times until all `With` nodes are resolved.
        relation
      } else {
        // A CTE definition might contain an inner CTE that has a higher priority, so traverse and
        // substitute CTE defined in `relation` first.
        // NOTE: we must call `traverseAndSubstituteCTE` before `substituteCTE`, as the relations
        // in the inner CTE have higher priority over the relations in the outer CTE when resolving
        // inner CTE relations. For example:
        // WITH t1 AS (SELECT 1)
        // t2 AS (
        //   WITH t1 AS (SELECT 2)
        //   WITH t3 AS (SELECT * FROM t1)
        // )
        // t3 should resolve the t1 to `SELECT 2` instead of `SELECT 1`.
        traverseAndSubstituteCTE(relation, isCommand, resolvedCTERelations, cteDefs)._1
      }
      // CTE definition can reference a previous one
      val substituted = substituteCTE(innerCTEResolved, isLegacy || isCommand, resolvedCTERelations)
      val cteRelation = CTERelationDef(substituted)
      if (!(isLegacy || isCommand)) {
        cteDefs += cteRelation
      }
      // Prepending new CTEs makes sure that those have higher priority over outer ones.
      resolvedCTERelations +:= (name -> cteRelation)
    }
    resolvedCTERelations
  }

  private def substituteCTE(
      plan: LogicalPlan,
      alwaysInline: Boolean,
      cteRelations: Seq[(String, CTERelationDef)]): LogicalPlan =
    plan.resolveOperatorsUpWithPruning(
        _.containsAnyPattern(RELATION_TIME_TRAVEL, UNRESOLVED_RELATION, PLAN_EXPRESSION)) {
      case RelationTimeTravel(UnresolvedRelation(Seq(table), _, _), _, _)
        if cteRelations.exists(r => plan.conf.resolver(r._1, table)) =>
        throw QueryCompilationErrors.timeTravelUnsupportedError(toSQLId(table))

      case u @ UnresolvedRelation(Seq(table), _, _) =>
        cteRelations.find(r => plan.conf.resolver(r._1, table)).map { case (_, d) =>
          if (alwaysInline) {
            d.child
          } else {
            // Add a `SubqueryAlias` for hint-resolving rules to match relation names.
            SubqueryAlias(table, CTERelationRef(d.id, d.resolved, d.output))
          }
        }.getOrElse(u)

      case other =>
        // This cannot be done in ResolveSubquery because ResolveSubquery does not know the CTE.
        other.transformExpressionsWithPruning(_.containsPattern(PLAN_EXPRESSION)) {
          case e: SubqueryExpression =>
            e.withNewPlan(apply(substituteCTE(e.plan, alwaysInline, cteRelations)))
        }
    }
}
