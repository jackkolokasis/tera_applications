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

package org.apache.spark.sql.catalyst.optimizer

import scala.annotation.tailrec

import org.apache.spark.sql.catalyst.expressions._
import org.apache.spark.sql.catalyst.expressions.aggregate.BloomFilterAggregate
import org.apache.spark.sql.catalyst.planning.ExtractEquiJoinKeys
import org.apache.spark.sql.catalyst.plans.logical._
import org.apache.spark.sql.catalyst.rules.Rule
import org.apache.spark.sql.catalyst.trees.TreePattern.{INVOKE, JSON_TO_STRUCT, LIKE_FAMLIY, PYTHON_UDF, REGEXP_EXTRACT_FAMILY, REGEXP_REPLACE, SCALA_UDF}
import org.apache.spark.sql.internal.SQLConf
import org.apache.spark.sql.types._

/**
 * Insert a filter on one side of the join if the other side has a selective predicate.
 * The filter could be an IN subquery (converted to a semi join), a bloom filter, or something
 * else in the future.
 */
object InjectRuntimeFilter extends Rule[LogicalPlan] with PredicateHelper with JoinSelectionHelper {

  // Wraps `expr` with a hash function if its byte size is larger than an integer.
  private def mayWrapWithHash(expr: Expression): Expression = {
    if (expr.dataType.defaultSize > IntegerType.defaultSize) {
      new Murmur3Hash(Seq(expr))
    } else {
      expr
    }
  }

  private def injectFilter(
      filterApplicationSideExp: Expression,
      filterApplicationSidePlan: LogicalPlan,
      filterCreationSideExp: Expression,
      filterCreationSidePlan: LogicalPlan): LogicalPlan = {
    require(conf.runtimeFilterBloomFilterEnabled || conf.runtimeFilterSemiJoinReductionEnabled)
    if (conf.runtimeFilterBloomFilterEnabled) {
      injectBloomFilter(
        filterApplicationSideExp,
        filterApplicationSidePlan,
        filterCreationSideExp,
        filterCreationSidePlan
      )
    } else {
      injectInSubqueryFilter(
        filterApplicationSideExp,
        filterApplicationSidePlan,
        filterCreationSideExp,
        filterCreationSidePlan
      )
    }
  }

  private def injectBloomFilter(
      filterApplicationSideExp: Expression,
      filterApplicationSidePlan: LogicalPlan,
      filterCreationSideExp: Expression,
      filterCreationSidePlan: LogicalPlan): LogicalPlan = {
    // Skip if the filter creation side is too big
    if (filterCreationSidePlan.stats.sizeInBytes > conf.runtimeFilterCreationSideThreshold) {
      return filterApplicationSidePlan
    }
    val rowCount = filterCreationSidePlan.stats.rowCount
    val bloomFilterAgg =
      if (rowCount.isDefined && rowCount.get.longValue > 0L) {
        new BloomFilterAggregate(new XxHash64(Seq(filterCreationSideExp)), rowCount.get.longValue)
      } else {
        new BloomFilterAggregate(new XxHash64(Seq(filterCreationSideExp)))
      }

    val alias = Alias(bloomFilterAgg.toAggregateExpression(), "bloomFilter")()
    val aggregate =
      ConstantFolding(ColumnPruning(Aggregate(Nil, Seq(alias), filterCreationSidePlan)))
    val bloomFilterSubquery = ScalarSubquery(aggregate, Nil)
    val filter = BloomFilterMightContain(bloomFilterSubquery,
      new XxHash64(Seq(filterApplicationSideExp)))
    Filter(filter, filterApplicationSidePlan)
  }

