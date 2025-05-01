package gbana
import "base:runtime"
import "core:math/rand"
import "core:math/bits"


// NOTE I have implemented the entire ISA. //


// register file -- an array of processor registers
// load-store architecture -- instructions only operate on registers


// REGISTERS
//
// 31 regs of 32 bits each
// 16 registers are visible to the programmer (non-privileged, user-mode registers)
// 15 registers are invisible to the programmer (privileged registers)
// register 15, the program counter, points to the instruction after the next instruction
// instructions in memory must be aligned at 32-bit boundaries (the lowest 2 bits of PC must always be 0)
// banked register -- a register name that points to a distinct physical register in each processor mode
//
// INSTRUCTION SET
//
// 4 classes of instructions:
// - branch
// - data-processing
// - load & store
// - coprocessor
//
// every instruction may be conditionally executed.
// several instructions result in updating of the condition code flags.
// there are 15 conditions, whose result is determined solely by the condition code flags (?).
// each instruction must be assigned one of the 15 conditions (?).
//
// there are two instruction sets in the ARMv4t, both of which are used by the GBA:
// - 32-bit ARM isa
// - 16-bit Thumb isa
//
// 3 types of data processing instructions:
// - arithmetic / logic instructions -- self-explanatory
// - multiply instructions -- multiplication with 64-bit result
// - status register transfer instructions -- copy to/from status registers
//
// 2 source operands:
// 1. register value
// 2. immediate value or a (shifted) register value
//
// since every data processing instruction can be shifted, there are no dedicated shift instructions.
// instructions can read/write the PC directly, because it is a general-purpose register.
// 32-bit multiply with 32-bit or 64-bit result.
//
// multiply operands:
// a. multiplicant 1
// b. multiplicant 2
// c. (optional) accumulant from the result register
// a <- a + (b x c)
//
// 3 types of load/store instructions:
// (1) load / store a single register
// (2) load / store multiple registers
// (3) swap register with memory
//
// 3 single-value addressing modes:
// (1) offset       -- (immediate or register) offset
// (2) pre-indexed  -- base + (immediate or register) offset
// (3) post-indexed -- base + (immediate or register) offset
//
// 4 block addressing modes:
// (1) pre-increment
// (2) post-increment
// (3) pre-decrement
// (4) post-decrement
//
// 3 types of coprocessor instructions:
// (1) data-processing instructions -- initiate a coprocessor operation
// (2) register transfer instructions -- transfer data between coprocessor and ARM registers
// (3) data-transfer instructions -- transfer data between coprocessor and memory


// DATA TYPES //
halfword:: u16 // aligned to 16-bit boundaries
word::     u32 // aligned to 32-bit boundaries
halfword_aligned:: struct #align(2) { value: halfword }
word_aligned::     struct #align(4) { value: word     }
align_halfword:: proc(hw: halfword) -> (ahw: halfword_aligned) { return halfword_aligned{ hw } }
align_word::     proc(hw: word)     -> (ahw: word_aligned)     { return word_aligned{ hw }     }
// NOTE This is unnecessary. //
copy_halfwords_to_halfwords_aligned:: proc(dst: []halfword_aligned, src: []halfword) {
	assert(len(dst) == len(src))
	runtime.mem_copy(raw_data(dst), raw_data(src), len(src) * size_of(halfword)) }
zero_extend_byte_to_halfword:: proc(b: byte) -> (hw: halfword) { return halfword(u8(b))      }
zero_extend_byte_to_word::     proc(b: byte) -> (w: word)      { return word(u8(b))          }
sign_extend_byte_to_halfword:: proc(b: byte) -> (hw: halfword) { return halfword(i16(i8(b))) }
sign_extend_byte_to_word::     proc(b: byte) -> (w: word)      { return word(i32(i8(b)))     }


// PROCESSOR MODES //
GBA_Processor_Mode:: enum {
	User =           0b10000, // normal program execution mode
	Fast_Interrupt = 0b10001, // supports a high-speed data transfer or channel process
	Interrupt =      0b10010, // used for general purpose interrupt handling
	Supervisor =     0b10011, // a protected mode for the operating system
	Abort =          0b10111, // implements virtual memory and/or memory protection
	Undefined =      0b11011, // supports software emulation of hardware coprocessors
	System =         0b11111  /* runs privileged operating system tasks*/ }
GBA_PROCESSOR_MODE_DEFAULT:: GBA_Processor_Mode.User
gba_mode_is_privileged::     proc(mode: GBA_Processor_Mode) -> bool { return mode != .User }
gba_mode_is_non_privileged:: proc(mode: GBA_Processor_Mode) -> bool { return mode == .User }
gba_set_mode_initial:: proc() {
	gba_core.logical_registers.r0   = &gba_core.physical_registers.r0
	gba_core.logical_registers.r1   = &gba_core.physical_registers.r1
	gba_core.logical_registers.r2   = &gba_core.physical_registers.r2
	gba_core.logical_registers.r3   = &gba_core.physical_registers.r3
	gba_core.logical_registers.r4   = &gba_core.physical_registers.r4
	gba_core.logical_registers.r5   = &gba_core.physical_registers.r5
	gba_core.logical_registers.r6   = &gba_core.physical_registers.r6
	gba_core.logical_registers.r7   = &gba_core.physical_registers.r7
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14
	gba_core.logical_registers.pc   = &gba_core.physical_registers.pc
	gba_core.logical_registers.cpsr = &gba_core.physical_registers.cpsr
	gba_core.logical_registers.spsr = &gba_core.physical_registers.spsr_svc }
gba_set_mode:: proc(mode: GBA_Processor_Mode) {
	switch mode {
	case .User:           gba_set_mode_user()
	case .Fast_Interrupt: gba_set_mode_fiq()
	case .Interrupt:      gba_set_mode_irq()
	case .Supervisor:     gba_set_mode_supervisor()
	case .Abort:          gba_set_mode_abort()
	case .Undefined:      gba_set_mode_undefined()
	case .System:         gba_set_mode_system() } }
gba_set_mode_user:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14 }
gba_set_mode_fiq:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8_fiq
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9_fiq
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10_fiq
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11_fiq
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12_fiq
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13_fiq
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14_fiq
	gba_core.logical_registers.spsr = &gba_core.physical_registers.spsr_fiq }
gba_set_mode_irq:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13_irq
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14_irq
	gba_core.logical_registers.spsr = &gba_core.physical_registers.spsr_irq }
gba_set_mode_supervisor:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13_svc
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14_svc
	gba_core.logical_registers.spsr = &gba_core.physical_registers.spsr_svc }
gba_set_mode_abort:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13_abort
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14_abort
	gba_core.logical_registers.spsr = &gba_core.physical_registers.spsr_abort }
gba_set_mode_undefined:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13_undef
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14_undef
	gba_core.logical_registers.spsr = &gba_core.physical_registers.spsr_undef }
gba_set_mode_system:: proc() {
	gba_core.logical_registers.r8   = &gba_core.physical_registers.r8
	gba_core.logical_registers.r9   = &gba_core.physical_registers.r9
	gba_core.logical_registers.r10  = &gba_core.physical_registers.r10
	gba_core.logical_registers.r11  = &gba_core.physical_registers.r11
	gba_core.logical_registers.r12  = &gba_core.physical_registers.r12
	gba_core.logical_registers.r13  = &gba_core.physical_registers.r13
	gba_core.logical_registers.r14  = &gba_core.physical_registers.r14 }


// EXCEPTIONS //
//
// 5 types of hardware exceptions:
// - fast interrupt (1 exception vector)
// - slow interrupt (1 exception vector)
// - memory abort (2 exception vectors, one for data access & one for instruction access)
// - undefined instructions (1 exception vector)
// - software interrupt (1 exception vector) (jumps to location in the operating system, a software interrupt handler)
//
// exception handling process:
// 1. exception occurs
// 2. halt execution
// 3. jump to respective exception vector
// 4. execute exception vector
//
GBA_Exception:: enum {
	Reset,
	Undefined_Instructions,
	Software_Interrupt,
	Prefetch_Abort,
	Data_Abort,
	Interrupt,
	Fast_Interrupt }
// NOTE Switch to this mode before executing the exception handler. //
@(rodata) GBA_EXCEPTION_MODES: [7]GBA_Processor_Mode = [7]GBA_Processor_Mode{
	GBA_Exception.Reset                  = .Supervisor,
	GBA_Exception.Undefined_Instructions = .Undefined,
	GBA_Exception.Software_Interrupt     = .Supervisor,
	GBA_Exception.Prefetch_Abort         = .Abort,
	GBA_Exception.Data_Abort             = .Abort,
	GBA_Exception.Interrupt              = .Interrupt,
	GBA_Exception.Fast_Interrupt         = .Fast_Interrupt }
// NOTE Jump to this address to execute the exception handler. //
@(rodata) GBA_EXCEPTION_VECTORS: [7]u32 = {
	GBA_Exception.Reset                  = 0x00000000,
	GBA_Exception.Undefined_Instructions = 0x00000004,
	GBA_Exception.Software_Interrupt     = 0x00000008,
	GBA_Exception.Prefetch_Abort         = 0x0000000c,
	GBA_Exception.Data_Abort             = 0x00000010,
	GBA_Exception.Interrupt              = 0x00000018,
	GBA_Exception.Fast_Interrupt         = 0x0000001c }
@(rodata) GBA_EXCEPTION_PRIORITIES: [7]u32 = {
	GBA_Exception.Reset                  = 1,  // Highest
	GBA_Exception.Data_Abort             = 2,
	GBA_Exception.Fast_Interrupt         = 3,
	GBA_Exception.Interrupt              = 4,
	GBA_Exception.Prefetch_Abort         = 5,
	GBA_Exception.Undefined_Instructions = 6,  // Lowest
	GBA_Exception.Software_Interrupt     = 6 } // Lowest
gba_exceptions_order:: proc(exa: GBA_Exception, exb: GBA_Exception) -> int {
	if GBA_EXCEPTION_PRIORITIES[exa] < GBA_EXCEPTION_PRIORITIES[exb] do return +1
	else if GBA_EXCEPTION_PRIORITIES[exa] > GBA_EXCEPTION_PRIORITIES[exb] do return -1
	else do return 0 }
gba_handle_exception_generic:: proc(exception: GBA_Exception) {
	gba_set_mode(GBA_EXCEPTION_MODES[exception])
	gba_core.logical_registers.r14^ = gba_core.logical_registers.pc^
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_EXCEPTION_MODES[exception]), { 0, 5 })
	if (exception == .Reset) || (exception == .Fast_Interrupt) do insert_bit(gba_core.logical_registers.cpsr, 0b1, 6)
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = GBA_EXCEPTION_VECTORS[exception] }
// NOTE This should be called when the Reset signal becomes 0. //
gba_reset:: proc() {
	gba_set_mode(.Supervisor)
	gba_core.logical_registers.r14^ = rand.uint32()
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Supervisor), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 6)
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0x0 }
gba_handle_undefined_instructions_exception:: proc(address_of_undefined_instruction: u32) {
	gba_set_mode(.Undefined)
	gba_core.logical_registers.r14^ = address_of_undefined_instruction + 4
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Undefined), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0x4 }
gba_return_from_undefined_instructions_exception:: proc() {
	gba_core.logical_registers.pc^ = gba_core.logical_registers.r14^
	gba_set_mode(.User) }
gba_handle_software_interrupt_exception:: proc(address_of_swi_instruction: u32) {
	gba_set_mode(.Supervisor)
	gba_core.logical_registers.r14^ = address_of_swi_instruction + 4
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Supervisor), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0x8 }
gba_return_from_software_interrupt_exception:: proc() {
	gba_core.logical_registers.pc^ = gba_core.logical_registers.r14^
	gba_set_mode(.User) }
gba_handle_prefetch_abort_exception:: proc(address_of_the_aborted_instruction: u32) {
	gba_set_mode(.Abort)
	gba_core.logical_registers.r14^ = address_of_the_aborted_instruction + 4
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Abort), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0xc }
gba_return_from_abort_exception:: proc() {
	gba_core.logical_registers.pc^ = gba_core.logical_registers.r14^ - 4
	gba_set_mode(.User) }
gba_handle_data_abort_exception:: proc(address_of_the_aborted_instruction: u32) {
	gba_set_mode(.Abort)
	gba_core.logical_registers.r14^ = address_of_the_aborted_instruction + 8
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Abort), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0x10 }
gba_return_from_data_abort_exception:: proc(re_execute: bool = true) {
	gba_core.logical_registers.pc^ = gba_core.logical_registers.r14^ - (re_execute ? 8 : 4)
	gba_set_mode(.User) }
gba_handle_interrupt_exception:: proc(address_of_next_instruction: u32) {
	gba_set_mode(.Interrupt)
	gba_core.logical_registers.r14^ = address_of_next_instruction + 4
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Interrupt), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0x18 }
gba_return_from_interrupt_exception:: proc() {
	gba_core.logical_registers.pc^ = gba_core.logical_registers.r14^ - 4
	gba_set_mode(.User) }
gba_handle_fast_interrupt_exception:: proc(address_of_next_instruction: u32) {
	gba_set_mode(.Fast_Interrupt)
	gba_core.logical_registers.r14^ = address_of_next_instruction + 4
	gba_core.logical_registers.spsr^ = gba_core.logical_registers.cpsr^
	insert_bits(gba_core.logical_registers.cpsr, u32(GBA_Processor_Mode.Fast_Interrupt), { 0, 5 })
	insert_bit(gba_core.logical_registers.cpsr, 0b1, 7)
	gba_core.logical_registers.pc^ = 0x1c }
gba_return_from_fast_interrupt_exception:: proc() {
	gba_core.logical_registers.pc^ = gba_core.logical_registers.r14^ - 4
	gba_set_mode(.User) }


// REGISTERS //
GBA_Register:: u32
GBA_Logical_Register_Name:: enum {
	R0 = 0,
	R1 = 1,
	R2 = 2,
	R3 = 3,
	R4 = 4,
	R5 = 5,
	R6 = 6,
	R7 = 7,
	R8 = 8,
	R9 = 9,
	R10 = 10,
	R11 = 11,
	R12 = 12,
	R13 = 13,
	SP = R13,
	R14 = 14,
	LR = R14,
	PC = 15,
	CPSR = 16,
	SPSR = 17 }
GBA_Physical_Register_Name:: enum {
	R0,
	R1,
	R2,
	R3,
	R4,
	R5,
	R6,
	R7,
	R8,
	R9,
	R10,
	R11,
	R12,
	R13,
	R14,
	R13_SVC,
	R14_SVC,
	R13_ABORT,
	R14_ABORT,
	R13_UNDEF,
	R14_UNDEF,
	R13_Interrupt,
	R14_Interrupt,
	R8_Fast_Interrupt,
	R9_Fast_Interrupt,
	R10_Fast_Interrupt,
	R11_Fast_Interrupt,
	R12_Fast_Interrupt,
	R13_Fast_Interrupt,
	R14_Fast_Interrupt,
	CPSR,
	SPSR_SVC,
	SPSR_ABORT,
	SPSR_UNDEF,
	SPSR_Interrupt,
	SPSR_Fast_Interrupt,
	PC }
GBA_Logical_Registers:: struct #raw_union {
	using name: struct {
		r0:   ^GBA_Register,
		r1:   ^GBA_Register,
		r2:   ^GBA_Register,
		r3:   ^GBA_Register,
		r4:   ^GBA_Register,
		r5:   ^GBA_Register,
		r6:   ^GBA_Register,
		r7:   ^GBA_Register,
		r8:   ^GBA_Register,
		r9:   ^GBA_Register,
		r10:  ^GBA_Register,
		r11:  ^GBA_Register,
		r12:  ^GBA_Register,
		r13:  ^GBA_Register,
		r14:  ^GBA_Register,
		pc:   ^GBA_Register,
		cpsr: ^GBA_Register,
		spsr: ^GBA_Register },
	array:    [18]^GBA_Register }
