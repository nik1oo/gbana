package gbana
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "vendor:glfw"
LOG:  string: "\e[0;36m[ log  ]\e[0m"
BAD:  string: "\e[0;31m[ bad  ]\e[0m"
WARN: string: "\e[0;33m[ warn ]\e[0m"
// - graphics hardware registers (GPU)
// - background registers (GPU)
// - windowing registers (GPU)
// - effects registers (GPU)
// - sound registers (sound)
// - DMA registers (DMA)
// - time registers (CPU)
// - serial communication registers (network)
// - keypad input & control registers (input)
// - interrupt registers (cpu)



// Stages of the tick:
// Transition - transition from the previous tick into the current tick.


tick_index:       u64 = 0
cycle_index:      u64 = 0
cycle_tick_index: u64 = 0
main:: proc() {
	init_gba()
	// insert_cartridge("C:\\Games\\GBA Roms\\chessmaster.gba")
	// ins: = cast(GBA_Instruction)memory_read_u32(0)
	ins: = cast(GBA_Instruction)memory.data[0]
	// fmt.printfln("%b", ins)
	ins_ident, ok: = gba_identify_instruction(ins)
	assert(ok)
	fmt.println("identified instruction |", ins_ident)
	// ins_dec, defined: = gba_decode_instruction(ins_ident)
	// assert(defined)
	// // fmt.println(ins_dec)
	// for (glfw.WindowShouldClose(window) == false) {
	// 	draw_display() }
	// NOTE Each cycle is 2 ticks: A low-MCLK tick and a high-MCLK tick. //
	for cycle_index = 0; cycle_index < 16; cycle_index += 1 do for cycle_tick_index = 0; cycle_tick_index < 2; cycle_tick_index += 1 {
		tick_index += 1 } }