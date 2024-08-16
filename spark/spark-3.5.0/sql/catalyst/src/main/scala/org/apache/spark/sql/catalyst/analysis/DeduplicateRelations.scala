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

import scala.collection.mutable

import org.apache.spark.sql.catalyst.expressions.{Alias, AttributeMap, AttributeSet, NamedExpression, OuterReference, SubqueryExpression}
import org.apache.spark.sql.catalyst.plans.logical._
import org.apache.spark.sql.catalyst.rules.Rule
import org.apache.spark.sql.catalyst.trees.TreePattern._

/**
 * A helper class used to detect duplicate relations fast in `DeduplicateRelations`. Two relations
 * are duplicated if:
 *  1. they are the same class.
 *  2. they have the same output attribute IDs.
 *
 * The first condition is necessary because the CTE relation definition node and reference node have
 * the same output attribute IDs but they are not duplicated.
 */
case class RelationWrapper(cls: Class[_], outputAttrIds: Seq[Long])

object DeduplicateRelations extends Rule[LogicalPlan] {
  override def apply(plan: LogicalPlan): LogicalPlan = {
    val newPlan = renewDuplicatedRelations(mutable.HashSet.empty, plan)._1
    if (newPlan.find(p => p.resolved && p.missingInput.nonEmpty).isDefined) {
      // Wait for `ResolveMissingReferences` to resolve missing attributes first
      return newPlan
    }
    newPlan.resolveOperatorsUpWithPruning(
      _.containsAnyPattern(JOIN, LATERAL_JOIN, AS_OF_JOIN, INTERSECT, EXCEPT, UNION, COMMAND),
      ruleId) {
      case p: LogicalPlan if !p.childrenResolved => p
      // To resolve duplicate expression IDs for Join.
      case j @ Join(left, right, _, _, _) if !j.duplicateResolved =>
        j.copy(right = dedupRight(left, right))
      // Resolve duplicate output for LateralJoin.
      case j @ LateralJoin(left, right, _, _) if right.resolved && !j.duplicateResolved =>
        j.copy(right = right.withNewPlan(dedupRight(left, right.plan)))
      // Resolve duplicate output for AsOfJoin.
      case j @ AsOfJoin(left, right, _, _, _, _, _) if !j.duplicateResolved =>
        j.copy(right = dedupRight(left, right))
      // intersect/except will be rewritten to join at the beginning of optimizer. Here we need to
      // deduplicate the right side plan, so that we won't produce an invalid self-join later.
      case i @ Intersect(left, right, _) if !i.duplicateResolved =>
        i.copy(right = dedupRight(left, right))
      case e @ Except(left, right, _) if !e.duplicateResolved =>
        e.copy(right = dedupRight(left, right))
      // Only after we finish by-name resolution for Union
      case u: Union if !u.byName && !u.duplicateResolved =>
        // Use projection-based de-duplication for Union to avoid breaking the checkpoint sharing
        // feature in streaming.
        val newChildren = u.children.foldRight(Seq.empty[LogicalPlan]) { (head, tail) =>
          head +: tail.map {
            case child if head.outputSet.intersect(child.outputSet).isEmpty =>
              child
            case child =>
              val projectList = child.output.map { attr =>
                Alias(attr, attr.name)()
              }
              Project(projectList, child)
          }
        }
        u.copy(children = newChildren)
      case merge: MergeIntoTable if !merge.duplicateResolved =>
        merge.copy(sourceTable = dedupRight(merge.targetTable, merge.sourceTable))
    }
  }

