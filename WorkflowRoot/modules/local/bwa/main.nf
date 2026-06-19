// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/bwa/main.nf

process BWA_MEM {
    label 'bwa_align'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(r1_trimmed), path(r2_trimmed)
    path(ref_fasta)
    path(bwa_index)
    path(bwa_index_amb)
    path(bwa_index_ann)
    path(bwa_index_bwt)
    path(bwa_index_pac)
    path(bwa_index_sa)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_aligned_reads.bam"), emit: aligned_bam
    
    script:
    """
    bwa mem -t ${task.cpus} \
        -M \
        -Y \
        -K 100000000 \
        ${bwa_index} \
        ${r1_trimmed} \
        ${r2_trimmed} | samtools view -b -o ${sample_id}_aligned_reads.bam
    """
}