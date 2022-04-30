# Benchmark Suite for Apache Spark #

- Current version: 2.0
- Release date: 2015-5-10

- Contents:

  1. Overview
  2. Getting Started
  3. Advanced Configuration
  4. Possible Issues

---
### OVERVIEW ###

**What's Benchmark Suite for Apache Spark ?**

Spark-Bench is a benchmarking suite specific for Apache Spark.
It comprises a representative and comprehensive set of workloads belonging to four different application types that currently supported by Apache Spark, including machine learning, graph processing, streaming and SQL queries.

The chosen workloads exhibit different workload characteristics and exercise different system bottlenecks; currently we cover CPU, memory, and shuffle and IO intensive workloads.

It also includes a data generator that allows users to generate arbitrary size of input data.

**Why the Benchmark Suite for Apache Spark ?**

While Apache Spark has been evolving rapidly, the community lacks a comprehensive benchmarking suite specifically tailored for Apache Spark. The purpose of such a suite is to help users to understand the trade-off between different system designs, guide the configuration optimization and cluster provisioning for Apache Spark deployments. In particular, there are four main use cases of Spark-Bench.
	
Usecase 1. It enables quantitative comparison for Apache Spark system optimizations such as caching policy and memory management optimization, scheduling policy optimization. Researchers and developers can use Spark-Bench to comprehensively evaluate and compare the performance of their optimization and the vanilla Apache Spark. 
	
Usecase 2. It provides quantitative comparison for different platforms and hardware cluster setups such as Google cloud and Amazon cloud. 
	
Usecase 3. It offers insights and guidance for cluster sizing and provision. It also helps to identify the bottleneck resources and minimize the impact of resource contention.
	
Usecase 4. It allows in-depth study of performance implication of Apache Spark system in various aspects including workload characterization, the study of parameter impact, scalability and fault tolerance behavior of Apache Spark system.
	
**Machine Learning Workloads:**

- Logistic Regression
- Support Vector Machine
- Matrix Factorization

**Graph Computation Workloads:**

- PageRank
- SVD++
- Triangle Count

**SQL Workloads:**

- Hive
- RDD Relation

**Streaming Workloads:**

- Twitter Tag
- Page View

**Other Workloads:**

- KMeans, LinearRegression, DecisionTree, ShortestPaths, LabelPropagation, ConnectedComponent, StronglyConnectedComponent, PregelOperation

**Supported Apache Spark releases:**
 
  - Spark 2.0.1, this code is branched for release 2.0.1, note that these versions need a later version of scala and as such there are changes to pom files. 
 
---
### Getting Started ###

1. System setup and compilation.

	Setup JDK, Apache Hadoop-YARN, Apache Spark runtime environment properly.
	
	Download  wikixmlj package:
	cd to a directory for download and type the next commands
	```
		git clone https://github.com/synhershko/wikixmlj.git
		cd wikixmlj
		mvn package install
	```
	Download/checkout Spark-Bench benchmark suite

	Run `<SPARK_BENCH_HOME>/bin/build-all.sh` to build Spark-Bench.
	
	Copy `<SparkBench_Root>/conf/env.sh.template` to `<SparkBench_Root>/conf/env.sh`, and set it according to your cluster.
	
2. Spark-Bench Configurations.
	
	Make sure below variables has been set:
	
	SPARK_HOME    The Spark installation location  
	HADOOP_HOME   The HADOOP installation location  
	SPARK_MASTER  Spark master  
	HDFS_MASTER	  HDFS master  

    Local mode:         
            `DATA_HDFS="file:///home/`whoami`/SparkBench"`
            `SPARK_MASTER=local[2]`
            `MC_List=""`


3. Execute.

    **Scala version:**
    
	`<SPARK_BENCH_HOME>/<Workload>/bin/gen_data.sh`  
	`<SPARK_BENCH_HOME>/<Workload>/bin/run.sh`
	
    **Java version:**
    
	`<SparkBench_Root>/<Workload>/bin/gen_data_java.sh`  
	`<SparkBench_Root>/<Workload>/bin/run_java.sh`	
	
	**Note for SQL applications**
	
	For SQL applications, by default it runs the RDDRelation workload.
	To run Hive workload, execute `<SPARK_BENCH_HOME>/SQL/bin/run.sh hive`;
	
	**Note for streaming applications**
	For Streaming applications such as TwitterTag,StreamingLogisticRegression
	First, execute `<SPARK_BENCH_HOME>/Streaming/bin/gen_data.sh` in one terminal;
	Second, execute `<SPARK_BENCH_HOME>/Streaming/bin/run.sh` in another terminal;

        In order run a particular streaming app (default: PageViewStream):
            You need to pass a subApp parameter to the gen_data.sh or run.sh like this:
                  <SPARK_BENCH_HOME>/Streaming/bin/run.sh TwitterPopularTags
            *Note: some subApps do not need the data_gen step. In those you will get a "no need" string in the output.

        You can make a certain subApp default by changing Streaming/conf/env.sh and changing the subApp= line with your choice of the streaming application.
	
    In addition, StreamingLogisticRegression requires the `gen_data.sh` and `run.sh` scripts which
	launches Apache Spark applications can run simultaneously.
