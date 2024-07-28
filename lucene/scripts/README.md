# Scripts to Run Lucene Benchmarks

## Prerequisites
Setup the variables in the conf.sh file.

You need to have "sudo" access in the server.

## Generate Datasets, Lucene Indexes, and Queries
```sh
./download_real_dataset.sh
```

## Run experiments with native JVM
```sh
./run.sh -n 1 -o <path/to/result/directory>

```
## Run experiments with FlexHeap
```sh
./run.sh -n 1 -o <path/to/result/directory> -f

```

## Run experiments with TeraHeap (not supported yet)
```sh
./run.sh -n 1 -o <path/to/result/directory> -t

```

## Kill all background processes
```sh
./run.sh -k 
```
