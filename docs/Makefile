default: book

book: clean build
	gitbook serve

GENERATED_DOCS = glossary.md

build: platform-install test profiles xos xos-gui $(GENERATED_DOCS)
	gitbook init
	gitbook install
	gitbook build

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

glossary.md: scripts/descriptions.md scripts/defaults.md.j2 scripts/defaultsdoc.py
	python scripts/defaultsdoc.py -o glossary.md > /dev/null

ubuntu-tools:
	sudo apt-get install nodejs npm

clean:
	rm -rf $(GENERATED_DOCS)
	rm -rf _book
	rm -rf node_modules
	rm -f platform-install test profiles xos xos-gui

