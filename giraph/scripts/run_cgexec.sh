#!/usr/bin/env bash

export LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/allocator/lib:$LD_LIBRARY_PATH
export PATH=/opt/carvguest/asplos23_ae/teraheap/allocator/include/:$PATH
export LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/carvguest/asplos23_ae/teraheap/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=/opt/carvguest/asplos23_ae/teraheap/tera_malloc/include/:$PATH

"$@"
