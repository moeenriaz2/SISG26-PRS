#!/usr/bin/env bash
# =============================================================================
# setup.sh  –  Download PLINK 1.9, PLINK 2, GCTA, and GCTB
#
# Sources (checked June 2026):
#   PLINK 1.9  https://www.cog-genomics.org/plink/1.9/
#   PLINK 2.0  https://www.cog-genomics.org/plink/2.0/
#   GCTA       https://yanglab.westlake.edu.cn/software/gcta/#Download
#   GCTB       https://cnsgenomics.com/software/gctb/#Download
#
# NOTE: GCTB v2.5.5 provides a Linux binary only.
#       macOS users must compile from source (see below) or use a Linux machine.
#
# Usage:
#   bash setup.sh            # auto-detect OS and chip
#   bash setup.sh linux      # force Linux
#   bash setup.sh macos      # force macOS
# =============================================================================

set -euo pipefail

EXE_DIR="$(cd "$(dirname "$0")" && pwd)/exe"
mkdir -p "${EXE_DIR}"

# ── Detect OS ─────────────────────────────────────────────────────────────────
OS="${1:-auto}"
if [ "${OS}" = "auto" ]; then
  case "$(uname -s)" in
    Darwin*) OS="macos" ;;
    Linux*)  OS="linux" ;;
    *) echo "ERROR: Unknown OS. Specify 'linux' or 'macos'."; exit 1 ;;
  esac
fi

ARCH="$(uname -m)"

echo "============================================================"
echo "  PLINK + GCTA + GCTB Setup"
echo "  Target : ${EXE_DIR}"
echo "  OS     : ${OS}  |  Arch: ${ARCH}"
echo "============================================================"
echo ""

# ── Download helper: curl (macOS built-in) or wget ────────────────────────────
dl() {
  local url="$1" out="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL --retry 3 -o "${out}" "${url}"
  elif command -v wget &>/dev/null; then
    wget -q --tries=3 -O "${out}" "${url}"
  else
    echo "  ERROR: neither curl nor wget found."
    echo "  Install: brew install curl  (macOS)  or  sudo apt install curl  (Linux)"
    exit 1
  fi
}

# ── 1. PLINK 1.9  (stable beta 7.11 · 19 Aug 2025) ───────────────────────────
echo "[1/4] PLINK 1.9"
if [ "${OS}" = "linux" ]; then
  P1URL="https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20250819.zip"
else
  P1URL="https://s3.amazonaws.com/plink1-assets/plink_mac_20250819.zip"
fi
echo "  URL: ${P1URL}"
dl "${P1URL}" "${EXE_DIR}/plink1.zip"
unzip -q -o "${EXE_DIR}/plink1.zip" plink -d "${EXE_DIR}/"
chmod +x "${EXE_DIR}/plink"
rm -f "${EXE_DIR}/plink1.zip"
echo "  OK: $("${EXE_DIR}/plink" --version 2>&1 | head -1)"

# ── 2. PLINK 2  (alpha 7.1 · 4 May 2026) ─────────────────────────────────────
echo ""
echo "[2/4] PLINK 2"
if [ "${OS}" = "linux" ]; then
  if grep -q avx2 /proc/cpuinfo 2>/dev/null; then
    P2URL="https://s3.amazonaws.com/plink2-assets/alpha7/plink2_linux_avx2_20260504.zip"
    echo "  AVX2 CPU detected — using optimised build"
  else
    P2URL="https://s3.amazonaws.com/plink2-assets/alpha7/plink2_linux_x86_64_20260504.zip"
  fi
else
  if [ "${ARCH}" = "arm64" ]; then
    P2URL="https://s3.amazonaws.com/plink2-assets/alpha7/plink2_mac_arm64_20260504.zip"
    echo "  Apple Silicon (arm64) detected"
  else
    P2URL="https://s3.amazonaws.com/plink2-assets/alpha7/plink2_mac_avx2_20260504.zip"
    echo "  Intel Mac — using AVX2 build"
  fi
fi
echo "  URL: ${P2URL}"
dl "${P2URL}" "${EXE_DIR}/plink2.zip"
unzip -q -o "${EXE_DIR}/plink2.zip" plink2 -d "${EXE_DIR}/"
chmod +x "${EXE_DIR}/plink2"
rm -f "${EXE_DIR}/plink2.zip"
echo "  OK: $("${EXE_DIR}/plink2" --version 2>&1 | head -1)"

# ── 3. GCTA  (v1.95.1 · 9 Feb 2026) ──────────────────────────────────────────
# Source: https://yanglab.westlake.edu.cn/software/gcta/#Download
echo ""
echo "[3/4] GCTA v1.95.1"
if [ "${OS}" = "linux" ]; then
  GCTA_URL="https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.95.1-linux-x86_64.zip"
else
  if [ "${ARCH}" = "arm64" ]; then
    GCTA_URL="https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.95.1-macOS-arm64.zip"
    echo "  Apple Silicon — using macOS arm64 build"
  else
    # v1.95.1 not yet available for Intel Mac; latest is v1.94.1
    GCTA_URL="https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.94.1-macOS-x86_64.zip"
    echo "  Intel Mac — using v1.94.1 (latest available for x86_64)"
  fi
