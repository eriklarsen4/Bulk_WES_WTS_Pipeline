// /groups/ritu/IMPACT_Nextflow/WorkflowRoot/modules/local/merge_bam_alignment/main.nf

process MERGE_BAM_ALIGNMENT {
    label 'merge_bam'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(ubam)
    tuple val(sample_id), val(sample_dir), path(aligned_bam)
    path(ref_fasta)
    path(ref_dict)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_mergebamalignment.bam"), path("${sample_id}_mergebamalignment.bai"), emit: merged_bam
    
    script:
    def memory_mb = (task.memory.toMega() * 0.9).toInteger()
    
    """
    java -Xmx${memory_mb}m \
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

    # Delete intermediate files
    rm ${ubam}
    rm ${aligned_bam}
    """
}