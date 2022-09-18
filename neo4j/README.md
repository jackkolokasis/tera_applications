## Neo4j with TeraHeap

### Preparation

1. Set the JAVA_HOME in the ./config.sh 

2. Edit "ldbc_graphalytics_platforms_neo4j-master/src/main/java/science/atlarge/graphalytics/neo4j/Neo4jPlatform.java"
Find the following line and change the path "/mnt/spark/" to show in a
path over a local device. In this file the benchamark suite creates
the neo4j database.

```java
Path loadedPath = Paths.get("/mnt/spark/intermediate").resolve(formattedGraph.getName());
```

### Build Neo4j and benchmark suite
```sh
./build -a
```
### Build only benchmark suite
```sh
./build -s
```
### Clean All
```sh
./build -c
```

### Run Benchmarks
To run the benchmarks please read the README file in ./scripts
directory
