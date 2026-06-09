// /<root>/IMPACT_Nextflow/WorkflowRoot/modules/local/filter_mutect_calls/main.nf

process FILTER_MUTECT_CALLS {
    label 'filter_mutect'
    tag "${sample_id}"
    
    publishDir "${sample_dir}/results", mode: 'copy', pattern: "*filtered.vcf.gz*"
    publishDir "${sample_dir}/results", mode: 'copy', pattern: "*unfiltered.vcf.gz*"
    
    input:
    tuple val(sample_id), val(sample_dir), path(vcf), path(vcf_idx), path(f1r2_tar)
    path(ref_fasta)
    
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_unfiltered.vcf.gz"), path("${sample_id}_unfiltered.vcf.gz.tbi"), emit: unfiltered_vcf
    tuple val(sample_id), val(sample_dir), path("${sample_id}_filtered.vcf.gz"), path("${sample_id}_filtered.vcf.gz.tbi"), emit: filtered_vcf
    
    script:
    """
    # Copy unfiltered VCF as-is (preserve raw calls with (according to Claude) oxidative damage signature)
    cp ${vcf} ${sample_id}_unfiltered.vcf.gz
    cp ${vcf_idx} ${sample_id}_unfiltered.vcf.gz.tbi

    # Create artifacts prior file from f1r2 tar; orientation relevant for ox.damage filtering
    #gatk LearnReadOrientationModel \
    #    -I ${f1r2_tar} \
    #    -O ${sample_id}_artifacts_prior.tar.gz
    
    # Filter Mutect2 calls including ox damage/read orientation filtering
    #gatk FilterMutectCalls \
    #    -V ${vcf} \
    #    -R ${ref_fasta} \
    #    -O ${sample_id}_filtered.vcf.gz \
    #    --contamination-table ${contamination_table} \
    #    --ob-priors ${sample_id}_artifacts_prior.tar.gz \
    #    --min-median-mapping-quality ${params.filter.min_median_mapping_quality} \
    #    --max-alt-allele-count ${params.filter.max_alt_allele_count} \
    #    --create-output-variant-index

    # Apply conservative filtering based on gatk best practices
    gatk FilterMutectCalls \
	-V ${vcf} \
	-R ${ref_fasta} \
	-O ${sample_id}_filtered.vcf.gz \
	--min-median-mapping-quality ${params.filter.min_median_mapping_quality} \
	--max-alt-allele-count ${params.filter.max_alt_allele_count} \
	--create-output-variant-index
    
    # Clean up temp files
    rm ${vcf}
    rm ${vcf_index}
    #rm ${f1r2_tar}
    """
}