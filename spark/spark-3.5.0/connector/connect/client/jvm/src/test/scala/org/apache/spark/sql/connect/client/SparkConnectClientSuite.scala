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
package org.apache.spark.sql.connect.client

import java.util.UUID
import java.util.concurrent.TimeUnit

import scala.collection.JavaConverters._
import scala.collection.mutable

import io.grpc.{CallOptions, Channel, ClientCall, ClientInterceptor, MethodDescriptor, Server, Status, StatusRuntimeException}
import io.grpc.netty.NettyServerBuilder
import io.grpc.stub.StreamObserver
import org.scalatest.BeforeAndAfterEach

import org.apache.spark.SparkException
import org.apache.spark.connect.proto
import org.apache.spark.connect.proto.{AddArtifactsRequest, AddArtifactsResponse, AnalyzePlanRequest, AnalyzePlanResponse, ArtifactStatusesRequest, ArtifactStatusesResponse, ExecutePlanRequest, ExecutePlanResponse, SparkConnectServiceGrpc}
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.connect.common.config.ConnectCommon
import org.apache.spark.sql.test.ConnectFunSuite

class SparkConnectClientSuite extends ConnectFunSuite with BeforeAndAfterEach {

  private var client: SparkConnectClient = _
  private var service: DummySparkConnectService = _
  private var server: Server = _

  private def startDummyServer(port: Int): Unit = {
    service = new DummySparkConnectService
    server = NettyServerBuilder
      .forPort(port)
      .addService(service)
      .build()
    server.start()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
    client = null
    server = null
    service = null
  }

  override def afterEach(): Unit = {
    if (server != null) {
      server.shutdownNow()
      assert(server.awaitTermination(5, TimeUnit.SECONDS), "server failed to shutdown")
    }

    if (client != null) {
      client.shutdown()
    }
  }

  test("Placeholder test: Create SparkConnectClient") {
    client = SparkConnectClient.builder().userId("abc123").build()
    assert(client.userId == "abc123")
  }

  // Use 0 to start the server at a random port
  private def testClientConnection(serverPort: Int = 0)(
      clientBuilder: Int => SparkConnectClient): Unit = {
    startDummyServer(serverPort)
    client = clientBuilder(server.getPort)
    val request = AnalyzePlanRequest
      .newBuilder()
      .setSessionId("abc123")
      .build()

    val response = client.analyze(request)
    assert(response.getSessionId === "abc123")
  }

  test("Test connection") {
    testClientConnection() { testPort => SparkConnectClient.builder().port(testPort).build() }
  }

  test("Test connection string") {
    testClientConnection() { testPort =>
      SparkConnectClient.builder().connectionString(s"sc://localhost:$testPort").build()
    }
  }

  test("Test encryption") {
    startDummyServer(0)
    client = SparkConnectClient
      .builder()
      .connectionString(s"sc://localhost:${server.getPort}/;use_ssl=true")
      .retryPolicy(GrpcRetryHandler.RetryPolicy(maxRetries = 0))
      .build()

    val request = AnalyzePlanRequest.newBuilder().setSessionId("abc123").build()

    // Failed the ssl handshake as the dummy server does not have any server credentials installed.
    assertThrows[SparkException] {
      client.analyze(request)
    }
  }

  test("SparkSession initialisation with connection string") {
    startDummyServer(0)
    client = SparkConnectClient
      .builder()
      .connectionString(s"sc://localhost:${server.getPort}")
      .build()

    val session = SparkSession.builder().client(client).create()
    val df = session.range(10)
    df.analyze // Trigger RPC
    assert(df.plan === service.getAndClearLatestInputPlan())
  }

  test("Custom Interceptor") {
    startDummyServer(0)
    client = SparkConnectClient
      .builder()
      .connectionString(s"sc://localhost:${server.getPort}")
      .interceptor(new ClientInterceptor {
        override def interceptCall[ReqT, RespT](
            methodDescriptor: MethodDescriptor[ReqT, RespT],
            callOptions: CallOptions,
            channel: Channel): ClientCall[ReqT, RespT] = {
          throw new RuntimeException("Blocked")
        }
      })
      .build()

    val session = SparkSession.builder().client(client).create()

    assertThrows[RuntimeException] {
      session.range(10).count()
    }
  }

