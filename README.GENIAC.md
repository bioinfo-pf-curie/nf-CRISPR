# Prerequis


### Cmake3
sudo yum install cmake3

### clone repo 
mkdir nf-CRISPR-GENIAC  
cd nf-CRISPR-GENIAC  

git clone --recursive https://gitlab.curie.fr/data-analysis/nf-CRISPR  
cd nf-CRISPR  
git checkout geniac  

CRISPR=`pwd`

cd ..  
mkdir build  
mkdir deploy  
mkdir singularity

PATH_TO_DEPLOY=${CRISPR}/deploy  
PATH_TO_BUILD=${CRISPR}/build  
PATH_TO_SINGULARITY=${CRISPR}/singularity  


#   TEST PROFIL SINGULARITY
 

### singularity
export PATH=/bioinfo/local/build/singularity/singularity-3.5.2/bin:$PATH  
export LC_ALL=en_US.utf-8  
export LANGAGE=en_US.utf-8  

### copy des images singularity  

cp /data/tmp/fjarlier/nf-CRISPR-Singularity/*.simg ${PATH_TO_SINGULARITY}  

### build 

cd build  

cmake3 ${CRISPR}/geniac -DCMAKE_INSTALL_PREFIX="${PATH_TO_DEPLOY}" -Dap_annotation_path="" -Dap_install_docker_images="OFF" -Dap_install_docker_recipes="ON" -Dap_install_singularity_images="OFF" -Dap_install_singularity_recipes="ON" -Dap_nf_executor="pbs" -Dap_singularity_image_path="${PATH_TO_SINGULARITY}" -Dap_use_singularity_image_link="ON"  

make install  

### test
cd ${PATH_TO_DEPLOY}/pipeline  

nextflow run main.nf --singleEnd 'true' --genome 'hg38' --library 'GW-KO-Sabatini-Human-10' --samplePlan '${PATH_TO_DEPLOY}/pipeline/test/sample_plan.csv' -profile singularity


#   TEST PROFIL MULTICONDA


### miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  
bash Miniconda3-latest-Linux-x86_64.sh  
export PATH=/data/users/${usr_name}/miniconda3/bin:$PATH  

### build environment

cd build    

cmake3 ${CRISPR}/geniac -DCMAKE_INSTALL_PREFIX="${PATH_TO_DEPLOY}" -Dap_annotation_path="" -Dap_install_docker_images="OFF" -Dap_install_docker_recipes="ON" -Dap_install_singularity_images="OFF" -Dap_install_singularity_recipes="ON" -Dap_nf_executor="pbs" -Dap_singularity_image_path="" -Dap_use_singularity_image_link="OFF"  

make install  

### run pipeline

cd ${PATH_TO_DEPLOY}/pipeline  

nextflow run main.nf --singleEnd 'true' --genome 'hg38' --library 'GW-KO-Sabatini-Human-10' --samplePlan '${PATH_TO_DEPLOY}/pipeline/test/sample_plan.csv' -profile multiconda




