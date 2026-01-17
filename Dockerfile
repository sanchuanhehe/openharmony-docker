# Dockerfile for building OpenHarmony rootfs images
# Downloads NDK and extracts sysroot, adds busybox for basic commands

# ============================================================================
# Stage 1: NDK Download and Sysroot Extraction
# ============================================================================
FROM ubuntu:22.04 AS ndk-extractor

ARG NDK_URL=https://cidownload.openharmony.cn/version/Daily_Version/LLVM-19/20260114_061434/version-Daily_Version-LLVM-19-20260114_061434-LLVM-19.tar.gz

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /extract

# Download NDK and extract sysroot
RUN echo "Downloading NDK..." && \
    wget -q -O ndk-llvm.tar.gz "${NDK_URL}" && \
    echo "Extracting ohos-sysroot.tar.gz from NDK..." && \
    tar -xzf ndk-llvm.tar.gz ohos-sysroot.tar.gz && \
    echo "Extracting sysroot contents..." && \
    tar -xzf ohos-sysroot.tar.gz && \
    rm -f ndk-llvm.tar.gz ohos-sysroot.tar.gz && \
    echo "Sysroot extraction complete" && \
    ls -la sysroot/


# ============================================================================
# Stage 2: Build static busybox for each architecture
# ============================================================================

# Build x86_64 busybox
FROM ubuntu:22.04 AS busybox-x86_64

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates build-essential bzip2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
ARG BUSYBOX_VERSION=1.37.0
RUN wget -O busybox.tar.bz2 "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" && \
    tar -xjf busybox.tar.bz2 && mv busybox-${BUSYBOX_VERSION} busybox-src

RUN cd busybox-src && \
    make defconfig && \
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
    make -j$(nproc) && \
    mkdir -p /out && cp busybox /out/

# Build aarch64 busybox
FROM ubuntu:22.04 AS busybox-aarch64

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates build-essential bzip2 \
    gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
ARG BUSYBOX_VERSION=1.37.0
RUN wget -O busybox.tar.bz2 "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" && \
    tar -xjf busybox.tar.bz2 && mv busybox-${BUSYBOX_VERSION} busybox-src

RUN cd busybox-src && \
    make defconfig CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 && \
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
    sed -i 's/CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' .config && \
    sed -i 's/CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' .config && \
    make -j$(nproc) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 && \
    mkdir -p /out && cp busybox /out/

# Build arm busybox
FROM ubuntu:22.04 AS busybox-arm

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates build-essential bzip2 \
    gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
ARG BUSYBOX_VERSION=1.37.0
RUN wget -O busybox.tar.bz2 "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" && \
    tar -xjf busybox.tar.bz2 && mv busybox-${BUSYBOX_VERSION} busybox-src

RUN cd busybox-src && \
    make defconfig CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm && \
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
    sed -i 's/CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' .config && \
    sed -i 's/CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' .config && \
    make -j$(nproc) CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm && \
    mkdir -p /out && cp busybox /out/


# ============================================================================
# Stage 3: OpenHarmony x86_64 rootfs
# ============================================================================
FROM ubuntu:22.04 AS x86_64-builder
COPY --from=ndk-extractor /extract/sysroot/x86_64-linux-ohos/usr/lib/ /rootfs/usr/lib/
COPY --from=ndk-extractor /extract/sysroot/x86_64-linux-ohos/usr/include/ /rootfs/usr/include/
COPY --from=busybox-x86_64 /out/busybox /rootfs/usr/bin/busybox
# Use usr-merge layout: /bin, /sbin, /lib, /lib64 are symlinks to /usr/*
RUN mkdir -p /rootfs/usr/bin /rootfs/usr/sbin /rootfs/usr/lib \
             /rootfs/tmp /rootfs/var /rootfs/etc /rootfs/proc /rootfs/sys /rootfs/dev && \
    ln -sf usr/bin /rootfs/bin && \
    ln -sf usr/sbin /rootfs/sbin && \
    ln -sf usr/lib /rootfs/lib && \
    ln -sf usr/lib /rootfs/lib64 && \
    chmod +x /rootfs/usr/bin/busybox && \
    cd /rootfs/usr/bin && \
    for cmd in sh ash cat ls cp mv rm mkdir rmdir echo pwd sleep test expr head tail grep sed awk sort uniq wc cut tr date env printenv id whoami basename dirname find xargs du df free top; do \
        ln -sf busybox $cmd; \
    done && \
    echo "root:x:0:0:root:/:/bin/sh" > /rootfs/etc/passwd && \
    echo "root:x:0:" > /rootfs/etc/group

