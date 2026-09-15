#!/usr/bin/env bash
#
# create_index.sh -- load a workload's index and leave it in a state where the
# request cache can be measured.
#
# Runs only the indexing tasks of the chosen test procedure (delete-index,
# create-index, check-cluster-health, index-append), refreshes, freezes the
# refresh interval, verifies both caches are enabled, and probes the size of a
# single cache entry.
#
# This is destructive: the procedure deletes and recreates the index.
#
# Usage:
#   ./create_index.sh                          # defaults below
#   ./create_index.sh -p 30 -s 1               # 30% of the corpus, 1 shard
#   ./create_index.sh -w /path/to/nyc_taxis -i nyc_taxis -t append-no-conflicts-index-only
#   ./create_index.sh -n                       # dry run
#
set -euo pipefail

export BENCHMARK_HOME="${BENCHMARK_HOME:-/mnt/spark/benchmark-home}"

# ----------------------------------------------------------------- defaults
WORKLOADS_ROOT="${WORKLOADS_ROOT:-/home1/public/kolokasis/github/latest_version/smartsweep/benchmarks/tera_applications/opensearch/query_cache/opensearch-benchmark-workloads-geopoint-nyc-taxis}"

WORKLOAD="${WORKLOAD:-nyc_taxis}"
WORKLOAD_PATH=""
INDEX=""
TARGET_HOST="${TARGET_HOST:-127.0.0.1:9200}"
PARAMS_FILE=""
TEST_PROCEDURE="${TEST_PROCEDURE:-'append-no-conflicts'}"

# Only the indexing half of the procedure. Everything after index-append
# (refresh, force-merge, the query tasks) is skipped: force-merge to one segment
# would cost as much free space again as the index occupies, and it disables
# concurrent segment search, which is the thing that made queries fast enough to
# benchmark in the first place.
INCLUDE_TASKS="${INCLUDE_TASKS:-delete-index,create-index,check-cluster-health,index-append}"

INGEST_PERCENTAGE="${INGEST_PERCENTAGE:-100}"
NUMBER_OF_SHARDS="${NUMBER_OF_SHARDS:-1}"
NUMBER_OF_REPLICAS="${NUMBER_OF_REPLICAS:-0}"
BULK_CLIENTS="${BULK_CLIENTS:-8}"

# Both default to true in OpenSearch. nyc_taxis is the odd one out: its
# index.json explicitly sets them false, which is why they have to be passed as
# workload params rather than left alone.
REQUESTS_CACHE=true
QUERY_CACHE=true

# Uncompressed corpus size in GB, used only for the disk warning.
CORPUS_GB="${CORPUS_GB:-100}"

DRY_RUN=false

