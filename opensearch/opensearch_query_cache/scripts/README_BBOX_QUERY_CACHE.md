# bbox / Lucene query-cache harness

This version of the scripts targets:

- repository checkout: `opensearch-benchmark-workloads-geopoint-nyc-taxis`
- workload: `nyc_taxis`
- test procedure: `append-no-conflicts`
- task: **`bbox` only**

The benchmark command uses `--include-tasks=bbox`, so the delete-index,
create-index, indexing, refresh, force-merge, and merge-wait tasks in the full
test procedure do **not** execute. The `nyc_taxis` index must therefore already
exist before running these scripts.

The bbox workload uses OpenSearch Benchmark query randomization. The runner
always enables it and passes:

- `--randomization-enabled`
- `--randomization-repeat-frequency=<rf>` from `run.sh -f`
- `--randomization-n` (default 5000)
- `--randomization-alpha` (default 1.0)

The harness is configured for the Lucene query cache:

- `indices.queries.cache.size` is controlled by `run.sh -c`.
- `index.queries.cache.enabled` is forced to `true`.
- `index.requests.cache.enable` is forced to `false` so `size:0` bbox requests
  cannot be served by the request cache.
- query-cache statistics are captured before and after every load point.

## Example

```bash
./run.sh \
  -n 1 \
  -o bbox_eval \
  -m onheap \
  -H 4 \
  -c 512mb \
  -M 8G \
  -f 0.3,0.5,0.7 \
  --tp-bbox 3,6,12,24 \
  --search-clients 1
```

The branch defaults are retained unless overridden: 50 warmup iterations,
100 measured iterations, target throughput 3 ops/s, and one search client.

`offheap` is intentionally disabled here because the old mode configures the
pluggable request-cache disk tier and does not represent the Lucene query cache.
