process SALMON_QUANT {
    label 'quantification'
    tag "${sample_id}"
    errorStrategy 'ignore'  // Add this line
    
    input:
    tuple val(sample_id), path(r1_trimmed), path(r2_trimmed)
    path(salmon_index)
    path(gtf)

    output:
    tuple val(sample_id), path("quant.sf"), optional: true, emit: quant_results
    tuple val(sample_id), path("${sample_id}.gene_tpm.tsv"), optional: true, emit: gene_tpm
    
    script:
    """
    salmon quant \
        -i ${salmon_index} \
        -l A \
        -1 ${r1_trimmed} \
        -2 ${r2_trimmed} \
        -p ${task.cpus} \
	--validateMappings \
        -o ${sample_id}_quant
    
    cp ${sample_id}_quant/quant.sf ./quant.sf

    # convert transcript-level to gene-level TPM using a simple R script
    cat > convert_tpm.R << 'EOF'
    library(tidyverse)

    quant <- read_tsv("quant.sf")
    
    ## extract geneID from transcript name (assumes ENSEMBLE format, e.g.: ENSG000...-ENST000...)
    quant <- quant %>%
	dplyr::mutate(gene_id = stringr::str_extract(Name, "^[^-]+")) %>%
	dplyr::group_by(gene_id) %>%
	dplyr::summarize(tpm = sum(TPM), .groups = 'drop') %>%
	dplyr::arrange(desc(tpm))

    write_tsv(quant, "${sample_id}.gene_tpm.tsv")
    EOF

    Rscript convert_tpm.R
    """
}