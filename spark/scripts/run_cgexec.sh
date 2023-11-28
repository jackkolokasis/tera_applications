#!/usr/bin/env bash

#export LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/allocator/lib:$LIBRARY_PATH
#export LD_LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/allocator/lib:$LD_LIBRARY_PATH
#export PATH=/opt/carvguest/asplos23_ae/teraheap/allocator/include/:$PATH
#
#export LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/tera_malloc/lib:$LIBRARY_PATH
#export LD_LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/tera_malloc/lib:$LD_LIBRARY_PATH
#export PATH=/opt/carvguest/asplos23_ae/teraheap/tera_malloc/include/:$PATH

export LIBRARY_PATH=/spare/perpap/teraheap/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/spare/perpap/teraheap/allocator/lib:$LD_LIBRARY_PATH
export PATH=/spare/perpap/teraheap/allocator/include:$PATH
export C_INCLUDE_PATH=/spare/perpap/teraheap/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/spare/perpap/teraheap/allocator/include:$CPLUS_INCLUDE_PATH

export LIBRARY_PATH=/spare/perpap/teraheap/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/spare/perpap/teraheap/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=/spare/perpap/teraheap/tera_malloc/include:$PATH
export C_INCLUDE_PATH=/spare/perpap/teraheap/tera_malloc/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/spare/perpap/teraheap/tera_malloc/include:$CPLUS_INCLUDE_PATH

LD_PRELOAD=/usr/lib64/libjemalloc.so.1
export LD_PRELOAD

"$@"
#numactl --cpunodebind=0 "$@"
