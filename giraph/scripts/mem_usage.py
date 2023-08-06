#!/usr/bin/env python3
###################################################
#
# file: mem_usage.py
#
# @Author:   Iacovos G. Kolokasis
# @Version:  01-06-2023
# @email:    kolokasis@ics.forth.gr
#
# Plot memory usage. Used memory and page cache
#
###################################################

import optparse
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import config
import numpy as np

usage = "usage: %prog [options]"
parser = optparse.OptionParser(usage=usage)
parser.add_option("-i", "--inputFile", metavar="PATH", dest="inFile",
                  help="Input CSV File")
parser.add_option("-o", "--outFile", metavar="PATH", dest="outFile",
                  default="output.svg", help="Output PNG File")
parser.add_option("-t", "--title", metavar="PATH", dest="title",
                  help="Plot title")
(options, args) = parser.parse_args()

used_mem = []
page_cache = []

'''
The file is in the following format:
               total        used        free      shared  buff/cache   available
Mem:              15           3           9           0           3          12
Swap:              1           0           1
'''

# Open the file
with open(options.inFile, 'r') as file:
    # Read the file line by line
    for line in file:
        if "total" in line or "Swap" in line:
            continue

        used_mem.append(int(line.split()[2].strip()))  # Convert to integer
        page_cache.append(int(line.split()[5].strip()))  # Convert to integer

indices = list(range(1, len(used_mem) + 1))  # Generate indices from 1 to len(dirty_cards)

# Plot figure with fix size
fig, ax = plt.subplots(figsize=config.halffigsize)

ax.plot(indices, used_mem, color=config.B_color_cycle[0],
         label='Used Memory', linewidth=0.8)

ax.plot(indices, page_cache, color=config.B_color_cycle[1],
         label='Page Cache', linewidth=0.8)

# Axis name
ax.set_ylabel('Memory (GB)', ha="center", fontsize=config.fontsize)
plt.xlabel('Time (s)', fontsize=config.fontsize)

# Legend
legend = ax.legend(loc='upper left', bbox_to_anchor=(0.18, 1.18),
                   fontsize=config.fontsize, ncol=3, handletextpad=0.1,
                   columnspacing=0.5, framealpha=1)

legend.get_frame().set_linewidth(config.edgewidth)
legend.get_frame().set_edgecolor(config.edgecolor)

# Save figure
plt.savefig('%s' % options.outFile, bbox_inches='tight', dpi=900)
