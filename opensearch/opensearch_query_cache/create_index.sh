#!/usr/bin/env bash

## This is for sith5
# ./create_index_new.sh \
#   -w /home1/public/kolokasis/github/latest_version/smartsweep/benchmarks/tera_applications/opensearch/opensearch-benchmark-workloads/cacheable_nyc_taxis \
#   -i nyc_taxis \
#   -t cacheable-queries \
#   -T delete-index,create-index,check-cluster-health,index \
#   -p 100 \
#   -s 1 \
#   -R 0 \
#   -c 8 \
#   -H 127.0.0.1:9200 \
#   -f /home1/public/kolokasis/github/latest_version/smartsweep/benchmarks/tera_applications/opensearch/opensearch-benchmark-workloads/cacheable_nyc_taxis/params.json \
#   -g 23

# This is for sith4
./create_index_new.sh \
  -w /home1/public/kolokasis/github/latest_version/smartsweep/benchmarks/tera_applications/opensearch/query_cache/opensearch-benchmark-workloads-geopoint-nyc-taxis/nyc_taxis \
  -i nyc_taxis \
  -t append-no-conflicts \
  -T delete-index,create-index,check-cluster-health,index \
  -p 100 \
  -s 1 \
  -R 0 \
  -c 8 \
  -C \
  -H sith4:9200 \
  -f /home1/public/kolokasis/github/latest_version/smartsweep/benchmarks/tera_applications/opensearch/query_cache/opensearch-benchmark-workloads-geopoint-nyc-taxis/nyc_taxis/params.json \
  -g 23
