#!/usr/bin/env bash

# vanilla teraheap
  # --tp-bbox=     60,   90,  120,  150,  165,  180,  200,  220,  240 \
  # --tp-update=10000,15000,20000,25000,27500,30000,33333,36667,40000
./run.sh \
  -n 1 \
  -o heap_pressure/results_chipper \
  -m teraheap \
  -H 8 \
  -c 65536mb \
  -M 16G \
  -f 1.0 \
  --tp-bbox=200 \
  --tp-update=33333 \
  --search-clients=8 \
  --warmup-iterations=0 \
  --iterations=20000 \
  --randomization-n=200 \
  --randomization-alpha=0.3
