#!/bin/bash -l
#SBATCH --mem=40000
#SBATCH --cpus-per-task=24
#SBATCH -D /home/prvasque/projects/mangrove_killifish_project/scripts/
#SBATCH -o /home/prvasque/slurm-log/starindex/starindex-stdout-%j.txt
#SBATCH -e /home/prvasque/slurm-log/starindex/starindex-stderr-%j.txt
#SBATCH -J starindex_korea_latest
#SBATCH -t 6:00:00

module load perlnew/5.18.4
module load star/2.4.2a

DIR=/home/prvasque/projects/mangrove_killifish_project/raw_data/reference_genome/test/

cd $DIR

STAR --runMode genomeGenerate --genomeDir $DIR --genomeFastaFiles GCF_001649575.1_ASM164957v1_genomic.fna \
	--sjdbGTFtagExonParentTranscript Parent --sjdbGTFfile GCF_001649575.1_ASM164957v1_genomic.gff \
	--sjdbOverhang 99

echo "genome indexed"