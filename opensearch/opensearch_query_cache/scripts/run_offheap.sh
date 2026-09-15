#!/usr/bin/env bash

echo "run_offheap.sh is intentionally disabled for this bbox/query-cache harness." >&2
echo "The old offheap mode configures OpenSearch's pluggable REQUEST cache, not Lucene's QUERY cache." >&2
exit 1
