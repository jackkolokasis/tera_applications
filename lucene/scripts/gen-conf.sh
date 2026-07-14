#!/usr/bin/env bash

###################################################
#
# file: gen-conf.sh
#
# @Author:   Giannis Melidonis
# @Version:  22-1-26
# @email:    imel@ics.forth.gr
#
# @brief: Generate configuration for a run
#
###################################################

# == Documentation
# - H1_SIZE: Heap size '-Xms' is in GB e.g., 54 -> 54GB
#
# Arguments:
# - g: # of gc threads                  [Default is 16]
# - m: Memory budget xG (x is a number) [Default is 60G]
# - t: Enable TeraHeap                  [Native will run if not passed]
# - D: Disable the QueryCache           [Default is enabled]
# - e: # of QueryCache entries          [Default is 3000000]
# - s: Enable statistics                [Default is disabled]
# - H: Ratio (%) Heap/PageCache (TH)    [Default is 55]
# - Q: Ratio (%) QueryCache/Heap (N)    [Default is 50]
# -----------------

##### Default Configuration:
ENABLE_TERAHEAP=false
# Number of garbage collection threads
GC_THREADS=16
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
MEM_BUDGET=60G
# Enable the QueryCache -> "ENABLE" | Disable QueryCache -> "DISABLE"
CACHE=ENABLE
# Query Cache's number of entries
CACHE_ENTRIES=3000000
# Enable statistics
ENABLE_STATS=false
# Ratio (%) of Heap/PageCache for TeraHeap configuration
TH_HEAP_RATIO=55
# Ratio (%) of QueryCache/Heap for Native configuration
N_QCACHE_RATIO=50
##### End of Default Configuration

# Check for the input arguments
while getopts "g:m:tDe:sH:Q:" opt
do
  case "${opt}" in
    g)
      GC_THREADS=${OPTARG}
      ;;
    m)
      MEM_BUDGET="${OPTARG}"
      ;;
    t)
      ENABLE_TERAHEAP=true
      ;;
    D)
      CACHE=DISABLE
      ;;
    e)
      CACHE_ENTRIES=${OPTARG}
      ;;
    s)
      ENABLE_STATS=true
      ;;
    H)
      TH_HEAP_RATIO="${OPTARG}"
      ;;
    Q)
      N_QCACHE_RATIO="${OPTARG}"
      ;;
    *)
      echo "wrong arguments"
      exit 1
      ;;
  esac
done

if $ENABLE_TERAHEAP; then
  # TERAHEAP CONF

  if [[ $MEM_BUDGET =~ ^[0-9]+G$ ]]; then
    memory=${MEM_BUDGET%G}
    # Rounded down as in general more PageCache --> better performance
    heap=$(( memory * TH_HEAP_RATIO / 100 ))

    H1_SIZE=( $heap )
  else
    echo "MEM_BUDGET: configuration not recognized - $MEM_BUDGET"
  fi

  QUERY_CACHE=200
else
  # NATIVE CONF

  if [[ $MEM_BUDGET =~ ^[0-9]+G$ ]]; then
    memory=${MEM_BUDGET%G}
    # In native we reserve 8GB for Page Cache and the rest for H1
    heap=$(( memory - 8 ))

    H1_SIZE=( $heap )
  else
    echo "MEM_BUDGET: configuration not recognized - $MEM_BUDGET"
  fi

  QUERY_CACHE=$(( $H1_SIZE * N_QCACHE_RATIO / 100 ))
fi

{
  echo "#!/usr/bin/env bash"
  echo
  echo "#########################"
  echo "# Auto-generated script #"
  echo "#         #####         #"
  echo "#  Do NOT modify this!  #"
  echo "#########################"

  cat ./conf.tmpl.sh

  echo "# Generated"
  echo "# ----------------------"
  echo
  echo "ENABLE_TERAHEAP=${ENABLE_TERAHEAP}"
  echo
  echo "GC_THREADS=${GC_THREADS}"
  echo "H1_SIZE=( ${H1_SIZE[@]} )"
  echo "MEM_BUDGET=${MEM_BUDGET}"
  echo
  echo "CACHE=${CACHE}"
  echo "QUERY_CACHE=${QUERY_CACHE}"
  echo "CACHE_ENTRIES=${CACHE_ENTRIES}"
  echo
  echo "ENABLE_STATS=${ENABLE_STATS}"
  echo

} > ./conf.sh
