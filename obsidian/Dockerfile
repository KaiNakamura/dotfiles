FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for headless Obsidian (Xvfb stack + libs).
RUN apt-get update && apt-get install -y \
    xvfb \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libasound2t64 \
    libgbm1 \
    wget \
    ca-certificates \
    xdg-utils \
    libsecret-1-0 \
    libdrm2 \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Pin Obsidian via build arg. Bump in obsidian/install.sh.
# AppImage-extract path (works); .deb migration deferred.
ARG OBSIDIAN_VERSION=1.12.7
RUN wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage" -O /opt/obsidian.AppImage \
    && chmod +x /opt/obsidian.AppImage \
    && cd /opt && /opt/obsidian.AppImage --appimage-extract \
    && mv /opt/squashfs-root /opt/obsidian \
    && rm /opt/obsidian.AppImage \
    && chmod -R a+rx /opt/obsidian \
    && chmod a+x /opt/obsidian/obsidian

# Match host uid/gid so vault writes round-trip with correct ownership.
ARG OBSIDIAN_UID=1000
ARG OBSIDIAN_GID=1000
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd -g ${OBSIDIAN_GID} obsidian 2>/dev/null || true; \
    useradd -m -s /bin/bash -u ${OBSIDIAN_UID} -o -g ${OBSIDIAN_GID} obsidian

RUN mkdir -p /vault && chown obsidian:obsidian /vault

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

USER obsidian
WORKDIR /home/obsidian

ENTRYPOINT ["/opt/entrypoint.sh"]
