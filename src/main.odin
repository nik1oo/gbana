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


LOW_PHASE:: 0
HIGH_PHASE:: 1
first_tick: bool
tick_index: uint
cycle_index: uint
phase_index: uint
init:: proc() {
	reinit() }
reinit:: proc() {
	first_tick = true
	tick_index = 0
	cycle_index = 0
	phase_index = 0
	signals: [dynamic]Any_Signal = make([dynamic]Any_Signal)
	device_reset()
}
tick:: proc(n: uint = 0, times: int = 1) -> bool {
	current_tick_index: uint = tick_index
	current_cycle_index: uint = cycle_index
	current_phase_index: uint = phase_index
	if cycle_index >= n do return false
	defer {
		if times > 1 do tick(times = times - 1) }
	if first_tick {
		first_tick = false
		return true }
	if phase_index == 1 {
		cycle_index += 1
		phase_index = 0 }
	else do phase_index += 1
	tick_index += 1
	signals_tick(current_tick_index, current_cycle_index, current_phase_index)
	return true }
main:: proc() {
	init()
	for tick(n = 8) { }
	timeline_print() }