GBA_Physical_Registers:: struct #raw_union {
	using name: struct {
		r0:              GBA_Register,
		r1:              GBA_Register,
		r2:              GBA_Register,
		r3:              GBA_Register,
		r4:              GBA_Register,
		r5:              GBA_Register,
		r6:              GBA_Register,
		r7:              GBA_Register,
		r8:              GBA_Register,
		r9:              GBA_Register,
		r10:             GBA_Register,
		r11:             GBA_Register,
		r12:             GBA_Register,
		r13:             GBA_Register,
		r14:             GBA_Register,
		r13_svc:         GBA_Register,
		r14_svc:         GBA_Register,
		r13_abort:       GBA_Register,
		r14_abort:       GBA_Register,
		r13_undef:       GBA_Register,
		r14_undef:       GBA_Register,
		r13_irq:         GBA_Register,
		r14_irq:         GBA_Register,
		r8_fiq:          GBA_Register,
		r9_fiq:          GBA_Register,
		r10_fiq:         GBA_Register,
		r11_fiq:         GBA_Register,
		r12_fiq:         GBA_Register,
		r13_fiq:         GBA_Register,
		r14_fiq:         GBA_Register,
		cpsr:            GBA_Register,
		spsr_svc:        GBA_Register,
		spsr_abort:      GBA_Register,
		spsr_undef:      GBA_Register,
		spsr_irq:        GBA_Register,
		spsr_fiq:        GBA_Register,
		pc:              GBA_Register },
	using type: struct {
		general_purpose: [30]GBA_Register,
		status:          [6]GBA_Register,
		program_counter: GBA_Register },
	array:               [37]GBA_Register }
// How are the logical registers identified?
// How are the physical registers identified?
// How are the logical registers mapped to the physical registers?
// How is this mapping stored and updated on mode switch?
GBA_Program_Status_Register:: bit_field u32 {
	mode:                  GBA_Processor_Mode | 5,  // M0-M4
	thumb_state:           bool               | 1,  // T
	// NOTE I don't know if I should disable interrupt procedures when these flags are set. //
	fiq_interrupt_disable: bool               | 1,  // F
	irq_interrupt_disable: bool               | 1,  // I
	dnm_raz:               uint               | 20, // DNM/RAZ
	overflow:              bool               | 1,  // V
	carry:                 bool               | 1,  // C
	zero:                  bool               | 1,  // Z
	negative:              bool               | 1 } // N
gba_push_psr:: proc() {
	gba_core.logical_registers.array[GBA_Logical_Register_Name.SPSR]^ = gba_core.logical_registers.array[GBA_Logical_Register_Name.CPSR]^ }
gba_pop_psr:: proc() {
	gba_core.logical_registers.array[GBA_Logical_Register_Name.CPSR]^ = gba_core.logical_registers.array[GBA_Logical_Register_Name.SPSR]^ }


// INSTRUCTION //
GBA_Instruction:: u32


// ADDRESSING MODES //
GBA_Addressing_Mode:: enum {
	SHIFTER_OPERANDS = 0,
	LOAD_AND_STORE_WORD_OR_UNSIGNED_BYTE = 1,
	LOAD_AND_STORE_HALFWORD_OR_LOAD_SIGNED_BYTE = 2,
	LOAD_AND_STORE_MULTIPLE = 3,
	LOAD_AND_STORE_COPROCESSOR = 4,
	MODE_1 = SHIFTER_OPERANDS,
	MODE_2 = LOAD_AND_STORE_WORD_OR_UNSIGNED_BYTE,
	MODE_3 = LOAD_AND_STORE_HALFWORD_OR_LOAD_SIGNED_BYTE,
	MODE_4 = LOAD_AND_STORE_MULTIPLE,
	MODE_5 = LOAD_AND_STORE_COPROCESSOR }


// ADDRESSING MODE 1 //
// NOTE On operands:
// - no memory transfers in decode stage
// - register operands are read from registers
// - registers are not updated
// register                                0000 0000 xxxx
// rotate right with extend                0000 0110 xxxx
// logical shift left by register          xxxx 0001 xxxx
// logical shift right by register         xxxx 0011 xxxx
// arithmetic shift right by register      xxxx 0101 xxxx
// rotate right by register                xxxx 0111 xxxx
// logical shift left by immediate         xxxx x000 xxxx
// logical shift right by immediate        xxxx x010 xxxx
// arithmetic shift right by immediate     xxxx x100 xxxx
// rotate right by immediate               xxxx x110 xxxx
// immediate                               xxxx xxxx xxxx
GBA_SHIFTER_MASK:: 0b_00000000_00000000_00001111_11111111
gba_decode_address_mode_1:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	switch {
	case bits.bitfield_extract(shifter_bits, 4, 8) == 0b_0000_0000: return gba_decode_address_mode_1_register(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 8) == 0b_0000_0110: return gba_decode_address_mode_1_rotate_right_with_extend(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 4) ==      0b_0001: return gba_decode_address_mode_1_logical_shift_left_by_register(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 4) ==      0b_0011: return gba_decode_address_mode_1_logical_shift_right_by_register(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 4) ==      0b_0101: return gba_decode_address_mode_1_arithmetic_shift_right_by_register(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 4) ==      0b_0111: return gba_decode_address_mode_1_rotate_right_by_register(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 3) ==       0b_000: return gba_decode_address_mode_1_logical_shift_left_by_immediate(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 3) ==       0b_010: return gba_decode_address_mode_1_logical_shift_right_by_immediate(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 3) ==       0b_100: return gba_decode_address_mode_1_arithmetic_shift_right_by_immediate(shifter_bits)
	case bits.bitfield_extract(shifter_bits, 4, 3) ==       0b_110: return gba_decode_address_mode_1_rotate_right_by_immediate(shifter_bits)
	case:                                                           return gba_decode_address_mode_1_immediate(shifter_bits) }
	return 0b0, false }
gba_decode_address_mode_1_immediate:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	immediate: u32 = bits.bitfield_extract(shifter_bits, 0, 8)
	rotate: u32 = bits.bitfield_extract(shifter_bits, 8, 4)
	shifter_operand = rotate_right(immediate, uint(rotate))
	if rotate == 0 do shifter_carry_out = gba_get_cpsr().carry
	else do shifter_carry_out = bool(bits.bitfield_extract(shifter_operand, 31, 1))
	return shifter_operand, shifter_carry_out }
gba_decode_address_mode_1_register:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	return gba_core.logical_registers.array[shifter_bits]^, false }
gba_decode_address_mode_1_logical_shift_left_by_immediate:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = bits.bitfield_extract(shifter_bits, 7, 5)
	return u32(rm) << shift, bool(bits.bitfield_extract(rm, uint(32 - shift), 1)) }
gba_decode_address_mode_1_logical_shift_left_by_register:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 8, 4)]^ & 0b_00000000_11111111
	return u32(rm) << shift, bool(bits.bitfield_extract(rm, uint(32 - shift), 1)) }
gba_decode_address_mode_1_logical_shift_right_by_immediate:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = bits.bitfield_extract(shifter_bits, 7, 5)
	return u32(rm) >> shift, bool(bits.bitfield_extract(rm, uint(shift - 1), 1)) }
gba_decode_address_mode_1_logical_shift_right_by_register:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 8, 4)]^ & 0b_00000000_11111111
	return u32(rm) >> shift, bool(bits.bitfield_extract(rm, uint(shift - 1), 1)) }
gba_decode_address_mode_1_arithmetic_shift_right_by_immediate:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = bits.bitfield_extract(shifter_bits, 7, 5)
	if shift == 0 do shift = 32
	return u32(i32(rm) >> shift), bool(bits.bitfield_extract(rm, uint(shift - 1), 1)) }
gba_decode_address_mode_1_arithmetic_shift_right_by_register:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 8, 4)]^ & 0b_00000000_11111111
	if shift == 0 do shift = 32
	return u32(i32(rm) >> shift), bool(bits.bitfield_extract(rm, uint(shift - 1), 1)) }
gba_decode_address_mode_1_rotate_right_by_immediate:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = bits.bitfield_extract(shifter_bits, 7, 5)
	return rotate_right(rm, uint(shift)), bool(bits.bitfield_extract(rm, uint(shift - 1), 1)) }
gba_decode_address_mode_1_rotate_right_by_register:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	shift: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 8, 4)]^ & 0b_00000000_11111111
	return rotate_right(rm, uint(shift)), bool(bits.bitfield_extract(rm, uint(shift - 1), 1)) }
gba_decode_address_mode_1_rotate_right_with_extend:: proc(shifter_bits: u32) -> (shifter_operand: u32, shifter_carry_out: bool) {
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(shifter_bits, 0, 4)]^
	return (u32(gba_get_cpsr().carry) << 31) | rm >> 1, bool(rm & 0b1) }


// ADDRESSING MODE 2 //
gba_decode_address_mode_2:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32, unsigned_byte: bool, write_back: bool, write_back_register: GBA_Logical_Register_Name) {
	bit_25: u32 = bits.bitfield_extract(ins, 25, 1)
	p: bool = cast(bool)bits.bitfield_extract(ins, 24, 1)
	write_back = cast(bool)bits.bitfield_extract(ins, 24, 1)
	unsigned_byte = cast(bool)bits.bitfield_extract(ins, 22, 1)
	scaled_bits: u32 = bits.bitfield_extract(ins, 5, 7)
	write_back_register = cast(GBA_Logical_Register_Name)bits.bitfield_extract(ins, 16, 4)
	if bit_25 == 0b_0 {
		if p != write_back do address, write_back_value = gba_decode_address_mode_2_immediate_offset(ins)
		else {
			if p do address, write_back_value = gba_decode_address_mode_2_immediate_pre_indexed(ins)
			else do address, write_back_value = gba_decode_address_mode_2_immediate_post_indexed(ins) } }
	else if scaled_bits == 0b_0000_000 {
		if p != write_back do address, write_back_value = gba_decode_address_mode_2_register_offset(ins)
		else {
			if p do address, write_back_value = gba_decode_address_mode_2_register_pre_indexed(ins)
			else do address, write_back_value = gba_decode_address_mode_2_register_post_indexed(ins) } }
	else {
		if p != write_back do address, write_back_value = gba_decode_address_mode_2_scaled_register_offset(ins)
		else {
			if p do address, write_back_value = gba_decode_address_mode_2_scaled_register_pre_indexed(ins)
			else do address, write_back_value = gba_decode_address_mode_2_scaled_register_post_indexed(ins) } }
	return address, write_back_value, unsigned_byte, write_back, write_back_register }
gba_decode_address_mode_2_immediate_offset:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	u: bool = bool(bits.bitfield_extract(ins, 23, 1))
	rn: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^
	offset: u32 = bits.bitfield_extract(ins, 0, 12)
	if u do address = rn + offset
	else do address = rn - offset
	write_back_value = 0b0
	return address, write_back_value }
gba_decode_address_mode_2_register_offset:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	u: bool = bool(bits.bitfield_extract(ins, 23, 1))
	rn: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^
	rm: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 0, 4)]^
	if u do address = rn + rm
	else do address = rn - rm
	write_back_value = 0b0
	return address, write_back_value }
gba_decode_address_mode_2_scaled_register_offset:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	u: bool = bool(bits.bitfield_extract(ins, 23, 1))
	rn: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^
	rm: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 0, 4)]^
	shift: u32 = bits.bitfield_extract(ins, 5, 2)
	shift_immediate: u32 = bits.bitfield_extract(ins, 7, 5)
	index: u32
	switch shift {
	case 0b_00:
		index = rm << shift_immediate
	case 0b_01:
		index = rm >> shift_immediate
	case 0b_10:
		index = u32(i32(rm) >> shift_immediate)
	case 0b_11:
		if shift_immediate == 0 do index = (u32(gba_get_cpsr().carry) << 31) | (rm >> 1)
		else do index = rotate_right(rm, uint(shift_immediate)) }
	if u do address = rn + index
	else do address = rn - index
	write_back_value = 0b0
	return address, write_back_value }
gba_decode_address_mode_2_immediate_pre_indexed:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	// TODO This updates Rn. Make sure it is executed in the correct place.
	address, _ = gba_decode_address_mode_2_immediate_offset(ins)
	write_back_value = address
	return address, write_back_value }
gba_decode_address_mode_2_register_pre_indexed:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	address, _ = gba_decode_address_mode_2_register_offset(ins)
	write_back_value = address
	return address, write_back_value }
gba_decode_address_mode_2_scaled_register_pre_indexed:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	address, _ = gba_decode_address_mode_2_scaled_register_offset(ins)
	write_back_value = address
	return address, write_back_value }
gba_decode_address_mode_2_immediate_post_indexed:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	address = rn^
	write_back_value, _ = gba_decode_address_mode_2_immediate_offset(ins)
	return address, write_back_value }
gba_decode_address_mode_2_register_post_indexed:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	address = rn^
	write_back_value, _ = gba_decode_address_mode_2_register_offset(ins)
	return address, write_back_value }
gba_decode_address_mode_2_scaled_register_post_indexed:: proc(ins: GBA_Instruction) -> (address: u32, write_back_value: u32) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	address = rn^
	write_back_value, _ = gba_decode_address_mode_2_scaled_register_offset(ins)
	return address, write_back_value }
// TODO Call this at the end of execution of every function that has a write_back flag set to TRUE in its decoded object. //
gba_write_back:: proc(write_back_value: u32, write_back_register: GBA_Logical_Register_Name) {
	gba_core.logical_registers.array[write_back_register]^ = write_back_value }


// ADDRESSING MODE 3 //
gba_decode_address_mode_3:: proc(ins: GBA_Instruction) -> (address: u32) {
	bit_22: u32 = bits.bitfield_extract(ins, 22, 1)
	p: bool = cast(bool)bits.bitfield_extract(ins, 24, 1)
	w: bool = cast(bool)bits.bitfield_extract(ins, 21, 1)
	scaled_bits: u32 = bits.bitfield_extract(ins, 5, 7)
	if bit_22 == 0b_1 {
		if p != w do return gba_decode_address_mode_3_immediate_offset(ins)
		else {
			if p do return gba_decode_address_mode_3_immediate_pre_indexed(ins)
			else do return gba_decode_address_mode_3_immediate_post_indexed(ins) } }
	else {
		if p != w do return gba_decode_address_mode_3_register_offset(ins)
		else {
			if p do return gba_decode_address_mode_3_register_pre_indexed(ins)
			else do return gba_decode_address_mode_3_register_post_indexed(ins) } }
	return 0b0 }
gba_decode_address_mode_3_immediate_offset:: proc(ins: GBA_Instruction) -> (address: u32) {
	u: bool = bool(bits.bitfield_extract(ins, 23, 1))
	rn: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^
	immed_l: u32 = bits.bitfield_extract(ins, 0, 4)
	immed_h: u32 = bits.bitfield_extract(ins, 8, 4)
	offset: u32 = (immed_h << 4) | immed_l
	if u do address = rn + offset
	else do address = rn - offset
	return address }
gba_decode_address_mode_3_register_offset:: proc(ins: GBA_Instruction) -> (address: u32) {
	u: bool = bool(bits.bitfield_extract(ins, 23, 1))
	rn: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^
	rm: u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 0, 4)]^
	if u do address = rn + rm
	else do address = rn - rm
	return address }
gba_decode_address_mode_3_immediate_pre_indexed:: proc(ins: GBA_Instruction) -> (address: u32) {
	address = gba_decode_address_mode_3_immediate_offset(ins)
	gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^ = address
	return address }
gba_decode_address_mode_3_register_pre_indexed:: proc(ins: GBA_Instruction) -> (address: u32) {
	address = gba_decode_address_mode_3_register_offset(ins)
	gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]^ = address
	return address }
gba_decode_address_mode_3_immediate_post_indexed:: proc(ins: GBA_Instruction) -> (address: u32) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	address = rn^
	rn^ = gba_decode_address_mode_3_immediate_offset(ins)
	return address }
gba_decode_address_mode_3_register_post_indexed:: proc(ins: GBA_Instruction) -> (address: u32) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	address = rn^
	rn^ = gba_decode_address_mode_3_register_offset(ins)
	return address }


// ADDRESSING MODE 4 //
gba_decode_address_mode_4:: proc(ins: GBA_Instruction) -> (start_address: u32, end_address: u32, registers: bit_set[GBA_Logical_Register_Name]) {
	bit_22: u32 = bits.bitfield_extract(ins, 22, 1)
	p: bool = cast(bool)bits.bitfield_extract(ins, 24, 1)
	u: bool = cast(bool)bits.bitfield_extract(ins, 23, 1)
	switch {
	case [2]bool{p, u} == [2]bool{false, true}:  return gba_decode_address_mode_4_increment_after(ins)
	case [2]bool{p, u} == [2]bool{true, true}:   return gba_decode_address_mode_4_increment_before(ins)
	case [2]bool{p, u} == [2]bool{false, false}: return gba_decode_address_mode_4_decrement_after(ins)
	case [2]bool{p, u} == [2]bool{true, false}:  return gba_decode_address_mode_4_decrement_before(ins)  }
	return 0, 0, {} }
