## Build Apache Lucene

### Prerequisites
Build TeraHeap openJDK17 and set the following variables in the
./config.sh

```sh
export JAVA_HOME=/path/to/teraheap/jdk17
export TERA_APPS_REPO=/path/to/teraapplication/directory
```

### Build Lucene and benchmarks
```sh
./build -a
```

### Build only Lucene
```sh
./build -l
```

### Build only the benchmarks
```sh
./build.sh -b
``` 
