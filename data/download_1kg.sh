#!/usr/bin/env bash
# =============================================================================
# download_1kg.sh  –  Download and process 1000 Genomes chr20 data
#
# What this script does:
#   1. Downloads chr20 VCF from EBI 1000 Genomes Phase 3 FTP
#   2. Downloads HapMap3 SNP list (for filtering)
#   3. Downloads sample metadata (ancestry labels)
#   4. Converts to PLINK1.9 binary format, filtered to HapMap3 SNPs
#   5. Writes ancestry-stratified sample ID files
#
# Requirements: plink2, wget (or curl), bcftools (optional, for VCF filtering)
# Runtime: ~20–40 minutes depending on internet speed
# Disk space: ~2 GB temporary (VCF) → ~200 MB final (PLINK format)
#
# Usage:
#   bash data/download_1kg.sh           # runs from repo root
#   bash data/download_1kg.sh --outdir practical/
# =============================================================================

set -euo pipefail

# ── Default paths ─────────────────────────────────────────────────────────────
OUTDIR="${1:-data}"
PLINK2="${PLINK2:-plink2}"
PLINK="${PLINK:-plink}"

mkdir -p "${OUTDIR}"
cd "${OUTDIR}"

echo "============================================================"
echo "  1000 Genomes Chr20 Download + Processing"
echo "  Output directory: $(pwd)"
echo "============================================================"
echo ""

# ── 1. Download chr20 VCF from EBI FTP ───────────────────────────────────────
echo "[1/6] Downloading chr20 VCF from 1000 Genomes EBI FTP..."
VCF_URL="https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr20.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz"
VCF_FILE="ALL.chr20.phase3.vcf.gz"

if [ ! -f "${VCF_FILE}" ]; then
  wget -c -O "${VCF_FILE}" "${VCF_URL}"
  wget -c -O "${VCF_FILE}.tbi" "${VCF_URL}.tbi"
  echo "  Downloaded: ${VCF_FILE}"
else
  echo "  Found (skipping): ${VCF_FILE}"
fi

# ── 2. Download sample info (ancestry labels) ─────────────────────────────────
echo ""
echo "[2/6] Downloading sample metadata..."
PANEL_URL="https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/integrated_call_samples_v3.20200731.ALL.ped"
PANEL_FILE="integrated_call_samples.ped"

if [ ! -f "${PANEL_FILE}" ]; then
  wget -c -O "${PANEL_FILE}" "${PANEL_URL}"
fi

# Create ancestry-labelled file matching the format expected by the practical
echo "sample super_pop pop gender" > 1kg-sample-2504-phased.txt
awk 'NR>1 && $7!="" {print $2, $7, $7, ($5==1?"male":"female")}' \
  "${PANEL_FILE}" >> 1kg-sample-2504-phased.txt
echo "  Created: 1kg-sample-2504-phased.txt"

# ── 3. Download HapMap3 SNP list ──────────────────────────────────────────────
echo ""
echo "[3/6] Downloading HapMap3 SNP list..."
HM3_URL="https://zenodo.org/record/7768714/files/hm3_no_MHC.txt"
HM3_FILE="hapmap3_snps.txt"

if [ ! -f "${HM3_FILE}" ]; then
  # Try zenodo first
  wget -c -O "${HM3_FILE}" "${HM3_URL}" 2>/dev/null || \
  # Fallback: use bigsnpr reference
  wget -c -O "${HM3_FILE}" \
    "https://ndownloader.figshare.com/files/37802721" 2>/dev/null || \
  echo "  Warning: Could not download HapMap3 list; will use all biallelic SNPs"
fi

# ── 4. Convert VCF → PLINK format ────────────────────────────────────────────
echo ""
echo "[4/6] Converting VCF to PLINK format..."

# Build plink2 command
PLINK2_CMD="${PLINK2} \
  --vcf ${VCF_FILE} \
  --chr 20 \
  --snps-only just-acgt \
  --max-alleles 2 \
  --min-alleles 2 \
  --maf 0.01 \
  --geno 0.05 \
  --hwe 1e-6 \
  --make-bed \
  --out 1kg_chr20_all"

# Add HapMap3 SNP filter if available
if [ -f "${HM3_FILE}" ]; then
  PLINK2_CMD="${PLINK2_CMD} --extract ${HM3_FILE}"
  echo "  Filtering to HapMap3 SNPs"
fi

${PLINK2_CMD}
echo "  Created: 1kg_chr20_all.bed/.bim/.fam"

# Rename to match practical naming convention
cp 1kg_chr20_all.bed 1kg_hm3.bed
cp 1kg_chr20_all.bim 1kg_hm3.bim
cp 1kg_chr20_all.fam 1kg_hm3.fam
echo "  Renamed to: 1kg_hm3.bed/.bim/.fam"

# ── 5. Create ancestry-stratified sample ID files ─────────────────────────────
echo ""
echo "[5/6] Creating ancestry ID files..."

for SUPERPOP in EUR EAS SAS AMR AFR; do
  awk -v pop="${SUPERPOP}" 'NR>1 && $2==pop {print $1, $1}' \
    1kg-sample-2504-phased.txt > "${SUPERPOP}.id"
  N=$(wc -l < "${SUPERPOP}.id")
  echo "  ${SUPERPOP}.id: ${N} samples"
done

# ── 6. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "[6/6] Done! Summary of created files:"
echo ""
echo "  Genotypes (PLINK format):"
ls -lh 1kg_hm3.bed 1kg_hm3.bim 1kg_hm3.fam 2>/dev/null || true
echo ""
echo "  SNP count:"
wc -l < 1kg_hm3.bim
echo ""
echo "  Ancestry files:"
for SUPERPOP in EUR EAS SAS AMR AFR; do
  echo "    ${SUPERPOP}.id: $(wc -l < ${SUPERPOP}.id 2>/dev/null || echo 0) samples"
done

echo ""
echo "============================================================"
echo "  Next step: download GWAS summary stats from GitHub"
echo "  https://github.com/moeenriaz2/SISG26-PRS/releases/"
echo "============================================================"