  private case class TestPackURI(
      connectionString: String,
      isCorrect: Boolean,
      extraChecks: SparkConnectClient => Unit = _ => {})

  private val URIs = Seq[TestPackURI](
    TestPackURI("sc://host", isCorrect = true),
    TestPackURI(
      "sc://localhost/",
      isCorrect = true,
      client => testClientConnection(ConnectCommon.CONNECT_GRPC_BINDING_PORT)(_ => client)),
    TestPackURI(
      "sc://localhost:1234/",
      isCorrect = true,
      client => {
        assert(client.configuration.host == "localhost")
        assert(client.configuration.port == 1234)
        assert(client.sessionId != null)
        // Must be able to parse the UUID
        assert(UUID.fromString(client.sessionId) != null)
      }),
    TestPackURI(
      "sc://localhost/;",
      isCorrect = true,
      client => {
        assert(client.configuration.host == "localhost")
        assert(client.configuration.port == ConnectCommon.CONNECT_GRPC_BINDING_PORT)
      }),
    TestPackURI("sc://host:123", isCorrect = true),
    TestPackURI(
      "sc://host:123/;user_id=a94",
      isCorrect = true,
      client => assert(client.userId == "a94")),
    TestPackURI(
      "sc://host:123/;user_agent=a945",
      isCorrect = true,
      client => assert(client.userAgent == "a945")),
    TestPackURI("scc://host:12", isCorrect = false),
    TestPackURI("http://host", isCorrect = false),
    TestPackURI("sc:/host:1234/path", isCorrect = false),
    TestPackURI("sc://host/path", isCorrect = false),
    TestPackURI("sc://host/;parm1;param2", isCorrect = false),
    TestPackURI("sc://host:123;user_id=a94", isCorrect = false),
    TestPackURI("sc:///user_id=123", isCorrect = false),
    TestPackURI("sc://host:-4", isCorrect = false),
    TestPackURI("sc://:123/", isCorrect = false),
    TestPackURI("sc://host:123/;use_ssl=true", isCorrect = true),
    TestPackURI("sc://host:123/;token=mySecretToken", isCorrect = true),
    TestPackURI("sc://host:123/;token=", isCorrect = false),
    TestPackURI("sc://host:123/;session_id=", isCorrect = false),
    TestPackURI("sc://host:123/;session_id=abcdefgh", isCorrect = false),
    TestPackURI(s"sc://host:123/;session_id=${UUID.randomUUID().toString}", isCorrect = true),
    TestPackURI("sc://host:123/;use_ssl=true;token=mySecretToken", isCorrect = true),
    TestPackURI("sc://host:123/;token=mySecretToken;use_ssl=true", isCorrect = true),
    TestPackURI("sc://host:123/;use_ssl=false;token=mySecretToken", isCorrect = false),
    TestPackURI("sc://host:123/;token=mySecretToken;use_ssl=false", isCorrect = false),
    TestPackURI("sc://host:123/;param1=value1;param2=value2", isCorrect = true))

  private def checkTestPack(testPack: TestPackURI): Unit = {
    val client = SparkConnectClient.builder().connectionString(testPack.connectionString).build()
    testPack.extraChecks(client)
  }

  URIs.foreach { testPack =>
    test(s"Check URI: ${testPack.connectionString}, isCorrect: ${testPack.isCorrect}") {
      if (!testPack.isCorrect) {
        assertThrows[IllegalArgumentException](checkTestPack(testPack))
      } else {
        checkTestPack(testPack)
      }
    }
  }

  private class DummyFn(val e: Throwable, numFails: Int = 3) {
    var counter = 0
    def fn(): Int = {
      if (counter < numFails) {
        counter += 1
        throw e
      } else {
        42
      }
    }
  }

