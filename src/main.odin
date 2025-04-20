package gbana
import		"core:fmt"
import		"core:os"
import		"core:path/filepath"
import		"core:strings"
import		"vendor:glfw"
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
main:: proc() {
	k:    u32 = 1443029
	k_le: u32le = u32le(k)
	k_be: u32be = u32be(k)
	fmt.printfln("%X, %X, %X", k, transmute(u32)k_le, transmute(u32)k_be)
	init_memory()
	init_gba_core()
	init_gpu()
	init_display()
	insert_cartridge("C:\\Games\\GBA Roms\\chessmaster.gba")
	for (glfw.WindowShouldClose(window) == false) {
		draw_display() } }