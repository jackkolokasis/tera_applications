#!/usr/bin/env bash
###################################################
#
# file: conf.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  18-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Configuration for DaCapo + TeraHeap runs
#
###################################################

# Results directory
RESULT_DIR="/archive/users/kolokasis/smartsweep_results/dacapo"

# TeraHeap repository path
TERAHEAP_REPO="/home1/public/kolokasis/github/latest_version/smartsweep/teraheap"

# JDK path (TeraHeap-patched JVM)
JAVA_HOME="${TERAHEAP_REPO}/jdk17/build/linux-x86_64-server-release/images/jdk"

# GC threads
GC_THREADS=32

# Total heap size (H1 + H2) in GB — TeraHeap mode only
H1_H2_SIZE=900

# G1 heap region size
G1_HEAP_REGION_SZ=4m
REGION_SIZE=$((4 * 1024 * 1024))

# Mount point for H2 memory-mapped file (TeraHeap only)
MNT_H2=/mnt/fmap

# DaCapo benchmark jar (path as seen from run_cgexec.sh's working directory)
DACAPO_JAR="../../../benchmarks/dacapobench/benchmarks/dacapo-evaluation-git-0db32562-dirty.jar"

# Scratch directory for the DaCapo harness's own temp files
DACAPO_SCRATCH_DIR="/mnt/spark"

# Enable TeraHeap statistics (true/false)
ENABLE_STATS=true

# Run mode: "teraheap" or "native" (overridden by --mode flag)
RUN_MODE="teraheap"

# DRAM overhead above H1 heap size in GB
DRAM_OVERHEAD_GB=6

# Cgroup name
CGROUP_NAME="memlim"

# Benchmarks to run (full DaCapo suite)
BENCHMARKS=(
    "h2"
    "batik"
    "graphchi"
    "biojava"
    "cassandra"
    "h2o"
    "tradesoap"
    "avrora"
    "eclipse"
    "fop"
    "jme"
    "jython"
    "kafka"
    "luindex"
    "lusearch"
    "pmd"
    "sunflow"
    "xalan"
    "zxing"
)

# Per-benchmark DaCapo size
declare -A BENCHMARK_SIZE
BENCHMARK_SIZE=(
    ["h2"]="vlarge"
    ["batik"]="large"
    ["graphchi"]="large"
    ["biojava"]="large"
    ["cassandra"]="huge"
    ["h2o"]="huge"
    ["tradesoap"]="huge"
    ["avrora"]="large"
    ["eclipse"]="large"
    ["fop"]="default"     # no "large" size upstream
    ["jme"]="large"
    ["jython"]="large"
    ["kafka"]="large"
    ["luindex"]="large"
    ["lusearch"]="large"
    ["pmd"]="default"     # no "large" size upstream
    ["sunflow"]="large"
    ["xalan"]="large"
    ["zxing"]="default"   # no "large" size upstream
)

# Per-benchmark number of iterations
declare -A BENCHMARK_ITERATIONS
BENCHMARK_ITERATIONS=(
    ["h2"]=2
    ["batik"]=2
    ["graphchi"]=1
    ["biojava"]=1
    ["tradesoap"]=1
    ["cassandra"]=1
    ["h2o"]=1
    ["avrora"]=1
    ["eclipse"]=1
    ["fop"]=1
    ["jme"]=1
    ["jython"]=1
    ["kafka"]=1
    ["luindex"]=1
    ["lusearch"]=1
    ["pmd"]=1
    ["sunflow"]=1
    ["xalan"]=1
    ["zxing"]=1
)

