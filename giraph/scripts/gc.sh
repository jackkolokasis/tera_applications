#!/usr/bin/env bash

processId=$(jps |\
        grep "YarnChild" |\
        awk '{split($0,array," "); print array[1]}')

echo $processId
jcmd $processId GC.run
