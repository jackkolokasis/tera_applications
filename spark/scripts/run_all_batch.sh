#!/usr/bin/env bash
./run_batch.sh -t /spare/s1/perpap/teraheap -g amperesudo -m ampere -s ampere -b r -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -e f -j $TERA_JDK17_AARCH64_RELEASE -l asplos_config.sh -w AsyncWritePolicy -c -o -a 2

./run_batch.sh -t /spare/s1/perpap/teraheap -g amperesudo -m ampere -s ampere -b r -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -e f -j $TERA_JDK17_AARCH64_RELEASE -l asplos_config.sh -w AsyncWritePolicy -c -o -a 0

./run_batch.sh -t /spare/s1/perpap/teraheap -g amperesudo -m ampere -s ampere -b r -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -e n -j $TERA_JDK17_AARCH64_RELEASE -l asplos_config.sh -w AsyncWritePolicy -c -o -a 2