  /**
   * Deduplicate any duplicated relations of a LogicalPlan
   * @param existingRelations the known unique relations for a LogicalPlan
   * @param plan the LogicalPlan that requires the deduplication
   * @return (the new LogicalPlan which already deduplicate all duplicated relations (if any),
   *          whether the plan is changed or not)
   */
  private def renewDuplicatedRelations(
      existingRelations: mutable.HashSet[RelationWrapper],
      plan: LogicalPlan): (LogicalPlan, Boolean) = plan match {
    case p: LogicalPlan if p.isStreaming => (plan, false)

    case m: MultiInstanceRelation =>
      val planWrapper = RelationWrapper(m.getClass, m.output.map(_.exprId.id))
      if (existingRelations.contains(planWrapper)) {
        val newNode = m.newInstance()
        newNode.copyTagsFrom(m)
        (newNode, true)
      } else {
        existingRelations.add(planWrapper)
        (m, false)
      }

    case plan: LogicalPlan =>
      var planChanged = false
      val newPlan = if (plan.children.nonEmpty) {
        val newChildren = mutable.ArrayBuffer.empty[LogicalPlan]
        for (c <- plan.children) {
          val (renewed, changed) = renewDuplicatedRelations(existingRelations, c)
          newChildren += renewed
          if (changed) {
            planChanged = true
          }
        }

        val planWithNewSubquery = plan.transformExpressions {
          case subquery: SubqueryExpression =>
            val (renewed, changed) = renewDuplicatedRelations(existingRelations, subquery.plan)
            if (changed) planChanged = true
            subquery.withNewPlan(renewed)
        }

        if (planChanged) {
          if (planWithNewSubquery.childrenResolved) {
            val planWithNewChildren = planWithNewSubquery.withNewChildren(newChildren.toSeq)
            val attrMap = AttributeMap(
              plan
                .children
                .flatMap(_.output).zip(newChildren.flatMap(_.output))
                .filter { case (a1, a2) => a1.exprId != a2.exprId }
            )
            if (attrMap.isEmpty) {
              planWithNewChildren
            } else {
              planWithNewChildren.rewriteAttrs(attrMap)
            }
          } else {
            planWithNewSubquery.withNewChildren(newChildren.toSeq)
          }
        } else {
          plan
        }
      } else {
        plan
      }
      (newPlan, planChanged)
  }

