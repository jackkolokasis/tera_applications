#!/usr/bin/env python3

import argparse
import csv
import json
import re
import shutil
import sys
from pathlib import Path


QUERY_TO_PARAM = {
    "bbox": "target_throughput",
}

TEST_RUN_ID_RE = re.compile(r"\[Test Run ID\]:\s*([0-9A-Fa-f-]+)")


def load_json(path):
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        print(f"warning: cannot read {path}: {exc}", file=sys.stderr)
        return None


def extract_test_run_id(log_path):
    if not log_path.exists():
        return None
    matches = TEST_RUN_ID_RE.findall(log_path.read_text(errors="replace"))
    return matches[-1] if matches else None


def get_test_run_json(run_dir, benchmark_home):
    local = run_dir / "test_run.json"
    if local.exists():
        return local

    test_run_id = extract_test_run_id(run_dir / "osb_run.txt")
    if not test_run_id:
        print(f"warning: missing Test Run ID in {run_dir}", file=sys.stderr)
        return None

    source = (
        benchmark_home
        / ".osb"
        / "benchmarks"
        / "test-runs"
        / test_run_id
        / "test_run.json"
    )

    if not source.exists():
        print(f"warning: missing {source}", file=sys.stderr)
        return None

    try:
        shutil.copy2(source, local)
        (run_dir / "test_run_id.txt").write_text(test_run_id + "\n")
        print(f"recovered {local}")
        return local
    except OSError as exc:
        print(f"warning: could not archive {source}: {exc}", file=sys.stderr)
        return source


def p99(values):
    if not isinstance(values, dict):
        return ""

    for key in ("99_0", "99.0", "99"):
        if key in values and values[key] is not None:
            return values[key]

    for key, value in values.items():
        try:
            if float(str(key).replace("_", ".")) == 99.0:
                return value
        except ValueError:
            pass

    return ""


def mean_throughput(values):
    if not isinstance(values, dict):
        return ""

    if values.get("mean") is not None:
        return values["mean"]
    if values.get("median") is not None:
        return values["median"]
    return ""


def metrics_by_task(test_run):
    result = {}
    for item in test_run.get("results", {}).get("op_metrics", []):
        task = item.get("task") or item.get("operation")
        if task:
            result[task] = item
    return result


def metadata_from_path(run_dir):
    out = {"run": "", "conf": "", "load": "", "repeat_freq": ""}

    for part in run_dir.parts:
        m = re.fullmatch(r"run(\d+)", part)
        if m:
            out["run"] = int(m.group(1))
            continue

        m = re.fullmatch(r"conf(\d+)", part)
        if m:
            out["conf"] = int(m.group(1))
            continue

        m = re.fullmatch(r"load(\d+)", part)
        if m:
            out["load"] = int(m.group(1))
            continue

        m = re.fullmatch(r"rf(.+)", part)
        if m:
            out["repeat_freq"] = m.group(1)

    return out


def find_runs(root):
    for params_file in sorted(root.rglob("params.json")):
        run_dir = params_file.parent
        if (run_dir / "osb_run.txt").exists() or (run_dir / "test_run.json").exists():
            yield run_dir


def sort_num(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return float("inf")


def main():
    parser = argparse.ArgumentParser(
        description="Parse bbox OpenSearch Benchmark results."
    )
    parser.add_argument("results_root")
    parser.add_argument("-o", "--output", default=None)
    parser.add_argument(
        "--benchmark-home",
        default="/mnt/spark/benchmark-home",
    )
    args = parser.parse_args()

    root = Path(args.results_root).resolve()
    benchmark_home = Path(args.benchmark_home).resolve()
    output = Path(args.output).resolve() if args.output else root / "csv"
    output.mkdir(parents=True, exist_ok=True)

    per_query = {q: [] for q in QUERY_TO_PARAM}
    all_rows = []
    runs_found = 0
    runs_parsed = 0

    for run_dir in find_runs(root):
        runs_found += 1

        params = load_json(run_dir / "params.json")
        if params is None:
            continue

        test_run_path = get_test_run_json(run_dir, benchmark_home)
        if test_run_path is None:
            continue

        test_run = load_json(test_run_path)
        if test_run is None:
            continue

        by_task = metrics_by_task(test_run)
        meta = metadata_from_path(run_dir)

        test_run_id = (
            test_run.get("test-run-id")
            or test_run.get("test_run_id")
            or extract_test_run_id(run_dir / "osb_run.txt")
            or ""
        )

        repeat_freq = params.get("repeat_freq", meta["repeat_freq"])
        matched = False

        for query, param_name in QUERY_TO_PARAM.items():
            if param_name not in params:
                continue

            metric = by_task.get(query, {})
            if metric:
                matched = True

            raw_error_rate = metric.get("error_rate")
            error_rate_pct = (
                raw_error_rate * 100.0
                if isinstance(raw_error_rate, (int, float))
                else ""
            )

            row = {
                "run": meta["run"],
                "conf": meta["conf"],
                "load": meta["load"],
                "repeat_freq": repeat_freq,
                "search_clients": params.get("search_clients", ""),
                "randomization_n": params.get("randomization_n", ""),
                "randomization_alpha": params.get("randomization_alpha", ""),
                "test_run_id": test_run_id,
                "target_throughput_ops_s": params[param_name],
                "achieved_throughput_ops_s": mean_throughput(metric.get("throughput", {})),
                "p99_latency_ms": p99(metric.get("latency", {})),
                "p99_service_time_ms": p99(metric.get("service_time", {})),
                "error_rate_pct": error_rate_pct,
            }

            per_query[query].append(row)
            all_rows.append({"query": query, **row})

        if matched:
            runs_parsed += 1
        else:
            print(
                f"warning: no bbox metric in {test_run_path}",
                file=sys.stderr,
            )

    if runs_found == 0:
        raise SystemExit(f"No runs found under {root}")

    fields = [
        "run",
        "conf",
        "load",
        "repeat_freq",
        "search_clients",
        "randomization_n",
        "randomization_alpha",
        "test_run_id",
        "target_throughput_ops_s",
        "achieved_throughput_ops_s",
        "p99_latency_ms",
        "p99_service_time_ms",
        "error_rate_pct",
    ]

    def key(row):
        return (
            sort_num(row["target_throughput_ops_s"]),
            sort_num(row["repeat_freq"]),
            sort_num(row["run"]),
            sort_num(row["conf"]),
            sort_num(row["load"]),
        )

    for query, rows in per_query.items():
        rows.sort(key=key)
        path = output / f"{query}.csv"
        with path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
        print(f"{query:<20} {len(rows):>4} rows -> {path}")

    all_rows.sort(key=lambda row: (row["query"], key(row)))
    combined = output / "all_queries.csv"
    with combined.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["query", *fields])
        writer.writeheader()
        writer.writerows(all_rows)

    print()
    print(f"Parsed {runs_parsed}/{runs_found} runs.")
    print(f"Combined CSV -> {combined}")


if __name__ == "__main__":
    main()
