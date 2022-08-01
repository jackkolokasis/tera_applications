#!/usr/bin/env bash

. ./config.sh
# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ $1 -ne 0 ]
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
    echo "      -a  Compile and build both Spark and SparkBench Suite" 
    echo "      -s  Compile and build only Spark" 
    echo "      -b  Compile and build only SparkBench suite" 
    echo "      -c  Clean Spark and SparkBench suite"
    echo "      -h  Show usage"
    echo

    exit 1
}

prepare_certificates() {
  cp -r ../util/certificates/lib ${JAVA_HOME}/../

  # Create the security directory if it does not exist
  if [ ! -d "${JAVA_HOME}/lib/security/" ]
  then 
    mkdir -p ${JAVA_HOME}/lib/security
  fi 

  cp ../util/certificates/blacklisted.certs ${JAVA_HOME}/lib/security/
  cp ../util/certificates/cacerts ${JAVA_HOME}/lib/security/
  cp ../util/certificates/nss.cfg ${JAVA_HOME}/lib/security/
  cp ../util/certificates/java.policy ${JAVA_HOME}/lib/security/
  cp ../util/certificates/java.security ${JAVA_HOME}/lib/security/
}

spark_dependencies() {
  if [ "$SPARK_VERSION" == "spark-2.3.0" ]
  then
    if [ -d "~/.m2" ]
    then
      if [[ -n $(find ~/.m2 -name "nvmUnsafe*") ]]
      then
        rm -rf ~/.m2/repository/NVMUnsafePath
      fi
    fi

    cd ${HUGE_HEAP_REPO}/nvmUnsafe/
    ./build.sh ${COMPILE_OUT} ${SPARK_DIR}
    cd - > /dev/null
  fi
}

build_spark() {
  cd ${SPARK_DIR} || exit
  ./compile.sh >> ${COMPILE_OUT} 2>&1
  retValue=$?
  message="Build Spark" 
  check ${retValue} "${message}"
  cd - > /dev/null
}

benchmark_dependencies() {
  if [[ ! -n $(find ~/.m2 -name "wikixmlj*") ]]
  then 
    git clone  https://github.com/synhershko/wikixmlj.git >> ${COMPILE_OUT} 2>&1

    cd wikixmlj
    mvn package -Dmaven.test.skip=true >> {COMPILE_OUT} 2>&1
    mvn install -Dmaven.test.skip=true >> {COMPILE_OUT} 2>&1
    cd - >> compile.out 2>&1

    rm -rf ./wikixmlj >> ${COMPILE_OUT} 2>&1
  fi
}

build_benchmarks() {
  ./spark-bench/bin/build-all.sh >> ${COMPILE_OUT} 2>&1
  retValue=$?
  message="Build Spark Benchmarks" 
  check ${retValue} "${message}"
}

clean_all() {
  cd ${SPARK_DIR}
  ./build/mvn clean >> ${COMPILE_OUT} 2>&1
  
  retValue=$?
  message="Clean Spark" 
  check ${retValue} "${message}"

  cd - >> ${COMPILE_OUT} 2>&1

  cd ./spark-bench
  mvn clean >> ${COMPILE_OUT} 2>&1

  retValue=$?
  message="Clean SparkBench suite" 
  check ${retValue} "${message}"

  cd - >> ${COMPILE_OUT} 2>&1
}

# Check for the input arguments
while getopts "asbch" opt
do
  case "${opt}" in
    a)
      prepare_certificates
      spark_dependencies
      build_spark
      benchmark_dependencies
      build_benchmarks
      ;;
    s)
      prepare_certificates
      spark_dependencies
      build_spark
      ;;
    b)
      benchmark_dependencies
      build_benchmarks
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
