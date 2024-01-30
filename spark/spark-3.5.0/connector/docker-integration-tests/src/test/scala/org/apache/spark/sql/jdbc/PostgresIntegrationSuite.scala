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

package org.apache.spark.sql.jdbc

import java.math.{BigDecimal => JBigDecimal}
import java.sql.{Connection, Date, Timestamp}
import java.text.SimpleDateFormat
import java.time.{LocalDateTime, ZoneOffset}
import java.util.Properties

import org.apache.spark.sql.Column
import org.apache.spark.sql.Row
import org.apache.spark.sql.catalyst.expressions.Literal
import org.apache.spark.sql.types.{ArrayType, DecimalType, FloatType, ShortType}
import org.apache.spark.tags.DockerTest

/**
 * To run this test suite for a specific version (e.g., postgres:15.1):
 * {{{
 *   ENABLE_DOCKER_INTEGRATION_TESTS=1 POSTGRES_DOCKER_IMAGE_NAME=postgres:15.1
 *     ./build/sbt -Pdocker-integration-tests
 *     "testOnly org.apache.spark.sql.jdbc.PostgresIntegrationSuite"
 * }}}
 */
@DockerTest
class PostgresIntegrationSuite extends DockerJDBCIntegrationSuite {
  override val db = new DatabaseOnDocker {
    override val imageName = sys.env.getOrElse("POSTGRES_DOCKER_IMAGE_NAME", "postgres:15.1-alpine")
    override val env = Map(
      "POSTGRES_PASSWORD" -> "rootpass"
    )
    override val usesIpc = false
    override val jdbcPort = 5432
    override def getJdbcUrl(ip: String, port: Int): String =
      s"jdbc:postgresql://$ip:$port/postgres?user=postgres&password=rootpass"
  }

