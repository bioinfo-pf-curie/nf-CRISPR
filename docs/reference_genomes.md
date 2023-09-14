# Reference Genomes and Annotations Configuration

The pipeline needs a few annotation files for the analysis.

These paths can be supplied on the command line at run time (see the [usage docs](../usage.md)),
but for convenience it's often better to save these paths in a nextflow config file.
See below for instructions on how to do this.

## Adding paths to a config file
In the context of the CRISPR analysis, the main annotations are the description of the CRISPR libraries used for the screens.
To make this easier, the pipeline comes configured with a few library keywords which correspond to preconfigured design paths available in `assets/libraries`, and that you can just specify `--library ID` when running the pipeline.

To add any other library, add paths to your config file using the following template:

```nextflow
params {
  libraries {
    'YOUR-ID' {
      description = '<DESCRIPTION OF THE LIBRARY>'
      design  = '<PATH TO CSV FILE>/lib.csv'
    }
    'OTHER-LIBRARY' {
      // [..]
    }
  }
}
```

You can add as many libraries as you like as long as they have unique IDs.

## Library cleaning

CRISPR libraries usually need to be cleaned before using them for analysis.
Here is a few cleaning steps we usually advice ;

- Create a `csv` files with the following information: guide_id, sequence, gene

```
sgCHRND_1,GGAGAACCGCACCTACCCCG,CHRND
sgGPR142_2,CCATGGAGCAAAAGATCCAG,GPR142
sgCDH17_9,GAAGACACAGGGAGTGAAGA,CDH17
sgKCNN3_8,ATACCTTTCACAGACACGGA,KCNN3
```

In most of the libraries, there are several guides (~10) per gene.

- Convert the `cvs` file into a `fastq` file

```
awk -F "," '{print "@"$3"_"$1"\n"$2"\n+\nIIIIIIIIIIIIIIIIIIII"}' library.csv >library.fastq
```

- Align the guide sequences on the reference genome using stringent parameters

```
bowtie hg38_basechr.fa -v 0 --best --strata -l 20 -y -a -p 8 -S library.fastq > library_VS_hg38_bowtie1_v0_best_strata_l20_y_a.sam
```

- Remove from the `csv` file, any guides that do not align AND which are not negative controls ("Non-TargetingXXXX" or "NonTargetingControlGuideForHuman" or "INTERGENIC")

- Remove guides that align at several loci on the reference genome

- Merge the remaining guides that have exactly yhe same sequence, merging their `guide_id` and `gene_id` ("|" separated)

```
sgZNF177_2|sgZNF559-ZNF177_2,ACACAGTCTGATCTCCAAGG,ZNF177|ZNF559-ZNF177
sgRBM14_10|sgRBM14-RBM4_10,TGGTGGAGATGTCGCGCCCA,RBM14|RBM14-RBM4
sgCORO7_5|sgCORO7-PAM16_6,GCGGTGATGGAGACACCCGT,CORO7|CORO7-PAM16
sgPRAMEF22_7|sgPRAMEF3_8,CGACGTGCCACAGCAAGGGC,PRAMEF22|PRAMEF3
sgPTGES3L_2|sgPTGES3L-AARSD1_2,GAGAAAATGGAAGGAAAAGG,PTGES3L|PTGES3L-AARSD1
```

In average, these cleaning steps usually remove 5 to 10% of the initial guides.



