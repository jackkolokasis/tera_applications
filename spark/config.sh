export JAVA_HOME="${HOME}/github/teracache/openjdk-8/openjdk8/build/linux-x86_64-normal-server-release/jdk"
export C_INCLUDE_PATH=${JAVA_HOME}/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${JAVA_HOME}/include:$CPLUS_INCLUDE_PATH
TERA_HEAP_REPO="${HOME}/github/teracache"
TERA_APPS_REPO="${HOME}/tera_applications"
SPARK_VERSION="spark-2.3.0"
SPARK_DIR="${TERA_APPS_REPO}/spark/${SPARK_VERSION}"
COMPILE_OUT="${TERA_APPS_REPO}/spark/compile.out"
