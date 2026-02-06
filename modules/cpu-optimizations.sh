#!/bin/bash
# Gentoo make.conf optimization script (auto-detect CPU).

SCRIPT_DIR="$(cd -- "$(dirname -- "$1")" && pwd)"
source "${SCRIPT_DIR}/modules/common.sh"
require_root
require_chroot

echo ">>> Detecting CPU + GCC tuning info..."
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
echo ">>> CPU model: ${CPU_MODEL}"

# Ask GCC what it actually uses for -march/-mtune when we say -march=native.
GCC_MARCH=$(gcc -Q -march=native --help=target 2>/dev/null | awk '$1=="-march=" {print $2}')
GCC_MTUNE=$(gcc -Q -march=native --help=target 2>/dev/null | awk '$1=="-mtune=" {print $2}')

[ -z "$GCC_MARCH" ] && GCC_MARCH="native"
[ -z "$GCC_MTUNE" ] && GCC_MTUNE="native"

echo ">>> GCC reports: -march=${GCC_MARCH}, -mtune=${GCC_MTUNE}"

EXTRA_FLAGS=""
if echo "$CPU_MODEL" | grep -qi 'FX(tm)-8350'; then
    echo ">>> FX(tm)-8350 detected, adding -mfpmath=sse..."
    EXTRA_FLAGS="-mfpmath=sse"
fi

NEW_COMMON_FLAGS="-O2 -pipe -march=native -mtune=${GCC_MTUNE} ${EXTRA_FLAGS}"
echo ">>> Updating COMMON_FLAGS in /etc/portage/make.conf to:"
echo "    ${NEW_COMMON_FLAGS}"

# Replace COMMON_FLAGS line.
if grep -q '^COMMON_FLAGS=' /etc/portage/make.conf; then
    sed -i "s|^COMMON_FLAGS=\".*\"|COMMON_FLAGS=\"${NEW_COMMON_FLAGS}\"|" /etc/portage/make.conf
else
    echo "COMMON_FLAGS=\"${NEW_COMMON_FLAGS}\"" >> /etc/portage/make.conf
fi

# CPU feature flags (CPU_FLAGS_X86), used by ebuilds (NOT -march).
echo ">>> Installing cpuid2cpuflags and generating CPU_FLAGS_X86..."
emerge --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

# Set Rust optimizations.
echo ">>> Setting RUSTFLAGS..."
if grep -q '^RUSTFLAGS=' /etc/portage/make.conf; then
    sed -i 's|^RUSTFLAGS=".*"|RUSTFLAGS="-C target-cpu=native"|' /etc/portage/make.conf
else
    echo 'RUSTFLAGS="-C target-cpu=native"' >> /etc/portage/make.conf
fi

# Set MAKEOPTS based on CPU cores (nproc + 1, like -j9 on 8 cores).
CORES=$(nproc 2>/dev/null || echo 4)
JOBS=$((CORES + 1))

echo ">>> Setting MAKEOPTS to -j${JOBS} (detected ${CORES} cores)..."
if grep -q '^MAKEOPTS=' /etc/portage/make.conf; then
    sed -i "s|^MAKEOPTS=\".*\"|MAKEOPTS=\"-j${JOBS}\"|" /etc/portage/make.conf
else
    echo "MAKEOPTS=\"-j${JOBS}\"" >> /etc/portage/make.conf
fi