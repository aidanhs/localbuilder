FROM alpine:3.3
RUN apk update && \
	apk add gcc autoconf automake pkgconf libtool musl-dev git make
WORKDIR /work
# Can't get libevent-static from alpine
RUN git clone https://github.com/libevent/libevent.git && \
	cd libevent && \
	git checkout release-2.0.22-stable && \
	sh autogen.sh && \
	./configure --enable-static --prefix=/usr && \
	make && \
	make install
ADD ncurses-6.0.tar.gz /work/
# First line of configure flags are stolen from debian/rules in the ubuntu src tar,
# second line is mine. The crucial flag is with-terminfo-dirs - the one for alpine
# doesn't include /lib/terminfo so misses some fundamental terminals on ubuntu.
RUN apk del ncurses-static ncurses-dev && ln -s ncurses-6.0 ncurses && \
	cd ncurses && \
	./configure \
		--prefix=/usr --without-profile --without-debug --without-shared --disable-termcap --without-ada --without-tests --without-progs --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo" --with-default-terminfo-dir=/etc/terminfo \
		--disable-db-install --without-manpages && \
	make && \
	make install
RUN git clone https://github.com/tmux/tmux.git && \
	cd tmux && \
	git checkout 2.2 && \
	sh autogen.sh && \
	./configure --enable-static --prefix=/home/aidanhs/local && \
	make && \
	make install
