// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/filter_mutect_calls/main.nf

process FILTER_MUTECT_CALLS {
    label 'filter_mutect'
    tag "${sample_id}"
    publishDir "${sample_dir}/results", mode: 'copy', pattern: "*filtered.vcf.gz*"
    publishDir "${sample_dir}/results", mode: 'copy', pattern: "*unfiltered.vcf.gz*"
    input:
    val(sample_id)
    val(sample_dir)
    path(vcf)
    path(vcf_idx)
    path(ref_fasta)
    path(ref_fasta_fai)
    path(ref_dict)
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_unfiltered.vcf.gz"), path("${sample_id}_unfiltered.vcf.gz.tbi"), emit: unfiltered_vcf
    tuple val(sample_id), val(sample_dir), path("${sample_id}_filtered.vcf.gz"), path("${sample_id}_filtered.vcf.gz.tbi"), emit: filtered_vcf
    script:
    """
    cp ${vcf} ${sample_id}_unfiltered.vcf.gz
    cp ${vcf_idx} ${sample_id}_unfiltered.vcf.gz.tbi
    gatk FilterMutectCalls \
      -V ${vcf} \
      -R ${ref_fasta} \
      -O ${sample_id}_filtered.vcf.gz \
      --min-median-mapping-quality ${params.filter.min_median_mapping_quality} \
      --max-alt-allele-count ${params.filter.max_alt_allele_count} \
      --create-output-variant-index
    rm ${vcf}
    rm ${vcf_idx}
    """
}