#!/usr/bin/env bash
#
# cache_stats.sh -- report OpenSearch cache statistics.
#
#   ./cache_stats.sh              one snapshot
#   ./cache_stats.sh -w           watch, refreshing every 2s
#   ./cache_stats.sh -d 30        two snapshots 30s apart, report deltas
#   ./cache_stats.sh -c           clear the request cache, then report
#   ./cache_stats.sh -a           clear request, query, and fielddata caches
#   ./cache_stats.sh -r           raw JSON from both endpoints
#
# Reports:
#   - Request cache (legacy on-heap OR pluggable/tiered on_heap + disk)
#   - Query cache
#   - Fielddata cache
#
set -u

HOST="${HOST:-sith4:9200}"
INDEX="${INDEX:-}"
MODE="snapshot"
DELTA_SECONDS=30
INTERVAL=2

TMP="${TMPDIR:-/tmp}/cache_stats.$$"
mkdir -p "$TMP"

# Clean up temporary files whenever the script exits.
cleanup() {
    rm -rf "$TMP"
}

# EXIT performs the cleanup.  SIGINT/SIGTERM must explicitly terminate the
# script; otherwise trapping SIGINT and merely returning would let the
# `while true` watch loop continue after Ctrl+C.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
    echo "Usage: $0 [-H host:port] [-i index] [-w] [-n sec] [-d sec] [-c] [-r]"
    echo
    echo "Options:"
    echo "  -H <host:port>  target (default: ${HOST})"
    echo "  -i <index>      index name, for -c (default: all)"
    echo "  -w              watch mode"
    echo "  -n <sec>        watch interval (default: ${INTERVAL})"
    echo "  -d <sec>        delta mode: sample, wait, sample again"
    echo "  -c              clear the REQUEST cache first"
    echo "  -a              clear request, query, and fielddata caches first"
    echo "  -r              raw JSON"
    echo "  -h              this help"
    exit 1
}

CLEAR=false
CLEAR_ALL=false
while getopts ":H:i:n:d:wcarh" opt; do
    case "$opt" in
        H) HOST=$OPTARG ;;
        i) INDEX=$OPTARG ;;
        w) MODE="watch" ;;
        n) INTERVAL=$OPTARG ;;
        d) MODE="delta"; DELTA_SECONDS=$OPTARG ;;
        c) CLEAR=true ;;
        a) CLEAR_ALL=true ;;
        r) MODE="raw" ;;
        h) usage ;;
        *) usage ;;
    esac
done

fetch_json() {
    local caches_file="$1"
    local indices_file="$2"

    curl -sf \
        "http://${HOST}/_nodes/stats/caches/request_cache?level=tier" \
        > "$caches_file" || return 1

    curl -sf \
        "http://${HOST}/_nodes/stats/indices/request_cache,query_cache,fielddata" \
        > "$indices_file" || return 1
}

fetch_raw() {
    echo "=== caches/request_cache?level=tier ==="
    curl -s "http://${HOST}/_nodes/stats/caches/request_cache?level=tier&pretty"
    echo
    echo
    echo "=== indices/request_cache,query_cache,fielddata ==="
    curl -s "http://${HOST}/_nodes/stats/indices/request_cache,query_cache,fielddata?pretty"
    echo
}

