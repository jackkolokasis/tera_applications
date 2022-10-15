#!/usr/bin/env bash

#export LIBRARY_PATH=/home1/public/kolokasis/jdk8u/teracache/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/home1/public/kolokasis/jdk8u/teracache/allocator/lib:$LD_LIBRARY_PATH
export PATH=/home1/public/kolokasis/jdk8u/teracache/allocator/include/:$PATH
#export C_INCLUDE_PATH=/home1/public/kolokasis/jdk8u/teracache/allocator/include/:$C_INCLUDE_PATH
#export CPLUS_INCLUDE_PATH=/home1/public/kolokasis/jdk8u/teracache/allocator/include/:$CPLUS_INCLUDE_PATH

#numactl --cpunodebind=0 "$@"
"$@"
