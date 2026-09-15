#!/usr/bin/env bash

# ./run.sh \
#   -n 1 \
#   -o results_onheap \
#   -m onheap \
#   -H 4 \
#   -c 410mb \
#   -M 8G \
#   -f 0.8 \
#   --tp-bbox=30,60,90,120,140 \
#   --search-clients=8 \
#   --warmup-iterations=0 \
#   --iterations=10000 \
#   --randomization-n=200 \
#   --randomization-alpha=0.4

  # --tp-bbox=60,90,120,150,180,210,240,300 \
  # --tp-bbox=     60,   90,  120,  150,  165,  180,  200,  220,  240 \
  # --tp-update=10000,15000,20000,25000,27500,30000,33333,36667,40000
# Native
./run.sh \
  -n 1 \
  -o heap_pressure/results_onheap \
  -m onheap \
  -H 8 \
  -c 307mb \
  -M 16G \
  -f 1.0 \
  --tp-bbox=60,90,150,180,200,240 \
  --tp-update=10000,15000,25000,30000,33333,40000 \
  --search-clients=8 \
  --warmup-iterations=0 \
  --iterations=20000 \
  --randomization-n=200 \
  --randomization-alpha=0.3


# for clients in 3 8 16 32 64; do
#   echo "=== Running with ${clients} clients ==="
#
#   ./run.sh \
#     -n 1 \
#     -o "results_onheap_c${clients}" \
#     -m onheap \
#     -H 4 \
#     -c 410mb \
#     -M 8G \
#     -f 0.8 \
#     --tp-bbox=1200 \
#     --search-clients="${clients}" \
#     --warmup-iterations=0 \
#     --iterations=5000 \
#     --randomization-n=200 \
#     --randomization-alpha=0.4
# done
