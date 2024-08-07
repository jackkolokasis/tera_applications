import os
import sys
import tabulate
import statistics
import pandas as pd
import re
import math

resultsDir = "results/raw-lucene"
configs = [f"{heapLoc}_{workload}_100k" for heapLoc in ["DRAM", "PM"]
                                        for workload in ["L", "M", "H", "LL", "MM", "HH"]]
noRepeat = 5

table = {}

table["headers"] = [f"Repeat {i}" for i in range(1, noRepeat+1)]

for configName in configs:
    configResults = []

    for i in range(1, noRepeat+1):
        with open(f"{resultsDir}/{configName}_{i}") as file:
            configResults.append(int(file.readlines()[-1].split(" ")[-2]))

    table[configName] = configResults

print(table)
compiledData = pd.DataFrame(table).set_index("headers")
print(compiledData)
compiledData.to_csv(f"results/compile-lucene.csv")
