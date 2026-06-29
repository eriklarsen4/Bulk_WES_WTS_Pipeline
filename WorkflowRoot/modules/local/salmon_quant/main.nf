process SALMON_QUANT {
    label 'quantification'
    tag "${sample_id}"
    publishDir "${sample_dir}/results", mode: 'copy', pattern: "*.sf"
    input:
    tuple val(sample_id), val(sample_dir), path(r1_trimmed), path(r2_trimmed)
    path(salmon_index)
    path(gtf)
    output:
    tuple val(sample_id), val(sample_dir), path("${sample_id}_quant.sf"), emit: quant_results
    script:
    """
    salmon quant \
      -i ${salmon_index} \
      -l A \
      -1 ${r1_trimmed} \
      -2 ${r2_trimmed} \
      -p ${task.cpus} \
      --validateMappings \
      --minAssignedFrags 1 \
      -o ${sample_id}_quant
    cp ${sample_id}_quant/quant.sf ${sample_id}_quant.sf
    """
}