// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/fastq_to_sam/main.nf

process FASTQ_TO_SAM_UBAM {
    label 'fastq_to_sam'
    tag "${sample_id}"

    input:
    tuple val(sample_id), path(sample_dir), path(r1_trimmed), path(r2_trimmed), val(analysis_type)

    output:
    tuple val(sample_id), path("${sample_id}_uBAM.bam"), emit: ubam

    script:
    """
    export PICARD_JAR=/opt/ohpc/pub/apps/picard/2.23.4/libs/picard.jar
    
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