  test("SPARK-44721: Retries run for a minimum period") {
    // repeat test few times to avoid random flakes
    for (_ <- 1 to 10) {
      var totalSleepMs: Long = 0

      def sleep(t: Long): Unit = {
        totalSleepMs += t
      }

      val dummyFn = new DummyFn(new StatusRuntimeException(Status.UNAVAILABLE), numFails = 100)
      val retryHandler = new GrpcRetryHandler(GrpcRetryHandler.RetryPolicy(), sleep)

      assertThrows[StatusRuntimeException] {
        retryHandler.retry {
          dummyFn.fn()
        }
      }

      assert(totalSleepMs >= 10 * 60 * 1000) // waited at least 10 minutes
    }
  }

  test("SPARK-44275: retry actually retries") {
    val dummyFn = new DummyFn(new StatusRuntimeException(Status.UNAVAILABLE))
    val retryPolicy = GrpcRetryHandler.RetryPolicy()
    val retryHandler = new GrpcRetryHandler(retryPolicy)
    val result = retryHandler.retry { dummyFn.fn() }

    assert(result == 42)
    assert(dummyFn.counter == 3)
  }

  test("SPARK-44275: default retryException retries only on UNAVAILABLE") {
    val dummyFn = new DummyFn(new StatusRuntimeException(Status.ABORTED))
    val retryPolicy = GrpcRetryHandler.RetryPolicy()
    val retryHandler = new GrpcRetryHandler(retryPolicy)

    assertThrows[StatusRuntimeException] {
      retryHandler.retry { dummyFn.fn() }
    }
    assert(dummyFn.counter == 1)
  }

  test("SPARK-44275: retry uses canRetry to filter exceptions") {
    val dummyFn = new DummyFn(new StatusRuntimeException(Status.UNAVAILABLE))
    val retryPolicy = GrpcRetryHandler.RetryPolicy(canRetry = _ => false)
    val retryHandler = new GrpcRetryHandler(retryPolicy)

    assertThrows[StatusRuntimeException] {
      retryHandler.retry { dummyFn.fn() }
    }
    assert(dummyFn.counter == 1)
  }

  test("SPARK-44275: retry does not exceed maxRetries") {
    val dummyFn = new DummyFn(new StatusRuntimeException(Status.UNAVAILABLE))
    val retryPolicy = GrpcRetryHandler.RetryPolicy(canRetry = _ => true, maxRetries = 1)
    val retryHandler = new GrpcRetryHandler(retryPolicy)

    assertThrows[StatusRuntimeException] {
      retryHandler.retry { dummyFn.fn() }
    }
    assert(dummyFn.counter == 2)
  }
}

class DummySparkConnectService() extends SparkConnectServiceGrpc.SparkConnectServiceImplBase {

  private var inputPlan: proto.Plan = _
  private val inputArtifactRequests: mutable.ListBuffer[AddArtifactsRequest] =
    mutable.ListBuffer.empty

  private[sql] def getAndClearLatestInputPlan(): proto.Plan = {
    val plan = inputPlan
    inputPlan = null
    plan
  }

  private[sql] def getAndClearLatestAddArtifactRequests(): Seq[AddArtifactsRequest] = {
    val requests = inputArtifactRequests.toSeq
    inputArtifactRequests.clear()
    requests
  }

  override def executePlan(
      request: ExecutePlanRequest,
      responseObserver: StreamObserver[ExecutePlanResponse]): Unit = {
    // Reply with a dummy response using the same client ID
    val requestSessionId = request.getSessionId
    val operationId = if (request.hasOperationId) {
      request.getOperationId
    } else {
      UUID.randomUUID().toString
    }
    inputPlan = request.getPlan
    val response = ExecutePlanResponse
      .newBuilder()
      .setSessionId(requestSessionId)
      .setOperationId(operationId)
      .build()
    responseObserver.onNext(response)
    // Reattachable execute must end with ResultComplete
    if (request.getRequestOptionsList.asScala.exists { option =>
        option.hasReattachOptions && option.getReattachOptions.getReattachable == true
      }) {
      val resultComplete = ExecutePlanResponse
        .newBuilder()
        .setSessionId(requestSessionId)
        .setOperationId(operationId)
        .setResultComplete(proto.ExecutePlanResponse.ResultComplete.newBuilder().build())
        .build()
      responseObserver.onNext(resultComplete)
    }
    responseObserver.onCompleted()
  }

