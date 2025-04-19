package gbana
import		"base:runtime"
import		"core:fmt"
import		"vendor:glfw"


// REGISTERS //
Key_Input_Status:: enum{ Pressed, Released }
KEYINPUT:: bit_field u16 {
	button_a: Key_Input_Status | 1,
	button_b: Key_Input_Status | 1,
	select:   Key_Input_Status | 1,
	start:    Key_Input_Status | 1,
	right:    Key_Input_Status | 1,
	left:     Key_Input_Status | 1,
	up:       Key_Input_Status | 1,
	down:     Key_Input_Status | 1,
	button_r: Key_Input_Status | 1,
	button_l: Key_Input_Status | 1,
	_:        int              | 6 }
Key_Interrupt_Status:: enum{ Ignore, Select }
KEYCNT:: bit_field u16 {
	button_a:             Key_Interrupt_Status             | 1,
	button_b:             Key_Interrupt_Status             | 1,
	select:               Key_Interrupt_Status             | 1,
	start:                Key_Interrupt_Status             | 1,
	right:                Key_Interrupt_Status             | 1,
	left:                 Key_Interrupt_Status             | 1,
	up:                   Key_Interrupt_Status             | 1,
	down:                 Key_Interrupt_Status             | 1,
	button_r:             Key_Interrupt_Status             | 1,
	button_l:             Key_Interrupt_Status             | 1,
	_:                    int                              | 4,
	button_irq_enable:    bool                             | 1,
	button_irq_condition: enum { Logical_OR, Logical_AND } | 1 }


key_callback:: proc "c"(window: glfw.WindowHandle, key: i32, scancode: i32, action: i32, mods: i32) {
    context= runtime.default_context() }
drag_and_drop_callback:: proc "c"(window: glfw.WindowHandle, count: i32, paths: [^]cstring) {
	context= runtime.default_context()
	insert_cartridge(string(paths[0])) }