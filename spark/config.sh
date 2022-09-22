# Set JAVA_HOME to use TeraHeap JVM
export JAVA_HOME="${HOME}/jdk8u/teracache/jdk8u345/build/linux-x86_64-normal-server-release/jdk"
# Set up the path of TeraHeap repo
TERA_HEAP_REPO="${HOME}/jdk8u/teracache"
# Set up the path of TeraHeap applications
TERA_APPS_REPO="/opt/kolokasis/tera_applications"

########################################
# DO NOT CHANGE THE FOLLOWING VARIABLES
########################################
SPARK_VERSION="spark-2.3.0"
SPARK_DIR="${TERA_APPS_REPO}/spark/${SPARK_VERSION}"
COMPILE_OUT="${TERA_APPS_REPO}/spark/compile.out"