  override def dataPreparation(conn: Connection): Unit = {
    conn.prepareStatement("CREATE DATABASE foo").executeUpdate()
    conn.setCatalog("foo")
    conn.prepareStatement("CREATE TYPE enum_type AS ENUM ('d1', 'd2')").executeUpdate()
    conn.prepareStatement("CREATE TABLE bar (c0 text, c1 integer, c2 double precision, c3 bigint, "
      + "c4 bit(1), c5 bit(10), c6 bytea, c7 boolean, c8 inet, c9 cidr, "
      + "c10 integer[], c11 text[], c12 real[], c13 numeric(2,2)[], c14 enum_type, "
      + "c15 float4, c16 smallint, c17 numeric[], c18 bit varying(6), c19 point, c20 line, "
      + "c21 lseg, c22 box, c23 path, c24 polygon, c25 circle, c26 pg_lsn, "
      + "c27 character(2), c28 character varying(3), c29 date, c30 interval, "
      + "c31 macaddr, c32 macaddr8, c33 numeric(6,4), c34 pg_snapshot, "
      + "c35 real, c36 time, c37 timestamp, c38 tsquery, c39 tsvector, c40 txid_snapshot, "
      + "c41 xml)").executeUpdate()
    conn.prepareStatement("INSERT INTO bar VALUES ('hello', 42, 1.25, 123456789012345, B'0', "
      + "B'1000100101', E'\\\\xDEADBEEF', true, '172.16.0.42', '192.168.0.0/16', "
      + """'{1, 2}', '{"a", null, "b"}', '{0.11, 0.22}', '{0.11, 0.22}', 'd1', 1.01, 1, """
      + "'{111.2222, 333.4444}', B'101010', '(800, 600)', '(23.8, 56.2), (16.23, 89.2)', "
      + "'[(80.12, 131.24), (201.5, 503.33)]', '(19.84, 11.23), (20.21, 2.1)', "
      + "'(10.2, 30.4), (50.6, 70.8), (90.1, 11.3)', "
      + "'((100.3, 40.2), (20.198, 83.1), (500.821, 311.38))', '<500, 200, 100>', '16/B374D848', "
      + "'ab', 'efg', '2021-02-02', '1 minute', '00:11:22:33:44:55', "
      + "'00:11:22:33:44:55:66:77', 12.3456, '10:20:10,14,15', 1E+37, "
      + "'17:22:31', '2016-08-12 10:22:31.949271', 'cat:AB & dog:CD', "
      + "'dog and cat and fox', '10:20:10,14,15', '<key>id</key><value>10</value>')"
    ).executeUpdate()
    conn.prepareStatement("INSERT INTO bar VALUES (null, null, null, null, null, "
      + "null, null, null, null, null, null, null, null, null, null, null, null, "
      + "null, null, null, null, null, null, null, null, null, null, null, null, "
      + "null, null, null, null, null, null, null, null, null, null, null, null, null)"
    ).executeUpdate()

    conn.prepareStatement("CREATE TABLE ts_with_timezone " +
      "(id integer, tstz TIMESTAMP WITH TIME ZONE, ttz TIME WITH TIME ZONE)")
      .executeUpdate()
    conn.prepareStatement("INSERT INTO ts_with_timezone VALUES " +
      "(1, TIMESTAMP WITH TIME ZONE '2016-08-12 10:22:31.949271-07', " +
      "TIME WITH TIME ZONE '17:22:31.949271+00')")
      .executeUpdate()

    conn.prepareStatement("CREATE TABLE st_with_array (c0 uuid, c1 inet, c2 cidr," +
      "c3 json, c4 jsonb, c5 uuid[], c6 inet[], c7 cidr[], c8 json[], c9 jsonb[], c10 xml[], " +
      "c11 tsvector[], c12 tsquery[], c13 macaddr[], c14 txid_snapshot[], c15 point[], " +
      "c16 line[], c17 lseg[], c18 box[], c19 path[], c20 polygon[], c21 circle[], c22 pg_lsn[], " +
      "c23 bit varying(6)[], c24 interval[], c25 macaddr8[], c26 pg_snapshot[])")
      .executeUpdate()
    conn.prepareStatement("INSERT INTO st_with_array VALUES ( " +
      "'0a532531-cdf1-45e3-963d-5de90b6a30f1', '172.168.22.1', '192.168.100.128/25', " +
      """'{"a": "foo", "b": "bar"}', '{"a": 1, "b": 2}', """ +
      "ARRAY['7be8aaf8-650e-4dbb-8186-0a749840ecf2'," +
      "'205f9bfc-018c-4452-a605-609c0cfad228']::uuid[], ARRAY['172.16.0.41', " +
      "'172.16.0.42']::inet[], ARRAY['192.168.0.0/24', '10.1.0.0/16']::cidr[], " +
      """ARRAY['{"a": "foo", "b": "bar"}', '{"a": 1, "b": 2}']::json[], """ +
      """ARRAY['{"a": 1, "b": 2, "c": 3}']::jsonb[], """ +
      """ARRAY['<key>id</key><value>10</value>']::xml[], ARRAY['The dog laying on the grass', """ +
      """'the:1 cat:2 is:3 on:4 the:5 table:6']::tsvector[], """ +
      """ARRAY['programming & language & ! interpreter', 'cat:AB & dog:CD']::tsquery[], """ +
      """ARRAY['12:34:56:78:90:ab', 'cd-ef-12-34-56-78']::macaddr[], """ +
      """ARRAY['10:20:10,14,15']::txid_snapshot[], """ +
      """ARRAY['(800, 600)', '83.24, 5.10']::point[], """ +
      """ARRAY['(23.8, 56.2), (16.23, 89.2)', '{23.85, 10.87, 5.92}']::line[], """ +
      """ARRAY['[(80.12, 131.24), (201.5, 503.33)]']::lseg[], """ +
      """ARRAY['(19.84, 11.23), (20.21, 2.1)']::box[], """ +
      """ARRAY['(10.2, 30.4), (50.6, 70.8), (90.1, 11.3)']::path[], """ +
      """ARRAY['((100.3, 40.2), (20.198, 83.1), (500.821, 311.38))']::polygon[], """ +
      """ARRAY['<500, 200, 100>']::circle[], """ +
      """ARRAY['16/B374D848']::pg_lsn[], """ +
      """ARRAY[B'101010']::bit varying(6)[], """ +
      """ARRAY['1 day', '2 minutes']::interval[], """ +
      """ARRAY['08:00:2b:01:02:03:04:05']::macaddr8[], """ +
      """ARRAY['10:20:10,14,15']::pg_snapshot[])"""
    ).executeUpdate()

    conn.prepareStatement("CREATE TABLE char_types (" +
      "c0 char(4), c1 character(4), c2 character varying(4), c3 varchar(4), c4 bpchar(1))"
    ).executeUpdate()
    conn.prepareStatement("INSERT INTO char_types VALUES " +
      "('abcd', 'efgh', 'ijkl', 'mnop', 'q')").executeUpdate()

    // SPARK-42916: character/char/bpchar w/o length specifier defaults to int max value, this will
    // cause OOM as it will be padded with ' ' to 2147483647.
    conn.prepareStatement("CREATE TABLE char_array_types (" +
      "c0 char(4)[], c1 character(4)[], c2 character varying(4)[], c3 varchar(4)[], c4 bpchar(1)[])"
    ).executeUpdate()
    conn.prepareStatement("INSERT INTO char_array_types VALUES " +
      """('{"a", "bcd"}', '{"ef", "gh"}', '{"i", "j", "kl"}', '{"mnop"}', '{"q", "r"}')"""
    ).executeUpdate()

    conn.prepareStatement("CREATE TABLE money_types (" +
      "c0 money)").executeUpdate()
    conn.prepareStatement("INSERT INTO money_types VALUES " +
      "('$1,000.00')").executeUpdate()

    conn.prepareStatement(s"CREATE TABLE timestamp_ntz(v timestamp)").executeUpdate()
    conn.prepareStatement(s"""INSERT INTO timestamp_ntz VALUES
      |('2013-04-05 12:01:02'),
      |('2013-04-05 18:01:02.123'),
      |('2013-04-05 18:01:02.123456')""".stripMargin).executeUpdate()

    conn.prepareStatement("CREATE TABLE infinity_timestamp" +
      "(id SERIAL PRIMARY KEY, timestamp_column TIMESTAMP);").executeUpdate()
    conn.prepareStatement("INSERT INTO infinity_timestamp (timestamp_column)" +
      " VALUES ('infinity'), ('-infinity');").executeUpdate()

    conn.prepareStatement("CREATE DOMAIN not_null_text AS TEXT DEFAULT ''").executeUpdate()
    conn.prepareStatement("create table custom_type(type_array not_null_text[]," +
      "type not_null_text)").executeUpdate()
    conn.prepareStatement("INSERT INTO custom_type (type_array, type) VALUES" +
      "('{1,fds,fdsa}','fdasfasdf')").executeUpdate()

  }

