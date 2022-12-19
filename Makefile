.PHONY: build install

default: build

build: local.tar.gz

fuse-overlayfs:
	cd fuse-overlayfs-repo && git clean -fxd && podman build -v $$(pwd):/build/fuse-overlayfs -t fuse-overlayfs -f ./Containerfile.static.ubuntu .
	cp fuse-overlayfs-repo/fuse-overlayfs .

install: local.tar.gz
	rm -rf $$HOME/local
	cd $$HOME && tar xf $$(cd -)/$<

deploy: local.tar.gz
	rsync -av --progress $< aidanhs.com:/var/www/aidanhs/$<

local.tar.gz: Dockerfile fuse-overlayfs $(shell find scripts systemd -type f)
	tar -c -f - $^ | podman build -v $$(pwd):/out --tag localbuilder -
	podman run --rm -v $$(pwd):/out localbuilder tar -c -f /out/local.tar -C /home/aidanhs local
	gzip --rsyncable -f local.tar
