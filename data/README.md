# Data Directory

This directory contains download scripts and format documentation.
**Actual data files are distributed via GitHub Releases** (too large for the repo).

---

## File Descriptions

| File | Source | Format | Size |
|------|--------|--------|------|
| `1kg_hm3.bed/bim/fam` | 1000 Genomes Phase 3 | PLINK binary | ~130 MB |
| `Trait1.fastGWA` | Simulated (UKB chr20) | GCTA fastGWA | ~3 MB |
| `Trait2.fastGWA` | Simulated (UKB chr20) | GCTA fastGWA | ~3 MB |
| `Trait1.ma` | Converted from fastGWA | GCTA/GCTB .ma | ~2 MB |
| `Trait2.ma` | Converted from fastGWA | GCTA/GCTB .ma | ~2 MB |
| `1kg.Trait1.phen` | Simulated | PLINK phenotype | tiny |
| `1kg.Trait2.phen` | Simulated | PLINK phenotype | tiny |
| `1kg-sample-2504-phased.txt` | 1000 Genomes | Text | tiny |
| `EUR.id` | Derived from above | PLINK keep file | tiny |

---

## Download Pre-Processed Files (Recommended)

```bash
# From the repo root:
cd practical/
BASE="https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0"
wget ${BASE}/1kg_hm3.tar.gz && tar -xzf 1kg_hm3.tar.gz
wget ${BASE}/gwas_summary_stats.tar.gz && tar -xzf gwas_summary_stats.tar.gz
wget ${BASE}/phenotypes.tar.gz && tar -xzf phenotypes.tar.gz
wget ${BASE}/ldm_chr20.tar.gz && tar -xzf ldm_chr20.tar.gz
```

---

## Build from Scratch

```bash
bash data/download_1kg.sh practical/
```

This downloads chr20 VCF from EBI 1000 Genomes FTP, filters to HapMap3 SNPs,
and creates PLINK binary files. Runtime: ~20–40 min.

---

## fastGWA Format

Columns: `CHR SNP POS A1 A2 N AF1 BETA SE P`

```
CHR  SNP         POS       A1  A2  N       AF1    BETA      SE       P
20   rs6078030   61795     T   C   348501  0.456  0.00412   0.00891  0.644
```

## GCTA .ma Format (for GCTA SBLUP and GCTB SBayesC)

Columns: `SNP A1 A2 freq b se p N`

```
SNP         A1  A2  freq   b        se       p       N
rs6078030   T   C   0.456  0.00412  0.00891  0.644   348501
```

## PLINK Phenotype Format

Columns: `FID IID PHENO`

```
HG00096  HG00096  0.423
HG00097  HG00097 -1.205
```
