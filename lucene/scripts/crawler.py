import tldextract
import argparse
import gzip
import time
import os
import collections
import pandas as pd
import threading
from multiprocessing import Pool
import re
import requests
from concurrent.futures import ThreadPoolExecutor

def read_every_line(fname, max_lines=-1):
    lines = []
    with open(fname, encoding='utf-8') as f:
        for i, l in enumerate(f):
            lines.append(l)
            if i > max_lines and max_lines > 0:
                break
    return lines

def save(url, filename, log):
    if not os.path.exists(filename):
        with requests.get(url, stream=True) as response:
            with open(filename, 'wb') as file:
                for chunk in response.iter_content(chunk_size=8192):
                    file.write(chunk)
        log.write(f"downloaded:{filename}\n")

def remove_non_alpha_chars(input_string):
    # Replace non-alphabetic characters with a single space
    cleaned_string = re.sub(r'[^a-zA-Z]', ' ', input_string)
    # Replace all consecutive spaces with a single space
    cleaned_string = re.sub(r'\s+', ' ', cleaned_string)
    return cleaned_string.strip()  # Strip leading and trailing

def process_index_file(file_name, out_file, line_counter):
    # print('Unzipping index file ... ')
    # print("process")
    with gzip.open(file_name, 'rb') as f_in:
        valid_content_type = False
        start_writing = False
        content_length = 0
        valid_language = False
        char_counter = 0
        output_line = ""
        counter = 0
        for line in f_in:
            decoded_line = line.decode("utf-8")
            if decoded_line.startswith("WARC-Identified-Content-Language: "):
                language = decoded_line.split(": ")[1].strip()
                valid_language = (language == "eng")
            elif decoded_line.startswith("WARC"):
                pass
            elif decoded_line.startswith("Content-Type: "):
                content_type = decoded_line.split(": ")[1].strip()
                valid_content_type = (content_type == "text/plain")
            elif decoded_line.startswith("Content-Length: "):
                try:
                    content_length = int(decoded_line.split(": ")[1])
                except:
                    content_length = 0
            else:
                start_writing = valid_content_type and valid_language and content_length >= 1000
                if start_writing:
                    remaining = 1000 - char_counter
                    decoded_line = remove_non_alpha_chars(decoded_line)
                    if len(decoded_line) == 0:
                        continue
                    output_line += (decoded_line + " ")[:remaining]

                    char_counter += len(decoded_line) + 1
                    if char_counter >= 1000:
                        if line_counter >= max_line:
                            # print("max_line")
                            return False, line_counter
                        out_file.write(output_line + "\n")
                        line_counter += 1
                        char_counter = 0
                        output_line = ""
                else:
                    char_counter = 0
                    output_line = ""
    return True, line_counter

def download_and_process(file_name_url_tuple, line_counter, out_file, log):
    # print(f"downloading {file_name_url_tuple}")
    file_name, url = file_name_url_tuple
    save(url, file_name, log)
    # print(f"saved {file_name_url_tuple}")
    # log.write(f"saved {file_name_url_tuple}")
    return process_index_file(file_name, out_file, line_counter)

def run_thread(thread_num, lock, log):
    try:
        global doc_counter
        running = True
        my_counter = 0
        line_counter = 0
        out_file_name = f"{processed_dir}/corpus{thread_num}.txt"
        print(f"started thread {thread_num}")
        with open(out_file_name, 'w') as out_file:
            while running:
                with lock:
                    my_counter = doc_counter
                    doc_counter += 1
                # print(f"grabbed counter {my_counter}")
                log.write(f"{cc_files[my_counter][0]}\n")
                try:
                    running, line_counter = download_and_process(cc_files[my_counter], line_counter, out_file, log)
                except:
                    print(f"An unexpected error occurred for thread {thread_num}, doc_counter: {my_counter}, file: {cc_files[my_counter][0]}")
                # log.write(f"finished processing {cc_files[my_counter]}")
        print(f"stopped thread {thread_num}")
    except Exception as e:
        print(f"An unexpected error occurred for thread {thread_num}:", e)

if __name__ == "__main__":
    # Set up the argument parser
    parser = argparse.ArgumentParser(description='Process some paths.')

    # Define the arguments
    parser.add_argument('-s', '--storage-folder', type=str, required=True, 
                        help='The storage folder')
    parser.add_argument('-p', '--processed-dir', type=str, required=True, 
                        help='The processed directory')

    # Parse the arguments
    args = parser.parse_args()

    # Initialize the variables
    storage_folder = args.storage_folder
    file_prefix = 'https://data.commoncrawl.org/'
    processed_dir = args.processed_dir

    cc_indexes = read_every_line('wet.paths')

    cc_indexes = [_.replace('\n','') for _ in cc_indexes]
    file_dict = collections.OrderedDict()

    # iterate over the index files
    for cc_index in cc_indexes:
        cc_index_file = cc_index.split('/')[-1]
        file_dict[os.path.join(storage_folder,cc_index_file)] = file_prefix + cc_index

    cc_files = list(file_dict.items())
    max_line = 10000000 # each line is 1000 bytes, so 10 GB per thread
    # max_line = 1000 # testing
    num_threads = 32
    starting_thread = 0
    doc_counter = 0
    log_file = 'log.txt-{}'.format(time.strftime("%Y%m%d-%H%M%S"))

    with open(log_file, 'w') as log:
        lock = threading.Lock()
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            executor.map(lambda x: run_thread(x, lock, log), range(starting_thread, starting_thread + num_threads))
        log.write("done\n")

