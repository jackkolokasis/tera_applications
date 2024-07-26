#!/bin/bash

read_random_split_file() {
  # The common prefix of the split files
  local prefix=$1

  # List all files with the common prefix and store them in an array
  local files=(${prefix}*)

  # Get the total number of files
  local total_files=${#files[@]}

  # Generate a random index between 0 and total_files-1
  local random_index=$((RANDOM % total_files))

  # Get the randomly selected file
  local selected_file=${files[$random_index]}

  # Display the contents of the selected file
  echo "$selected_file"
}

read_random_word() {
  local term_file=$1

  # Count the total words in the file. Each word is in differnt line
  local total_words=$(wc -l < "$term_file")

  # Check if the file is empty
  if [ "$total_words" -eq 0 ]; then
    echo "The file: $term_file is empty or does not exist."
  fi

  # Generate a random line number between 1 and total words
  local random_line=$((1 + RANDOM % total_words))

  # Read the word from the randomly selected line
  local word=$(sed -n "${random_line}p" "$term_file")

  echo $word
}

ctg=$1 # H,M,L

SCRIPT_DIR=`dirname "$(readlink -f "$0")"`

max_idx=0
file='null'

if [ "$ctg" = 'H' ]; then
	file="$SCRIPT_DIR/terms/HIGHT"
elif [ "$ctg" = 'M' ]; then
  file=$(read_random_split_file "$SCRIPT_DIR/terms/MEDT_PART_")
else
  file=$(read_random_split_file "$SCRIPT_DIR/terms/LOWT_PART_")
fi


#idx=$((1 + $RANDOM % $max_idx))
##echo $idx
#word=`sed -n ${idx}p $SCRIPT_DIR/terms/$file`

echo $(read_random_word $file)
