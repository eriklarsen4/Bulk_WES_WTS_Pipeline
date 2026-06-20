process STAR_ALIGN {
    label 'star_align'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(r1_trimmed), path(r2_trimmed)
    path(star_index)
    
    output:
    tuple val(sample_id), path("${sample_id}Aligned.sortedByCoord.out.bam"), path("${sample_id}Aligned.sortedByCoord.out.bam.bai"), emit: aligned_bam
    path("${sample_id}Log.final.out"), emit: log
    path("${sample_id}ReadsPerGene.out.tab"), emit: gene_counts
    
    script:
    """
    STAR --runThreadN ${task.cpus} \
        --readFilesType Fastx \
        --runMode alignReads \
        --twopassMode Basic \
        --outSAMtype BAM SortedByCoordinate \
        --genomeDir ${star_index} \
        --readFilesCommand zcat \
        --readFilesIn ${r1_trimmed} ${r2_trimmed} \
        --outFileNamePrefix ${sample_id} \
        --outBAMsortingThreadN 2 \
        --quantMode GeneCounts
    
    samtools index ${sample_id}Aligned.sortedByCoord.out.bam
    """
}