report() {
    local caches_file="$TMP/caches.json"
    local indices_file="$TMP/indices.json"

    if ! fetch_json "$caches_file" "$indices_file"; then
        echo "failed to fetch cache statistics from ${HOST}" >&2
        return 1
    fi

    python3 - "$caches_file" "$indices_file" <<'PY'
import json, sys

caches_path, indices_path = sys.argv[1:3]

def load_node(path):
    try:
        data = json.load(open(path))
        nodes = data.get("nodes", {})
        return next(iter(nodes.values())) if nodes else None
    except Exception:
        return None

def nested(obj, *keys):
    for key in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
        if obj is None:
            return None
    return obj

def mib(n):
    return n / 1048576.0

caches_node = load_node(caches_path)
indices_node = load_node(indices_path)

if caches_node is None and indices_node is None:
    print("no cache stats available -- is the node up?")
    sys.exit(1)

tiered = nested(caches_node, "caches", "request_cache")
legacy = nested(indices_node, "indices", "request_cache")
query = nested(indices_node, "indices", "query_cache")
fielddata = nested(indices_node, "indices", "fielddata")

# If pluggable caching is disabled this endpoint returns noop_store and zeros.
if tiered and tiered.get("store_name") == "noop_store":
    tiered = None

print("=== REQUEST CACHE ===")

if tiered:
    store = tiered.get("store_name", "unknown")
    source = "tiered request cache" if store == "tiered_spillover" else f"pluggable on-heap ({store})"

    size = tiered.get("size_in_bytes", 0)
    hits = tiered.get("hit_count", 0)
    miss = tiered.get("miss_count", 0)
    evic = tiered.get("evictions", 0)
    items = tiered.get("item_count")
    total = hits + miss
    rate = 100.0 * hits / total if total else 0.0

    print(f"source      : {source}")
    print(f"store       : {store}")
    print(f"requests    : {total:,}   ({hits:,} hits / {miss:,} misses)")
    print(f"hit rate    : {rate:.2f}%")
    print(f"cache size  : {mib(size):,.1f} MB")
    print(f"evictions   : {evic:,}")

    if items is not None:
        print(f"entries     : {items:,}")
        if items:
            print(f"entry size  : {size/items/1024:,.1f} KB")

    tiers = tiered.get("tier", {})
    if tiers:
        print()
        print("tiers:")
        for name in ("on_heap", "disk"):
            t = tiers.get(name)
            if not t:
                continue
            th = t.get("hit_count", 0)
            tm = t.get("miss_count", 0)
            te = t.get("evictions", 0)
            ti = t.get("item_count", 0)
            ts = t.get("size_in_bytes", 0)
            req_pct = 100.0 * th / total if total else 0.0
            hit_pct = 100.0 * th / hits if hits else 0.0
            print(
                f"  {name:<8}"
                f" hits {th:>10,}"
                f" ({req_pct:>5.1f}% req, {hit_pct:>5.1f}% hits)"
                f" | misses {tm:>10,}"
                f" | items {ti:>8,}"
                f" | size {mib(ts):>8,.1f} MB"
                f" | spill/evict {te:>8,}"
            )

elif legacy:
    size = legacy.get("memory_size_in_bytes", 0)
    hits = legacy.get("hit_count", 0)
    miss = legacy.get("miss_count", 0)
    evic = legacy.get("evictions", 0)
    total = hits + miss
    rate = 100.0 * hits / total if total else 0.0

    print("source      : on-heap (legacy request cache)")
    print(f"requests    : {total:,}   ({hits:,} hits / {miss:,} misses)")
    print(f"hit rate    : {rate:.2f}%")
    print(f"cache size  : {mib(size):,.1f} MB")
    print(f"evictions   : {evic:,}")

    # Legacy request-cache stats do not expose item_count. This is only an
    # estimate; explicit invalidations/cache clears can make it inaccurate.
    resident_est = max(miss - evic, 0)
    if resident_est:
        print(f"entries(est): {resident_est:,}  (misses - evictions)")
        print(f"entry size  : {size/resident_est/1024:,.1f} KB")
else:
    print("no request-cache statistics available")

print()
print("=== QUERY CACHE ===")

if query:
    size = query.get("memory_size_in_bytes", 0)
    hits = query.get("hit_count", 0)
    miss = query.get("miss_count", 0)
    total = query.get("total_count", hits + miss)
    evic = query.get("evictions", 0)
    current = query.get("cache_size", 0)
    ever = query.get("cache_count", 0)
    rate = 100.0 * hits / (hits + miss) if hits + miss else 0.0

    print(f"lookups     : {total:,}   ({hits:,} hits / {miss:,} misses)")
    print(f"hit rate    : {rate:.2f}%")
    print(f"cache size  : {mib(size):,.1f} MB")
    print(f"entries     : {current:,} current / {ever:,} ever cached")
    print(f"evictions   : {evic:,}")
    if current:
        print(f"entry size  : {size/current/1024:,.1f} KB")
else:
    print("no query-cache statistics available")

print()
print("=== FIELDDATA CACHE ===")

if fielddata:
    size = fielddata.get("memory_size_in_bytes", 0)
    evic = fielddata.get("evictions", 0)
    items = fielddata.get("item_count")

    print(f"cache size  : {mib(size):,.1f} MB")
    if items is not None:
        print(f"items       : {items:,}")
        if items:
            print(f"item size   : {size/items/1024:,.1f} KB")
    print(f"evictions   : {evic:,}")
else:
    print("no fielddata-cache statistics available")
PY
}

