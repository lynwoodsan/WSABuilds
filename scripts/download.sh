#!/bin/bash

# WSABuilds - Download Script
# Handles downloading WSA packages and required components
# Fork of MustardChef/WSABuilds

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Default values
WSA_ARCH="x64"
WSA_RELEASE="retail"
DOWNLOAD_DIR="./download"
MAX_RETRIES=3
RETRY_DELAY=5

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            WSA_ARCH="$2"
            shift 2
            ;;
        --release)
            WSA_RELEASE="$2"
            shift 2
            ;;
        --download-dir)
            DOWNLOAD_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --arch <x64|arm64>          Target architecture (default: x64)"
            echo "  --release <retail|release preview|insider slow|insider fast>"
            echo "                              WSA release channel (default: retail)"
            echo "  --download-dir <path>       Directory to store downloads (default: ./download)"
            echo "  --help                      Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            ;;
    esac
done

# Validate architecture
if [[ "$WSA_ARCH" != "x64" && "$WSA_ARCH" != "arm64" ]]; then
    log_error "Invalid architecture: $WSA_ARCH. Must be 'x64' or 'arm64'."
fi

# Create download directory
mkdir -p "$DOWNLOAD_DIR"
log_info "Download directory: $DOWNLOAD_DIR"

# Function to download with retry logic
download_with_retry() {
    local url="$1"
    local output="$2"
    local attempt=1

    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_info "Downloading $(basename "$output") (attempt $attempt/$MAX_RETRIES)..."
        if curl -L --progress-bar --retry 3 --retry-delay 2 -o "$output" "$url"; then
            log_success "Downloaded: $(basename "$output")"
            return 0
        fi
        log_warn "Download failed. Retrying in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"
        ((attempt++))
    done

    log_error "Failed to download $url after $MAX_RETRIES attempts."
}

# Fetch WSA package URL from Microsoft Store
fetch_wsa_url() {
    log_info "Fetching WSA package URL for arch: $WSA_ARCH, release: $WSA_RELEASE"

    local store_id="9P3395VX91NR"
    local api_url="https://store.rg-adguard.net/api/GetFiles"

    local response
    response=$(curl -s -X POST "$api_url" \
        -d "type=ProductId&url=${store_id}&ring=${WSA_RELEASE}&lang=en-US" \
        -H "Content-Type: application/x-www-form-urlencoded")

    # Extract the MSIX bundle URL matching the architecture
    local wsa_url
    wsa_url=$(echo "$response" | grep -oP 'https://[^"]+MicrosoftCorporationII\.WindowsSubsystemForAndroid[^"]+\.msixbundle' | head -1)

    if [[ -z "$wsa_url" ]]; then
        log_error "Could not find WSA download URL. The store API may be unavailable."
    fi

    echo "$wsa_url"
}

# Main download routine
main() {
    log_info "Starting WSA download process"
    log_info "Architecture: $WSA_ARCH"
    log_info "Release channel: $WSA_RELEASE"

    local wsa_url
    wsa_url=$(fetch_wsa_url)

    local wsa_filename
    wsa_filename=$(basename "$wsa_url" | cut -d'?' -f1)
    local wsa_output="${DOWNLOAD_DIR}/${wsa_filename}"

    if [[ -f "$wsa_output" ]]; then
        log_warn "WSA package already exists at $wsa_output. Skipping download."
    else
        download_with_retry "$wsa_url" "$wsa_output"
    fi

    # Export path for use in other scripts
    echo "$wsa_output" > "${DOWNLOAD_DIR}/.wsa_package_path"
    log_success "WSA package path saved to ${DOWNLOAD_DIR}/.wsa_package_path"
    log_success "Download complete!"
}

main
