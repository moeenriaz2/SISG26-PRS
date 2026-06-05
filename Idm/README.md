# LD Matrices (for GCTB SBayes C)

GCTB requires LD correlation matrices in its own sparse binary format.
These are pre-computed in 38 non-overlapping LD blocks for chromosome 20.

## Download

**Option 1 — From this repository's Releases:**
```bash
wget https://github.com/moeenriaz2/SISG26-PRS/releases/download/v1.0/ldm_chr20.tar.gz
tar -xzf ldm_chr20.tar.gz -C practical/
```

**Option 2 — From GCTB website (full genome):**
Pre-computed LD matrices for the full genome are available at:
https://cnsgenomics.com/software/gctb/#Download

**Option 3 — Compute your own** (reference population must match GWAS ancestry):
```bash
GCTB=./exe/gctb
for block in 1 2 3 ... 38; do
  ${GCTB} --bfile <your_ref_panel> \
          --make-full-ldm \
          --snp-list ldm/block${block}.snplist \
          --out ldm/BLOCK${block}.CHROM20
done
```

LD blocks for EUR were identified using [LDetect](http://bitbucket.org/nygcresearch/ldetect-data).

---

## File Structure (after download)

```
ldm/
├── mldm.txt                   ← List of paths to all 38 block matrices (passed to --mldm)
├── BLOCK1618.CHROM20.ldm.full
├── BLOCK1618.CHROM20.ldm.full.bin
├── BLOCK1618.CHROM20.ldm.full.info
├── BLOCK1619.CHROM20.ldm.full
├── ...
└── BLOCK1655.CHROM20.ldm.full
```

The `mldm.txt` file lists the **full path** to each `.ldm.full` file, one per line:
```
ldm/BLOCK1618.CHROM20.ldm.full
ldm/BLOCK1619.CHROM20.ldm.full
...
```

**Important:** Update paths in `mldm.txt` if you move the `ldm/` folder.

---

## How LD Matrices Were Computed

```bash
# N = 348,501 unrelated EUR UK Biobank participants
# chromosome 20 only, split into 38 LD blocks
GCTB=./exe/gctb
for block in $(seq 1 38); do
  ${GCTB} --bfile UKBu_chrom20 \
          --make-full-ldm \
          --snp-list ldm/block${block}.snplist \
          --out ldm/BLOCK$(printf "%04d" $block).CHROM20
  echo "ldm/BLOCK$(printf "%04d" $block).CHROM20.ldm.full"
done > ldm/mldm.txt
```
