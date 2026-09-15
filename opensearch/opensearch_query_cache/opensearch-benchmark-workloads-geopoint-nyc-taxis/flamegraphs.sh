#!/bin/bash

echo "Kicked off iostat & vmstat"
pids=$(ps aux | grep '[O]penSearch' | awk '{print $2}')
OS_PID=$(echo "$pids" | sed -n '2p')
echo "Detected OS PID as : $OS_PID"

if [ -z "$OS_PID" ]; then 
    # happens when running from tar install
    echo "Retrying to get OS PID..."
    OS_PID=$pids
    echo "Detected OS PID as : $OS_PID"
fi

mkdir /home/ec2-user/flamegraphs

if [ ! -d "/home/ec2-user/async-profiler-3.0-linux-x64" ]; then
    cd /home/ec2-user
    wget https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz
    tar -xzvf async-profiler-3.0-linux-x64.tar.gz
fi

cd /home/ec2-user/async-profiler-3.0-linux-x64/bin

while true; do 
    currMin=$(date +%m-%dT%H-%M)
    outputFile=/home/ec2-user/flamegraphs/flamegraph-${currMin}.html
    ./asprof -d 300 -f "$outputFile" "$OS_PID"
    sleep 600
done