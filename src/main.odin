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
tick_index:  uint
cycle_index: uint
phase_index: uint
init:: proc() {
	first_tick = true
	tick_index = 0
	cycle_index = 0
	phase_index = 0
	signals: [dynamic]Any_Signal = make([dynamic]Any_Signal)
	init_gba_core()
	device_reset() }
tick:: proc(n: uint = 0, times: int = 1) -> bool {
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
	signals_tick()
	if cycle_index == n do return false
	return true }
main:: proc() {
	init()
	for tick() {
		fmt.print("CYCLE ", cycle_index, " | PHASE ", phase_index, " | ", sep="")
		fmt.print("MCLK ", gba_core.main_clock.output ? 1 : 0, " | ", sep="")
		fmt.print("RESET ", gba_core.reset.output ? 1 : 0, " | ", sep="")
		fmt.print("A ", gba_core.address.output, " | ", sep="")
		fmt.print("D ", gba_core.data_in.output, " | ", sep="")
		fmt.print("MREQ ", gba_core.memory_request.output ? 1 : 0, " | ", sep="")
		fmt.print("SEQ ", gba_core.sequential_cycle.output ? 1 : 0, " | ", sep="")
		fmt.print("EXEC ", gba_core.execute_cycle.output ? 1 : 0, " | ", sep="")
		fmt.println()
		if cycle_index == 8 do return } }