gba_decode_address_mode_4_increment_after:: proc(ins: GBA_Instruction) -> (start_address: u32, end_address: u32, registers: bit_set[GBA_Logical_Register_Name]) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	start_address = rn^
	register_list: u32 = bits.bitfield_extract(u32(ins), 0, 15)
	for i in 0 ..< 15 {
		if bool(register_list & (0b1 << uint(i))) do registers += { GBA_Logical_Register_Name(i) } }
	end_address = start_address + cast(u32)(card(registers) - 1) * 4
	return start_address, end_address, registers }
gba_decode_address_mode_4_increment_before:: proc(ins: GBA_Instruction) -> (start_address: u32, end_address: u32, registers: bit_set[GBA_Logical_Register_Name]) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	start_address = rn^ + 4
	register_list: u32 = bits.bitfield_extract(u32(ins), 0, 15)
	for i in 0 ..< 15 {
		if bool(register_list & (0b1 << uint(i))) do registers += { GBA_Logical_Register_Name(i) } }
	end_address = start_address + cast(u32)card(registers) * 4
	return start_address, end_address, registers }
gba_decode_address_mode_4_decrement_after:: proc(ins: GBA_Instruction) -> (start_address: u32, end_address: u32, registers: bit_set[GBA_Logical_Register_Name]) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	start_address = rn^ - cast(u32)(card(registers) - 1) * 4
	register_list: u32 = bits.bitfield_extract(u32(ins), 0, 15)
	for i in 0 ..< 15 {
		if bool(register_list & (0b1 << uint(i))) do registers += { GBA_Logical_Register_Name(i) } }
	end_address = rn^
	return start_address, end_address, registers }
gba_decode_address_mode_4_decrement_before:: proc(ins: GBA_Instruction) -> (start_address: u32, end_address: u32, registers: bit_set[GBA_Logical_Register_Name]) {
	rn: ^u32 = gba_core.logical_registers.array[bits.bitfield_extract(ins, 16, 4)]
	start_address = rn^ - cast(u32)card(registers) * 4
	register_list: u32 = bits.bitfield_extract(u32(ins), 0, 15)
	for i in 0 ..< 15 {
		if bool(register_list & (0b1 << uint(i))) do registers += { GBA_Logical_Register_Name(i) } }
	end_address = rn^ - 4
	return start_address, end_address, registers }


// CONDITION //
GBA_Condition:: enum u8 {
EQUAL                     = 0b0000,  // Z set
NOT_EQUAL                 = 0b0001,  // Z clear
CARRY_SET                 = 0b0010,  // C set
UNSIGNED_GREATER_OR_EQUAL = 0b0010,  // C set
CARRY_CLEAR               = 0b0011,  // C clear
UNSIGNED_LESSER           = 0b0011,  // C clear
MINUS                     = 0b0100,  // N set
NEGATIVE                  = 0b0100,  // N set
PLUS                      = 0b0101,  // N clear
POSITIVE_OR_ZERO          = 0b0101,  // N clear
OVERFLOW                  = 0b0110,  // V set
NO_OVERFLOW               = 0b0111,  // V clear
UNSIGNED_GREATER          = 0b1000,  // C set and Z clear
UNSIGNED_LESSER_OR_EQUAL  = 0b1001,  // C clear or Z set
SIGNED_GREATER_OR_EQUAL   = 0b1010,  // N set and V set, or N clear and V clear (N = V)
SIGNED_LESSER             = 0b1011,  // N set and V clear, or N clear and V set (N != V)
SIGNED_GREATER            = 0b1100,  // Z clear, and either N set and V set, or N clear and V clear (Z = 0, N = V)
SIGNED_LESSER_OR_EQUAL    = 0b1101,  // Z set, or N set and V clear, or N clear and V set (Z = 1, N != V)
ALWAYS                    = 0b1110,  // true
NEVER                     = 0b1111 } // false
gba_condition_passed:: proc(condition: GBA_Condition) -> bool {
	switch condition {
	case .EQUAL:                     return gba_condition_passed_equal()
	case .NOT_EQUAL:                 return gba_condition_passed_not_equal()
	case .CARRY_SET:                 return gba_condition_passed_carry_set()
	case .CARRY_CLEAR:               return gba_condition_passed_carry_clear()
	case .MINUS:                     return gba_condition_passed_minus()
	case .PLUS:                      return gba_condition_passed_plus()
	case .OVERFLOW:                  return gba_condition_passed_overflow()
	case .NO_OVERFLOW:               return gba_condition_passed_no_overflow()
	case .UNSIGNED_GREATER:          return gba_condition_passed_unsigned_greater()
	case .UNSIGNED_LESSER_OR_EQUAL:  return gba_condition_passed_unsigned_lesser_or_equal()
	case .SIGNED_GREATER_OR_EQUAL:   return gba_condition_passed_signed_greater_or_equal()
	case .SIGNED_LESSER:             return gba_condition_passed_signed_lesser()
	case .SIGNED_GREATER:            return gba_condition_passed_signed_greater()
	case .SIGNED_LESSER_OR_EQUAL:    return gba_condition_passed_signed_lesser_or_equal()
	case .ALWAYS:                    return gba_condition_passed_always()
	case .NEVER:                     return gba_condition_passed_never() }
	return false }
gba_get_cpsr:: proc() -> ^GBA_Program_Status_Register {
	return (^GBA_Program_Status_Register)(gba_core.logical_registers.cpsr) }
gba_get_spsr:: proc() -> ^GBA_Program_Status_Register {
	return (^GBA_Program_Status_Register)(gba_core.logical_registers.spsr) }
gba_condition_passed_equal:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.zero }
gba_condition_passed_not_equal:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return ! cpsr.zero }
gba_condition_passed_carry_set:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.carry }
gba_condition_passed_carry_clear:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return ! cpsr.carry }
gba_condition_passed_minus:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.negative }
gba_condition_passed_plus:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return ! cpsr.negative }
gba_condition_passed_overflow:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.overflow }
gba_condition_passed_no_overflow:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.overflow }
gba_condition_passed_unsigned_greater:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.carry && (! cpsr.zero) }
gba_condition_passed_unsigned_lesser_or_equal:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return (! cpsr.carry) || cpsr.zero }
gba_condition_passed_signed_greater_or_equal:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.negative == cpsr.overflow }
gba_condition_passed_signed_lesser:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.negative != cpsr.overflow }
gba_condition_passed_signed_greater:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return (! cpsr.zero) && (cpsr.negative == cpsr.overflow) }
gba_condition_passed_signed_lesser_or_equal:: proc() -> bool {
	cpsr: = gba_get_cpsr()
	return cpsr.zero || (cpsr.negative != cpsr.overflow) }
gba_condition_passed_always:: proc() -> bool {
	return true }
gba_condition_passed_never:: proc() -> bool {
	return false }


// INSTRUCTION CLASSES //
GBA_Instruction_Class:: enum {
	DATA_PROCESSING = 0b00,
	LOAD_AND_STORE  = 0b01,
	BRANCH          = 0b10,
	COPROCESSOR     = 0b11 }
GBA_Instruction_Group:: enum {
	DATA_PROCESSING,        // < DATA_PROCESSING
	MULTIPLY,               // < DATA_PROCESSING
	STATUS_REGISTER_ACCESS, // < DATA_PROCESSING
	SEMAPHORE,              // < DATA_PROCESSING
	LOAD_AND_STORE,         // < LOAD_AND_STORE
	BRANCH,                 // < BRANCH
	COPROCESSOR }           // < COPROCESSOR
GBA_Instruction_Type:: enum {
	DATA_PROCESSING_IMMEDIATE,
	DATA_PROCESSING_IMMEDIATE_SHIFT,
	DATA_PROCESSING_REGISTER_SHIFT,
	MULTIPLY,
	MULTIPLY_LONG,
	MOVE_FROM_STATUS_REGISTER,
	MOVE_IMMEDIATE_TO_STATUS_REGISTER,
	MOVE_REGISTER_TO_STATUS_REGISTER,
	BRANCH_AND_EXCHANGE,
	LOAD_STORE_IMMEDIATE_OFFSET,
	LOAD_STORE_REGISTER_OFFSET,
	LOAD_STORE_HALFWORD_SIGNED_BYTE,
	SWAP,
	LOAD_STORE_MULTIPLE,
	COPROCESSOR_DATA_PROCESSING,
	COPROCESSOR_REGISTER_TRANSFERS,
	COPROCESSOR_LOAD_STORE,
	BRANCH,
	SOFTWARE_INTERRUPT,
	UNDEFINED }
