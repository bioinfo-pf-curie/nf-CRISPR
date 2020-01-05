#!/usr/bin/env nextflow

/*
Copyright Institut Curie 2019
This software is a computer program whose purpose is to analyze high-throughput sequencing data.
You can use, modify and/ or redistribute the software under the terms of license (see the LICENSE file for more details).
The software is distributed in the hope that it will be useful, but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND. 
Users are therefore encouraged to test the software's suitability as regards their requirements in conditions enabling the security of their systems and/or data. 
The fact that you are presently reading this means that you have had knowledge of the license and that you accept its terms.

This script is based on the nf-core guidelines. See https://nf-co.re/ for more information
*/


/*
========================================================================================
                         nf-CRISPR PIPELINE
========================================================================================
 nf-CRISPR Pipeline.
 #### Homepage / Documentation
 https://gitlab.curie.fr/data-analysis/nf-CRISPR
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    
    nf-CRISPR v${workflow.manifest.version}
    =======================================================

    Usage:

    nextflow run main.nf -profile test
    nextflow run main.nf --reads '*_R{1,2}.fastq.gz' -profile curie
    nextflow run main.nf --samplePlan sample_plan.csv -profile curie

    Mandatory arguments:
      --reads                       Path to input data (must be surrounded with quotes)
      --samplePlan                  Path to sample plan file if '--reads' is not specified
      --csv                      Name of iGenomes reference
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: conda, singularityPath, cluster, test and more.

    Options:
      --singleEnd                   Specifies that the input is single end reads

    Genome References:              If not specified in the configuration file or you wish to overwrite any of the references.
      --csv                      Name of iGenomes reference
      --fasta                       Path to Fasta reference (.fasta)

    Library References:
      --fasta_hpv                   Path to Fasta HPV reference (.fasta)                 

    Other options:
      --skip_fastqc                 Skip quality controls on sequencing reads
      --skip_multiqc                Skip report
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

// Configure reference genomes
// Reference index path configuration

params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false

params.fasta_hpv = params.fasta_hpv ?: params.genomes['HPV'].fasta ?: false

params.genes_hpv = params.genomes['HPV'].genes ?: false
params.fasta_ctrl = params.genomes['HPV'].ctrl_capture ?: false



// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

// Stage config files
ch_multiqc_config = Channel.fromPath(params.multiqc_config)
ch_output_docs = Channel.fromPath("$baseDir/docs/output.md")
ch_fasta_ctrl = Channel.fromPath(params.fasta_ctrl)

/*
 * CHANNELS
 */

/*
 * Create a channel for input read files
 */

if(params.samplePlan){
   if(params.singleEnd){
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[1], [file(row[2])]] }
         .set {reads_fastqc}
   }else{
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[1], [file(row[2]), file(row[3])]] }
         .set {reads_fastqc}
   }
   params.reads=false
}
else if(params.readPaths){
    if(params.singleEnd){
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .set {reads_fastqc}
    } else {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0]), file(row[1][1])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .set {reads_fastqc}
    }
} else {
    Channel
        .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
        .set {reads_fastqc}
}

/*
 * Make sample plan if not available
 */

if (params.samplePlan){
  ch_splan = Channel.fromPath(params.samplePlan)
}else{
  if (params.singleEnd){
    Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
        }
       .set{ ch_splan }
  }else{
     Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
        }
       .set{ ch_splan }
  }
}

reads_fastqc.into { reads_fastqc; reads_gunzip }

/*
 * Other input channels
 */

// Reference library

if ( params.csv ) {
   lastPath = params.csv.lastIndexOf(File.separator)
   library_base = params.fasta.substring(lastPath+1)

   Channel.fromPath( params.csv )
        .ifEmpty { exit 1, "Reference library: CSV file not found: ${params.csv}" }
        .set { library_csv }
}
else {
   exit 1, "No reference library specified!"
}

// Header log info
log.info """=======================================================

CRISPR v${workflow.manifest.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'CRISPR'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = custom_runName ?: workflow.runName
if (params.samplePlan) {
   summary['SamplePlan']   = params.samplePlan
}else{
   summary['Reads']        = params.reads
}
summary['Fasta Ref']    = params.fasta
summary['Fasta HPV']    = params.fasta_hpv
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Output dir']   = params.outdir
summary['Working dir']  = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
summary['Current user']   = "$USER"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Config Profile'] = workflow.profile

if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


/****************************************************
 * Main worflow
 */

/*
 * FastQC
 */
process fastqc {
    tag "$name"
    conda "/bioinfo/local/build/Centos/envs_conda/nf-CRISPR-1.0dev"
    publishDir "${params.outdir}/fastqc", mode: 'copy'
   
    when:
    !params.skip_fastqc

    input:
    set val(name), file(reads) from reads_fastqc

    output:
    set val(prefix), file("${prefix}*.{zip,html}") into fastqc_results

    script:
    prefix = reads[0].toString() - ~/(_1)?(_2)?(_R1)?(_R2)?(.R1)?(.R2)?(_val_1)?(_val_2)?(_trimmed)?(\.fq)?(\.fastq)?(\.gz)?$/
    """
    fastqc -t ${task.cpus} -q $reads
    """
}


/*
 * Gunzip
 */
process gunzip {
    tag "$name"
    conda "/bioinfo/local/build/Centos/envs_conda/nf-CRISPR-1.0dev"
    publishDir "${params.outdir}/gunzip", mode: 'copy'

    when:
    !params.skip_fastqc

    input:
    set val(name), file(reads) from reads_gunzip

    output:
    set val(prefix), file("${prefix}.R1.fastq") into reads_gunzipped

    script:
    prefix= reads.toString() - ~/(.R1.fastq.gz)?$/
    """
    gunzip -c -f $reads >${prefix}.R1.fastq
    """
}


/*
 * Counting
 */

process Counting {
  tag "$prefix"
  conda "/bioinfo/local/build/Centos/envs_conda/nf-CRISPR-1.0dev"
  publishDir "${params.outdir}/counting", mode: 'copy'

  input:
  set val(prefix), file(reads) from reads_gunzipped
  file(library) from library_csv.collect()

  output:
  set val(prefix), file("${prefix}.counts") into ch_counts
  set val(prefix), file("${prefix}.stats") into ch_stats

  script:
  """
  count_spacers_enhanced_20180627_20bp.py -f $reads -o $prefix -i $library
  """
}


/*
/* MultiQC
 */

process get_software_versions {

    conda "/bioinfo/local/build/Centos/envs_conda/nf-CRISPR-1.0dev"

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml

    script:
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    fastqc --version > v_fastqc.txt
    python --version 2> v_python.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py > software_versions_mqc.yaml
    """
   }

   process multiqc_allsamples {
     publishDir "${params.outdir}/MultiQC/", mode: 'copy'

     when:
     !params.skip_multiqc

     input:
     file splan from ch_splan.first()
     file('fastqc/*') from fastqc_results.map{items->items[1]}.collect().ifEmpty([])
  
     file ('software_versions/*') from software_versions_yaml.collect()
     // file ('workflow_summary/*') from workflow_summary_yaml.collect()
 
     output:
     file splan
     file "*multiqc_report.html" into multiqc_report
     file "*_data"

     script:
     rtitle = custom_runName ? "--title \"$custom_runName\"" : ''
     rfilename = custom_runName ? "--filename " + custom_runName.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report" : ''
     """	
     multiqc . -f $rtitle $rfilename -m fastqc -m custom_content
     """
   }