  private def injectInSubqueryFilter(
      filterApplicationSideExp: Expression,
      filterApplicationSidePlan: LogicalPlan,
      filterCreationSideExp: Expression,
      filterCreationSidePlan: LogicalPlan): LogicalPlan = {
    require(filterApplicationSideExp.dataType == filterCreationSideExp.dataType)
    val actualFilterKeyExpr = mayWrapWithHash(filterCreationSideExp)
    val alias = Alias(actualFilterKeyExpr, actualFilterKeyExpr.toString)()
    val aggregate =
      ColumnPruning(Aggregate(Seq(filterCreationSideExp), Seq(alias), filterCreationSidePlan))
    if (!canBroadcastBySize(aggregate, conf)) {
      // Skip the InSubquery filter if the size of `aggregate` is beyond broadcast join threshold,
      // i.e., the semi-join will be a shuffled join, which is not worthwhile.
      return filterApplicationSidePlan
    }
    val filter = InSubquery(Seq(mayWrapWithHash(filterApplicationSideExp)),
      ListQuery(aggregate, numCols = aggregate.output.length))
    Filter(filter, filterApplicationSidePlan)
  }

  /**
   * Extracts a sub-plan which is a simple filter over scan from the input plan. The simple
   * filter should be selective and the filter condition (including expressions in the child
   * plan referenced by the filter condition) should be a simple expression, so that we do
   * not add a subquery that might have an expensive computation.
   */
  private def extractSelectiveFilterOverScan(
      plan: LogicalPlan,
      filterCreationSideExp: Expression): Option[LogicalPlan] = {
    @tailrec
    def extract(
        p: LogicalPlan,
        predicateReference: AttributeSet,
        hasHitFilter: Boolean,
        hasHitSelectiveFilter: Boolean,
        currentPlan: LogicalPlan): Option[LogicalPlan] = p match {
      case Project(projectList, child) if hasHitFilter =>
        // We need to make sure all expressions referenced by filter predicates are simple
        // expressions.
        val referencedExprs = projectList.filter(predicateReference.contains)
        if (referencedExprs.forall(isSimpleExpression)) {
          extract(
            child,
            referencedExprs.map(_.references).foldLeft(AttributeSet.empty)(_ ++ _),
            hasHitFilter,
            hasHitSelectiveFilter,
            currentPlan)
        } else {
          None
        }
      case Project(_, child) =>
        assert(predicateReference.isEmpty && !hasHitSelectiveFilter)
        extract(child, predicateReference, hasHitFilter, hasHitSelectiveFilter, currentPlan)
      case Filter(condition, child) if isSimpleExpression(condition) =>
        extract(
          child,
          predicateReference ++ condition.references,
          hasHitFilter = true,
          hasHitSelectiveFilter = hasHitSelectiveFilter || isLikelySelective(condition),
          currentPlan)
      case ExtractEquiJoinKeys(_, _, _, _, _, left, right, _) =>
        // Runtime filters use one side of the [[Join]] to build a set of join key values and prune
        // the other side of the [[Join]]. It's also OK to use a superset of the join key values
        // (ignore null values) to do the pruning.
        if (left.output.exists(_.semanticEquals(filterCreationSideExp))) {
          extract(left, AttributeSet.empty,
            hasHitFilter = false, hasHitSelectiveFilter = false, currentPlan = left)
        } else if (right.output.exists(_.semanticEquals(filterCreationSideExp))) {
          extract(right, AttributeSet.empty,
            hasHitFilter = false, hasHitSelectiveFilter = false, currentPlan = right)
        } else {
          None
        }
      case _: LeafNode if hasHitSelectiveFilter =>
        Some(currentPlan)
      case _ => None
    }

    if (!plan.isStreaming) {
      extract(plan, AttributeSet.empty,
        hasHitFilter = false, hasHitSelectiveFilter = false, currentPlan = plan)
    } else {
      None
    }
  }

  private def isSimpleExpression(e: Expression): Boolean = {
    !e.containsAnyPattern(PYTHON_UDF, SCALA_UDF, INVOKE, JSON_TO_STRUCT, LIKE_FAMLIY,
      REGEXP_EXTRACT_FAMILY, REGEXP_REPLACE)
  }

  private def isProbablyShuffleJoin(left: LogicalPlan,
      right: LogicalPlan, hint: JoinHint): Boolean = {
    !hintToBroadcastLeft(hint) && !hintToBroadcastRight(hint) &&
      !canBroadcastBySize(left, conf) && !canBroadcastBySize(right, conf)
  }

