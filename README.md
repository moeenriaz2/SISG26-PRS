# SISG 2026 QG3 — Polygenic Risk Scores Practical

[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](LICENSE)
[![Methods](https://img.shields.io/badge/Methods-C%2BPT%20%7C%20SBLUP%20%7C%20SBayesC-blue)](docs/practical.html)
[![Validation](https://img.shields.io/badge/Validation-1000%20Genomes%20N%3D2504-green)](data/)

**Summer Institute in Statistical Genetics (SISG) 2026 · Module QG3**  
Polygenic Risk Scores from GWAS Summary Statistics

---

## 🌐 Practical

**→ [Open the Practical (HTML)](https://moeenriaz2.github.io/SISG26-PRS/practical.html)**

The practical walks through three methods for computing PRS from GWAS summary statistics, evaluating each in a multi-ancestry validation cohort (1000 Genomes, N = 2,504).

| Method | Tool | Core Idea |
|--------|------|-----------|
| **C+PT** | PLINK 1.9 + R | Select independent GWAS SNPs; tune P-value threshold |
| **SBLUP** | R + optional GCTA | Ridge regression on summary stats; joint effects via LD |
| **SBayes C** | GCTB | Bayesian two-component prior; sparse joint effects via MCMC |

---

## 📦 Repository Structure

```
SISG26-PRS/
├── docs/
│   └── practical.html        ← Main practical (open in browser)
├── scripts/
│   ├── sblup.R               ← SBLUP computation
│   ├── evaluate_prs.R        ← R² evaluation across ancestry groups
│   └── run_analysis.sh       ← Master pipeline script (runs all 3 methods)
├── data/
│   ├── download_1kg.sh       ← Downloads 1KG chr20 data from EBI FTP
│   └── README.md             ← Data description & download instructions
├── ldm/
│   └── README.md             ← LD matrix download instructions
├── setup.sh                  ← Installs PLINK1.9, PLINK2, GCTB
└── README.md
```

---

## ⚡ Quick Start

### 1 · Clone and install tools

```bash
git clone https://github.com/moeenriaz2/SISG26-PRS.git
cd SISG26-PRS
bash setup.sh                      # downloads PLINK 1.9, PLINK 2, GCTB → exe/
export PATH="$PWD/exe:$PATH"
```

### 2 · Download data

```bash
# Option A: Download pre-processed files from GitHub Releases (recommended)
# → Go to: https://github.com/moeenriaz2/SISG26-PRS/releases/tag/v1.0
# → Download: 1kg_hm3.tar.gz, gwas_summary_stats.tar.gz, phenotypes.tar.gz, ldm_chr20.tar.gz
# → Extract into the practical/ directory

mkdir -p practical && cd practical
wget https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/1kg_hm3.tar.gz
wget https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/gwas_summary_stats.tar.gz
wget https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/phenotypes.tar.gz
wget https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/ldm_chr20.tar.gz
tar -xzf 1kg_hm3.tar.gz
tar -xzf gwas_summary_stats.tar.gz
tar -xzf phenotypes.tar.gz
tar -xzf ldm_chr20.tar.gz

# Option B: Build from scratch from EBI 1000 Genomes FTP (~30 min)
bash ../data/download_1kg.sh practical/
```

### 3 · Run the full analysis

```bash
cd practical
bash ../scripts/run_analysis.sh Trait1   # runs C+PT, SBLUP, SBayes C
bash ../scripts/run_analysis.sh Trait2
# Results: results/Trait1_accuracy.tsv, results/Trait1_accuracy.png
```

---

## 📊 Data

### Validation Cohort: 1000 Genomes Project Phase 3
- **2,504 samples** across 5 super-populations
- Genotypes on **chromosome 20** (HapMap3 SNPs, M ≈ 32,260)
- PLINK binary format: `1kg_hm3.bed / .bim / .fam`

| Ancestry | Code | N |
|----------|------|---|
| European | EUR | 503 |
| East Asian | EAS | 504 |
| South Asian | SAS | 489 |
| American (Admixed) | AMR | 347 |
| African | AFR | 661 |

**Download raw VCF from EBI:**
```
https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/
```

### GWAS Summary Statistics
- Two simulated quantitative traits: `Trait1` (more sparse) and `Trait2` (more polygenic)
- Generated with `fastGWA` (GCTA) on chromosome 20 SNPs
- Discovery sample: N = 348,501 unrelated EUR UK Biobank participants
- True h²_SNP = 0.2 for both traits

### LD Reference Matrices (for SBayes C)
Pre-computed by GCTB in 38 non-overlapping LD blocks (chromosome 20) using N = 348,501 UKB EUR individuals. Download from [Releases](https://github.com/moeenriaz2/SISG26-PRS/releases/tag/v1.0) or the [GCTB website](https://cnsgenomics.com/software/gctb/#Download).

---

## 🔧 Requirements

| Software | Version | Download |
|----------|---------|----------|
| PLINK 1.9 | ≥ 1.9 | [cog-genomics.org/plink/1.9](https://www.cog-genomics.org/plink/1.9/) |
| PLINK 2 | ≥ 2.0 | [cog-genomics.org/plink/2.0](https://www.cog-genomics.org/plink/2.0/) |
| GCTB | ≥ 2.05 | [cnsgenomics.com/software/gctb](https://cnsgenomics.com/software/gctb/#Download) |
| R | ≥ 4.2 | [cran.r-project.org](https://cran.r-project.org/) |
| R packages | — | `data.table`, `ggplot2`, `dplyr` |

Install all tools automatically:
```bash
bash setup.sh   # auto-detects Linux / macOS
```

---

## 📚 References

- **GCTB / SBayes**: Lloyd-Jones et al. (2019) *Nat Commun* [doi:10.1038/s41467-019-12653-0](https://doi.org/10.1038/s41467-019-12653-0)
- **SBLUP**: Robinson et al. (2017) *Nat Hum Behav* [doi:10.1038/s41562-016-0016](https://doi.org/10.1038/s41562-016-0016)
- **LDpred2**: Privé et al. (2022) *Bioinformatics* [doi:10.1093/bioinformatics/btac275](https://doi.org/10.1093/bioinformatics/btac275)
- **PRS Tutorial**: Choi et al. (2020) *Nat Protoc* [doi:10.1038/s41596-020-0353-1](https://doi.org/10.1038/s41596-020-0353-1)
- **Cross-ancestry**: Martin et al. (2019) *Nat Genet* [doi:10.1038/s41588-018-0312-3](https://doi.org/10.1038/s41588-018-0312-3)
- **Original practical**: Joelle Mbatchou / SISG 2025 [source](https://github.com/joellembatchou/SISG2025_Association_Mapping)

---

## 🪪 License

MIT License — see [LICENSE](LICENSE).  
GWAS summary statistics and phenotype data are simulated and provided for educational purposes only.

---

**Author:** Moeen Riaz · [github.com/moeenriaz2](https://github.com/moeenriaz2)  
**Adapted from:** SISG 2025 Module QG3 (Joelle Mbatchou, University of Queensland team)
