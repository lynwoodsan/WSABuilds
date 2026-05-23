#!/bin/bash

# WSABuilds - Build Script
# Builds Windows Subsystem for Android (WSA) with optional GApps and root support
# Based on MustardChef/WSABuilds

set -e

# ============================================================
# Configuration & Defaults
# ============================================================

ARCH=${ARCH:-x64}
RELEASE_TYPE=${RELEASE_TYPE:-retail}       # retail | RP | WIS | WIF
MAGISK_VER=${MAGISK_VER:-stable}           # stable | beta | canary | debug
GAPPS_BRAND=${GAPPS_BRAND:-MindTheGapps}   # MindTheGapps | none
GAPPS_VARIANT=${GAPPS_VARIANT:-pico}
ROOT_SOL=${ROOT_SOL:-magisk}               # magisk | kernelsu | none
COMPRESS_FORMAT=${COMPRESS_FORMAT:-zip}    # zip | 7z | xz
BUILD_DIR="$(pwd)/build"
DOWNLOAD_DIR="$(pwd)/download"
OUTPUT_DIR="$(pwd)/output"

# ============================================================
# Logging Helpers
# ============================================================

log_info()  { echo -e "\e[32m[INFO]\e[0m  $*"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

# ============================================================
# Dependency Check
# ============================================================

check_dependencies() {
    log_info "Checking dependencies..."
    local deps=("python3" "pip" "unzip" "7z" "curl" "jq" "lzip")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Please install them before continuing."
        exit 1
    fi

    log_info "All dependencies satisfied."
}

# ============================================================
# Directory Setup
# ============================================================

setup_dirs() {
    log_info "Setting up build directories..."
    mkdir -p "$BUILD_DIR" "$DOWNLOAD_DIR" "$OUTPUT_DIR"
}

# ============================================================
# Fetch Latest WSA Package
# ============================================================

fetch_wsa() {
    log_info "Fetching WSA package (arch=$ARCH, release=$RELEASE_TYPE)..."
    python3 scripts/fetch_wsa.py \
        --arch "$ARCH" \
        --release-type "$RELEASE_TYPE" \
        --download-dir "$DOWNLOAD_DIR"
}

# ============================================================
# Download GApps
# ============================================================

download_gapps() {
    if [[ "$GAPPS_BRAND" == "none" ]]; then
        log_info "GApps disabled — skipping download."
        return
    fi

    log_info "Downloading $GAPPS_BRAND ($GAPPS_VARIANT) for $ARCH..."
    python3 scripts/download_gapps.py \
        --brand "$GAPPS_BRAND" \
        --variant "$GAPPS_VARIANT" \
        --arch "$ARCH" \
        --download-dir "$DOWNLOAD_DIR"
}

# ============================================================
# Download Root Solution
# ============================================================

download_root() {
    if [[ "$ROOT_SOL" == "none" ]]; then
        log_info "Root solution disabled — skipping."
        return
    fi

    log_info "Downloading root solution: $ROOT_SOL ($MAGISK_VER)..."
    python3 scripts/download_root.py \
        --root-sol "$ROOT_SOL" \
        --magisk-ver "$MAGISK_VER" \
        --download-dir "$DOWNLOAD_DIR"
}

# ============================================================
# Build WSA Image
# ============================================================

build_wsa() {
    log_info "Building WSA image..."
    python3 scripts/build_wsa.py \
        --arch "$ARCH" \
        --gapps-brand "$GAPPS_BRAND" \
        --gapps-variant "$GAPPS_VARIANT" \
        --root-sol "$ROOT_SOL" \
        --build-dir "$BUILD_DIR" \
        --download-dir "$DOWNLOAD_DIR" \
        --output-dir "$OUTPUT_DIR" \
        --compress-format "$COMPRESS_FORMAT"
}

# ============================================================
# Main
# ============================================================

main() {
    log_info "=== WSABuilds — Starting Build ==="
    log_info "Arch=$ARCH | Release=$RELEASE_TYPE | Root=$ROOT_SOL | GApps=$GAPPS_BRAND"

    check_dependencies
    setup_dirs
    fetch_wsa
    download_gapps
    download_root
    build_wsa

    log_info "=== Build complete! Output: $OUTPUT_DIR ==="
}

main "$@"
