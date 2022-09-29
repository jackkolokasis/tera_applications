# Scripts to Run Spark Benchmarks

## Prerequisites
Setup the following variables in the conf.sh file.

| **Variable**            | **Description**                                                      |
|----------------------	  |-------------------------------------------------------------------   |
| DATA_SIZE               | Select to run with small datasets (up to 2GB) or large datasets      |
| MY_JAVA_HOME            | Path to TeraHeap building directory                                  |
| DATA_HDFS               | Path to the directory with the datasets                              |
| SPARK_VERSION           | It can be "2.3.0" or "3.3.0"                                         |
| NUMBER_OF_PARTITIONS    | Set the number of partitions                                         |
| BENCH_DIR               | Set the path of tera_applications directory                          | 
| SPARK_MASTER            | Set the host of spark master e.g., sith4-fast                        |
| SPARK_SLAVE             | Set the host of spark slave e.g., sith4-fast                         |
| GC_THREADS              | Set the number of GC threads                                         |
| DEV_SHFL                | Set the device for shuffle (e.g., nvme0n1)                           |
| MNT_SHFL                | Set the mount point for shuffle directory                            |
| DEV_H2                  | Set the device for H2                                                |
| MNT_H2                  | Set the mount point for H2 directory                                 |
| H2_FILE_SZ              | Set the size of H2 file                                              |
| EXEC_CORES              | Set the number of executor cores                                     |
| H1_SIZE                 | Set the executor heap size                                           |
| S_LEVEL                 | Set Spark caching storage level (e.g., MEMORY_ONLY, MEMORY_AND_DISK) |
| H1_H2_SIZE              | Set the total heap size of both H1 and H2                            |
| NUM_EXECUTORS           | Number of executors                                                  |

You need to have "sudo" access in the server.

Supported Benchmarks:
| **Benchmarks**         |
|----------------------  |
| PageRank               |
| ConnectedComponents    |
| TriangleCounts         |
| ShortestPaths          |
| SVDPlusPlus            |
| LinearRegression       |
| LogisticRegression     |
| SVM                    |
| SQL                    |

## Generate Datasets
Before run a specific benchmark you have to generate a dataset. This
dataset will be used as an input file for the specific benchmark.
```
./gen_dataset.sh
```
In case of SQL workload you have to run also the following script to
increase the dataset size.
```sh
./sql_gen_data.sh

```

## Run experiments with enable TeraHeap
```sh
./run.sh -n 1 -o <path/to/result/directory> -t
```
## Run experiments with native (serialization/deserialization)
```sh
./run.sh -n 1 -o <path/to/result/directory> -s
```

## Kill all background processes
```sh
./run.sh -k 
```

## Other options
```sh
./run.sh -h
```

## Change JVM Option Flags
If you want to add/remove jvm flags for Spark executor please edit the
spark-defaults.conf files under ./configs/native and
./configs/teraheap

## Reduction of Memory for Out of Core Experiments
Scripts reduce memory using Cgroups. You need to set in conf.sh 
```sh
# cgset accepts K,M,G and KiB, MiB, GiB units for memory limit
MEM_BUDGET=
```
Edit spark-3.3.0/bin/spark-class file:

```sh
# Replace line: exec "${CMD[@]}"
cgexec -g memory:memlim --sticky "${CMD[@]}"
```

\Edit spark-3.3.0/bin/spark-submit file:
```sh
# Replace line: 
exec "${SPARK_HOME}"/bin/spark-class org.apache.spark.deploy.SparkSubmit "$@"
# with
cgexec -g memory:memlim --sticky "${SPARK_HOME}"/bin/spark-class org.apache.spark.deploy.SparkSubmit "$@"

```

