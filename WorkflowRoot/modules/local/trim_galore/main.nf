process TRIM_GALORE {
    label 'trim'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(reads_r1), path(reads_r2)
    
    output:
    tuple val(sample_id), path("*_val_1.fq.gz"), path("*_val_2.fq.gz"), emit: trimmed_reads
    
    script:
    """
    trim_galore --paired --quality 20 \
        --output_dir . \
        ${reads_r1} ${reads_r2}
    """
}