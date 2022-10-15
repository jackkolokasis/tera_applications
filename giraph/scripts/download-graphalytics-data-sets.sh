#!/usr/bin/env bash

DOWNLOAD_PATH=$1

if [ -z "$1" ]
then
  echo
  echo "Usage:"
  echo -e "\t ./download-graphalytics-data-sets.sh <path/to/download/file>"
  exit
fi


mkdir -p "$DOWNLOAD_PATH"/graphs
mkdir -p "$DOWNLOAD_PATH"/output
mkdir -p "$DOWNLOAD_PATH"/validations

download_dataset() {
  #echo cit-Patents;        curl https://surfdrive.surf.nl/files/index.php/s/mhTyNV2wk5HNAf7/download | tar -xv --use-compress-program=unzstd
  #echo com-friendster;     curl https://surfdrive.surf.nl/files/index.php/s/z8PSwZwBma7etRg/download | tar -xv --use-compress-program=unzstd
  #echo datagen-7_5-fb;     curl https://surfdrive.surf.nl/files/index.php/s/ypGcsxzrBeh2YGb/download | tar -xv --use-compress-program=unzstd
  #echo datagen-7_6-fb;     curl https://surfdrive.surf.nl/files/index.php/s/pxl7rDvzDQJFhfc/download | tar -xv --use-compress-program=unzstd
  #echo datagen-7_7-zf;     curl https://surfdrive.surf.nl/files/index.php/s/sstTvqgcyhWVVPn/download | tar -xv --use-compress-program=unzstd
  #echo datagen-7_8-zf;     curl https://surfdrive.surf.nl/files/index.php/s/QPSagck1SZTbIA1/download | tar -xv --use-compress-program=unzstd
  #echo datagen-7_9-fb;     curl https://surfdrive.surf.nl/files/index.php/s/btdN4uMsW20YJmV/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_0-fb;     curl https://surfdrive.surf.nl/files/index.php/s/lPIRs3QIlrACz86/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_1-fb;     curl https://surfdrive.surf.nl/files/index.php/s/RB5vU9WUtzA00Nz/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_2-zf;     curl https://surfdrive.surf.nl/files/index.php/s/BdQESW3JPg2uMJH/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_3-zf;     curl https://surfdrive.surf.nl/files/index.php/s/35KImcT5RbnZZFb/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_4-fb;     curl https://surfdrive.surf.nl/files/index.php/s/2xB1K9hVe3JSTdH/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_5-fb;     curl https://surfdrive.surf.nl/files/index.php/s/2d8wUj9HGIzime3/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_6-fb;     curl https://surfdrive.surf.nl/files/index.php/s/yyJoaazDGKmLc0k/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_7-zf;     curl https://surfdrive.surf.nl/files/index.php/s/jik4NN4CDnUDmAG/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_8-zf;     curl https://surfdrive.surf.nl/files/index.php/s/Qmi35tpKSjovS5d/download | tar -xv --use-compress-program=unzstd
  #echo datagen-8_9-fb;     curl https://surfdrive.surf.nl/files/index.php/s/A8dCtfeqNgSyAOF/download | tar -xv --use-compress-program=unzstd
  echo datagen-9_0-fb;     curl https://surfdrive.surf.nl/files/index.php/s/RFkNmmIOewT3YSd/download | tar -xv --use-compress-program=unzstd
  #echo datagen-9_1-fb;     curl https://surfdrive.surf.nl/files/index.php/s/7vJ0i7Ydj67loEL/download | tar -xv --use-compress-program=unzstd
  #echo datagen-9_2-zf;     curl https://surfdrive.surf.nl/files/index.php/s/cT4SZT8frlaIkLI/download | tar -xv --use-compress-program=unzstd
  #echo datagen-9_3-zf;     curl https://surfdrive.surf.nl/files/index.php/s/DE67JXHTN3jxM7O/download | tar -xv --use-compress-program=unzstd
  #echo datagen-9_4-fb;     curl https://surfdrive.surf.nl/files/index.php/s/epHG26pswdJG4kQ/download | tar -xv --use-compress-program=unzstd
  #echo datagen-sf3k-fb;    curl https://surfdrive.surf.nl/files/index.php/s/5l6bQq9a6GjZBRq/download | tar -xv --use-compress-program=unzstd
  #echo dota-league;        curl https://surfdrive.surf.nl/files/index.php/s/oyOewICGppmn0Jq/download | tar -xv --use-compress-program=unzstd
  #echo example-directed;   curl https://surfdrive.surf.nl/files/index.php/s/7hGIIZ6nzxgi0dU/download | tar -xv --use-compress-program=unzstd
  #echo example-undirected; curl https://surfdrive.surf.nl/files/index.php/s/enKFbXmUBP2rxgB/download | tar -xv --use-compress-program=unzstd
  #echo graph500-22;        curl https://surfdrive.surf.nl/files/index.php/s/0ix5lmNLsUsbx5W/download | tar -xv --use-compress-program=unzstd
  #echo graph500-23;        curl https://surfdrive.surf.nl/files/index.php/s/IIDfjd1ALbWQKhD/download | tar -xv --use-compress-program=unzstd
  #echo graph500-24;        curl https://surfdrive.surf.nl/files/index.php/s/FmhO7Xwtd2VYHb9/download | tar -xv --use-compress-program=unzstd
  #echo graph500-25;        curl https://surfdrive.surf.nl/files/index.php/s/gDwvrZLQXHr9IN7/download | tar -xv --use-compress-program=unzstd
  #echo graph500-26;        curl https://surfdrive.surf.nl/files/index.php/s/GE7kIyBL0PULiRK/download | tar -xv --use-compress-program=unzstd
  #echo graph500-27;        curl https://surfdrive.surf.nl/files/index.php/s/l1FRzpAZ2uIddKq/download | tar -xv --use-compress-program=unzstd
  #echo graph500-28;        curl https://surfdrive.surf.nl/files/index.php/s/n45KOpNrWZVon04/download | tar -xv --use-compress-program=unzstd
  #echo graph500-29;        curl https://surfdrive.surf.nl/files/index.php/s/VSXkomtgPGwZMW4/download | tar -xv --use-compress-program=unzstd
  #echo kgs;                curl https://surfdrive.surf.nl/files/index.php/s/L59W21l2jUzAOGf/download | tar -xv --use-compress-program=unzstd
  #echo twitter_mpi;        curl https://surfdrive.surf.nl/files/index.php/s/keuUstVmhPAIW3A/download | tar -xv --use-compress-program=unzstd
  #echo wiki-Talk;          curl https://surfdrive.surf.nl/files/index.php/s/c5dT1fwzXaNHT8j/download | tar -xv --use-compress-program=unzstd
  #
  #echo datagen-sf10k-fb 
  #curl --output datagen-sf10k-fb.tar.zst.000 https://surfdrive.surf.nl/files/index.php/s/mQpAeUD4HIdh88R/download
  #curl --output datagen-sf10k-fb.tar.zst.001 https://surfdrive.surf.nl/files/index.php/s/bLthhT3tQytnlM0/download
  #cat datagen-sf10k-fb.tar.zst.* | tar -tv --use-compress-program=unzstd
  #
  #echo graph500-30
  #curl --output graph500-30.tar.zst.000 https://surfdrive.surf.nl/files/index.php/s/07HY4YvhsFp3awr/download
  #curl --output graph500-30.tar.zst.001 https://surfdrive.surf.nl/files/index.php/s/QMy60s36HBYXliD/download
  #curl --output graph500-30.tar.zst.002 https://surfdrive.surf.nl/files/index.php/s/K0SsxPKogKZu86P/download
  #curl --output graph500-30.tar.zst.003 https://surfdrive.surf.nl/files/index.php/s/E5ZgpdUyDxVMP9O/download
  #cat graph500-30.tar.zst.* | tar -tv --use-compress-program=unzstd
}

download_dataset

mv ./*.e "$DOWNLOAD_PATH"/graphs
mv ./*.v "$DOWNLOAD_PATH"/graphs
mv ./*.properties "$DOWNLOAD_PATH"/graphs

mv ./*-BFS "$DOWNLOAD_PATH"/validations  
mv ./*-LCC "$DOWNLOAD_PATH"/validations
mv ./*-CDLP "$DOWNLOAD_PATH"/validations
mv ./*-PR "$DOWNLOAD_PATH"/validations
mv ./*-WCC "$DOWNLOAD_PATH"/validations
mv ./*-SSSP "$DOWNLOAD_PATH"/validations
