#!/usr/bin/env python3
import json
import pathlib
import sys

run = pathlib.Path(sys.argv[1])


def read_node(filename):
    path = run / filename
    if not path.exists():
        return None
    try:
        nodes = json.loads(path.read_text()).get("nodes", {})
        return next(iter(nodes.values())) if nodes else None
    except Exception:
        return None


def query_cache(label):
    node = read_node(f"query-cache-{label}.json")
    if node is None:
        return None
    return node.get("indices", {}).get("query_cache")


def request_cache(label):
    node = read_node(f"request-cache-{label}.json")
    if node is None:
        return None
    return node.get("indices", {}).get("request_cache")


before = query_cache("before") or {}
after = query_cache("after")

if after is None:
    print("No Lucene query-cache statistics captured.")
    raise SystemExit(0)


def delta(data_after, data_before, field):
    return (data_after.get(field, 0) or 0) - (data_before.get(field, 0) or 0)


hits = delta(after, before, "hit_count")
misses = delta(after, before, "miss_count")
lookups = hits + misses
evictions = delta(after, before, "evictions")
cache_count = delta(after, before, "cache_count")
size = after.get("memory_size_in_bytes", 0) or 0
entries = after.get("cache_size", 0) or 0
hit_rate = 100.0 * hits / lookups if lookups else 0.0

print("source      : Lucene query cache")
print(f"lookups     : {lookups:,} ({hits:,} hits / {misses:,} misses)")
print(f"hit rate    : {hit_rate:.2f}%")
print(f"cache size  : {size / 1048576:.1f} MB")
print(f"entries     : {entries:,}")
print(f"new cached  : {cache_count:,}")
print(f"evictions   : {evictions:,}")
if entries:
    print(f"entry size  : {size / entries / 1024:.1f} KB")

# Guard against accidentally benchmarking the request cache instead.
req_before = request_cache("before") or {}
req_after = request_cache("after") or {}
req_hits = delta(req_after, req_before, "hit_count")
req_misses = delta(req_after, req_before, "miss_count")
req_total = req_hits + req_misses
print()
print("request-cache sanity check:")
print(f"requests    : {req_total:,} ({req_hits:,} hits / {req_misses:,} misses)")
if req_total:
    print("WARNING: request-cache activity detected; it should be disabled for this experiment.")