  private def probablyHasShuffle(plan: LogicalPlan): Boolean = {
    plan.exists {
      case Join(left, right, _, _, hint) => isProbablyShuffleJoin(left, right, hint)
      case _: Aggregate => true
      case _: Window => true
      case _ => false
    }
  }

  // Returns the max scan byte size in the subtree rooted at `filterApplicationSide`.
  private def maxScanByteSize(filterApplicationSide: LogicalPlan): BigInt = {
    val defaultSizeInBytes = conf.getConf(SQLConf.DEFAULT_SIZE_IN_BYTES)
    filterApplicationSide.collect({
      case leaf: LeafNode => leaf
    }).map(scan => {
      // DEFAULT_SIZE_IN_BYTES means there's no byte size information in stats. Since we avoid
      // creating a Bloom filter when the filter application side is very small, so using 0
      // as the byte size when the actual size is unknown can avoid regression by applying BF
      // on a small table.
      if (scan.stats.sizeInBytes == defaultSizeInBytes) BigInt(0) else scan.stats.sizeInBytes
    }).max
  }

  // Returns true if `filterApplicationSide` satisfies the byte size requirement to apply a
  // Bloom filter; false otherwise.
  private def satisfyByteSizeRequirement(filterApplicationSide: LogicalPlan): Boolean = {
    // In case `filterApplicationSide` is a union of many small tables, disseminating the Bloom
    // filter to each small task might be more costly than scanning them itself. Thus, we use max
    // rather than sum here.
    val maxScanSize = maxScanByteSize(filterApplicationSide)
    maxScanSize >=
      conf.getConf(SQLConf.RUNTIME_BLOOM_FILTER_APPLICATION_SIDE_SCAN_SIZE_THRESHOLD)
  }

  /**
   * Extracts the beneficial filter creation plan with check show below:
   * - The filterApplicationSideJoinExp can be pushed down through joins, aggregates and windows
   *   (ie the expression references originate from a single leaf node)
   * - The filter creation side has a selective predicate
   * - The current join is a shuffle join or a broadcast join that has a shuffle below it
   * - The max filterApplicationSide scan size is greater than a configurable threshold
   */
  private def extractBeneficialFilterCreatePlan(
      filterApplicationSide: LogicalPlan,
      filterCreationSide: LogicalPlan,
      filterApplicationSideExp: Expression,
      filterCreationSideExp: Expression,
      hint: JoinHint): Option[LogicalPlan] = {
    if (findExpressionAndTrackLineageDown(
      filterApplicationSideExp, filterApplicationSide).isDefined &&
      (isProbablyShuffleJoin(filterApplicationSide, filterCreationSide, hint) ||
        probablyHasShuffle(filterApplicationSide)) &&
      satisfyByteSizeRequirement(filterApplicationSide)) {
      extractSelectiveFilterOverScan(filterCreationSide, filterCreationSideExp)
    } else {
      None
    }
  }

  def hasRuntimeFilter(left: LogicalPlan, right: LogicalPlan, leftKey: Expression,
      rightKey: Expression): Boolean = {
    if (conf.runtimeFilterBloomFilterEnabled) {
      hasBloomFilter(left, right, leftKey, rightKey)
    } else {
      hasInSubquery(left, right, leftKey, rightKey)
    }
  }

  // This checks if there is already a DPP filter, as this rule is called just after DPP.
  @tailrec
  def hasDynamicPruningSubquery(
      left: LogicalPlan,
      right: LogicalPlan,
      leftKey: Expression,
      rightKey: Expression): Boolean = {
    (left, right) match {
      case (Filter(DynamicPruningSubquery(pruningKey, _, _, _, _, _, _), plan), _) =>
        pruningKey.fastEquals(leftKey) || hasDynamicPruningSubquery(plan, right, leftKey, rightKey)
      case (_, Filter(DynamicPruningSubquery(pruningKey, _, _, _, _, _, _), plan)) =>
        pruningKey.fastEquals(rightKey) ||
          hasDynamicPruningSubquery(left, plan, leftKey, rightKey)
      case _ => false
    }
  }

