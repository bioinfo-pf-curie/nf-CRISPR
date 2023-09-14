# Output

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

## Pipeline overview
The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

* [Quality Controls](#trimgalore) - reads trimming and quality control
* [Counts](#counts) - table counts
* [MultiQC](#multiqc) - aggregate report, describing results of the whole pipeline


## FastQC

Sequencing reads were first trimmed with [TrimGalore!](https://github.com/FelixKrueger/TrimGalore) to remove any adaptater sequences in the 3' end of the reads. This step is crutial to avoid noise in the downstream analysis and in the detection of soft-clipped reads.

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) is then used to assess the overall sequencing quality. It provides information about the quality score distribution across your reads, the per base sequence content (%T/A/G/C). You get information about adapter contamination and other overrepresented sequences.

For further reading and documentation see the [FastQC help](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

> **NB:** The FastQC plots displayed in the MultiQC report shows the trimmed reads.

**Output directory: `results/fastqc`**

* `sample_fastqc.html`
  * FastQC report, containing quality metrics for your untrimmed raw fastq files
* `zips/sample_fastqc.zip`
  * zip file containing the FastQC report, tab-delimited data file and plot images

## Counts

The table counts of all guides for all samples is available in the file `tablecounts_raw.csv`.
Note that only reads with a perfect guide sequences are counted.

## MultiQC

[MultiQC](http://multiqc.info) is a visualisation tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in within the report data directory.

The pipeline has special steps which allow the software versions used to be reported in the MultiQC output for future traceability.

**Output directory: `results/multiqc`**

* `Project_multiqc_report.html`
  * MultiQC report - a standalone HTML file that can be viewed in your web browser
* `Project_multiqc_data/`
  * Directory containing parsed statistics from the different tools used in the pipeline

For more information about how to use MultiQC reports, see http://multiqc.info
