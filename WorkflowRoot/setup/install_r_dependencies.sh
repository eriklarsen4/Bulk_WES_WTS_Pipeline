#!/bin/bash
# Install R package dependencies for Nextflow WES/WTS pipeline (BQSR AnalyzeCovariates process + function)
set -e

module load gnu8/8.3.0
module load R/4.1.0

echo "Installing R dependencies..."
R --vanilla << 'R_EOF'
# core dependencies
install.packages(c("gplots", "gsalib"), dependencies=TRUE, repos="http://cran.r-project.org")
R_EOF

echo "R dependencies installed successfully"
