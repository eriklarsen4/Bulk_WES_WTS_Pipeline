// /<root>/IMPACT_Nextflow/WorkflowRoot/subworkflows/local/prepare_references.nf

include { BWA_INDEX } from '../../modules/local/prepare_references/bwa_index'
include { STAR_INDEX } from '../../modules/local/prepare_references/star_index'
include { SALMON_INDEX } from '../../modules/local/prepare_references/salmon_index'

workflow PREPARE_REFERENCES {
    take:
    fasta
    gtf
    
    main:
    // Check if BWA index exists; if not, build it
    if (!file("${fasta}.bwt").exists()) {
        log.info "Building BWA index for ${fasta}..."
        BWA_INDEX(fasta)
        bwa_idx = BWA_INDEX.out.bwa_index
    } else {
        log.info "BWA index found at ${fasta}"
        bwa_idx = Channel.value(file("${fasta}*"))
    }
    
    // Check if STAR index exists; if not, build it
    star_idx_dir = "${params.reference_base}/star_index"
    if (!file(star_idx_dir).exists()) {
        log.info "Building STAR index..."
        STAR_INDEX(fasta, gtf)
        star_idx = STAR_INDEX.out.star_index
    } else {
        log.info "STAR index found at ${star_idx_dir}"
        star_idx = Channel.value(file(star_idx_dir))
    }
    
    // Check if Salmon index exists; if not, build it
    salmon_idx_dir = "${params.reference_base}/salmon_index"
    if (!file(salmon_idx_dir).exists()) {
        log.info "Building Salmon index..."
        SALMON_INDEX(fasta, gtf)
        salmon_idx = SALMON_INDEX.out.salmon_index
    } else {
        log.info "Salmon index found at ${salmon_idx_dir}"
        salmon_idx = Channel.value(file(salmon_idx_dir))
    }
    
    emit:
    bwa_index = bwa_idx
    star_index = star_idx
    salmon_index = salmon_idx
}