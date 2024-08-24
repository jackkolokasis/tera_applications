#!/bin/bash
#
# Copyright 2015 - 2017 Atlarge Research Team,
# operating at Technische Universiteit Delft
# and Vrije Universiteit Amsterdam, the Netherlands.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


set -e

rootdir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))/../../
config="${rootdir}/config/"

function print-usage() {
	echo "Usage: ${BASH_SOURCE[0]} [--config <dir>]" >&2
}

# Parse the command-line arguments
while :
do
	case "$1" in
		--config)                      # Use a different config directory
			config="$(readlink -f "$2")"
			echo "Using config: $config"
			shift 2
			;;
		--)                            # End of options
			shift
			break
			;;
		-*)                            # Unknown command line option
			echo "Unknown option: $1" >&2
			print-usage
			exit 1
			;;
		*)                             # End of options
			break
			;;
	esac
done

# Execute platform specific initialization
export config=$config
. ${rootdir}/bin/sh/prepare-benchmark.sh "$@"

# Verify that the library jar is set
if [ "$LIBRARY_JAR" = "" ]; then
	echo "The prepare-benchmark.sh script must set variable \$LIBRARY_JAR" >&2
	exit 1
fi

PROJECT_DIR="/home1/public/kolokasis/github/latest_version/teraheap"

export LIBRARY_PATH=${PROJECT_DIR}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${PROJECT_DIR}/allocator/lib:$LD_LIBRARY_PATH
export PATH=${PROJECT_DIR}/allocator/include:$PATH
export C_INCLUDE_PATH=${PROJECT_DIR}/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${PROJECT_DIR}/allocator/include:$CPLUS_INCLUDE_PATH
export ALLOCATOR_HOME=${PROJECT_DIR}/allocator

export LIBRARY_PATH=${PROJECT_DIR}/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${PROJECT_DIR}/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=${PROJECT_DIR}/tera_malloc/include:$PATH
export C_INCLUDE_PATH=${PROJECT_DIR}/tera_malloc/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${PROJECT_DIR}/tera_malloc/include:$CPLUS_INCLUDE_PATH
export TERA_MALLOC_HOME=${PROJECT_DIR}/tera_malloc

# Run the benchmark
export CLASSPATH=$config:$(find ${rootdir}/$LIBRARY_JAR):$platform_classpath:/archive/users/kolokasis/tera_applications/neo4j/neo4j/community/configuration/target/neo4j-configuration-5.15.0-SNAPSHOT.jar
java -cp $CLASSPATH $java_opts science.atlarge.graphalytics.BenchmarkSuite

