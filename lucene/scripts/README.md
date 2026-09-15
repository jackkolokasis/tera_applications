# Scripts to Run Lucene Benchmarks

## Prerequisites
Setup the fixed variables in the `conf.tmpl.sh` file.

Modify (if required) `gen-conf.sh` script which generates
the configuration.

**NOTE:** as `conf.sh` is dynamically generated, do not modify it.

Change the benchmark in `run.sh` variable `BENCHMARKS`

You need to have "sudo" access in the server.

## Generate Datasets, Lucene Indexes, and Queries
```sh
./download_real_dataset.sh
```

## Run experiments with native JVM
```sh
./run.sh -n 1 -o <path/to/result/directory>

```
## Run experiments with TeraHeap
```sh
./run.sh -n 1 -o <path/to/result/directory> -t

```

## Run flags for configuration

You can pass the following flags to `run.sh` to modify the configuration

```
-g  Number of GC Threads            [Default: 16]
-m  Memory Budget                   [<x>G where x is a number | Default: 60G]
-t  Enable TeraHeap
-D  Disable QueryCache
-e  Number of QueryCache entries    [Default: 3000000]
-s  Enable statistics
-H  Ratio (%) Heap/PageCache (TH)   [Default: 55]
-Q  Ratio (%) QueryCache/Heap (N)   [Default: 50]
```

## Kill all background processes
```sh
./run.sh -k 
```

## Extract GC pause times

To extract the GC pauses from the median run of two configurations in a single csv file:

```
python3 ./extract_pause_times.py -c Native=<path/to/native/results> -c TeraHeap=<path/to/teraheap/results> -o <path/to/generated/output.csv>
```

The CSV will have a `Native` and a `TeraHeap` column for Native and TeraHeap GCs, respectively, in order.
If a configuration has fewer GCs, the respective column will be filled with blank.
Note that both paths should point to the directory that contains the `run*/` sub-directories to be able to find the median run.
You can add additional configurations following the same pattern by adding `-c CONF-NAME=PATH`