  test("Type mapping for various types") {
    val df = sqlContext.read.jdbc(jdbcUrl, "bar", new Properties)
    val rows = df.collect().sortBy(_.toString())
    assert(rows.length == 2)
    // Test the types, and values using the first row.
    val types = rows(0).toSeq.map(x => x.getClass)
    assert(types.length == 42)
    assert(classOf[String].isAssignableFrom(types(0)))
    assert(classOf[java.lang.Integer].isAssignableFrom(types(1)))
    assert(classOf[java.lang.Double].isAssignableFrom(types(2)))
    assert(classOf[java.lang.Long].isAssignableFrom(types(3)))
    assert(classOf[java.lang.Boolean].isAssignableFrom(types(4)))
    assert(classOf[Array[Byte]].isAssignableFrom(types(5)))
    assert(classOf[Array[Byte]].isAssignableFrom(types(6)))
    assert(classOf[java.lang.Boolean].isAssignableFrom(types(7)))
    assert(classOf[String].isAssignableFrom(types(8)))
    assert(classOf[String].isAssignableFrom(types(9)))
    assert(classOf[scala.collection.Seq[Int]].isAssignableFrom(types(10)))
    assert(classOf[scala.collection.Seq[String]].isAssignableFrom(types(11)))
    assert(classOf[scala.collection.Seq[Double]].isAssignableFrom(types(12)))
    assert(classOf[scala.collection.Seq[BigDecimal]].isAssignableFrom(types(13)))
    assert(classOf[String].isAssignableFrom(types(14)))
    assert(classOf[java.lang.Float].isAssignableFrom(types(15)))
    assert(classOf[java.lang.Short].isAssignableFrom(types(16)))
    assert(classOf[scala.collection.Seq[BigDecimal]].isAssignableFrom(types(17)))
    assert(classOf[String].isAssignableFrom(types(18)))
    assert(classOf[String].isAssignableFrom(types(19)))
    assert(classOf[String].isAssignableFrom(types(20)))
    assert(classOf[String].isAssignableFrom(types(21)))
    assert(classOf[String].isAssignableFrom(types(22)))
    assert(classOf[String].isAssignableFrom(types(23)))
    assert(classOf[String].isAssignableFrom(types(24)))
    assert(classOf[String].isAssignableFrom(types(25)))
    assert(classOf[String].isAssignableFrom(types(26)))
    assert(classOf[String].isAssignableFrom(types(27)))
    assert(classOf[String].isAssignableFrom(types(28)))
    assert(classOf[Date].isAssignableFrom(types(29)))
    assert(classOf[String].isAssignableFrom(types(30)))
    assert(classOf[String].isAssignableFrom(types(31)))
    assert(classOf[String].isAssignableFrom(types(32)))
    assert(classOf[JBigDecimal].isAssignableFrom(types(33)))
    assert(classOf[String].isAssignableFrom(types(34)))
    assert(classOf[java.lang.Float].isAssignableFrom(types(35)))
    assert(classOf[java.sql.Timestamp].isAssignableFrom(types(36)))
    assert(classOf[java.sql.Timestamp].isAssignableFrom(types(37)))
    assert(classOf[String].isAssignableFrom(types(38)))
    assert(classOf[String].isAssignableFrom(types(39)))
    assert(classOf[String].isAssignableFrom(types(40)))
    assert(classOf[String].isAssignableFrom(types(41)))
    assert(rows(0).getString(0).equals("hello"))
    assert(rows(0).getInt(1) == 42)
    assert(rows(0).getDouble(2) == 1.25)
    assert(rows(0).getLong(3) == 123456789012345L)
    assert(!rows(0).getBoolean(4))
    // BIT(10)'s come back as ASCII strings of ten ASCII 0's and 1's...
    assert(java.util.Arrays.equals(rows(0).getAs[Array[Byte]](5),
      Array[Byte](49, 48, 48, 48, 49, 48, 48, 49, 48, 49)))
    assert(java.util.Arrays.equals(rows(0).getAs[Array[Byte]](6),
      Array[Byte](0xDE.toByte, 0xAD.toByte, 0xBE.toByte, 0xEF.toByte)))
    assert(rows(0).getBoolean(7))
    assert(rows(0).getString(8) == "172.16.0.42")
    assert(rows(0).getString(9) == "192.168.0.0/16")
    assert(rows(0).getSeq(10) == Seq(1, 2))
    assert(rows(0).getSeq(11) == Seq("a", null, "b"))
    assert(rows(0).getSeq(12).toSeq == Seq(0.11f, 0.22f))
    assert(rows(0).getSeq(13) == Seq("0.11", "0.22").map(BigDecimal(_).bigDecimal))
    assert(rows(0).getString(14) == "d1")
    assert(rows(0).getFloat(15) == 1.01f)
    assert(rows(0).getShort(16) == 1)
    assert(rows(0).getSeq(17) ==
      Seq("111.222200000000000000", "333.444400000000000000").map(BigDecimal(_).bigDecimal))
    assert(rows(0).getString(18) == "101010")
    assert(rows(0).getString(19) == "(800,600)")
    assert(rows(0).getString(20) == "{-4.359313077939234,-1,159.9516512549538}")
    assert(rows(0).getString(21) == "[(80.12,131.24),(201.5,503.33)]")
    assert(rows(0).getString(22) == "(20.21,11.23),(19.84,2.1)")
    assert(rows(0).getString(23) == "((10.2,30.4),(50.6,70.8),(90.1,11.3))")
    assert(rows(0).getString(24) == "((100.3,40.2),(20.198,83.1),(500.821,311.38))")
    assert(rows(0).getString(25) == "<(500,200),100>")
    assert(rows(0).getString(26) == "16/B374D848")
    assert(rows(0).getString(27) == "ab")
    assert(rows(0).getString(28) == "efg")
    assert(rows(0).getDate(29) == new SimpleDateFormat("yyyy-MM-dd").parse("2021-02-02"))
    assert(rows(0).getString(30) == "00:01:00")
    assert(rows(0).getString(31) == "00:11:22:33:44:55")
    assert(rows(0).getString(32) == "00:11:22:33:44:55:66:77")
    assert(rows(0).getDecimal(33) == new JBigDecimal("12.3456"))
    assert(rows(0).getString(34) == "10:20:10,14,15")
    assert(rows(0).getFloat(35) == 1E+37F)
    assert(rows(0).getTimestamp(36) == Timestamp.valueOf("1970-01-01 17:22:31.0"))
    assert(rows(0).getTimestamp(37) == Timestamp.valueOf("2016-08-12 10:22:31.949271"))
    assert(rows(0).getString(38) == "'cat':AB & 'dog':CD")
    assert(rows(0).getString(39) == "'and' 'cat' 'dog' 'fox'")
    assert(rows(0).getString(40) == "10:20:10,14,15")
    assert(rows(0).getString(41) == "<key>id</key><value>10</value>")

    // Test reading null values using the second row.
    assert(0.until(16).forall(rows(1).isNullAt(_)))
  }

