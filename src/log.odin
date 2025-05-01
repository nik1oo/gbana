package gbana
import "core:text/table"
import "core:os"
import "core:io"
import "core:fmt"
import "core:strings"


Timeline_Node:: struct {
	tick_index:         uint,
	cycle_index:        uint,
	phase_index:        uint,
	gba_core_interface: GBA_Core_Interface,
	memory_interface:   Memory_Interface }
Timeline:: [dynamic]Timeline_Node
timeline: Timeline
saved_timelines: [dynamic]Timeline
timeline_append:: proc(tl: ^Timeline, current_tick_index: uint, current_cycle_index: uint, current_phase_index: uint) {
	append(tl, Timeline_Node{
		tick_index = current_tick_index,
		cycle_index = current_cycle_index,
		phase_index = current_phase_index,
		gba_core_interface = gba_core.interface,
		memory_interface = memory.interface }) }
save_timeline:: proc(tl: ^Timeline) {
	append(&saved_timelines, tl^) }
format_line:: proc(line: bool) -> string { return line ? "HIGH" : "LOW" }
timeline_print:: proc(tl: ^Timeline = nil, handle: os.Handle = 0) -> string {
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 1024)
	stream: = table.strings_builder_writer(&sb)
	tl: = tl
	if tl == nil do tl = &timeline
	tbl: = table.init(&table.Table{})
	defer table.destroy(tbl)
	table.caption(tbl, "Timeline")
	table.padding(tbl, 1, 1)
	table.header(tbl, "tick", "cycle", "phase", "MCLK", "MREQ", "SEQ", "RW", "A", "DOUT", "WAIT", "DIN")
	for node, i in tl {
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
	table.write_plain_table(stream, tbl)
	return strings.to_string(sb) }