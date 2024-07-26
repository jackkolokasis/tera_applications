#!/bin/bash

# returns a random word from the (H,M,L) category
# expects a terms directory in ./ with HIGH LOW and MED terms in the wikipedia corpus
# currently generates either 1-term or 2-term AND/OR queries
# note: since SPIRIT doesn't support OR queries, script has been modified;
# there is no distinction between OR and AND queries

workload=$1 # H,M,L,HH,HL,HM,LL,LM,MM
type_workload=$2 # 1-->single-term, 2-->two-term-AND
total=$3

SCRIPT_DIR=`dirname "$(readlink -f "$0")"`

# check for the right argument number
if [ $# -lt 3 ]; then
	echo "workload->H/M/L/HH/HL/HM/LL/LM/MM type->1:1-term/2:AND/3:OR #queries"
	exit
fi

# stop if workload specifies 2-term queries but type_workload is 1
if [ $type_workload -eq 1 ]; then
	if [ "${workload:1:1}" != '' ]; then
		echo "If you are using two letters in your query type (e.g. HL) you cannot use query operation 1 (single-term). You must either use 2 or 3 (AND or OR respectively)."
		exit
	fi
fi

# need two words for 2-term queries and one word for 1-term
if [ $type_workload -ge 2 ]; then
	word1_type="${workload:0:1}"
	word2_type="${workload:1:1}"
else
	word1_type="$workload"
fi

# handle 1-term query workload
word=''
if [ $type_workload -eq 1 ]; then
	for i in `seq $total`; do
		word=`$SCRIPT_DIR/get_word.sh $word1_type`
		echo $word
	done
fi

# handle 2-term query workload
word1=''
word2=''
if [ $type_workload -ge 2 ]; then
	for i in `seq $total`; do
		word1=`$SCRIPT_DIR/get_word.sh $word1_type`
		word2=`$SCRIPT_DIR/get_word.sh $word2_type`
		printf "$word1 $word2"
		echo
	done
fi