log()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m[warn] %s\033[0m\n' "$*"; }
die()  { printf '\033[31m[fail] %s\033[0m\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" == "true" ]; then printf '\033[33m  would run:\033[0m %s\n' "$*"; else "$@"; fi; }

usage() {
    cat <<USAGE

Usage: $0 [options]

  -w <name|path>  Workload name under WORKLOADS_ROOT, or an absolute path
                  (default: ${WORKLOAD})
  -i <index>      Index name to verify and probe (default: same as workload)
  -t <procedure>  Test procedure to draw the indexing tasks from
                  (default: ${TEST_PROCEDURE})
  -T <tasks>      Comma-separated tasks to include
                  (default: ${INCLUDE_TASKS})
  -p <pct>        Ingest percentage 1-100 (default: ${INGEST_PERCENTAGE})
  -s <n>          number_of_shards (default: ${NUMBER_OF_SHARDS})
  -R <n>          number_of_replicas (default: ${NUMBER_OF_REPLICAS})
  -c <n>          bulk_indexing_clients (default: ${BULK_CLIENTS})
  -H <host:port>  Target host (default: ${TARGET_HOST})
  -f <file>       params.json path (default: <workload path>/params.json)
  -Q              Disable the query cache (default: enabled)
  -C              Disable the request cache (default: enabled)
  -g <gb>         Uncompressed corpus size for the disk check (default: ${CORPUS_GB})
  -n              Dry run
  -h              This help

Note on shards: the request cache is PER SHARD, so N shards split each logical
query into N entries of 1/N the size. Use 1 shard unless you specifically want
to study sharded behaviour -- it keeps entries large, which is the whole point.

USAGE
    exit 1
}

while getopts ":w:i:t:T:p:s:R:c:H:f:g:QCnh" opt; do
    case "$opt" in
        w) WORKLOAD=$OPTARG          ;;
        i) INDEX=$OPTARG             ;;
        t) TEST_PROCEDURE=$OPTARG    ;;
        T) INCLUDE_TASKS=$OPTARG     ;;
        p) INGEST_PERCENTAGE=$OPTARG ;;
        s) NUMBER_OF_SHARDS=$OPTARG  ;;
        R) NUMBER_OF_REPLICAS=$OPTARG;;
        c) BULK_CLIENTS=$OPTARG      ;;
        H) TARGET_HOST=$OPTARG       ;;
        f) PARAMS_FILE=$OPTARG       ;;
        g) CORPUS_GB=$OPTARG         ;;
        Q) QUERY_CACHE=false         ;;
        C) REQUESTS_CACHE=false      ;;
        n) DRY_RUN=true              ;;
        h) usage                     ;;
        *) usage                     ;;
    esac
done