  /**
   * Generate a new logical plan for the right child with different expression IDs
   * for all conflicting attributes.
   */
  private def dedupRight(left: LogicalPlan, right: LogicalPlan): LogicalPlan = {
    val conflictingAttributes = left.outputSet.intersect(right.outputSet)
    logDebug(s"Conflicting attributes ${conflictingAttributes.mkString(",")} " +
      s"between $left and $right")

    /**
     * For LogicalPlan likes MultiInstanceRelation, Project, Aggregate, etc, whose output doesn't
     * inherit directly from its children, we could just stop collect on it. Because we could
     * always replace all the lower conflict attributes with the new attributes from the new
     * plan. Theoretically, we should do recursively collect for Generate and Window but we leave
     * it to the next batch to reduce possible overhead because this should be a corner case.
     */
    def collectConflictPlans(plan: LogicalPlan): Seq[(LogicalPlan, LogicalPlan)] = plan match {
      // Handle base relations that might appear more than once.
      case oldVersion: MultiInstanceRelation
          if oldVersion.outputSet.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.newInstance()
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion: SerializeFromObject
          if oldVersion.outputSet.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(serializer = oldVersion.serializer.map(_.newInstance()))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      // Handle projects that create conflicting aliases.
      case oldVersion @ Project(projectList, _)
          if findAliases(projectList).intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(projectList = newAliases(projectList))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      // Handle projects that create conflicting outer references.
      case oldVersion @ Project(projectList, _)
          if findOuterReferences(projectList).intersect(conflictingAttributes).nonEmpty =>
        // Add alias to conflicting outer references.
        val aliasedProjectList = projectList.map {
          case o @ OuterReference(a) if conflictingAttributes.contains(a) => Alias(o, a.name)()
          case other => other
        }
        val newVersion = oldVersion.copy(projectList = aliasedProjectList)
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      // We don't need to search child plan recursively if the projectList of a Project
      // is only composed of Alias and doesn't contain any conflicting attributes.
      // Because, even if the child plan has some conflicting attributes, the attributes
      // will be aliased to non-conflicting attributes by the Project at the end.
      case _ @ Project(projectList, _)
        if findAliases(projectList).size == projectList.size =>
        Nil

      case oldVersion @ Aggregate(_, aggregateExpressions, _)
          if findAliases(aggregateExpressions).intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(aggregateExpressions = newAliases(aggregateExpressions))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      // We don't search the child plan recursively for the same reason as the above Project.
      case _ @ Aggregate(_, aggregateExpressions, _)
        if findAliases(aggregateExpressions).size == aggregateExpressions.size =>
        Nil

      case oldVersion @ FlatMapGroupsInPandas(_, _, output, _)
          if oldVersion.outputSet.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(output = output.map(_.newInstance()))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion @ FlatMapCoGroupsInPandas(_, _, _, output, _, _)
        if oldVersion.outputSet.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(output = output.map(_.newInstance()))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion @ MapInPandas(_, output, _, _)
        if oldVersion.outputSet.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(output = output.map(_.newInstance()))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion @ PythonMapInArrow(_, output, _, _)
        if oldVersion.outputSet.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(output = output.map(_.newInstance()))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion @ AttachDistributedSequence(sequenceAttr, _)
        if oldVersion.producedAttributes.intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(sequenceAttr = sequenceAttr.newInstance())
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion: Generate
          if oldVersion.producedAttributes.intersect(conflictingAttributes).nonEmpty =>
        val newOutput = oldVersion.generatorOutput.map(_.newInstance())
        val newVersion = oldVersion.copy(generatorOutput = newOutput)
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion: Expand
          if oldVersion.producedAttributes.intersect(conflictingAttributes).nonEmpty =>
        val producedAttributes = oldVersion.producedAttributes
        val newOutput = oldVersion.output.map { attr =>
          if (producedAttributes.contains(attr)) {
            attr.newInstance()
          } else {
            attr
          }
        }
        val newVersion = oldVersion.copy(output = newOutput)
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion @ Window(windowExpressions, _, _, child)
          if AttributeSet(windowExpressions.map(_.toAttribute)).intersect(conflictingAttributes)
          .nonEmpty =>
        val newVersion = oldVersion.copy(windowExpressions = newAliases(windowExpressions))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case oldVersion @ ScriptTransformation(_, output, _, _)
          if AttributeSet(output).intersect(conflictingAttributes).nonEmpty =>
        val newVersion = oldVersion.copy(output = output.map(_.newInstance()))
        newVersion.copyTagsFrom(oldVersion)
        Seq((oldVersion, newVersion))

      case _ => plan.children.flatMap(collectConflictPlans)
    }

    val conflictPlans = collectConflictPlans(right)

    /*
     * Note that it's possible `conflictPlans` can be empty which implies that there
     * is a logical plan node that produces new references that this rule cannot handle.
     * When that is the case, there must be another rule that resolves these conflicts.
     * Otherwise, the analysis will fail.
     */
    if (conflictPlans.isEmpty) {
      right
    } else {
      val planMapping = conflictPlans.toMap
      right.transformUpWithNewOutput {
        case oldPlan =>
          val newPlanOpt = planMapping.get(oldPlan)
          newPlanOpt.map { newPlan =>
            newPlan -> oldPlan.output.zip(newPlan.output)
          }.getOrElse(oldPlan -> Nil)
      }
    }
  }

  private def newAliases(expressions: Seq[NamedExpression]): Seq[NamedExpression] = {
    // SPARK-43030: It's important to avoid creating new aliases for duplicate aliases
    // in the original project list, to avoid assertion failures when rewriting attributes
    // in transformUpWithNewOutput.
    val oldAliasToNewAlias = AttributeMap(expressions.collect {
      case a: Alias => (a.toAttribute, a.newInstance())
    })
    expressions.map {
      case a: Alias => oldAliasToNewAlias(a.toAttribute)
      case other => other
    }
  }

  private def findAliases(projectList: Seq[NamedExpression]): AttributeSet = {
    AttributeSet(projectList.collect { case a: Alias => a.toAttribute })
  }

  private def findOuterReferences(projectList: Seq[NamedExpression]): AttributeSet = {
    AttributeSet(projectList.collect { case o: OuterReference => o.toAttribute })
  }
}
