main:
	odin run . -debug -max-error-count:8

release:
	odin build . -subsystem:windows

run:
	odin run . -subsystem:console -debug

sanitize:
	odin run . -subsystem:console -debug -sanitize:address

debug:
	odin build . -subsystem:console -debug
	remedybg -g session.rdbg