# Resolve workload name vs path.
if [[ "$WORKLOAD" == /* ]]; then
    WORKLOAD_PATH="$WORKLOAD"
    WORKLOAD="$(basename "$WORKLOAD_PATH")"
else
    WORKLOAD_PATH="${WORKLOADS_ROOT}/${WORKLOAD}"
fi
INDEX="${INDEX:-$WORKLOAD}"
PARAMS_FILE="${PARAMS_FILE:-${WORKLOAD_PATH}/params.json}"

# ------------------------------------------------------------ preflight
log "Preflight"

command -v opensearch-benchmark >/dev/null || die "opensearch-benchmark not on PATH (activate the venv?)"
command -v jq >/dev/null || warn "jq not found -- falling back to grep parsing"

[[ -d "$WORKLOAD_PATH" ]] || die "workload path not found: $WORKLOAD_PATH"

# workload.py is optional: many workloads have none, and OSB only needs it for
# custom runners and query randomization.
if [[ -f "$WORKLOAD_PATH/workload.py" ]]; then
    n_reg=$(grep -c '^def register' "$WORKLOAD_PATH/workload.py" || true)
    [[ "$n_reg" == "1" ]] || die "workload.py has $n_reg register() definitions, expected 1"
    python3 -c "import ast; ast.parse(open('$WORKLOAD_PATH/workload.py').read())" \
        || die "workload.py does not parse"
    if grep -q 'register_standard_value_source' "$WORKLOAD_PATH/workload.py"; then
        n_src=$(grep -c 'register_standard_value_source' "$WORKLOAD_PATH/workload.py")
        echo "  workload.py: ${n_src} standard value source(s) -- query randomization available"
    else
        warn "workload.py registers no standard value sources."
        warn "--randomization-enabled will do nothing: every operation issues one fixed"
        warn "query, so the cache holds one entry per operation and can never fill."
    fi
else
    warn "no workload.py -- query randomization is unavailable for this workload"
fi

curl -sf "http://${TARGET_HOST}" >/dev/null || die "no OpenSearch at ${TARGET_HOST}"

# ------------------------------------------------------------ params.json
# Always regenerated. A stale params.json silently carrying the previous
# workload's variables is hard to notice and invalidates everything after it.
log "Writing ${PARAMS_FILE}"
if [ "$DRY_RUN" != "true" ]; then
    mkdir -p "$(dirname "$PARAMS_FILE")"
    cat > "$PARAMS_FILE" <<JSON
{
  "number_of_shards": ${NUMBER_OF_SHARDS},
  "number_of_replicas": ${NUMBER_OF_REPLICAS},
  "requests_cache_enabled": ${REQUESTS_CACHE},
  "query_cache_enabled": ${QUERY_CACHE},
  "ingest_percentage": ${INGEST_PERCENTAGE},
  "bulk_indexing_clients": ${BULK_CLIENTS}
}
JSON
fi
[ -f "$PARAMS_FILE" ] && cat "$PARAMS_FILE"

# Report which of these the workload's index.json actually consumes. Unused
# params are ignored silently by OSB, so without this check you can spend a load
# believing a setting applied when it never reached the template.
if [[ -f "$WORKLOAD_PATH/index.json" ]]; then
    echo
    echo "  index.json template variables:"
    for v in number_of_shards number_of_replicas requests_cache_enabled query_cache_enabled; do
        if grep -q "$v" "$WORKLOAD_PATH/index.json"; then
            echo "    ${v}: used"
        else
            echo "    ${v}: NOT used by this workload (relies on the OpenSearch default)"
        fi
    done
fi

if [ "$NUMBER_OF_SHARDS" -gt 1 ]; then
    warn "${NUMBER_OF_SHARDS} shards: the request cache is per shard, so each logical"
    warn "query becomes ${NUMBER_OF_SHARDS} entries of roughly 1/${NUMBER_OF_SHARDS} the size."
fi

# ------------------------------------------------------------ disk check
avail_gb=$(df -BG --output=avail /mnt/spark 2>/dev/null | tail -1 | tr -dc '0-9' || echo 0)
est_gb=$(( CORPUS_GB * INGEST_PERCENTAGE / 100 ))
log "Disk: ${avail_gb}GB available; corpus at ${INGEST_PERCENTAGE}% is about ${est_gb}GB uncompressed"
if (( avail_gb > 0 && avail_gb < est_gb )); then
    warn "not enough space for the corpus alone -- lower -p"
fi

# ------------------------------------------------------------ load
log "Loading '${INDEX}' (procedure ${TEST_PROCEDURE}, tasks: ${INCLUDE_TASKS})"
echo "This DELETES and recreates '${INDEX}'. Ctrl-C within 10s to abort."
[ "$DRY_RUN" == "true" ] || sleep 10

start=$(date +%s)
run opensearch-benchmark run \
    --workload-path="$WORKLOAD_PATH" \
    --target-hosts="$TARGET_HOST" \
    --pipeline=benchmark-only \
    --test-procedure="$TEST_PROCEDURE" \
    --include-tasks="$INCLUDE_TASKS" \
    --workload-params="$PARAMS_FILE" \
    --on-error=abort \
    --kill-running-processes
elapsed=$(( $(date +%s) - start ))
log "Load finished in $(( elapsed / 60 ))m $(( elapsed % 60 ))s"

[ "$DRY_RUN" == "true" ] && { log "Dry run complete"; exit 0; }

# Make everything searchable: the indexing tasks stop at index-append, and
# without an explicit refresh the most recent documents are not yet visible.
log "Refreshing"
curl -s -X POST "http://${TARGET_HOST}/${INDEX}/_refresh" >/dev/null && echo "  done"

# ------------------------------------------------- verify the caches
log "Verifying index settings"
settings=$(curl -s "http://${TARGET_HOST}/${INDEX}/_settings?flat_settings=true&include_defaults=true")
echo "$settings" | tr ',' '\n' \
    | grep -E 'requests\.cache|queries\.cache|number_of_shards|refresh_interval' \
    | sed 's/^/  /' || true

# index.requests.cache.enable is DYNAMIC, so it can be corrected in place.
if ! echo "$settings" | grep -q '"index.requests.cache.enable":"true"'; then
    if [ "$REQUESTS_CACHE" == "true" ]; then
        warn "request cache is disabled -- enabling it now (this setting is dynamic)"
        curl -s -X PUT "http://${TARGET_HOST}/${INDEX}/_settings" \
            -H 'Content-Type: application/json' \
            -d '{"index.requests.cache.enable": true}' >/dev/null && echo "  enabled"
    fi
fi

# index.queries.cache.enabled is STATIC: it is fixed at index creation and
# cannot be changed without reindexing. If it came out wrong, the load has to be
# repeated, so fail loudly rather than measure against the wrong configuration.
if echo "$settings" | grep -q '"index.queries.cache.enabled":"false"'; then
    if [ "$QUERY_CACHE" == "true" ]; then
        die "query cache is DISABLED and that setting is static -- it cannot be
     changed after index creation. Check that index.json consumes
     query_cache_enabled, then re-run the load."
    fi
fi

# Without this the request cache is invalidated at every refresh.
log "Freezing refresh interval"
curl -s -X PUT "http://${TARGET_HOST}/${INDEX}/_settings" \
    -H 'Content-Type: application/json' \
    -d '{"index.refresh_interval": -1}' >/dev/null && echo "  refresh_interval = -1"

# ------------------------------------------------------ probe entry size
# Shaped like big5's date_histogram_minute_agg: minute buckets over a two-day
# window, which is the largest cacheable response in that workload. Override
# PROBE_QUERY for a different workload.
log "Probing cache entry size"
curl -s -X POST "http://${TARGET_HOST}/${INDEX}/_cache/clear?request=true" >/dev/null

PROBE_QUERY="${PROBE_QUERY:-}"
if [ -z "$PROBE_QUERY" ]; then
    PROBE_QUERY='{
      "size": 0,
      "query": {"range": {"@timestamp": {"gte": "2023-01-01T00:00:00", "lt": "2023-01-03T00:00:00"}}},
      "aggs": {"by_minute": {"date_histogram": {"field": "@timestamp", "calendar_interval": "minute"}}}
    }'
fi

probe_out=$(curl -s "http://${TARGET_HOST}/${INDEX}/_search?request_cache=true" \
    -H 'Content-Type: application/json' -d "$PROBE_QUERY")

if echo "$probe_out" | grep -q '"error"'; then
    warn "probe query failed -- the fields may not exist in this workload:"
    echo "$probe_out" | head -c 400 | sed 's/^/  /'
    echo
    warn "set PROBE_QUERY to a query valid for '${INDEX}' and re-run, or probe by hand"
    exit 0
fi

stats=$(curl -s "http://${TARGET_HOST}/_nodes/stats/indices/request_cache")
if command -v jq >/dev/null; then
    entry=$(echo "$stats" | jq '[.nodes[].indices.request_cache.memory_size_in_bytes] | add')
else
    entry=$(echo "$stats" | tr ',' '\n' | grep memory_size_in_bytes | head -1 | tr -dc '0-9')
fi

echo
if [[ -z "${entry:-}" || "$entry" == "0" ]]; then
    warn "cache is empty after the probe -- the query was not cached."
    warn "Check that size is 0 and that index.requests.cache.enable is true."
else
    cache_limit=$(curl -s "http://${TARGET_HOST}/_cluster/settings?include_defaults=true&flat_settings=true" \
        | tr ',' '\n' | grep 'indices.requests.cache.size' | head -1 | cut -d'"' -f4)
    printf '  entry size  : %s bytes (%.1f KB)\n' "$entry" "$(awk -v e="$entry" 'BEGIN{print e/1024}')"
    printf '  cache limit : %s\n' "${cache_limit:-unknown}"
    echo
    echo "  Working set = distinct queries x entry size. Size the cache, or the"
    echo "  number of distinct queries (--randomization-n), so the working set is"
    echo "  2-3x the cache; that is where eviction starts and the cache does real work."
fi

log "Done. Next: run.sh with --test-procedure=cache-eval"