  test("Basic write test") {
    val df = sqlContext.read.jdbc(jdbcUrl, "bar", new Properties)
    // Test only that it doesn't crash.
    df.write.jdbc(jdbcUrl, "public.barcopy", new Properties)
    // Test that written numeric type has same DataType as input
    assert(sqlContext.read.jdbc(jdbcUrl, "public.barcopy", new Properties).schema(13).dataType ==
      ArrayType(DecimalType(2, 2), true))
    // Test write null values.
    df.select(df.queryExecution.analyzed.output.map { a =>
      Column(Literal.create(null, a.dataType)).as(a.name)
    }: _*).write.jdbc(jdbcUrl, "public.barcopy2", new Properties)
  }

  test("Creating a table with shorts and floats") {
    sqlContext.createDataFrame(Seq((1.0f, 1.toShort)))
      .write.jdbc(jdbcUrl, "shortfloat", new Properties)
    val schema = sqlContext.read.jdbc(jdbcUrl, "shortfloat", new Properties).schema
    assert(schema(0).dataType == FloatType)
    assert(schema(1).dataType == ShortType)
  }

  test("SPARK-20557: column type TIMESTAMP with TIME ZONE and TIME with TIME ZONE " +
    "should be recognized") {
    // When using JDBC to read the columns of TIMESTAMP with TIME ZONE and TIME with TIME ZONE
    // the actual types are java.sql.Types.TIMESTAMP and java.sql.Types.TIME
    val dfRead = sqlContext.read.jdbc(jdbcUrl, "ts_with_timezone", new Properties)
    val rows = dfRead.collect()
    val types = rows(0).toSeq.map(x => x.getClass.toString)
    assert(types(1).equals("class java.sql.Timestamp"))
    assert(types(2).equals("class java.sql.Timestamp"))
  }

