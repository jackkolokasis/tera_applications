## Giraph Benchmark Scripts

### Prerequisites
Edit the ./config.sh file to setup the configuration variables

### Download Dataset
```sh
./download-graphalytics-data-sets.sh /path/to/locate/dataset
```

### Run Giraph with TeraHeap
```sh
./run.sh -n 1 -o "nvme" -t
```
### Run Giraph natively
```sh
./run.sh -n 1 -o "nvme" -t
```
