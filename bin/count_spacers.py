#!/usr/bin/env python
from Bio import SeqIO
import csv
from collections import OrderedDict, defaultdict
import numpy as np
import sys
import argparse
import regex
import os

alt_map = {'ins':'0'}
complement = {'A': 'T', 'C': 'G', 'G': 'C', 'T': 'A'} 

def reverse_complement(seq):    
	for k,v in alt_map.items():
		seq = seq.replace(k,v)
	bases = list(seq) 
	bases = reversed([complement.get(base,base) for base in bases])
	bases = ''.join(bases)
	for k,v in alt_map.items():
		bases = bases.replace(v,k)
	return bases

def count_spacers(input_file, fastq_file, output_prefix, reverse_count):
	"""
	creates a dictionary with guide counts from fastq_file, writes to output_prefix
	fastq_file: forward read fastq file
	output_prefix: csv file to write guide dictionary to
	dictionary: guide sequence as key, guide count as entry
	"""
	ok=0
	num_reads = 0  # total number of reads processed
	perfect_matches = 0  # guides with perfect match to library
	non_perfect_matches = 0  # number of guides without a perfect match to the library
	no_matches = 0  # number of guides without neither a perfect nor permissive match to the library
	key_not_found = 0  # number of guides without a key
	nb_primer = 0  # number of key in reads with a perfect match
	perfect_primer = 0  # number of key before guides with a perfect match
	approx_primer = 0  # number of key before guides without a perfect match
	dict_counter = 0
	dictionary = defaultdict(str)
	dict_guidename = defaultdict(str)
	dict_genename = defaultdict(str)
	# open library sequences and initiate dictionary of read counts for each guide
	try:
		with open(input_file, mode='rU') as infile:  # rU mode is necessary for excel!
			for line in infile:
				splitted_line = line.strip().split(',')
				dictionary[splitted_line[1]] = 0
				if not (splitted_line[1] in dict_guidename):
					dict_guidename[splitted_line[1]] = splitted_line[0]
				if not (splitted_line[1] in dict_genename):
					dict_genename[splitted_line[1]] = splitted_line[2]
	except:
		print ("could not open", input_file)
	# open fastq file
	try:
		handle = open(fastq_file, "rU")
	except:
		print ("could not find fastq file")
		return

	# process reads in fastq file
	readiter = SeqIO.parse(handle, "fastq")
	for record in readiter:  # contains the seq and Qscore etc.
		num_reads += 1
		read_sequence = str.upper(str(record.seq))
		# look for the 5' key with a maximum edit distance of 2 bp in the read
		for i in range(len(read_sequence)-19):
			guide = read_sequence[i:i+20]
			guide_revcomp = reverse_complement(guide)
			primer = read_sequence[i-19:i]
			if reverse_count:
				if guide_revcomp in dictionary:
					dictionary[guide_revcomp] += 1
					dictionary[guide] += 1
					dict_counter += 1
					perfect_matches += 1
			else:
				if guide in dictionary:
					dictionary[guide] += 1
					dict_counter += 1
					perfect_matches += 1

	# create ordered dictionary with guides and respective counts and output as a csv file
	dict_sorted = OrderedDict(sorted(dictionary.items(), key=lambda t: t[0]))
	out_counts = output_prefix + ".counts"
	with open(out_counts, 'w') as csvfile:
		mywriter = csv.writer(csvfile, delimiter=',')
		for guide in dict_sorted:
			count = dict_sorted[guide]
			genename = dict_genename[guide]
			guidename = dict_guidename[guide]
			mywriter.writerow([guidename, guide, genename, count])
	csvfile.close()

	if (perfect_matches + non_perfect_matches) == 0:
		print >> sys.stderr, "Error : no match detected. Please check if this is a 'forward' or a 'reverse' library !"
		sys.exit(-1)


	# percentage of guides that matched perfectly
	percent_mapped = round(perfect_matches / float(perfect_matches + non_perfect_matches) * 100, 1)
	# percentage of undetected guides with no read counts
	guides_with_reads = np.count_nonzero(list(dictionary.values()))
	guides_no_reads = len(dictionary.values()) - guides_with_reads
	percent_no_reads = round(len(dictionary.values()) - guides_with_reads / float(len(dictionary.values())) * 100, 1)
	# skew ratio of top 10% to bottom 10% of guide counts
	top_10 = np.percentile(list(dictionary.values()), 90)
	bottom_10 = np.percentile(list(dictionary.values()), 10)
	if top_10 != 0 and bottom_10 != 0:
		skew_ratio = top_10 / bottom_10
	else:
		skew_ratio = 'Not enough perfect matches to determine skew ratio'

	# write analysis statistics to statistics.txt
	out_stats = output_prefix + ".stats"
	header = 'sample_name' + ',' + 'num_reads' + ',' + 'num_reads_with_guide' + ',' + \
                 'perc_mapped_reads' + ',' + 'perc_undetected_guides' + ',' + 'skew_ratio' + ',' + 'sgRNA_library_size'
	with open(out_stats, 'w') as infile:
		percent_mapped = round(dict_counter / float(num_reads) * 100, 1)
		percent_zero_guides = round((len(dictionary.values()) - np.count_nonzero(list(dictionary.values()))) / float(len(dictionary.values())) * 100, 1)
		infile.write(header + '\n')
		infile.write(str(output_prefix) + ',' + str(num_reads) + ',' + str(dict_counter) + ',' + str(percent_mapped) + ',' + \
				     str(percent_zero_guides) + ',' + str(skew_ratio) + ',' + str(len(dictionary)) + '\n')
		infile.close()
	handle.close()
	return


if __name__ == '__main__':
	parser = argparse.ArgumentParser(
		description='Analyze sequencing data for sgRNA library distribution')
	parser.add_argument('-f', '--fastq', type=str, dest='fastq_file',
						help='fastq file name (Mandatory)', required=True)
	parser.add_argument('-o', '--output', type=str, dest='output_prefix',
						help='output prefix for result files (Mandatory)', required=True)
	parser.add_argument('-i', '--input', type=str, dest='input_file',
						help='input file name (Mandatory)', required=True)
	parser.add_argument('-r', '--reverse', action="store_true")
	args = parser.parse_args()

	count_spacers(args.input_file, args.fastq_file, args.output_prefix, args.reverse)
