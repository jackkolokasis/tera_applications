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

  # TODO clean benchmarks
}

prepare_certificates() {
  cp -r ../util/certificates/lib "${JAVA_HOME}"/

  # Create the security directory if it does not exist
  if [ ! -d "${JAVA_HOME}/lib/security/" ]
  then 
    mkdir -p "${JAVA_HOME}"/lib/security
  fi 

  cp ../util/certificates/blacklisted.certs "${JAVA_HOME}"/lib/security/
  cp ../util/certificates/cacerts "${JAVA_HOME}"/lib/security/
  cp ../util/certificates/nss.cfg "${JAVA_HOME}"/lib/security/
  cp ../util/certificates/java.policy "${JAVA_HOME}"/lib/security/
  cp ../util/certificates/java.security "${JAVA_HOME}"/lib/security/
}

build_neo4j() {
  if [ ! -d neo4j ]
  then
    git clone https://github.com/neo4j/neo4j.git --branch 5.15.0 --single-branch
  fi

  cd "${NEO4J_DIR}" || exit

  export MAVEN_OPTS="-Xmx2048m"
  mvn clean install -DskipTests -T1C -X >> "${COMPILE_OUT}" 2>&1
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
    git clone -b teraHeap git@github.com:jackkolokasis/graph-data-science.git
  fi

  cd ./graph-data-science || exit

  ./compileAndPublishToMaven.sh >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build and Import GDS to .m2" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}

build_ldbc_graphalytics() {
  if [ ! -d "ldbc_graphalytics" ]
  then
    git clone git@github.com:jackkolokasis/ldbc_graphalytics.git >> "${COMPILE_OUT}" 2>&1
    retValue=$?
    message="Download LDBC Graphalytics Benchmark" 
    check ${retValue} "${message}"
  fi

  cd ldbc_graphalytics || exit
  git checkout huge_heap >> "${COMPILE_OUT}" 2>&1

  mvn clean install -Dmaven.buildNumber.skip >> "${COMPILE_OUT}" 2>&1
  
  retValue=$?
  message="Build LDBC Graphalytics Benchmark" 
  check ${retValue} "${message}"
  
  cd - > /dev/null || exit

  rm -rf ldbc_graphalytics
}

build_ldbc_neo4j_bench() {
  cd ./ldbc_graphalytics_platforms_neo4j-master || exit
  ./init.sh "${DATASET_DIR}" "${NEO4J_EXEC_DIR}" algolib >> "${COMPILE_OUT}" 2>&1
  
  retValue=$?
  message="Build Neo4j Benchmark" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}

build_benchmark() {
  #local is_gds_exist
  #is_gds_exist="false"

  #if [ -d "${HOME}/.m2/repository/org/neo4j/gds/" ]
  #then
  #  build_graph_data_science
  #  is_gds_exist="true"
  #fi

  #if [ $is_gds_exist == "false" ]
  #then
  #  build_ldbc_graphalytics
  #  build_ldbc_neo4j_bench

  #  build_graph_data_science
  #  build_ldbc_graphalytics
  #  build_ldbc_neo4j_bench
  #else
  #  build_graph_data_science
  #  build_ldbc_graphalytics
  #  build_ldbc_neo4j_bench
  #fi
  build_ldbc_graphalytics
  build_ldbc_neo4j_bench
}

# Check for the input arguments
while getopts "abch" opt
do
  case "${opt}" in
    a)
      if [ "$CUSTOM_JVM" == "true" ]
      then
        prepare_certificates
      fi
      #build_neo4j
      build_benchmark
      ;;
    b)
      if [ "$CUSTOM_JVM" == "true" ]
      then
        prepare_certificates
      fi
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
