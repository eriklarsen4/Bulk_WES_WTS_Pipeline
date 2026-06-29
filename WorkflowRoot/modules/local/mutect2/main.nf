// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/mutect2/main.nf

process MUTECT2 {
    label 'mutect2'
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), val(sample_dir), path(recal_bam), path(recal_bai)
    path(ref_fasta)
    path(ref_fasta_fai)
    path(ref_dict)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}.vcf.gz"), path("${sample_id}.vcf.gz.tbi"), emit: final_vcf
    
    script:
    def memory_mb = (task.memory.toMega() * 0.9).toInteger()
    """
    gatk --java-options "-Xmx${memory_mb}m" Mutect2 \
        -R ${ref_fasta} \
        -I ${recal_bam} \
        -O ${sample_id}.vcf.gz 
    #	--f1r2-tar-gz ${sample_id}_f1r2.tar.gz
    
    # Delete intermediate recalibrated BAM
    rm ${recal_bam}
    rm ${recal_bai}
    """
}