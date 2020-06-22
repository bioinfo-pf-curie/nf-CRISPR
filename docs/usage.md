# Usage

## Table of contents

* [Introduction](#general-nextflow-info)
* [Running the pipeline](#running-the-pipeline)
* [Main arguments](#main-arguments)
    * [`-profile`](#-profile-single-dash)
    * [`--reads`](#--reads)
    * [`--samplePlan`](#--samplePlan)
* [CRISPR Libraries](#crispr-library)
    * [`--library`](#--library)
    * [`--libraryList`](#--libraryList)
    * [`--libraryDesign`](#--libraryDesign)
* [Counts](#counts)
    * [`--reverse`](#--reverse)
* [Job resources](#job-resources)
* [Automatic resubmission](#automatic-resubmission)
* [Custom resource requests](#custom-resource-requests)
* [Other command line parameters](#other-command-line-parameters)
    * [`--skip*`](#--skip*)
    * [`--metadata`](#--metadta)
    * [`--outdir`](#--outdir)
    * [`--email`](#--email)
    * [`-name`](#-name-single-dash)
    * [`-resume`](#-resume-single-dash)
    * [`-c`](#-c-single-dash)
    * [`--maxMemory`](#--maxMemory)
    * [`--maxTime`](#--maxTime)
    * [`--maxCpus`](#--maxCpus)
    * [`--multiqc_config`](#--multiqc_config)


## General Nextflow info
Nextflow handles job submissions on SLURM or other environments, and supervises running the jobs. Thus the Nextflow process must run until the pipeline is finished. We recommend that you put the process running in the background through `screen` / `tmux` or similar tool. Alternatively you can run nextflow within a cluster job submitted your job scheduler.

It is recommended to limit the Nextflow Java virtual machines memory. We recommend adding the following line to your environment (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

## Running the pipeline
The typical command for running the pipeline is as follows:
```bash
nextflow run main.nf --reads '*_R{1,2}.fastq.gz' -profile 'singularity'
```

This will launch the pipeline with the `singularity` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work            # Directory containing the nextflow working files
results         # Finished results (configurable, see below)
.nextflow_log   # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

You can change the output director using the `--outdir/-w` options.

## Main arguments

### `-profile`
Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments. Note that multiple profiles can be loaded, for example: `-profile docker` - the order of arguments is important!

If `-profile` is not specified at all the pipeline will be run locally and expects all software to be installed and available on the `PATH`.

* `conda`
    * A generic configuration profile to be used with [conda](https://conda.io/docs/)
    * Pulls most software from [Bioconda](https://bioconda.github.io/)
* `singularity`
    * A generic configuration profile to be used with [Singularity](http://singularity.lbl.gov/) images
* `toolPaths`
    * A generic profile that use a path where all tools are expected to be installed. This path is set in the `toolPaths.conf` file.
* `cluster`
    * Submit the jobs to the cluster instead of running them locally
* `test`
    * A profile with a complete configuration for automated testing
    * Includes links to test data so needs no other parameters


### `--reads`
Use this to specify the location of your input FastQ files. For example:

```bash
--reads 'path/to/data/sample_*_{1,2}.fastq'
```

Please note the following requirements:

1. The path must be enclosed in quotes
2. The path must have at least one `*` wildcard character
3. When using the pipeline with paired end data, the path must use `{1,2}` notation to specify read pairs.

If left unspecified, a default pattern is used: `data/*{1,2}.fastq.gz`


### `--samplePlan`
Use this to specify a sample plan file instead of a regular expression to find fastq files. For example :

```bash
--samplePlan 'path/to/data/sample_plan.csv
```

The sample plan is a csv file with the following information :

Sample ID | Sample Name | Path to R1 fastq file | Path to R2 fastq file


## CRISPR Libraries

### `--library`

By setting the `--library 'LIB_ID'` parameters, the pipeline will used a dedicated library design.  
The library design files are stored in `assets/libraries/`.

Currently the followinf libraries are supported:

```
Available CRISPR Libraries:
Library Name: sabatiniPositiveMouse10
Description: Librairie Genome-Wide Knockout standard Sabatini Mouse with 10 guides/gene
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/0096_grnas_ngs_reads_sabatini_positive_screen_mouse_NoUnmapped_NoMultihits_NonRedundant.csv

Library Name: sabatiniNegativeHuman10
Description: Librairie Genome-Wide Knockout standard Sabatini Human with 10 guides/gene
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/0095_grnas_ngs_reads_sabatini_negative_screen_human_NoUnmapped_NoMultihits_NonRedundant.csv

Library Name: weissmanHuman5
Description: Librairie Genome-Wide Inhibition Standard Weissman Human with 5 guides/gene
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/190730_Library_CRISPRi_Weissman_Top5.csv

Library Name: weissmanHuman10
Description: Librairie Genome-Wide Inhibition Weissman Human with 10 guides/gene
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/hcrispri-v2-guides-weissman.csv

Library Name: humanGeCKOv2
Description: Librairie Genome-Wide Knockout standard Gecko Human with 5 guides/gene
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/Human_GeCKOv2_Library_combine_NoUnmapped_NoMultihits_NonRedundant.csv

Library Name: mouseGeCKOv2
Description: Librairie Genome-Wide Knockout standard Gecko Mouse with 5 guides/gene
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/Mouse_GeCKOv2_Library_combine_NoUnmapped_NoMultihits_NonRedundant.csv

Library Name: customFre
Description: Librairie Custom Knockout Gecko design Fre team
Design: /bioinfo/users/nservant/GitLab/nf-CRISPR/assets/libraries/191003-FRE-customlib-Gecko-Sg_custom_library_NoUnmapped_NoMultihits_NonRedundant.csv

```

Note that it is easy to add a new library by simply editing the `conf/genomes.conf` file and adding a new references as follow:

```nextflow
params {
  libraries {
    'MY_LIB' {
      description = '<SHORT DESCRIPTION OF THE DESIGN>'
      design = '<PATH TO CSV FILE>'
    }
  }
}
```

### `--libraryList`

Running the pipeline with this option will simply list the available libraries and keywords.

### `--libraryDesign`

If a library is not available in the pipeline and you do not want to modify the `conf/genomes.conf` file, you can simply provide a `csv` file  with the `--libraryDesign` options.
The design file is expected to be a comma separated file with 3 columns: guide_id, sequence, gene_id.

## Counts

The main goal of this pipeline is to generate a count table with the number of guides detected for each sample.
So far, the guide sequence is read in forward of the reads, and only perfect match are reported.

### `--reverse`

Look for the guide sequence in revese complement of the sequencing reads.

## Other command line parameters

### `--skip*`

The pipeline is made with a few *skip* options that allow to skip optional steps in the workflow.
The following options can be used:
- `--skip_fastqc` - Skip FastQC
- `--skip_multiqc` - Skip MultiQC
				
### `--metadata`
Specify a two-columns (tab-delimited) metadata file to diplay in the final Multiqc report.

### `--outdir`
The output directory where the results will be saved.

### `--email`
Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to speicfy this on the command line for every run.

### `-name`
Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

This is used in the MultiQC report (if not default) and in the summary HTML / e-mail (always).

**NB:** Single hyphen (core Nextflow option)

### `-resume`
Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

**NB:** Single hyphen (core Nextflow option)

### `-c`
Specify the path to a specific config file (this is a core NextFlow command).

**NB:** Single hyphen (core Nextflow option)

Note - you can use this to override pipeline defaults.

### `--maxMemory`
Use to set a top-limit for the default memory requirement for each process.
Should be a string in the format integer-unit. eg. `--maxMemory '8.GB'`

### `--maxTime`
Use to set a top-limit for the default time requirement for each process.
Should be a string in the format integer-unit. eg. `--maxTime '2.h'`

### `--maxCpus`
Use to set a top-limit for the default CPU requirement for each process.
Should be a string in the format integer-unit. eg. `--maxCpus 1`

### `--multiqc_config`
Specify a path to a custom MultiQC configuration file.

## Job resources

Each step in the pipeline has a default set of requirements for number of CPUs, memory and time (see the `conf/base.conf` file). 
For most of the steps in the pipeline, if the job exits with an error code of `143` (exceeded requested resources) it will automatically resubmit with higher requests (2 x original, then 3 x original). If it still fails after three times then the pipeline is stopped.
