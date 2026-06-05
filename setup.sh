#!/usr/bin/env bash
# =============================================================================
# setup.sh  –  Download PLINK 1.9, PLINK 2, and GCTA
#
# Sources (checked June 2026):
#   PLINK 1.9  https://www.cog-genomics.org/plink/1.9/
#   PLINK 2.0  https://www.cog-genomics.org/plink/2.0/
#   GCTA v1.95.1  https://yanglab.westlake.edu.cn/software/gcta/#Download
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
echo "  PLINK + GCTA Setup"
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

# ── 3. GCTA  (v1.95.1 · 9 Feb 2026) ──────────────────────────────────────────
# Source: https://yanglab.westlake.edu.cn/software/gcta/#Download
echo ""
echo "[3/3] GCTA v1.95.1"

if [ "${OS}" = "linux" ]; then
  # Linux x86_64 — v1.95.1
  GCTA_URL="https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.95.1-linux-x86_64.zip"
else
  if [ "${ARCH}" = "arm64" ]; then
    # macOS Apple Silicon — v1.95.1
    GCTA_URL="https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.95.1-macOS-arm64.zip"
    echo "  Apple Silicon — using macOS arm64 build"
  else
    # macOS Intel — latest available is v1.94.1 for x86_64
    GCTA_URL="https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.94.1-macOS-x86_64.zip"
    echo "  Intel Mac — using macOS x86_64 build (v1.94.1)"
  fi
fi

echo "  URL: ${GCTA_URL}"
if dl "${GCTA_URL}" "${EXE_DIR}/gcta.zip" 2>/dev/null; then
  unzip -q -o "${EXE_DIR}/gcta.zip" -d "${EXE_DIR}/gcta_tmp/"

  # The binary may be named gcta64, gcta-1.95.1, or similar — find it
  GCTA_BIN=$(find "${EXE_DIR}/gcta_tmp" -type f \( -name "gcta64" -o -name "gcta-*" \) | grep -v "\.txt\|\.pdf\|\.sh\|\.dylib\|\.so" | head -1)

  if [ -n "${GCTA_BIN}" ]; then
    cp "${GCTA_BIN}" "${EXE_DIR}/gcta"
    chmod +x "${EXE_DIR}/gcta"
    echo "  OK: GCTA installed as ${EXE_DIR}/gcta"
  else
    echo "  WARN: Could not locate gcta binary inside zip. Check ${EXE_DIR}/gcta_tmp/"
  fi

  rm -rf "${EXE_DIR}/gcta.zip" "${EXE_DIR}/gcta_tmp/"

  # macOS arm64: GCTA requires setting library env vars (see README in zip)
  if [ "${OS}" = "macos" ] && [ "${ARCH}" = "arm64" ]; then
    echo ""
    echo "  NOTE (macOS arm64): GCTA may require setting DYLD_LIBRARY_PATH."
    echo "  If you see 'Library not loaded' errors, run:"
    echo "    export DYLD_LIBRARY_PATH=\"${EXE_DIR}:\$DYLD_LIBRARY_PATH\""
    echo "  Or check the README inside the original zip for full instructions."
  fi
else
  echo "  WARN: GCTA download failed."
  echo "  Download manually from: https://yanglab.westlake.edu.cn/software/gcta/#Download"
  echo "  Place the gcta binary in: ${EXE_DIR}/ and rename it to 'gcta'"
fi

# ── macOS: remove Gatekeeper quarantine so binaries can actually run ──────────
if [ "${OS}" = "macos" ]; then
  echo ""
  echo "  Clearing macOS Gatekeeper quarantine..."
  xattr -dr com.apple.quarantine "${EXE_DIR}/" 2>/dev/null || true
  echo "  Done"
fi

# ── Final verification ────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Verification"
echo "============================================================"
all_ok=true
for t in plink plink2 gcta; do
  if [ -x "${EXE_DIR}/${t}" ]; then
    echo "  [OK] ${t}"
  else
    echo "  [!!] ${t}  — not found at ${EXE_DIR}/${t}"
    all_ok=false
  fi
done

echo ""
echo "  Add exe/ to your PATH for this session:"
echo "    export PATH=\"${EXE_DIR}:\$PATH\""
echo ""
echo "  To make it permanent, add the line above to:"
echo "    macOS  → ~/.zshrc"
echo "    Linux  → ~/.bashrc"
echo "  then restart your terminal."
echo "============================================================"