4. View the result.

	Goto `<SPARK_BENCH_HOME>/report` to check for the final report.

---
### Advanced Configurations ###

1. Enviroment 
    To configure the enviroment for the Spark-Bench suite make
    additional changes to the following file:
        bin/env.sh
		`<Workloads>/bin/env.sh`



1. Configuration for running workloads.

	The `<SPARK_BENCH_HOME>/bin/applications.lst` file defines the workloads to
	run when you execute the bin/run-all.sh script under the package folder.
	Each line in the list file specifies one workload. You can use # at the
	beginning of each line to skip the corresponding bench if necessary.

	You can also run each workload separately. In general, there are 3 different
	files under one workload folder.

	`<Workload>/bin/config.sh`      change the workload specific configurations  
	`<Workload>/bin/gen_data.sh`  
	`<Workload>/bin/run.sh`  

2. Apache Spark configuration.

	spark.executors.memory                Executor memory, standalone or YARN mode
	spark.driver.memory                   Driver memory, standalone or YARN mode
	spark.rdd.cache

3. New configuration parameters
	To support new configuration parameters for the spark just add new functions
	in the following file:
        bin/funcs.sh

### Run Workload
1. Generate Datasets
```sh
	`./<Workload>/bin/gendata.sh`
```

2. Run Benchmarks
```sh
	`./<Benchmark>/bin/run.sh`
```

### Executors Profiling :
## Setup
1. Download and install InfluxDB
(https://influxdata.com/downloads/#influxdb)

2. Run InfluxDB
```sh
sudo service influxdb start

#Access the DB using either the web UI
#(http://localhost:8083/) or shell:

/user/bin/influx
```

3. Create a database to store the stack traces in:
```sh
CREATE DATABASE profiler
```

4. Create a user:

```sh
CREATE USER profiler WITH PASSWORD ‘profiler’ WITH ALL PRIVILEGES
```

5. Build/download statsd-jvm-profiler jar (https://github.com/etsy/statsd-jvm-profiler)

Deploy the jar to the machines which are running the executor processes. One way
to do this is to using spark-submit’s –jars attribute, which will deploy it to
the executor.

--jars /path/to/statsd-jvm-profiler-2.1.0-jar-with-dependencies.jar

Specify the Java agent in your executor processes. This
can be done, for example, by using spark-submit’s –conf
attribute

-javaagent:statsd-jvm-profiler-2.1.0-jar-with-dependencies.jar=server=<INFLUX_DB_HOST>,port=<INFLUX_DB_PORT>,reporter=InfluxDBReporter,database=<INFLUX_DB_DATABASE_NAME>,username=<INFLUX_DB_USERNAME>,password=<INFLUX_DB_PASSWORD>,prefix=<TAG_VALUE_1>.<TAG_VALUE_2>.….<TAG_VALUE_N>,tagMapping=<TAG_NAME_1>.<TAG_NAME_2>.….<TAG_NAME_N>

6. Download influxdb_dump.py
https://github.com/aviemzur/statsd-jvm-profiler/blob/master/visualization/influxdb_dump.py

Install all required python modules that influxdb_dump.py imports.

Run influxdb_dump.py to create text files with stack
traces as input for flame graphs:

python influxdb_dump.py -o "<INFLUX_DB_HOST>" -u
<INFLUX_DB_USERNAME> -p <INFLUX_DB_PASSWORD> -d
<INFLUX_DB_DATABASE_NAME> -t <TAGS> -e <VALUES> -x "<OUTPUT_DIR>"

7. Download flamegraph.pl
https://github.com/brendangregg/FlameGraph/blob/master/flamegraph.pl

Generate flame graphs using the text files you dumped from
DB:

flamegraph.pl <INPUT_FILES> > <OUTPUT_FILES>
