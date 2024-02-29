#!/usr/bin/env bash

# Backup original conf.sh to restore later
cp conf.sh conf.sh.backup

BENCHMARKS=( ConnectedComponent LinearRegression LogisticRegression PageRank )
EXEC_CORES=8
GC_THREADS=5
#H1_SIZE=64
sed -i "s/^EXEC_CORES=(.*)/EXEC_CORES=( $EXEC_CORES )/" conf.sh
sed -i "s/^GC_THREADS=.*/GC_THREADS=$GC_THREADS/" conf.sh
sed -i "s/^H1_SIZE=(.*)/H1_SIZE=( 160 )/" conf.sh
sed -i "s/^MEM_BUDGET=.*/MEM_BUDGET=200G/" conf.sh
sed -i "s/^S_LEVEL=(.*)/S_LEVEL=( \"MEMORY_ONLY\" )/" conf.sh

for BENCHMARK in "${BENCHMARKS[@]}"; do
    sed -i "s/^BENCHMARKS=(.*)/BENCHMARKS=( \"$BENCHMARK\" )/" conf.sh
    echo "Checking for dataset $MOUNT_POINT_BENCHMARK_DATASETS/SparkBench/$BENCHMARK"

    if [[ -d "$MOUNT_POINT_BENCHMARK_DATASETS/SparkBench/$BENCHMARK" ]]; then
      echo "$BENCHMARK dataset has already been generated."
    else
      echo "Generating $BENCHMARK dataset..."
      ./gen_dataset.sh
    fi
done

# Restore the original conf.sh to leave no side effects
cp conf.sh.backup conf.sh
rm conf.sh.backup