  test("SPARK-22291: Conversion error when transforming array types of " +
    "uuid, inet and cidr to StingType in PostgreSQL") {
    val df = sqlContext.read.jdbc(jdbcUrl, "st_with_array", new Properties)
    val rows = df.collect()
    assert(rows(0).getString(0) == "0a532531-cdf1-45e3-963d-5de90b6a30f1")
    assert(rows(0).getString(1) == "172.168.22.1")
    assert(rows(0).getString(2) == "192.168.100.128/25")
    assert(rows(0).getString(3) == "{\"a\": \"foo\", \"b\": \"bar\"}")
    assert(rows(0).getString(4) == "{\"a\": 1, \"b\": 2}")
    assert(rows(0).getSeq(5) == Seq("7be8aaf8-650e-4dbb-8186-0a749840ecf2",
      "205f9bfc-018c-4452-a605-609c0cfad228"))
    assert(rows(0).getSeq(6) == Seq("172.16.0.41", "172.16.0.42"))
    assert(rows(0).getSeq(7) == Seq("192.168.0.0/24", "10.1.0.0/16"))
    assert(rows(0).getSeq(8) == Seq("""{"a": "foo", "b": "bar"}""", """{"a": 1, "b": 2}"""))
    assert(rows(0).getSeq(9) == Seq("""{"a": 1, "b": 2, "c": 3}"""))
    assert(rows(0).getSeq(10) == Seq("""<key>id</key><value>10</value>"""))
    assert(rows(0).getSeq(11) == Seq("'The' 'dog' 'grass' 'laying' 'on' 'the'",
      "'cat':2 'is':3 'on':4 'table':6 'the':1,5"))
    assert(rows(0).getSeq(12) == Seq("'programming' & 'language' & !'interpreter'",
      "'cat':AB & 'dog':CD"))
    assert(rows(0).getSeq(13) == Seq("12:34:56:78:90:ab", "cd:ef:12:34:56:78"))
    assert(rows(0).getSeq(14) == Seq("10:20:10,14,15"))
    assert(rows(0).getSeq(15) == Seq("(800.0,600.0)", "(83.24,5.1)"))
    assert(rows(0).getSeq(16) == Seq("{-4.359313077939234,-1.0,159.9516512549538}",
      "{23.85,10.87,5.92}"))
    assert(rows(0).getSeq(17) == Seq("[(80.12,131.24),(201.5,503.33)]"))
    assert(rows(0).getSeq(18) == Seq("(20.21,11.23),(19.84,2.1)"))
    assert(rows(0).getSeq(19) == Seq("((10.2,30.4),(50.6,70.8),(90.1,11.3))"))
    assert(rows(0).getSeq(20) == Seq("((100.3,40.2),(20.198,83.1),(500.821,311.38))"))
    assert(rows(0).getSeq(21) == Seq("<(500.0,200.0),100.0>"))
    assert(rows(0).getSeq(22) == Seq("16/B374D848"))
    assert(rows(0).getSeq(23) == Seq("101010"))
    assert(rows(0).getSeq(24) == Seq("0 years 0 mons 1 days 0 hours 0 mins 0.0 secs",
      "0 years 0 mons 0 days 0 hours 2 mins 0.0 secs"))
    assert(rows(0).getSeq(25) == Seq("08:00:2b:01:02:03:04:05"))
    assert(rows(0).getSeq(26) == Seq("10:20:10,14,15"))
  }

