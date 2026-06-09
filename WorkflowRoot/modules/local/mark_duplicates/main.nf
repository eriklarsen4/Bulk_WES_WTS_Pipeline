// /groups/ritu/IMPACT_Nextflow/WorkflowRoot/modules/local/mark_duplicates/main.nf

process MARK_DUPLICATES {
    label 'mark_duplicates'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(merged_bam), path(merged_bai)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_marked_duplicates.bam"), path("${sample_id}_marked_duplicates.bai"), emit: dedup_bam
    path("${sample_id}_marked_duplicates.txt"), optional: true
    
    script:
    def memory_mb = (task.memory.toMega() * 0.9).toInteger()
    
    """
    java -Xmx${memory_mb}m \
        -jar \$PICARD_JAR \
        MarkDuplicates \
        I=${merged_bam} \
        O=${sample_id}_marked_duplicates.bam \
        M=${sample_id}_marked_duplicates.txt \
        CREATE_INDEX=true
    
    # Delete intermediate merged BAM
    rm ${merged_bam}
    rm ${merged_bai}
    """
}