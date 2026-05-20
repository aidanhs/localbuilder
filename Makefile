.PHONY: build install

default: build

build: local.tar.gz

fuse-overlayfs:
	cd fuse-overlayfs-repo && git clean -fxd && git checkout -- . && git apply ../fuse-overlayfs.patch && docker build -t fuse-overlayfs -f ./Containerfile.static.ubuntu .
	docker run --rm fuse-overlayfs cat /build/fuse-overlayfs/fuse-overlayfs > fuse-overlayfs
	chmod +x fuse-overlayfs

install: local.tar.gz
	rm -rf $$HOME/local
	cd $$HOME && tar xf $$(cd -)/$<

deploy: local.tar.gz
	rsync -av --progress $< aidanhs.com:/var/www/aidanhs/$<

local.tar.gz: Dockerfile fuse-overlayfs pkg2appimage.patch fuse-overlayfs.patch $(shell find scripts systemd -type f)
	tar -c -f - $^ | docker build --tag localbuilder -
	docker run --rm -v $$(pwd):/out localbuilder tar -c -f /out/local.tar -C /home/aidanhs local
	gzip --rsyncable -f local.tar
