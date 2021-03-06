# Final Script
NOTE: Not completed

[TOC]
   
 ### 1.1 - Getting the Data
 
First step is to download the list of SRR Accension numbers. The text file used in this script can be found [here](https://github.com/prvasquez/mangrove_killifish/blob/master/SRR_Acc_List.txt).

Downloading the data from NCBI requires the SRA Toolkit. If you're working from a shared cluster, the SRA toolkit may already be installed, if not, here is the [link](https://www.ncbi.nlm.nih.gov/sra/docs/toolkitsoft/).

To direct the download of the data off of NCBI, we have to configure the SRA toolkit and change the download directory.
```
prvasque@farm:~$ vdb-config -i
```
This command brings up the configuration menu. Navagate to the change option and change the directory to where you want the data to be downloaded. More info can be found [here](https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=toolkit_doc&f=std).

To download all the data off of NCBI I used this script.
```
#!/bin/bash -l
#SBATCH --mem=16000
#SBATCH -J download_sra
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/scripts
#SBATCH -o /home/prvasque/slurm-log/download_sra_stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/download_sra_stderr-%j.txt

# Load the sratoolkit module
module load sratoolkit

# File that contains the SRA accension numbers for the data we want
file=/home/prvasque/projects/mangrove_killifish_project/raw_data/sra/SRR_Acc_List.txt

# Removes spaces between the accension numbers
IFS=$'\n'

# Directory where data will be downloaded (may not be needed because of above step)
DIR="/home/prvasque/projects/mangrove_killifish_project/raw_data/sra/"

cd $DIR

# Code that iterates through list and downloads the data as .sra files.
for i in `cat $file`
do
	prefetch $i
done
```

### 1.2 Fastqc

Files are downloaded as .sra, however, they need to be .fastq for the next step. To do this I used this script.

```
#!/bin/bash -l
#SBATCH -J fastqdump
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/raw_data/fastq/
#SBATCH -o /home/prvasque/slurm-log/fastqdump_stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/fastqdump_stderr-%j.txt
#SBATCH -t 12:00:00
#SBATCH -c 2
#SBATCH --array=25941-26018

# Loads the sratoolkit
module load sratoolkit

# Because this process involves a lot of reading and writing on the computers part, I created a sratch directory in a node so less I/O has to happen
DIR=/scratch/prvasque/$SLURM_JOBID
mkdir -p $DIR

# Copies each .sra file to the scratch directory
cp /home/prvasque/projects/mangrove_killifish_project/raw_data/sra/SRR69$SLURM_ARRAY_TASK_ID.sra $DIR

# Splits the files and gzipps them
fastq-dump -I --split-files --gzip $DIR/SRR69$SLURM_ARRAY_TASK_ID.sra 

cp $DIR/*.fastq.gz /home/prvasque/projects/mangrove_killifish_project/raw_data/fastq/

# rm -rf /scratch/prvasque/$SLURM_JOBID
```
Now to run fastqc
```
#!/bin/bash -l
#SBATCH -J fastqc
#SBATCH -o /home/prvasque/slurm-log/fastqc-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/fastqc-stderr-%j.txt
#SBATCH --mem=6000
#SBATCH -c 2
#SBATCH -t 6:00:00
#SBATCH --array=25941-26018

# Load the fastqc module
module load fastqc

# Assign directory of data
DIR=/home/prvasque/projects/mangrove_killifish_project/raw_data

# Code to run fastqc
fastqc -o $DIR/fastqc/ $DIR/fastq/SRR69$SLURM_ARRAY_TASK_ID*.fastq.gz
```
### 1.3 Trimmomatic
```
#!/bin/bash -l
#SBATCH -c 6
#SBATCH --mem=16000
#SBATCH -J trimmomatic
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/raw_data/fastq/
#SBATCH -o /home/prvasque/slurm-log/trimmomatic_stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/trimmomatic_stderr-%j.txt
#SBATCH --array=25941-26018
#SBATCH --time=12:00:00
#SBATCH -p med

# Directory of data
DIR=/home/prvasque/projects/mangrove_killifish_project/raw_data/fastq/

# Output directory
outdir=/home/prvasque/projects/mangrove_killifish_project/trim/data/

# Change to 
cd $DIR

# Trimmomatic code
java -jar /share/apps/Trimmomatic-0.36/trimmomatic.jar PE SRR69$SLURM_ARRAY_TASK_ID\_1.fastq.gz \
        SRR69$SLURM_ARRAY_TASK_ID\_2.fastq.gz $outdir/SRR69$SLURM_ARRAY_TASK_ID\_1.qc.fq.gz \
        $outdir/orphans/69$SLURM_ARRAY_TASK_ID\_1_se $outdir/SRR69$SLURM_ARRAY_TASK_ID\_2.qc.fq.gz \
        $outdir/orphans/69$SLURM_ARRAY_TASK_ID\_2_se \
        ILLUMINACLIP:/home/prvasque/projects/mangrove_killifish_project/trim/adapters/NEBnextAdapt.fa:2:40:15 \
        LEADING:2 TRAILING:2 SLIDINGWINDOW:4:2 MINLEN:25
```
### 1.4.1 Downloading reference genome from NCBI
```
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/vertebrate_other/Kryptolebias_marmoratus/latest_assembly_versions/GCF_001649575.1_ASM164957v1/GCF_001649575.1_ASM164957v1_genomic.gff.gz
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/vertebrate_other/Kryptolebias_marmoratus/latest_assembly_versions/GCF_001649575.1_ASM164957v1/GCF_001649575.1_ASM164957v1_genomic.fna.gz
```
These files are gzipped so make sure to unzip them before continuing
```
gunzip *.gz
```
### 1.4.2 Mapping reads to reference genome using STAR
```
#!/bin/bash -l
#SBATCH --mem=40000
#SBATCH --cpus-per-task=24
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/scripts/
#SBATCH -o /home/prvasque/slurm-log/starindex/starindex-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/starindex/starindex-stderr-%j.txt
#SBATCH -J starindex_korea_latest
#SBATCH -t 6:00:00
#SBATCH -p med

# Load modules for STAR
module load perlnew/5.18.4
module load star/2.4.2a

# Directory of reference genome
DIR=/home/prvasque/projects/mangrove_killifish_project/raw_data/reference_genome/
cd $DIR

# Code for STAR alignment
STAR --runMode genomeGenerate --genomeDIR $DIR --genomeFastaFiles GCF_001649575.1_ASM164957v1_genomic.fna \
--sjdbGTFtagExonParentTranscript Parent --sjdbGTFfile GCF_001649575.1_ASM164957v1_genomic.gff \
--sjdbOverhang 99

echo "genome indexed"
```
### 1.4.3 Aligning sequences with the korea genome
```
#!/bin/bash -l
#SBATCH --cpus-per-task=24
#SBATCH --mem=40000
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/scripts/
#SBATCH -o /home/prvasque/slurm-log/staralignment/stargenoalign-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/staralignment/stargenoalign-stderr-%j.txt
#SBATCH -J staralignment_last_korea
#SBATCH -a 25941-26018
#SBATCH -t 6:00:00
#SBATCH -p med

# Load modules
module load perlnew/5.18.4
module load star/2.4.2a

# Directory of reference genome
genome_dir=/home/prvasque/projects/mangrove_killifish_project/raw_data/reference_genome/

# Directory of trimmed data
dir=/home/prvasque/projects/mangrove_killifish_project/trim/data

# Output directory
outdir=/home/prvasque/projects/mangrove_killifish_project/alignment

# Alignment code
STAR --genomeDir $genome_dir \
 --runThreadN 24 --readFilesCommand zcat --sjdbInsertSave all \
 --readFilesIn ${dir}/SRR69${SLURM_ARRAY_TASK_ID}_1.qc.fq.gz ${dir}/SRR69${SLURM_ARRAY_TASK_ID}_2.qc.fq.gz \
 --outFileNamePrefix ${outdir}/SRR69${SLURM_ARRAY_TASK_ID}
```
### 1.5.1 Samtools
Our files are currently in the .sam file format. However, for the next step in the pipeline they need to be in .bam format. Samtools will help us accomplish this goal.
```
#!/bin/bash -l
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/alignment/
#SBATCH --mem=16000
#SBATCH -o /home/prvasque/slurm-log/samtools/sambam-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/samtools/sambam-stderr-%j.txt
#SBATCH -J sam_to_bam
#SBATCH -p high
#SBATCH -t 12:00:00
#SBATCH -a 25941-26018%6

# Load module
module load samtools

# Create scratch directories
DIR=/scratch/prvasque/$SLURM_JOBID
mkdir -p $DIR/

# Echo hostname of file
echo 'hostname'

# Copy sam file into scratch directory
cp /home/prvasque/projects/mangrove_killifish_project/alignment/SRR69${SLURM_ARRAY_TASK_ID}Aligned.out.sam \
$DIR/SRR69${SLURM_ARRAY_TASK_ID}.Aligned.out.sam

# Code for using samtools
srun samtools view -bS -u $DIR/SRR69${SLURM_ARRAY_TASK_ID}Aligned.out.sam | \
 samtools sort --output-fmt BAM -o $DIR/SRR69${SLURM_ARRAY_TASK_ID}.bam

# Copy bam file back into normal directory
cp $DIR/SRR69${SLURM_ARRAY_TASK_ID}.bam /home/prvasque/projects/mangrove_killifish_project/alignment/SRR69${SLURM_ARRAY_TASK_ID}.bam 

# Remove scratch directory
rm -rf /scratch/prvasque/$SLURM_JOBID/
```
### 1.5.2 Santools sort
```
#!/bin/bash -l
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/alignment/bam/
#SBATCH --mem=16000
#SBATCH -o /home/prvasque/slurm-log/samtools/samsort-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/samtools/samsort-stderr-%j.txt
#SBATCH -J samsort
#SBATCH -p high
#SBATCH -t 12:00:00
#SBATCH -a 25941-26018%8

# Directory of data
DIR=/home/prvasque/projects/mangrove_killifish_project/alignment
cd $DIR

# Echo SRR accession name
echo SRR69${SLURM_ARRAY_TASK_ID}

# Code
samtools sort -n -o $DIR/sorted/SRR69${SLURM_ARRAY_TASK_ID}_sorted.bam \
	$DIR/bam/SRR69${SLURM_ARRAY_TASK_ID}.bam

echo 'done!'
```
### 1.6 HTSeq-Count
```
#!/bin/bash -l
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/scripts/
#SBATCH --mem=16000
#SBATCH -o /home/prvasque/slurm-log/htseq/hts_count-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/htseq/hts_count-stderr-%j.txt
#SBATCH -J hts_count
#SBATCH -p high
#SBATCH -t 12:00:00
#SBATCH -a 25941-26018%10


#module load pysam
#module load python
#module load HTSeq

# Load modules
module load bio

# Echo SRR accension number
echo SRR${SLURM_ARRAY_TASK_ID}

# Directory of sorted bam files
DIR=/home/prvasque/projects/mangrove_killifish_project/alignment/sorted

# Directory of reference genome
REF_DIR=/home/prvasque/projects/mangrove_killifish_project/raw_data/reference_genome

# Output directory
OUT_DIR=/home/prvasque/projects/mangrove_killifish_project/alignment/counts

# Code
htseq-count --type=gene -i Dbxref -f bam -s no $DIR/SRR69${SLURM_ARRAY_TASK_ID}_sorted.bam \
	$REF_DIR/GCF_001649575.1_ASM164957v1_genomic.gff > \
	$OUT_DIR/SRR69${SLURM_ARRAY_TASK_ID}count.txt

echo finished
```
### 1.7 Formatting Files for R analysis
This code should be done on the files created from HTSeq-Count
```
paste *.txt  | tail -n +2 |awk '{OFS="\t";for(i=2;i<=NF;i=i+2){printf "%s ", $i}{printf "%s", RS}}' >test.out.txt
cat SRR6925941count.txt | cut -f 1| tail -n +2| paste - test.out.txt | tr ' ' \\t > test2.out.txt 
touch test.names.txt
# echo NA >> test.names.txt
ls SRR* | sed 's/count\.txt//g' | tr '\n' \\t > test.names.txt
touch names.txt
echo $(cat test.names.txt) >> names.txt
cat names.txt test2.out.txt | tr ' ' \\t > test4.out.txt
```

### 2.0 R Code
```
# Set directory
setwd("/Users/prvasquez/Whiteheadlab/Projects/Mangrove_killifish/data") 

# Install dependancies

library("BiocInstaller", lib.loc="/Library/Frameworks/R.framework/Versions/3.5/Resources/library")

biocLite("limma")
biocLite("edgeR")
install.packages("ggplot2")
install.packages("gplots")
install.packages("dendextend")

library(limma)
library(edgeR)
library(ggplot2)
library(gplots)
library(dendextend)

# Design Matrix
sampleTable <- read.csv("design.matrixSRR08282018.csv", row.names = 1)
data.frame(sampleTable)
sampleTable_control <- subset(sampleTable, Air == "C")
data.frame(sampleTable_control)
sampleTable_treatment <- subset(sampleTable, Air == "A" | Time == 0) # include time = 0 for the intercept group
data.frame(sampleTable_treatment)

# Setup read counts file
y <- read.table("~/Whiteheadlab/Projects/Mangrove_killifish/data/test2.out.txt", header = FALSE, sep = "\t", row.names = 1)
z <- scan("~/Whiteheadlab/Projects/Mangrove_killifish/data/test.names.txt", sep = '\t', what = "character")
colnames(y) <- z

# Subset data
y_control <- subset(y, select = c(row.names(sampleTable_control)))
y_treatment <- subset(y, select = c(row.names(sampleTable_treatment)))

# Filter data
y <- y[rowSums(y>10)>5, ]
y_control <- y_control[rowSums(y_control>10)>5, ]
y_treatment <- y_treatment[rowSums(y_treatment>10)>5, ] # ignore all read counts under 5 (or 10?)
data.frame(y_control)
data.frame(y_treatment)

# Create the counts matrix for control
dge_control <- DGEList(counts = y_control)
dge_control <- calcNormFactors(dge_control)
logCPM_control <- cpm(dge_control, prior.count = 2, log = TRUE)

# Design matrix for control
Time_control <- factor(sampleTable_control$Time, levels = c("0", "72", "164"))
Time_control <- relevel(Time_control, ref = "0")
Strain_control <- factor(sampleTable_control$Strain, levels = c("HON11", "FW"))
designmatrix_control <- model.matrix(~Time_control*Strain_control)
colnames(designmatrix_control)

# Fit voom for control
v_control <- voom(dge_control, designmatrix_control, plot = TRUE)
colnames(v_control)

# Lmfit for control
fit_control <- lmFit(v_control, designmatrix_control)
fit_control <- eBayes(fit_control)
summary(decideTests(fit_control))
Dif_gene_control <- topTable(fit_control, coef = 5:6, adjust.method = "BH")
sum(Dif_gene_control$adj.P.Val<0.05)

# Create counts matrix for treatment group
dge_treatment <- DGEList(counts = y_treatment)
dge_treatment <- calcNormFactors(dge_treatment)
logcpm_treatment <- cpm(dge_treatment, prior.count = 2, log = TRUE)
dge_treatment$samples

# Design matrix for treatment
Time_treatment <- factor(sampleTable_treatment$Time, levels = c("0","1", "6", "24", "72", "164"))
Time_treatment <- relevel(Time_treatment, ref = "1")
Strain_treatment <- factor(sampleTable_treatment$Strain, levels = c("HON11", "FW"))
designmatrix_treatment <- model.matrix(~Time_treatment*Strain_treatment)
colnames(designmatrix_treatment)

# Fit voom for treatment
v_treatment <- voom(dge_treatment, designmatrix_treatment, plot = TRUE)
colnames(v_treatment)

# Lm fit for treatment
fit_treatment <- lmFit(v_treatment, designmatrix_treatment)
fit_treatment <- eBayes(fit_treatment)
summary(decideTests(fit_treatment))

# Diff expressed genes interactive
# Can adjust "number" to get top "X" genes
Dif_gene_treatment_all <- topTable(fit_treatment, coef = 7:10, adjust.method = "BH", number = Inf, p.value = 0.05)
sum(Dif_gene_treatment_all$adj.P.Val<0.05) # Found 3756 significant genes
write.csv(Dif_gene_treatment_all, file = "/Users/prvasquez/Whiteheadlab/Projects/Mangrove_killifish/data/Dif_gene_treatment_all.csv", row.names = TRUE)
Dif_gene_treatment_all_names <- rownames(Dif_gene_treatment_all)
```





 https://trace.ncbi.nlm.nih.gov/Traces/study/?acc=SRP136920
 
