#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

function exit_with_usage {
  cat << EOF
usage: release-build.sh <package|docs|publish-snapshot|publish-release>
Creates build deliverables from a Spark commit.

Top level targets are
  package: Create binary packages and commit them to dist.apache.org/repos/dist/dev/spark/
  docs: Build docs and commit them to dist.apache.org/repos/dist/dev/spark/
  publish-snapshot: Publish snapshot release to Apache snapshots
  publish-release: Publish a release to Apache release repo

All other inputs are environment variables

GIT_REF - Release tag or commit to build from
SPARK_PACKAGE_VERSION - Release identifier in top level package directory (e.g. 2.1.2-rc1)
SPARK_VERSION - (optional) Version of Spark being built (e.g. 2.1.2)

ASF_USERNAME - Username of ASF committer account
ASF_PASSWORD - Password of ASF committer account

GPG_KEY - GPG key used to sign release artifacts
GPG_PASSPHRASE - Passphrase for GPG key
EOF
  exit 1
}

set -e

if [ $# -eq 0 ]; then
  exit_with_usage
fi

if [[ $@ == *"help"* ]]; then
  exit_with_usage
fi

if [[ -z "$ASF_PASSWORD" ]]; then
  echo 'The environment variable ASF_PASSWORD is not set. Enter the password.'
  echo
  stty -echo && printf "ASF password: " && read ASF_PASSWORD && printf '\n' && stty echo
fi

if [[ -z "$GPG_PASSPHRASE" ]]; then
  echo 'The environment variable GPG_PASSPHRASE is not set. Enter the passphrase to'
  echo 'unlock the GPG signing key that will be used to sign the release!'
  echo
  stty -echo && printf "GPG passphrase: " && read GPG_PASSPHRASE && printf '\n' && stty echo
fi

for env in ASF_USERNAME GPG_PASSPHRASE GPG_KEY; do
  if [ -z "${!env}" ]; then
    echo "ERROR: $env must be set to run this script"
    exit_with_usage
  fi
done

# Explicitly set locale in order to make `sort` output consistent across machines.
# See https://stackoverflow.com/questions/28881 for more details.
export LC_ALL=C

# Commit ref to checkout when building
GIT_REF=${GIT_REF:-master}

RELEASE_STAGING_LOCATION="https://dist.apache.org/repos/dist/dev/spark"

GPG="gpg -u $GPG_KEY --no-tty --batch"
NEXUS_ROOT=https://repository.apache.org/service/local/staging
NEXUS_PROFILE=d63f592e7eac0 # Profile for Spark staging uploads
BASE_DIR=$(pwd)

MVN="build/mvn --force"

# Hive-specific profiles for some builds
HIVE_PROFILES="-Phive -Phive-thriftserver"
# Profiles for publishing snapshots and release to Maven Central
PUBLISH_PROFILES="-Pmesos -Pyarn -Pkubernetes -Pflume $HIVE_PROFILES -Pspark-ganglia-lgpl -Pkinesis-asl"
# Profiles for building binary releases
BASE_RELEASE_PROFILES="-Pmesos -Pyarn -Pkubernetes -Pflume -Psparkr"
# Scala 2.11 only profiles for some builds
SCALA_2_11_PROFILES="-Pkafka-0-8"
# Scala 2.12 only profiles for some builds
SCALA_2_12_PROFILES="-Pscala-2.12"

rm -rf spark
git clone https://git-wip-us.apache.org/repos/asf/spark.git
cd spark
git checkout $GIT_REF
git_hash=`git rev-parse --short HEAD`
echo "Checked out Spark git hash $git_hash"

if [ -z "$SPARK_VERSION" ]; then
  SPARK_VERSION=$($MVN help:evaluate -Dexpression=project.version \
    | grep -v INFO | grep -v WARNING | grep -v Download)
fi

# Verify we have the right java version set
if [ -z "$JAVA_HOME" ]; then
  echo "Please set JAVA_HOME."
  exit 1
fi

java_version=$("${JAVA_HOME}"/bin/javac -version 2>&1 | cut -d " " -f 2)

if [[ ! $SPARK_VERSION < "2.2." ]]; then
  if [[ $java_version < "1.8." ]]; then
    echo "Java version $java_version is less than required 1.8 for 2.2+"
    echo "Please set JAVA_HOME correctly."
    exit 1
  fi
else
  if [[ $java_version > "1.7." ]]; then
    if [ -z "$JAVA_7_HOME" ]; then
      echo "Java version $java_version is higher than required 1.7 for pre-2.2"
      echo "Please set JAVA_HOME correctly."
      exit 1
    else
      export JAVA_HOME="$JAVA_7_HOME"
    fi
  fi
fi

# This is a band-aid fix to avoid the failure of Maven nightly snapshot in some Jenkins
# machines by explicitly calling /usr/sbin/lsof. Please see SPARK-22377 and the discussion
# in its pull request.
LSOF=lsof
if ! hash $LSOF 2>/dev/null; then
  LSOF=/usr/sbin/lsof
fi

if [ -z "$SPARK_PACKAGE_VERSION" ]; then
  SPARK_PACKAGE_VERSION="${SPARK_VERSION}-$(date +%Y_%m_%d_%H_%M)-${git_hash}"
fi

DEST_DIR_NAME="$SPARK_PACKAGE_VERSION"

git clean -d -f -x
rm .gitignore
rm -rf .git
cd ..

if [[ "$1" == "package" ]]; then
  # Source and binary tarballs
  echo "Packaging release source tarballs"
  cp -r spark spark-$SPARK_VERSION
  tar cvzf spark-$SPARK_VERSION.tgz spark-$SPARK_VERSION
  echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --armour --output spark-$SPARK_VERSION.tgz.asc \
    --detach-sig spark-$SPARK_VERSION.tgz
  echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md MD5 spark-$SPARK_VERSION.tgz > \
    spark-$SPARK_VERSION.tgz.md5
  echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
    SHA512 spark-$SPARK_VERSION.tgz > spark-$SPARK_VERSION.tgz.sha512
  rm -rf spark-$SPARK_VERSION

  # Updated for each binary build
  make_binary_release() {
    NAME=$1
    FLAGS=$2
    ZINC_PORT=$3
    BUILD_PACKAGE=$4
    cp -r spark spark-$SPARK_VERSION-bin-$NAME

    cd spark-$SPARK_VERSION-bin-$NAME

    # TODO There should probably be a flag to make-distribution to allow 2.12 support
    #if [[ $FLAGS == *scala-2.12* ]]; then
    #  ./dev/change-scala-version.sh 2.12
    #fi

    export ZINC_PORT=$ZINC_PORT
    echo "Creating distribution: $NAME ($FLAGS)"

    # Write out the VERSION to PySpark version info we rewrite the - into a . and SNAPSHOT
    # to dev0 to be closer to PEP440.
    PYSPARK_VERSION=`echo "$SPARK_VERSION" |  sed -r "s/-/./" | sed -r "s/SNAPSHOT/dev0/"`
    echo "__version__='$PYSPARK_VERSION'" > python/pyspark/version.py

    # Get maven home set by MVN
    MVN_HOME=`$MVN -version 2>&1 | grep 'Maven home' | awk '{print $NF}'`


    if [ -z "$BUILD_PACKAGE" ]; then
      echo "Creating distribution without PIP/R package"
      ./dev/make-distribution.sh --name $NAME --mvn $MVN_HOME/bin/mvn --tgz $FLAGS \
        -DzincPort=$ZINC_PORT 2>&1 >  ../binary-release-$NAME.log
      cd ..
    elif [[ "$BUILD_PACKAGE" == "withr" ]]; then
      echo "Creating distribution with R package"
      ./dev/make-distribution.sh --name $NAME --mvn $MVN_HOME/bin/mvn --tgz --r $FLAGS \
        -DzincPort=$ZINC_PORT 2>&1 >  ../binary-release-$NAME.log
      cd ..

      echo "Copying and signing R source package"
      R_DIST_NAME=SparkR_$SPARK_VERSION.tar.gz
      cp spark-$SPARK_VERSION-bin-$NAME/R/$R_DIST_NAME .

      echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --armour \
        --output $R_DIST_NAME.asc \
        --detach-sig $R_DIST_NAME
      echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
        MD5 $R_DIST_NAME > \
        $R_DIST_NAME.md5
      echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
        SHA512 $R_DIST_NAME > \
        $R_DIST_NAME.sha512
    else
      echo "Creating distribution with PIP package"
      ./dev/make-distribution.sh --name $NAME --mvn $MVN_HOME/bin/mvn --tgz --pip $FLAGS \
        -DzincPort=$ZINC_PORT 2>&1 >  ../binary-release-$NAME.log
      cd ..

      echo "Copying and signing python distribution"
      PYTHON_DIST_NAME=pyspark-$PYSPARK_VERSION.tar.gz
      cp spark-$SPARK_VERSION-bin-$NAME/python/dist/$PYTHON_DIST_NAME .

      echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --armour \
        --output $PYTHON_DIST_NAME.asc \
        --detach-sig $PYTHON_DIST_NAME
      echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
        MD5 $PYTHON_DIST_NAME > \
        $PYTHON_DIST_NAME.md5
      echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
        SHA512 $PYTHON_DIST_NAME > \
        $PYTHON_DIST_NAME.sha512
    fi

    echo "Copying and signing regular binary distribution"
    cp spark-$SPARK_VERSION-bin-$NAME/spark-$SPARK_VERSION-bin-$NAME.tgz .
    echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --armour \
      --output spark-$SPARK_VERSION-bin-$NAME.tgz.asc \
      --detach-sig spark-$SPARK_VERSION-bin-$NAME.tgz
    echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
      MD5 spark-$SPARK_VERSION-bin-$NAME.tgz > \
      spark-$SPARK_VERSION-bin-$NAME.tgz.md5
    echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --print-md \
      SHA512 spark-$SPARK_VERSION-bin-$NAME.tgz > \
      spark-$SPARK_VERSION-bin-$NAME.tgz.sha512
  }

  # TODO: Check exit codes of children here:
  # http://stackoverflow.com/questions/1570262/shell-get-exit-code-of-background-process

  # We increment the Zinc port each time to avoid OOM's and other craziness if multiple builds
  # share the same Zinc server.
  make_binary_release "hadoop2.6" "-Phadoop-2.6 $HIVE_PROFILES $SCALA_2_11_PROFILES $BASE_RELEASE_PROFILES" "3035" "withr" &
  make_binary_release "hadoop2.7" "-Phadoop-2.7 $HIVE_PROFILES $SCALA_2_11_PROFILES $BASE_RELEASE_PROFILES" "3036" "withpip" &
  make_binary_release "without-hadoop" "-Phadoop-provided $SCALA_2_11_PROFILES $BASE_RELEASE_PROFILES" "3038" &
  wait
  rm -rf spark-$SPARK_VERSION-bin-*/

  svn co --depth=empty $RELEASE_STAGING_LOCATION svn-spark
  rm -rf "svn-spark/${DEST_DIR_NAME}-bin"
  mkdir -p "svn-spark/${DEST_DIR_NAME}-bin"

  echo "Copying release tarballs"
  cp spark-* "svn-spark/${DEST_DIR_NAME}-bin/"
  cp pyspark-* "svn-spark/${DEST_DIR_NAME}-bin/"
  cp SparkR_* "svn-spark/${DEST_DIR_NAME}-bin/"
  svn add "svn-spark/${DEST_DIR_NAME}-bin"

  cd svn-spark
  svn ci --username $ASF_USERNAME --password "$ASF_PASSWORD" -m"Apache Spark $SPARK_PACKAGE_VERSION"
  cd ..
  rm -rf svn-spark
  exit 0
fi

if [[ "$1" == "docs" ]]; then
  # Documentation
  cd spark
  echo "Building Spark docs"
  cd docs
  # TODO: Make configurable to add this: PRODUCTION=1
  PRODUCTION=1 RELEASE_VERSION="$SPARK_VERSION" jekyll build
  cd ..
  cd ..

  svn co --depth=empty $RELEASE_STAGING_LOCATION svn-spark
  rm -rf "svn-spark/${DEST_DIR_NAME}-docs"
  mkdir -p "svn-spark/${DEST_DIR_NAME}-docs"

  echo "Copying release documentation"
  cp -R "spark/docs/_site" "svn-spark/${DEST_DIR_NAME}-docs/"
  svn add "svn-spark/${DEST_DIR_NAME}-docs"

  cd svn-spark
  svn ci --username $ASF_USERNAME --password "$ASF_PASSWORD" -m"Apache Spark $SPARK_PACKAGE_VERSION docs"
  cd ..
  rm -rf svn-spark
  exit 0
fi

if [[ "$1" == "publish-snapshot" ]]; then
  cd spark
  # Publish Spark to Maven release repo
  echo "Deploying Spark SNAPSHOT at '$GIT_REF' ($git_hash)"
  echo "Publish version is $SPARK_VERSION"
  if [[ ! $SPARK_VERSION == *"SNAPSHOT"* ]]; then
    echo "ERROR: Snapshots must have a version containing SNAPSHOT"
    echo "ERROR: You gave version '$SPARK_VERSION'"
    exit 1
  fi
  # Coerce the requested version
  $MVN versions:set -DnewVersion=$SPARK_VERSION
  tmp_settings="tmp-settings.xml"
  echo "<settings><servers><server>" > $tmp_settings
  echo "<id>apache.snapshots.https</id><username>$ASF_USERNAME</username>" >> $tmp_settings
  echo "<password>$ASF_PASSWORD</password>" >> $tmp_settings
  echo "</server></servers></settings>" >> $tmp_settings

  # Generate random point for Zinc
  export ZINC_PORT=$(python -S -c "import random; print random.randrange(3030,4030)")

  $MVN -DzincPort=$ZINC_PORT --settings $tmp_settings -DskipTests $SCALA_2_11_PROFILES $PUBLISH_PROFILES deploy
  #./dev/change-scala-version.sh 2.12
  #$MVN -DzincPort=$ZINC_PORT --settings $tmp_settings \
  #  -DskipTests $SCALA_2_12_PROFILES $PUBLISH_PROFILES clean deploy

  # Clean-up Zinc nailgun process
  $LSOF -P |grep $ZINC_PORT | grep LISTEN | awk '{ print $2; }' | xargs kill

  rm $tmp_settings
  cd ..
  exit 0
fi

if [[ "$1" == "publish-release" ]]; then
  cd spark
  # Publish Spark to Maven release repo
  echo "Publishing Spark checkout at '$GIT_REF' ($git_hash)"
  echo "Publish version is $SPARK_VERSION"
  # Coerce the requested version
  $MVN versions:set -DnewVersion=$SPARK_VERSION

  # Using Nexus API documented here:
  # https://support.sonatype.com/entries/39720203-Uploading-to-a-Staging-Repository-via-REST-API
  echo "Creating Nexus staging repository"
  repo_request="<promoteRequest><data><description>Apache Spark $SPARK_VERSION (commit $git_hash)</description></data></promoteRequest>"
  out=$(curl -X POST -d "$repo_request" -u $ASF_USERNAME:$ASF_PASSWORD \
    -H "Content-Type:application/xml" -v \
    $NEXUS_ROOT/profiles/$NEXUS_PROFILE/start)
  staged_repo_id=$(echo $out | sed -e "s/.*\(orgapachespark-[0-9]\{4\}\).*/\1/")
  echo "Created Nexus staging repository: $staged_repo_id"

  tmp_repo=$(mktemp -d spark-repo-XXXXX)

  # Generate random point for Zinc
  export ZINC_PORT=$(python -S -c "import random; print random.randrange(3030,4030)")

  $MVN -DzincPort=$ZINC_PORT -Dmaven.repo.local=$tmp_repo -DskipTests $SCALA_2_11_PROFILES $PUBLISH_PROFILES clean install

  #./dev/change-scala-version.sh 2.12
  #$MVN -DzincPort=$ZINC_PORT -Dmaven.repo.local=$tmp_repo \
  #  -DskipTests $SCALA_2_12_PROFILES ??$PUBLISH_PROFILES clean install

  # Clean-up Zinc nailgun process
  $LSOF -P |grep $ZINC_PORT | grep LISTEN | awk '{ print $2; }' | xargs kill

  #./dev/change-scala-version.sh 2.11

  pushd $tmp_repo/org/apache/spark

  # Remove any extra files generated during install
  find . -type f |grep -v \.jar |grep -v \.pom | xargs rm

  echo "Creating hash and signature files"
  # this must have .asc, .md5 and .sha1 - it really doesn't like anything else there
  for file in $(find . -type f)
  do
    echo $GPG_PASSPHRASE | $GPG --passphrase-fd 0 --output $file.asc \
      --detach-sig --armour $file;
    if [ $(command -v md5) ]; then
      # Available on OS X; -q to keep only hash
      md5 -q $file > $file.md5
    else
      # Available on Linux; cut to keep only hash
      md5sum $file | cut -f1 -d' ' > $file.md5
    fi
    sha1sum $file | cut -f1 -d' ' > $file.sha1
  done

  nexus_upload=$NEXUS_ROOT/deployByRepositoryId/$staged_repo_id
  echo "Uplading files to $nexus_upload"
  for file in $(find . -type f)
  do
    # strip leading ./
    file_short=$(echo $file | sed -e "s/\.\///")
    dest_url="$nexus_upload/org/apache/spark/$file_short"
    echo "  Uploading $file_short"
    curl -u $ASF_USERNAME:$ASF_PASSWORD --upload-file $file_short $dest_url
  done

  echo "Closing nexus staging repository"
  repo_request="<promoteRequest><data><stagedRepositoryId>$staged_repo_id</stagedRepositoryId><description>Apache Spark $SPARK_VERSION (commit $git_hash)</description></data></promoteRequest>"
  out=$(curl -X POST -d "$repo_request" -u $ASF_USERNAME:$ASF_PASSWORD \
    -H "Content-Type:application/xml" -v \
    $NEXUS_ROOT/profiles/$NEXUS_PROFILE/finish)
  echo "Closed Nexus staging repository: $staged_repo_id"
  popd
  rm -rf $tmp_repo
  cd ..
  exit 0
fi

cd ..
rm -rf spark
echo "ERROR: expects to be called with 'package', 'docs', 'publish-release' or 'publish-snapshot'"
