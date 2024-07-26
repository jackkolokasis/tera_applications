#!/usr/bin/python3

import datetime
import subprocess
import argparse
import sys

classpath :=/home1/public/dimklin/lucene9.6/dev-tools/missing-doclet/build/libs/missing-doclet-1.0.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/core.tests/build/libs/lucene-core.tests-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-test-framework/lucene-test-framework-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/asm-7.2.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/morfologik-polish-2.1.9.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/antlr4-runtime-4.11.1.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/asm-tree-7.2.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/icu4j-70.1.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/morfologik-fsa-2.1.9.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/hppc-0.9.1.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/commons-codec-1.13.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/asm-analysis-7.2.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/asm-commons-7.2.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/morfologik-ukrainian-search-4.9.1.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/opennlp-tools-1.9.1.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules-thirdparty/morfologik-stemming-2.1.9.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-common-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-phonetic-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-luke-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-nori-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-memory-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-classification-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-queryparser-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-grouping-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-sandbox-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-morfologik-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-expressions-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-core-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-backward-codecs-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-highlighter-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-icu-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-facet-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-monitor-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-benchmark-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-misc-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-join-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-opennlp-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-smartcn-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-suggest-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-replicator-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-spatial-extras-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-spatial3d-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-kuromoji-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-analysis-stempel-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-codecs-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-queries-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/join/build/libs/lucene-join-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/backward-codecs/build/libs/lucene-backward-codecs-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/queryparser/build/libs/lucene-queryparser-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/replicator/build/libs/lucene-replicator-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/spatial3d/build/libs/lucene-spatial3d-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/codecs/build/libs/lucene-codecs-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/test-framework/build/libs/lucene-test-framework-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/sandbox/build/libs/lucene-sandbox-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/spatial-test-fixtures/build/libs/lucene-spatial-test-fixtures-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/opennlp/build/libs/lucene-analysis-opennlp-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/nori/build/libs/lucene-analysis-nori-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/common/build/libs/lucene-analysis-common-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/stempel/build/libs/lucene-analysis-stempel-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/smartcn/build/libs/lucene-analysis-smartcn-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/phonetic/build/libs/lucene-analysis-phonetic-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/morfologik.tests/build/libs/lucene-analysis-morfologik.tests-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/kuromoji/build/libs/lucene-analysis-kuromoji-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/icu/build/libs/lucene-analysis-icu-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis/morfologik/build/libs/lucene-analysis-morfologik-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution.tests/build/libs/lucene-distribution.tests-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/misc/build/libs/lucene-misc-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-backward-codecs-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-suggest-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/morfologik-polish-2.1.9.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-queries-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-nori-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-phonetic-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-memory-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-core-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/morfologik-stemming-2.1.9.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-stempel-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-queryparser-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-opennlp-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-smartcn-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-luke-9.6.0-SNAPSHOT-standalone.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-sandbox-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-common-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/morfologik-ukrainian-search-4.9.1.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-morfologik-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-misc-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/commons-codec-1.13.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-highlighter-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-codecs-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/opennlp-tools-1.9.1.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-kuromoji-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/icu4j-70.1.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/morfologik-fsa-2.1.9.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/lucene-luke-9.6.0-SNAPSHOT/lucene-analysis-icu-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/libs/lucene-luke-9.6.0-SNAPSHOT-standalone.jar:/home1/public/dimklin/lucene9.6/lucene/luke/build/libs/lucene-luke-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/classification/build/libs/lucene-classification-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/benchmark/build/libs/lucene-benchmark-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/core/build/libs/lucene-core-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/facet/build/libs/lucene-facet-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/monitor/build/libs/lucene-monitor-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/memory/build/libs/lucene-memory-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/spatial-extras/build/libs/lucene-spatial-extras-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/queries/build/libs/lucene-queries-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/highlighter/build/libs/lucene-highlighter-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/expressions/build/libs/lucene-expressions-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/suggest/build/libs/lucene-suggest-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/grouping/build/libs/lucene-grouping-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/analysis.tests/build/libs/lucene-analysis.tests-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/gradle/wrapper/gradle-wrapper.jar:/home1/public/dimklin/lucene9.6/buildSrc/build/libs/buildSrc.jar:/home1/public/dimklin/lucene9.6/lucene/demo/build/libs/lucene-demo-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene9.6/lucene/distribution/build/packages/lucene-9.6.0-SNAPSHOT-itests/modules/lucene-demo-9.6.0-SNAPSHOT.jar:/home1/public/dimklin/lucene_benchmarks/anu_bench/src/customCodecs/NoCompressionCodec.jar

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
    subprocess.run(f"ssh {notifyDevice} 'echo \"Problem occurred, experiment aborted!\" >> {notifyFile}'", shell=True)
    exit(1)

