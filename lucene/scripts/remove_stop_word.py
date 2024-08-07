#!/usr/bin/env python3

###################################################
#
# file: remove_stop_word.py
#
# @Author:   Iacovos G. Kolokasis
# @Version:  26-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Clean from a file stop-words and non-english words
#
###################################################

import nltk
from nltk.corpus import words
import pandas as pd

# Download the words dataset from nltk
nltk.download('words')

# Define the list of stop words
stop_words = set([
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an', 'and', 'any', 'are', 'aren\'t', 'as', 'at',
    'be', 'because', 'been', 'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can\'t', 'cannot', 'could',
    'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t', 'doing', 'don\'t', 'down', 'during', 'each', 'few', 'for',
    'from', 'further', 'had', 'hadn\'t', 'has', 'hasn\'t', 'have', 'haven\'t', 'having', 'he', 'he\'d', 'he\'ll', 'he\'s',
    'her', 'here', 'here\'s', 'hers', 'herself', 'him', 'himself', 'his', 'how', 'how\'s', 'i', 'i\'d', 'i\'ll', 'i\'m',
    'i\'ve', 'if', 'in', 'into', 'is', 'isn\'t', 'it', 'it\'s', 'its', 'itself', 'let\'s', 'me', 'more', 'most', 'mustn\'t',
    'my', 'myself', 'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'ought', 'our', 'ours', 'ourselves',
    'out', 'over', 'own', 'same', 'shan\'t', 'she', 'she\'d', 'she\'ll', 'she\'s', 'should', 'shouldn\'t', 'so', 'some',
    'such', 'than', 'that', 'that\'s', 'the', 'their', 'theirs', 'them', 'themselves', 'then', 'there', 'there\'s', 'these',
    'they', 'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through', 'to', 'too', 'under', 'until', 'up',
    'very', 'was', 'wasn\'t', 'we', 'we\'d', 'we\'ll', 'we\'re', 'we\'ve', 'were', 'weren\'t', 'what', 'what\'s', 'when',
    'when\'s', 'where', 'where\'s', 'which', 'while', 'who', 'who\'s', 'whom', 'why', 'why\'s', 'with', 'won\'t', 'would',
    'wouldn\'t', 'you', 'you\'d', 'you\'ll', 'you\'re', 'you\'ve', 'your', 'yours', 'yourself', 'yourselves'
])

# Get the set of valid English words from nltk
english_words = set(words.words())

# Function to remove stop words, one-letter words, excessively long words, and non-dictionary words
def remove_stop_words(input_file, output_file):
    # Read the input file into a DataFrame
    df = pd.read_csv(input_file, delimiter=r'\s+', header=None, names=['frequency', 'word'])
    
    # Filter out stop words
    df = df[~df['word'].isin(stop_words)]
    
    # Filter out one-letter words, excessively long words, and non-dictionary words
    df = df[df['word'].apply(lambda x: isinstance(x, str) and len(x) > 1 and x in english_words)]

    #df = df[df['word'].apply(lambda x: isinstance(x, str) and len(x) > 1)]
    
    # Write the cleaned DataFrame to the output file
    df.to_csv(output_file, sep=' ', index=False, header=False)

# Usage example
input_file = 'word_count.txt'  # Replace with the path to your input file
output_file = 'cleaned_word_counts.txt'  # Replace with the path to your output file
remove_stop_words(input_file, output_file)
