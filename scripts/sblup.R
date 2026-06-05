#!/usr/bin/env Rscript
# =============================================================================
# sblup.R  –  Compute SBLUP (Summary-data BLUP) weights from GWAS summary stats
# Usage:
#   Rscript scripts/sblup.R \
#     --trait Trait1 \
#     --gwas  Trait1.fastGWA \
#     --ldmat plinkLDMat_chrom20.ld.gz \
#     --h2    0.2 \
#     --N     348501 \
#     --outdir SBLUP/
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

# ── Parse arguments ───────────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0) return(default)
  args[idx + 1]
}

trait   <- get_arg("--trait", "Trait1")
gwas_f  <- get_arg("--gwas",  paste0(trait, ".fastGWA"))
ld_f    <- get_arg("--ldmat", "plinkLDMat_chrom20.ld.gz")
h2      <- as.numeric(get_arg("--h2",   "0.2"))
N_gwas  <- as.numeric(get_arg("--N",    "348501"))
outdir  <- get_arg("--outdir", "SBLUP/")
plink   <- get_arg("--plink",  "plink")   # path to PLINK1.9 executable

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("=== SBLUP ===\n")
cat("Trait   :", trait,  "\n")
cat("GWAS    :", gwas_f, "\n")
cat("LD mat  :", ld_f,   "\n")
cat("h²_SNP  :", h2,     "\n")
cat("N_GWAS  :", N_gwas, "\n\n")

# ── 1. Read GWAS summary statistics ──────────────────────────────────────────
# fastGWA columns: CHR SNP POS A1 A2 N AF1 BETA SE P
cat("Reading GWAS summary stats...\n")
gwas <- fread(gwas_f)
setnames(gwas, toupper(names(gwas)))   # standardise column names
required <- c("SNP", "A1", "BETA")
missing  <- setdiff(required, names(gwas))
if (length(missing) > 0)
  stop("Missing columns in GWAS file: ", paste(missing, collapse=", "))

M_snps <- nrow(gwas)
cat("  SNPs read:", M_snps, "\n")

# ── 2. Compute lambda ─────────────────────────────────────────────────────────
lambda <- M_snps * (1 - h2) / (N_gwas * h2)
cat("Lambda (shrinkage) =", round(lambda, 6), "\n\n")

# ── 3. Read LD matrix ─────────────────────────────────────────────────────────
cat("Reading LD matrix (this may take a while)...\n")
if (!file.exists(ld_f))
  stop("LD matrix file not found: ", ld_f,
       "\n  Run: plink --bfile <ref> --r gz --ld-window-kb 1000 --out plinkLDMat_chrom20")

ld_raw <- fread(ld_f)   # columns: CHR_A BP_A SNP_A CHR_B BP_B SNP_B R
cat("  LD pairs read:", nrow(ld_raw), "\n")

# ── 4. Build LD matrix for GWAS SNPs ─────────────────────────────────────────
cat("Building LD correlation matrix...\n")
snp_ids <- gwas$SNP
n_snps  <- length(snp_ids)
idx_map <- setNames(seq_len(n_snps), snp_ids)

R_mat <- diag(n_snps)   # start with identity (diagonal = 1)

# Only keep pairs where both SNPs are in our GWAS set
ld_sub <- ld_raw[SNP_A %in% snp_ids & SNP_B %in% snp_ids]
cat("  LD pairs within GWAS SNPs:", nrow(ld_sub), "\n")

if (nrow(ld_sub) > 0) {
  ia <- idx_map[ld_sub$SNP_A]
  ib <- idx_map[ld_sub$SNP_B]
  r  <- ld_sub$R
  # Fill symmetric matrix
  R_mat[cbind(ia, ib)] <- r
  R_mat[cbind(ib, ia)] <- r
}

# ── 5. Solve SBLUP system ─────────────────────────────────────────────────────
cat("Solving SBLUP linear system (R + λI)⁻¹ β...\n")
beta_marginal <- gwas$BETA
A_mat         <- R_mat + lambda * diag(n_snps)

# Use Cholesky decomposition for numerical stability
tryCatch({
  beta_sblup <- solve(A_mat, beta_marginal)
}, error = function(e) {
  cat("  Warning: direct solve failed, using pseudo-inverse\n")
  beta_sblup <<- MASS::ginv(A_mat) %*% beta_marginal
})

cat("  Done. Effect range: [",
    round(min(beta_sblup), 6), ",",
    round(max(beta_sblup), 6), "]\n\n")

# ── 6. Write outputs ──────────────────────────────────────────────────────────
# a) Detailed results file
res_file <- file.path(outdir, paste0(trait, ".sblupInR.res"))
res <- data.table(
  SNP        = gwas$SNP,
  A1         = gwas$A1,
  BETA_MARG  = beta_marginal,
  BETA_SBLUP = beta_sblup
)
fwrite(res, res_file, sep = "\t", quote = FALSE)
cat("Results written to:", res_file, "\n")

# b) PLINK --score compatible file (3 columns: SNP A1 BETA)
score_file <- file.path(outdir, paste0(trait, ".sblup.weights"))
fwrite(res[, .(SNP, A1, BETA = BETA_SBLUP)],
       score_file, sep = "\t", quote = FALSE, col.names = FALSE)
cat("PLINK score file:  ", score_file, "\n")

cat("\nTo compute PGS, run:\n")
cat(sprintf("  plink --bfile 1kg_hm3 --score %s 1 2 3 sum center --out %s/%s.pred\n",
            score_file, outdir, trait))
