import re
import csv
import subprocess
import argparse
from pathlib import Path
from itertools import zip_longest

# Configuration

results_filename = "result.csv"
gc_log = "gc.log"

# Regex paterns
EXEC_TIME_REGEX = re.compile(r"TOTAL_TIME,\s*([\d\.]+)")
GC_PAUSE_REGEX = re.compile(r"Pause.*?([\d\.]+)\s*ms")

#=========================

# Argument parsing 

def parse_args():
    parser = argparse.ArgumentParser(
        description="Find median run and extract Pause Times into a single CSV. Pauses are in order."
    )
    parser.add_argument(
        "-c", "--config",
        action="append",
        metavar="NAME=DIR",
        required=True,
        help="Add configuration directory as name=dir."
    )
    parser.add_argument(
        "-o", "--output",
        default="output.csv",
        help="Output CSV filename (default: output.csv)"
    )
    return parser.parse_args()

def build_configurations(config_args):
    configurations = []
    for entry in config_args:
        if "=" not in entry:
            raise ValueError(f"Invalid --config value '{entry}', expected NAME=DIR")
        name, directory = entry.split("=", 1)
        configurations.append({"name": name, "dir": directory})
    return configurations

#=========================

def get_execution_time(run_dir: Path) -> float:
    """Parses the result file in a run directory to find the execution time."""
    result_file = run_dir / results_filename
    if not result_file.exists():
        return None
    
    with open(result_file, 'r') as f:
        for line in f:
            match = EXEC_TIME_REGEX.search(line)
            if match:
                return float(match.group(1))
    return None

def find_median_run(config_dir: Path) -> Path:
    """Finds the run directory with the median execution time."""
    runs = []
    # Assuming each run is in a sub-directory (e.g., run_1, run_2)
    for run_dir in config_dir.iterdir():
        if run_dir.is_dir():
            run_dir = run_dir / "conf0"
            exec_time = get_execution_time(run_dir)
            if exec_time is not None:
                runs.append((exec_time, run_dir))
    
    if not runs:
        raise ValueError(f"No valid run results found in {config_dir}")
    
    # Sort by execution time and pick the median
    runs.sort(key=lambda x: x)
    median_index = len(runs) // 2
    median_time, median_dir = runs[median_index]
    
    print(f"[{config_dir.name}] Median run found: {median_dir.parent.name} ({median_time})")
    return median_dir

def extract_gc_pauses(run_dir: Path) -> list:
    """Extracts a list of GC pause times from the gc.log in the given directory."""
    gc_log_file = run_dir / gc_log
    pauses = []
    
    if not gc_log_file.exists():
        print(f"Warning: No {gc_log} found in {run_dir}")
        return pauses

    with open(gc_log_file, 'r') as f:
        for line in f:
            match = GC_PAUSE_REGEX.search(line)
            if match:
                pauses.append(float(match.group(1)))
                
    return pauses

def main():
    args = parse_args()
    configurations = build_configurations(args.config)
    output_filename = args.output

    # Find median run and extract GC pauses
    all_pauses = []
    for conf in configurations:
        print(f"Processing Configuration {conf['name']}...")
        median_run = find_median_run(Path(conf['dir']))
        pauses = extract_gc_pauses(median_run)
        all_pauses.append(pauses)

    # Merge into CSV
    print(f"Writing results to {output_filename}...")
    with open(output_filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Write headers
        headers = [ conf['name']  for conf in configurations ]
        writer.writerow(headers)
        
        # zip_longest pairs up the elements. If one list is shorter, it fills with ''
        for pauses_row in zip_longest(*all_pauses, fillvalue=''):
            writer.writerow(pauses_row)
            
    print("CSV generation complete.")

if __name__ == "__main__":
    main()
