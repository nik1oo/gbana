main:
	odin check . -debug -max-error-count:8

release:
	odin build . -subsystem:windows

run:
	odin run . -subsystem:console -debug

test:
	odin test . -ignore-warnings -define:ODIN_TEST_TRACK_MEMORY=false

sanitize:
	odin run . -subsystem:console -debug -sanitize:address

debug:
	odin build . -subsystem:console -debug
	remedybg -g session.rdbg