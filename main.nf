#!/usr/bin/env nextflow

/*
Copyright Institut Curie 2019-2020
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
    if ("${workflow.manifest.version}" =~ /dev/ ){
       devMess = file("$baseDir/assets/dev_message.txt")
       log.info devMess.text
    }

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
      --library                     Library type. See --libraryList for more information
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Configuration profile to use. test / conda / toolsPath / singularity / cluster (see below)

    Other options:
      --libraryList                 List the support CRISPR library designs
      --libraryDesign               Library design file (if not supported in --libraryList)
      --reverse                     Count guides on the reverse strand. Default is forward
      --skipFastqc                  Skip quality controls on sequencing reads
      --skipMultiqc                 Skip report
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic
 
   =======================================================
    Available Profiles

      -profile test                Set up the test dataset
      -profile conda               Build a new conda environment before running the pipeline
      -profile multiconda          Build a new conda environment for each process before running the pipeline
      -profile toolsPath           Use the paths defined in configuration for each tool
      -profile singularity         Use the Singularity images for each process
      -profile cluster             Run the workflow on the cluster, instead of locally

    """.stripIndent()
}

def listLib() {

  log.info"""
    
  nf-CRISPR v${workflow.manifest.version}
  =======================================================

  Available CRISPR Libraries:

  """.stripIndent()

  for ( lib in params.libraries.keySet() ){
    log.info "Library Name: " + lib
    log.info "Description: " + params.libraries[lib].description
    log.info "Design: " + params.libraries[lib].design
    log.info "\n"
  }
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}
if (params.libraryList){
    listLib()
    exit 0
}

// Configure reference genomes
// Reference index path configuration
//if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
//   exit 1, "The provided genome '${params.genome}' is not available in the genomes file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
//}
//params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
customRunName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  customRunName = workflow.runName
}

// Stage config files
chMultiqcConfig = Channel.fromPath(params.multiqcConfig)
chOutputDocs = Channel.fromPath("$baseDir/docs/output.md")

/*
 * CHANNELS
 */

// Library type
if (!params.libraryDesign && params.library){
  if (params.libraries && params.library && !params.libraries.containsKey(params.library)) {
     exit 1, "The provided library '${params.library}' is not available. See the '--libraryList' or '--libraryDesign' parameters.}"
  }
  designPath = params.library ? params.libraries[ params.library ].design ?: false : false
  Channel.fromPath( designPath )
      .ifEmpty { exit 1, "Reference library not found: ${designPath}" }
      .set { chLibraryCsv }
}else if ( params.libraryDesign ){
  Channel.fromPath( params.libraryDesign )
      .ifEmpty { exit 1, "Reference library not found: ${params.libraryDesign}" }
      .set { chLibraryCsv }
}else{
  exit 1, "No library detected. See the '--libraryList', '--library' or '--libraryDesign' parameters.}"
}


/*
 * Create a channel for input read files
 */

if(params.samplePlan){
   if(params.singleEnd){
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[0], [file(row[2])]] }
         .into {chReadsFastqc; chReadsGunzip}
   }else{
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[0], [file(row[2]), file(row[3])]] }
         .into {chReadsFastqc; chReadsGunzip}
   }
   params.reads=false
}
else if(params.readPaths){
    if(params.singleEnd){
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into {chReadsFastqc; chReadsGunzip}
    } else {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0]), file(row[1][1])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into {chReadsFastqc; chReadsGunzip}
    }
} else {
    Channel
        .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
        .into {chReadsFastqc; chReadsGunzip}
}

/*
 * Make sample plan if not available
 */

if (params.samplePlan){
  chSplan = Channel.fromPath(params.samplePlan)
}else{
  if (params.singleEnd){
    Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
        }
       .set{ chSplan }
  }else{
     Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
        }
       .set{ chSplan }
  }
}

// Header log info
if ("${workflow.manifest.version}" =~ /dev/ ){
   devMess = file("$baseDir/assets/dev_message.txt")
   log.info devMess.text
}