FROM scratch AS ohos-x86_64
COPY --from=x86_64-builder /rootfs/ /

ENV PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LD_LIBRARY_PATH=/lib

LABEL org.opencontainers.image.title="OpenHarmony x86_64" \
      org.opencontainers.image.description="OpenHarmony rootfs for x86_64 with busybox" \
      org.opencontainers.image.vendor="OpenHarmony"

CMD ["/bin/sh"]


# ============================================================================
# Stage 4: OpenHarmony aarch64 rootfs
# ============================================================================
FROM ubuntu:22.04 AS aarch64-builder
COPY --from=ndk-extractor /extract/sysroot/aarch64-linux-ohos/usr/lib/ /rootfs/usr/lib/
COPY --from=ndk-extractor /extract/sysroot/aarch64-linux-ohos/usr/include/ /rootfs/usr/include/
COPY --from=busybox-aarch64 /out/busybox /rootfs/usr/bin/busybox
# Use usr-merge layout: /bin, /sbin, /lib are symlinks to /usr/*
RUN mkdir -p /rootfs/usr/bin /rootfs/usr/sbin /rootfs/usr/lib \
             /rootfs/tmp /rootfs/var /rootfs/etc /rootfs/proc /rootfs/sys /rootfs/dev && \
    ln -sf usr/bin /rootfs/bin && \
    ln -sf usr/sbin /rootfs/sbin && \
    ln -sf usr/lib /rootfs/lib && \
    chmod +x /rootfs/usr/bin/busybox && \
    cd /rootfs/usr/bin && \
    for cmd in sh ash cat ls cp mv rm mkdir rmdir echo pwd sleep test expr head tail grep sed awk sort uniq wc cut tr date env printenv id whoami basename dirname find xargs du df free top; do \
        ln -sf busybox $cmd; \
    done && \
    echo "root:x:0:0:root:/:/bin/sh" > /rootfs/etc/passwd && \
    echo "root:x:0:" > /rootfs/etc/group

FROM scratch AS ohos-aarch64
COPY --from=aarch64-builder /rootfs/ /

ENV PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LD_LIBRARY_PATH=/lib

LABEL org.opencontainers.image.title="OpenHarmony aarch64" \
      org.opencontainers.image.description="OpenHarmony rootfs for aarch64 with busybox" \
      org.opencontainers.image.vendor="OpenHarmony"

CMD ["/bin/sh"]


# ============================================================================
# Stage 5: OpenHarmony ARM (32-bit) rootfs
# ============================================================================
FROM ubuntu:22.04 AS arm-builder
COPY --from=ndk-extractor /extract/sysroot/arm-linux-ohos/usr/lib/ /rootfs/usr/lib/
COPY --from=ndk-extractor /extract/sysroot/arm-linux-ohos/usr/include/ /rootfs/usr/include/
COPY --from=busybox-arm /out/busybox /rootfs/usr/bin/busybox
# Use usr-merge layout: /bin, /sbin, /lib are symlinks to /usr/*
RUN mkdir -p /rootfs/usr/bin /rootfs/usr/sbin /rootfs/usr/lib \
             /rootfs/tmp /rootfs/var /rootfs/etc /rootfs/proc /rootfs/sys /rootfs/dev && \
    ln -sf usr/bin /rootfs/bin && \
    ln -sf usr/sbin /rootfs/sbin && \
    ln -sf usr/lib /rootfs/lib && \
    chmod +x /rootfs/usr/bin/busybox && \
    cd /rootfs/usr/bin && \
    for cmd in sh ash cat ls cp mv rm mkdir rmdir echo pwd sleep test expr head tail grep sed awk sort uniq wc cut tr date env printenv id whoami basename dirname find xargs du df free top; do \
        ln -sf busybox $cmd; \
    done && \
    echo "root:x:0:0:root:/:/bin/sh" > /rootfs/etc/passwd && \
    echo "root:x:0:" > /rootfs/etc/group

FROM scratch AS ohos-arm
COPY --from=arm-builder /rootfs/ /

ENV PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LD_LIBRARY_PATH=/lib

LABEL org.opencontainers.image.title="OpenHarmony ARM" \
      org.opencontainers.image.description="OpenHarmony rootfs for ARM 32-bit with busybox" \
      org.opencontainers.image.vendor="OpenHarmony"

CMD ["/bin/sh"]


