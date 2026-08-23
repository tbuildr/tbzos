# tbzos — single Containerfile, two variants selected by build args:
#
#   AMD:    --build-arg BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome \
#           --build-arg GPU_VENDOR=amd
#   NVIDIA: --build-arg BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome-nvidia-open \
#           --build-arg GPU_VENDOR=nvidia
#
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome
ARG BASE_TAG=stable
FROM ${BASE_IMAGE}:${BASE_TAG}

# Redeclared post-FROM: ARGs above FROM don't carry into the build stage.
ARG GPU_VENDOR=amd

# dnf5 cache
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
 dnf5 config-manager setopt keepcache=1

# Copy repo files to /tmp
COPY build_files/ /tmp/tbzos-build_files/
COPY config/ /tmp/tbzos-config/
COPY assets/ /tmp/tbzos-assets/
COPY --chmod=0644 ./cosign.pub /tmp/tbzos.pub

RUN --mount=type=cache,dst=/var/cache/libdnf5 \
    /tmp/tbzos-build_files/00-packages.sh "${GPU_VENDOR}"

RUN /tmp/tbzos-build_files/01-config-files.sh

RUN /tmp/tbzos-build_files/02-services.sh

RUN /tmp/tbzos-build_files/03-cosign.sh

RUN bootc container lint
