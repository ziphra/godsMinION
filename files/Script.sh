#!/bin/sh

#  Script.sh
#  
#
#  Created by Euphrasie Servant on 04/05/2022.
#

###### 1. BASECALLING ######
guppy_basecaller \
-i ./data \
-s ./guppy_output \
--records_per_fastq 0 \
--disable_qscore_filtering \
-r \
-c dna_r9.4.1_450bps_hac.cfg \
--device 'auto' \
--compress_fastq \
--num_callers 16 \
--chunk_size 1000 \
--gpu_runners_per_device 4 \
--chunks_per_runner 512 \
--disable_pings \


###### 2. MAPPING ######
# minimap2 #

# index
minimap2 -x map-ont hg38_GenDev.fa -d hg38_GenDev.fa.mmi

# alignment
minimap2 -t 10 -ax map-ont /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa ../fastq/basecalled.fastq | samtools sort -@ 8 -o minimap2_alignment.bam


# lra #

#index
lra index -ONT hg38_GenDev.fa

# alignment
lra align -ONT -t 10 /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa ../fastq/basecalled.fastq -p s | samtools sort -@ 4 -o lra.bam


###### 3. SNP calling ######

BASE="`pwd`"

# Set up input data
INPUT_DIR="${BASE}/input/data"
BAM_DIR="/home/euphrasie/Documents/lr_test3/minimap2MD"
HGREF="/media/god/DATA/reference_genome/hg38/hg38_GenDev.fa"
BAM="minimap2MD.bam"

# Set the number of CPUs to use
THREADS="14"

# Set up output directory
OUTPUT_DIR="${BASE}/output"
OUTPUT_PREFIX="god_pmdvMD"
OUTPUT_VCF="god_pmdvMD"

## Create local directory structure
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${INPUT_DIR}"



docker run --ipc=host \
--gpus all \
-v "${INPUT_DIR}":"${INPUT_DIR}" \
-v "${OUTPUT_DIR}":"${OUTPUT_DIR}" \
-v "${BAM_DIR}":"${BAM_DIR}" \
-v "${HGREF}":"${HGREF}" \
kishwars/pepper_deepvariant:r0.8-gpu \
run_pepper_margin_deepvariant call_variant \
-o "${OUTPUT_DIR}" \
-b "${BAM_DIR}/${BAM}" \
-f "${HGREF}" \
-p "${OUTPUT_PREFIX}" \
-t ${THREADS} \
-g \
--ont_r9_guppy5_sup


###### 3. SV calling ######

## sniffles ##

# default mode
sniffles -i ../minimap2MD/minimap2MD.bam \
--vcf snifflesMD.vcf \
--tandem-repeats human_GRCh38_no_alt_analysis_set.trf.bed \
--reference /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa \
-t 14


# 'low X mode'
sniffles -i ../minimap2MD/minimap2MD.bam \
--vcf snifflesMD.vcf \
--tandem-repeats human_GRCh38_no_alt_analysis_set.trf.bed \
--reference /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa \
-t 14 \
—mapq 19 \
—minsupport 3 \
--long-dup-length 20000 \
--long-dup-coverage 0.5



## cute sv ##
cuteSV ../lra/lra.bam /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa lra_cutesv.vcf . \
    --max_cluster_bias_INS 100 \
    --diff_ratio_merging_INS 0.3 \
    --max_cluster_bias_DEL 100 \
    --diff_ratio_merging_DEL 0.3 \
    --threads 16
