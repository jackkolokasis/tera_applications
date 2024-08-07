#!/usr/bin/env bash

###################################################
#
# file: download_real_dataset.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  19-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Download dataset, build the index, and
# generate queries 
#
###################################################

. ./config.sh

# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ "$1" -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]"
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]"
    fi
}

# Downlaod the real world dataset using the croweler
download_dataset() {
  local storage_folder=$(pwd)
  local processed_dir=$(pwd)/processed

  mkdir -p ${processed_dir}

  python crowler.py \
    -s $storage_folder \
    -p $processed_dir 
}

# Create the Lucene index
create_index() {
  local processed_dir=$(pwd)/processed

  cd $processed_dir || exit
  # Concantenate all corpus into one file
  cat corpus* > ../all_corpus.txt
  cd - > /dev/null || exit

  cd ${BENCH_DIR}/lucene/benchmarks || exit

  local lucene_classpath_jars=$(grep '^CLASSPATH *:=' Makefile | awk -F ':=' '{print $2}' | sed 's/^ *//;s/ *$//')
	java -cp ${lucene_classpath_jars} -Xmx100g src/IndexFiles.java -a st -i ${DATASET} -d ${processed_dir}/../all_corpus.txt
  cd - > /dev/null || exit
}

# Function to process each chunk
process_chunk() {
    local chunk_file=$1
    tr -cs '[:alnum:]' '[\n*]' < "$chunk_file" | tr '[:upper:]' '[:lower:]' | sort | uniq -c
}

# Create the terms for the queries generation
create_terms() {
  local word_count_file="word_count.txt"
  local processed_dir=$(pwd)/processed
  local terms_dir=$(pwd)/terms
  local tmp_dir=$(pwd)/tmpdir

  mkdir -p "${terms_dir}"
  mkdir -p "${tmp_dir}"

  local num_threads=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

  export -f process_chunk

  # Step 2: Process chunks in parallel to count word frequencies
  echo "Processing chunks in parallel..."
  parallel --tmpdir ./tmpdir process_chunk ::: "${processed_dir}/corpus"* > "$word_count_file.tmp"

  # Step 3: Merge and sort word counts
  echo "Merging and sorting word counts..."
  cat "$word_count_file.tmp" | awk '{count[$2] += $1} END {for (word in count) print count[word], word}' | sort -nr > "$word_count_file"
  rm "$word_count_file.tmp"

  # Step 4: Clean from a file stop-words and non-english words
  ./remove_stop_word.py
  
  # Step 5: Create HIGHT, MIDT, and LOWT queries
  local high_freq_threshold=2488844
  local low_freq_threshold=44620
  local high_freq_file="${terms_dir}/HIGHT"
  local medium_freq_file="${terms_dir}/MEDT"
  local low_freq_file="${terms_dir}/LOWT"

  # Step 6: Categorize words based on frequency based on the
  # clean_word_count.txt
  echo "Categorizing words into high, medium, and low frequency..."
  awk -v high="$high_freq_threshold" \
    -v low="$low_freq_threshold" \
    '
    {
      if ($1 >= high) {
        print $2 > "'"$high_freq_file"'"
      } else if ($1 <= low) {
      print $2 > "'"$low_freq_file"'"
      } else {
      print $2 > "'"$medium_freq_file"'"
    }
  }
  ' cleaned_word_counts.txt

  # Copy folder terms to the benchmarks
  cp ${terms_dir} ../benchmarks/query-workload/
}

# Create a list of single and double terms queries
create_queries() {
  local queries_dir="$(pwd)/queries"
  local num_threads=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

  cd ${BENCH_DIR}/lucene/benchmarks/query-workload/terms || exit
  split -b 60k LOWT LOWT_PART_
  split -b 60k MEDT MEDT_PART_
  cd - > /dev/null

  cd ${BENCH_DIR}/lucene/benchmarks/query-workload  || exit
  ./query_gen_multicore.sh H 1 ${num_threads} 1250 > ${queries_dir}/H_40k
  ./query_gen_multicore.sh HH 2 ${num_threads} 1250 > ${queries_dir}/HH_40k
  ./query_gen_multicore.sh M 1 ${num_threads} 1250 > ${queries_dir}/M_40k
  ./query_gen_multicore.sh MM 2 ${num_threads} 1250 > ${queries_dir}/MM_40k
  ./query_gen_multicore.sh L 1 ${num_threads} 1250 > ${queries_dir}/L_40k
  ./query_gen_multicore.sh LL 2 ${num_threads} 1250 > ${queries_dir}/LL_40k
  cd - > /dev/null
}

# Create the queries for the Lucene workloads
create_queries_for_workloads() {
  local queries_dir="$(pwd)/queries"

  head -n 200 ${queries_dir}/H_40k > ${QUERIES_DIR}/HL
  head -n 200 ${queries_dir}/HH_40k >> ${QUERIES_DIR}/HL

  head -n 25000 ${queries_dir}/H_40k > ${QUERIES_DIR}/HS
  head -n 25000 ${queries_dir}/HH_40k >> ${QUERIES_DIR}/HS

  head -n 3500 ${queries_dir}/M_40k > ${QUERIES_DIR}/ML
  head -n 3500 ${queries_dir}/MM_40k >> ${QUERIES_DIR}/ML
  
  head -n 40000 ${queries_dir}/M_40k > ${QUERIES_DIR}/MS
  head -n 40000 ${queries_dir}/MM_40k >> ${QUERIES_DIR}/MS
  
  for ((i=0; i<6; i++))
  do
    head -n 40000 ${queries_dir}/L_40k >> ${QUERIES_DIR}/LS
    head -n 40000 ${queries_dir}/LL_40k >> ${QUERIES_DIR}/LS
  done

  head -n 10000 ${queries_dir}/L_40k >> ${QUERIES_DIR}/LS
  head -n 10000 ${queries_dir}/LL_40k >> ${QUERIES_DIR}/LS

  cat HS ML LS HL MS > HS_ML_LS_HL_MS
  cat HS HL > HS_HL
  cat MS ML > MS_ML
  cat ML HL > ML_HL
}

download_dataset
create_index
create_terms
create_queries
create_queries_for_workloads