// gba_verify_opcode:: proc {
// 	gba_verify_data_processing_immediate_opcode,
// 	gba_verify_data_processing_immediate_shift_opcode,
// 	gba_verify_data_processing_register_shift_opcode,
// 	gba_verify_multiply_opcode,
// 	gba_verify_multiply_long_opcode,
// 	gba_verify_move_from_status_register_opcode,
// 	gba_verify_move_immediate_to_status_register_opcode,
// 	gba_verify_move_register_to_status_register_opcode,
// 	gba_verify_branch_and_exchange_opcode,
// 	gba_verify_load_store_immediate_offset_opcode,
// 	gba_verify_load_store_register_offset_opcode,
// 	gba_verify_load_store_halfword_signed_byte_opcode,
// 	gba_verify_swap_opcode,
// 	gba_verify_load_store_multiple_opcode,
// 	gba_verify_coprocessor_data_processing_opcode,
// 	gba_verify_coprocessor_register_transfers_opcode,
// 	gba_verify_coprocessor_load_store_opcode,
// 	gba_verify_branch_opcode,
// 	gba_verify_software_interrupt_opcode,
// 	gba_verify_undefined_opcode }
// gba_determine_instruction_type:: proc(ins: GBA_Instruction) -> GBA_Instruction_Type {
// 	switch {
// 	case gba_verify_data_processing_immediate_opcode(auto_cast ins):         return .DATA_PROCESSING_IMMEDIATE
// 	case gba_verify_data_processing_immediate_shift_opcode(auto_cast ins):   return .DATA_PROCESSING_IMMEDIATE_SHIFT
// 	case gba_verify_data_processing_register_shift_opcode(auto_cast ins):    return .DATA_PROCESSING_REGISTER_SHIFT
// 	case gba_verify_multiply_opcode(auto_cast ins):                          return .MULTIPLY
// 	case gba_verify_multiply_long_opcode(auto_cast ins):                     return .MULTIPLY_LONG
// 	case gba_verify_move_from_status_register_opcode(auto_cast ins):         return .MOVE_FROM_STATUS_REGISTER
// 	case gba_verify_move_immediate_to_status_register_opcode(auto_cast ins): return .MOVE_IMMEDIATE_TO_STATUS_REGISTER
// 	case gba_verify_move_register_to_status_register_opcode(auto_cast ins):  return .MOVE_REGISTER_TO_STATUS_REGISTER
// 	case gba_verify_branch_and_exchange_opcode(auto_cast ins):               return .BRANCH_AND_EXCHANGE
// 	case gba_verify_load_store_immediate_offset_opcode(auto_cast ins):       return .LOAD_STORE_IMMEDIATE_OFFSET
// 	case gba_verify_load_store_register_offset_opcode(auto_cast ins):        return .LOAD_STORE_REGISTER_OFFSET
// 	case gba_verify_load_store_halfword_signed_byte_opcode(auto_cast ins):   return .LOAD_STORE_HALFWORD_SIGNED_BYTE
// 	case gba_verify_swap_opcode(auto_cast ins):                              return .SWAP
// 	case gba_verify_load_store_multiple_opcode(auto_cast ins):               return .LOAD_STORE_MULTIPLE
// 	case gba_verify_coprocessor_data_processing_opcode(auto_cast ins):       return .COPROCESSOR_DATA_PROCESSING
// 	case gba_verify_coprocessor_register_transfers_opcode(auto_cast ins):    return .COPROCESSOR_REGISTER_TRANSFERS
// 	case gba_verify_coprocessor_load_store_opcode(auto_cast ins):            return .COPROCESSOR_LOAD_STORE
// 	case gba_verify_branch_opcode(auto_cast ins):                            return .BRANCH
// 	case gba_verify_software_interrupt_opcode(auto_cast ins):                return .SOFTWARE_INTERRUPT
// 	case gba_verify_undefined_opcode(auto_cast ins):                         return .UNDEFINED }
// 	panic("unrecognized instruction") }
// // Instruction Classes that have an "opcode" field:
// // - data processing instructions
// // - coprocessor data processing instructions
// // - coprocessor register transfers instructions
// GBA_Data_Processing_Immediate_Instruction:: bit_field u32 {
// 	immediate: u32                      | 8,
// 	rotate:    uint                      | 4,
// 	rd:        GBA_Logical_Register_Name | 4,
// 	rn:        GBA_Logical_Register_Name | 4,
// 	set_condition_codes:         bool                      | 1,
// 	opcode:        uint                      | 4,
// 	_:         uint                      | 3,
// 	cond:      GBA_Condition             | 4 }
// GBA_DATA_PROCESSING_IMMEDIATE_OPCODE::      0b00000010_00000000_00000000_00000000
// GBA_DATA_PROCESSING_IMMEDIATE_OPCODE_MASK:: 0b00001110_00000000_00000000_00000000
// gba_verify_data_processing_immediate_opcode:: proc(ins: GBA_Data_Processing_Immediate_Instruction) -> bool {
// 	return (i32(ins) & GBA_DATA_PROCESSING_IMMEDIATE_OPCODE_MASK) == GBA_DATA_PROCESSING_IMMEDIATE_OPCODE }
// GBA_Data_Processing_Immediate_Shift_Instruction:: bit_field u32 {
// 	rm:              GBA_Logical_Register_Name | 4,
// 	_:               uint                      | 1,
// 	shift:           uint                      | 2,
// 	shift_immediate: uint                      | 5,
// 	rd:              GBA_Logical_Register_Name | 4,
// 	rn:              GBA_Logical_Register_Name | 4,
// 	set_condition_codes:               bool                      | 1,
// 	opcode:          uint                      | 4,
// 	_:               uint                      | 3,
// 	cond:            GBA_Condition             | 4 }
// GBA_DATA_PROCESSING_IMMEDIATE_SHIFT_OPCODE::      0b00000000_00000000_00000000_00000000
// GBA_DATA_PROCESSING_IMMEDIATE_SHIFT_OPCODE_MASK:: 0b00001110_00000000_00000000_00010000
// gba_verify_data_processing_immediate_shift_opcode:: proc(ins: GBA_Data_Processing_Immediate_Shift_Instruction) -> bool {
// 	return (i32(ins) & GBA_DATA_PROCESSING_IMMEDIATE_SHIFT_OPCODE_MASK) == GBA_DATA_PROCESSING_IMMEDIATE_SHIFT_OPCODE }
// GBA_Data_Processing_Register_Shift_Instruction:: bit_field u32 {
// 	rm:              GBA_Logical_Register_Name | 4,
// 	_:               uint                      | 1,
// 	shift:           uint                      | 2,
// 	_:               uint                      | 1,
// 	rs:              GBA_Logical_Register_Name | 4,
// 	rd:              GBA_Logical_Register_Name | 4,
// 	rn:              GBA_Logical_Register_Name | 4,
// 	set_condition_codes:               bool                      | 1,
// 	opcode:          uint                      | 4,
// 	_:               uint                      | 3,
// 	cond:            GBA_Condition             | 4 }
// GBA_DATA_PROCESSING_REGISTER_SHIFT_OPCODE::      0b00000000_00000000_00000000_00010000
// GBA_DATA_PROCESSING_REGISTER_SHIFT_OPCODE_MASK:: 0b00001110_00000000_00000000_10010000
// gba_verify_data_processing_register_shift_opcode:: proc(ins: GBA_Data_Processing_Register_Shift_Instruction) -> bool {
// 	return (i32(ins) & GBA_DATA_PROCESSING_REGISTER_SHIFT_OPCODE_MASK) == GBA_DATA_PROCESSING_REGISTER_SHIFT_OPCODE }
// GBA_Multiply_Instruction:: bit_field u32 {
// 	rm:   GBA_Logical_Register_Name | 4,
// 	_:    uint                      | 4,
// 	rs:   GBA_Logical_Register_Name | 4,
// 	rn:   GBA_Logical_Register_Name | 4,
// 	rd:   GBA_Logical_Register_Name | 4,
// 	set_condition_codes:    bool                      | 1,
// 	a:    bool                      | 1,
// 	_:    uint                      | 6,
// 	cond: GBA_Condition             | 4 }
// GBA_MULTIPLY_OPCODE::      0b00000000_00000000_00000000_10010000
// GBA_MULTIPLY_OPCODE_MASK:: 0b00001111_11000000_00000000_11110000
// gba_verify_multiply_opcode:: proc(ins: GBA_Multiply_Instruction) -> bool {
// 	return (i32(ins) & GBA_MULTIPLY_OPCODE_MASK) == GBA_MULTIPLY_OPCODE }
// GBA_Multiply_Long_Instruction:: bit_field u32 {
// 	rm:    GBA_Logical_Register_Name | 4,
// 	_:     uint                      | 4,
// 	rs:    GBA_Logical_Register_Name | 4,
// 	rd_lo: GBA_Logical_Register_Name | 4,
// 	rd_hi: GBA_Logical_Register_Name | 4,
// 	set_condition_codes:     bool                      | 1,
// 	a:     bool                      | 1,
// 	u:     bool                      | 1,
// 	_:     uint                      | 5,
// 	cond:  GBA_Condition             | 4 }
// GBA_MULTIPLY_LONG_OPCODE::      0b00000000_10000000_00000000_10010000
// GBA_MULTIPLY_LONG_OPCODE_MASK:: 0b00001111_10000000_00000000_11110000
// gba_verify_multiply_long_opcode:: proc(ins: GBA_Multiply_Long_Instruction) -> bool {
// 	return (i32(ins) & GBA_MULTIPLY_LONG_OPCODE_MASK) == GBA_MULTIPLY_LONG_OPCODE }
// GBA_Move_From_Status_Register_Instruction:: bit_field u32 {
// 	sbz:   uint                      | 12,
// 	rd:    GBA_Logical_Register_Name | 4,
// 	sbo:   uint                      | 4,
// 	_:     uint                      | 2,
// 	r:     bool                      | 1,
// 	_:     uint                      | 5,
// 	cond:  GBA_Condition             | 4 }
// GBA_MOVE_FROM_STATUS_REGISTER_OPCODE::      0b00000001_00000000_00000000_00000000
// GBA_MOVE_FROM_STATUS_REGISTER_OPCODE_MASK:: 0b00001111_10110000_00000000_00000000
// gba_verify_move_from_status_register_opcode:: proc(ins: GBA_Move_From_Status_Register_Instruction) -> bool {
// 	return (i32(ins) & GBA_MOVE_FROM_STATUS_REGISTER_OPCODE_MASK) == GBA_MOVE_FROM_STATUS_REGISTER_OPCODE }
// GBA_Move_Immediate_To_Status_Register_Instruction:: bit_field u32 {
// 	immediate: uint          | 8,
// 	rotate:    uint          | 4,
// 	sbo:       uint          | 4,
// 	mask:      uint          | 4,
// 	_:         uint          | 2,
// 	r:         bool          | 1,
// 	_:         uint          | 5,
// 	cond:      GBA_Condition | 4 }
// GBA_MOVE_IMMEDIATE_TO_STATUS_REGISTER_OPCODE::      0b00000011_00100000_00000000_00000000
// GBA_MOVE_IMMEDIATE_TO_STATUS_REGISTER_OPCODE_MASK:: 0b00001111_10110000_00000000_00000000
// gba_verify_move_immediate_to_status_register_opcode:: proc(ins: GBA_Move_Immediate_To_Status_Register_Instruction) -> bool {
// 	return (i32(ins) & GBA_MOVE_IMMEDIATE_TO_STATUS_REGISTER_OPCODE_MASK) == GBA_MOVE_IMMEDIATE_TO_STATUS_REGISTER_OPCODE }
// GBA_Move_Register_To_Status_Register_Instruction:: bit_field u32 {
// 	immediate: uint          | 8,
// 	rotate:    uint          | 4,
// 	sbo:       uint          | 4,
// 	mask:      uint          | 4,
// 	_:         uint          | 2,
// 	r:         bool          | 1,
// 	_:         uint          | 5,
// 	cond:      GBA_Condition | 4 }
// GBA_MOVE_REGISTER_TO_STATUS_REGISTER_OPCODE::      0b00000001_00100000_00000000_00000000
// GBA_MOVE_REGISTER_TO_STATUS_REGISTER_OPCODE_MASK:: 0b00001111_10110000_00000000_00010000
// gba_verify_move_register_to_status_register_opcode:: proc(ins: GBA_Move_Register_To_Status_Register_Instruction) -> bool {
// 	return (i32(ins) & GBA_MOVE_REGISTER_TO_STATUS_REGISTER_OPCODE_MASK) == GBA_MOVE_REGISTER_TO_STATUS_REGISTER_OPCODE }
// GBA_Move_Branch_And_Exchange_Instruction:: bit_field u32 {
// 	rm:        GBA_Logical_Register_Name | 4,
// 	_:         uint                      | 4,
// 	sbo_0:     uint                      | 4,
// 	sbo_1:     uint                      | 4,
// 	sbo_2:     uint                      | 4,
// 	_:         uint                      | 8,
// 	cond:      GBA_Condition             | 4 }
// GBA_BRANCH_AND_EXCHANGE_OPCODE::      0b00000001_00100000_00000000_00010000
// GBA_BRANCH_AND_EXCHANGE_OPCODE_MASK:: 0b00001111_11110000_00000000_11110000
// gba_verify_branch_and_exchange_opcode:: proc(ins: GBA_Move_Branch_And_Exchange_Instruction) -> bool {
// 	return (i32(ins) & GBA_BRANCH_AND_EXCHANGE_OPCODE_MASK) == GBA_BRANCH_AND_EXCHANGE_OPCODE }
// GBA_Load_Store_Immediate_Offset_Instruction:: bit_field u32 {
// 	immediate: uint                      | 12,
// 	rd:        GBA_Logical_Register_Name | 4,
// 	rn:        GBA_Logical_Register_Name | 4,
// 	l:         bool                      | 1,
// 	w:         bool                      | 1,
// 	b:         bool                      | 1,
// 	u:         bool                      | 1,
// 	p:         bool                      | 1,
// 	_:         uint                      | 3,
// 	cond:      GBA_Condition             | 4 }
// GBA_LOAD_STORE_IMMEDIATE_OFFSET_OPCODE::      0b00000100_00000000_00000000_00000000
// GBA_LOAD_STORE_IMMEDIATE_OFFSET_OPCODE_MASK:: 0b00001110_00000000_00000000_00000000
// gba_verify_load_store_immediate_offset_opcode:: proc(ins: GBA_Load_Store_Immediate_Offset_Instruction) -> bool {
// 	return (i32(ins) & GBA_LOAD_STORE_IMMEDIATE_OFFSET_OPCODE_MASK) == GBA_LOAD_STORE_IMMEDIATE_OFFSET_OPCODE }
// GBA_Load_Store_Register_Offset_Instruction:: bit_field u32 {
// 	rm:              GBA_Logical_Register_Name | 4,
// 	_:               uint                      | 1,
// 	shift:           uint                      | 2,
// 	shift_immediate: uint                      | 5,
// 	rd:              GBA_Logical_Register_Name | 4,
// 	rn:              GBA_Logical_Register_Name | 4,
// 	l:               bool                      | 1,
// 	w:               bool                      | 1,
// 	b:               bool                      | 1,
// 	u:               bool                      | 1,
// 	p:               bool                      | 1,
// 	_:               uint                      | 3,
// 	cond:            GBA_Condition             | 4 }
// GBA_LOAD_STORE_REGISTER_OFFSET_OPCODE::      0b00000110_00000000_00000000_00000000
// GBA_LOAD_STORE_REGISTER_OFFSET_OPCODE_MASK:: 0b00001110_00000000_00000000_00010000
// gba_verify_load_store_register_offset_opcode:: proc(ins: GBA_Load_Store_Register_Offset_Instruction) -> bool {
// 	return (i32(ins) & GBA_LOAD_STORE_REGISTER_OFFSET_OPCODE_MASK) == GBA_LOAD_STORE_REGISTER_OFFSET_OPCODE }
// GBA_Load_Store_Halfword_Signed_Byte_Instruction:: bit_field u32 {
// 	lo_offset:       uint                      | 4,
// 	_:               uint                      | 1,
// 	h:               bool                      | 1,
// 	set_condition_codes:               bool                      | 1,
// 	_:               uint                      | 1,
// 	hi_offset:       uint                      | 4,
// 	rd:              GBA_Logical_Register_Name | 4,
// 	rn:              GBA_Logical_Register_Name | 4,
// 	l:               bool                      | 1,
// 	w:               bool                      | 1,
// 	_:               uint                      | 1,
// 	u:               bool                      | 1,
// 	p:               bool                      | 1,
// 	_:               uint                      | 3,
// 	cond:            GBA_Condition             | 4 }
// GBA_LOAD_STORE_HALFWORD_SIGNED_BYTE_OPCODE::      0b00000000_01000000_00000000_10010000
// GBA_LOAD_STORE_HALFWORD_SIGNED_BYTE_OPCODE_MASK:: 0b00001110_01000000_00000000_10010000
// gba_verify_load_store_halfword_signed_byte_opcode:: proc(ins: GBA_Load_Store_Halfword_Signed_Byte_Instruction) -> bool {
// 	return (i32(ins) & GBA_LOAD_STORE_HALFWORD_SIGNED_BYTE_OPCODE_MASK) == GBA_LOAD_STORE_HALFWORD_SIGNED_BYTE_OPCODE }
// GBA_Swap_Instruction:: bit_field u32 {
// 	rm:              GBA_Logical_Register_Name | 4,
// 	_:               uint                      | 4,
// 	sbz:             uint                      | 4,
// 	rd:              GBA_Logical_Register_Name | 4,
// 	rn:              GBA_Logical_Register_Name | 4,
// 	_:               uint                      | 2,
// 	b:               bool                      | 1,
// 	_:               uint                      | 5,
// 	cond:            GBA_Condition             | 4 }
// GBA_SWAP_OPCODE::      0b00000001_00000000_00000000_10010000
// GBA_SWAP_OPCODE_MASK:: 0b00001111_10110000_00000000_11110000
// gba_verify_swap_opcode:: proc(ins: GBA_Swap_Instruction) -> bool {
// 	return (i32(ins) & GBA_SWAP_OPCODE_MASK) == GBA_SWAP_OPCODE }
// GBA_Load_Store_Multiple_Instruction:: bit_field u32 {
// 	register_list:   uint                      | 16,
// 	rn:              GBA_Logical_Register_Name | 4,
// 	l:               bool                      | 1,
// 	w:               bool                      | 1,
// 	set_condition_codes:               bool                      | 1,
// 	u:               bool                      | 1,
// 	p:               bool                      | 1,
// 	_:               uint                      | 3,
// 	cond:            GBA_Condition             | 4 }
// GBA_LOAD_STORE_MULTIPLE_OPCODE::      0b00001000_00000000_00000000_00000000
// GBA_LOAD_STORE_MULTIPLE_OPCODE_MASK:: 0b00001110_00000000_00000000_00000000
// gba_verify_load_store_multiple_opcode:: proc(ins: GBA_Load_Store_Multiple_Instruction) -> bool {
// 	return (i32(ins) & GBA_LOAD_STORE_MULTIPLE_OPCODE_MASK) == GBA_LOAD_STORE_MULTIPLE_OPCODE }
// GBA_Coprocessor_Data_Processing_Instruction:: bit_field u32 {
// 	crm:    uint          | 4,
// 	_:      uint          | 1,
// 	op2:    uint          | 3,
// 	cp_num: uint          | 4,
// 	crd:    uint          | 4,
// 	crn:    uint          | 4,
// 	opcode_1:    uint          | 4,
// 	_:      uint          | 4,
// 	cond:   GBA_Condition | 4 }
// GBA_COPROCESSOR_DATA_PROCESSING_OPCODE::      0b00001110_00000000_00000000_00000000
// GBA_COPROCESSOR_DATA_PROCESSING_OPCODE_MASK:: 0b00001111_00000000_00000000_00010000
// gba_verify_coprocessor_data_processing_opcode:: proc(ins: GBA_Coprocessor_Data_Processing_Instruction) -> bool {
// 	return (i32(ins) & GBA_COPROCESSOR_DATA_PROCESSING_OPCODE_MASK) == GBA_COPROCESSOR_DATA_PROCESSING_OPCODE }
// GBA_Coprocessor_Register_Transfers_Instruction:: bit_field u32 {
// 	crm:    uint                      | 4,
// 	_:      uint                      | 1,
// 	opcode_2:    uint                      | 3,
// 	cp_num: uint                      | 4,
// 	rd:     GBA_Logical_Register_Name | 4,
// 	crn:    uint                      | 4,
// 	l:      bool                      | 1,
// 	opcode_1:    uint                      | 3,
// 	_:      uint                      | 4,
// 	cond:   GBA_Condition             | 4 }
// GBA_COPROCESSOR_REGISTER_TRANSFERS_OPCODE::      0b00001110_00000000_00000000_00010000
// GBA_COPROCESSOR_REGISTER_TRANSFERS_OPCODE_MASK:: 0b00001111_00000000_00000000_00010000
// gba_verify_coprocessor_register_transfers_opcode:: proc(ins: GBA_Coprocessor_Register_Transfers_Instruction) -> bool {
// 	return (i32(ins) & GBA_COPROCESSOR_REGISTER_TRANSFERS_OPCODE_MASK) == GBA_COPROCESSOR_REGISTER_TRANSFERS_OPCODE }
// GBA_Coprocessor_Load_Store_Instruction:: bit_field u32 {
// 	offset: uint                      | 8,
// 	cp_num: uint                      | 4,
// 	crd:    uint                      | 4,
// 	rn:     GBA_Logical_Register_Name | 4,
// 	l:      bool                      | 1,
// 	w:      bool                      | 1,
// 	n:      bool                      | 1,
// 	u:      bool                      | 1,
// 	p:      bool                      | 1,
// 	_:      uint                      | 3,
// 	cond:   GBA_Condition             | 4 }
// GBA_COPROCESSOR_LOAD_STORE_OPCODE::      0b00001100_00000000_00000000_00000000
// GBA_COPROCESSOR_LOAD_STORE_OPCODE_MASK:: 0b00001110_00000000_00000000_00000000
// gba_verify_coprocessor_load_store_opcode:: proc(ins: GBA_Coprocessor_Load_Store_Instruction) -> bool {
// 	return (i32(ins) & GBA_COPROCESSOR_LOAD_STORE_OPCODE_MASK) == GBA_COPROCESSOR_LOAD_STORE_OPCODE }
// GBA_Branch_Instruction:: bit_field u32 {
// 	offset: uint          | 24,
// 	l:      bool          | 1,
// 	_:      uint          | 3,
// 	cond:   GBA_Condition | 4 }
// GBA_BRANCH_OPCODE::      0b00001010_00000000_00000000_00000000
// GBA_BRANCH_OPCODE_MASK:: 0b00001110_00000000_00000000_00000000
// gba_verify_branch_opcode:: proc(ins: GBA_Branch_Instruction) -> bool {
// 	return (i32(ins) & GBA_BRANCH_OPCODE_MASK) == GBA_BRANCH_OPCODE }
// GBA_Software_Interrupt_Instruction:: bit_field u32 {
// 	swi_number: uint          | 24,
// 	_:          uint          | 4,
// 	cond:       GBA_Condition | 4 }
// GBA_SOFTWARE_INTERRUPT_OPCODE::      0b00001111_00000000_00000000_00000000
// GBA_SOFTWARE_INTERRUPT_OPCODE_MASK:: 0b00001111_00000000_00000000_00000000
// gba_verify_software_interrupt_opcode:: proc(ins: GBA_Software_Interrupt_Instruction) -> bool {
// 	return (i32(ins) & GBA_SOFTWARE_INTERRUPT_OPCODE_MASK) == GBA_SOFTWARE_INTERRUPT_OPCODE }
// GBA_Undefined_Instruction:: bit_field u32 {
// 	_:    uint          | 28,
// 	cond: GBA_Condition | 4 }
// GBA_UNDEFINED_OPCODE::      0b00000110_00000000_00000000_00010000
// GBA_UNDEFINED_OPCODE_MASK:: 0b00001110_00000000_00000000_00010000
// gba_verify_undefined_opcode:: proc(ins: GBA_Undefined_Instruction) -> bool {
// 	return (i32(ins) & GBA_UNDEFINED_OPCODE_MASK) == GBA_UNDEFINED_OPCODE }


