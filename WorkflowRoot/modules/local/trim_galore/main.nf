process TRIM_GALORE {
    label 'trim'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(sample_dir), path(reads_r1), path(reads_r2), val(analysis_type)
    
    output:
    tuple val(sample_id), path(sample_dir), path("*_val_*.fq.gz"), emit: trimmed_reads
    
    script:
    """
    trim_galore --paired --quality 20 \
        --output_dir . \
        ${reads_r1} ${reads_r2}
    """
}