# Lucene benchmarking

This repo includes custom benchmarking programs for use with linedocs and query docs in the same
format as used by SPIRIT. It is designed to be simpler than luceneutil and is appropriate for
simple benchmarks for baseline Lucene. 

## Setup

Install and setup Java with version at least 17.

These benchmarking programs are to be used with **Lucene 9.6.0** specifically.

Install Lucene 9.6.0 somewhere else on your device from here:
https://archive.apache.org/dist/lucene/java/9.6.0/

You can either install pre-built binaries (in which case they will be in the modules folder),
or download the source code and build it yourself (in which case run `./gradlew assemble` to
build using the provided gradle wrapper, and then run `find . -name *.jar` to find where the JARs
are. You should find at least two folders which contain all of the JARs).

Then, there are two things that need to be in your classpath when compiling the benchmarking programs:
- Lucene's JARs
- The resources folder in this repo, which is required to allow the indexer to use the direct postings format. The resources folder will allow the "NoCompressionCodec" which uses the DirectPostingsFormat to be registered as a Java "service" and for the SPI loader to find it. Read more at https://docs.oracle.com/javase/8/docs/api/java/util/ServiceLoader.html.
- (When running the programs) The `out` folder containing the benchmarking programs' class files generated by `make`

Change the `classpath` variable in the `scripts/benchmark.py` script and the argument given to `-cp` in the Makefile accordingly.

Note: A better way would be to import the JARs as Java modules, using Java 9's module system, since
they come packaged as such. This will require you to refactor the Java programs in this repo into
a Java module though. The author has managed up until now using the classpath solution.

## Running

There are two main actions: indexing and searching. 

Documents need to be in a linedoc with one document per line. Queries need to also be in a file with one query per line. The searcher provided interprets multiterm queries as AND queries, e.g. `term1 term2`
is a search for `term1 AND term2`. To use other types of queries, please edit EvaluateQueries.java.

Compile the benchmarking programs with `make`.

Run the indexer with `java IndexFiles -i DIRECTORY_TO_INDEX_TO -d PATH_TO_LINEDOCS_FILE`. Options:
- `-rb RB_SIZE`: Ram buffer size. Controls RAM space used for new segments, and hence segment size. (Default: 128 MB)
- `-u`: Update an existing index
- `-c`: Create a new index (marks existing documents as deleted) (This is the default)
- `-die`: Delete the index directory if it already exists before indexing
- `-de`: Disable encryption. Uses the direct postings format, where the normal format is used for storage on disk but the IndexSearcher uncompresses the whole index, storing postings as `int[]` and `byte[]`, directly into the heap before searching (Default: encryption is enabled)
- `-fm`: Forces all segments to be merged into one at the end of the run (Default: disabled)
- `-dam`: Disables automatic merging during indexing. Note this can still be used with `-fm`, in which case all the merging is just done manually. (Default: automatic merging enabled)
- `-ws NO_OF_SETS`: Indexes the docs into a temporary directory, which it deletes after done, a few times to warm up the JVM. (Default: 0 sets/no warmup)

The indexer creates a directory containing the index. Then search queries over this index using `java EvaluateQueries -i INDEX_DIR -q PATH_TO_QUERIES_FILE`. Options:
- `-r RESULTS_PATH`: optionally specify a file to write the results of each query to. For verifying that it is actually searching things correctly.
- `-n N_RESULTS`: control how many results are fetched. Has no effect if scoring is disabled (in which case it always fetches all existing results).
- `-ar`: Fetch all existing results.
- `-dc`: Disable the query cache.
- `-ws NO_OF_SETS`: runs warmup sets of the queries similarly to indexing

The `benchmark.py` script runs experiments in batches, but is quite roughshod and what configurations
it runs is hardcoded. Please read the code yourself and modify it to your needs.

## Notes on JVM and OS parameters

In general, use `numactl` to bind both the cpu and memory to one socket to avoid variations due to NUMA.