// INSTRUCTIONS //
GBA_Instruction_Identified:: union {
	GBA_ADC_Instruction,
	GBA_ADD_Instruction,
	GBA_AND_Instruction,
	GBA_B_Instruction,
	GBA_BL_Instruction,
	GBA_BIC_Instruction,
	GBA_BX_Instruction,
	GBA_CDP_Instruction,
	GBA_CMN_Instruction,
	GBA_CMP_Instruction,
	GBA_EOR_Instruction,
	GBA_LDC_Instruction,
	GBA_LDM_Instruction,
	GBA_LDR_Instruction,
	GBA_LDRB_Instruction,
	GBA_LDRBT_Instruction,
	GBA_LDRH_Instruction,
	GBA_LDRSB_Instruction,
	GBA_LDRSH_Instruction,
	GBA_LDRT_Instruction,
	GBA_MCR_Instruction,
	GBA_MLA_Instruction,
	GBA_MOV_Instruction,
	GBA_MRC_Instruction,
	GBA_MRS_Instruction,
	GBA_MSR_Instruction,
	GBA_MUL_Instruction,
	GBA_MVN_Instruction,
	GBA_ORR_Instruction,
	GBA_RSB_Instruction,
	GBA_RSC_Instruction,
	GBA_SBC_Instruction,
	GBA_SMLAL_Instruction,
	GBA_SMULL_Instruction,
	GBA_STM_Instruction,
	GBA_STR_Instruction,
	GBA_STRB_Instruction,
	GBA_STRBT_Instruction,
	GBA_STRH_Instruction,
	GBA_STRT_Instruction,
	GBA_SUB_Instruction,
	GBA_SWI_Instruction,
	GBA_SWP_Instruction,
	GBA_SWPB_Instruction,
	GBA_TEQ_Instruction,
	GBA_TST_Instruction,
	GBA_UMLAL_Instruction,
	GBA_UMULL_Instruction }
GBA_Branch_and_Link_Instruction:: union {
	GBA_B_Instruction,
	GBA_BL_Instruction }
GBA_Branch_and_Exchange_Instructio:: union {
	GBA_BX_Instruction }
GBA_Data_Processing_Instruction:: union {
	GBA_ADC_Instruction,
	GBA_ADD_Instruction,
	GBA_AND_Instruction,
	GBA_BIC_Instruction,
	GBA_CMN_Instruction,
	GBA_CMP_Instruction,
	GBA_EOR_Instruction,
	GBA_MOV_Instruction,
	GBA_MRS_Instruction,
	GBA_MSR_Instruction,
	GBA_MVN_Instruction,
	GBA_ORR_Instruction,
	GBA_RSB_Instruction,
	GBA_RSC_Instruction,
	GBA_SBC_Instruction,
	GBA_SUB_Instruction,
	GBA_TEQ_Instruction,
	GBA_TST_Instruction }
GBA_Multiply_and_Multiply_Accumulate_Instruction:: union {
	GBA_MLA_Instruction,
	GBA_MUL_Instruction,
	GBA_SMLAL_Instruction,
	GBA_SMULL_Instruction,
	GBA_UMLAL_Instruction,
	GBA_UMULL_Instruction }
GBA_Load_Register_Instruction:: union {
	GBA_LDR_Instruction,
	GBA_LDRB_Instruction,
	GBA_LDRBT_Instruction,
	GBA_LDRH_Instruction,
	GBA_LDRSB_Instruction,
	GBA_LDRSH_Instruction,
	GBA_LDRT_Instruction }
GBA_Store_Register_Instruction:: union {
	GBA_STR_Instruction,
	GBA_STRB_Instruction,
	GBA_STRBT_Instruction,
	GBA_STRH_Instruction,
	GBA_STRT_Instruction }
GBA_Load_Multiple_Register_Instruction:: union {
	GBA_LDM_Instruction }
GBA_Store_Multiple_Register_Instruction:: union {
	GBA_STM_Instruction }
GBA_Data_Swap_Instruction:: union {
	GBA_SWP_Instruction,
	GBA_SWPB_Instruction }
GBA_Software_Interrupt_Instruction:: union {
	GBA_SWI_Instruction }
// TODO Since the GBA doesn't have a coprocessor, executing any of the coprocessor instrucitons should trigger an Undefined Instruction exception.
//      They don't need behaviour, but their layout still needs to be defined, so they can be identified.
GBA_ADC_Instruction:: bit_field u32 { // Add with Carry / Data Processing / Addressing Mode 1 //
	shifter_operand:     u32                       | 12,
	rd:                  GBA_Logical_Register_Name | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	set_condition_codes: bool                      | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_ADC_CODE_MASK:: 0b00001101_11100000_00000000_00000000
GBA_ADC_CODE::      0b00000000_10100000_00000000_00000000
gba_instruction_is_ADC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_ADC_CODE_MASK) == GBA_ADC_CODE }
GBA_ADC_OPCODE:: 0b0101
gba_ADC_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_ADC_Instruction(ins).opcode == GBA_ADC_OPCODE }
GBA_ADC_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_ADD_Instruction:: bit_field u32 { // Add / Data Processing / Addressing Mode 1 //
	shifter_operand:     u32                       | 12,
	rd:                  GBA_Logical_Register_Name | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	set_condition_codes: bool                      | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_ADD_CODE_MASK:: 0b00001101_11100000_00000000_00000000
GBA_ADD_CODE::      0b00000000_10000000_00000000_00000000
gba_instruction_is_ADD:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_ADD_CODE_MASK) == GBA_ADD_CODE }
GBA_ADD_OPCODE:: 0b0100
gba_ADD_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_ADD_Instruction(ins).opcode == GBA_ADD_OPCODE }
GBA_ADD_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_AND_Instruction:: bit_field u32 { // And / Data Processing / Addressing Mode 1 //
	shifter_operand:     u32                       | 12,
	rd:                  GBA_Logical_Register_Name | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	set_condition_codes: bool                      | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_AND_CODE_MASK:: 0b00001101_11100000_00000000_00000000
GBA_AND_CODE::      0b00000000_00000000_00000000_00000000
gba_instruction_is_AND:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_AND_CODE_MASK) == GBA_AND_CODE }
GBA_AND_OPCODE:: 0b0000
gba_AND_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_AND_Instruction(ins).opcode == GBA_AND_OPCODE }
GBA_AND_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_B_Instruction:: bit_field u32 { // Branch / Branch //
	signed_offset: uint          | 24,
	_:        uint          | 4,
	cond:          GBA_Condition | 4 }
GBA_B_CODE_MASK:: 0b00001111_00000000_00000000_00000000
GBA_B_CODE::      0b00001010_00000000_00000000_00000000
gba_instruction_is_B:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_B_CODE_MASK) == GBA_B_CODE }
GBA_BL_Instruction:: bit_field u32 { // Branch and Link / Branch //
	signed_offset: uint          | 24,
	_:        uint          | 4,
	cond:          GBA_Condition | 4 }
GBA_BL_CODE_MASK:: 0b00001111_00000000_00000000_00000000
GBA_BL_CODE::      0b00001011_00000000_00000000_00000000
gba_instruction_is_BL:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_BL_CODE_MASK) == GBA_BL_CODE }
GBA_BIC_Instruction:: bit_field u32 { // Bit Clear / Data Processing //
	shifter_operand:     uint                      | 12,
	rd:                  GBA_Logical_Register_Name | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	set_condition_codes: bool                      | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_BIC_CODE_MASK:: 0b00001101_11100000_00000000_00000000
GBA_BIC_CODE::      0b00000001_11000000_00000000_00000000
gba_instruction_is_BIC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_BIC_CODE_MASK) == GBA_BIC_CODE }
GBA_BIC_OPCODE:: 0b1110
gba_BIC_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_BIC_Instruction(ins).opcode == GBA_BIC_OPCODE }
GBA_BX_Instruction:: bit_field u32 { // Branch and Exchange instructions set / Branch //
	rm:     GBA_Logical_Register_Name | 4,
	_:      uint                      | 4,
	sbo:    uint                      | 12,
	_:      uint                      | 8,
	cond:   GBA_Condition             | 4 }
GBA_BX_CODE_MASK:: 0b00001111_11110000_00000000_11110000
GBA_BX_CODE::      0b00000001_00100000_00000000_00010000
gba_instruction_is_BX:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_BX_CODE_MASK) == GBA_BX_CODE }
GBA_CDP_Instruction:: bit_field u32 { // Coprocessor Data Processing / Coprocessor //
	_:    uint          | 28,
	cond: GBA_Condition | 4 }
GBA_CDP_CODE_MASK:: 0b00001111_00000000_00000000_00010000
GBA_CDP_CODE::      0b00001110_00000000_00000000_00000000
gba_instruction_is_CDP:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_CDP_CODE_MASK) == GBA_CDP_CODE }
GBA_CMN_Instruction:: bit_field u32 { // Compare Negative / Data Processing / Addressing Mode 1 //
	shifter_operand:   uint                      | 12,
	sbz:               uint                      | 4,
	rn:                GBA_Logical_Register_Name | 4,
	_:                 uint                      | 1,
	opcode:            uint                      | 4,
	immediate_shifter: bool                      | 1,
	_:                 uint                      | 2,
	cond:              GBA_Condition             | 4 }
GBA_CMN_CODE_MASK:: 0b00001101_11110000_00000000_00000000
GBA_CMN_CODE::      0b00000001_01110000_00000000_00000000
gba_instruction_is_CMN:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_CMN_CODE_MASK) == GBA_CMN_CODE }
GBA_CMN_OPCODE:: 0b1011
gba_CMN_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_CMN_Instruction(ins).opcode == GBA_CMN_OPCODE }
GBA_CMN_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_CMP_Instruction:: bit_field u32 { // Compare / Data Processing / Addressing Mode 1 //
	shifter_operand:   uint                      | 12,
	sbz:               uint                      | 4,
	rn:                GBA_Logical_Register_Name | 4,
	_:                 uint                      | 1,
	opcode:            uint                      | 4,
	immediate_shifter: bool                      | 1,
	_:                 uint                      | 2,
	cond:              GBA_Condition             | 4 }
GBA_CMP_CODE_MASK:: 0b00001101_11110000_00000000_00000000
GBA_CMP_CODE::      0b00000001_01010000_00000000_00000000
gba_instruction_is_CMP:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_CMP_CODE_MASK) == GBA_CMP_CODE }
GBA_CMP_OPCODE:: 0b1010
gba_CMP_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_CMP_Instruction(ins).opcode == GBA_CMP_OPCODE }
GBA_CMP_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_EOR_Instruction:: bit_field u32 { // Exclusive-OR / Data Processing / Addressing Mode 1 //
	shifter_operand:     uint                      | 12,
	rd:                  GBA_Logical_Register_Name | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	set_condition_codes: bool                      | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_EOR_CODE_MASK:: 0b00001101_11100000_00000000_00000000
GBA_EOR_CODE::      0b00000000_00100000_00000000_00000000
gba_instruction_is_EOR:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_EOR_CODE_MASK) == GBA_EOR_CODE }
GBA_EOR_OPCODE:: 0b0001
gba_EOR_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_EOR_Instruction(ins).opcode == GBA_EOR_OPCODE }
GBA_EOR_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_LDC_Instruction:: bit_field u32 { // Load Coprocessor / Coprocessor //
	_:    uint          | 28,
	cond: GBA_Condition | 4 }
GBA_LDC_CODE_MASK:: 0b00001110_00010000_00000000_00000000
GBA_LDC_CODE::      0b00001100_00010000_00000000_00000000
gba_instruction_is_LDC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDC_CODE_MASK) == GBA_LDC_CODE }
GBA_LDC_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_5
GBA_LDM_Instruction:: bit_field u32 { // Load Multiple / Load and Store Multiple / Addressing Mode 4 //
	register_list: uint                      | 16,
	rn:            GBA_Logical_Register_Name | 4,
	_:             uint                      | 1,
	w:             bool                      | 1,
	_:             uint                      | 1,
	u:             bool                      | 1,
	p:             bool                      | 1,
	_:             uint                      | 3,
	cond:          GBA_Condition             | 4 }
GBA_LDM_CODE_MASK:: 0b00001110_00010000_00000000_00000000
GBA_LDM_CODE::      0b00001000_00010000_00000000_00000000
gba_instruction_is_LDM:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDM_CODE_MASK) == GBA_LDM_CODE }
GBA_LDM_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_4
GBA_LDR_Instruction:: bit_field u32 { // Load Register / Load and Store / Addressing Mode 2 //
	address: uint                      | 12,
	rd:                       GBA_Logical_Register_Name | 4,
	rn:                       GBA_Logical_Register_Name | 4,
	_:                        uint                      | 1,
	w:                        bool                      | 1,
	_:                        uint                      | 1,
	u:                        bool                      | 1,
	p:                        bool                      | 1,
	immediate_shifter:        bool                      | 1,
	_:                        uint                      | 2,
	cond:                     GBA_Condition             | 4 }
GBA_LDR_CODE_MASK:: 0b00001100_01010000_00000000_00000000
GBA_LDR_CODE::      0b00000100_00010000_00000000_00000000
gba_instruction_is_LDR:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDR_CODE_MASK) == GBA_LDR_CODE }
GBA_LDR_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_LDRB_Instruction:: bit_field u32 { // Load Register Byte / Load and Store / Addressing Mode 2 //
	address: uint                      | 12,
	rd:                       GBA_Logical_Register_Name | 4,
	rn:                       GBA_Logical_Register_Name | 4,
	_:                        uint                      | 1,
	w:                        bool                      | 1,
	_:                        uint                      | 1,
	u:                        bool                      | 1,
	p:                        bool                      | 1,
	immediate_shifter:        bool                      | 1,
	_:                        uint                      | 2,
	cond:                     GBA_Condition             | 4 }
GBA_LDRB_CODE_MASK:: 0b00001100_01010000_00000000_00000000
GBA_LDRB_CODE::      0b00000100_01010000_00000000_00000000
gba_instruction_is_LDRB:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDRB_CODE_MASK) == GBA_LDRB_CODE }
GBA_LDRB_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_LDRBT_Instruction:: bit_field u32 { // Load Register Byte with Translation / Load and Store / Addressing Mode 2 //
	address: uint                      | 12,
	rd:                       GBA_Logical_Register_Name | 4,
	rn:                       GBA_Logical_Register_Name | 4,
	_:                        uint                      | 3,
	u:                        bool                      | 1,
	_:                        uint                      | 1,
	immediate_shifter:        bool                      | 1,
	_:                        uint                      | 2,
	cond:                     GBA_Condition             | 4 }
GBA_LDRBT_CODE_MASK:: 0b00001101_01110000_00000000_00000000
GBA_LDRBT_CODE::      0b00000100_01110000_00000000_00000000
gba_instruction_is_LDRBT:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDRBT_CODE_MASK) == GBA_LDRBT_CODE }
GBA_LDRBT_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_LDRH_Instruction:: bit_field u32 { // Load Register Halfword / Load and Store / Addressing Mode 3 //
	address_0: uint                      | 4,
	_: uint | 4,
	address_1: uint | 4,
	rd: GBA_Logical_Register_Name | 4,
	rn:                       GBA_Logical_Register_Name | 4,
	_: uint | 1,
	w: bool | 1,
	immediate_shifter: bool | 1,
	u: bool | 1,
	p: bool | 1,
	_: uint | 3,
	cond:                     GBA_Condition             | 4 }
GBA_LDRH_CODE_MASK:: 0b00001110_00010000_00000000_11110000
GBA_LDRH_CODE::      0b00000000_00010000_00000000_10110000
gba_instruction_is_LDRH:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDRH_CODE_MASK) == GBA_LDRH_CODE }
GBA_LDRH_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_3
GBA_LDRSB_Instruction:: bit_field u32 { // Load Register Signed Byte / Load and Store / Addressing Mode 2 //
	address_0: uint                      | 4,
	_: uint | 4,
	address_1: uint | 4,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 1,
	w: bool | 1,
	immediate_shifter: bool | 1,
	u: bool | 1,
	p: bool | 1,
	_: uint | 3,
	cond:                     GBA_Condition             | 4 }
GBA_LDRSB_CODE_MASK:: 0b00001110_00010000_00000000_11110000
GBA_LDRSB_CODE::      0b00000000_00010000_00000000_11010000
gba_instruction_is_LDRSB:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDRSB_CODE_MASK) == GBA_LDRSB_CODE }
GBA_LDRSB_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_3
GBA_LDRSH_Instruction:: bit_field u32 { // Load Register Signed Halfword / Load and Store / Addressing Mode 3 //
	address_0: uint                      | 4,
	_: uint | 4,
	address_1: uint | 4,
	rd: GBA_Logical_Register_Name | 4,
	rn:                       GBA_Logical_Register_Name | 4,
	_: uint | 1,
	w: bool | 1,
	immediate_shifter: bool | 1,
	u: bool | 1,
	p: bool | 1,
	_: uint | 3,
	cond:                     GBA_Condition             | 4 }
