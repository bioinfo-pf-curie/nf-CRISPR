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
customRunName = !(workflow.runName ==~ /[a-z]+_[a-z]+/) ? workflow.runName: params.name

// Stage config files
multiqcConfigCh = Channel.fromPath(params.multiqcConfig)
outputDocsCh = Channel.fromPath("$baseDir/docs/output.md")

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
      .set { libraryCsvCh }
}else if ( params.libraryDesign ){
  Channel.fromPath( params.libraryDesign )
      .ifEmpty { exit 1, "Reference library not found: ${params.libraryDesign}" }
      .set { libraryCsvCh }
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
         .into {readsFastqcCh; readsGunzipCh}
   }else{
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[0], [file(row[2]), file(row[3])]] }
         .into {readsFastqcCh; readsGunzipCh}
   }
   params.reads=false
}
else if(params.readPaths){
    if(params.singleEnd){
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into {readsFastqcCh; readsGunzipCh}
    } else {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0]), file(row[1][1])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into {readsFastqcCh; readsGunzipCh}
    }
} else {
    Channel
        .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
        .into {readsFastqcCh; readsGunzipCh}
}

/*
 * Make sample plan if not available
 */

if (params.samplePlan){
  samplePlanCh = Channel.fromPath(params.samplePlan)
}else{
  if (params.singleEnd){
    Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
        }
       .set{ samplePlanCh }
  }else{
     Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
        }
       .set{ samplePlanCh }
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
def summary = [
    'Pipeline Name': 'CRISPR',
    'Pipeline Version': workflow.manifest.version,
    'Run Name': customRunName ?: workflow.runName,
    'SamplePlan': params.samplePlan ?: null,
    'Reads': params.reads?: null ,
    'Library Name': params.library?: null,
    'Library Design': params.libraryDesign ?: designPath,
    'Count Strand': params.reverse ? "reverse" : "forward",
    'Max Memory': params.maxMemory,
    'Max CPUs': params.maxCpus,
    'Max Time': params.maxTime,
    'Output dir': params.outdir,
    'Working dir': workflow.workDir,
    'Container Engine': workflow.containerEngine,
    'Current user': "$USER",
    'Working dir': workflow.workDir,
    'Output dir': params.outdir,
    'Config Profile': workflow.profile,
    'E-mail Address': params.email ?: null
].findAll{ it.value != null }

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
    set val(name), file(reads) from readsFastqcCh

    output:
    set val(prefix), file("${prefix}*.{zip,html}") into fastqcResultsCh

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
    set val(name), file(reads) from readsGunzipCh

    output:
    set val(prefix), file("${prefix}.R1.fastq") into readsGunzipedCh

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
  set val(prefix), file(reads) from readsGunzipedCh
  file(library) from libraryCsvCh.collect()

  output:
  file("${prefix}.counts") into countsToMergeCh
  file("${prefix}.stats") into statsCh

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
  file input_counts from countsToMergeCh.collect()

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

process getSoftwareVersions {
  label 'python'
  label 'lowCpu'
  label 'lowMem'

  input:
  file 'v_fastqc.txt'   from fastqcVersionCh
  file 'v_multiqc.txt'  from multiqcVersionCh 

  output:
  file 'software_versions_mqc.yaml' into softwareVersionsYamlCh

  script:
  """
  echo $workflow.manifest.version > v_pipeline.txt
  echo $workflow.nextflow.version > v_nextflow.txt
  python --version 2> v_python.txt
  scrape_software_versions.py > software_versions_mqc.yaml
  """
}

process workflowSummaryMqc {
  label 'onlyLinux'
  label 'lowCpu'
  label 'lowMem'

  when:
  !params.skipMultiqc

  output:
  file 'workflow_summary_mqc.yaml' into workflowSummaryYamlCh

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
  file splan from samplePlanCh.first()
  file multiqc_config from multiqcConfigCh
  file('fastqc/*') from fastqcResultsCh.map{items->items[1]}.collect().ifEmpty([])
  file('stats/*') from statsCh.collect()
  file ('software_versions/*') from softwareVersionsYamlCh.collect()
  file ('workflow_summary/*') from workflowSummaryYamlCh.collect()
 
  output:
  file splan
  file "*report.html" into multiqcReportCh
  file "*_data"

  script:
  rtitle = customRunName ? "--title \"$customRunName\"" : ''
  rfilename = customRunName ? "--filename " + customRunName + "_crispr_report" : "--filename crispr_report"
  metadataOpts = params.metadata ? "--metadata ${metadata}" : ""
  splanOpts = params.samplePlan ? "--splan ${splan}" : ""
  """	
  mqc_header.py --name "CRISPR" --version "${workflow.manifest.version}" ${metadataOpts} ${splanOpts} > multiqc-config-header.yaml
  multiqc . -f $rtitle $rfilename -m fastqc -m custom_content -c multiqc-config-header.yaml -c $multiqc_config
  """
}

/*
 * Sub-routine
 */
process outputDocumentation {
    label 'rmarkdown'
    label 'lowCpu'
    label 'lowMem'

    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    file output_docs from outputDocsCh

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}

workflow.onComplete {

    /*pipeline_report.html*/

    def reportFields = [
        version: workflow.manifest.version,
        runName: customRunName ?: workflow.runName,
        success: workflow.success,
        dateComplete: workflow.complete,
        duration: workflow.duration,
        exitStatus: workflow.exitStatus,
        errorMessage: (workflow.errorMessage ?: 'None'),
        errorReport: (workflow.errorReport ?: 'None'),
        commandLine: workflow.commandLine,
        projectDir: workflow.projectDir,
        summary: summary + [
            'Date Started': workflow.start,
            'Date Completed': workflow.complete,
            'Pipeline script file path': workflow.scriptFile,
            'Pipeline script hash ID': workflow.scriptId,
            'Pipeline repository Git URL': workflow.repository,
            'Pipeline repository Git Commit': workflow.commitId,
            'Pipeline Git branch/tag': workflow.revision,
        ].findAll{ it.value != null },
    ]

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/oncomplete_template.txt")
    def txtTemplate = engine.createTemplate(tf).make(reportFields)
    def reportTxt = txtTemplate.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/oncomplete_template.html")
    def htmlTemplate = engine.createTemplate(hf).make(reportFields)
    def reportHtml = htmlTemplate.toString()

    // Write summary e-mail HTML to a file
    def outputD = new File( "${params.outdir}/pipeline_info/" )
    if( !outputD.exists() ) {
      outputD.mkdirs()
    }
    def output_hf = new File( outputD, "pipeline_report.html" )
    output_hf.withWriter { w -> w << reportHtml }
    def output_tf = new File( outputD, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << reportTxt }

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