  test("query JDBC option") {
    val expectedResult = Set(
      (42, 123456789012345L)
    ).map { case (c1, c3) =>
      Row(Integer.valueOf(c1), java.lang.Long.valueOf(c3))
    }

    val query = "SELECT c1, c3 FROM bar WHERE c1 IS NOT NULL"
    // query option to pass on the query string.
    val df = spark.read.format("jdbc")
      .option("url", jdbcUrl)
      .option("query", query)
      .load()
    assert(df.collect.toSet === expectedResult)

    // query option in the create table path.
    sql(
      s"""
         |CREATE OR REPLACE TEMPORARY VIEW queryOption
         |USING org.apache.spark.sql.jdbc
         |OPTIONS (url '$jdbcUrl', query '$query')
       """.stripMargin.replaceAll("\n", " "))
    assert(sql("select c1, c3 from queryOption").collect.toSet == expectedResult)
  }

  test("write byte as smallint") {
    sqlContext.createDataFrame(Seq((1.toByte, 2.toShort)))
      .write.jdbc(jdbcUrl, "byte_to_smallint_test", new Properties)
    val df = sqlContext.read.jdbc(jdbcUrl, "byte_to_smallint_test", new Properties)
    val schema = df.schema
    assert(schema.head.dataType == ShortType)
    assert(schema(1).dataType == ShortType)
    val rows = df.collect()
    assert(rows.length === 1)
    assert(rows(0).getShort(0) === 1)
    assert(rows(0).getShort(1) === 2)
  }

