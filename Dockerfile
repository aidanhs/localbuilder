FROM alpine:3.11
RUN apk update && \
    apk add gcc g++ linux-headers autoconf automake pkgconf libtool musl-dev git make file wget
WORKDIR /work

RUN mkdir -p /home/aidanhs/local/bin /home/aidanhs/local/etc

# Can't get libevent-static from alpine
RUN VSN=2.1.11-stable && \
    wget -q https://github.com/libevent/libevent/releases/download/release-$VSN/libevent-$VSN.tar.gz && \
    tar -xf libevent-$VSN.tar.gz && mv libevent-$VSN libevent && \
    cd libevent && \
    ./configure --enable-static --prefix=/usr && \
    make && \
    make install
# First line of configure flags are stolen from debian/rules in the ubuntu src tar,
# second line is mine. Crucial flag is with-terminfo-dirs - alpine ncurses-static
# doesn't include /lib/terminfo so misses some fundamental terminals on ubuntu.
RUN VSN=6.1 && \
    wget -q https://invisible-mirror.net/archives/ncurses/ncurses-$VSN.tar.gz && \
    tar xf ncurses-$VSN.tar.gz && mv ncurses-$VSN ncurses && \
    cd ncurses && \
    ./configure \
        --prefix=/usr --without-profile --without-debug --without-shared --disable-termcap --without-ada --without-tests --without-progs \
        --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo" --with-default-terminfo-dir=/etc/terminfo \
        --disable-db-install --without-manpages && \
    make && \
    make install
RUN VSN=3.0a && \
    wget -q https://github.com/tmux/tmux/releases/download/3.0a/tmux-3.0a.tar.gz && \
    tar xf tmux-$VSN.tar.gz && mv tmux-$VSN tmux && \
    cd tmux && \
    ./configure --enable-static --prefix=/home/aidanhs/local && \
    make && \
    make install

RUN git clone https://github.com/StackExchange/blackbox.git && \
    cd blackbox && \
    git checkout v1.20170611 && \
    cp -r bin/* /home/aidanhs/local/bin/ && \
    rm /home/aidanhs/local/bin/Makefile

# Really I should build this myself to have a statically linked binary with only extensions I want but
# - an appimage is 'good enough' when fuse is accessible, but...
# - appimagetool does not work with a musl libc, but...
# - using ubuntu needs https://github.com/keepassxreboot/keepassxc/pull/1047, but even if that worked...
# - taming cmake is not fun
RUN VSN=2.5.4 && \
    wget -q https://github.com/keepassxreboot/keepassxc/releases/download/$VSN/KeePassXC-$VSN-x86_64.AppImage && \
    mv KeePassXC-$VSN-x86_64.AppImage /home/aidanhs/local/bin/keepassxc && \
    chmod +x /home/aidanhs/local/bin/keepassxc
RUN /bin/echo -e '#!/bin/bash\nset -o errexit\nset -o nounset\nset -o pipefail\nset -o xtrace' >> /home/aidanhs/local/bin/pass && \
    /bin/echo -e 'keepassxc ~/Sync/keepass.kdbx' >> /home/aidanhs/local/bin/pass && \
    chmod +x /home/aidanhs/local/bin/pass

# TODO: use systemd autostart scripts
RUN VSN=v1.4.2 && \
    wget -q https://github.com/syncthing/syncthing/releases/download/$VSN/syncthing-linux-amd64-$VSN.tar.gz && \
    tar xf syncthing-linux-amd64-$VSN.tar.gz && \
    cp syncthing-linux-amd64-$VSN/etc/linux-desktop/syncthing-start.desktop /home/aidanhs/local/etc/ && \
    sed -i 's#/usr/bin/syncthing#/home/aidanhs/local/bin/syncthing#g' /home/aidanhs/local/etc/syncthing-start.desktop && \
    cp syncthing-linux-amd64-$VSN/syncthing /home/aidanhs/local/bin/

COPY fuse-overlayfs scripts/boxtool /home/aidanhs/local/bin/

RUN VSN=12.0.1 && \
    wget -q https://github.com/BurntSushi/ripgrep/releases/download/$VSN/ripgrep-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf ripgrep-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp ripgrep-$VSN-x86_64-unknown-linux-musl/rg /home/aidanhs/local/bin/

RUN VSN=0.9.0 && \
    wget -q https://github.com/ogham/exa/releases/download/v$VSN/exa-linux-x86_64-$VSN.zip && \
    unzip exa-linux-x86_64-$VSN.zip && \
    cp exa-linux-x86_64 /home/aidanhs/local/bin/exa

RUN VSN=v7.5.0 && \
    wget -q https://github.com/sharkdp/fd/releases/download/$VSN/fd-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf fd-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp fd-$VSN-x86_64-unknown-linux-musl/fd /home/aidanhs/local/bin/

RUN VSN=v0.15.0 && \
    wget -q https://github.com/sharkdp/bat/releases/download/$VSN/bat-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    tar xf bat-$VSN-x86_64-unknown-linux-musl.tar.gz && \
    cp bat-$VSN-x86_64-unknown-linux-musl/bat /home/aidanhs/local/bin/

RUN tar -c -f /work/local.tar -C /home/aidanhs local
