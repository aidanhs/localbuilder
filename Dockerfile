FROM alpine:3.3
RUN apk update && \
	apk add apk add gcc autoconf automake pkgconf libtool musl-dev ncurses-static ncurses-dev git make
WORKDIR /work
# Can't get libevent-static from alpine
RUN git clone https://github.com/libevent/libevent.git && \
	cd libevent && \
	git checkout release-2.0.22-stable && \
	sh autogen.sh && \
	./configure --enable-static --prefix=/usr && \
	make && \
	make install
RUN git clone https://github.com/tmux/tmux.git && \
	cd tmux && \
	git checkout 2.2 && \
	sh autogen.sh && \
	./configure --enable-static --prefix=/home/aidanhs/local && \
	make && \
	make install
