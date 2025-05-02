main:
	clear
	odin run . -debug -max-error-count:8

release:
	clear
	odin build . -subsystem:windows

run:
	clear
	odin run . -subsystem:console -debug

test:
	clear
	odin test . -define:ODIN_TEST_TRACK_MEMORY=true -define:ODIN_TEST_THREADS=1 -disable-assert # -debug

sanitize:
	clear
	odin run . -subsystem:console -debug -sanitize:address

debug:
	# odin build . -subsystem:console
	remedybg -g session.rdbg