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
timeline_append:: proc(current_tick_index: uint, current_cycle_index: uint, current_phase_index: uint) {
	using state: ^State = cast(^State)context.user_ptr
	append(&timeline, Timeline_Node{
		tick_index = current_tick_index,
		cycle_index = current_cycle_index,
		phase_index = current_phase_index,
		gba_core_interface = gba_core.interface,
		memory_interface = memory.interface }) }
format_line:: proc(signal: Signal(bool)) -> string {
	return signal.enabled ? (signal.output ? "HIGH" : "LOW") : "--" }
format_bus:: proc(signal: Signal($T)) -> string {
	return signal.enabled ? fmt.tprint(signal.output) : "--" }
timeline_print:: proc(handle: os.Handle = 0, name: string = "") -> string {
	using state: ^State = cast(^State)context.user_ptr
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 1024)
	stream: = table.strings_builder_writer(&sb)
	tbl: = table.init(&table.Table{})
	defer table.destroy(tbl)
	table.caption(tbl, (name == "") ? "Timeline" : name)
	table.padding(tbl, 1, 1)
	table.header(tbl, "tick", "cycle", "phase", "MCLK", "MREQ", "SEQ", "RW", "A", "DOUT", "WAIT", "DIN", "EXEC")
	for node, i in timeline {
		table.row(tbl,
			node.tick_index,
			node.cycle_index,
			node.phase_index,
			format_line(node.gba_core_interface.main_clock),
			format_line(node.memory_interface.memory_request),
			format_line(node.memory_interface.sequential_cycle),
			format_bus(node.memory_interface.read_write),
			format_bus(node.memory_interface.address),
			format_bus(node.memory_interface.data_out),
			format_line(node.gba_core_interface.wait),
			format_bus(node.gba_core_interface.data_in),
			format_line(node.gba_core_interface.execute_cycle)) }
	table.write_plain_table(stream, tbl)
	return strings.to_string(sb) }