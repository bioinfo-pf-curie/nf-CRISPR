# Déploiement via geniac

Le module `geniac` permet de générer les différentes configurations nextflow 
nécessaires pour définir l'environnement d'exécution du pipeline. 

## Prérequis

* git (>= 2.0) [required]
* cmake (>= 3.0) [required]
* Nextflow (>= 20.01) [required]
* Singularity (>= 3.2) [optional]
* Docker (>= 18.0) [optional]

> La procédure de déploiement précisée dans ce document utilise des variables 
d'environnements qui sont définies par l'utilisateur. Les 
valeurs données ci dessous ne sont données qu'à titre d'exemple.

```shell
#!/usr/bin/env bash
export WORK_DIR=/data/tmp/$USER/sandbox/nf-CRISPR
export SRC_DIR=$WORK_DIR/src
export INSTALL_DIR=$WORK_DIR/install
export BUILD_DIR=$WORK_DIR/build
```

## Initialisation

En utilisant les options par défaut, seul le dossier où le pipeline va être déployé 
est nécessaire à cette étape (via l'option `CMAKE_INSTALL_PREFIX`)
```shell
git clone --recursive https://gitlab.curie.fr/data-analysis/nf-CRISPR $SRC_DIR
mkdir -p $INSTALL_DIR $BUILD_DIR
cd $BUILD_DIR
cmake $SRC_DIR/geniac -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
```

Les options acceptées par la commande `cmake` sont listées ci dessous
* `ap_annotation_path`: Chemin vers les annotations utilisées par le pipeline. (`""`)
* `ap_install_docker_images`: Active la construction des conteneurs dockers (`"OFF"`)
* `ap_install_docker_recipes`: Active la génération des recettes docker (`"OFF"`)
* `ap_install_singularity_images`: Active la construction des conteneurs singularity (`"OFF"`)
* `ap_install_singularity_recipes`: Active la génération des recettes docker (`"OFF"`)
* `ap_nf_executor`: exécuteur utilisé par nextflow (`"pbs"`)
* `ap_singularity_image_path`: Chemin vers les conteneurs singularity du pipeline (`""`)
* `ap_use_singularity_image_link`: Utilise le chemin des images singularity (`"OFF"`)

## Exemple 

Dans cet exemple, les images singularity présent dans le dossier `SING_DIR` vont être 
utilisées pour déployer le pipeline en utilisant l'option `ap_singularity_image_path` et `ap_use_singularity_image_link`

```shell
cmake $SRC_DIR/geniac -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -Dap_singularity_image_path="${SING_DIR}" -Dap_use_singularity_image_link="ON"  
```

## Installation

> Si l'installation des images `singularity` ou `docker` a été activé à l'étape précédente, il 
> faudra exécuter la commande `make` en tant qu'utilisateur `root`

```shell
cd $BUILD_DIR
make
make install
```

# Test

## Singularity


```shell
cd ${INSTALL_DIR}/pipeline  

nextflow run main.nf --singleEnd 'true' --genome 'hg38' --library 'GW-KO-Sabatini-Human-10' --samplePlan 'test/sample_plan.csv' -profile singularity
```

## Multiconda

Le profile `multiconda`  génère un environement `conda` par outil listé dans le fichier `conf/base.conf`

```shell
cd ${INSTALL_DIR}/pipeline  

nextflow run main.nf --singleEnd 'true' --genome 'hg38' --library 'GW-KO-Sabatini-Human-10' --samplePlan 'test/sample_plan.csv' -profile multiconda
```
