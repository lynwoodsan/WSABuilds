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
    curl -L --fail --show-error --progress-bar \
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

    if [[ ! -d "$wsa_dir" ]]; then
        log_error "WSA directory not found: ${wsa_dir}"
        exit 1
    fi

    log_info "Patching WSA system image with Magisk ..."

    # Copy Magisk binaries into WSA tools directory
    local tools_dir="${wsa_dir}/Tools"
    mkdir -p "$tools_dir"

    cp -v "${magisk_extract_dir}/lib/x86_64/libmagisk64.so" \
          "${tools_dir}/magisk64" 2>/dev/null || log_warn "libmagisk64.so not found, skipping."

    cp -v "${magisk_extract_dir}/lib/x86/libmagisk32.so" \
          "${tools_dir}/magisk32" 2>/dev/null || log_warn "libmagisk32.so not found, skipping."

    cp -v "${magisk_extract_dir}/lib/x86_64/libmagiskinit.so" \
          "${tools_dir}/magiskinit" 2>/dev/null || log_warn "libmagiskinit.so not found, skipping."

    chmod +x "${tools_dir}/"magisk* 2>/dev/null || true

    log_info "Magisk binaries copied to ${tools_dir}"
}

# -----------------------------------------------
# Main entry point
# -----------------------------------------------
main() {
    local magisk_version="${1:-26.4}"

    log_info "=== Magisk Integration Script ==="
    log_info "Magisk version : ${magisk_version}"
    log_info "Work directory : ${WORK_DIR}"

    check_dependencies

    local apk_path
    apk_path="$(download_magisk "$magisk_version")"

    local extract_dir
    extract_dir="$(extract_magisk_libs "$apk_path")"

    local wsa_dir="${WORK_DIR}/wsa"
    patch_wsa_image "$wsa_dir" "$extract_dir"

    log_info "Magisk integration complete."
}

main "$@"