// Header log info
log.info """=======================================================

CRISPR v${workflow.manifest.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'CRISPR'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = customRunName ?: workflow.runName
if (params.samplePlan) {
   summary['SamplePlan']   = params.samplePlan
}else{
   summary['Reads']        = params.reads
}
if (params.library){
   summary['Library Name'] = params.library
}
if (params.libraryDesign){
   summary['Library Design']  = params.libraryDesign
}else{
   summary['Library Design']  = designPath
}
//summary['Fasta Ref']    = params.fasta
summary['Count Strand'] = params.reverse ? "reverse" : "forward"
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
    label 'fastqc'
    label 'medCpu'
    label 'medMem'

    publishDir "${params.outdir}/fastqc", mode: 'copy'
    
    when:
    !params.skipFastqc

    input:
    set val(name), file(reads) from chReadsFastqc

    output:
    set val(prefix), file("${prefix}*.{zip,html}") into fastqcResults

    script:
    prefix = reads[0].toString() - ~/(_1)?(_2)?(_R1)?(_R2)?(.R1)?(.R2)?(_val_1)?(_val_2)?(_trimmed)?(\.fq)?(\.fastq)?(\.gz)?$/
    """
    fastqc -t ${task.cpus} -q $reads
    """
}

/*
 * get FastQC Ver
 */
process getFastqcVer {
    tag "$name"
    label 'fastqc'
    label 'lowCpu'
    label 'lowMem'

    publishDir "${params.outdir}/fastqc_version", mode: 'copy'

    when:
    !params.skipFastqc

    
    output:
    file("v_fastqc.txt") into fastqcVersionCh

    script:
    
    """
    fastqc --version > v_fastqc.txt
    """ 
}                  

/*
 * get multiQC Ver
 */
process getMultiqcVer {
    tag "$name"
    label 'multiqc'
    label 'lowCpu'
    label 'lowMem'

    publishDir "${params.outdir}/MultiQC_version/", mode: 'copy'

    when:
    !params.skipMultiqc


    output:
    file("v_multiqc.txt") into multiqcVersionCh

    script:

    """
    multiqc --version > v_multiqc.txt
    """
}

/*
 * Gunzip
 */
process gunzip {
    tag "$name"
    label 'onlylinux'
    label 'lowCpu'
    label 'lowMem'

    publishDir "${params.outdir}/gunzip", mode: 'copy'

    input:
    set val(name), file(reads) from chReadsGunzip

    output:
    set val(prefix), file("${prefix}.R1.fastq") into chReadsGunzipped

    script:
    prefix= reads.toString() - ~/(.R1.fastq.gz)?$/
    """
    gunzip -c -f $reads >${prefix}.R1.fastq
    """
}

/*
 * Counting
 */

process counts {
  tag "$prefix"
  label 'biopython'
  label 'lowCpus'
  label 'medMem'

  publishDir "${params.outdir}/counts", mode: 'copy'

  input:
  set val(prefix), file(reads) from chReadsGunzipped
  file(library) from chLibraryCsv.collect()

  output:
  file("${prefix}.counts") into countsToMerge
  file("${prefix}.stats") into chStats

  script:
  opts = params.reverse ? "--reverse" : ''
  """
  count_spacers.py -f $reads -o $prefix -i $library $opts
  """
}

process mergeCounts {
  label 'rbase'
  label 'lowCpu'
  label 'medMem'

  publishDir "${params.outdir}/counts", mode: 'copy'

  input:
  file input_counts from countsToMerge.collect()

  output:
  file "tablecounts_raw.csv"

  script:
  """
  echo -e ${input_counts} | tr " " "\n" > listofcounts.tsv
  makeCountTable.r listofcounts.tsv
  """
}


/*
/* MultiQC
 */

process get_software_versions {
  label 'python'
  label 'lowCpu'
  label 'lowMem'

  input:
  file 'v_fastqc.txt'   from fastqcVersionCh
  file 'v_multiqc.txt'  from multiqcVersionCh 

  output:
  file 'software_versions_mqc.yaml' into software_versions_yaml

  script:
  """
  echo $workflow.manifest.version > v_pipeline.txt
  echo $workflow.nextflow.version > v_nextflow.txt
  python --version 2> v_python.txt
  scrape_software_versions.py > software_versions_mqc.yaml
  """
}

process workflow_summary_mqc {  
  label 'onlyLinux'
  label 'lowCpu'
  label 'lowMem'

  when:
  !params.skipMultiqc

  output:
  file 'workflow_summary_mqc.yaml' into workflow_summary_yaml

  exec:
  def yaml_file = task.workDir.resolve('workflow_summary_mqc.yaml')
  yaml_file.text  = """
  id: 'summary'
  description: " - this information is collected when the pipeline is started."
  section_name: 'Workflow Summary'
  section_href: 'https://gitlab.curie.fr/rnaseq'
  plot_type: 'html'
  data: |
      <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
      </dl>
  """.stripIndent()
}

process multiqc {
  label 'multiqc' 
  label 'lowCpu'
  label 'lowMem'

  publishDir "${params.outdir}/MultiQC/", mode: 'copy'

  when:
  !params.skipMultiqc

  input:
  file splan from chSplan.first()
  file multiqc_config from chMultiqcConfig
  file('fastqc/*') from fastqcResults.map{items->items[1]}.collect().ifEmpty([])
  file('stats/*') from chStats.collect()
  file ('software_versions/*') from software_versions_yaml.collect()
  file ('workflow_summary/*') from workflow_summary_yaml.collect()
 
  output:
  file splan
  file "*report.html" into multiqc_report
  file "*_data"

  script:
  rtitle = customRunName ? "--title \"$customRunName\"" : ''
  rfilename = customRunName ? "--filename " + customRunName + "_crispr_report" : "--filename crispr_report"
  metadataOpts = params.metadata ? "--metadata ${metadata}" : ""
  splanOpts = params.samplePlan ? "--splan ${params.samplePlan}" : ""
  """	
  mqc_header.py --name "CRISPR" --version "${workflow.manifest.version}" ${metadataOpts} ${splanOpts} > multiqc-config-header.yaml
  multiqc . -f $rtitle $rfilename -m fastqc -m custom_content -c multiqc-config-header.yaml -c $multiqc_config
  """
}

/*
 * Sub-routine
 */
process output_documentation {
    label 'rmarkdown'
    label 'lowCpu'
    label 'lowMem'

    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    file output_docs from chOutputDocs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}

workflow.onComplete {

    /*pipeline_report.html*/

    def report_fields = [:]
    report_fields['version'] = workflow.manifest.version
    report_fields['runName'] = custom_runName ?: workflow.runName
    report_fields['success'] = workflow.success
    report_fields['dateComplete'] = workflow.complete
    report_fields['duration'] = workflow.duration
    report_fields['exitStatus'] = workflow.exitStatus
    report_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    report_fields['errorReport'] = (workflow.errorReport ?: 'None')
    report_fields['commandLine'] = workflow.commandLine
    report_fields['projectDir'] = workflow.projectDir
    report_fields['summary'] = summary
    report_fields['summary']['Date Started'] = workflow.start
    report_fields['summary']['Date Completed'] = workflow.complete
    report_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    report_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) report_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) report_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) report_fields['summary']['Pipeline Git branch/tag'] = workflow.revision

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/oncomplete_template.txt")
    def txt_template = engine.createTemplate(tf).make(report_fields)
    def report_txt = txt_template.toString()
    
    // Render the HTML template
    def hf = new File("$baseDir/assets/oncomplete_template.html")
    def html_template = engine.createTemplate(hf).make(report_fields)
    def report_html = html_template.toString()

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/pipeline_info/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << report_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << report_txt }

    /*oncomplete file*/

    File woc = new File("${params.outdir}/workflow.oncomplete.txt")
    Map endSummary = [:]
    endSummary['Completed on'] = workflow.complete
    endSummary['Duration']     = workflow.duration
    endSummary['Success']      = workflow.success
    endSummary['exit status']  = workflow.exitStatus
    endSummary['Error report'] = workflow.errorReport ?: '-'
    String endWfSummary = endSummary.collect { k,v -> "${k.padRight(30, '.')}: $v" }.join("\n")
    println endWfSummary
    String execInfo = "${fullSum}\nExecution summary\n${logSep}\n${endWfSummary}\n${logSep}\n"
    woc.write(execInfo)

    /*final logs*/
    if(workflow.success){
        log.info "[rnaseq] Pipeline Complete"
    }else{
        log.info "[rnaseq] FAILED: $workflow.runName"
        if( workflow.profile == 'test'){
            log.error "====================================================\n" +
                    "  WARNING! You are running with the profile 'test' only\n" +
                    "  pipeline config profile, which runs on the head node\n" +
                    "  and assumes all software is on the PATH.\n" +
                    "  This is probably why everything broke.\n" +
                    "  Please use `-profile test,conda` or `-profile test,singularity` to run on local.\n" +
                    "  Please use `-profile test,conda,cluster` or `-profile test,singularity,cluster` to run on your cluster.\n" +
                    "============================================================"
        }
    }
 
}
