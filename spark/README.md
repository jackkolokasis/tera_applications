# Running Spark with TeraHeap

## Build
Build Spark and Spark-Bench suite you have to move this
repository to a local disk directory (e.g., /opt).

Setup configuration file config.sh by setting the following variables
as shown in the table below.

| **Parameters** 	|                   **Description**                   	|
|:--------------:	|:---------------------------------------------------:	|
| JAVA_HOME      	| Locate the build directory of the JVM with HugeHeap 	|
| TERA_APPS_REPO 	| Path to the repository of tera_applications         	|
| SPARK_VERSION 	| Set "spark-3.3.0" or "spark-2.3.0"                    |

### Build Spark and SparkBench suite
```sh
./build -a
```
### Build only Spark
```sh
./build -s
```
### Build only SparkBench suite
```sh
./build -b
```
### Clean All
```sh
./build -c

```
## Run Benchmarks
To run benchmarks with Spark go to the scripts repository and read the
README file. 
