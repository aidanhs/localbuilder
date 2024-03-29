FROM alpine:3.15
RUN apk update && \
    apk add gcc g++ linux-headers autoconf automake pkgconf libtool musl-dev git make file wget && \
    apk add libgcc curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable --default-host x86_64-unknown-linux-musl -y --profile minimal
ENV PATH="/root/.cargo/bin:$PATH"
WORKDIR /work

RUN mkdir -p /home/aidanhs/local/bin /home/aidanhs/local/etc /home/aidanhs/local/etc/systemd

# 2022-06-03 - tmux
# Can't get libevent-static from alpine
RUN VSN=2.1.12-stable && \
    wget -q https://github.com/libevent/libevent/releases/download/release-$VSN/libevent-$VSN.tar.gz && \
    tar -xf libevent-$VSN.tar.gz && mv libevent-$VSN libevent && \
    cd libevent && \
    ./configure --enable-static --prefix=/usr --disable-openssl && \
    make && \
    make install
# First line of configure flags are stolen from debian/rules in the ubuntu src tar,
# second line is mine. Crucial flag is with-terminfo-dirs - alpine ncurses-static
# doesn't include /lib/terminfo so misses some fundamental terminals on ubuntu.
RUN VSN=6.3 && \
    wget -q https://invisible-mirror.net/archives/ncurses/ncurses-$VSN.tar.gz && \
    tar xf ncurses-$VSN.tar.gz && mv ncurses-$VSN ncurses && \
    cd ncurses && \
    ./configure \
        --prefix=/usr --without-profile --without-debug --without-shared --disable-termcap --without-ada --without-tests --without-progs \
        --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo" --with-default-terminfo-dir=/etc/terminfo \
        --disable-db-install --without-manpages && \
    make && \
    make install
RUN VSN=3.3 && \
    wget -q https://github.com/tmux/tmux/releases/download/$VSN/tmux-$VSN.tar.gz && \
    tar xf tmux-$VSN.tar.gz && mv tmux-$VSN tmux && \
    cd tmux && \
    ./configure --enable-static --prefix=/home/aidanhs/local && \
    make && \
    make install

# 2022-06-03 - bgproc/evry
RUN VSN=db2fc09 && \
    git clone https://github.com/seanbreckenridge/evry.git && \
    cd evry && \
    git checkout $VSN && \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/evry /home/aidanhs/local/bin/
RUN VSN=7da55a6 && \
    wget -q https://raw.githubusercontent.com/seanbreckenridge/bgproc/$VSN/bgproc && \
    mv bgproc /home/aidanhs/local/bin/ && \
    chmod +x /home/aidanhs/local/bin/bgproc

