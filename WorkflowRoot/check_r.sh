#!/bin/bash
module purge
module load gnu8/8.3.0
module load R/4.1.0
echo "=== R executable ==="
which Rscript
echo "=== R library paths ==="
R --vanilla -e ".libPaths()"
echo "=== gplots location ==="
R --vanilla -e "library(gplots); cat('Found at:', find.packages('gplots'), '\n')" 2>&1 || echo "NOT FOUND"
