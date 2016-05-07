.PHONY: build localbuilder install

GRAB = docker run --rm localbuilder cat

build: local.tar.gz

install: build
	rm -rf $$HOME/local
	cd $$HOME && tar xf $$(cd -)/local.tar.gz

localbuilder:
	tar -c -f - Dockerfile *.tar.gz | docker build --tag localbuilder -

local.tar.gz: localbuilder
	docker run --rm localbuilder tar -c -f - -C /home/aidanhs local > local.tar
	gzip local.tar