# 2020-06-20 - blackbox
RUN git clone https://github.com/StackExchange/blackbox.git && \
    cd blackbox && \
    git checkout v1.20200429 && \
    cp -r bin/* /home/aidanhs/local/bin/ && \
    rm /home/aidanhs/local/bin/Makefile

# 2021-12-28 - keepassxc
# Really I should build this myself to have a statically linked binary with only extensions I want but
# - an appimage is 'good enough' when fuse is accessible, but...
# - appimagetool does not work with a musl libc, but...
# - using ubuntu needs https://github.com/keepassxreboot/keepassxc/pull/1047, but even if that worked...
# - taming cmake is not fun
RUN VSN=2.7.1 && \
    wget -q https://github.com/keepassxreboot/keepassxc/releases/download/$VSN/KeePassXC-$VSN-x86_64.AppImage && \
    mv KeePassXC-$VSN-x86_64.AppImage /home/aidanhs/local/bin/keepassxc && \
    chmod +x /home/aidanhs/local/bin/keepassxc
RUN /bin/echo -e '#!/bin/bash\nset -o errexit\nset -o nounset\nset -o pipefail\nset -o xtrace' >> /home/aidanhs/local/bin/pass && \
    /bin/echo -e 'keepassxc ~/Sync/keepass.kdbx' >> /home/aidanhs/local/bin/pass && \
    chmod +x /home/aidanhs/local/bin/pass

# 2022-06-03 - syncthing
# TODO: use systemd autostart scripts
RUN VSN=v1.20.1 && \
    wget -q https://github.com/syncthing/syncthing/releases/download/$VSN/syncthing-linux-amd64-$VSN.tar.gz && \
    tar xf syncthing-linux-amd64-$VSN.tar.gz && \
    cp syncthing-linux-amd64-$VSN/etc/linux-systemd/user/syncthing.service /home/aidanhs/local/etc/systemd/ && \
    sed -i 's#/usr/bin/syncthing#/home/aidanhs/local/bin/syncthing#g' /home/aidanhs/local/etc/systemd/syncthing.service && \
    sed -i 's#ExecStart.*#\0 --no-upgrade#g' /home/aidanhs/local/etc/systemd/syncthing.service && \
    cp syncthing-linux-amd64-$VSN/syncthing /home/aidanhs/local/bin/

# ?-?-? - ripgrep
RUN VSN=12.0.1 && \
    wget -q https://github.com/BurntSushi/ripgrep/releases/download/$VSN/ripgrep-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf ripgrep-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp ripgrep-$VSN-x86_64-unknown-linux-musl/rg /home/aidanhs/local/bin/

# ?-?-? - exa
RUN VSN=0.9.0 && \
    wget -q https://github.com/ogham/exa/releases/download/v$VSN/exa-linux-x86_64-$VSN.zip && \
    unzip exa-linux-x86_64-$VSN.zip && \
    cp exa-linux-x86_64 /home/aidanhs/local/bin/exa

# ?-?-? - fd
RUN VSN=v7.5.0 && \
    wget -q https://github.com/sharkdp/fd/releases/download/$VSN/fd-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf fd-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp fd-$VSN-x86_64-unknown-linux-musl/fd /home/aidanhs/local/bin/

# 2020-04-30 - bat
RUN VSN=v0.15.0 && \
    wget -q https://github.com/sharkdp/bat/releases/download/$VSN/bat-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf bat-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp bat-$VSN-x86_64-unknown-linux-musl/bat /home/aidanhs/local/bin/

# 2023-04-22 - sccache
RUN VSN=v0.4.2 && \
    wget -q https://github.com/mozilla/sccache/releases/download/$VSN/sccache-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf sccache-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp sccache-$VSN-x86_64-unknown-linux-musl/sccache /home/aidanhs/local/bin/

# 2022-06-03 - nvim
RUN VSN=v0.7.0 && \
    wget -q https://github.com/neovim/neovim/releases/download/$VSN/nvim-linux64.tar.gz && \
    tar xf nvim-linux64.tar.gz && \
    cp -r nvim-linux64/* /home/aidanhs/local/ && \
    cd /home/aidanhs/local/bin/ && ln -s nvim vim

# 2022-06-03 - rust-analyzer
RUN VSN=2022-05-30 && \
    wget -q https://github.com/rust-analyzer/rust-analyzer/releases/download/$VSN/rust-analyzer-x86_64-unknown-linux-musl.gz && \
    gunzip rust-analyzer-x86_64-unknown-linux-musl.gz && \
    mv rust-analyzer-x86_64-unknown-linux-musl /home/aidanhs/local/bin/rust-analyzer && \
    chmod +x /home/aidanhs/local/bin/rust-analyzer

# 2021-12-28 - jq
RUN VSN=1.6 && \
    wget -q https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
    mv jq-linux64 /home/aidanhs/local/bin/jq && \
    chmod +x /home/aidanhs/local/bin/jq

# 2022-06-03 - zettlr
RUN VSN=2.2.6 && \
    wget -q https://github.com/Zettlr/Zettlr/releases/download/v$VSN/Zettlr-$VSN-x86_64.AppImage && \
    mv Zettlr-$VSN-x86_64.AppImage /home/aidanhs/local/bin/zettlr && \
    chmod +x /home/aidanhs/local/bin/zettlr

# 2023-04-28 - zellij
RUN VSN=0.36.0 && \
    wget -q https://github.com/zellij-org/zellij/releases/download/v$VSN/zellij-x86_64-unknown-linux-musl.tar.gz && \
    tar xf zellij-x86_64-unknown-linux-musl.tar.gz && \
    cp zellij /home/aidanhs/local/bin/

# 2023-04-28 - helix
RUN VSN=23.03 && \
    wget -q https://github.com/helix-editor/helix/releases/download/$VSN/helix-$VSN-x86_64-linux.tar.xz && \
    tar xf helix-$VSN-x86_64-linux.tar.xz && \
    cp -r helix-23.03-x86_64-linux/* /home/aidanhs/local/bin/

COPY fuse-overlayfs /home/aidanhs/local/bin/
COPY scripts/boxtool /home/aidanhs/local/bin/
COPY systemd/* /home/aidanhs/local/etc/systemd/
