SHELL := /bin/bash

default: book

build: swagger
	ln -s ../platform-install/docs platform-install && \
	ln -s ../../test/cord-tester/docs test && \
	ln -s ../../orchestration/xos/docs xos && \
	ln -s ../../orchestration/xos-gui/docs xos-gui && \
	ln -s ../../orchestration/xos-tosca/docs xos-tosca && \
	ln -s ../../orchestration/profiles profiles && \
	gitbook install && gitbook build

book: clean build
	gitbook serve
clean:
	rm -rf _book; \
	rm -rf node_modules; \
	rm platform-install; \
	rm test; \
	rm profiles; \
	rm xos; \
	rm xos-gui; \
	rm xos-tosca; \
	rm -f ../platform-install/docs/docs; \
	rm -f ../../test/cord-tester/docs/docs; \
	rm -f ../../orchestration/xos/docs/docs; \
	rm -f ../../orchestration/xos-gui/docs/docs; \
	rm -f ../../orchestration/xos-tosca/docs/docs; \
	rm -f ../../orchestration/profiles/profiles

swagger:
	pushd ../../orchestration/xos/docs/; make swagger_docs; popd;

