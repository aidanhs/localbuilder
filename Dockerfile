FROM alpine:3.3
RUN apk update && \
	apk add gcc g++ linux-headers autoconf automake pkgconf libtool musl-dev git make file
WORKDIR /work

# Can't get libevent-static from alpine
RUN git clone https://github.com/libevent/libevent.git && \
	cd libevent && \
	git checkout release-2.0.22-stable && \
	sh autogen.sh && \
	./configure --enable-static --prefix=/usr && \
	make && \
	make install
# http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz
ADD ncurses-6.0.tar.gz /work/
# First line of configure flags are stolen from debian/rules in the ubuntu src tar,
# second line is mine. Crucial flag is with-terminfo-dirs - alpine ncurses-static
# doesn't include /lib/terminfo so misses some fundamental terminals on ubuntu.
RUN ln -s ncurses-6.0 ncurses && \
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

RUN git clone https://github.com/StackExchange/blackbox.git && \
    cd blackbox && \
    git checkout v1.20160122 && \
    cp -r bin/* /home/aidanhs/local/bin/ && \
    rm /home/aidanhs/local/bin/Makefile

# Jesus wept, Mono is an absolute pig to get fully functional with musl.
# Instead, the Mono stuff is done in a glibc-based container, see the makefile.
#
## This seemed too much like hard work, and I'm a bit leery about a
## poorly-tested security-critical program in C++
##git clone https://code.qt.io/qt/qt5.git
##cd qt5
##git checkout 5.5
##perl init-repository --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine,-qt3d,-qtwayland,-qtwinextras,-qtcanvas3d
##./configure -opensource -nomake examples -nomake tests -prefix $(pwd)/dist -confirm-license -static -no-qml-debug -qt-zlib -no-gif -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz -no-openssl -no-libproxy -qt-pcre -qt-xcb -qt-xkbcommon-x11 -no-xkbcommon-evdev -no-xinput2 -no-xcb-xlib -no-glib -no-pulseaudio -no-alsa -no-gtkstyle -no-nis -no-cups -no-iconv -no-evdev -no-tslib -no-icu -no-fontconfig -no-dbus -no-xcb -no-eglfs -no-directfb -no-linuxfb -no-kms -no-opengl -no-libinput -no-gstreamer
##
### apk add cmake g++
### apk add qt5-qtbase qt5-qtbase-dev qt5-qttools qt5-qttools-dev libgcrypt libgcrypt-dev
### CMAKE_BUILD_TYPE = release|relwithdebinfo|minsizerel
### The specific commit chosen contains qt5, see
### https://github.com/keepassx/keepassx/pull/81
##RUN git clone https://github.com/keepassx/keepassx.git && \
##    cd keepassx && \
##    git checkout 4eea7c829754b263be142e09993147763c8a8585 && \
##    mkdir build && \
##    cd build && \
##    cmake -DWITH_TESTS=no -DCMAKE_INSTALL_PREFIX=/home/aidanhs/local ..
#
#RUN wget http://download.mono-project.com/sources/mono/mono-4.4.0.148.tar.bz2
## Misc notes:
##  - Recommended configure flags for musl: --disable-boehm --without-sigaltstack
##  - https://github.com/beagleboard/buildroot/blob/master/package/mono/mono-002-support-uclibc-musl.patch
##  - http://www.mono-project.com/archived/guiderunning_mono_applications/#bundles
#
## Patch needs to address the following:
## 1. mono assumes you're using glibc, and so applies totally incorrect compat
##    workarounds by manually including specific linux headers - undo this idiocy
##    (http://stackoverflow.com/questions/14533191/c-interfaces-and-implementations-david-hanson-code-install)
## 2. unit tests are broken because of something to do with the fancy mono gc, just
##    disable unit tests (https://bugzilla.xamarin.com/show_bug.cgi?id=32016)
#COPY mono.patch /work/
#
## ATTEMPT 1: getting this working would mean a dynamically linked mono to musl. It
## turns out even this is hard because you have to build libgdiplus, and therefore
## freetype and cairo etc, yourself, as well as then copying the libraries out of
## the container and setting up the necessary paths to use them. Also note the patch
## from beagleboard above - it hints how to fix the mapping from Mono runtime to native
## libraries because Mono always assumes glibc and the glibc library name.
#RUN tar xjf mono-4.4.0.148.tar.bz2 && \
#    cd mono-4.4.0 && \
#    patch -p1 <../mono.patch && \
#    ./configure --prefix=/home/aidanhs/local --enable-shared --enable-static --enable-libraries --enable-mcs-build --enable-system-aot --with-static_mono=yes --with-shared_mono=no --with-sgen=yes --enable-nls=no --enable-minimal=profiler --with-profile4=no --with-mcs-docs=no --with-moonlight=no && \
#    make LDFLAGS="-Wl,--strip-debug" && \
#    make install
#
## ATTEMPT 2: this is where attempt 1 should progress to, and is what I was working
## on before lowering my expectations to attempt 1 - a properly statically linked
## mono. On reflection, I'm not even sure if this is possible because Mono likes to
## load a bunch of .so files on demand.
##
## Note that LDFLAGS is set during make - this is because configure blows up with
## -all-static because it's using gnu ld rather than libtool. -static isn't
## sufficient because libtool interprets that as only being for 'libtool libraries'
## and it's not possible to add -all-static as an argument to libtool itself because
## indicating a desire for static linking can only be done within the linker
## arguments somewhere (libtool plucks the information out).
## However, there is one component Makefile which passes the LDFLAGS to CC directly
## (jay, a yacc parser generator under the mcs directory, mcs being the mono
## compiler which is necessary for compiling mscorlib.dll and other assorted
## runtime library dlls). Of course, since -all-static is not an actual linker flag
## gcc blows up, so we compile jay first with acceptable LDFLAGS.
##RUN tar xjf mono-4.4.0.148.tar.bz2 && \
##    cd mono-4.4.0 && \
##    patch -p1 <../mono.patch && \
##    ./configure --prefix=/home/aidanhs/local --enable-shared --enable-static --enable-libraries --enable-mcs-build --enable-system-aot --with-static_mono=yes --with-shared_mono=no --with-sgen=yes --enable-nls=no --enable-minimal=profiler --with-profile4=no --with-mcs-docs=no --with-moonlight=no && \
##    cd mcs/jay && make LDFLAGS="-Wl,--strip-debug -static" && cd ../.. && \
##    make -j3 LDFLAGS="-Wl,--strip-debug -all-static" && \
##    make install
#
## Some other bits and bobs here if we ever got a musl mono working...
## --with-x
## http://downloads.sourceforge.net/project/keepass/KeePass%202.x/2.33/KeePass-2.33.zip
##ADD KeePass-2.33.zip /work/

RUN tar -c -f /work/local.tar -C /home/aidanhs local && \
    gzip /work/local.tar
