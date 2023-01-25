#!/usr/bin/env bash                                                             

. ./conf.sh

RUN_DIR=$1
SERDES=$2

function timestamp()                                                            
{
    local sec
    local nanosec
    local tmp
    local msec

    sec=$(date +%s)
    nanosec=$(date +%N)

    tmp=$(( sec * 1000 ))
    msec=$(( nanosec / 1000000 ))
    echo $(( tmp + msec ))
}                                                                               

word_to_remove="file:\/\/"
dataset_path="${DATA_HDFS//${word_to_remove}/}"

start_time=$(timestamp)

if [ "$SERDES" ]
then
  "${SPARK_DIR}"/bin/spark-submit \
    --class org.apache.spark.examples.mllib.SparseNaiveBayes \
    --conf spark.executor.instances=1 \
    --conf spark.executor.cores="${EXEC_CORES}" \
    --conf spark.executor.memory="${H1_SIZE}"g \
    --conf spark.kryoserializer.buffer.max=512m \
    --jars "${SPARK_DIR}"/examples/target/scala-2.12/jars/spark-examples_2.12-3.3.0.jar, "${SPARK_DIR}"/examples/target/scala-2.12/jars/scopt_2.12-3.7.1.jar\
    --numPartitions 512 \
    --numFeatures 54686452 \
    "${dataset_path}"/kdd12 \
    "${S_LEVEL}"
else
  "${SPARK_DIR}"/bin/spark-submit \
    --class org.apache.spark.examples.mllib.SparseNaiveBayes \
    --conf spark.executor.instances=1 \
    --conf spark.executor.cores="${EXEC_CORES}" \
    --conf spark.executor.memory="${H1_H2_SIZE}"g \
    --conf spark.kryoserializer.buffer.max=512m \
    --jars "${SPARK_DIR}"/examples/target/scala-2.12/jars/spark-examples_2.12-3.3.0.jar, "${SPARK_DIR}"/examples/target/scala-2.12/jars/scopt_2.12-3.7.1.jar\
    --numPartitions 512 \
    --numFeatures 54686452 \
    "${dataset_path}"/kdd12 \
    "${S_LEVEL}"
fi

end_time=$(timestamp)                                                           

duration=$(echo "scale=6;($end_time-$start_time)/1000" | bc)

echo ",,${duration}" >> "${RUN_DIR}"/total_time.txt
