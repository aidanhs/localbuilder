.PHONY: build localbuilder install

default: build

GRAB = podman run --rm localbuilder cat

build: local.tar.gz

install: local.tar.gz
	rm -rf $$HOME/local
	cd $$HOME && tar xf $$(cd -)/$<

deploy: local.tar.gz
	rsync -av --progress $< aidanhs.com:/var/www/aidanhs/$<

localbuilder:
	tar -c -f - Dockerfile *.tar.gz scripts | podman build --tag localbuilder -

local.tar.gz: localbuilder
	$(GRAB) /work/local.tar | gzip --rsyncable -c > $@
