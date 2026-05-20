FROM ubuntu:24.04 AS meld-build
RUN apt-get update && apt-get install -y git wget imagemagick file binutils desktop-file-utils libglib2.0-bin gcc squashfs-tools patchelf
WORKDIR /work

COPY pkg2appimage.patch .

RUN VSN=19e30b2 && \
    git clone https://github.com/AppImageCommunity/pkg2appimage.git && \
    cd pkg2appimage && \
    git checkout $VSN && \
    git apply /work/pkg2appimage.patch && \
    DOCKER_BUILD=1 bash dogfeeding.sh && \
    ./out/pkg2appimage-*.AppImage --appimage-extract-and-run recipes/Meld.yml

FROM alpine:3.19
RUN apk update && \
    apk add gcc g++ linux-headers autoconf automake pkgconf libtool musl-dev git make file wget && \
    apk add libgcc curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable --default-host x86_64-unknown-linux-musl -y --profile minimal
ENV PATH="/root/.cargo/bin:$PATH"
WORKDIR /work

RUN mkdir -p /home/aidanhs/local/bin /home/aidanhs/local/etc /home/aidanhs/local/etc/systemd

# 2026-05-20 - bgproc/evry
RUN VSN=5e3ebfb && \
    git clone https://github.com/purarue/evry.git && \
    cd evry && \
    git checkout $VSN && \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/evry /home/aidanhs/local/bin/
RUN VSN=9ec68eb && \
    wget -q https://raw.githubusercontent.com/purarue/bgproc/$VSN/bgproc && \
    mv bgproc /home/aidanhs/local/bin/ && \
    chmod +x /home/aidanhs/local/bin/bgproc

# 2026-05-20 - keepassxc
# Really I should build this myself to have a statically linked binary with only extensions I want but
# - an appimage is 'good enough' when fuse is accessible, but...
# - appimagetool does not work with a musl libc, so...
# - using ubuntu needs https://github.com/keepassxreboot/keepassxc/pull/1047, but even if that worked...
# - taming cmake is not fun
RUN VSN=2.7.12 && \
    wget -q https://github.com/keepassxreboot/keepassxc/releases/download/$VSN/KeePassXC-$VSN-x86_64.AppImage && \
    mv KeePassXC-$VSN-x86_64.AppImage /home/aidanhs/local/bin/keepassxc && \
    chmod +x /home/aidanhs/local/bin/keepassxc
RUN /bin/echo -e '#!/bin/bash\nset -o errexit\nset -o nounset\nset -o pipefail\nset -o xtrace' >> /home/aidanhs/local/bin/pass && \
    /bin/echo -e 'keepassxc ~/Sync/keepass.kdbx' >> /home/aidanhs/local/bin/pass && \
    chmod +x /home/aidanhs/local/bin/pass

# 2026-05-20 - syncthing
# TODO: use systemd autostart scripts
RUN VSN=v2.1.0 && \
    wget -q https://github.com/syncthing/syncthing/releases/download/$VSN/syncthing-linux-amd64-$VSN.tar.gz && \
    tar xf syncthing-linux-amd64-$VSN.tar.gz && \
    cp syncthing-linux-amd64-$VSN/etc/linux-systemd/user/syncthing.service /home/aidanhs/local/etc/systemd/ && \
    sed -i 's#/usr/bin/syncthing#/home/aidanhs/local/bin/syncthing#g' /home/aidanhs/local/etc/systemd/syncthing.service && \
    sed -i 's#ExecStart.*#\0 --no-upgrade#g' /home/aidanhs/local/etc/systemd/syncthing.service && \
    cp syncthing-linux-amd64-$VSN/syncthing /home/aidanhs/local/bin/

# 2026-05-20 - zellij
RUN VSN=0.44.3 && \
    wget -q https://github.com/zellij-org/zellij/releases/download/v$VSN/zellij-x86_64-unknown-linux-musl.tar.gz && \
    tar xf zellij-x86_64-unknown-linux-musl.tar.gz && \
    cp zellij /home/aidanhs/local/bin/

# 2026-05-20 - ripgrep
RUN VSN=15.1.0 && \
    wget -q https://github.com/BurntSushi/ripgrep/releases/download/$VSN/ripgrep-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf ripgrep-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp ripgrep-$VSN-x86_64-unknown-linux-musl/rg /home/aidanhs/local/bin/

# 2026-05-20 - exa
RUN VSN=0.23.4 && \
    wget -q https://github.com/eza-community/eza/releases/download/v$VSN/eza_x86_64-unknown-linux-musl.tar.gz && \
    tar xf eza_x86_64-unknown-linux-musl.tar.gz && \
    cp eza /home/aidanhs/local/bin/eza

# 2026-05-20 - fd
RUN VSN=v10.4.2 && \
    wget -q https://github.com/sharkdp/fd/releases/download/$VSN/fd-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf fd-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp fd-$VSN-x86_64-unknown-linux-musl/fd /home/aidanhs/local/bin/

# 2026-05-20 - sccache
RUN VSN=v0.15.0 && \
    wget -q https://github.com/mozilla/sccache/releases/download/$VSN/sccache-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf sccache-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp sccache-$VSN-x86_64-unknown-linux-musl/sccache /home/aidanhs/local/bin/

# 2026-05-20 - nvim
RUN VSN=v0.12.2 && \
    wget -q https://github.com/neovim/neovim/releases/download/$VSN/nvim-linux-x86_64.tar.gz && \
    tar xf nvim-linux-x86_64.tar.gz && \
    cp -r nvim-linux-x86_64/* /home/aidanhs/local/ && \
    cd /home/aidanhs/local/bin/ && ln -s nvim vim

# 2026-05-20 - jq
RUN VSN=1.8.1 && \
    wget -q https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
    mv jq-linux64 /home/aidanhs/local/bin/jq && \
    chmod +x /home/aidanhs/local/bin/jq

# 2026-05-20 - zettlr
RUN VSN=4.5.0 && \
    wget -q https://github.com/Zettlr/Zettlr/releases/download/v$VSN/Zettlr-$VSN-x86_64.AppImage && \
    mv Zettlr-$VSN-x86_64.AppImage /home/aidanhs/local/bin/zettlr && \
    chmod +x /home/aidanhs/local/bin/zettlr

# 2026-05-20 - nushell
RUN VSN=0.112.2 && \
    wget -q https://github.com/nushell/nushell/releases/download/$VSN/nu-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf nu-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp -r nu-$VSN-x86_64-unknown-linux-musl/* /home/aidanhs/local/bin/

COPY --from=meld-build /work/pkg2appimage/out/Meld-*.AppImage /home/aidanhs/local/bin/meld

COPY fuse-overlayfs /home/aidanhs/local/bin/
COPY scripts/boxtool /home/aidanhs/local/bin/
COPY systemd/* /home/aidanhs/local/etc/systemd/