fi
echo "  URL: ${GCTA_URL}"
if dl "${GCTA_URL}" "${EXE_DIR}/gcta.zip" 2>/dev/null; then
  unzip -q -o "${EXE_DIR}/gcta.zip" -d "${EXE_DIR}/gcta_tmp/"
  # Binary may be named gcta64 or gcta-1.95.1 etc.
  GCTA_BIN=$(find "${EXE_DIR}/gcta_tmp" -type f \
    \( -name "gcta64" -o -name "gcta-*" \) \
    ! -name "*.txt" ! -name "*.pdf" ! -name "*.sh" \
    ! -name "*.dylib" ! -name "*.so" | head -1)
  if [ -n "${GCTA_BIN}" ]; then
    cp "${GCTA_BIN}" "${EXE_DIR}/gcta"
    chmod +x "${EXE_DIR}/gcta"
    echo "  OK: GCTA installed as ${EXE_DIR}/gcta"
  else
    echo "  WARN: Could not locate gcta binary inside zip."
    ls "${EXE_DIR}/gcta_tmp/" 2>/dev/null || true
  fi
  rm -rf "${EXE_DIR}/gcta.zip" "${EXE_DIR}/gcta_tmp/"
  if [ "${OS}" = "macos" ] && [ "${ARCH}" = "arm64" ]; then
    echo "  NOTE (macOS arm64): if you see 'Library not loaded', run:"
    echo "    export DYLD_LIBRARY_PATH=\"${EXE_DIR}:\$DYLD_LIBRARY_PATH\""
  fi
else
  echo "  WARN: GCTA download failed."
  echo "  Download manually: https://yanglab.westlake.edu.cn/software/gcta/#Download"
fi

# ── 4. GCTB  (v2.5.5 · 4 Feb 2026) ───────────────────────────────────────────
# Source: https://cnsgenomics.com/software/gctb/#Download
# NOTE: v2.x is Linux-only. No macOS binary is provided for v2.x.
echo ""
echo "[4/4] GCTB v2.5.5"

if [ "${OS}" = "linux" ]; then
  GCTB_URL="https://gctbhub.cloud.edu.au/software/gctb/download/gctb_2.5.5_Linux.zip"
  echo "  URL: ${GCTB_URL}"
  if dl "${GCTB_URL}" "${EXE_DIR}/gctb.zip" 2>/dev/null; then
    unzip -q -o "${EXE_DIR}/gctb.zip" -d "${EXE_DIR}/gctb_tmp/"
    GCTB_BIN=$(find "${EXE_DIR}/gctb_tmp" -type f -name "gctb" | head -1)
    if [ -n "${GCTB_BIN}" ]; then
      cp "${GCTB_BIN}" "${EXE_DIR}/gctb"
      chmod +x "${EXE_DIR}/gctb"
      echo "  OK: GCTB installed as ${EXE_DIR}/gctb"
    else
      echo "  WARN: Could not find gctb binary inside zip."
      ls "${EXE_DIR}/gctb_tmp/" 2>/dev/null || true
    fi
    rm -rf "${EXE_DIR}/gctb.zip" "${EXE_DIR}/gctb_tmp/"
  else
    echo "  WARN: GCTB download failed."
    echo "  Download manually: https://cnsgenomics.com/software/gctb/#Download"
  fi
else
  # macOS: no pre-built binary for v2.x — must compile from source
  echo ""
  echo "  ⚠  GCTB v2.x has no macOS binary — Linux only."
  echo ""
  echo "  Options for macOS users:"
  echo "  ① Compile from source (requires CMake, gcc, Eigen3):"
  echo "       git clone https://github.com/jianzeng/GCTB.git"
  echo "       cd GCTB && mkdir build && cd build"
  echo "       cmake .. -DCMAKE_BUILD_TYPE=Release"
  echo "       make -j4"
  echo "       cp gctb ${EXE_DIR}/gctb"
  echo ""
  echo "  ② Use a Linux machine / HPC / Docker for the SBayesC steps."
  echo ""
  echo "  ③ Install the old v1.0 Mac binary (limited features, missing SBayes):"
  echo "       curl -fsSL -o /tmp/gctb_1.0_Mac.zip \\"
  echo "         https://gctbhub.cloud.edu.au/software/gctb/download/gctb_1.0_Mac.zip"
  echo "       unzip -q /tmp/gctb_1.0_Mac.zip -d ${EXE_DIR}/gctb_tmp/"
  echo "       cp \$(find ${EXE_DIR}/gctb_tmp -name 'gctb') ${EXE_DIR}/gctb"
  echo "       chmod +x ${EXE_DIR}/gctb"
fi

# ── macOS: clear Gatekeeper quarantine ────────────────────────────────────────
if [ "${OS}" = "macos" ]; then
  echo ""
  echo "  Clearing macOS Gatekeeper quarantine on all binaries..."
  xattr -dr com.apple.quarantine "${EXE_DIR}/" 2>/dev/null || true
  echo "  Done"
fi

# ── Final verification ────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Verification"
echo "============================================================"
for t in plink plink2 gcta gctb; do
  if [ -x "${EXE_DIR}/${t}" ]; then
    echo "  [OK] ${t}"
  else
    if [ "${t}" = "gctb" ] && [ "${OS}" = "macos" ]; then
      echo "  [--] gctb  — not installed (macOS: see instructions above)"
    else
      echo "  [!!] ${t}  — not found at ${EXE_DIR}/${t}"
    fi
  fi
done

echo ""
echo "  Add exe/ to your PATH for this session:"
echo "    export PATH=\"${EXE_DIR}:\$PATH\""
echo ""
echo "  To make it permanent:"
echo "    macOS → add to ~/.zshrc"
echo "    Linux → add to ~/.bashrc"
echo "============================================================"
