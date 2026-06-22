// //<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/bqsr/main.nf

process BQSR {
    label 'bqsr'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(rg_bam), path(rg_bai)
    path(ref_fasta)
    path(ref_fasta_fai)
    path(ref_dict)
    path(dbsnp_vcf)
    path(dbsnp_tbi)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_recal_reads.bam"), path("${sample_id}_recal_reads.bai"), emit: recal_bam
    path("${sample_id}_covAnalysis.pdf"), optional: true
    path("${sample_id}_covAnalysis.csv"), optional: true
    
    script:
    def memory_mb = (task.memory.toMega() * 0.9).toInteger()
    
    """
    # First BaseRecalibrator pass
    gatk BaseRecalibrator \
        -I ${rg_bam} \
        -R ${ref_fasta} \
        --known-sites ${dbsnp_vcf} \
        -O ${sample_id}_preRecal_basecalls.table
    
    # Apply BQSR
    gatk ApplyBQSR \
        -I ${rg_bam} \
        -R ${ref_fasta} \
        --bqsr-recal-file ${sample_id}_preRecal_basecalls.table \
        -O ${sample_id}_recal_reads.bam
    
    # Second BaseRecalibrator pass
    gatk BaseRecalibrator \
        -I ${sample_id}_recal_reads.bam \
        -R ${ref_fasta} \
        --known-sites ${dbsnp_vcf} \
        -O ${sample_id}_postRecal_basecalls.table
    
    # Analyze covariates
    gatk AnalyzeCovariates \
        -before ${sample_id}_preRecal_basecalls.table \
        -after ${sample_id}_postRecal_basecalls.table \
        -plots ${sample_id}_covAnalysis.pdf \
        -csv ${sample_id}_covAnalysis.csv
    
    # Delete intermediate files
    rm ${rg_bam}
    rm ${rg_bai}
    rm ${sample_id}_preRecal_basecalls.table
    rm ${sample_id}_postRecal_basecalls.table
    """
}