def send_msg_ssh(msg):
    run_command(f"ssh {notifyDevice} 'echo \"{datetime.datetime.now()}: {msg}\" >> {notifyFile}'")

# TODO: THIS DOESN'T WORK FOR SOME REASON
def run_command_sudo(command):
    if args.pw == None:
        print("Sudo command needs to be run but password not provided! Aborting.")
        abort()
    else:
        run_command(f"echo {args.pw} | sudo -S {command}")

# ---------- PREAMBLE -------------

parser = argparse.ArgumentParser(prog = "Lucene benchmarking", 
                                 description = "Simple benchmarking script")

parser.add_argument("-r", required=True, dest="resultsDir", help="Directory to store results")
parser.add_argument("-n", required=True, dest="notify", 
                          metavar=("SSHSERVER", "FILENAME"),
                          nargs=2,
                          help="If passed, script will write to the file specified on the SSH server " + \
                               "specified, notifying the user of the progress of the experiment. " + \
                               "Needs passwordless access to the server to be set up on this machine.")
parser.add_argument("-re", dest="repeats", help="Number of repeats")
parser.add_argument("--send-results-copy", dest="remoteResultsDir", 
                                           metavar=("DIRNAME"),
                                           default=None,
                                           help="Sends a copy of the evaluation results to the specified directory " + \
                                                "on the remote device spacified with -n. Needs -n option to be used.")
parser.add_argument("-pw", dest="pw", help="Password, to authorise the script to run commands as SUDO. " + \
                                                 "Note that running the script itself as SUDO doesn't tend to work because, " + \
                                                 "among other possible issues, root user may not have configured SSH access " + \
                                                 "to the lab machines so the remote notification system fails.")

args = parser.parse_args()

resultsDir = args.resultsDir

notifyDevice = args.notify[0]
notifyFile = args.notify[1]

noRepeats = int(args.repeats)

# ---------- EXPERIMENT -------------

workloads = ["L", "M", "H", "LL", "MM", "HH"]

docsPerWorkload = {
    "L": "100k",
    "M": "100k",
    "H": "10k",
    "LL": "100k",
    "MM": "100k",
    "HH": "10k"
}

run_command(f"ssh {notifyDevice} 'touch -a {notifyFile}'")
if args.remoteResultsDir != None:
    run_command(f"ssh {notifyDevice} 'mkdir -p {args.remoteResultsDir}'")
send_msg_ssh("Started new experiment")

# example: DRAM only, DPF, merged index
for w in workloads:
    send_msg_ssh(f"DRAM with workload {w} starting")
    for i in range(1, noRepeats+1):
        runName = f"DRAM_{w}_{docsPerWorkload[w]}_{i}"

        run_command("numactl --cpunodebind=1 --membind=1 -- " + \
                    f"java -XX:-TieredCompilation -server -Xms20g -Xmx20g -cp {classpath} " + \
                    f"EvaluateQueries -i index-wikilines-merged-dpf -q query-workload/{w}_{docsPerWorkload[w]}.txt -ds -ar -dc -ws 5 " + \
                    f"> {resultsDir}/{runName}")

        send_msg_ssh(f"DRAM with workload {w} repeat {i} complete")

        if args.remoteResultsDir != None:
            run_command(f"scp {resultsDir}/{runName} {notifyDevice}:{args.remoteResultsDir}/{runName}")
            send_msg_ssh("Successfully copied over results")

send_msg_ssh("Experiment finished")