  test("character type tests") {
    val df = sqlContext.read.jdbc(jdbcUrl, "char_types", new Properties)
    val row = df.collect()
    assert(row.length == 1)
    assert(row(0).length === 5)
    assert(row(0).getString(0) === "abcd")
    assert(row(0).getString(1) === "efgh")
    assert(row(0).getString(2) === "ijkl")
    assert(row(0).getString(3) === "mnop")
    assert(row(0).getString(4) === "q")
  }

  test("SPARK-32576: character array type tests") {
    val df = sqlContext.read.jdbc(jdbcUrl, "char_array_types", new Properties)
    val row = df.collect()
    assert(row.length == 1)
    assert(row(0).length === 5)
    assert(row(0).getSeq[String](0) === Seq("a   ", "bcd "))
    assert(row(0).getSeq[String](1) === Seq("ef  ", "gh  "))
    assert(row(0).getSeq[String](2) === Seq("i", "j", "kl"))
    assert(row(0).getSeq[String](3) === Seq("mnop"))
    assert(row(0).getSeq[String](4) === Seq("q", "r"))
  }

  test("SPARK-34333: money type tests") {
    val df = sqlContext.read.jdbc(jdbcUrl, "money_types", new Properties)
    val row = df.collect()
    assert(row.length === 1)
    assert(row(0).length === 1)
    assert(row(0).getString(0) === "$1,000.00")
  }

  test("SPARK-43040: timestamp_ntz read test") {
    val prop = new Properties
    prop.setProperty("preferTimestampNTZ", "true")
    val df = sqlContext.read.jdbc(jdbcUrl, "timestamp_ntz", prop)
    val row = df.collect()
    assert(row.length === 3)
    assert(row(0).length === 1)
    assert(row(0) === Row(LocalDateTime.of(2013, 4, 5, 12, 1, 2)))
    assert(row(1) === Row(LocalDateTime.of(2013, 4, 5, 18, 1, 2, 123000000)))
    assert(row(2) === Row(LocalDateTime.of(2013, 4, 5, 18, 1, 2, 123456000)))
  }

  test("SPARK-43040: timestamp_ntz roundtrip test") {
    val prop = new Properties
    prop.setProperty("preferTimestampNTZ", "true")

    val sparkQuery = """
      |select
      |  timestamp_ntz'2020-12-10 11:22:33' as col0
      """.stripMargin

    val df_expected = sqlContext.sql(sparkQuery)
    df_expected.write.jdbc(jdbcUrl, "timestamp_ntz_roundtrip", prop)

    val df_actual = sqlContext.read.jdbc(jdbcUrl, "timestamp_ntz_roundtrip", prop)
    assert(df_actual.collect()(0) == df_expected.collect()(0))
  }

  test("SPARK-43267: user-defined column in array test") {
    val df = sqlContext.read.jdbc(jdbcUrl, "custom_type", new Properties)
    val row = df.collect()
    assert(row.length === 1)
    assert(row(0).length === 2)
    assert(row(0).getSeq[String](0) == Seq("1", "fds", "fdsa"))
    assert(row(0).getString(1) == "fdasfasdf")
  }

  test("SPARK-44280: infinity timestamp test") {
    val df = sqlContext.read.jdbc(jdbcUrl, "infinity_timestamp", new Properties)
    val row = df.collect()

    assert(row.length == 2)
    val infinity = row(0).getAs[Timestamp]("timestamp_column")
    val negativeInfinity = row(1).getAs[Timestamp]("timestamp_column")
    val minTimeStamp = LocalDateTime.of(1, 1, 1, 0, 0, 0).toEpochSecond(ZoneOffset.UTC)
    val maxTimestamp = LocalDateTime.of(9999, 12, 31, 23, 59, 59).toEpochSecond(ZoneOffset.UTC)

    assert(infinity.getTime == maxTimestamp)
    assert(negativeInfinity.getTime == minTimeStamp)
  }
}
