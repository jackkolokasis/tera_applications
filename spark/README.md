# Spark with TeraHeap

## Build
Before build Spark and Spark-Bench suite you have to move this repository to a
local disk directory (e.g., /opt).

```sh
./build
```

## Spark Configuration
Before start running the experiments you have to setup the configuration in
Spark.

1. Go to spark directory
```sh
cd spark-3.2.1/conf
```
2. Open workers file and replace "localhost" with the node hostname e.g.,
   sith4-fast.

3. Open spark-defaults.conf and replace spark://master:7077 with
   spark://`hostname`:7077.

4. Open spark-env.sh file and setup JAVA_HOME.
