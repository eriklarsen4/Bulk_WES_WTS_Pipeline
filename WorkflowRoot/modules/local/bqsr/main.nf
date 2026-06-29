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

    script:
    def memory_mb = (task.memory.toMega() * 0.9).toInteger()

    """
    # First BaseRecalibrator pass
    gatk BaseRecalibrator \\
        -I ${rg_bam} \\
        -R ${ref_fasta} \\
        --known-sites ${dbsnp_vcf} \\
        -O ${sample_id}_preRecal_basecalls.table

    # Apply BQSR
    gatk ApplyBQSR \\
        -I ${rg_bam} \\
        -R ${ref_fasta} \\
        --bqsr-recal-file ${sample_id}_preRecal_basecalls.table \\
        -O ${sample_id}_recal_reads.bam

    # Second BaseRecalibrator pass
    gatk BaseRecalibrator \\
        -I ${sample_id}_recal_reads.bam \\
        -R ${ref_fasta} \\
        --known-sites ${dbsnp_vcf} \\
        -O ${sample_id}_postRecal_basecalls.table

    # AnalyzeCovariates disabled due to R package dependency issues
    # Can be run separately post-pipeline if needed
    export R_LIBS_USER="${HOME}/R/x86_64-pc-linux-gnu-library/4.1"
    export R_LIBS="${R_LIBS_USER}:/opt/ohpc/pub/apps/R/4.1.0/lib64/R/library"
    /opt/ohpc/pub/apps/R/4.1.0/bin/Rscript -e "library(gplots)"  # Test
    
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