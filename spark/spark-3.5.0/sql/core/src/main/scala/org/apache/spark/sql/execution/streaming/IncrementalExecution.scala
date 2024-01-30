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

package org.apache.spark.sql.execution.streaming

import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

import org.apache.spark.internal.Logging
import org.apache.spark.sql.{SparkSession, Strategy}
import org.apache.spark.sql.catalyst.QueryPlanningTracker
import org.apache.spark.sql.catalyst.expressions.{CurrentBatchTimestamp, ExpressionWithRandomSeed}
import org.apache.spark.sql.catalyst.plans.logical._
import org.apache.spark.sql.catalyst.rules.Rule
import org.apache.spark.sql.catalyst.trees.TreePattern._
import org.apache.spark.sql.execution.{LocalLimitExec, QueryExecution, SparkPlan, SparkPlanner, UnaryExecNode}
import org.apache.spark.sql.execution.aggregate.{HashAggregateExec, MergingSessionsExec, ObjectHashAggregateExec, SortAggregateExec, UpdatingSessionsExec}
import org.apache.spark.sql.execution.exchange.ShuffleExchangeLike
import org.apache.spark.sql.execution.python.FlatMapGroupsInPandasWithStateExec
import org.apache.spark.sql.execution.streaming.sources.WriteToMicroBatchDataSourceV1
import org.apache.spark.sql.internal.SQLConf
import org.apache.spark.sql.streaming.OutputMode
import org.apache.spark.util.Utils

/**
 * A variant of [[QueryExecution]] that allows the execution of the given [[LogicalPlan]]
 * plan incrementally. Possibly preserving state in between each execution.
 */
