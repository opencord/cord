default: book

book:
	ln -s ../platform-install/docs platform-install; \
	ln -s ../../test/cord-tester/docs test; \
	ln -s ../../orchestration/xos/docs xos; \
	ln -s ../../orchestration/profiles profiles; \
	gitbook init; gitbook serve &

clean:
	rm -rf _book; \
	rm platform-install; \
	rm test; \
	rm profiles; \
	rm xos


