SHELL := /bin/bash

default: book

build: swagger
	ln -s ../platform-install/docs platform-install && \
	ln -s ../../test/cord-tester/docs test && \
	ln -s ../../orchestration/xos/docs xos && \
	ln -s ../../orchestration/xos-gui/docs xos-gui && \
	ln -s ../../orchestration/profiles profiles && \
	gitbook init && gitbook install && gitbook build

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
	rm -f ../platform-install/docs/docs; \
	rm -f ../../test/cord-tester/docs/docs; \
	rm -f ../../orchestration/xos/docs/docs; \
	rm -f ../../orchestration/xos-gui/docs/docs; \
	rm -f ../../orchestration/profiles/profiles

swagger:
	# pushd ../../orchestration/xos/; source scripts/setup_venv.sh; popd;
	pushd ../../orchestration/xos/docs/; make swagger_docs; popd;

