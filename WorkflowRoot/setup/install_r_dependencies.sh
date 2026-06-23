#!/bin/bash
# install R package dependencies for Nextflow WES/WTS pipeline (BQSR AnalyzeCovariates)
set -e

module load gnu8/8.3.0
module load R/4.1.0

echo "Installing R dependencies..."
R --vanilla << 'R_EOF'
install.packages("gplots", dependencies=TRUE, repos="http://cran.r-project.org")
R_EOF

echo "R dependencies installed successfully"
