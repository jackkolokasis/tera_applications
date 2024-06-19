#!/usr/bin/env bash

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

build_lucene() {
  wget https://github.com/apache/lucene/archive/refs/tags/releases/lucene/9.6.0.tar.gz >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Download Lucene" 
  check ${retValue} "${message}"

  tar xf 9.6.0.tar.gz >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Extract Lucene" 
  check ${retValue} "${message}"

  mv lucene-releases-lucene-9.6.0/ lucene9.6.0/

  cd lucene9.6.0/ || exit
  ./gradlew >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Lucene" 
  check ${retValue} "${message}"

  ./gradlew jar >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Lucene Jar file" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}
      
build_luceneutil_benchmarks() {
  mkdir -p "$LUCENE_BENCH_HOME"

  pushd "$LUCENE_BENCH_HOME" > /dev/null || exit

  if ! [ -d luceneutil ]
  then
    git clone git@github.com:mikemccand/luceneutil.git >> "${COMPILE_OUT}" 2>&1
    retValue=$?
    message="Clone Luceneutil Benchmark Suite" 
    check ${retValue} "${message}"
  fi

  pushd luceneutil > /dev/null || exit

  python3 src/python/setup.py -download >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Download Files" 
  check ${retValue} "${message}"

  pushd "$LUCENE_BENCH_HOME"/data > /dev/null || exit 
  xz -d enwiki-20120502-lines-1k-fixed-utf8-with-random-label.txt.lzma >> "${COMPILE_OUT}" 2>&1

  popd > /dev/null || exit
  popd > /dev/null || exit
  popd > /dev/null || exit

  pushd "$LUCENE_BENCH_HOME"/lucene_util > /dev/null || exit
  # Go to this commit that support JDK17
  git checkout f7a0882

  python3 src


  popd > /dev/null || exit
}

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-h]"
    echo
    echo "Options:"
    echo "      -a  Compile and build both Lucene and benchmarks"
    echo "      -l  Compile and build only Lucene"
    echo "      -b  Compile and build only benchmarks"
    echo "      -h  Show usage"
    echo

    exit 1
}

# These benchmarks are from Shoaib
build_benchmarks() {

  # Check if the target directory already exists
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR does not exist. Cloning the repository..."
    git clone $REPO_URL $TARGET_DIR
  else
    echo "Directory $TARGET_DIR already exists. Skipping clone."
  fi

  git clone git@carvgit.ics.forth.gr:kolokasis/lucene_benchmarks.git >> "${COMPILE_OUT}" 2>&1

  # Produce jar files
  ./gradlew assemble
}
  
echo "-----------------------------------"
echo "Compilation output messages are here: ${COMPILE_OUT}"
echo "-----------------------------------"
echo 

# Check for the input arguments
while getopts "albh" opt
do
  case "${opt}" in
    a)
      build_lucene
      build_benchmarks
      ;;
    l)
      build_lucene
      ;;
    b)
      build_benchmarks
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done
