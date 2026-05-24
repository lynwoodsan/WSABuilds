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
    # Bumped --retry-max-time to 120 so slow connections have enough total time to complete
    curl -L --fail --show-error --progress-bar --retry 5 --connect-timeout 30 --retry-delay 5 --retry-max-time 120 \
        -o "$dest" \
        "$url" || {
        log_error "Failed to download Magisk v${version}."
        exit 1
    }

    # Verify the downloaded file is a valid zip/APK and not an HTML error page
    if ! unzip -t "$dest" &>/dev/null; then
        log_error "Downloaded file does not appear to be a valid APK. The version v${version} may not exist."
        rm -f "$dest"
        exit 1
    fi

    # Also sanity-check the file size -- a valid Magisk APK should be at least 5 MB.
    # Catches edge cases where the server returns a tiny redirect/error body that
    # somehow passes the unzip check (hasn't happened yet, but better safe than sorry).
    local file_size
    file_size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest")
    if [[ "$file_size" -lt 5242880 ]]; then
        log_warn "Downloaded APK is suspiciously small (${file_size} bytes). Double-check v${version}."
    fi

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

    # Note: only extracting x86_64 and x86 since I only build for Intel/AMD target