delta_report() {
    local secs="$1"
    local cb="$TMP/caches-before.json"
    local ib="$TMP/indices-before.json"
    local ca="$TMP/caches-after.json"
    local ia="$TMP/indices-after.json"

    fetch_json "$cb" "$ib" || { echo "failed to fetch initial stats" >&2; return 1; }
    echo "sampling for ${secs}s..."
    sleep "$secs"
    fetch_json "$ca" "$ia" || { echo "failed to fetch final stats" >&2; return 1; }

    python3 - "$secs" "$cb" "$ib" "$ca" "$ia" <<'PY'
import json, sys

secs = float(sys.argv[1])
cb_path, ib_path, ca_path, ia_path = sys.argv[2:]

def load_node(path):
    data = json.load(open(path))
    return next(iter(data["nodes"].values()))

def nested(obj, *keys):
    for key in keys:
        obj = obj.get(key) if isinstance(obj, dict) else None
        if obj is None:
            return None
    return obj

def request_source(caches_node, indices_node):
    t = nested(caches_node, "caches", "request_cache")
    if t and t.get("store_name") != "noop_store":
        return "pluggable", t
    return "legacy", nested(indices_node, "indices", "request_cache")

def d(a, b, key):
    return a.get(key, 0) - b.get(key, 0)

cb, ib, ca, ia = map(load_node, (cb_path, ib_path, ca_path, ia_path))
kind_b, req_b = request_source(cb, ib)
kind_a, req_a = request_source(ca, ia)
q_b = nested(ib, "indices", "query_cache") or {}
q_a = nested(ia, "indices", "query_cache") or {}
f_b = nested(ib, "indices", "fielddata") or {}
f_a = nested(ia, "indices", "fielddata") or {}

print(f"over {secs:.0f}s:")
print()
print("=== REQUEST CACHE DELTA ===")
if req_b and req_a:
    size_key = "size_in_bytes" if kind_a == "pluggable" else "memory_size_in_bytes"
    source = req_a.get("store_name", "pluggable") if kind_a == "pluggable" else "on-heap (legacy)"
    hits = d(req_a, req_b, "hit_count")
    miss = d(req_a, req_b, "miss_count")
    evic = d(req_a, req_b, "evictions")
    size = d(req_a, req_b, size_key)
    total = hits + miss
    print(f"source      : {source}")
    print(f"requests    : {total:,}   ({total/secs:.1f} req/s)")
    print(f"hits        : {hits:,}")
    print(f"misses      : {miss:,}   ({miss/secs:.1f}/s)")
    print(f"hit rate    : {100*hits/total if total else 0:.2f}%")
    print(f"evictions   : {evic:,}")
    print(f"size delta  : {size/1048576:+,.1f} MB")
    print(f"size now    : {req_a.get(size_key, 0)/1048576:,.1f} MB")

    if kind_a == "pluggable":
        tb = req_b.get("tier", {})
        ta = req_a.get("tier", {})
        if ta:
            print()
            print("tier deltas:")
            for name in ("on_heap", "disk"):
                b = tb.get(name, {})
                a = ta.get(name, {})
                if not a:
                    continue
                print(
                    f"  {name:<8}"
                    f" hits {d(a,b,'hit_count'):>10,}"
                    f" | misses {d(a,b,'miss_count'):>10,}"
                    f" | evict/spill {d(a,b,'evictions'):>8,}"
                    f" | size delta {d(a,b,'size_in_bytes')/1048576:+8.1f} MB"
                )
else:
    print("no request-cache statistics available")

print()
print("=== QUERY CACHE DELTA ===")
qh = d(q_a, q_b, "hit_count")
qm = d(q_a, q_b, "miss_count")
qe = d(q_a, q_b, "evictions")
qs = d(q_a, q_b, "memory_size_in_bytes")
qt = qh + qm
print(f"lookups     : {qt:,}   ({qt/secs:.1f}/s)")
print(f"hits        : {qh:,}")
print(f"misses      : {qm:,}")
print(f"hit rate    : {100*qh/qt if qt else 0:.2f}%")
print(f"evictions   : {qe:,}")
print(f"size delta  : {qs/1048576:+,.1f} MB")
print(f"size now    : {q_a.get('memory_size_in_bytes', 0)/1048576:,.1f} MB")
print(f"entries now : {q_a.get('cache_size', 0):,}")

print()
print("=== FIELDDATA CACHE DELTA ===")
fe = d(f_a, f_b, "evictions")
fs = d(f_a, f_b, "memory_size_in_bytes")
print(f"evictions   : {fe:,}")
print(f"size delta  : {fs/1048576:+,.1f} MB")
print(f"size now    : {f_a.get('memory_size_in_bytes', 0)/1048576:,.1f} MB")
if "item_count" in f_a:
    print(f"items now   : {f_a.get('item_count', 0):,}")
PY
}

if [ "$CLEAR_ALL" == "true" ]; then
    target="${INDEX:+/${INDEX}}"
    curl -sf -X POST \
        "http://${HOST}${target}/_cache/clear?request=true&query=true&fielddata=true" \
        > /dev/null \
        && echo "request, query, and fielddata caches cleared${INDEX:+ on ${INDEX}}"
    echo
elif [ "$CLEAR" == "true" ]; then
    target="${INDEX:+/${INDEX}}"
    curl -sf -X POST \
        "http://${HOST}${target}/_cache/clear?request=true" \
        > /dev/null \
        && echo "request cache cleared${INDEX:+ on ${INDEX}}"
    echo
fi

case "$MODE" in
    raw)      fetch_raw ;;
    delta)    delta_report "$DELTA_SECONDS" ;;
    watch)    while true; do clear; date; echo; report; sleep "$INTERVAL"; done ;;
    snapshot) report ;;
esac