GBA_LDRSH_CODE_MASK:: 0b00001110_00010000_00000000_11110000
GBA_LDRSH_CODE::      0b00000000_00010000_00000000_11110000
gba_instruction_is_LDRSH:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDRSH_CODE_MASK) == GBA_LDRSH_CODE }
GBA_LDRSH_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_3
GBA_LDRT_Instruction:: bit_field u32 { // Load Register with Translation / Load and Store / Addressing Mode 2 //
	address: uint                      | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 3,
	u: bool | 1,
	_: uint | 1,
	immediate_shifter: bool | 1,
	_: uint | 2,
	cond:                     GBA_Condition             | 4 }
GBA_LDRT_CODE_MASK:: 0b00001101_01110000_00000000_00000000
GBA_LDRT_CODE::      0b00000100_00110000_00000000_00000000
gba_instruction_is_LDRT:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_LDRT_CODE_MASK) == GBA_LDRT_CODE }
GBA_LDRT_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_MCR_Instruction:: bit_field u32 { // Move to Coprocessor / Coprocessor //
	_:    uint          | 28,
	cond: GBA_Condition | 4 }
GBA_MCR_CODE_MASK:: 0b00001111_00010000_00000000_00010000
GBA_MCR_CODE::      0b00001110_00000000_00000000_00010000
gba_instruction_is_MCR:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MCR_CODE_MASK) == GBA_MCR_CODE }
GBA_MLA_Instruction:: bit_field u32 { // Multiply Accumulate / Multiply //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	rs: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	rd: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	_: uint | 7,
	cond: GBA_Condition | 4 }
GBA_MLA_CODE_MASK:: 0b00001111_11100000_00000000_11110000
GBA_MLA_CODE::      0b00000000_00100000_00000000_10010000
gba_instruction_is_MLA:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MLA_CODE_MASK) == GBA_MLA_CODE }
GBA_MOV_Instruction:: bit_field u32 { // Move / Data Processing / Addressing Mode 1 //
	shifter_operand: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	sbz: uint | 4,
	set_condition_codes: bool | 1,
	opcode: uint | 4,
	immediate_shifter: bool | 1,
	_: uint | 2,
	cond:                GBA_Condition             | 4 }
GBA_MOV_CODE_MASK:: 0b00001101_11100000_00000000_00000000
GBA_MOV_CODE::      0b00000001_10100000_00000000_00000000
gba_instruction_is_MOV:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MOV_CODE_MASK) == GBA_MOV_CODE }
GBA_MOV_OPCODE:: 0b1101
gba_MOV_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_MOV_Instruction(ins).opcode == GBA_MOV_OPCODE }
GBA_MOV_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_MRC_Instruction:: bit_field u32 { // Move from Coprocessor / Coprocessor //
	_:    uint          | 28,
	cond: GBA_Condition | 4 }
GBA_MRC_CODE_MASK:: 0b00001111_00010000_00000000_00010000
GBA_MRC_CODE::      0b00001110_00010000_00000000_00010000
gba_instruction_is_MRC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MRC_CODE_MASK) == GBA_MRC_CODE }
GBA_MRC_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_4
GBA_MRS_Instruction:: bit_field u32 { // Move from Status Register / Status Register Access //
	sbz: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	sbo: uint | 4,
	_: uint | 2,
	r: bool | 1,
	_: uint | 5,
	cond: GBA_Condition | 4 }
GBA_MRS_CODE_MASK:: 0b00001111_10110000_00000000_00000000
GBA_MRS_CODE::      0b00000001_00000000_00000000_00000000
gba_instruction_is_MRS:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MRS_CODE_MASK) == GBA_MRS_CODE }
GBA_MSR_Instruction:: bit_field u32 { // Move to Status Register / Status Register Access //
	operand: uint | 12,
	sbo: uint | 4,
	field_mask: uint | 4,
	_: uint | 2,
	r: bool | 1,
	_: uint | 5,
	cond: GBA_Condition | 4 }
GBA_MSR_CODE_MASK:: 0b00001101_10110000_00000000_00000000
GBA_MSR_CODE::      0b00000001_00100000_00000000_00000000
gba_instruction_is_MSR:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MSR_CODE_MASK) == GBA_MSR_CODE }
GBA_MUL_Instruction:: bit_field u32 { // Multiply / Multiply //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	rs: GBA_Logical_Register_Name | 4,
	sbz: uint | 4,
	rn: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	_: uint | 7,
	cond: GBA_Condition | 4 }
GBA_MUL_CODE_MASK:: 0b00001111_11100000_00000000_11110000
GBA_MUL_CODE::      0b00000000_00000000_00000000_10010000
gba_instruction_is_MUL:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MUL_CODE_MASK) == GBA_MUL_CODE }
GBA_MVN_Instruction:: bit_field u32 { // Move Negative / Data Processing / Addressing Mode 1 //
	shifter_operand: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	sbz: uint | 4,
	set_condition_codes: bool | 1,
	opcode: uint | 4,
	immediate_shifter: bool | 1,
	_: uint | 2,
	cond:                GBA_Condition             | 4 }
GBA_MVN_CODE_MASK:: 0b_00001101_11100000_00000000_00000000
GBA_MVN_CODE::      0b_00000001_11100000_00000000_00000000
gba_instruction_is_MVN:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_MVN_CODE_MASK) == GBA_MVN_CODE }
GBA_MVN_OPCODE:: 0b1111
gba_MVN_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_MVN_Instruction(ins).opcode == GBA_MVN_OPCODE }
GBA_MVN_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_ORR_Instruction:: bit_field u32 { // Logical OR / Data Processing / Addressing Mode 1 //
	shifter_operand: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	opcode: uint | 4,
	_: uint | 2,
	cond:                GBA_Condition             | 4 }
GBA_ORR_CODE_MASK:: 0b_00001101_11100000_00000000_00000000
GBA_ORR_CODE::      0b_00000001_10000000_00000000_00000000
gba_instruction_is_ORR:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_ORR_CODE_MASK) == GBA_ORR_CODE }
GBA_ORR_OPCODE:: 0b1100
gba_ORR_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_ORR_Instruction(ins).opcode == GBA_ORR_OPCODE }
GBA_ORR_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_RSB_Instruction:: bit_field u32 { // Reverse Subtract / Data Processing / Addressing Mode 1 //
	shifter_operand: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	opcode: uint | 4,
	_: uint | 2,
	cond:                GBA_Condition             | 4 }
GBA_RSB_CODE_MASK:: 0b_00001101_11100000_00000000_00000000
GBA_RSB_CODE::      0b_00000000_01100000_00000000_00000000
gba_instruction_is_RSB:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_RSB_CODE_MASK) == GBA_RSB_CODE }
GBA_RSB_OPCODE:: 0b0011
gba_RSB_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_RSB_Instruction(ins).opcode == GBA_RSB_OPCODE }
GBA_RSB_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_RSC_Instruction:: bit_field u32 { // Reverse Subtract with Carry / Data Processing / Addressing Mode 1 //
	shifter_operand: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	opcode: uint | 4,
	_: uint | 2,
	cond:                GBA_Condition             | 4 }
GBA_RSC_CODE_MASK:: 0b_00001101_11100000_00000000_00000000
GBA_RSC_CODE::      0b_00000000_11100000_00000000_00000000
gba_instruction_is_RSC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_RSC_CODE_MASK) == GBA_RSC_CODE }
GBA_RSC_OPCODE:: 0b0111
gba_RSC_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_RSC_Instruction(ins).opcode == GBA_RSC_OPCODE }
GBA_RSC_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_SBC_Instruction:: bit_field u32 { // Subtract with Carry / Data Processing / Addressing Mode 1 //
	shifter_operand: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	opcode: uint | 4,
	_: uint | 2,
	cond:                GBA_Condition             | 4 }
GBA_SBC_CODE_MASK:: 0b_00001101_11100000_00000000_00000000
GBA_SBC_CODE::      0b_00000000_11000000_00000000_00000000
gba_instruction_is_SBC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SBC_CODE_MASK) == GBA_SBC_CODE }
GBA_SBC_OPCODE:: 0b0110
gba_SBC_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_SBC_Instruction(ins).opcode == GBA_SBC_OPCODE }
GBA_SBC_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_SMLAL_Instruction:: bit_field u32 { // Signed Multiply Accumulate Long / Multiply //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	rs: GBA_Logical_Register_Name | 4,
	rd_lo: GBA_Logical_Register_Name | 4,
	rd_hi: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	_: uint | 7,
	cond: GBA_Condition | 4 }
GBA_SMLAL_CODE_MASK:: 0b_00001111_11100000_00000000_11110000
GBA_SMLAL_CODE::      0b_00000000_11100000_00000000_10010000
gba_instruction_is_SMLAL:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SMLAL_CODE_MASK) == GBA_SMLAL_CODE }
GBA_SMULL_Instruction:: bit_field u32 { // Signed Multiply Long / Multiply //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	rs: GBA_Logical_Register_Name | 4,
	rd_lo: GBA_Logical_Register_Name | 4,
	rd_hi: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	_: uint | 7,
	cond: GBA_Condition | 4 }
GBA_SMULL_CODE_MASK:: 0b_00001111_11100000_00000000_11110000
GBA_SMULL_CODE::      0b_00000000_11000000_00000000_10010000
gba_instruction_is_SMULL:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SMULL_CODE_MASK) == GBA_SMULL_CODE }
GBA_STC_Instruction:: bit_field u32 { // Store Coprocessor / Coprocessor //
	_:    uint          | 28,
	cond: GBA_Condition | 4 }
GBA_STC_CODE_MASK:: 0b_00001110_00010000_00000000_00000000
GBA_STC_CODE::      0b_00001100_00000000_00000000_00000000
gba_instruction_is_STC:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_STC_CODE_MASK) == GBA_STC_CODE }
GBA_STC_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_5
GBA_STM_Instruction:: bit_field u32 { // Store Multiple / Load and Store / Addressing Mode 4 //
	register_list: uint | 16,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 3,
	u: bool | 1,
	p: bool | 1,
	_: uint | 3,
	cond:                     GBA_Condition             | 4 }
GBA_STM_CODE_MASK:: 0b_00001110_00010000_00000000_00000000
GBA_STM_CODE::      0b_00001000_00000000_00000000_00000000
gba_instruction_is_STM:: proc(ins: GBA_Instruction) -> bool {
	return ((u32(ins) & GBA_STM_CODE_MASK) == GBA_STM_CODE) &&
		((bits.bitfield_extract(ins, 22, 1) == 1 && bits.bitfield_extract(ins, 20, 1) == 0) || (bits.bitfield_extract(ins, 22, 1) == 0)) }
GBA_STM_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_4
GBA_STR_Instruction:: bit_field u32 { // Store Register / Load and Store / Addressing Mode 2 //
	address: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 1,
	w: bool | 1,
	_: uint | 1,
	u: bool | 1,
	p: bool | 1,
	immediate_shifter: bool | 1,
	_: uint | 2,
	cond:                     GBA_Condition             | 4 }
GBA_STR_CODE_MASK:: 0b_00001100_01010000_00000000_00000000
GBA_STR_CODE::      0b_00000100_00000000_00000000_00000000
gba_instruction_is_STR:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_STR_CODE_MASK) == GBA_STR_CODE }
GBA_STR_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_STRB_Instruction:: bit_field u32 { // Store Register Byte / Load and Store / Addressing Mode 2 //
	address: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 1,
	w: bool | 1,
	_: uint | 1,
	u: bool | 1,
	p: bool | 1,
	immediate_shifter: bool | 1,
	_: uint | 2,
	cond:                     GBA_Condition             | 4 }
GBA_STRB_CODE_MASK:: 0b_00001100_01010000_00000000_00000000
GBA_STRB_CODE::      0b_00000100_01000000_00000000_00000000
gba_instruction_is_STRB:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_STRB_CODE_MASK) == GBA_STRB_CODE }
GBA_STRB_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_STRBT_Instruction:: bit_field u32 { // Store Register Byte with Translation / Load and Store / Addressing Mode 2 //
	address: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 3,
	u: bool | 1,
	_: uint | 1,
	immediate_shifter: bool | 1,
	_: uint | 2,
	cond:                     GBA_Condition             | 4 }
GBA_STRBT_CODE_MASK:: 0b_00001101_01110000_00000000_00000000
GBA_STRBT_CODE::      0b_00000100_01100000_00000000_00000000
gba_instruction_is_STRBT:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_STRBT_CODE_MASK) == GBA_STRBT_CODE }
GBA_STRBT_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_STRH_Instruction:: bit_field u32 { // Store Register Halfword / Load and Store / Addressing Mode 2 //
	address_0: uint | 4,
	_: uint | 4,
	address_1: uint | 4,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 1,
	w: bool | 1,
	immediate_shifter: uint | 1,
	u: bool | 1,
	p: bool | 1,
	_: uint | 3,
	cond:                     GBA_Condition             | 4 }
GBA_STRH_CODE_MASK:: 0b_00001110_00010000_00000000_11110000
GBA_STRH_CODE::      0b_00000000_00000000_00000000_10110000
gba_instruction_is_STRH:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_STRH_CODE_MASK) == GBA_STRH_CODE }
GBA_STRH_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_3
GBA_STRT_Instruction:: bit_field u32 { // Store Register with Translation / Load and Store / Addressing Mode 2 //
	address: uint | 12,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	_: uint | 3,
	u: bool | 1,
	_: uint | 1,
	immediate_shifter: uint | 1,
	_: uint | 2,
	cond:                     GBA_Condition             | 4 }
GBA_STRT_CODE_MASK:: 0b_00001101_01110000_00000000_00000000
GBA_STRT_CODE::      0b_00000100_00100000_00000000_00000000
gba_instruction_is_STRT:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_STRT_CODE_MASK) == GBA_STRT_CODE }
GBA_STRT_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_2
GBA_SUB_Instruction:: bit_field u32 { // Subtract / Data Processing / Addressing Mode 1 //
	shifter_operand:     u32                       | 12,
	rd:                  GBA_Logical_Register_Name | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	set_condition_codes: bool                      | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_SUB_CODE_MASK:: 0b_00001101_11100000_00000000_00000000
GBA_SUB_CODE::      0b_00000000_01000000_00000000_00000000
gba_instruction_is_SUB:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SUB_CODE_MASK) == GBA_SUB_CODE }
GBA_SUB_OPCODE:: 0b0010
gba_SUB_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_SUB_Instruction(ins).opcode == GBA_SUB_OPCODE }
GBA_SUB_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_SWI_Instruction:: bit_field u32 { // Software Interrupt / Interrupt //
	immediate: uint | 24,
	_: uint | 4,
	cond:                     GBA_Condition             | 4 }
GBA_SWI_CODE_MASK:: 0b_00001111_00000000_00000000_00000000
GBA_SWI_CODE::      0b_00001111_00000000_00000000_00000000
gba_instruction_is_SWI:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SWI_CODE_MASK) == GBA_SWI_CODE }
GBA_SWP_Instruction:: bit_field u32 { // Swap / Semaphore //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	sbz_0: uint | 4,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	sbz_1: uint | 2,
	_: uint | 6,
	cond:                     GBA_Condition             | 4 }
GBA_SWP_CODE_MASK:: 0b_00001111_11000000_00000000_11110000
GBA_SWP_CODE::      0b_00000001_00000000_00000000_10010000
gba_instruction_is_SWP:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SWP_CODE_MASK) == GBA_SWP_CODE }
GBA_SWPB_Instruction:: bit_field u32 { // Swap Byte / Semaphore //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	sbz_0: uint | 4,
	rd: GBA_Logical_Register_Name | 4,
	rn: GBA_Logical_Register_Name | 4,
	sbz_1: uint | 2,
	_: uint | 6,
	cond:                     GBA_Condition             | 4 }
