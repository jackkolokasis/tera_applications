#!/usr/bin/env bash

# git clone git@github.com:jackkolokasis/lucene.git
# cd lucene
# ./gradlew -Dversion.release=9.12.3 -Pvalidation.errorprone=false :lucene:core:jar --no-daemon -Pjavac.failOnWarnings=false                                                                                                                                                                                                                                     │
# cd -

wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.19.5/opensearch-2.19.5-linux-x64.tar.gz
tar xvf opensearch-2.19.5-linux-x64.tar.gz
cd opensearch-2.19.5
cp ../opensearch_jars/lucene-core-9.12.3.jar ./lib/
cp ../opensearch_jars/opensearch-2.19.5.jar ./lib/
cd -

