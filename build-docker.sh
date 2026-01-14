#!/bin/bash
# Build script for OpenHarmony rootfs Docker images
# Downloads NDK, extracts sysroot, and builds minimal OHOS containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${REGISTRY:-}"
IMAGE_PREFIX="${IMAGE_PREFIX:-openharmony}"
TAG="${TAG:-latest}"
NDK_URL="${NDK_URL:-https://cidownload.openharmony.cn/version/Daily_Version/LLVM-19/20260114_061434/version-Daily_Version-LLVM-19-20260114_061434-LLVM-19.tar.gz}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg() { echo -e "${GREEN}===> $*${NC}"; }
error() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING: $*${NC}"; }

show_help() {
    cat <<EOF
Build OpenHarmony rootfs Docker images from NDK sysroot

Usage: $0 [OPTIONS] [TARGET...]

Targets:
    x86_64      Build x86_64 OpenHarmony rootfs
    aarch64     Build aarch64 OpenHarmony rootfs
    arm         Build ARM 32-bit OpenHarmony rootfs
    riscv64     Build RISC-V 64-bit OpenHarmony rootfs
    mips64      Build MIPS64 OpenHarmony rootfs
    all         Build all available targets (default)

Options:
    --registry=REG      Docker registry prefix (e.g., docker.io/user)
    --prefix=PREFIX     Image name prefix (default: openharmony)
    --tag=TAG           Image tag (default: latest)
    --ndk-url=URL       Custom NDK download URL
    --push              Push images to registry after build
    --no-cache          Build without Docker cache
    --help              Show this help

Examples:
    # Build all targets
    $0 all

    # Build x86_64 only
    $0 x86_64

    # Build and push to Docker Hub
    $0 --registry=docker.io/myuser --push all

EOF
}

# Parse arguments
TARGETS=""
PUSH_IMAGE=0
BUILD_ARGS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --help) show_help; exit 0 ;;
        --registry=*) REGISTRY="${1#*=}" ;;
        --prefix=*) IMAGE_PREFIX="${1#*=}" ;;
        --tag=*) TAG="${1#*=}" ;;
        --ndk-url=*) NDK_URL="${1#*=}" ;;
        --push) PUSH_IMAGE=1 ;;
        --no-cache) BUILD_ARGS="${BUILD_ARGS} --no-cache" ;;
        x86_64|aarch64|arm|riscv64|mips64|all) TARGETS="${TARGETS} $1" ;;
        *) error "Unknown option: $1" ;;
    esac
    shift
done

# Default to all targets
TARGETS="${TARGETS:-all}"
if [[ "${TARGETS}" == *"all"* ]]; then
    TARGETS="x86_64 aarch64 arm riscv64 mips64"
fi

# Build image function
build_image() {
    local target=$1
    local image_name="${IMAGE_PREFIX}-${target}"
    
    if [ -n "${REGISTRY}" ]; then
        image_name="${REGISTRY}/${image_name}"
    fi
    
    local full_tag="${image_name}:${TAG}"
    
    msg "Building OpenHarmony ${target} rootfs..."
    msg "Image: ${full_tag}"
    
    docker build \
        --build-arg NDK_URL="${NDK_URL}" \
        --target "ohos-${target}" \
        --tag "${full_tag}" \
        ${BUILD_ARGS} \
        -f "${SCRIPT_DIR}/Dockerfile" \
        "${SCRIPT_DIR}" || error "Failed to build ${target}"
    
    msg "Successfully built ${full_tag}"
    
    if [ ${PUSH_IMAGE} -eq 1 ]; then
        msg "Pushing ${full_tag}..."
        docker push "${full_tag}" || error "Failed to push ${full_tag}"
    fi
}

# Main
msg "OpenHarmony rootfs Docker build"
echo "  Targets: ${TARGETS}"
echo "  Registry: ${REGISTRY:-<local>}"
echo "  Tag: ${TAG}"
echo ""

for target in ${TARGETS}; do
    build_image "${target}"
done

msg "Build complete!"
echo ""
echo "Built images:"
docker images --filter "reference=${IMAGE_PREFIX}*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

