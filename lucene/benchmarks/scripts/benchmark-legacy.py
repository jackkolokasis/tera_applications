#!/usr/bin/python3

# wrote this script on tuesday 27/06/2023, but the experiments we're going to run are actually
# simple enough that a bash script suffices. this is kept in case we do something more complicated.

import subprocess
import statistics

# note: we assume here that the java classpath has been set appropriately already

# ---------------- PREAMBLE -----------------

def run_command(command):
    print(f"Running command: {command}")
    p = subprocess.run(command, shell=True)
    if (p.returncode != 0):
        print(f"Command completed with abnormal return code {p.returncode}; aborting")
        abort()
    else:
        print(f"Command completed successfully")

def run_command_get_stdout(command):
    print(f"Running command: {command}")
    p = subprocess.run(command, shell=True, stdout=subprocess.PIPE, text=True)
    print(p.stdout)
    if (p.returncode != 0):
        print(f"Command completed with abnormal return code {p.returncode}; aborting")
        abort()
    else:
        print(f"Command completed successfully")
        return p.stdout

def abort():
    exit(1)

# ------- PARAMETERS (hardcoded to keep it simple) ----------

# TODO: add JVM options here later
indexConfigs = {
    "def": "-d docs/test1.txt -de -fm"
}

searchConfigs = {
    "def": "-q query-workload/test -ds"
}

noRepeatIndexing = 0
noRepeatSearching = 5

# TODO: implement notifySSH later
#notifySSH = False

# ---------- EXPERIMENT -------------

# for each indexer config, run indexing (for as many repeats as requested) then run each search config on that
# index (for as many repeats as requested)
indexingTimes = {}
searchingTimes = {}

for indexConfigName, indexConfig in indexConfigs.items():
    indexingTimes[indexConfigName] = []
    searchingTimes[indexConfigName] = {}

    # run indexing
    for _ in range(0, noRepeatIndexing):
        out = run_command_get_stdout(f"java IndexFiles -i index{indexConfigName} {indexConfig}")
        indexingTimes[indexConfigName].append(int(out.split("\n")[-2].split(" ")[-2])) # capture output and extract the time from it
    
    # run searching
    for searchConfigName, searchConfig in searchConfigs.items():
        searchingTimes[indexConfigName][searchConfigName] = []

        for _ in range(0, noRepeatSearching):
            out = run_command_get_stdout(f"java EvaluateQueries -i index{indexConfigName} {searchConfig}")
            searchingTimes[indexConfigName][searchConfigName].append(int(out.split("\n")[-2].split(" ")[-2]))
    
    # cleanup: delete the index
    run_command(f"rm -rf index{indexConfigName}")

# ----------- REPORT RESULTS ------------

print("\n----------- FINAL RESULTS ------------\n")

notFirst = False
for indexConfigName in indexConfigs.keys():
    if notFirst:
        print("\n")
        notFirst = True

    print(f"Indexing config {indexConfigName} times (ms):")
    print(indexingTimes[indexConfigName])
    print(f"Average: {statistics.mean(indexingTimes[indexConfigName])} ms")
    print(f"Std dev: {statistics.stdev(indexingTimes[indexConfigName])} ms")

    for searchConfigName in searchConfigs.keys():
        print()
        print(f"Search config {searchConfigName} times on this indexing config (ms):")
        print(searchingTimes[indexConfigName][searchConfigName])
        print(f"Average: {statistics.mean(searchingTimes[indexConfigName][searchConfigName])} ms")
        print(f"Std dev: {statistics.stdev(searchingTimes[indexConfigName][searchConfigName])} ms")     

# ----------- CLEANUP -------------
