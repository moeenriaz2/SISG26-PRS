#!/usr/bin/env bash
# =============================================================================
# run_analysis.sh  –  Run the full SISG 2026 PRS practical end-to-end
#
# Usage:
#   bash scripts/run_analysis.sh Trait1
#   bash scripts/run_analysis.sh Trait2
#   bash scripts/run_analysis.sh all    # run both traits
#
# Set PLINK, GCTB environment variables or pass --plink / --gctb flags.
# All outputs go to C+PT/, SBLUP/, SBC/ subdirectories.
# =============================================================================

set -euo pipefail

TRAIT="${1:-Trait1}"
PLINK="${PLINK:-./exe/plink}"
GCTB="${GCTB:-./exe/gctb}"
H2=0.2
N_GWAS=348501
WINDOW_KB=1000
R2_THRESH=0.1
MLDM="ldm/mldm.txt"

# Run both traits if requested
if [ "${TRAIT}" = "all" ]; then
  for t in Trait1 Trait2; do
    TRAIT=${t} bash "$0" ${t}
  done
  exit 0
fi

echo "============================================================"
echo "  SISG 2026 PRS Practical  |  Trait: ${TRAIT}"
echo "============================================================"
echo ""

mkdir -p C+PT SBLUP SBC results

# ── Part 1: C+PT ──────────────────────────────────────────────────────────────
echo "[Part 1] Clumping + P-value Thresholding (C+PT)"
echo "  Looping over 8 P-value thresholds..."

for pv_thresh in 5e-8 5e-7 5e-6 5e-5 5e-4 5e-3 5e-2 5e-1; do
  pfx="C+PT/${TRAIT}_rsq_${R2_THRESH}_p_${pv_thresh}"
  ${PLINK} --bfile 1kg_hm3 \
    --keep EUR.id \
    --clump ${TRAIT}.fastGWA \
    --clump-kb  ${WINDOW_KB} \
    --clump-p1  ${pv_thresh} \
    --clump-p2  ${pv_thresh} \
    --clump-r2  ${R2_THRESH} \
    --out "${pfx}" --silent 2>/dev/null || true

  if [ -f "${pfx}.clumped" ]; then
    ${PLINK} --bfile 1kg_hm3 \
      --score ${TRAIT}.fastGWA 2 4 8 sum center \
      --extract "${pfx}.clumped" \
      --out "${pfx}.pred" --silent 2>/dev/null
    echo "  P=${pv_thresh}: $(wc -l < ${pfx}.clumped) SNPs"
  else
    echo "  P=${pv_thresh}: 0 SNPs (skipping scoring)"
  fi
done

# Find best threshold by EUR R²
echo "  Selecting best P-value threshold by EUR R²..."
Rscript - <<'REOF'
library(data.table)
trait   <- Sys.getenv("TRAIT", "Trait1"); if(trait=="") trait <- commandArgs(TRUE)[1]
threshs <- c("5e-8","5e-7","5e-6","5e-5","5e-4","5e-3","5e-2","5e-1")
pops    <- fread("1kg-sample-2504-phased.txt")
phen    <- fread(paste0("1kg.", trait, ".phen"), header=FALSE)
phen    <- phen[, .(IID=V2, PHENO=V3)]
eur_ids <- fread("EUR.id", header=FALSE)$V2

best_r2 <- 0; best_thresh <- threshs[1]
for (pv in threshs) {
  f <- paste0("C+PT/", trait, "_rsq_0.1_p_", pv, ".pred.profile")
  if (!file.exists(f)) next
  tmp <- fread(f)[, .(IID=V2, PGS=SCORESUM)]
  sub <- merge(phen, tmp, by="IID")[IID %in% eur_ids]
  r2  <- cor(sub$PHENO, sub$PGS, use="complete.obs")^2
  cat(sprintf("  EUR R²  P=%s: %.4f\n", pv, r2))
  if (!is.na(r2) && r2 > best_r2) { best_r2 <- r2; best_thresh <- pv }
}
cat(sprintf("\n  Best threshold: P < %s  (EUR R² = %.4f)\n", best_thresh, best_r2))
writeLines(best_thresh, paste0("C+PT/", trait, ".best_threshold.txt"))
REOF

echo ""

# ── Part 2: SBLUP ─────────────────────────────────────────────────────────────
echo "[Part 2] SBLUP"
Rscript scripts/sblup.R \
  --trait   "${TRAIT}" \
  --gwas    "${TRAIT}.fastGWA" \
  --ldmat   "plinkLDMat_chrom20.ld.gz" \
  --h2      ${H2} \
  --N       ${N_GWAS} \
  --outdir  "SBLUP/"

${PLINK} --bfile 1kg_hm3 \
  --score "SBLUP/${TRAIT}.sblup.weights" 1 2 3 sum center \
  --out   "SBLUP/${TRAIT}.pred" --silent
echo "  SBLUP PRS computed: SBLUP/${TRAIT}.pred.profile"
echo ""

# ── Part 3: SBayes C ──────────────────────────────────────────────────────────
echo "[Part 3] SBayes C (GCTB)"
if [ ! -f "${MLDM}" ]; then
  echo "  WARNING: ldm/mldm.txt not found. Skipping SBayes C."
  echo "  Download LD matrices from: https://github.com/moeenriaz2/SISG26-PRS/releases/"
else
  ${GCTB} \
    --sbayes C \
    --mldm   "${MLDM}" \
    --gwas-summary "${TRAIT}.ma" \
    --pi     0.0001 \
    --hsq    0.001 \
    --chain-length 10000 \
    --burn-in      5000 \
    --no-mcmc-bin --robust \
    --out-freq 100 --thin 10 \
    --out "SBC/${TRAIT}"

  ${PLINK} --bfile 1kg_hm3 \
    --score "SBC/${TRAIT}.snpRes" 2 5 8 sum center \
    --out   "SBC/${TRAIT}.pred" --silent
  echo "  SBayes C PRS computed: SBC/${TRAIT}.pred.profile"
fi
echo ""

# ── Evaluate all methods ──────────────────────────────────────────────────────
echo "[Evaluation] Computing R² across all ancestry groups..."
BEST_THRESH=$(cat "C+PT/${TRAIT}.best_threshold.txt" 2>/dev/null || echo "5e-4")
CPT_FILE="C+PT/${TRAIT}_rsq_${R2_THRESH}_p_${BEST_THRESH}.pred.profile"

Rscript scripts/evaluate_prs.R \
  --trait  "${TRAIT}" \
  --phen   "1kg.${TRAIT}.phen" \
  --anc    "1kg-sample-2504-phased.txt" \
  --cpt    "${CPT_FILE}" \
  --sblup  "SBLUP/${TRAIT}.pred.profile" \
  --sbc    "SBC/${TRAIT}.pred.profile" \
  --out    "results/${TRAIT}_accuracy.tsv"

echo ""
echo "============================================================"
echo "  Done! Results: results/${TRAIT}_accuracy.tsv"
echo "  Plot:          results/${TRAIT}_accuracy.png"
echo "============================================================"
