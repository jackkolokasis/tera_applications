#!/usr/bin/env bash

TERAHEAP_REPO=$HOME/teraheap

export LIBRARY_PATH=$TERAHEAP_REPO/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=$TERAHEAP_REPO/allocator/lib:$LD_LIBRARY_PATH
export PATH=$TERAHEAP_REPO/allocator/include:$PATH
export C_INCLUDE_PATH=$TERAHEAP_REPO/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$TERAHEAP_REPO/allocator/include:$CPLUS_INCLUDE_PATH

export LIBRARY_PATH=$TERAHEAP_REPO/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=$TERAHEAP_REPO/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=$TERAHEAP_REPO/tera_malloc/include:$PATH
export C_INCLUDE_PATH=$TERAHEAP_REPO/tera_malloc/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$TERAHEAP_REPO/tera_malloc/include:$CPLUS_INCLUDE_PATH

#LD_PRELOAD=/usr/lib64/libjemalloc.so.1
#export LD_PRELOAD

"$@"
#numactl --cpunodebind=0 "$@"