  def hasBloomFilter(
      left: LogicalPlan,
      right: LogicalPlan,
      leftKey: Expression,
      rightKey: Expression): Boolean = {
    findBloomFilterWithExp(left, leftKey) || findBloomFilterWithExp(right, rightKey)
  }

  private def findBloomFilterWithExp(plan: LogicalPlan, key: Expression): Boolean = {
    plan.exists {
      case Filter(condition, _) =>
        splitConjunctivePredicates(condition).exists {
          case BloomFilterMightContain(_, XxHash64(Seq(valueExpression), _))
            if valueExpression.fastEquals(key) => true
          case _ => false
        }
      case _ => false
    }
  }

  def hasInSubquery(left: LogicalPlan, right: LogicalPlan, leftKey: Expression,
      rightKey: Expression): Boolean = {
    (left, right) match {
      case (Filter(InSubquery(Seq(key),
      ListQuery(Aggregate(Seq(Alias(_, _)), Seq(Alias(_, _)), _), _, _, _, _, _)), _), _) =>
        key.fastEquals(leftKey) || key.fastEquals(new Murmur3Hash(Seq(leftKey)))
      case (_, Filter(InSubquery(Seq(key),
      ListQuery(Aggregate(Seq(Alias(_, _)), Seq(Alias(_, _)), _), _, _, _, _, _)), _)) =>
        key.fastEquals(rightKey) || key.fastEquals(new Murmur3Hash(Seq(rightKey)))
      case _ => false
    }
  }

  private def tryInjectRuntimeFilter(plan: LogicalPlan): LogicalPlan = {
    var filterCounter = 0
    val numFilterThreshold = conf.getConf(SQLConf.RUNTIME_FILTER_NUMBER_THRESHOLD)
    plan transformUp {
      case join @ ExtractEquiJoinKeys(joinType, leftKeys, rightKeys, _, _, left, right, hint) =>
        var newLeft = left
        var newRight = right
        (leftKeys, rightKeys).zipped.foreach((l, r) => {
          // Check if:
          // 1. There is already a DPP filter on the key
          // 2. There is already a runtime filter (Bloom filter or IN subquery) on the key
          // 3. The keys are simple cheap expressions
          if (filterCounter < numFilterThreshold &&
            !hasDynamicPruningSubquery(left, right, l, r) &&
            !hasRuntimeFilter(newLeft, newRight, l, r) &&
            isSimpleExpression(l) && isSimpleExpression(r)) {
            val oldLeft = newLeft
            val oldRight = newRight
            if (canPruneLeft(joinType)) {
              extractBeneficialFilterCreatePlan(left, right, l, r, hint).foreach {
                filterCreationSidePlan =>
                  newLeft = injectFilter(l, newLeft, r, filterCreationSidePlan)
              }
            }
            // Did we actually inject on the left? If not, try on the right
            if (newLeft.fastEquals(oldLeft) && canPruneRight(joinType)) {
              extractBeneficialFilterCreatePlan(right, left, r, l, hint).foreach {
                filterCreationSidePlan =>
                  newRight = injectFilter(r, newRight, l, filterCreationSidePlan)
              }
            }
            if (!newLeft.fastEquals(oldLeft) || !newRight.fastEquals(oldRight)) {
              filterCounter = filterCounter + 1
            }
          }
        })
        join.withNewChildren(Seq(newLeft, newRight))
    }
  }

  override def apply(plan: LogicalPlan): LogicalPlan = plan match {
    case s: Subquery if s.correlated => plan
    case _ if !conf.runtimeFilterSemiJoinReductionEnabled &&
      !conf.runtimeFilterBloomFilterEnabled => plan
    case _ =>
      val newPlan = tryInjectRuntimeFilter(plan)
      if (conf.runtimeFilterSemiJoinReductionEnabled && !plan.fastEquals(newPlan)) {
        RewritePredicateSubquery(newPlan)
      } else {
        newPlan
      }
  }

}
