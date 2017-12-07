# Makefile for building CORD docs site, guide.opencord.org
# Building docs requires the following tools:
#  - Gitbook toolchain: https://toolchain.gitbook.com/setup.html
#  - NPM (for Gitbook and Swagger)
#  - Python (for build glossary script)
#  - linkchecker (for test target) http://wummel.github.io/linkchecker/

default: serve

# use bash for pushd/popd, and to fail if commands within  a pipe fail
SHELL = bash -o pipefail

GENERATED_DOCS = build_glossary.md

serve: setup
	gitbook serve

build: setup
	gitbook build

setup: clean platform-install cord-tester profiles xos xos-gui xos-tosca swagger $(GENERATED_DOCS)
	gitbook init
	gitbook install

test: linkcheck

linkcheck: build
	linkchecker --check-extern -a _book/

platform-install:
	ln -s ../platform-install/docs platform-install

cord-tester:
	ln -s ../../test/cord-tester/docs cord-tester

profiles:
	mkdir -p profiles/rcord profiles/ecord profiles/mcord profiles/opencloud
	ln -s ../../../../orchestration/profiles/rcord/docs/README.md profiles/rcord/
	ln -s ../../../../orchestration/profiles/ecord/docs/README.md profiles/ecord/
	ln -s ../../../../orchestration/profiles/mcord/docs/README.md profiles/mcord/
	ln -s ../../../../orchestration/profiles/opencloud/docs/README.md profiles/opencloud/

xos:
	ln -s ../../orchestration/xos/docs xos

xos-gui:
	ln -s ../../orchestration/xos-gui/docs xos-gui

xos-tosca:
	ln -s ../../orchestration/xos-tosca/docs xos-tosca

build_glossary.md: scripts/descriptions.md scripts/defaults.md.j2 scripts/defaultsdoc.py scripts/markedyaml.py
	python scripts/defaultsdoc.py -o build_glossary.md

swagger: xos
	pushd ../../orchestration/xos/docs/; make swagger_docs; popd;

clean:
	rm -rf $(GENERATED_DOCS)
	rm -rf _book
	rm -rf node_modules
	rm -rf platform-install test profiles xos xos-gui xos-tosca

