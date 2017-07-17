default: serve

GENERATED_DOCS = build_glossary.md

serve: setup
	gitbook serve

build: setup
	gitbook build

setup: clean platform-install test profiles xos xos-gui xos-tosca swagger $(GENERATED_DOCS)
	gitbook init
	gitbook install

platform-install:
	ln -s ../platform-install/docs platform-install

test:
	ln -s ../../test/cord-tester/docs test

profiles:
	ln -s ../../orchestration/profiles profiles

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
	rm -f platform-install test profiles xos xos-gui xos-tosca