GBA_SWPB_CODE_MASK:: 0b_00001111_11000000_00000000_11110000
GBA_SWPB_CODE::      0b_00000001_01000000_00000000_10010000
gba_instruction_is_SWPB:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_SWPB_CODE_MASK) == GBA_SWPB_CODE }
GBA_TEQ_Instruction:: bit_field u32 { // Test Equivalence / Data Processing / Addressing Mode 1 //
	shifter_operand:     u32                       | 12,
	sbz:                  uint | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	_: uint | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_TEQ_CODE_MASK:: 0b_00001101_11110000_00000000_00000000
GBA_TEQ_CODE::      0b_00000001_00110000_00000000_00000000
gba_instruction_is_TEQ:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_TEQ_CODE_MASK) == GBA_TEQ_CODE }
GBA_TEQ_OPCODE:: 0b1001
gba_TEQ_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_TEQ_Instruction(ins).opcode == GBA_TEQ_OPCODE }
GBA_TEQ_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_TST_Instruction:: bit_field u32 { // Test / Data Processing / Addressing Mode 1 //
	shifter_operand:     u32                       | 12,
	sbz:                  uint | 4,
	rn:                  GBA_Logical_Register_Name | 4,
	_: uint | 1,
	opcode:              uint                      | 4,
	immediate_shifter:   bool                      | 1,
	_:                   uint                      | 2,
	cond:                GBA_Condition             | 4 }
GBA_TST_CODE_MASK:: 0b_00001101_11110000_00000000_00000000
GBA_TST_CODE::      0b_00000001_00010000_00000000_00000000
gba_instruction_is_TST:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_TST_CODE_MASK) == GBA_TST_CODE }
GBA_TST_OPCODE:: 0b1000
gba_TST_opcode_match:: proc(ins: GBA_Instruction) -> bool {
	return GBA_TST_Instruction(ins).opcode == GBA_TST_OPCODE }
GBA_TST_ADDRESSING_MODE:: GBA_Addressing_Mode.MODE_1
GBA_UMLAL_Instruction:: bit_field u32 { // Unsigned Multiply Accumulate Long / Multiply //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	rs: GBA_Logical_Register_Name | 4,
	rd_lo: GBA_Logical_Register_Name | 4,
	rd_hi: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	_: uint | 7,
	cond: GBA_Condition | 4 }
GBA_UMLAL_CODE_MASK:: 0b_00001111_11100000_00000000_11110000
GBA_UMLAL_CODE::      0b_00000000_10100000_00000000_10010000
gba_instruction_is_UMLAL:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_UMLAL_CODE_MASK) == GBA_UMLAL_CODE }
GBA_UMULL_Instruction:: bit_field u32 { // Unsigned Multiply Long / Multiply //
	rm: GBA_Logical_Register_Name | 4,
	_: uint | 4,
	rs: GBA_Logical_Register_Name | 4,
	rd_lo: GBA_Logical_Register_Name | 4,
	rd_hi: GBA_Logical_Register_Name | 4,
	set_condition_codes: bool | 1,
	_: uint | 7,
	cond: GBA_Condition | 4 }
GBA_UMULL_CODE_MASK:: 0b_00001111_11100000_00000000_11110000
GBA_UMULL_CODE::      0b_00000000_10000000_00000000_10010000
gba_instruction_is_UMULL:: proc(ins: GBA_Instruction) -> bool {
	return (u32(ins) & GBA_UMULL_CODE_MASK) == GBA_UMULL_CODE }


// IDENTIFIED INSTRUCTIONS //
gba_identify_instruction:: proc(ins: GBA_Instruction) -> (ins_ided: GBA_Instruction_Identified, ok: bool) {
	class: GBA_Instruction_Class
	type: GBA_Instruction_Type
	switch {
	case gba_instruction_is_ADC(ins):   return GBA_ADC_Instruction(ins),   true
	case gba_instruction_is_ADD(ins):   return GBA_ADD_Instruction(ins),   true
	case gba_instruction_is_AND(ins):   return GBA_AND_Instruction(ins),   true
	case gba_instruction_is_B(ins):     return GBA_B_Instruction(ins),     true
	case gba_instruction_is_BL(ins):    return GBA_BL_Instruction(ins),    true
	case gba_instruction_is_BIC(ins):   return GBA_BIC_Instruction(ins),   true
	case gba_instruction_is_BX(ins):    return GBA_BX_Instruction(ins),    true
	case gba_instruction_is_CDP(ins):   return GBA_CDP_Instruction(ins),   true
	case gba_instruction_is_CMN(ins):   return GBA_CMN_Instruction(ins),   true
	case gba_instruction_is_CMP(ins):   return GBA_CMP_Instruction(ins),   true
	case gba_instruction_is_EOR(ins):   return GBA_EOR_Instruction(ins),   true
	case gba_instruction_is_LDC(ins):   return GBA_LDC_Instruction(ins),   true
	case gba_instruction_is_LDM(ins):   return GBA_LDM_Instruction(ins),   true
	case gba_instruction_is_LDR(ins):   return GBA_LDR_Instruction(ins),   true
	case gba_instruction_is_LDRB(ins):  return GBA_LDRB_Instruction(ins),  true
	case gba_instruction_is_LDRBT(ins): return GBA_LDRBT_Instruction(ins), true
	case gba_instruction_is_LDRH(ins):  return GBA_LDRH_Instruction(ins),  true
	case gba_instruction_is_LDRSB(ins): return GBA_LDRSB_Instruction(ins), true
	case gba_instruction_is_LDRSH(ins): return GBA_LDRSH_Instruction(ins), true
	case gba_instruction_is_LDRT(ins):  return GBA_LDRT_Instruction(ins),  true
	case gba_instruction_is_MCR(ins):   return GBA_MCR_Instruction(ins),   true
	case gba_instruction_is_MLA(ins):   return GBA_MLA_Instruction(ins),   true
	case gba_instruction_is_MOV(ins):   return GBA_MOV_Instruction(ins),   true
	case gba_instruction_is_MRC(ins):   return GBA_MRC_Instruction(ins),   true
	case gba_instruction_is_MRS(ins):   return GBA_MRS_Instruction(ins),   true
	case gba_instruction_is_MSR(ins):   return GBA_MSR_Instruction(ins),   true
	case gba_instruction_is_MUL(ins):   return GBA_MUL_Instruction(ins),   true
	case gba_instruction_is_MVN(ins):   return GBA_MVN_Instruction(ins),   true
	case gba_instruction_is_ORR(ins):   return GBA_ORR_Instruction(ins),   true
	case gba_instruction_is_RSB(ins):   return GBA_RSB_Instruction(ins),   true
	case gba_instruction_is_RSC(ins):   return GBA_RSC_Instruction(ins),   true
	case gba_instruction_is_SBC(ins):   return GBA_SBC_Instruction(ins),   true
	case gba_instruction_is_SMLAL(ins): return GBA_SMLAL_Instruction(ins), true
	case gba_instruction_is_SMULL(ins): return GBA_SMULL_Instruction(ins), true
	case gba_instruction_is_STM(ins):   return GBA_STM_Instruction(ins),   true
	case gba_instruction_is_STR(ins):   return GBA_STR_Instruction(ins),   true
	case gba_instruction_is_STRB(ins):  return GBA_STRB_Instruction(ins),  true
	case gba_instruction_is_STRBT(ins): return GBA_STRBT_Instruction(ins), true
	case gba_instruction_is_STRH(ins):  return GBA_STRH_Instruction(ins),  true
	case gba_instruction_is_STRT(ins):  return GBA_STRT_Instruction(ins),  true
	case gba_instruction_is_SUB(ins):   return GBA_SUB_Instruction(ins),   true
	case gba_instruction_is_SWI(ins):   return GBA_SWI_Instruction(ins),   true
	case gba_instruction_is_SWP(ins):   return GBA_SWP_Instruction(ins),   true
	case gba_instruction_is_SWPB(ins):  return GBA_SWPB_Instruction(ins),  true
	case gba_instruction_is_TEQ(ins):   return GBA_TEQ_Instruction(ins),   true
	case gba_instruction_is_TST(ins):   return GBA_TST_Instruction(ins),   true
	case gba_instruction_is_UMLAL(ins): return GBA_UMLAL_Instruction(ins), true
	case gba_instruction_is_UMULL(ins): return GBA_UMULL_Instruction(ins), true
	case: return {}, true }
	return {}, true }


// DECODED INSTRUCTIONS //
GBA_Address_Operand:: distinct u32
GBA_Immediate_Operand:: distinct i32
GBA_Register_Operand:: distinct ^u32
GBA_Operand:: union { GBA_Immediate_Operand, GBA_Address_Operand, GBA_Register_Operand }
GBA_Instruction_Decoded:: union {
	GBA_ADC_Instruction_Decoded,
	GBA_ADD_Instruction_Decoded,
	GBA_AND_Instruction_Decoded,
	GBA_B_Instruction_Decoded,
	GBA_BL_Instruction_Decoded,
	GBA_BIC_Instruction_Decoded,
	GBA_BX_Instruction_Decoded,
	GBA_CMN_Instruction_Decoded,
	GBA_CMP_Instruction_Decoded,
	GBA_EOR_Instruction_Decoded,
	GBA_LDM_Instruction_Decoded,
	GBA_LDR_Instruction_Decoded,
	GBA_LDRB_Instruction_Decoded,
	GBA_LDRBT_Instruction_Decoded,
	GBA_LDRH_Instruction_Decoded,
	GBA_LDRSB_Instruction_Decoded,
	GBA_LDRSH_Instruction_Decoded,
	GBA_LDRT_Instruction_Decoded,
	GBA_MLA_Instruction_Decoded,
	GBA_MOV_Instruction_Decoded,
	GBA_MRS_Instruction_Decoded,
	GBA_MSR_Instruction_Decoded,
	GBA_MUL_Instruction_Decoded,
	GBA_MVN_Instruction_Decoded,
	GBA_ORR_Instruction_Decoded,
	GBA_RSB_Instruction_Decoded,
	GBA_RSC_Instruction_Decoded,
	GBA_SBC_Instruction_Decoded,
	GBA_SMLAL_Instruction_Decoded,
	GBA_SMULL_Instruction_Decoded,
	GBA_STM_Instruction_Decoded,
	GBA_STR_Instruction_Decoded,
	GBA_STRB_Instruction_Decoded,
	GBA_STRBT_Instruction_Decoded,
	GBA_STRH_Instruction_Decoded,
	GBA_STRT_Instruction_Decoded,
	GBA_SUB_Instruction_Decoded,
	GBA_SWI_Instruction_Decoded,
	GBA_SWP_Instruction_Decoded,
	GBA_SWPB_Instruction_Decoded,
	GBA_TEQ_Instruction_Decoded,
	GBA_TST_Instruction_Decoded,
	GBA_UMLAL_Instruction_Decoded,
	GBA_UMULL_Instruction_Decoded }
gba_decode_instruction:: proc {
	gba_decode_identified,
	gba_decode_ADC,
	gba_decode_ADD,
	gba_decode_AND,
	gba_decode_B,
	gba_decode_BL,
	gba_decode_BIC,
	gba_decode_BX,
	gba_decode_CMN,
	gba_decode_CMP,
	gba_decode_EOR,
	gba_decode_LDM,
	gba_decode_LDR,
	gba_decode_LDRB,
	gba_decode_LDRBT,
	gba_decode_LDRH,
	gba_decode_LDRSB,
	gba_decode_LDRSH,
	gba_decode_LDRT,
	gba_decode_MLA,
	gba_decode_MOV,
	gba_decode_MRS,
	gba_decode_MSR,
	gba_decode_MUL,
	gba_decode_MVN,
	gba_decode_ORR,
	gba_decode_RSB,
	gba_decode_RSC,
	gba_decode_SBC,
	gba_decode_SMLAL,
	gba_decode_SMULL,
	gba_decode_STM,
	gba_decode_STR,
	gba_decode_STRB,
	gba_decode_STRBT,
	gba_decode_STRH,
	gba_decode_STRT,
	gba_decode_SUB,
	gba_decode_SWI,
	gba_decode_SWP,
	gba_decode_SWPB,
	gba_decode_TEQ,
	gba_decode_TST,
	gba_decode_UMLAL,
	gba_decode_UMULL }
gba_decode_identified:: proc(ins_union: GBA_Instruction_Identified, instruction_address: u32) -> (ins_decoded: GBA_Instruction_Decoded, defined: bool) {
	#partial switch ins in ins_union {
	case GBA_ADC_Instruction:   return gba_decode_ADC(ins, instruction_address),   true
	case GBA_ADD_Instruction:   return gba_decode_ADD(ins, instruction_address),   true
	case GBA_AND_Instruction:   return gba_decode_AND(ins, instruction_address),   true
	case GBA_B_Instruction:     return gba_decode_B(ins, instruction_address),     true
	case GBA_BL_Instruction:    return gba_decode_BL(ins, instruction_address),    true
	case GBA_BIC_Instruction:   return gba_decode_BIC(ins, instruction_address),   true
	case GBA_BX_Instruction:    return gba_decode_BX(ins, instruction_address),    true
	case GBA_CMN_Instruction:   return gba_decode_CMN(ins, instruction_address),   true
	case GBA_CMP_Instruction:   return gba_decode_CMP(ins, instruction_address),   true
	case GBA_EOR_Instruction:   return gba_decode_EOR(ins, instruction_address),   true
	case GBA_LDM_Instruction:   return gba_decode_LDM(ins, instruction_address),   true
	case GBA_LDR_Instruction:   return gba_decode_LDR(ins, instruction_address),   true
	case GBA_LDRB_Instruction:  return gba_decode_LDRB(ins, instruction_address),  true
	case GBA_LDRBT_Instruction: return gba_decode_LDRBT(ins, instruction_address), true
	case GBA_LDRH_Instruction:  return gba_decode_LDRH(ins, instruction_address),  true
	case GBA_LDRSB_Instruction: return gba_decode_LDRSB(ins, instruction_address), true
	case GBA_LDRSH_Instruction: return gba_decode_LDRSH(ins, instruction_address), true
	case GBA_LDRT_Instruction:  return gba_decode_LDRT(ins, instruction_address),  true
	case GBA_MLA_Instruction:   return gba_decode_MLA(ins, instruction_address),   true
	case GBA_MOV_Instruction:   return gba_decode_MOV(ins, instruction_address),   true
	case GBA_MRS_Instruction:   return gba_decode_MRS(ins, instruction_address),   true
	case GBA_MSR_Instruction:   return gba_decode_MSR(ins, instruction_address),   true
	case GBA_MUL_Instruction:   return gba_decode_MUL(ins, instruction_address),   true
	case GBA_MVN_Instruction:   return gba_decode_MVN(ins, instruction_address),   true
	case GBA_ORR_Instruction:   return gba_decode_ORR(ins, instruction_address),   true
	case GBA_RSB_Instruction:   return gba_decode_RSB(ins, instruction_address),   true
	case GBA_RSC_Instruction:   return gba_decode_RSC(ins, instruction_address),   true
	case GBA_SBC_Instruction:   return gba_decode_SBC(ins, instruction_address),   true
	case GBA_SMLAL_Instruction: return gba_decode_SMLAL(ins, instruction_address), true
	case GBA_SMULL_Instruction: return gba_decode_SMULL(ins, instruction_address), true
	case GBA_STM_Instruction:   return gba_decode_STM(ins, instruction_address),   true
	case GBA_STR_Instruction:   return gba_decode_STR(ins, instruction_address),   true
	case GBA_STRB_Instruction:  return gba_decode_STRB(ins, instruction_address),  true
	case GBA_STRBT_Instruction: return gba_decode_STRBT(ins, instruction_address), true
	case GBA_STRH_Instruction:  return gba_decode_STRH(ins, instruction_address),  true
	case GBA_STRT_Instruction:  return gba_decode_STRT(ins, instruction_address),  true
	case GBA_SUB_Instruction:   return gba_decode_SUB(ins, instruction_address),   true
	case GBA_SWI_Instruction:   return gba_decode_SWI(ins, instruction_address),   true
	case GBA_SWP_Instruction:   return gba_decode_SWP(ins, instruction_address),   true
	case GBA_SWPB_Instruction:  return gba_decode_SWPB(ins, instruction_address),  true
	case GBA_TEQ_Instruction:   return gba_decode_TEQ(ins, instruction_address),   true
	case GBA_TST_Instruction:   return gba_decode_TST(ins, instruction_address),   true
	case GBA_UMLAL_Instruction: return gba_decode_UMLAL(ins, instruction_address), true
	case GBA_UMULL_Instruction: return gba_decode_UMULL(ins, instruction_address), true
	case:                       return {}, false } }
