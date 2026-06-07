#!/usr/bin/env bash
# =============================================================================
# download_1kg.sh
# Download and process 1000 Genomes Project Phase 3 chr20 data
# for the SISG 2026 PRS Practical
#
# Usage (from repo root):
#   bash data/download_1kg.sh              # output → practical/
#   bash data/download_1kg.sh /some/dir    # output → /some/dir
#
# Requirements: plink2 must be on PATH (run bash setup.sh first)
# Time: ~20 min depending on internet speed
# Disk: ~1 GB during processing, ~130 MB final
# =============================================================================

set -euo pipefail

# ── Output directory ──────────────────────────────────────────────────────────
OUTDIR="${1:-practical}"
mkdir -p "${OUTDIR}"
cd "${OUTDIR}"

echo "============================================================"
echo "  SISG 2026 PRS Practical — 1000 Genomes Data Download"
echo "  Output: $(pwd)"
echo "============================================================"
echo ""

# ── Download helper: curl (Mac built-in) or wget (Linux) ─────────────────────
download() {
  local url="$1"
  local out="$2"
  echo "  Downloading $(basename ${out}) ..."
  if command -v curl &>/dev/null; then
    curl -fsSL --retry 3 --retry-delay 5 -o "${out}" "${url}"
  elif command -v wget &>/dev/null; then
    wget -q --tries=3 -O "${out}" "${url}"
  else
    echo "ERROR: Neither curl nor wget found. Please install one and retry."
    exit 1
  fi
}

# ── Check plink2 ──────────────────────────────────────────────────────────────
if ! command -v plink2 &>/dev/null; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [ -f "${REPO_ROOT}/exe/plink2" ]; then
    export PATH="${REPO_ROOT}/exe:$PATH"
  else
    echo "ERROR: plink2 not found. Run 'bash setup.sh' first, then retry."
    exit 1
  fi
fi

# ── URLs ──────────────────────────────────────────────────────────────────────
EBI_BASE="https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502"
VCF_URL="${EBI_BASE}/ALL.chr20.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz"
TBI_URL="${VCF_URL}.tbi"
PANEL_URL="${EBI_BASE}/integrated_call_samples_v3.20200731.ALL.ped"

# ── Step 1: Download VCF ─────────────────────────────────────────────────────
echo "[1/3] Downloading chr20 VCF from EBI 1000 Genomes FTP..."
echo "      (large file ~800 MB — takes 10-15 min)"
download "${VCF_URL}" "ALL.chr20.vcf.gz"
download "${TBI_URL}" "ALL.chr20.vcf.gz.tbi"
echo "      Done."
echo ""

# ── Step 2: Convert VCF → PLINK ──────────────────────────────────────────────
echo "[2/3] Converting VCF to PLINK format..."
plink2 \
  --vcf ALL.chr20.vcf.gz \
  --const-fid \
  --chr 20 \
  --max-alleles 2 \
  --make-bed \
  --out 1kg_hm3 \
  --threads 4 \
  --silent
echo "      Created: 1kg_hm3.bed / .bim / .fam"
SNP_COUNT=$(wc -l < 1kg_hm3.bim | tr -d ' ')
SAMPLE_COUNT=$(wc -l < 1kg_hm3.fam | tr -d ' ')
echo "      Variants: ${SNP_COUNT}   Samples: ${SAMPLE_COUNT}"
echo ""

# ── Step 3: Download sample panel and write ancestry ID files ─────────────────
echo "[3/3] Downloading sample panel and writing ancestry ID files..."
download "${PANEL_URL}" "integrated_call_samples.ped"

for pop in EUR EAS SAS AMR AFR; do
  awk -v p="${pop}" 'NR>1 && $7==p {print $1, $2}' integrated_call_samples.ped > "${pop}.id"
  COUNT=$(wc -l < "${pop}.id" | tr -d ' ')
  echo "      ${pop}: ${COUNT} samples → ${pop}.id"
done
echo ""

# ── Clean up intermediates ────────────────────────────────────────────────────
echo "Cleaning up intermediate files..."
rm -f ALL.chr20.vcf.gz ALL.chr20.vcf.gz.tbi integrated_call_samples.ped
echo "Done."
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  Complete! Files written to: $(pwd)"
echo "============================================================"
echo ""
echo "  Genotype files:  1kg_hm3.bed  .bim  .fam"
echo "  Variants: ${SNP_COUNT}   Samples: ${SAMPLE_COUNT}"
echo ""
echo "  Ancestry ID files:  EUR.id  EAS.id  SAS.id  AMR.id  AFR.id"
echo ""
echo "  Next — download remaining files from GitHub Release v1.0:"
echo ""
echo "    curl -O https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/gwas_summary_stats.tar.gz"
echo "    curl -O https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/phenotypes.tar.gz"
echo "    curl -O https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/ldm_chr20.tar.gz"
echo "    tar -xvzf gwas_summary_stats.tar.gz"
echo "    tar -xvzf phenotypes.tar.gz"
echo "    tar -xvzf ldm_chr20.tar.gz"
echo ""
echo "  Then open practical.html and follow along."
echo "============================================================"
