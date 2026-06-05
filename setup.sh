#!/usr/bin/env bash
# =============================================================================
# setup.sh  –  Download and install tools for the SISG 2026 PRS Practical
#
# Downloads into exe/ directory in the repo root.
# Usage:
#   bash setup.sh             # auto-detect OS
#   bash setup.sh linux       # force Linux binaries
#   bash setup.sh macos       # force macOS binaries
# =============================================================================

set -euo pipefail
EXE_DIR="$(pwd)/exe"
mkdir -p "${EXE_DIR}"

OS="${1:-auto}"
if [ "${OS}" = "auto" ]; then
  case "$(uname -s)" in
    Darwin*) OS="macos" ;;
    Linux*)  OS="linux" ;;
    *) echo "Unsupported OS: $(uname -s). Specify 'linux' or 'macos'."; exit 1 ;;
  esac
fi

echo "============================================================"
echo "  SISG 2026 PRS Practical — Tool Setup"
echo "  Target: ${EXE_DIR}"
echo "  OS:     ${OS}"
echo "============================================================"
echo ""

# ── Download helper: uses curl (macOS built-in) or wget (Linux) ───────────────
download() {
  local url="$1"
  local out="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL -o "${out}" "${url}"
  elif command -v wget &>/dev/null; then
    wget -q -O "${out}" "${url}"
  else
    echo "ERROR: Neither curl nor wget found. Install one and retry."
    exit 1
  fi
}

# ── PLINK 1.9 ─────────────────────────────────────────────────────────────────
echo "[1/3] Installing PLINK 1.9..."
if [ "${OS}" = "linux" ]; then
  PLINK_URL="https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20231211.zip"
else
  PLINK_URL="https://s3.amazonaws.com/plink1-assets/plink_mac_20231211.zip"
fi

download "${PLINK_URL}" "${EXE_DIR}/plink1.zip"
unzip -q -o "${EXE_DIR}/plink1.zip" plink -d "${EXE_DIR}/"
chmod +x "${EXE_DIR}/plink"
rm "${EXE_DIR}/plink1.zip"
echo "  ✓ PLINK 1.9: ${EXE_DIR}/plink"
"${EXE_DIR}/plink" --version 2>&1 | head -1

# ── PLINK 2 ───────────────────────────────────────────────────────────────────
echo ""
echo "[2/3] Installing PLINK 2..."
if [ "${OS}" = "linux" ]; then
  PLINK2_URL="https://s3.amazonaws.com/plink2-assets/alpha6/plink2_linux_x86_64_20250103.zip"
else
  # Detect Apple Silicon vs Intel
  ARCH="$(uname -m)"
  if [ "${ARCH}" = "arm64" ]; then
    PLINK2_URL="https://s3.amazonaws.com/plink2-assets/alpha6/plink2_mac_arm64_20250103.zip"
  else
    PLINK2_URL="https://s3.amazonaws.com/plink2-assets/alpha6/plink2_mac_20250103.zip"
  fi
fi

download "${PLINK2_URL}" "${EXE_DIR}/plink2.zip"
unzip -q -o "${EXE_DIR}/plink2.zip" plink2 -d "${EXE_DIR}/"
chmod +x "${EXE_DIR}/plink2"
rm "${EXE_DIR}/plink2.zip"
echo "  ✓ PLINK 2: ${EXE_DIR}/plink2"
"${EXE_DIR}/plink2" --version 2>&1 | head -1

# ── GCTB ──────────────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Installing GCTB..."
if [ "${OS}" = "linux" ]; then
  GCTB_URL="https://cnsgenomics.com/software/gctb/download/gctb_2.05beta_Linux.zip"
else
  GCTB_URL="https://cnsgenomics.com/software/gctb/download/gctb_2.05beta_Mac.zip"
fi

download "${GCTB_URL}" "${EXE_DIR}/gctb.zip" || {
  echo "  Warning: GCTB download failed. Download manually from:"
  echo "  https://cnsgenomics.com/software/gctb/#Download"
}

if [ -f "${EXE_DIR}/gctb.zip" ]; then
  unzip -q -o "${EXE_DIR}/gctb.zip" -d "${EXE_DIR}/gctb_tmp/"
  find "${EXE_DIR}/gctb_tmp" -name "gctb" -exec cp {} "${EXE_DIR}/gctb" \;
  chmod +x "${EXE_DIR}/gctb"
  rm -rf "${EXE_DIR}/gctb.zip" "${EXE_DIR}/gctb_tmp/"
  echo "  ✓ GCTB: ${EXE_DIR}/gctb"
  "${EXE_DIR}/gctb" --version 2>&1 | head -1 || true
fi

# ── macOS: remove quarantine flag if needed ───────────────────────────────────
if [ "${OS}" = "macos" ]; then
  echo ""
  echo "  Removing macOS quarantine flags..."
  xattr -dr com.apple.quarantine "${EXE_DIR}/" 2>/dev/null || true
  echo "  ✓ Done"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Setup complete! Add exe/ to your PATH:"
echo ""
echo "    export PATH=\"\$PWD/exe:\$PATH\""
echo ""
echo "  Or set per-session in your shell config (~/.zshrc or ~/.bash_profile):"
echo "    export PATH=\"$(pwd)/exe:\$PATH\""
echo "============================================================"
