. ./config.sh

# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ "$1" -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]"
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]"
    fi
}

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-h]"
    echo
    echo "Options:"
    echo "      -a  Compile and build both Neo4j and Neo4j Benchmark Suite" 
    echo "      -b  Compile and build Neo4j Benchmark Suite" 
    echo "      -h  Show usage"
    echo

    exit 1
}

clean_all() {
  cd "${NEO4J_DIR}" || exit
  mvn clean >> "${COMPILE_OUT}" 2>&1
  
  retValue=$?
  message="Clean Neo4j" 
  check ${retValue} "${message}"

  cd - >> "${COMPILE_OUT}" 2>&1 || exit
}

build_neo4j() {
  if [ ! -d neo4j ]
  then
    git clone https://github.com/neo4j/neo4j.git --branch 5.15.0 --single-branch >> "${COMPILE_OUT}" 2>&1
  fi

  cd "${NEO4J_DIR}" || exit

  export MAVEN_OPTS="-Xmx2048m"
  mvn clean install -DskipTests >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Neo4j" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit

  cd "${NEO4J_DIR}"/packaging/standalone/target/ || exit
  tar xf neo4j-community-5.15.0-SNAPSHOT-unix.tar.gz

  cd - > /dev/null || exit
}

build_graph_data_science() {
  if [ ! -d "graph-data-science" ]
  then
    git clone -b teraheap_2.6 git@github.com:jackkolokasis/graph-data-science.git >> "${COMPILE_OUT}" 2>&1
  fi

  cd ./graph-data-science || exit

  ./gradlew :open-packaging:shadowCopy -Pneo4jVersion=5.15.0 >> "${COMPILE_OUT}" 2>&1

  retValue=$?
  message="Build GDS" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}

build_benchmark() {
  cd ./benchmarks || exit
  mvn clean package >> "${COMPILE_OUT}" 2>&1
  cd - > /dev/null || exit
}

# Check for the input arguments
while getopts "abch" opt
do
  case "${opt}" in
    a)
      export JAVA_HOME="${COMMERCIAL_JAVA}"
      build_neo4j
      export JAVA_HOME=${TERAHEAP_JAVA}
      build_graph_data_science
      build_benchmark
      ;;
    b)
      export JAVA_HOME=${TERAHEAP_JAVA}
      build_benchmark
      ;;
    c)
      clean_all
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done
