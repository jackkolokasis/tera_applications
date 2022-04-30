#!/bin/bash
set -u
DIR=`dirname "$0"`
DIR=`cd "${DIR}/.."; pwd`
cd $DIR

mvn package -P spark3.2.1

result=$?

if [ $result -ne 0 ]; then
    echo "Build failed, please check!"
else
    echo "Build all done!"
fi
