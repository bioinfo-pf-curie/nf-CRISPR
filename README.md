# nf-CRISPR: A Nextflow-based CRISPR genome-wide screens pipeline

**Institut Curie - Bioinformatics Core Facility**

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)
[![MultiQC](https://img.shields.io/badge/MultiQC-1.6-blue.svg)](https://multiqc.info/)
[![Install with](https://anaconda.org/anaconda/conda-build/badges/installer/conda.svg)](https://conda.anaconda.org/anaconda)
[![Singularity Container available](https://img.shields.io/badge/singularity-available-7E4C74.svg)](https://singularity.lbl.gov/)

### Introduction

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple computing infrastructures in a very portable manner.
It comes with conda / singularity containers making installation trivial and results highly reproducible, and can be run on a single laptop as well as on a cluster.
The current workflow is based on the nf-core best practice. See the nf-core project from details on [guidelines](https://nf-co.re/).

### Pipeline summary

This pipeline was designed to process Illumina sequencing data from the Curie CRISPR'IT platform.
Briefly, it allows to calculate quality metrics and generate count tables.

1. Reads quality control ([FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Count each library guides in FASTQ reads

### Quick help

```bash
N E X T F L O W  ~  version 19.10.0
Launching `main.nf` [backstabbing_roentgen] - revision: 93bf83bb3b
nf-CRISPR v1.0dev
=======================================================

Usage:

nextflow run main.nf --reads '*_R{1,2}.fastq.gz' --genome 'hg38'
nextflow run main.nf --samplePlan sample_plan --genome 'hg38'

Mandatory arguments:
  --reads                       Path to input data (must be surrounded with quotes)
  --samplePlan                  Path to sample plan file if '--reads' is not specified
  --library                     Library type. See --libraryList for more information
  -profile                      Configuration profile to use. Can use multiple (comma separated)
                                Configuration profile to use. test / conda / toolsPath / singularity / cluster (see below)

Genome References:              If not specified in the configuration file or you wish to overwrite any of the references
  --fasta                       Path to Fasta reference (.fasta)

Other options:
  --libraryList                 List the support CRISPR library designs
  --libraryDesign               Library design file (if not supported in --libraryList)
  --reverse                     Count guides on the reverse strand. Default is forward
  --skip_fastqc                 Skip quality controls on sequencing reads
  --skip_multiqc                Skip report
  --outdir                      The output directory where the results will be saved
  --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
  -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic
 
=======================================================
Available Profiles

  -profile test                Set up the test dataset
  -profile conda               Build a new conda environment before running the pipeline
  -profile toolsPath           Use the paths defined in configuration for each tool
  -profile singularity         Use the Singularity images for each process
  -profile cluster             Run the workflow on the cluster, instead of locally
```

### Quick run

The pipeline can be run on any infrastructure from a list of input files or from a sample plan as follow.
Note that by default, all tools are expected to be available from your `PATH`. See the full [`documentation`]('docs/README.md') for details and containers usage.

#### Run the pipeline on a test dataset
See the conf/test.conf to set your test dataset.

```
nextflow run main.nf -profile test

```

#### Run the pipeline from a sample plan

```
nextflow run main.nf --samplePlan MY_SAMPLE_PLAN --genome 'hg19' --outdir MY_OUTPUT_DIR

```

#### Run the pipeline on a cluster

```
echo "nextflow run main.nf --reads '*.R{1,2}.fastq.gz' --genome 'hg19' --outdir MY_OUTPUT_DIR -profile singularity,cluster" | qsub -N crispr

```

### Documentation

1. [Installation](docs/installation.md)
2. [Reference genomes](docs/configuration/reference_genomes.md)  
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)


#### Credits

This pipeline has been set up and written by the sequencing facility, the genetic service and the bioinformatics platform of the Institut Curie (M. Deloger, S. Lameiras, S. Baulande, N. Servant)

#### Contacts

For any question, bug or suggestion, please, contact the bioinformatics core facility

