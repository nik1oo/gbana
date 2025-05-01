package gbana
import "core:text/table"


Timeline_Node:: struct {
	tick_index:         uint,
	cycle_index:        uint,
	phase_index:        uint,
	gba_core_interface: GBA_Core_Interface,
	memory_interface:   Memory_Interface }
Timeline:: [dynamic]Timeline_Node
timeline: Timeline
timeline_append:: proc(current_tick_index: uint, current_cycle_index: uint, current_phase_index: uint) {
	append(&timeline, Timeline_Node{
		tick_index = current_tick_index,
		cycle_index = current_cycle_index,
		phase_index = current_phase_index,
		gba_core_interface = gba_core.interface,
		memory_interface = memory.interface }) }
format_line:: proc(line: bool) -> string { return line ? "HIGH" : "LOW" }
timeline_print:: proc() {
	stdout: = table.stdio_writer()
	tbl: = table.init(&table.Table{})
	defer table.destroy(tbl)
	table.caption(tbl, "Timeline")
	table.padding(tbl, 1, 1)
	table.header(tbl, "tick", "cycle", "phase", "MCLK", "MREQ", "SEQ", "RW", "A", "DOUT", "WAIT", "DIN")
	// fmt.print("CYCLE ", cycle_index, " | PHASE ", phase_index, " | ", sep="")
	// fmt.print("MCLK ", gba_core.main_clock.output ? 1 : 0, " | ", sep="")
	// fmt.print("RESET ", gba_core.reset.output ? 1 : 0, " | ", sep="")
	// fmt.print("A ", memory.address.output, " | ", sep="")
	// fmt.print("D ", gba_core.data_in.output, " | ", sep="")
	// fmt.print("MREQ ", memory.memory_request.output ? 1 : 0, " | ", sep="")
	// fmt.print("SEQ ", memory.sequential_cycle.output ? 1 : 0, " | ", sep="")
	// fmt.print("EXEC ", gba_core.execute_cycle.output ? 1 : 0, " | ", sep="")
	for node, i in timeline {
		table.row(tbl,
			node.tick_index,
			node.cycle_index,
			node.phase_index,
			format_line(node.gba_core_interface.main_clock.output),
			format_line(node.memory_interface.memory_request.output),
			format_line(node.memory_interface.sequential_cycle.output),
			node.memory_interface.read_write.output,
			node.memory_interface.address.output,
			node.memory_interface.data_out.output,
			format_line(node.gba_core_interface.wait.output),
			node.gba_core_interface.data_in.output) }
	table.write_plain_table(stdout, tbl) }
