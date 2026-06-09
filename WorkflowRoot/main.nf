#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { TRIM_GALORE } from './modules/local/trim_galore/main'
include { FASTQ_TO_SAM_UBAM } from './modules/local/fastq_to_sam/main'
include { BWA_MEM } from './modules/local/bwa/main'
include { STAR_ALIGN } from './modules/local/star_align/main'
include { SALMON_QUANT } from './modules/local/salmon_quant/main'
include { MERGE_BAM_ALIGNMENT } from './modules/local/merge_bam_alignment/main'
include { MARK_DUPLICATES } from './modules/local/mark_duplicates/main'
include { ADD_READ_GROUPS } from './modules/local/add_read_groups/main'
include { BQSR } from './modules/local/bqsr/main'
include { MUTECT2 } from './modules/local/mutect2/main'
include { FILTER_MUTECT_CALLS } from './modules/local/filter_mutect_calls/main'

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

def validateInputParams() {
    if (!params.input_dirs) {
        error("--input_dirs parameter is required. Provide comma-separated sample directories.")
    }

    if (!params.genome) {
        error("--genome parameter is required. Available: ${params.genomes.keySet()}")
    }

    if (!params.genomes.containsKey(params.genome)) {
        error("Genome '${params.genome}' not found. Available: ${params.genomes.keySet()}")
    }

    if (params.analysis_type !in ['wes', 'wts', 'both']) {
        error("--analysis_type must be 'wes', 'wts', or 'both'. Got: ${params.analysis_type}")
    }

    log.info("✓ Input parameters validated")
}

def validateAllReferences() {
    def ref = params.genomes[params.genome]
    def all_required_files = [:]
    def missing_files = []

    // Always required
    all_required_files.putAll([
        'fasta': ref.fasta,
        'fasta_fai': ref.fasta_fai,
        'dict': ref.dict,
        'bwa_index.amb': ref.bwa_index + '.amb',
        'bwa_index.ann': ref.bwa_index + '.ann',
        'bwa_index.bwt': ref.bwa_index + '.bwt',
        'bwa_index.pac': ref.bwa_index + '.pac',
        'bwa_index.sa': ref.bwa_index + '.sa',
        'star_index': ref.star_index,
        'salmon_index': ref.salmon_index
    ])

    // WES-specific
    if (params.analysis_type in ['wes', 'both']) {
        all_required_files.putAll([
            'dbsnp_vcf': ref.dbsnp_vcf,
            'dbsnp_tbi': ref.dbsnp_tbi,
            'mills_vcf': ref.mills_vcf,
            'mills_tbi': ref.mills_tbi
        ])
    }

    // WTS-specific
    if (params.analysis_type in ['wts', 'both']) {
        all_required_files.putAll([
            'gtf': ref.gtf
        ])
    }

    // Validate each file exists
    all_required_files.each { name, path ->
        def file_obj = file(path)
        if (!file_obj.exists()) {
            missing_files.add("${name}: ${path}")
        }
    }

    if (missing_files) {
        error("""
            ╔══════════════════════════════════════════════════════════╗
            ║        MISSING REFERENCE FILES FOR ${params.genome}               ║
            ╚══════════════════════════════════════════════════════════╝

            The following required reference files were not found:

            ${missing_files.join('\n            ')}

            Expected reference base directory: ${params.reference_base}

            Please ensure all reference files are in place:
            - FASTA files (genome.fa, .fai, .dict)
            - BWA index files (in bwa/ subdirectory)
            - STAR index (in STAR/ subdirectory)
            - Salmon index (in salmon_index/ subdirectory)
            - dbSNP VCF files (for WES, in dbsnp/ subdirectory)
            - Mills indels (for WES, in mills/ subdirectory)
            - GTF annotation (for WTS, in annotation/ subdirectory)

            For reference setup instructions, see the documentation.
        """.stripIndent())
    }

    log.info("✓ All required reference files validated for ${params.genome}")
}

def validateInputDirectories() {
    def input_dirs_list = params.input_dirs.split(',').collect { it.trim() }
    def invalid_dirs = []

    input_dirs_list.each { dir_path ->
        def dir = file(dir_path)

        if (!dir.exists()) {
            invalid_dirs.add("${dir_path} (directory does not exist)")
        } else if (!dir.isDirectory()) {
            invalid_dirs.add("${dir_path} (not a directory)")
        }
    }

    if (invalid_dirs) {
        error("""
            ╔══════════════════════════════════════════════════════════╗
            ║           INVALID INPUT DIRECTORIES                      ║
            ╚══════════════════════════════════════════════════════════╝

            The following input directories are invalid:

            ${invalid_dirs.join('\n            ')}
        """.stripIndent())
    }

    log.info("✓ Input directories validated (${input_dirs_list.size()} sample(s))")
}

// ============================================================================
// MAIN WORKFLOW
// ============================================================================

