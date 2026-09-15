import requests 
import time 
import datetime

output = "/home/ec2-user/cluster_resource_usage.csv"

with open(output, "a") as f: 
    f.write("Time, CPU, JVM pressure, JVM max (B), Pct of time on old GC, Pct of time on young GC\n")

last_gc_old = -1
last_gc_young = -1

sleep_time = 15

while True: 
    cpu_result = requests.get("http://localhost:9200/_nodes/stats/process?pretty").json()
    jvm_result = requests.get("http://localhost:9200/_nodes/stats/jvm?pretty").json()

    node_id = list(cpu_result["nodes"].keys())[0]
    print("Found node ID = ", node_id)

    cpu_usage = cpu_result["nodes"][node_id]["process"]["cpu"]["percent"]
    jvm_pressure = jvm_result["nodes"][node_id]["jvm"]["mem"]["heap_used_percent"]
    jvm_max = jvm_result["nodes"][node_id]["jvm"]["mem"]["heap_max_in_bytes"]

    total_gc_old = jvm_result["nodes"][node_id]["jvm"]["gc"]["collectors"]["old"]["collection_time_in_millis"] 
    total_gc_young = jvm_result["nodes"][node_id]["jvm"]["gc"]["collectors"]["young"]["collection_time_in_millis"] 
    gc_old_percent = (total_gc_old - last_gc_old) / (1000 * sleep_time)
    gc_young_percent = (total_gc_young - last_gc_young) / (1000 * sleep_time)
    last_gc_old = total_gc_old
    last_gc_young = total_gc_young
    now = datetime.datetime.now()
    line = "{},{},{},{},{},{}\n".format(now, cpu_usage, jvm_pressure, jvm_max, gc_old_percent, gc_young_percent)
    with open(output, "a") as f: 
        f.write(line) 
    print("sleeping...")
    time.sleep(sleep_time)