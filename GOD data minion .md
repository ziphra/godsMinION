4/22
# GOD data minion 
## Raw data 

##### Run 1   
**Date:** 6/24/2021    
**Yield:** 7.31 Gb in 1d 2h 11min   
**instrument:** MN28337   
**flowcell id:** FAL50852   
**sample id:** 4092-WGS-24062020   
**protocol run id:** 4caf887c-59e4-419e-8f58-86aa69a3fc21   
**acquisition run id:** 45e21adf332dc913f1fa60113a0bd31cab2d622f   




##### Run 2  
**Date:** 7/1/2021   
**Yield:** 8.34 Gb in 2d 1h 6min   
**flow_cell\_id:** FAL50903   
**sample_id:** 4092   
**protocol run id:** f575c80b-6f7e-4e3b-a0bd-c321e9be6ff8   
**acquisition run id:** 880cb58e71070976d5643eac57cd1e77600e6427   




## Basecalling 
### Guppy 5.1.15
```
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
```


## Alignment 

**Reference genome:** hg38
### with minimap2 2.24-r1122
- **Reference indexing**   
```
minimap2 -x map-ont hg38_GenDev.fa -d hg38_GenDev.fa.mmi
```
- **Alignment**    
```
minimap2 -t 10 -ax map-ont /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa ../fastq/basecalled.fastq | samtools sort -@ 8 -o minimap2_alignment.bam
```

#### Statistics summary from the alignment
#### Q Scores

| name    | mean  | q10   | q50   | q90   |
|---------|-------|-------|-------|-------|
| err_ont | 10.60 | 15.47 | 12.00 | 7.60  |
| substitution rate | 15.46 | 21.47 | 17.21 | 11.86 |
| deletion     | 14.01 | 19.77 | 16.02 | 11.46 |
| insertion     | 16.56 | 22.35 | 18.00 | 12.82 |

### with LRA 1.3.2 (Aligner)
- **Reference indexing**   
```
lra index -ONT hg38_GenDev.fa
```

- **Alignment**   
```
lra align -ONT -t 10 /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa ../fastq/basecalled.fastq -p s | samtools sort -@ 4 -o lra.bam
```

#### Statistics summary from the alignment
##### Q Scores
| name    | mean  | q10   | q50   | q90   |
|---------|-------|-------|-------|-------|
| error rate | 10.77 | 15.42 | 12.10 | 7.93  |
| Substitution rate    | 16.85 | 22.50 | 18.39 | 13.38 |
| deletion     | 13.82 | 19.17 | 15.65 | 11.28 |
| insertion     | 16.11 | 21.43 | 17.44 | 12.62 |


## Quality check 
**See quality check report for reads aligned with [minimap2](https://htmlpreview.github.io/?https://github.com/ziphra/long_reads/blob/main/files/mmiQC.html) and for reads aligned with [lra](https://htmlpreview.github.io/?https://github.com/ziphra/long_reads/blob/main/files/lraQC.html)**

- **Mean coverage** = 6 with minimap2, which is what could be expected for 2 MinION runs (see 2016 ONT post ["Human Genome on a MinION"](https://nanoporetech.com/about-us/news/human-genome-minion)). However, steady developments in flow cell chemistry, library preparation and base calling algorithms has seen reported sequencing yields increase from less than 3 GB to greater than 40 GB, allowing to have a 10x read depth from a single flowcell. 

- **Read length** seems short, even if similar read length from minION sequencing were recently reported in the litterature ([Lamb et al, 2021](https://doi.org/10.1371/journal.pone.0261274)). We would usually expect a mean read length ranging from 8 to 20kb ([Leung et al, 2022](https://www.nature.com/articles/s41598-022-08576-4)). For structural variants detection, 20kb read length and longer allows to detects SVs accurately and sensitively ([Jiang et al, 2021](https://doi.org/10.1186/s12859‐021‐04422‐y)).



## SNP calling 
### Pepper Margin Deep Variant
Even though [Lamb et al, 2021](https://doi.org/10.1371/journal.pone.0261274) suggest ONT’s MinION sequencing at low coverage could be a useful tool for in-situ genomic prediction, with such bad quality scores, SNP cannot be recalled with confidence. 

```
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
```

**See [PMDV report](https://htmlpreview.github.io/?https://github.com/ziphra/long_reads/blob/main/files/pmdvQC.html)**


## Structural variant calling 
Structutal variant calling might be challenging due to low read coverage, and not so long read length. 
A table summarizing parameters that can be adjust can be found here. Parameters that can be adjust to troubleshot low X and smaller reads are shown in red. 

### Sniffles 
```
sniffles -i ../minimap2MD/minimap2MD.bam \
--vcf snifflesMD.vcf \
--tandem-repeats human_GRCh38_no_alt_analysis_set.trf.bed \
--reference /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa \
-t 14 
```

In *low depth mode:*

```
sniffles -i ../minimap2MD/minimap2MD.bam \
--vcf snifflesMD.vcf \
--tandem-repeats human_GRCh38_no_alt_analysis_set.trf.bed \
--reference /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa \
-t 14 \
—mapq 19 \
—minsupport 3 \
--long-dup-length 20000 \
--long-dup-coverage 0.5
```

### CuteSV
```
cuteSV ../lra/lra.bam /media/god/DATA/reference_genome/hg38/hg38_GenDev.fa lra_cutesv.vcf . \
    --max_cluster_bias_INS 100 \
    --diff_ratio_merging_INS 0.3 \
    --max_cluster_bias_DEL 100 \
    --diff_ratio_merging_DEL 0.3 \
    --threads 16
```


## Microarray results and hypothese.
- **duplication**    chr11:116825102-116913660
- **deletion**    chr11:33856203-33877519

**Hypothesis:** duplication in APOC3 chr11:116829907-116833072


