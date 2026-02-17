#!/usr/bin/env bash
./run_batch.sh -t /spare/s0/perpap/teraheap -g amperesudo -m ampere -s ampere -f /spare/s0/perpap/fmap -p /spare/s0/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s2/perpap/spark_results -e teraheap_g1 -j /spare/s0/perpap/teraheap/jdk17/build/linux-aarch64-server-release/jdk -t 1024 -w AsyncWritePolicy -l asplos_config.sh -c -o

./run_batch.sh -t /spare/s0/perpap/teraheap -g amperesudo -m ampere -s ampere -f /spare/s0/perpap/fmap -p /spare/s0/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s2/perpap/spark_results -e native_g1 -j /spare/s0/perpap/teraheap/jdk17/build/linux-aarch64-server-release/jdk -t 1024 -w AsyncWritePolicy -l asplos_config.sh -c -o

./run_batch.sh -t /spare/s0/perpap/teraheap -g amperesudo -m ampere -s ampere -f /spare/s0/perpap/fmap -p /spare/s0/perpap/spark -d /spare/s1/perpap/datasets_256 -r /spare/s2/perpap/spark_results -e teraheap_g1 -j /spare/s0/perpap/teraheap/jdk17/build/linux-aarch64-server-release/jdk -t 256 -w AsyncWritePolicy -l asplos_config.sh -c -o

./run_batch.sh -t /spare/s0/perpap/teraheap -g amperesudo -m ampere -s ampere -f /spare/s0/perpap/fmap -p /spare/s0/perpap/spark -d /spare/s1/perpap/datasets_256 -r /spare/s2/perpap/spark_results -e native_g1 -j /spare/s0/perpap/teraheap/jdk17/build/linux-aarch64-server-release/jdk -t 256 -w AsyncWritePolicy -l asplos_config.sh -c -o
