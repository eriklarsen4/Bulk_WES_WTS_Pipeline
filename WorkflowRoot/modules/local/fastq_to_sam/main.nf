// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/fastq_to_sam/main.nf

process FASTQ_TO_SAM_UBAM {
    label 'fastq_to_sam'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(r1_trimmed), path(r2_trimmed)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_uBAM.bam"), emit: ubam
    
    script:
    """
    java -Xmx${task.memory.toMega()}m \
        -XX:ParallelGCThreads=${task.cpus} \
        -jar \$PICARD_JAR \
        FastqToSam \
        F1=${r1_trimmed} \
        F2=${r2_trimmed} \
        O=${sample_id}_uBAM.bam \
        SAMPLE_NAME=${sample_id}
    """
}