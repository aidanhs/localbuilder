.PHONY: build localbuilder install

default: build

GRAB = docker run --rm localbuilder cat

build: local.tar.gz

install: local.tar.gz
	rm -rf $$HOME/local
	cd $$HOME && tar xf $$(cd -)/$<

deploy: local.tar.gz
	scp $< aidanhs.com:/var/www/aidanhs/$<

localbuilder:
	tar -c -f - Dockerfile *.tar.gz | docker build --tag localbuilder -

local.tar.gz: localbuilder
	$(GRAB) /work/local.tar.gz > $@
