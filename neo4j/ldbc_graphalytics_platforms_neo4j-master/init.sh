#/bin/sh

set -e

GRAPHS_DIR=${1:-~/graphs}
NEO4J_DIR=${2:-~/neo4j}
IMPLEMENTATION=${3:-embedded}

PROJECT=graphalytics-1.3.0-neo4j-0.1-SNAPSHOT

rm -rf $PROJECT
mvn package -DskipTests
tar xf $PROJECT-bin.tar.gz
rm $PROJECT-bin.tar.gz

cd $PROJECT/
cp -r config-template config
sed -i "s|^graphs.root-directory =$|graphs.root-directory = ${GRAPHS_DIR}/graphs|g" config/benchmark.properties
sed -i "s|^graphs.cache-directory =$|graphs.cache-directory = $GRAPHS_DIR/graphs/cache|g" config/benchmark.properties
sed -i "s|^graphs.output-directory =$|graphs.output-directory = $GRAPHS_DIR/output|g" config/benchmark.properties
sed -i "s|^graphs.validation-directory =$|graphs.validation-directory = $GRAPHS_DIR/validation|g" config/benchmark.properties
sed -i "s|^platform.neo4j.home =$|platform.neo4j.home = $NEO4J_DIR|g" config/platform.properties
sed -i "s|^platform.impl =$|platform.impl = $IMPLEMENTATION|g" config/platform.properties
mkdir report
