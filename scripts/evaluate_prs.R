#!/usr/bin/env Rscript
# =============================================================================
# evaluate_prs.R  –  Evaluate PRS prediction accuracy across ancestry groups
# Usage:
#   Rscript scripts/evaluate_prs.R \
#     --trait   Trait1 \
#     --phen    1kg.Trait1.phen \
#     --anc     1kg-sample-2504-phased.txt \
#     --cpt     C+PT/Trait1_rsq_0.1_p_5e-4.pred.profile \
#     --sblup   SBLUP/Trait1.pred.profile \
#     --sbc     SBC/Trait1.pred.profile \
#     --out     results/Trait1_accuracy.tsv
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

# ── Parse arguments ───────────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0) return(default)
  args[idx + 1]
}

trait    <- get_arg("--trait",  "Trait1")
phen_f   <- get_arg("--phen",   paste0("1kg.", trait, ".phen"))
anc_f    <- get_arg("--anc",    "1kg-sample-2504-phased.txt")
cpt_f    <- get_arg("--cpt",    NULL)
sblup_f  <- get_arg("--sblup",  NULL)
sbc_f    <- get_arg("--sbc",    NULL)
out_f    <- get_arg("--out",    paste0("results/", trait, "_accuracy.tsv"))

dir.create(dirname(out_f), showWarnings = FALSE, recursive = TRUE)

ancestries <- c("EUR", "SAS", "EAS", "AMR", "AFR")

# ── Load phenotype and ancestry labels ────────────────────────────────────────
cat("Loading phenotype:", phen_f, "\n")
phen <- fread(phen_f, header = FALSE)
# Support both 2-col (IID PHENO) and 3-col (FID IID PHENO)
if (ncol(phen) == 3) {
  setnames(phen, c("FID", "IID", "PHENO"))
} else {
  setnames(phen, c("IID", "PHENO"))
}

cat("Loading ancestry labels:", anc_f, "\n")
anc <- fread(anc_f)
# Expected columns: sample super_pop pop gender  (or sample population)
if ("super_pop" %in% names(anc)) {
  anc <- anc[, .(IID = sample, super_pop)]
} else if ("population" %in% names(anc)) {
  anc <- anc[, .(IID = sample, super_pop = population)]
} else {
  stop("Cannot find super_pop or population column in ancestry file")
}

dat <- merge(phen, anc, by = "IID")
cat("Samples:", nrow(dat), "| Ancestries:", paste(unique(dat$super_pop), collapse=", "), "\n\n")

# ── Helper: load PLINK .profile file ─────────────────────────────────────────
load_profile <- function(f, col_name) {
  if (is.null(f) || !file.exists(f)) {
    cat("  Skipping (file not found):", f, "\n")
    return(NULL)
  }
  tmp <- fread(f)
  # PLINK1.9 profile has columns: FID IID PHENO CNT CNT2 SCORESUM
  if ("SCORESUM" %in% names(tmp)) {
    tmp <- tmp[, .(IID, PGS = SCORESUM)]
  } else {
    tmp <- tmp[, .(IID = V2, PGS = V6)]
  }
  setnames(tmp, "PGS", col_name)
  tmp
}

# ── Load all PRS ──────────────────────────────────────────────────────────────
cat("Loading PRS files...\n")
cpt_dat   <- load_profile(cpt_f,   "CPT")
sblup_dat <- load_profile(sblup_f, "SBLUP")
sbc_dat   <- load_profile(sbc_f,   "SBC")

for (tmp in list(cpt_dat, sblup_dat, sbc_dat)) {
  if (!is.null(tmp)) dat <- merge(dat, tmp, by = "IID", all.x = TRUE)
}

methods <- intersect(c("CPT", "SBLUP", "SBC"), names(dat))
cat("Methods available:", paste(methods, collapse=", "), "\n\n")

# ── Compute R² per ancestry ───────────────────────────────────────────────────
compute_r2 <- function(y, yhat) {
  complete <- !is.na(y) & !is.na(yhat)
  if (sum(complete) < 10) return(NA_real_)
  cor(y[complete], yhat[complete])^2
}

results <- list()
for (anc_grp in ancestries) {
  sub <- dat[super_pop == anc_grp]
  if (nrow(sub) == 0) next
  row <- list(Trait = trait, Ancestry = anc_grp, N = nrow(sub))
  for (m in methods) {
    row[[m]] <- compute_r2(sub$PHENO, sub[[m]])
  }
  results[[length(results) + 1]] <- as.data.table(row)
}
res_tab <- rbindlist(results, fill = TRUE)

# ── Print and save ────────────────────────────────────────────────────────────
cat("=== Prediction Accuracy (R²) ===\n")
print(res_tab[, lapply(.SD, function(x) if(is.numeric(x)) round(x,4) else x)])
fwrite(res_tab, out_f, sep="\t", quote=FALSE)
cat("\nResults saved to:", out_f, "\n")

# ── Plot ──────────────────────────────────────────────────────────────────────
if (length(methods) > 0) {
  res_long <- melt(res_tab, id.vars = c("Trait","Ancestry","N"),
                   measure.vars = methods,
                   variable.name = "Method", value.name = "R2")

  pal <- c(CPT="#1D4E89", SBLUP="#0A6640", SBC="#6D28D9")

  p <- ggplot(res_long[!is.na(R2)],
              aes(x = Ancestry, y = R2, fill = Method)) +
    geom_bar(stat = "identity", position = "dodge", width = 0.7) +
    scale_fill_manual(values = pal[names(pal) %in% methods]) +
    labs(title    = paste0("PRS Prediction Accuracy — ", trait),
         subtitle = "Evaluated in 1000 Genomes Project super-populations",
         y        = "R² (proportion of variance explained)",
         x        = "Ancestry group") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "top",
          panel.grid.major.x = element_blank())

  plot_f <- sub("\\.tsv$", ".png", out_f)
  ggsave(plot_f, p, width = 8, height = 5, dpi = 150)
  cat("Plot saved to:", plot_f, "\n")
}

# ── Portability summary ───────────────────────────────────────────────────────
if ("EUR" %in% res_tab$Ancestry && length(methods) > 0) {
  cat("\n=== Portability (R² relative to EUR) ===\n")
  eur_r2 <- res_tab[Ancestry == "EUR", ..methods]
  port <- res_tab[Ancestry != "EUR"]
  for (m in methods) {
    eur_val <- as.numeric(eur_r2[[m]])
    if (!is.na(eur_val) && eur_val > 0)
      port[, (paste0(m,"_rel")) := round(get(m) / eur_val, 3)]
  }
  rel_cols <- grep("_rel$", names(port), value=TRUE)
  print(port[, c("Ancestry", rel_cols), with=FALSE])
}
