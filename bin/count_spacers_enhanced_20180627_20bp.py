#!/usr/bin/env python2
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
	for k,v in alt_map.iteritems():
		seq = seq.replace(k,v)
	bases = list(seq) 
	bases = reversed([complement.get(base,base) for base in bases])
	bases = ''.join(bases)
	for k,v in alt_map.iteritems():
		bases = bases.replace(v,k)
	return bases

def count_spacers(input_file, fastq_file, output_prefix, sensitive):
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
	dict_counter_stringent = 0
	dict_counter_fuzzykey = 0
	dictionary = defaultdict(str)
	dict_guidename = defaultdict(str)
	dict_genename = defaultdict(str)
	dictionary_stringent = defaultdict(str)
	dict_stringent_guidename = defaultdict(str)
	dict_stringent_genename = defaultdict(str)
	dictionary_fuzzykey = defaultdict(str)
	dict_fuzzykey_guidename = defaultdict(str)
	dict_fuzzykey_genename = defaultdict(str)
	# open library sequences and initiate dictionary of read counts for each guide
	try:
		with open(input_file, mode='rU') as infile:  # rU mode is necessary for excel!
			for line in infile:
				splitted_line = line.strip().split(',')
				# print splitted_line
				dictionary[splitted_line[1]] = 0
				dictionary_stringent[splitted_line[1]] = 0
				dictionary_fuzzykey[splitted_line[1]] = 0
				if not (splitted_line[1] in dict_guidename):
					dict_guidename[splitted_line[1]] = splitted_line[0]
					dict_stringent_guidename[splitted_line[1]] = splitted_line[0]
					dict_fuzzykey_guidename[splitted_line[1]] = splitted_line[0]
				if not (splitted_line[1] in dict_genename):
					dict_genename[splitted_line[1]] = splitted_line[2]
					dict_stringent_genename[splitted_line[1]] = splitted_line[2]
					dict_fuzzykey_genename[splitted_line[1]] = splitted_line[2]
			# print len(dictionary)
	except:
		print  "could not open", input_file
	# print dictionary
	# open fastq file
	try:
		handle = open(fastq_file, "rU")
	except:
		print "could not find fastq file"
		return

	# process reads in fastq file
	readiter = SeqIO.parse(handle, "fastq")
	for record in readiter:  # contains the seq and Qscore etc.
		num_reads += 1
		ok=0
		read_sequence = str.upper(str(record.seq))
		# look for the 5' key with a maximum edit distance of 2 bp in the read
		#reg = regex.match(r'.*(?<Foo>:TGGAAAGGACGAAACACCG){e<=2}', read_sequence)
		#if reg:
		for i in xrange(len(read_sequence)-19):
			guide = read_sequence[i:i+20]
			guide_revcomp = reverse_complement(guide)
			key = read_sequence[i:i+19]
			primer = read_sequence[i-19:i]
			if key == "AACTTGCTATTTCTAGCTCTAAAAC":
				nb_primer +=1
			if guide_revcomp in dictionary:
				dictionary[guide_revcomp] += 1
				dict_counter += 1
				perfect_matches += 1
				reg = regex.match(r'.*(?<Foo>:AACTTGCTATTTCTAGCTCTAAAAC){e<=2}', primer)
				if primer == "AACTTGCTATTTCTAGCTCTAAAAC":
					perfect_primer +=1
					dictionary_stringent[guide_revcomp] += 1
					dict_counter_stringent += 1
					dictionary_fuzzykey[guide_revcomp] += 1
					dict_counter_fuzzykey += 1
				elif reg:
					approx_primer +=1
					dictionary_fuzzykey[guide_revcomp] += 1
					dict_counter_fuzzykey += 1
				else:
					key_not_found +=1
				ok=1
		if not ok:
			non_perfect_matches += 1
			ok=0

	# create ordered dictionary with guides and respective counts and output as a csv file
	dict_sorted = OrderedDict(sorted(dictionary.items(), key=lambda t: t[0]))
	dict_stringent_sorted = OrderedDict(sorted(dictionary_stringent.items(), key=lambda t: t[0]))
	dict_fuzzykey_sorted = OrderedDict(sorted(dictionary_fuzzykey.items(), key=lambda t: t[0]))
	out_counts = output_prefix + ".counts"
	out_stringent_counts = output_prefix + ".counts.stringent"
	out_fuzzykey_counts = output_prefix + ".counts.fuzzykey"
	with open(out_counts, 'w') as csvfile:
		mywriter = csv.writer(csvfile, delimiter=',')
		for guide in dict_sorted:
			count = dict_sorted[guide]
			genename = dict_genename[guide]
			guidename = dict_guidename[guide]
			mywriter.writerow([guidename, guide, genename, count])
	csvfile.close()

	with open(out_stringent_counts, 'w') as csvfile:
		mywriter = csv.writer(csvfile, delimiter=',')
		for guide in dict_stringent_sorted:
			count = dict_stringent_sorted[guide]
			genename = dict_stringent_genename[guide]
			guidename = dict_stringent_guidename[guide]
			mywriter.writerow([guidename, guide, genename, count])
	csvfile.close()

	with open(out_fuzzykey_counts, 'w') as csvfile:
		mywriter = csv.writer(csvfile, delimiter=',')
		for guide in dict_stringent_sorted:
			count = dict_fuzzykey_sorted[guide]
			genename = dict_fuzzykey_genename[guide]
			guidename = dict_fuzzykey_guidename[guide]
			mywriter.writerow([guidename, guide, genename, count])
	csvfile.close()

	# percentage of guides that matched perfectly
	percent_mapped = round(perfect_matches / float(perfect_matches + non_perfect_matches) * 100, 1)
	percent_matched_stringent = round(perfect_matches / float(perfect_matches + non_perfect_matches) * 100, 1)
	percent_matched_fuzzykey = round(perfect_matches / float(perfect_matches + non_perfect_matches) * 100, 1)
	# percentage of undetected guides with no read counts
	guides_with_reads = np.count_nonzero(dictionary.values())
	guides_no_reads = len(dictionary.values()) - guides_with_reads
	percent_no_reads = round(len(dictionary.values()) - guides_with_reads / float(len(dictionary.values())) * 100, 1)
	# skew ratio of top 10% to bottom 10% of guide counts
	top_10 = np.percentile(dictionary.values(), 90)
	bottom_10 = np.percentile(dictionary.values(), 10)
	if top_10 != 0 and bottom_10 != 0:
		skew_ratio = top_10 / bottom_10
	else:
		skew_ratio = 'Not enough perfect matches to determine skew ratio'

	# write analysis statistics to statistics.txt
	out_stats = output_prefix + ".stats"
	out_stringent_stats = output_prefix + ".stats.stringent"
	out_fuzzykey_stats = output_prefix + ".stats.fuzzykey"
	with open(out_stats, 'w') as infile:
		infile.write('Num Reads:' + str(num_reads) + '\n')
		infile.write('Num Reads with guide:' + str(dict_counter) + '\n')
		percent_mapped = round(dict_counter / float(num_reads) * 100, 1)
		infile.write('Perc Mapped reads:' + str(percent_mapped) + '\n')
		percent_zero_guides = round((len(dictionary.values()) - np.count_nonzero(dictionary.values())) / float(len(dictionary.values())) * 100, 1)
		infile.write('Perc Undetected guides:' + str(percent_zero_guides) + '\n')
		infile.write('Skew ratio:' + str(skew_ratio) + '\n')
		infile.write('sgRNA library size:' + str(len(dictionary)) + '\n')
		infile.close()

	with open(out_stringent_stats, 'w') as infile:
		infile.write('Num Reads:' + str(num_reads) + '\n')
		infile.write('Num Reads with guide:' + str(dict_counter_stringent) + '\n')
		percent_mapped = round(dict_counter_stringent / float(num_reads) * 100, 1)
		infile.write('Perc Mapped reads:' + str(percent_mapped) + '\n')
		percent_zero_guides = round((len(dictionary_stringent.values()) - np.count_nonzero(dictionary_stringent.values())) / float(len(dictionary_stringent.values())) * 100, 1)
		infile.write('Perc Undetected guides:' + str(percent_zero_guides) + '\n')
		infile.write('Skew ratio:' + str(skew_ratio) + '\n')
		infile.write('sgRNA library size:' + str(len(dictionary_stringent)) + '\n')
		infile.close()

	with open(out_fuzzykey_stats, 'w') as infile:
		infile.write('Num Reads:' + str(num_reads) + '\n')
		infile.write('Num Reads with guide:' + str(dict_counter_fuzzykey) + '\n')
		percent_mapped = round(dict_counter_fuzzykey / float(num_reads) * 100, 1)
		infile.write('Perc Mapped reads:' + str(percent_mapped) + '\n')
		percent_zero_guides = round((len(dictionary_fuzzykey.values()) - np.count_nonzero(dictionary_fuzzykey.values())) / float(len(dictionary_fuzzykey.values())) * 100, 1)
		infile.write('Perc Undetected guides:' + str(percent_zero_guides) + '\n')
		infile.write('Skew ratio:' + str(skew_ratio) + '\n')
		infile.write('sgRNA library size:' + str(len(dictionary_fuzzykey)) + '\n')
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
	parser.add_argument('-s', dest='sensitive',
						help='increase sensitivy but VERY SLOW', action='store_true')
	args = parser.parse_args()

	count_spacers(args.input_file, args.fastq_file, args.output_prefix, args.sensitive)
