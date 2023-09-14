#!/usr/bin/env Rscript
# Command line argument processing
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Usage: makeCountTable.r <inputList> <gtf> <count_tool> <stranded>", call.=FALSE)
}
inputFiles <- args[1]

##################################################################

exprs.in <- as.vector(read.table(inputFiles, header=FALSE)[,1])

message("loading counts ...")
counts.exprs <- lapply(1:length(exprs.in), function(i){
  counts.exprs <- read.csv(exprs.in[i], sep=",", header=FALSE, row.names=1, check.names=FALSE)
  counts.v <- counts.exprs[,3]
  names(counts.v) <- rownames(counts.exprs)
  return(counts.v)
})
counts.exprs <- data.frame(counts.exprs)

## Add annotation
annot <- read.csv(exprs.in[1], sep=",", header=FALSE, row.names=1, check.names=FALSE)
counts.exprs <- cbind(counts.exprs, annot[,c(2,1)])

colnames(counts.exprs) <- c(gsub(".counts$","",basename(exprs.in)),"gene","sequence")

## export count table(s)
write.csv(counts.exprs, file="tablecounts_raw.csv", quote=FALSE)
