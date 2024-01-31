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
    echo "      -a  Compile and build both Giraph and Benchmark Suite" 
    echo "      -b  Compile and build Giraph Benchmark Suite" 
    echo "      -h  Show usage"
    echo

    exit 1
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

download_hadoop() {
  if [ ! -d hadoop-2.4.0 ]
  then
    wget https://archive.apache.org/dist/hadoop/common/hadoop-2.4.0/hadoop-2.4.0.tar.gz >> "${COMPILE_OUT}" 2>&1
    retValue=$?
    message="Download Hadoop" 
    check ${retValue} "${message}"

    tar xf hadoop-2.4.0.tar.gz >> "${COMPILE_OUT}" 2>&1
    rm hadoop-2.4.0.tar.gz

    # Copy the configurations
    cp ./scripts/config/hadoop/*  ./hadoop-2.4.0/etc/hadoop/

    cd ./hadoop-2.4.0/etc/hadoop/ || exit

    command="    <value>hdfs://${HADOOP_SLAVE}:9000</value>"
    sed -i '/hdfs:/c\'"${command}" core-site.xml

    command="    <value>${HDFS_DIR}/hadoop</value>"
    sed -i '/<value>\/mnt\/datasets\/hadoop/c\'"${command}" core-site.xml

    command="\t\t<value>${HADOOP_SLAVE}:8030</value>"
    sed -i '/<value>titan:8030/c\'"${command}" yarn-site.xml
    
    command="\t\t<value>${HADOOP_SLAVE}:8050</value>"
    sed -i '/<value>titan:8050/c\'"${command}" yarn-site.xml

    command="\t\t<value>LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${TERAHEAP_DIR}/allocator/lib:/usr/local/lib64</value>"
    sed -i '/<value>LD_LIBRARY_PATH/c\'"${command}" yarn-site.xml

    echo "${HADOOP_SLAVE}" > slaves

    cd - > /dev/null || exit

    # Copy the files that use cgroup commands and fix the path of the
    # run_cgexec.sh wrapper file
    cp ./scripts/config/hadoop_cgroups/bin/*  ./hadoop-2.4.0/bin/
    cd ./hadoop-2.4.0/bin/ || exit
    local modify_files=(hadoop hdfs mapred rcc yarn)
    for f in "${modify_files[@]}"
    do
      sed -i 's|/opt/carvguest/asplos23_ae/tera_applications/|'"${TERA_APPLICATIONS_REPO}"'/|' "$f"
    done
    cd - > /dev/null || exit
    
    # Copy the files that use cgroup commands and fix the path of the
    # run_cgexec.sh wrapper file
    cp ./scripts/config/hadoop_cgroups/sbin/*  ./hadoop-2.4.0/sbin/
    cd ./hadoop-2.4.0/sbin/ || exit
    local modify_files=(hadoop-daemons.sh httpfs.sh yarn-daemons.sh)
    for f in "${modify_files[@]}"
    do
      sed -i 's|/opt/carvguest/asplos23_ae/tera_applications/|'"${TERA_APPLICATIONS_REPO}"'/|' "$f"
    done
    cd - > /dev/null || exit

  fi
}

download_zookeeper() {
  if [ ! -d zookeeper-3.4.1 ]
  then
    wget https://archive.apache.org/dist/zookeeper/zookeeper-3.4.1/zookeeper-3.4.1.tar.gz >> "${COMPILE_OUT}" 2>&1
    retValue=$?
    message="Download Zookeeper" 
    check ${retValue} "${message}"

    tar xf zookeeper-3.4.1.tar.gz >> "${COMPILE_OUT}" 2>&1
    rm zookeeper-3.4.1.tar.gz

    # Compy the configurations
    cp ./scripts/config/zookeeper/*  ./zookeeper-3.4.1/conf/

    cd ./zookeeper-3.4.1/conf/ || exit
    
    command="dataDir=${ZK_SNAPSHOT_DIR}"
    sed -i '/dataDir=/c\'"${command}" zoo.cfg

    cd - > /dev/null || exit
  fi
}

build_giraph() {
  if [ ! -d Giraph_TeraHeap ]
  then
    git clone git@github.com:jackkolokasis/Giraph_TeraHeap.git >> "${COMPILE_OUT}" 2>&1
    
    retValue=$?
    message="Clone Giraph-TeraHeap" 
    check ${retValue} "${message}"
  fi

  cd ./Giraph_TeraHeap/giraph || exit
  mvn -Phadoop_yarn -Dhadoop.version=2.4.0 -DskipTests -Dcheckstyle.skip clean package install >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Giraph-TeraHeap" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}

build_ldbc_graphalytics() {
  if [ ! -d ldbc_graphalytics ]
  then
    git clone git@github.com:ldbc/ldbc_graphalytics.git >> "${COMPILE_OUT}" 2>&1
    
    retValue=$?
    message="Clone LDBC Graphalytics" 
    check ${retValue} "${message}"
  fi

  cd ldbc_graphalytics || exit

  mvn clean install -Dmaven.buildNumber.skip >> "${COMPILE_OUT}" 2>&1
  
  retValue=$?
  message="Build LDBC Graphalytics" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}

build_ldbc_giraph_bench() {
  if [ ! -d graphalytics-platforms-giraph ]
  then
    git clone git@github.com:jackkolokasis/graphalytics-platforms-giraph.git >> "${COMPILE_OUT}" 2>&1

    retValue=$?
    message="Clone Giraph Benchmark" 
    check ${retValue} "${message}"
  fi

  cd ./graphalytics-platforms-giraph || exit

  mvn -DskipTests clean package >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Giraph Benchmark" 
  check ${retValue} "${message}"

  tar xf graphalytics-1.2.0-giraph-0.2-SNAPSHOT-bin.tar.gz >> "${COMPILE_OUT}" 2>&1
  cp -r ../scripts/config/graphalytics/config/ graphalytics-1.2.0-giraph-0.2-SNAPSHOT/

  cd - > /dev/null || exit
}

# Check for the input arguments
while getopts "abch" opt
do
  case "${opt}" in
    a)
      prepare_certificates
      download_hadoop
      download_zookeeper
      build_giraph
      build_ldbc_graphalytics
      build_ldbc_giraph_bench
      ;;
    b)
      prepare_certificates
      build_giraph
      build_ldbc_graphalytics
      build_ldbc_giraph_bench
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done
