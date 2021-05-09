FROM alpine:3.13
RUN apk update && \
    apk add gcc g++ linux-headers autoconf automake pkgconf libtool musl-dev git make file wget && \
    apk add libgcc curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable --default-host x86_64-unknown-linux-musl -y --profile minimal
ENV PATH="/root/.cargo/bin:$PATH"
WORKDIR /work

RUN mkdir -p /home/aidanhs/local/bin /home/aidanhs/local/etc /home/aidanhs/local/etc/systemd

# 2021-05-09 - tmux
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
RUN VSN=6.2 && \
    wget -q https://invisible-mirror.net/archives/ncurses/ncurses-$VSN.tar.gz && \
    tar xf ncurses-$VSN.tar.gz && mv ncurses-$VSN ncurses && \
    cd ncurses && \
    ./configure \
        --prefix=/usr --without-profile --without-debug --without-shared --disable-termcap --without-ada --without-tests --without-progs \
        --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo" --with-default-terminfo-dir=/etc/terminfo \
        --disable-db-install --without-manpages && \
    make && \
    make install
# https://github.com/tmux/tmux/issues/2694
#RUN VSN=3.2 && \
#    wget -q https://github.com/tmux/tmux/releases/download/$VSN/tmux-$VSN.tar.gz && \
#    tar xf tmux-$VSN.tar.gz && mv tmux-$VSN tmux && \
#    cd tmux && \
#    ./configure --enable-static --prefix=/home/aidanhs/local && \
#    make && \
#    make install
RUN VSN=f2951bd4 && \
    apk add byacc && \
    git clone https://github.com/tmux/tmux.git tmux && \
    cd tmux && \
    git checkout $VSN && \
    sh autogen.sh && \
    ./configure --enable-static --prefix=/home/aidanhs/local && \
    make && \
    make install

# 2021-05-09 - bgproc/evry
RUN VSN=425bb2f21d7 && \
    git clone https://github.com/seanbreckenridge/evry.git && \
    cd evry && \
    git checkout $VSN && \
    cargo build --release --target x86_64-unknown-linux-musl && \
    cp target/x86_64-unknown-linux-musl/release/evry /home/aidanhs/local/bin/
RUN VSN=4434003d356f && \
    wget -q https://raw.githubusercontent.com/seanbreckenridge/bgproc/$VSN/bgproc && \
    mv bgproc /home/aidanhs/local/bin/ && \
    chmod +x /home/aidanhs/local/bin/bgproc

# 2020-06-20 - blackbox
RUN git clone https://github.com/StackExchange/blackbox.git && \
    cd blackbox && \
    git checkout v1.20200429 && \
    cp -r bin/* /home/aidanhs/local/bin/ && \
    rm /home/aidanhs/local/bin/Makefile

# 2021-04-17 - keepassxc
# Really I should build this myself to have a statically linked binary with only extensions I want but
# - an appimage is 'good enough' when fuse is accessible, but...
# - appimagetool does not work with a musl libc, but...
# - using ubuntu needs https://github.com/keepassxreboot/keepassxc/pull/1047, but even if that worked...
# - taming cmake is not fun
RUN VSN=2.6.4 && \
    wget -q https://github.com/keepassxreboot/keepassxc/releases/download/$VSN/KeePassXC-$VSN-x86_64.AppImage && \
    mv KeePassXC-$VSN-x86_64.AppImage /home/aidanhs/local/bin/keepassxc && \
    chmod +x /home/aidanhs/local/bin/keepassxc
RUN /bin/echo -e '#!/bin/bash\nset -o errexit\nset -o nounset\nset -o pipefail\nset -o xtrace' >> /home/aidanhs/local/bin/pass && \
    /bin/echo -e 'keepassxc ~/Sync/keepass.kdbx' >> /home/aidanhs/local/bin/pass && \
    chmod +x /home/aidanhs/local/bin/pass

# 2021-04-17 - syncthing
# TODO: use systemd autostart scripts
RUN VSN=v1.15.1 && \
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

# 2021-04-17 - sccache
RUN VSN=v0.2.15 && \
    wget -q https://github.com/mozilla/sccache/releases/download/$VSN/sccache-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf sccache-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp sccache-$VSN-x86_64-unknown-linux-musl/sccache /home/aidanhs/local/bin/

# 2021-04-17 - nvim
# 0.5.0 nightly as of date above
COPY nvim-linux64.tar.gz .
RUN true && \
    tar xf nvim-linux64.tar.gz && \
    cp -r nvim-linux64/* /home/aidanhs/local/ && \
    cd /home/aidanhs/local/bin/ && ln -s nvim vim
#RUN VSN=v0.4.3 && \
#    wget -q https://github.com/neovim/neovim/releases/download/$VSN/nvim-linux64.tar.gz && \
#    tar xf nvim-linux64.tar.gz && \
#    cp -r nvim-linux64/* /home/aidanhs/local/ && \
#    cd /home/aidanhs/local/bin/ && ln -s nvim vim

# ?-?-? - rust-analyzer
RUN VSN=2020-09-21 && \
    wget -q https://github.com/rust-analyzer/rust-analyzer/releases/download/$VSN/rust-analyzer-linux.gz && \
    gunzip rust-analyzer-linux.gz && \
    mv rust-analyzer-linux /home/aidanhs/local/bin/rust-analyzer && \
    chmod +x /home/aidanhs/local/bin/rust-analyzer

# 2021-04-17 - zettlr
RUN VSN=1.8.7 && \
    wget -q https://github.com/Zettlr/Zettlr/releases/download/v$VSN/Zettlr-$VSN-x86_64.AppImage && \
    mv Zettlr-$VSN-x86_64.AppImage /home/aidanhs/local/bin/zettlr && \
    chmod +x /home/aidanhs/local/bin/zettlr

COPY fuse-overlayfs /home/aidanhs/local/bin/
COPY scripts/boxtool /home/aidanhs/local/bin/
COPY systemd/* /home/aidanhs/local/etc/systemd/
