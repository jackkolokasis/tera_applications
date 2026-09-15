#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def number(value):
    value = float(value)
    return int(value) if value.is_integer() else value


def main():
    parser = argparse.ArgumentParser(
        description="Create workload params for one bbox load point."
    )
    parser.add_argument("--snapshot", required=True)
    parser.add_argument("--target-throughput", required=True)
    parser.add_argument("--target-update-throughput", required=True)
    parser.add_argument("--search-clients", required=True)
    parser.add_argument("--warmup-iterations", required=True)
    parser.add_argument("--iterations", required=True)
    parser.add_argument("--repeat-freq", required=True)
    parser.add_argument("--randomization-n", required=True)
    parser.add_argument("--randomization-alpha", required=True)
    args = parser.parse_args()

    # The first four keys are consumed by test_procedures/default.json.
    # The randomization keys are archived here as experiment metadata; OSB's
    # randomization itself is configured through CLI flags in lib/benchmark.sh.
    params = {
        "target_throughput": number(args.target_throughput),
        "update_target_throughput": number(args.target_update_throughput),
        "search_clients": int(args.search_clients),
        "warmup_iterations": int(args.warmup_iterations),
        "iterations": int(args.iterations),
    }

    snapshot = Path(args.snapshot)
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_text(json.dumps(params, indent=2) + "\n")


if __name__ == "__main__":
    main()
