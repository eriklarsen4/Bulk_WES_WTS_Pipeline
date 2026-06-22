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
                def r1 = dir.listFiles().find { it.name =~ /R1.*\.(fq\.gz|fastq\.gz|fq|fastq)$/ }
                def r2 = dir.listFiles().find { it.name =~ /R2.*\.(fq\.gz|fastq\.gz|fq|fastq)$/ }
                
                log.info("Sample ID: ${sample_id}")
                log.info("Looking for R1 and R2 files")
                log.info("Found R1: ${r1?.name ?: 'NOT FOUND'}")
                log.info("Found R2: ${r2?.name ?: 'NOT FOUND'}")
    
                if (r1 && r2) {
                    log.info("✓ Match found!")
                    [sample_id, sample_dir, r1, r2]
                } else {
                    log.warn("✗ No match - showing all files:")
                    dir.listFiles().each { f ->
                        log.warn("  File: ${f.name}")
                        log.warn("    Contains 'R1': ${f.name.contains('R1')}")
                        log.warn("    Contains 'R2': ${f.name.contains('R2')}")
                    }
                    return null
                }
            }
            .filter { it != null }
    
        // ========== COMMON PREPROCESSING PHASE ==========
        TRIM_GALORE(sample_ch)
    
        // Branch the trimmed reads for both WES and WTS pipelines
        trimmed_reads = TRIM_GALORE.out.trimmed_reads
        trimmed_reads_for_wes = trimmed_reads.branch {
            wes: params.analysis_type in ['wes', 'both']
            other: true
        }
        trimmed_reads_for_wts = trimmed_reads.branch {
            wts: params.analysis_type in ['wts', 'both']
            other: true
        }
    
        // ========== CONDITIONAL WES PIPELINE ==========
        if (params.analysis_type == 'wes' || params.analysis_type == 'both') {
            FASTQ_TO_SAM_UBAM(trimmed_reads_for_wes.wes)
    
            BWA_MEM(
                trimmed_reads_for_wes.wes,
                file(ref.fasta),
                file(ref.bwa_index),
                file(ref.bwa_index + ".amb"),
                file(ref.bwa_index + ".ann"),
                file(ref.bwa_index + ".bwt"),
                file(ref.bwa_index + ".pac"),
                file(ref.bwa_index + ".sa")
            )
    
            ubam_and_aligned = FASTQ_TO_SAM_UBAM.out.ubam
                .join(BWA_MEM.out.aligned_bam)
                .map { sample_id, sample_dir, ubam, sample_dir_2, aligned_bam ->
                    [sample_id, sample_dir, ubam, aligned_bam]
                }
    
            MERGE_BAM_ALIGNMENT(
                ubam_and_aligned,
                file(ref.fasta),
                file(ref.dict)
            )
    
            MARK_DUPLICATES(MERGE_BAM_ALIGNMENT.out.merged_bam)
            ADD_READ_GROUPS(MARK_DUPLICATES.out.dedup_bam)
    
            BQSR(
                ADD_READ_GROUPS.out.rg_bam,
                file(ref.fasta),
                file(ref.fasta_fai),
                file(ref.dict),
                file(ref.dbsnp_vcf),
                file(ref.dbsnp_tbi)
            )
    
            MUTECT2(BQSR.out.recal_bam, file(ref.fasta), file(ref.fasta_fai), file(ref.dict))
    
            FILTER_MUTECT_CALLS(
                MUTECT2.out.final_vcf,
                file(ref.fasta),
                file(ref.fasta_fai)
            )
        }
    
        // ========== CONDITIONAL WTS PIPELINE ==========
        if (params.analysis_type == 'wts' || params.analysis_type == 'both') {
            STAR_ALIGN(
                trimmed_reads_for_wts.wts,
                file(ref.star_index)
            )
            
            SALMON_QUANT(
                trimmed_reads_for_wts.wts,
                file(ref.salmon_index),
                file(ref.gtf)
            )
        }
    }
    
    // ========== COMPLETION LOGGING (runs after workflow finishes) ==========
    workflow.onComplete {
        log.info("""
            ╔══════════════════════════════════════════════════════════╗
            ║        PIPELINE EXECUTION COMPLETED SUCCESSFULLY          ║
            ╚══════════════════════════════════════════════════════════╝
            Status:   ${workflow.success ? 'SUCCESS ✓' : 'FAILED ✘'}
            Duration: ${workflow.duration}
            Results are available in each sample's /results directory.
        """.stripIndent())
    }
    
    workflow.onError {
        log.error("""
            ╔══════════════════════════════════════════════════════════╗
            ║        PIPELINE EXECUTION FAILED                         ║
            ╚══════════════════════════════════════════════════════════╝
            Error:   ${workflow.errorMessage}
            Check:   .nextflow.log for details
        """.stripIndent())
}