# Per-benchmark minimum heap for native mode (MB)
# Source: GMV for vlarge, GML for large, GMD for default (from stats-nominal.yml)
# Native heap = 2x the upstream minimum (see check.sh for raw GML/GMD values)
declare -A BENCHMARK_NATIVE_HEAP_MB
BENCHMARK_NATIVE_HEAP_MB=(
    ["h2"]=41218        # GMV (vlarge)
    ["batik"]=3518      # 2x GML (large)
    ["graphchi"]=2304   # 2x GML (large)
    ["biojava"]=2058    # 2x GML (large)
    ["cassandra"]=24576
    ["h2o"]=16384
    ["tradesoap"]=32768
    ["avrora"]=30       # 2x GML=15 (large)
    ["eclipse"]=278     # 2x GML=139 (large)
    ["fop"]=26          # 2x GMD=13 (default)
    ["jme"]=58          # 2x GML=29 (large)
    ["jython"]=50       # 2x GML=25 (large)
    ["kafka"]=610       # 2x GML=305 (large)
    ["luindex"]=74      # 2x GML=37 (large)
    ["lusearch"]=178    # 2x GML=89 (large)
    ["pmd"]=378         # 2x GMD=189 (default)
    ["sunflow"]=298     # 2x GML=149 (large)
    ["xalan"]=26        # 2x GML=13 (large)
    ["zxing"]=390       # 2x GMD=195 (default)
)

# Per-benchmark H1 sizes for TeraHeap mode (~70% of native heap, in MB)
declare -A BENCHMARK_H1_SIZES
BENCHMARK_H1_SIZES=(
    ["h2"]="28852"
    ["batik"]="2814"
    ["graphchi"]="1152"
    ["biojava"]="1646"
    ["cassandra"]=19660
    ["h2o"]=9830
    ["tradesoap"]=9830
    ["avrora"]=21
    ["eclipse"]=195
    ["fop"]=18
    ["jme"]=41
    ["jython"]=35
    ["kafka"]=427
    ["luindex"]=52
    ["lusearch"]=125
    ["pmd"]=265
    ["sunflow"]=209
    ["xalan"]=18
    ["zxing"]=273
)

# Per-benchmark H2 file sizes to sweep (space-separated GB values, TeraHeap only)
# Small benchmarks get the 1GB minimum since their footprint barely exceeds H1
declare -A BENCHMARK_H2_FILE_SIZES
BENCHMARK_H2_FILE_SIZES=(
    ["h2"]="36"
    ["batik"]="16"
    ["graphchi"]="4"
    ["biojava"]="4"
    ["cassandra"]="32"
    ["h2o"]="2"
    ["tradesoap"]="2"
    ["avrora"]="1"
    ["eclipse"]="1"
    ["fop"]="1"
    ["jme"]="1"
    ["jython"]="1"
    ["kafka"]="1"
    ["luindex"]="1"
    ["lusearch"]="1"
    ["pmd"]="1"
    ["sunflow"]="1"
    ["xalan"]="1"
    ["zxing"]="1"
)

# Per-benchmark DRAM overhead in GB (default: DRAM_OVERHEAD_GB)
# Override per benchmark here if needed
declare -A BENCHMARK_DRAM_OVERHEAD
BENCHMARK_DRAM_OVERHEAD=(
    ["h2"]=${DRAM_OVERHEAD_GB}
    ["batik"]=${DRAM_OVERHEAD_GB}
    ["graphchi"]=${DRAM_OVERHEAD_GB}
    ["biojava"]=${DRAM_OVERHEAD_GB}
    ["cassandra"]=${DRAM_OVERHEAD_GB}
    ["h2o"]=${DRAM_OVERHEAD_GB}
    ["tradesoap"]=${DRAM_OVERHEAD_GB}
    ["avrora"]=${DRAM_OVERHEAD_GB}
    ["eclipse"]=${DRAM_OVERHEAD_GB}
    ["fop"]=${DRAM_OVERHEAD_GB}
    ["jme"]=${DRAM_OVERHEAD_GB}
    ["jython"]=${DRAM_OVERHEAD_GB}
    ["kafka"]=${DRAM_OVERHEAD_GB}
    ["luindex"]=${DRAM_OVERHEAD_GB}
    ["lusearch"]=${DRAM_OVERHEAD_GB}
    ["pmd"]=${DRAM_OVERHEAD_GB}
    ["sunflow"]=${DRAM_OVERHEAD_GB}
    ["xalan"]=${DRAM_OVERHEAD_GB}
    ["zxing"]=${DRAM_OVERHEAD_GB}
)