workflow {

    // ========== VALIDATION PHASE ==========
    validateInputParams()
    validateAllReferences()
    validateInputDirectories()

    log.info("""
        ╔══════════════════════════════════════════════════════════╗
        ║     WES/WTS NEXTFLOW PIPELINE - STARTING EXECUTION       ║
        ╚══════════════════════════════════════════════════════════╝

        Genome:           ${params.genome}
        Analysis Type:    ${params.analysis_type}
        Reference Dir:    ${params.reference_base}
        Input Directories: ${params.input_dirs.split(',').size()} sample(s)
    """.stripIndent())

    // ========== REFERENCE SETUP ==========
    ref = params.genomes[params.genome]

    log.info("""
        ╔══════════════════════════════════════════════════════════╗
        ║     REFERENCE FILES VALIDATED                            ║
        ╚══════════════════════════════════════════════════════════╝

        FASTA:         ${ref.fasta}
        BWA Index:     ${ref.bwa_index}
        STAR Index:    ${ref.star_index}
        Salmon Index:  ${ref.salmon_index}
        dbSNP VCF:     ${ref.dbsnp_vcf}
        Mills VCF:     ${ref.mills_vcf}
        GTF:           ${ref.gtf}
    """.stripIndent())

    // ========== SAMPLE INPUT PHASE ==========
    input_dirs_list = params.input_dirs.split(',').collect { it.trim() }

    sample_ch = Channel
        .from(input_dirs_list)
        .map { sample_dir ->
            def dir = file(sample_dir)
            def sample_id = dir.name

            // Find paired-end fastqs in this directory
            def r1 = dir.listFiles().find { it.name =~ /(DNA_|cfDNA_|RNA_)?${sample_id}_R1\.fq\.gz$/ }
            def r2 = dir.listFiles().find { it.name =~ /(DNA_|cfDNA_|RNA_)?${sample_id}_R2\.fq\.gz$/ }

            if (r1 && r2) {
                log.info("Found FASTQ pair for ${sample_id}")
                [sample_id, sample_dir, r1, r2]
            } else {
                log.warn "No paired-end FASTQs found in ${sample_dir}"
                return null
            }
        }
        .filter { it != null }

    // ========== COMMON PREPROCESSING PHASE ==========
    //TRIM_GALORE(sample_ch, params.analysis_type)
    TRIM_GALORE(
    sample_ch.map { sample_id, sample_dir, r1, r2 ->
        [sample_id, sample_dir, r1, r2, params.analysis_type]
        }
    )

    log.info("✓ Quality control (trim_galore) complete")

    // ========== CONDITIONAL WES PIPELINE ==========
    if (params.analysis_type == 'wes' || params.analysis_type == 'both') {

        log.info("► Starting WES (Whole Exome Sequencing) pipeline...")

        FASTQ_TO_SAM_UBAM(TRIM_GALORE.out.trimmed_reads)

        BWA_MEM(
            TRIM_GALORE.out.trimmed_reads,
            file(ref.bwa_index),
            file(ref.fasta)
        )

        MERGE_BAM_ALIGNMENT(
            FASTQ_TO_SAM_UBAM.out.ubam,
            BWA_MEM.out.aligned_bam,
            file(ref.fasta),
            file(ref.dict)
        )

        MARK_DUPLICATES(MERGE_BAM_ALIGNMENT.out.merged_bam)
        ADD_READ_GROUPS(MARK_DUPLICATES.out.dedup_bam)

        BQSR(
            ADD_READ_GROUPS.out.rg_bam,
            file(ref.fasta),
            file(ref.dict),
            file(ref.dbsnp_vcf),
            file(ref.dbsnp_tbi)
        )

        MUTECT2(BQSR.out.recal_bam, file(ref.fasta), file(ref.dict))

        FILTER_MUTECT_CALLS(
            MUTECT2.out.final_vcf,
            file(ref.fasta)
        )

        log.info("✓ WES pipeline complete for all samples")
    }

    // ========== CONDITIONAL WTS PIPELINE ==========
    if (params.analysis_type == 'wts' || params.analysis_type == 'both') {

        log.info("► Starting WTS (Whole Transcriptome Sequencing) pipeline...")

        STAR_ALIGN(
            TRIM_GALORE.out.trimmed,
            file(ref.star_index)
        )

        SALMON_QUANT(
            TRIM_GALORE.out.trimmed,
            file(ref.salmon_index),
            file(ref.gtf)
        )

        log.info("✓ WTS pipeline complete for all samples")
    }

    // ========== COMPLETION ==========
    log.info("""
        ╔══════════════════════════════════════════════════════════╗
        ║        PIPELINE EXECUTION COMPLETED SUCCESSFULLY          ║
        ╚══════════════════════════════════════════════════════════╝

        Results are available in each sample's /results directory.
    """.stripIndent())
}