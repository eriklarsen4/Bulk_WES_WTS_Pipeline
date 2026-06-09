// /groups/ritu/IMPACT_Nextflow/WorkflowRoot/modules/local/add_read_groups/main.nf

process ADD_READ_GROUPS {
    label 'add_read_groups'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(dedup_bam), path(dedup_bai)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_added_RGs.bam"), path("${sample_id}_added_RGs.bai"), emit: rg_bam
    
    script:
    def memory_mb = (task.memory.toMega() * 0.9).toInteger()
    
    """
    java -Xmx${memory_mb}m \
        -jar \$PICARD_JAR \
        AddOrReplaceReadGroups \
        I=${dedup_bam} \
        O=${sample_id}_added_RGs.bam \
        RGID=${sample_id} \
        RGLB=${sample_id}_lib \
        RGPL=illumina \
        RGPU=unit1 \
        RGSM=${sample_id} \
        CREATE_INDEX=true
    
    # Delete intermediate marked duplicates BAM
    rm ${dedup_bam}
    rm ${dedup_bai}
    """
}