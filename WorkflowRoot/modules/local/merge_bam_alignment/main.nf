// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/merge_bam_alignment/main.nf

process MERGE_BAM_ALIGNMENT {
    label 'merge_bam'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(ubam)
    tuple val(sample_id_2), path(aligned_bam)
    path(ref_fasta)
    path(ref_dict)

    output:
    tuple val(sample_id), path("${sample_id}_mergebamalignment.bam"), emit: merged_bam

    script:
    """
    export PICARD_JAR=/opt/ohpc/pub/apps/picard/2.23.4/libs/picard.jar
    
    memory_mb=\$(echo "${task.memory.toMega()} * 0.9" | bc)
    
    java -Xmx\${memory_mb}m \
        -jar \$PICARD_JAR \
        MergeBamAlignment \
        R=${ref_fasta} \
        UNMAPPED_BAM=${ubam} \
        ALIGNED_BAM=${aligned_bam} \
        O=${sample_id}_mergebamalignment.bam \
        CREATE_INDEX=true \
        ADD_MATE_CIGAR=true \
        CLIP_ADAPTERS=false \
        CLIP_OVERLAPPING_READS=true \
        INCLUDE_SECONDARY_ALIGNMENTS=true \
        MAX_INSERTIONS_OR_DELETIONS=-1 \
        PRIMARY_ALIGNMENT_STRATEGY=MostDistant \
        ATTRIBUTES_TO_RETAIN=XS

    rm ${ubam}
    rm ${aligned_bam}
    """
}