class IncrementalExecution(
    sparkSession: SparkSession,
    logicalPlan: LogicalPlan,
    val outputMode: OutputMode,
    val checkpointLocation: String,
    val queryId: UUID,
    val runId: UUID,
    val currentBatchId: Long,
    val prevOffsetSeqMetadata: Option[OffsetSeqMetadata],
    val offsetSeqMetadata: OffsetSeqMetadata,
    val watermarkPropagator: WatermarkPropagator)
  extends QueryExecution(sparkSession, logicalPlan) with Logging {

  // Modified planner with stateful operations.
  override val planner: SparkPlanner = new SparkPlanner(
      sparkSession,
      sparkSession.sessionState.experimentalMethods) {
    override def strategies: Seq[Strategy] =
      extraPlanningStrategies ++
      sparkSession.sessionState.planner.strategies

    override def extraPlanningStrategies: Seq[Strategy] =
      StreamingJoinStrategy ::
      StatefulAggregationStrategy ::
      FlatMapGroupsWithStateStrategy ::
      FlatMapGroupsInPandasWithStateStrategy ::
      StreamingRelationStrategy ::
      StreamingDeduplicationStrategy ::
      StreamingGlobalLimitStrategy(outputMode) :: Nil
  }

  private[sql] val numStateStores = offsetSeqMetadata.conf.get(SQLConf.SHUFFLE_PARTITIONS.key)
    .map(SQLConf.SHUFFLE_PARTITIONS.valueConverter)
    .getOrElse(sparkSession.sessionState.conf.numShufflePartitions)

  /**
   * See [SPARK-18339]
   * Walk the optimized logical plan and replace CurrentBatchTimestamp
   * with the desired literal
   */
  override
  lazy val optimizedPlan: LogicalPlan = executePhase(QueryPlanningTracker.OPTIMIZATION) {
    // Performing streaming specific pre-optimization.
    val preOptimized = withCachedData.transform {
      // We eliminate the "marker" node for writer on DSv1 as it's only used as representation
      // of sink information.
      case w: WriteToMicroBatchDataSourceV1 => w.child
    }
    sparkSession.sessionState.optimizer.executeAndTrack(preOptimized,
      tracker).transformAllExpressionsWithPruning(
      _.containsAnyPattern(CURRENT_LIKE, EXPRESSION_WITH_RANDOM_SEED)) {
      case ts @ CurrentBatchTimestamp(timestamp, _, _) =>
        logInfo(s"Current batch timestamp = $timestamp")
        ts.toLiteral
      case e: ExpressionWithRandomSeed => e.withNewSeed(Utils.random.nextLong())
    }
  }

  private val allowMultipleStatefulOperators: Boolean =
    sparkSession.sessionState.conf.getConf(SQLConf.STATEFUL_OPERATOR_ALLOW_MULTIPLE)

  /**
   * Records the current id for a given stateful operator in the query plan as the `state`
   * preparation walks the query plan.
   */
  private val statefulOperatorId = new AtomicInteger(0)

  /** Get the state info of the next stateful operator */
  private def nextStatefulOperationStateInfo(): StatefulOperatorStateInfo = {
    StatefulOperatorStateInfo(
      checkpointLocation,
      runId,
      statefulOperatorId.getAndIncrement(),
      currentBatchId,
      numStateStores)
  }

  sealed trait SparkPlanPartialRule {
    val rule: PartialFunction[SparkPlan, SparkPlan]
  }

  object ShufflePartitionsRule extends SparkPlanPartialRule {
    override val rule: PartialFunction[SparkPlan, SparkPlan] = {
      // NOTE: we should include all aggregate execs here which are used in streaming aggregations
      case a: SortAggregateExec if a.isStreaming =>
        a.copy(numShufflePartitions = Some(numStateStores))

      case a: HashAggregateExec if a.isStreaming =>
        a.copy(numShufflePartitions = Some(numStateStores))

      case a: ObjectHashAggregateExec if a.isStreaming =>
        a.copy(numShufflePartitions = Some(numStateStores))

      case a: MergingSessionsExec if a.isStreaming =>
        a.copy(numShufflePartitions = Some(numStateStores))

      case a: UpdatingSessionsExec if a.isStreaming =>
        a.copy(numShufflePartitions = Some(numStateStores))
    }
  }

  object ConvertLocalLimitRule extends SparkPlanPartialRule {
    /**
     * Ensures that this plan DOES NOT have any stateful operation in it whose pipelined execution
     * depends on this plan. In other words, this function returns true if this plan does
     * have a narrow dependency on a stateful subplan.
     */
    private def hasNoStatefulOp(plan: SparkPlan): Boolean = {
      var statefulOpFound = false

      def findStatefulOp(planToCheck: SparkPlan): Unit = {
        planToCheck match {
          case s: StatefulOperator =>
            statefulOpFound = true

          case e: ShuffleExchangeLike =>
            // Don't search recursively any further as any child stateful operator as we
            // are only looking for stateful subplans that this plan has narrow dependencies on.

          case p: SparkPlan =>
            p.children.foreach(findStatefulOp)
        }
      }

      findStatefulOp(plan)
      !statefulOpFound
    }

    override val rule: PartialFunction[SparkPlan, SparkPlan] = {
      case StreamingLocalLimitExec(limit, child) if hasNoStatefulOp(child) =>
        // Optimize limit execution by replacing StreamingLocalLimitExec (consumes the iterator
        // completely) to LocalLimitExec (does not consume the iterator) when the child plan has
        // no stateful operator (i.e., consuming the iterator is not needed).
        LocalLimitExec(limit, child)
    }
  }

  object StateOpIdRule extends SparkPlanPartialRule {
    override val rule: PartialFunction[SparkPlan, SparkPlan] = {
      case StateStoreSaveExec(keys, None, None, None, None, stateFormatVersion,
      UnaryExecNode(agg,
      StateStoreRestoreExec(_, None, _, child))) =>
        val aggStateInfo = nextStatefulOperationStateInfo
        StateStoreSaveExec(
          keys,
          Some(aggStateInfo),
          Some(outputMode),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None,
          stateFormatVersion,
          agg.withNewChildren(
            StateStoreRestoreExec(
              keys,
              Some(aggStateInfo),
              stateFormatVersion,
              child) :: Nil))

      case SessionWindowStateStoreSaveExec(keys, session, None, None, None, None,
      stateFormatVersion,
      UnaryExecNode(agg,
      SessionWindowStateStoreRestoreExec(_, _, None, None, None, _, child))) =>
        val aggStateInfo = nextStatefulOperationStateInfo
        SessionWindowStateStoreSaveExec(
          keys,
          session,
          Some(aggStateInfo),
          Some(outputMode),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None,
          stateFormatVersion,
          agg.withNewChildren(
            SessionWindowStateStoreRestoreExec(
              keys,
              session,
              Some(aggStateInfo),
              eventTimeWatermarkForLateEvents = None,
              eventTimeWatermarkForEviction = None,
              stateFormatVersion,
              child) :: Nil))

      case StreamingDeduplicateExec(keys, child, None, None, None) =>
        StreamingDeduplicateExec(
          keys,
          child,
          Some(nextStatefulOperationStateInfo),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None)

      case StreamingDeduplicateWithinWatermarkExec(keys, child, None, None, None) =>
        StreamingDeduplicateWithinWatermarkExec(
          keys,
          child,
          Some(nextStatefulOperationStateInfo),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None)

      case m: FlatMapGroupsWithStateExec =>
        // We set this to true only for the first batch of the streaming query.
        val hasInitialState = (currentBatchId == 0L && m.hasInitialState)
        m.copy(
          stateInfo = Some(nextStatefulOperationStateInfo),
          batchTimestampMs = Some(offsetSeqMetadata.batchTimestampMs),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None,
          hasInitialState = hasInitialState
        )

      case m: FlatMapGroupsInPandasWithStateExec =>
        m.copy(
          stateInfo = Some(nextStatefulOperationStateInfo),
          batchTimestampMs = Some(offsetSeqMetadata.batchTimestampMs),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None
        )

      case j: StreamingSymmetricHashJoinExec =>
        j.copy(
          stateInfo = Some(nextStatefulOperationStateInfo),
          eventTimeWatermarkForLateEvents = None,
          eventTimeWatermarkForEviction = None
        )

      case l: StreamingGlobalLimitExec =>
        l.copy(
          stateInfo = Some(nextStatefulOperationStateInfo),
          outputMode = Some(outputMode))
    }
  }

  object WatermarkPropagationRule extends SparkPlanPartialRule {
    private def inputWatermarkForLateEvents(stateInfo: StatefulOperatorStateInfo): Option[Long] = {
      Some(watermarkPropagator.getInputWatermarkForLateEvents(currentBatchId,
        stateInfo.operatorId))
    }

    private def inputWatermarkForEviction(stateInfo: StatefulOperatorStateInfo): Option[Long] = {
      Some(watermarkPropagator.getInputWatermarkForEviction(currentBatchId, stateInfo.operatorId))
    }

    override val rule: PartialFunction[SparkPlan, SparkPlan] = {
      case s: StateStoreSaveExec if s.stateInfo.isDefined =>
        s.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(s.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(s.stateInfo.get)
        )

      case s: SessionWindowStateStoreSaveExec if s.stateInfo.isDefined =>
        s.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(s.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(s.stateInfo.get)
        )

      case s: SessionWindowStateStoreRestoreExec if s.stateInfo.isDefined =>
        s.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(s.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(s.stateInfo.get)
        )

      case s: StreamingDeduplicateExec if s.stateInfo.isDefined =>
        s.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(s.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(s.stateInfo.get)
        )

      case s: StreamingDeduplicateWithinWatermarkExec if s.stateInfo.isDefined =>
        s.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(s.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(s.stateInfo.get)
        )

      case m: FlatMapGroupsWithStateExec if m.stateInfo.isDefined =>
        m.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(m.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(m.stateInfo.get)
        )

      case m: FlatMapGroupsInPandasWithStateExec if m.stateInfo.isDefined =>
        m.copy(
          eventTimeWatermarkForLateEvents = inputWatermarkForLateEvents(m.stateInfo.get),
          eventTimeWatermarkForEviction = inputWatermarkForEviction(m.stateInfo.get)
        )

      case j: StreamingSymmetricHashJoinExec =>
        val iwLateEvents = inputWatermarkForLateEvents(j.stateInfo.get)
        val iwEviction = inputWatermarkForEviction(j.stateInfo.get)
        j.copy(
          eventTimeWatermarkForLateEvents = iwLateEvents,
          eventTimeWatermarkForEviction = iwEviction,
          stateWatermarkPredicates =
            StreamingSymmetricHashJoinHelper.getStateWatermarkPredicates(
              j.left.output, j.right.output, j.leftKeys, j.rightKeys, j.condition.full,
              iwEviction, !allowMultipleStatefulOperators)
        )
    }
  }

  val state = new Rule[SparkPlan] {
    private def simulateWatermarkPropagation(plan: SparkPlan): Unit = {
      val watermarkForPrevBatch = prevOffsetSeqMetadata.map(_.batchWatermarkMs).getOrElse(0L)
      val watermarkForCurrBatch = offsetSeqMetadata.batchWatermarkMs

      // This is to simulate watermark propagation for late events.
      watermarkPropagator.propagate(currentBatchId - 1, plan, watermarkForPrevBatch)
      // This is to simulate watermark propagation for eviction.
      watermarkPropagator.propagate(currentBatchId, plan, watermarkForCurrBatch)
    }

    private lazy val composedRule: PartialFunction[SparkPlan, SparkPlan] = {
      // There should be no same pattern across rules in the list.
      val rulesToCompose = Seq(ShufflePartitionsRule, ConvertLocalLimitRule, StateOpIdRule)
        .map(_.rule)

      rulesToCompose.reduceLeft { (ruleA, ruleB) => ruleA orElse ruleB }
    }

    override def apply(plan: SparkPlan): SparkPlan = {
      val planWithStateOpId = plan transform composedRule
      simulateWatermarkPropagation(planWithStateOpId)
      planWithStateOpId transform WatermarkPropagationRule.rule
    }
  }

  override def preparations: Seq[Rule[SparkPlan]] = state +: super.preparations

  /** No need assert supported, as this check has already been done */
  override def assertSupported(): Unit = { }

  /**
   * Should the MicroBatchExecution run another batch based on this execution and the current
   * updated metadata.
   *
   * This method performs simulation of watermark propagation against new batch (which is not
   * planned yet), which is required for asking the needs of another batch to each stateful
   * operator.
   */
  def shouldRunAnotherBatch(newMetadata: OffsetSeqMetadata): Boolean = {
    val tentativeBatchId = currentBatchId + 1
    watermarkPropagator.propagate(tentativeBatchId, executedPlan, newMetadata.batchWatermarkMs)
    executedPlan.collect {
      case p: StateStoreWriter => p.shouldRunAnotherBatch(
        watermarkPropagator.getInputWatermarkForEviction(tentativeBatchId,
          p.stateInfo.get.operatorId))
    }.exists(_ == true)
  }
}
