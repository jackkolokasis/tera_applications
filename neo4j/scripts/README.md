## Run Benchmarks

### Download Datasets

Open "./download-graphalytics-data-sets.sh" and uncommen the specific
line with the specific dataset. Then run:

```sh
./download-graphalytics-data-sets.sh <path/to/download/dataset>
```

### Run Benchmarks

Before running benchmarks you have to set the global configuration
variables in conf.sh

Run the benchmarks with TeraHeap enabled:
```sh
./run.sh -n 1 -o "test" -c
```

Run the benchmarks without TeraHeap enabled:
```sh
./run.sh -n 1 -o "test" -s
```

### Results Output
After the benchmark runs you a directory will be created that contains
the results. The directory form is as follow:

```sh
wcc_140g_14g_th_12:28:23-18-09-2022/
└── wcc
    └── conf0
        └── run0
            ├── bench.log
            ├── benchmark-summary.log
            ├── conf.sh
            ├── diskstat.csv
            ├── diskstats-after-12:44:27-18-09-2022
            ├── diskstats-before-12:28:42-18-09-2022
            ├── iostat-12:28:42-18-09-2022
            ├── jstat.txt
            ├── mpstat-12:28:42-18-09-2022
            ├── parsedate
            ├── plots
            │   ├── avg_qu_sz.png
            │   ├── avg_rq_sz.png
            │   ├── cpu.png
            │   ├── idle_cpu.png
            │   ├── iow_cpu.png
            │   ├── r_thrput.png
            │   ├── sys_cpu.png
            │   ├── thrput.png
            │   ├── user_cpu.png
            │   ├── util.png
            │   └── wr_thrput.png
            ├── result.csv
            ├── serdes.txt
            ├── statistics.csv
            ├── system.csv
            └── teraHeap.txt
```
The main files in the output results directory are the following:

|  File         | Description                                                     |
|:----------:   |:-------------:                                                  |
|result.csv     | Shows time breakdown (e.g., total time, gc time)                |
|diskstat.csv   | Contains read/write statistics for each storage device          |
|statistics.csv | Contains statistics for TeraHeap (e.g., number of objects in H2)|
