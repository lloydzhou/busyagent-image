# busyagent image — packaging for the busyagent busybox applet
#
# The busybox+agent source tree is pinned via the git submodule ./busybox
# (update the pointer to release a new image; no remote tarball fetching
# at build time). Build:
#
#   git submodule update --init
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     -t lloydzhou/busyagent:latest -t lloydzhou/busybox:latest --push .
#
# Config policy: self-contained in this file. make defconfig in the image
# build plus four pins (CONFIG_STATIC, LAST_SUPPORTED_WCHAR=1114111,
# UNICODE_WIDE_WCHARS, CONFIG_BUSYAGENT); TC disabled for current alpine
# headers.
#
FROM alpine:3.23 AS build
ARG TARGETARCH

RUN apk add --no-cache gcc make musl-dev linux-headers findutils
WORKDIR /src
COPY busybox/ .

RUN case "$TARGETARCH" in \
        amd64)          export ARCH=x86_64  ;; \
        arm64)          export ARCH=aarch64 ;; \
        arm|arm/v7)     export ARCH=arm     ;; \
        386)            export ARCH=i386    ;; \
        ppc64le)        export ARCH=powerpc ;; \
        s390x)          export ARCH=s390    ;; \
        *)              export ARCH="$(uname -m)" ;; \
    esac; \
    echo "building for ARCH=$ARCH (TARGETARCH=$TARGETARCH)" && \
    make defconfig >/dev/null && \
    sed -i -e '/^CONFIG_STATIC=/d' -e '/^# CONFIG_STATIC is not set/d' .config && \
    echo 'CONFIG_STATIC=y' >> .config && \
    sed -i -e '/^CONFIG_LAST_SUPPORTED_WCHAR=/d' -e '/^# CONFIG_LAST_SUPPORTED_WCHAR is not set/d' .config && \
    echo 'CONFIG_LAST_SUPPORTED_WCHAR=1114111' >> .config && \
    sed -i -e '/^CONFIG_UNICODE_WIDE_WCHARS=/d' -e '/^# CONFIG_UNICODE_WIDE_WCHARS is not set/d' .config && \
    echo 'CONFIG_UNICODE_WIDE_WCHARS=y' >> .config && \
    sed -i -e '/^CONFIG_TC=/d' -e '/^# CONFIG_TC is not set/d' .config && \
    echo '# CONFIG_TC is not set' >> .config && \
    grep -v '^CONFIG_BUSYAGENT=' .config > .t && mv .t .config && \
    echo 'CONFIG_BUSYAGENT=y' >> .config && \
    yes "" | make oldconfig >/dev/null && \
    grep -q '^CONFIG_STATIC=y' .config && \
    grep -q '^CONFIG_LAST_SUPPORTED_WCHAR=1114111$' .config && \
    grep -q '^CONFIG_UNICODE_WIDE_WCHARS=y' .config && \
    grep -q '^CONFIG_BUSYAGENT=y' .config && \
    make ARCH="$ARCH" -j"$(nproc)"

# minimal rootfs: binary + every applet link + /etc basics
RUN mkdir -p out-rootfs/bin out-rootfs/etc out-rootfs/root/.busyagent; \
    cp busybox out-rootfs/bin/; \
    printf 'root:x:0:0:root:/root:/bin/sh\n' > out-rootfs/etc/passwd; \
    printf 'root:x:0:\n' > out-rootfs/etc/group; \
    chroot out-rootfs /bin/busybox --install /bin

FROM scratch
COPY --from=build /src/out-rootfs/ /

ENV BB_AGENT_HOME=/root/.busyagent
VOLUME ["/root/.busyagent"]
WORKDIR /root

CMD ["sh"]
