#!/usr/bin/env bash

cd ../benchmarks || exit
"$@"
cd - > /dev/null
