import sys
import random

querySrcs = [
    #"datasets/L_5m", 
    #"datasets/M_5m", 
    #"datasets/H_5m", 
    #"datasets/LL_5m", 
    #"datasets/MM_5m", 
    #"datasets/HH_5m",
     "terms/LOWT",
     "terms/MEDT",
     "terms/HIGHT",   
]

if (len(sys.argv) != 3):
    print("Usage: python3 mix_queries.py [noQueries] [fileToSaveQsTo]")
    exit(1)

noQsTotal = int(sys.argv[1])
fileToSaveQsTo = sys.argv[2]

files = [open(q) for q in querySrcs]

with open(fileToSaveQsTo, 'w+') as dst:
    noQsMade = 0
    while noQsMade < noQsTotal:
        n = random.randint(1, 20)

        # truncate n to make sure exactly the number of queries specified is generated
        if noQsMade + n > noQsTotal:
            n = noQsTotal - noQsMade

        # read a random amount of queries from a random query src
        i = random.randrange(len(files))
        file = files[i]
        for i in range(n):
            dst.write(file.readline())

        noQsMade += n

# clean up
for f in files:
    f.close()
