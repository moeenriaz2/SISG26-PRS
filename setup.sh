#!/usr/bin/env bash
# =============================================================================
# setup.sh  –  Download PLINK 1.9, PLINK 2, and GCTB
#
# Sources (checked June 2026):
#   PLINK 1.9  https://www.cog-genomics.org/plink/1.9/
#   PLINK 2.0  https://www.cog-genomics.org/plink/2.0/
#   GCTB       https://cnsgenomics.com/software/gctb/#Download
#
# Usage:
#   bash setup.sh            # auto-detect OS / chip
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
echo "  PLINK / GCTB Setup"
echo "  Target : ${EXE_DIR}"
echo "  OS     : ${OS}"
echo "  Arch   : ${ARCH}"
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
echo "[1/3] PLINK 1.9"

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
echo "[2/3] PLINK 2"

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
    echo "  Intel Mac detected — using AVX2 build"
  fi
fi

echo "  URL: ${P2URL}"
dl "${P2URL}" "${EXE_DIR}/plink2.zip"
unzip -q -o "${EXE_DIR}/plink2.zip" plink2 -d "${EXE_DIR}/"
chmod +x "${EXE_DIR}/plink2"
rm -f "${EXE_DIR}/plink2.zip"
echo "  OK: $("${EXE_DIR}/plink2" --version 2>&1 | head -1)"

# ── 3. GCTB (v2.05 beta) ──────────────────────────────────────────────────────
echo ""
echo "[3/3] GCTB"

if [ "${OS}" = "linux" ]; then
  GURL="https://cnsgenomics.com/software/gctb/download/gctb_2.05beta_Linux.zip"
else
  GURL="https://cnsgenomics.com/software/gctb/download/gctb_2.05beta_Mac.zip"
fi

echo "  URL: ${GURL}"
if dl "${GURL}" "${EXE_DIR}/gctb.zip" 2>/dev/null; then
  unzip -q -o "${EXE_DIR}/gctb.zip" -d "${EXE_DIR}/gctb_tmp/"
  find "${EXE_DIR}/gctb_tmp" -type f -name "gctb" -exec cp {} "${EXE_DIR}/gctb" \;
  chmod +x "${EXE_DIR}/gctb"
  rm -rf "${EXE_DIR}/gctb.zip" "${EXE_DIR}/gctb_tmp/"
  echo "  OK: GCTB installed"
else
  echo "  WARN: GCTB download failed."
  echo "  Manual download: https://cnsgenomics.com/software/gctb/#Download"
  echo "  Place the gctb binary in: ${EXE_DIR}/"
fi

# ── macOS: clear Gatekeeper quarantine so binaries can run ────────────────────
if [ "${OS}" = "macos" ]; then
  echo ""
  echo "  Clearing macOS quarantine flags..."
  xattr -dr com.apple.quarantine "${EXE_DIR}/" 2>/dev/null || true
  echo "  Done"
fi

# ── Final check ───────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Verification"
echo "============================================================"
ok=true
for t in plink plink2 gctb; do
  if [ -x "${EXE_DIR}/${t}" ]; then
    echo "  [OK] ${t}"
  else
    echo "  [!!] ${t}  — not found"
    ok=false
  fi
done

echo ""
echo "  To use the tools in this session, run:"
echo "    export PATH=\"${EXE_DIR}:\$PATH\""
echo ""
echo "  To make permanent, add to ~/.zshrc (macOS) or ~/.bashrc (Linux):"
echo "    export PATH=\"${EXE_DIR}:\$PATH\""
echo "============================================================"
