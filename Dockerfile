FROM alpine:3.6
RUN apk update && \
    apk add gcc g++ linux-headers autoconf automake pkgconf libtool musl-dev git make file wget
WORKDIR /work

RUN mkdir -p /home/aidanhs/local/bin /home/aidanhs/local/etc

# Can't get libevent-static from alpine
RUN wget -q https://github.com/libevent/libevent/releases/download/release-2.1.11-stable/libevent-2.1.11-stable.tar.gz && \
    tar -xf libevent-2.1.11-stable.tar.gz && mv libevent-2.1.11-stable libevent && \
    cd libevent && \
    ./configure --enable-static --prefix=/usr && \
    make && \
    make install
# First line of configure flags are stolen from debian/rules in the ubuntu src tar,
# second line is mine. Crucial flag is with-terminfo-dirs - alpine ncurses-static
# doesn't include /lib/terminfo so misses some fundamental terminals on ubuntu.
RUN wget -q https://invisible-mirror.net/archives/ncurses/ncurses-6.1.tar.gz && \
    tar xf ncurses-6.1.tar.gz && mv ncurses-6.1 ncurses && \
    cd ncurses && \
    ./configure \
        --prefix=/usr --without-profile --without-debug --without-shared --disable-termcap --without-ada --without-tests --without-progs \
        --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo" --with-default-terminfo-dir=/etc/terminfo \
        --disable-db-install --without-manpages && \
    make && \
    make install
RUN wget -q https://github.com/tmux/tmux/releases/download/3.0a/tmux-3.0a.tar.gz && \
    tar xf tmux-3.0a.tar.gz && mv tmux-3.0a tmux && \
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
RUN wget -q https://github.com/keepassxreboot/keepassxc/releases/download/2.5.1/KeePassXC-2.5.1-x86_64.AppImage && \
    mv KeePassXC-2.5.1-x86_64.AppImage /home/aidanhs/local/bin/keepassxc && \
    chmod +x /home/aidanhs/local/bin/keepassxc
RUN /bin/echo -e '#!/bin/bash\nset -o errexit\nset -o nounset\nset -o pipefail\nset -o xtrace' >> /home/aidanhs/local/bin/pass && \
    /bin/echo -e 'keepassxc ~/Sync/keepass.kdbx' >> /home/aidanhs/local/bin/pass && \
    chmod +x /home/aidanhs/local/bin/pass

# TODO: use systemd autostart scripts
RUN wget -q https://github.com/syncthing/syncthing/releases/download/v1.3.2/syncthing-linux-amd64-v1.3.2.tar.gz && \
    tar xf syncthing-linux-amd64-v1.3.2.tar.gz && \
    cp syncthing-linux-amd64-v1.3.2/etc/linux-desktop/syncthing-start.desktop /home/aidanhs/local/etc/ && \
    sed -i 's#/usr/bin/syncthing#/home/aidanhs/local/bin/syncthing#g' /home/aidanhs/local/etc/syncthing-start.desktop && \
    cp syncthing-linux-amd64-v1.3.2/syncthing /home/aidanhs/local/bin/

COPY scripts/boxtool /home/aidanhs/local/bin/

RUN tar -c -f /work/local.tar -C /home/aidanhs local
