#!/usr/bin/env bash
export LIBRARY_PATH=/home1/public/kolokasis/github/latest_version/smartsweep/teraheap_latest/teraheap/jdk17/build/linux-x86_64-server-release/images/jdk/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/home1/public/kolokasis/github/latest_version/smartsweep/teraheap_latest/teraheap/jdk17/build/linux-x86_64-server-release/images/jdk/allocator/lib/:$LD_LIBRARY_PATH
export PATH=/home1/public/kolokasis/github/latest_version/smartsweep/teraheap_latest/teraheap/jdk17/build/linux-x86_64-server-release/images/jdk/allocator/include/:$PATH
export C_INCLUDE_PATH=/home1/public/kolokasis/github/latest_version/smartsweep/teraheap_latest/teraheap/jdk17/build/linux-x86_64-server-release/images/jdk/allocator/include/:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/home1/public/kolokasis/github/latest_version/smartsweep/teraheap_latest/teraheap/jdk17/build/linux-x86_64-server-release/images/jdk/allocator/include/:$CPLUS_INCLUDE_PATH
"$@"
