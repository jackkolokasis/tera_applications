#!/usr/bin/env bash

. ./conf.sh

DOWNLOAD_PATH=$1

# KDD2012
wget -P "${DOWNLOAD_PATH}" https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/binary/kdd12.bz2

# Extract the dataset
if ! [ -x "$(command -v unxz)" ]
then
  sudo yum install xz
fi

cd "${DOWNLOAD_PATH}" || exit

unxz kdd12.xz

cd - > /dev/null || exit
