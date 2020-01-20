
1) Extraire des grands tableaux Excel généralement envoyés par Camille, les 3 colonnes (pas toujours les mêmes en fonction des librairies) nécessaires à la création de la librairie au format CSV, à savoir : guide_id, sequence, gene

eg :

sgCHRND_1,GGAGAACCGCACCTACCCCG,CHRND
sgGPR142_2,CCATGGAGCAAAAGATCCAG,GPR142
sgCDH17_9,GAAGACACAGGGAGTGAAGA,CDH17
sgKCNN3_8,ATACCTTTCACAGACACGGA,KCNN3

Généralement il y a environ 10 guides par gène


2) Convertir le CSV en FASTQ :

awk -F "," '{print "@"$3"_"$1"\n"$2"\n+\nIIIIIIIIIIIIIIIIIIII"}' library.csv >library.fastq

3) Mapper les guides sur le génome de référence de manière stringente :

/bioinfo/local/build/Centos/bowtie/bowtie-1.2/bin/bowtie /annotations/pipelines/Human/hg38_base/indexes/bowtie/hg38_basechr.fa -v 0 --best --strata -l 20 -y -a -p 8 -S library.fastq >library_VS_hg38_bowtie1_v0_best_strata_l20_y_a.sam

4) Retirer de la librairie initiale les guides qui ne mappent pas sur le génome ET qui ne sont pas des guides de "contrôle négatif" (qui malheureusement portent des noms différents dans chaque librairie, tantôt leur guide_id est de type "Non-TargetingXXXX" tantôt de type "NonTargetingControlGuideForHuman" ou encore "INTERGENIC") => library_NoUnmapped.csv

5) Retirer de la librairie restante les guides qui mappent à plusieurs endroits sur le génome (multihits) => library_NoUnmapped_NoMultihits.csv

6) "Merger" dans les guides restants ceux qui ont exactement la même séquence en ne gardant qu'une seule fois la séquence mais en ajoutant un "|" entre les guide_id et les gene_id qui ont été mergés => library_NoUnmapped_NoMultihits_NonRedundant.csv

eg :

sgZNF177_2|sgZNF559-ZNF177_2,ACACAGTCTGATCTCCAAGG,ZNF177|ZNF559-ZNF177
sgRBM14_10|sgRBM14-RBM4_10,TGGTGGAGATGTCGCGCCCA,RBM14|RBM14-RBM4
sgCORO7_5|sgCORO7-PAM16_6,GCGGTGATGGAGACACCCGT,CORO7|CORO7-PAM16
sgPRAMEF22_7|sgPRAMEF3_8,CGACGTGCCACAGCAAGGGC,PRAMEF22|PRAMEF3
sgPTGES3L_2|sgPTGES3L-AARSD1_2,GAGAAAATGGAAGGAAAAGG,PTGES3L|PTGES3L-AARSD1


Généralement après tout ça je perds ~5-10% des guides initiaux


