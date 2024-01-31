#!/bin/bash
set -u
DIR=$(dirname "$0")
DIR=$(cd "${DIR}/.."; pwd)
SPARK_VERSION=${1:-"spark3.3.0"}
cd "$DIR" || exit

mvn clean package -P "$SPARK_VERSION"

result=$?

if [ $result -ne 0 ]; then
    echo "Build failed, please check!"
else
    echo "Build all done!"
fi
