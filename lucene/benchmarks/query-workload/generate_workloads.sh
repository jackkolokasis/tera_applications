if [ $# -lt 1 ]; then
    echo "Usage: ./generate_workloads.sh [directory]"
    exit
fi

./query_gen_multicore.sh H 1 32 1250 > $1/H_40k
./query_gen_multicore.sh HH 2 32 1250 > $1/HH_40k
./query_gen_multicore.sh M 1 32 1250 > $1/M_40k
./query_gen_multicore.sh MM 2 32 1250 > $1/MM_40k
./query_gen_multicore.sh L 1 32 1250 > $1/L_40k
./query_gen_multicore.sh LL 2 32 1250 > $1/LL_40k
