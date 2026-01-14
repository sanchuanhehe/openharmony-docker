# OpenHarmony Rootfs Docker Images

[![Build and Push](https://github.com/sanchuanhehe/openharmony-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/sanchuanhehe/openharmony-docker/actions/workflows/docker-build.yml)

Minimal OpenHarmony rootfs Docker images for multiple architectures, built from official NDK sysroot with statically compiled BusyBox.

## Available Images

| Architecture | Image | Size |
|-------------|-------|------|
| x86_64 | `ghcr.io/sanchuanhehe/openharmony-x86_64` | ~27MB |
| aarch64 (ARM64) | `ghcr.io/sanchuanhehe/openharmony-aarch64` | ~27MB |
| arm (32-bit) | `ghcr.io/sanchuanhehe/openharmony-arm` | ~60MB |

## Quick Start

### Pull Images

```bash
# x86_64 (runs natively on x86_64 hosts)
docker pull ghcr.io/sanchuanhehe/openharmony-x86_64:latest

# aarch64 (requires QEMU on x86_64 hosts)
docker pull ghcr.io/sanchuanhehe/openharmony-aarch64:latest

# arm 32-bit (requires QEMU on x86_64 hosts)
docker pull ghcr.io/sanchuanhehe/openharmony-arm:latest
```

### Run Container

```bash
# Interactive shell
docker run -it --rm ghcr.io/sanchuanhehe/openharmony-x86_64:latest

# Run a command
docker run --rm ghcr.io/sanchuanhehe/openharmony-x86_64:latest busybox --list

# Check libc
docker run --rm ghcr.io/sanchuanhehe/openharmony-x86_64:latest ls -la /lib/
```

### Cross-Architecture (with QEMU)

To run non-native architectures on x86_64 hosts, you need QEMU user-mode emulation:

```bash
# Enable QEMU support (one-time setup)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Run aarch64 container on x86_64 host
docker run -it --rm --platform linux/arm64 ghcr.io/sanchuanhehe/openharmony-aarch64:latest

# Run arm container on x86_64 host
docker run -it --rm --platform linux/arm/v7 ghcr.io/sanchuanhehe/openharmony-arm:latest
```

## Image Contents

Each image contains:

- **OpenHarmony Sysroot** from official NDK
  - `/lib/` - musl libc (`libc.so`, `ld-musl-*.so.1`, `libc.a`, CRT files)
  - `/usr/include/` - C headers for development
- **BusyBox 1.37.0** (statically compiled)
  - `/bin/busybox` - multi-call binary
  - Common command symlinks: `sh`, `ls`, `cat`, `cp`, `mv`, `grep`, `sed`, `awk`, etc.
- **Basic filesystem structure**
  - `/etc/passwd`, `/etc/group`
  - `/tmp`, `/var`, `/proc`, `/sys`, `/dev`

## Use Cases

### As Base Image for OpenHarmony Applications

```dockerfile
FROM ghcr.io/sanchuanhehe/openharmony-x86_64:latest

# Copy your statically compiled application
COPY myapp /bin/myapp

CMD ["/bin/myapp"]
```

### For Cross-Compilation Testing

```dockerfile
FROM ghcr.io/sanchuanhehe/openharmony-aarch64:latest

# The sysroot headers are available at /usr/include
# The libraries are at /lib
```

### In docker-compose

```yaml
version: '3.8'

services:
  ohos-app:
    image: ghcr.io/sanchuanhehe/openharmony-x86_64:latest
    stdin_open: true
    tty: true
```

## Building Locally

### Prerequisites

- Docker with BuildKit support
- For cross-architecture builds: `docker run --privileged multiarch/qemu-user-static --reset -p yes`

### Build Commands

```bash
# Build all architectures
./build-docker.sh all

# Build specific architecture
./build-docker.sh x86_64
./build-docker.sh aarch64
./build-docker.sh arm

# Build with custom tag
TAG=v1.0.0 ./build-docker.sh all

# Push to registry
REGISTRY=ghcr.io/username PUSH=1 ./build-docker.sh all
```

### Using Docker Compose

```bash
# Build all images
docker compose build

# Build specific image
docker compose build ohos-x86_64

# Run specific container
docker compose run --rm ohos-x86_64
```

## NDK Source

The sysroot is extracted from the official OpenHarmony LLVM NDK:
- URL: `https://cidownload.openharmony.cn/version/Daily_Version/LLVM-19/`
- Contains: musl libc, C headers, CRT objects

## License

- OpenHarmony NDK components: Apache 2.0 (OpenHarmony project)
- BusyBox: GPL v2
- Docker configuration: MIT

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
