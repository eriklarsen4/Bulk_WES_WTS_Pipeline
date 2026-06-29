# WES/WTS Nextflow Pipeline

## Pre-req's

### HPC Modules Required
module load gnu8/8.3.0
module load bwa/0.7.17
module load samtools/1.19.2
module load picard/2.23.4
module load gatk/4.2.5.0
module load star/2.7.11b
module load salmon/1.10.0
module load trimgalore
module load pigz/2.7
module load rstudio-server
module load vcftools/0.1.16
module load sratoolkit/3.1.1

### Reference Genome Setup
Ensure GRCh38 reference files exist at:
<filepath to repository root>/genomicsshare/references/GRCh38/

### R Dependencies
Run once before pipeline:
bash setup/install_r_dependencies.sh

### If on SLURM
bash export SLURM_ACCOUNT=<account name>

## Usage
nextflow run main.nf \ 
-profile slurm \
--input_dirs "/path/to/sample1,/path/to/sample2" \
--genome GRCh38 \
--analysis_type both
-resume # <in case of partial runs>

## Output
Results in each sample directory under /results/