  override def analyzePlan(
      request: AnalyzePlanRequest,
      responseObserver: StreamObserver[AnalyzePlanResponse]): Unit = {
    // Reply with a dummy response using the same client ID
    val requestSessionId = request.getSessionId
    request.getAnalyzeCase match {
      case proto.AnalyzePlanRequest.AnalyzeCase.SCHEMA =>
        inputPlan = request.getSchema.getPlan
      case proto.AnalyzePlanRequest.AnalyzeCase.EXPLAIN =>
        inputPlan = request.getExplain.getPlan
      case proto.AnalyzePlanRequest.AnalyzeCase.TREE_STRING =>
        inputPlan = request.getTreeString.getPlan
      case proto.AnalyzePlanRequest.AnalyzeCase.IS_LOCAL =>
        inputPlan = request.getIsLocal.getPlan
      case proto.AnalyzePlanRequest.AnalyzeCase.IS_STREAMING =>
        inputPlan = request.getIsStreaming.getPlan
      case proto.AnalyzePlanRequest.AnalyzeCase.INPUT_FILES =>
        inputPlan = request.getInputFiles.getPlan
      case _ => inputPlan = null
    }
    val response = AnalyzePlanResponse
      .newBuilder()
      .setSessionId(requestSessionId)
      .build()
    responseObserver.onNext(response)
    responseObserver.onCompleted()
  }

  override def addArtifacts(responseObserver: StreamObserver[AddArtifactsResponse])
      : StreamObserver[AddArtifactsRequest] = new StreamObserver[AddArtifactsRequest] {
    override def onNext(v: AddArtifactsRequest): Unit = inputArtifactRequests.append(v)

    override def onError(throwable: Throwable): Unit = responseObserver.onError(throwable)

    override def onCompleted(): Unit = {
      responseObserver.onNext(proto.AddArtifactsResponse.newBuilder().build())
      responseObserver.onCompleted()
    }
  }

  override def artifactStatus(
      request: ArtifactStatusesRequest,
      responseObserver: StreamObserver[ArtifactStatusesResponse]): Unit = {
    val builder = proto.ArtifactStatusesResponse.newBuilder()
    request.getNamesList().iterator().asScala.foreach { name =>
      val status = proto.ArtifactStatusesResponse.ArtifactStatus.newBuilder()
      val exists = if (name.startsWith("cache/")) {
        inputArtifactRequests.exists { artifactReq =>
          if (artifactReq.hasBatch) {
            val batch = artifactReq.getBatch
            batch.getArtifactsList.asScala.exists { singleArtifact =>
              singleArtifact.getName == name
            }
          } else false
        }
      } else false
      builder.putStatuses(name, status.setExists(exists).build())
    }
    responseObserver.onNext(builder.build())
    responseObserver.onCompleted()
  }

  override def interrupt(
      request: proto.InterruptRequest,
      responseObserver: StreamObserver[proto.InterruptResponse]): Unit = {
    val response = proto.InterruptResponse.newBuilder().setSessionId(request.getSessionId).build()
    responseObserver.onNext(response)
    responseObserver.onCompleted()
  }

  override def reattachExecute(
      request: proto.ReattachExecuteRequest,
      responseObserver: StreamObserver[proto.ExecutePlanResponse]): Unit = {
    // Reply with a dummy response using the same client ID
    val requestSessionId = request.getSessionId
    val response = ExecutePlanResponse
      .newBuilder()
      .setSessionId(requestSessionId)
      .build()
    responseObserver.onNext(response)
    responseObserver.onCompleted()
  }

  override def releaseExecute(
      request: proto.ReleaseExecuteRequest,
      responseObserver: StreamObserver[proto.ReleaseExecuteResponse]): Unit = {
    val response = proto.ReleaseExecuteResponse
      .newBuilder()
      .setSessionId(request.getSessionId)
      .setOperationId(request.getOperationId)
      .build()
    responseObserver.onNext(response)
    responseObserver.onCompleted()
  }
}