GBA_ADC_Instruction_Decoded:: struct {
	instruction_address: u32,
	// NOTE There is no need to preserve the condition field, because it can be checked before identifying the instruction.
	operand:             i32,
	shifter_operand:     i32,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_ADC:: proc(ins: GBA_ADC_Instruction, instruction_address: u32) -> (decoded: GBA_ADC_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_ADD_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	destination:         ^GBA_Register,
	shifter_operand:     i32,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_ADD:: proc(ins: GBA_ADD_Instruction, instruction_address: u32) -> (decoded: GBA_ADD_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_AND_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_AND:: proc(ins: GBA_AND_Instruction, instruction_address: u32) -> (decoded: GBA_AND_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_B_Instruction_Decoded:: struct {
	instruction_address: u32,
	target_address:      u32,
	cond:                GBA_Condition }
gba_decode_B:: proc(ins: GBA_B_Instruction, instruction_address: u32) -> (decoded: GBA_B_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	offset_bits: = sign_extend_u32(bits.bitfield_extract(u32(ins), 0, 24), 24)
	if offset_bits > 0 {
		decoded.target_address = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ + u32(offset_bits) }
	else {
		decoded.target_address = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ - u32(-offset_bits) }
	decoded.cond = ins.cond
	return decoded }
GBA_BL_Instruction_Decoded:: struct {
	instruction_address: u32,
	target_address:      u32,
	cond:                GBA_Condition }
gba_decode_BL:: proc(ins: GBA_BL_Instruction, instruction_address: u32) -> (decoded: GBA_BL_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	offset_bits: = sign_extend_u32(bits.bitfield_extract(u32(ins), 0, 24), 24)
	if offset_bits > 0 {
		decoded.target_address = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ + u32(offset_bits) }
	else {
		decoded.target_address = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ - u32(-offset_bits) }
	decoded.cond = ins.cond
	return decoded }
GBA_BIC_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_BIC:: proc(ins: GBA_BIC_Instruction, instruction_address: u32) -> (decoded: GBA_BIC_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_BX_Instruction_Decoded:: struct {
	instruction_address: u32,
	target_address:      u32,
	thumb_mode:          bool,
	cond:                GBA_Condition }
gba_decode_BX:: proc(ins: GBA_BX_Instruction, instruction_address: u32) -> (decoded: GBA_BX_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	rm: = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^
	decoded.target_address = rm & (~ u32(0b1))
	decoded.thumb_mode = bool(rm & u32(0b1))
	decoded.cond = ins.cond
	return decoded }
GBA_CMN_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	shifter_operand:     i32,
	cond:                GBA_Condition }
gba_decode_CMN:: proc(ins: GBA_CMN_Instruction, instruction_address: u32) -> (decoded: GBA_CMN_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.cond = ins.cond
	return decoded }
GBA_CMP_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	shifter_operand:     i32,
	cond:                GBA_Condition }
gba_decode_CMP:: proc(ins: GBA_CMP_Instruction, instruction_address: u32) -> (decoded: GBA_CMP_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.cond = ins.cond
	return decoded }
GBA_EOR_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_EOR:: proc(ins: GBA_EOR_Instruction, instruction_address: u32) -> (decoded: GBA_EOR_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_LDM_Instruction_Decoded:: struct {
	instruction_address:     u32,
	destination_registers:   bit_set[GBA_Logical_Register_Name],
	start_address:           u32,
	restore_status_register: bool,
	cond:                    GBA_Condition }
gba_decode_LDM:: proc(ins: GBA_LDM_Instruction, instruction_address: u32) -> (decoded: GBA_LDM_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.start_address, _, decoded.destination_registers = gba_decode_address_mode_4(u32(ins))
	decoded.restore_status_register = bool(bits.bitfield_extract(u32(ins), 15, 1)) && bool(bits.bitfield_extract(u32(ins), 22, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_LDR_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDR:: proc(ins: GBA_LDR_Instruction, instruction_address: u32) -> (decoded: GBA_LDR_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_LDRB_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDRB:: proc(ins: GBA_LDRB_Instruction, instruction_address: u32) -> (decoded: GBA_LDRB_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_LDRBT_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDRBT:: proc(ins: GBA_LDRBT_Instruction, instruction_address: u32) -> (decoded: GBA_LDRBT_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_LDRH_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDRH:: proc(ins: GBA_LDRH_Instruction, instruction_address: u32) -> (decoded: GBA_LDRH_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_LDRSB_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDRSB:: proc(ins: GBA_LDRSB_Instruction, instruction_address: u32) -> (decoded: GBA_LDRSB_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_LDRSH_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDRSH:: proc(ins: GBA_LDRSH_Instruction, instruction_address: u32) -> (decoded: GBA_LDRSH_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_LDRT_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	destination:         ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_LDRT:: proc(ins: GBA_LDRT_Instruction, instruction_address: u32) -> (decoded: GBA_LDRT_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_MLA_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	multiplicand:        i32,
	addend:              i32,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_MLA:: proc(ins: GBA_MLA_Instruction, instruction_address: u32) -> (decoded: GBA_MLA_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^)
	decoded.multiplicand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 8, 4)]^)
	decoded.addend = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]^)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_MOV_Instruction_Decoded:: struct {
	instruction_address: u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_MOV:: proc(ins: GBA_MOV_Instruction, instruction_address: u32) -> (decoded: GBA_MOV_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_MRS_Instruction_Decoded:: struct {
	instruction_address: u32,
	source:              ^GBA_Register,
	destination:         ^GBA_Register,
	cond:                GBA_Condition }
gba_decode_MRS:: proc(ins: GBA_MRS_Instruction, instruction_address: u32) -> (decoded: GBA_MRS_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	if bool(bits.bitfield_extract(u32(ins), 22, 1)) do decoded.source = gba_core.logical_registers.array[GBA_Logical_Register_Name.SPSR]
	else do decoded.source = gba_core.logical_registers.array[GBA_Logical_Register_Name.CPSR]
	decoded.cond = ins.cond
	return decoded }
GBA_MSR_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	destination:         GBA_Logical_Register_Name,
	field_mask:          bit_set[0 ..< 4],
	cond:                GBA_Condition }
gba_decode_MSR:: proc(ins: GBA_MSR_Instruction, instruction_address: u32) -> (decoded: GBA_MSR_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	if bits.bitfield_extract(u32(ins), 25, 1) == 1 {
		decoded.operand = rotate_right(bits.bitfield_extract(u32(ins), 0, 8), uint(bits.bitfield_extract(u32(ins), 8, 4) * 2)) }
	else {
		decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^ }
	if bool(bits.bitfield_extract(u32(ins), 22, 1)) do decoded.destination = GBA_Logical_Register_Name.SPSR
	else do decoded.destination = GBA_Logical_Register_Name.CPSR
	field_mask_bits: = bits.bitfield_extract(u32(ins), 16, 4)
	for i in 0 ..< 4 do if bool(field_mask_bits & (0b1 << uint(i))) do decoded.field_mask += { i }
	decoded.cond = ins.cond
	return decoded }
GBA_MUL_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	multiplicand:        i32,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_MUL:: proc(ins: GBA_MUL_Instruction, instruction_address: u32) -> (decoded: GBA_MUL_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^)
	decoded.multiplicand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 8, 4)]^)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_MVN_Instruction_Decoded:: struct {
	instruction_address: u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_MVN:: proc(ins: GBA_MVN_Instruction, instruction_address: u32) -> (decoded: GBA_MVN_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_ORR_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	destination:         ^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_ORR:: proc(ins: GBA_ORR_Instruction, instruction_address: u32) -> (decoded: GBA_ORR_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_RSB_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	destination:         ^GBA_Register,
	shifter_operand:     i32,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_RSB:: proc(ins: GBA_RSB_Instruction, instruction_address: u32) -> (decoded: GBA_RSB_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_RSC_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	destination:         ^GBA_Register,
	shifter_operand:     i32,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_RSC:: proc(ins: GBA_RSC_Instruction, instruction_address: u32) -> (decoded: GBA_RSC_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_SBC_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	destination:         ^GBA_Register,
	shifter_operand:     i32,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_SBC:: proc(ins: GBA_SBC_Instruction, instruction_address: u32) -> (decoded: GBA_SBC_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_SMLAL_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	multiplicands:       [2]i32,
	destinations:        [2]^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_SMLAL:: proc(ins: GBA_SMLAL_Instruction, instruction_address: u32) -> (decoded: GBA_SMLAL_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.multiplicands[0] = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^)
	decoded.multiplicands[1] = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 8, 4)]^)
	decoded.destinations[0] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.destinations[1] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_SMULL_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	multiplicands:       [2]i32,
	destinations:        [2]^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_SMULL:: proc(ins: GBA_SMULL_Instruction, instruction_address: u32) -> (decoded: GBA_SMULL_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.multiplicands[0] = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^)
	decoded.multiplicands[1] = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 8, 4)]^)
	decoded.destinations[0] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.destinations[1] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_STM_Instruction_Decoded:: struct {
	instruction_address:     u32,
	source_registers:        bit_set[GBA_Logical_Register_Name],
	start_address:           u32,
	restore_status_register: bool,
	cond:                    GBA_Condition }
gba_decode_STM:: proc(ins: GBA_STM_Instruction, instruction_address: u32) -> (decoded: GBA_STM_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.start_address, _, decoded.source_registers = gba_decode_address_mode_4(u32(ins))
	decoded.restore_status_register = bool(bits.bitfield_extract(u32(ins), 15, 1)) && bool(bits.bitfield_extract(u32(ins), 22, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_STR_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	source:              ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_STR:: proc(ins: GBA_STR_Instruction, instruction_address: u32) -> (decoded: GBA_STR_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.source = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_STRB_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	source:              ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_STRB:: proc(ins: GBA_STRB_Instruction, instruction_address: u32) -> (decoded: GBA_STRB_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.source = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_STRBT_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	source:              ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_STRBT:: proc(ins: GBA_STRBT_Instruction, instruction_address: u32) -> (decoded: GBA_STRBT_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.source = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_STRH_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	source:              ^GBA_Register,
	cond:                GBA_Condition }
gba_decode_STRH:: proc(ins: GBA_STRH_Instruction, instruction_address: u32) -> (decoded: GBA_STRH_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address = gba_decode_address_mode_3(u32(ins))
	decoded.source = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_STRT_Instruction_Decoded:: struct {
	instruction_address: u32,
	address:             u32,
	source:              ^GBA_Register,
	unsigned_byte:       bool,
	write_back:          bool,
	write_back_value:    u32,
	write_back_register: GBA_Logical_Register_Name,
	cond:                GBA_Condition }
gba_decode_STRT:: proc(ins: GBA_STRT_Instruction, instruction_address: u32) -> (decoded: GBA_STRT_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address, decoded.write_back_value, decoded.unsigned_byte, decoded.write_back, decoded.write_back_register = gba_decode_address_mode_2(u32(ins))
	decoded.source = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_SUB_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             i32,
	destination:         ^GBA_Register,
	shifter_operand:     i32,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_SUB:: proc(ins: GBA_SUB_Instruction, instruction_address: u32) -> (decoded: GBA_SUB_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = transmute(i32)(gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^)
	shifter_unsigned, _: = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.shifter_operand = transmute(i32)(shifter_unsigned)
	decoded.destination = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_SWI_Instruction_Decoded:: struct {
	instruction_address: u32,
	immediate:           u32,
	cond:                GBA_Condition }
gba_decode_SWI:: proc(ins: GBA_SWI_Instruction, instruction_address: u32) -> (decoded: GBA_SWI_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.immediate = bits.bitfield_extract(u32(ins), 0, 24)
	decoded.cond = ins.cond
	return decoded }
GBA_SWP_Instruction_Decoded:: struct {
	instruction_address:  u32,
	destination_register: ^GBA_Register,
	source_register:      ^GBA_Register,
	address:              u32,
	cond:                 GBA_Condition }
gba_decode_SWP:: proc(ins: GBA_SWP_Instruction, instruction_address: u32) -> (decoded: GBA_SWP_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.source_register = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]
	decoded.destination_register = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_SWPB_Instruction_Decoded:: struct {
	instruction_address:  u32,
	destination_register: ^GBA_Register,
	source_register:      ^GBA_Register,
	address:              u32,
	cond:                 GBA_Condition }
gba_decode_SWPB:: proc(ins: GBA_SWPB_Instruction, instruction_address: u32) -> (decoded: GBA_SWPB_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.address = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.source_register = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]
	decoded.destination_register = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.cond = ins.cond
	return decoded }
GBA_TEQ_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	cond:                GBA_Condition }
gba_decode_TEQ:: proc(ins: GBA_TEQ_Instruction, instruction_address: u32) -> (decoded: GBA_TEQ_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.cond = ins.cond
	return decoded }
GBA_TST_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	shifter_operand:     u32,
	shifter_carry_out:   bool,
	cond:                GBA_Condition }
gba_decode_TST:: proc(ins: GBA_TST_Instruction, instruction_address: u32) -> (decoded: GBA_TST_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.operand = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]^
	decoded.shifter_operand, decoded.shifter_carry_out = gba_decode_address_mode_1(u32(ins) & GBA_SHIFTER_MASK)
	decoded.cond = ins.cond
	return decoded }
GBA_UMLAL_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	multiplicands:       [2]u32,
	destinations:        [2]^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_UMLAL:: proc(ins: GBA_UMLAL_Instruction, instruction_address: u32) -> (decoded: GBA_UMLAL_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.multiplicands[0] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^
	decoded.multiplicands[1] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 8, 4)]^
	decoded.destinations[0] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.destinations[1] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }
GBA_UMULL_Instruction_Decoded:: struct {
	instruction_address: u32,
	operand:             u32,
	multiplicands:       [2]u32,
	destinations:        [2]^GBA_Register,
	set_condition_codes: bool,
	cond:                GBA_Condition }
gba_decode_UMULL:: proc(ins: GBA_UMULL_Instruction, instruction_address: u32) -> (decoded: GBA_UMULL_Instruction_Decoded) {
	decoded.instruction_address = instruction_address
	decoded.multiplicands[0] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 0, 4)]^
	decoded.multiplicands[1] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 8, 4)]^
	decoded.destinations[0] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 12, 4)]
	decoded.destinations[1] = gba_core.logical_registers.array[bits.bitfield_extract(u32(ins), 16, 4)]
	decoded.set_condition_codes = bool(bits.bitfield_extract(u32(ins), 20, 1))
	decoded.cond = ins.cond
	return decoded }


// UTIL //
gba_carry_from_add:: proc { gba_carry_from_add_without_carry, gba_carry_from_add_with_carry }
gba_carry_from_add_without_carry:: proc(a, b: i32) -> bool {
	return (u64(abs(a)) + u64(abs(b)) > (u64(0b1) << 31) - 1) }
gba_carry_from_add_with_carry:: proc(a, b: i32, carry: u32) -> bool {
	return (u64(abs(a)) + u64(abs(b)) + u64(abs(carry)) > (u64(0b1) << 31) - 1) }
gba_carry_from_sub:: proc { gba_carry_from_sub_without_carry, gba_carry_from_sub_with_carry }
gba_carry_from_sub_without_carry:: proc(a, b: i32) -> bool {
	return gba_carry_from_add_without_carry(a, - b) }
gba_carry_from_sub_with_carry:: proc(a, b: i32, carry: u32) -> bool {
	return gba_carry_from_add_without_carry(a, - b - i32(carry)) }
gba_overflow_from_add:: proc { gba_overflow_from_add_without_carry, gba_overflow_from_add_with_carry }
gba_overflow_from_add_without_carry:: proc(a, b: i32) -> bool {
	return ((a >> 31) & 0b1 == (b >> 31) & 0b1) && (((a + b) >> 31) & 0b1 == (b >> 31) & 0b1) }
gba_overflow_from_add_with_carry:: proc(a, b: i32, carry: u32) -> bool {
	return ((a >> 31) & 0b1 == (b >> 31) & 0b1) && (((a + b + i32(carry)) >> 31) & 0b1 == (b >> 31) & 0b1) }
gba_overflow_from_sub:: proc(a: i32, b: i32) -> bool {
	return (sign_bit(a) != sign_bit(b)) && (sign_bit(a) != sign_bit(a - b)) }
gba_borrow_from:: proc(a: i32, b: i32) -> bool {
	return abs(a) < abs(b) }
gba_current_mode_has_spsr:: proc() -> bool {
	#partial switch gba_core.mode {
	case .User, .System: return false
	case: return true } }
gba_in_a_privileged_mode:: proc() -> bool {
	#partial switch gba_core.mode {
	case .User: return false
	case: return true } }
gba_sign_extend:: proc(arg: u32, width: uint) -> i32 {
	sign_bit: = bits.bitfield_extract(arg, width - 1, 1)
	arg: = arg & ~(0b1 << (width - 1))
	return transmute(i32)(arg | (sign_bit << 31)) }