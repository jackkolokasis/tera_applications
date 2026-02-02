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
# - g: # of gc threads          [Default is 16]
# - m: Memory budget            [20G, 40G, 60G, 208G]
# - t: Enable TeraHeap          [Native will run if not passed]
# - D: Disable the QueryCache   [Default is enabled]
# - e: # of QueryCache entries  [Default is 3000000]
# - s: Enable statistics        [Default is disabled]
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
##### End of Default Configuration

# Check for the input arguments
while getopts "g:m:tDe:s" opt
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
    *)
      echo "wrong arguments"
      exit 1
      ;;
  esac
done

if $ENABLE_TERAHEAP; then
  # TERAHEAP CONF

  case "${MEM_BUDGET}" in
    "20G")
      H1_SIZE=( 11 )
      ;;
    "40G")
      H1_SIZE=( 22 )
      ;;
    "60G")
      H1_SIZE=( 33 )
      ;;
    "208G")
      H1_SIZE=( 115 )
      ;;
    *)
      echo "MEM_BUDGET: configuration not recognized - $MEM_BUDGET"
      exit 1
  esac

  QUERY_CACHE=200
else
  # NATIVE CONF

  # In native we reserve 8GB for Page Cache and the rest for H1
  case "${MEM_BUDGET}" in
    "20G")
      H1_SIZE=( 12 )
      ;;
    "40G")
      H1_SIZE=( 32 )
      ;;
    "60G")
      H1_SIZE=( 52 )
      ;;
    "208G")
      H1_SIZE=( 200 )
      ;;
    *)
      echo "MEM_BUDGET: configuration not recognized - $MEM_BUDGET"
      exit 1
  esac

  QUERY_CACHE=$(( $H1_SIZE / 2 ))
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