To limit the amount of DRAM used by the indexer/searcher, use cgroups. Some scripts are provided for this; see `scripts/cgroup-create.sh` and `scripts/cgroup-run.sh`, however the former requires sudo to run. Also see https://www.flamingbytes.com/blog/cgroups-limit-memory/.

JVM parameters of interest:
- Run `java -XX:+PrintFlagsFinal --version` to see all of the flags and their default values.
- `-XX:AllocateHeapAt=PATH_TO_DIRECTORY` allocates the heap on the specified directory (can be on SSD or NVM)
- `-Xmx` and `Xms` set the initial and maximum JVM heap size
- `-Xmn` sets the nursery size
- `-XX:-TieredCompilation` and `-server` disable tiered compilation and uses the best runtime compiler possible (the "server" compiler). Reduces overhead due to JVM.
- Read more at https://docs.oracle.com/en/java/javase/11/tools/java.html (though note that this website's info is for Java 11).

## Creating the linedoc and queries files

### Benchmark datasets

For testing, we use a dataset derived from Wikipedia articles (in English), broken into ~1kb chunks. We chose this dataset because:
 - real-time search is typically applied to social media sites, where posts are (on average) relatively short
 - Wikipedia articles include a broad range of words and writing styles
 - Apache Lucene (another search indexer) is benchmarked using this dataset

You can download the dataset directly using the following commands:

```
wget -c http://home.apache.org/~mikemccand/enwiki-20120502-lines-1k.txt.lzma
unlzma enwiki-20120502-lines-1k.txt.lzma
head -n 1000000 enwiki-20120502-lines-1k.txt > dataset.txt
```

Alternatively, you can recreate the dataset from scratch using a Wikipedia dump. To do this, follow the instructions in the [lucene-util](https://github.com/mikemccand/luceneutil#user-content-creating-line-doc-file-from-an-arbitrary-wikimedia-dump-data) repository.

For those using VICS' machines at the ANU (i.e. Rosella, Magpie, etc.), the dataset may be found existing
on your device's storage. Note that the dataset is very big and may take up to 4 hours to download, so you do
not want to do so unless you have to! On Rosella, it is at `/mnt/ssd/search-benchmarking/wiki-dataset`; for
other devices, ask your supervisor.

Note that although the articles are already clipped, a rare few of the articles have very large words/URLs as their
final word, or non-English characters, which cause them to be exceedingly long. SPIRIT has a hardcoded limit to document lengths, causing this to be problematic. You may resolve this using the command `cut -c -1000`, which cuts every line to 1000 bytes exactly. Note that the dash before the number is very important here!
This may cut the final word midway so use this at your discretion.

To use this dataset in SPIRIT, be sure to pass the `-i 1:dataset.txt` parameter, and do not provide the `-l` parameter

### Query workloads

We generate our query workloads from a selection of 50 K terms organised into:
- around 100 high frequency (H) terms
- around 1000 medium frequency (M) terms
- the remaining being low frequency (L) terms

These terms have been chosen based on their frequency in the Wikipedia articles dataset. The terms
can be found organised into respective folders based on frequency in `query-workload/terms`.

There are a few scripts used to generate query workloads in `query-workload`. The main ones are:
- `get_query_terms.sh`: Top level script to generate queries. Pass the following arguments; see the script itself for details:
  - The number of terms (1 or 2)
  - The frequency of each term (either L, M, H. E.g. for two term queries where one term is H and the other is L, pass HL).
  - The number of queries to generate (e.g. 10000).
- `query_gen_multicore.sh`: If `get_query_terms.sh` is too slow, use this to generate queries using multiple processes
  concurrently. Instead of passing the number of queries to generate, pass the number of threads (n) and then how many queries
  per thread (m), and it will generate n * m queries.
- `mix_queries.py`: For generating workloads with a mix of query types from a set of existing query workloads.
  Change the workloads that it draws queries from in the script itself (they are hardcoded), and then run the script
  specifying the number of mixed queries to generate and a file to save them to. This script is quite simple and can be
  easily modified to achieve finer/coarser mixing of query types if desired.

Note that scripts to generate queries with more than 2 terms are yet to be added.