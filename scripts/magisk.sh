#!/bin/bash

# magisk.sh - Script to integrate Magisk root into WSA builds
# Part of WSABuilds project
# Based on original work by MustardChef/WSABuilds

set -e

# -----------------------------------------------
# Configuration
# -----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="${ROOT_DIR}/work"
OUTPUT_DIR="${ROOT_DIR}/output"

# Magisk APK download base URL
MAGISK_RELEASE_URL="https://github.com/topjohnwu/Magisk/releases/download"

# -----------------------------------------------
# Logging helpers
# -----------------------------------------------
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# -----------------------------------------------
# Check required tools
# -----------------------------------------------
check_dependencies() {
    local deps=("curl" "unzip" "7z" "python3")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Required dependency '$dep' is not installed."
            exit 1
        fi
    done
    log_info "All dependencies are satisfied."
}

# -----------------------------------------------
# Download Magisk APK
# -----------------------------------------------
download_magisk() {
    local version="$1"
    local dest="${WORK_DIR}/magisk.apk"

    if [[ -z "$version" ]]; then
        log_error "Magisk version not specified."
        exit 1
    fi

    local url="${MAGISK_RELEASE_URL}/v${version}/Magisk-v${version}.apk"
    log_info "Downloading Magisk v${version} from ${url} ..."

    mkdir -p "$WORK_DIR"
    # Increased --retry from 3 to 5 to better handle flaky connections on my home network
    # Also added --connect-timeout 30 to avoid hanging indefinitely on slow connections
    # Added --retry-delay 5 so retries don't hammer the server back-to-back
    curl -L --fail --show-error --progress-bar --retry 5 --connect-timeout 30 --retry-delay 5 \
        -o "$dest" \
        "$url" || {
        log_error "Failed to download Magisk v${version}."
        exit 1
    }

    log_info "Magisk downloaded to ${dest}"
    echo "$dest"
}

# -----------------------------------------------
# Extract Magisk libs from APK
# -----------------------------------------------
extract_magisk_libs() {
    local apk_path="$1"
    local extract_dir="${WORK_DIR}/magisk_extracted"

    log_info "Extracting Magisk libs from APK ..."
    mkdir -p "$extract_dir"

    unzip -o "$apk_path" \
        'lib/x86_64/*' \
        'lib/x86/*' \
        'assets/boot_patch.sh' \
        'assets/util_functions.sh' \
        -d "$extract_dir" || {
        log_error "Failed to extract Magisk APK."
        exit 1
    }

    log_info "Magisk libs extracted to ${extract_dir}"
    echo "$extract_dir"
}

# -----------------------------------------------
# Patch WSA system image with Magisk
# -----------------------------------------------
patch_wsa_image() {
    local wsa_dir="$1"
    local magisk_extract_dir="$2"

    if [[ ! -d "$wsa_
