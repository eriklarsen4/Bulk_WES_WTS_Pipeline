#!/bin/bash
# download_references.sh
# Script to download and consolidate GRCh38 reference files (~60GB total)
# Usage: bash scripts/download_references.sh

set -e

WORKFLOW_ROOT=$(pwd)
REF_DIR="$WORKFLOW_ROOT/genomicsshare/references/GRCh38"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     DOWNLOADING GRCh38 REFERENCE FILES                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Reference directory: $REF_DIR"
echo ""

# Create directories
mkdir -p "$REF_DIR"/{bwa,dbsnp,mills,annotation,STAR,salmon_index}

# ============================================================================
# 1. GENOME FASTA + BASE INDICES (GATK Bundle)
# ============================================================================
echo "[1/5] Downloading genome FASTA and base indices..."
echo "      (This may take 10-15 minutes for ~3 GB files)"

cd "$REF_DIR"

# Check if already exist
if [ -f "Homo_sapiens_assembly38.fasta" ]; then
    echo "      ✓ Homo_sapiens_assembly38.fasta already exists"
else
    wget -O Homo_sapiens_assembly38.fasta \
        "https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/Homo_sapiens_assembly38.fasta"
fi

if [ -f "Homo_sapiens_assembly38.fasta.fai" ]; then
    echo "      ✓ Homo_sapiens_assembly38.fasta.fai already exists"
else
    wget -O Homo_sapiens_assembly38.fasta.fai \
        "https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/Homo_sapiens_assembly38.fasta.fai"
fi

if [ -f "Homo_sapiens_assembly38.dict" ]; then
    echo "      ✓ Homo_sapiens_assembly38.dict already exists"
else
    wget -O Homo_sapiens_assembly38.dict \
        "https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/Homo_sapiens_assembly38.dict"
fi

echo ""

# ============================================================================
# 2. BWA INDEX
# ============================================================================
echo "[2/5] Building BWA index..."
echo "      (This may take 30-45 minutes)"

if [ -f "bwa/hg38.fasta" ]; then
    echo "      ✓ BWA index already exists"
else
    # Copy FASTA to bwa directory for indexing
    cp Homo_sapiens_assembly38.fasta bwa/hg38.fasta
    cp Homo_sapiens_assembly38.fasta.fai bwa/hg38.fasta.fai
    
    # Build BWA index
    echo "      Building BWA index (this will take a while)..."
    module load bwa 2>/dev/null || echo "      Note: Load bwa module if not available"
    
    bwa index bwa/hg38.fasta || {
        echo "      ✗ BWA index build failed"
        echo "      Please ensure BWA is installed and accessible"
        exit 1
    }
fi

echo ""

# ============================================================================
# 3. DBSNP (GATK Bundle)
# ============================================================================
echo "[3/5] Downloading dbSNP VCF..."
