#+feature dynamic-literals
package gbana
import "core:container/queue"
import "core:math/bits"


ALU:: struct {

}


// INTERFACES //
GBA_Clocks_And_Timing_Interface:: struct {
	MCLK:  GBA_Clock,
	nWAIT: GBA_Clock,
	ECLK:  GBA_Clock }
GBA_Interrupts_Interface:: struct {
	nIRQ:  byte,
	nFIQ:  byte,
	ISYNC: byte }


// CLOCK //
GBA_Clock:: byte


// DECODER & CONTROL //
gba_should_be_zero:: proc(bits: u32, #any_int num: uint) -> bool {
	mask: u32 = (u32(0b1) << num) - 1
	return (bits & mask) == 0b00000000_00000000_00000000_00000000 }
gba_should_be_one:: proc(bits: u32, #any_int num: uint) -> bool {
	mask: u32 = (u32(0b1) << num) - 1
	return (bits & mask) == 0b11111111_11111111_11111111_11111111 }


// CORE //
R13_DEFAULT_USER_SYSTEM:: 0x03007f00
R13_DEFAULT_IRQ::         0x03007fa0
R13_DEFAULT_SUPERVISOR::  0x03007fe0
GBA_Core:: struct {
	mode: GBA_Processor_Mode,
	logical_registers: GBA_Logical_Registers,
	physical_registers: GBA_Physical_Registers,
	using clocks_and_timing: ^GBA_Clocks_And_Timing_Interface,
	using interrupts: struct {
		nIRQ:  byte,
		nFIQ:  byte,
		ISYNC: byte },
	using bus_controls: struct {
		nRESET:  byte,
		BUSEN:   byte,
		HIGHZ:   byte,
		BIGEND:  byte,
		nENIN:   byte,
		nENOUT:  byte,
		nENOUTI: byte,
		ABE:     byte,
		ALE:     byte,
		APE:     byte,
		DBE:     byte,
		TBE:     byte,
		BUSDIS:  byte,
		ECAPCLK: byte }
}
gba_core: ^GBA_Core
init_gba_core:: proc() {
	gba_core= new(GBA_Core) }
Hardware_Interrupt:: enum {
	V_BLANK,
	H_BLANK,
	SERIAL,
	V_COUNT,
	TIMER,
	DMA,
	KEY,
	CARTRIDGE }
Software_Interrupt:: enum {
	SOFT_RESET=              0x00,
	REGISTER_RAM_RESET=      0x01,
	HALT=                    0x02,
	STOP=                    0x03,
	INTR_WAIT=               0x04,
	V_BLANK_INTR_WAIT=       0x05,
	DIV=                     0x06,
	DIV_ARM=                 0x07,
	SQRT=                    0x08,
	ARC_TAN=                 0x09,
	ARC_TAN_2=               0x0A,
	CPU_SET=                 0x0B,
	CPU_FAST_SET=            0x0C,
	BIOS_CHECKSUM=           0x0D,
	BG_AFFINE_SET=           0x0E,
	OBJ_AFFINE_SET=          0x0F,
	BIT_UNPACK=              0x10,
	LZ77_UNCOMP_WRAM=        0x11,
	LZ77_UNCOMP_VRAM=        0x12,
	HUFF_UNCOMP=             0x13,
	RL_UNCOMP_WRAM=          0x14,
	RL_UNCOMP_VRAM=          0x15,
	DIFF_8BIT_UNFILTER_WRAM= 0x16,
	DIFF_8BIT_UNFILTER_VRAM= 0x17,
	DIFF_16BIT_UNFILTER=     0x18,
	SOUND_BIAS_CHANGE=       0x19,
	SOUND_DRIVER_INIT=       0x1A,
	SOUND_DRIVER_MODE=       0x1B,
	SOUND_DRIVER_MAIN=       0x1C,
	SOUND_DRIVER_VSYNC=      0x1D,
	SOUND_CHANNEL_CLEAR=     0x1E,
	MIDI_KEY_2FREQ=          0x1F,
	MUSIC_PLAYER_OPEN=       0x20,
	MUSIC_PLAYER_START=      0x21,
	MUSIC_PLAYER_STOP=       0x22,
	MUSIC_PLAYER_CONTINUE=   0x23,
	MUSIC_PLAYER_FADE_OUT=   0x24,
	MULTI_BOOT=              0x25,
	SOUND_DRIVER_VSYNC_OFF=  0x28,
	SOUND_DRIVER_VSYNC_ON=   0x29 }


// PROGRAM COUNTER //
// NOTE These depend on how I emulate and syncronize instruction pipelining. //
// gba_address_of_current_instruction:: proc() -> u32 {
// 	return gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
// }
// gba_address_of_next_instruction:: proc() -> u32 {
// }


// INSTRUCTIONS //
gba_execute_ADC:: proc(ins: GBA_ADC_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand + ins.shifter_operand + i32(cpsr.carry))
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand, u32(cpsr.carry))
		cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand, u32(cpsr.carry)) } }
gba_execute_ADD:: proc(ins: GBA_ADD_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand + ins.shifter_operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand)
		cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand) } }
gba_execute_AND:: proc(ins: GBA_AND_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand & ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_B:: proc(ins: GBA_B_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address }
gba_execute_BL:: proc(ins: GBA_BL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.LR]^ = ins.instruction_address + 4
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address }
gba_execute_BIC:: proc(ins: GBA_BIC_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand & (~ ins.shifter_operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_BX:: proc(ins: GBA_BX_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address
	cpsr.thumb_state = true }
gba_execute_CMN:: proc(ins: GBA_CMN_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand + ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand) }
gba_execute_CMP:: proc(ins: GBA_CMP_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand - ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_borrow_from(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_sub(ins.operand, ins.shifter_operand) }
gba_execute_EOR:: proc(ins: GBA_EOR_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand ~ ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_LDM:: proc(ins: GBA_LDM_Instruction_Decoded) {

}
gba_execute_LDR:: proc(ins: GBA_LDR_Instruction_Decoded) {

}
gba_execute_LDRB:: proc(ins: GBA_LDRB_Instruction_Decoded) {

}
gba_execute_LDRBT:: proc(ins: GBA_LDRBT_Instruction_Decoded) {

}
gba_execute_LDRH:: proc(ins: GBA_LDRH_Instruction_Decoded) {

}
gba_execute_LDRSB:: proc(ins: GBA_LDRSB_Instruction_Decoded) {

}
gba_execute_LDRSH:: proc(ins: GBA_LDRSH_Instruction_Decoded) {

}
gba_execute_LDRT:: proc(ins: GBA_LDRT_Instruction_Decoded) {

}
gba_execute_MLA:: proc(ins: GBA_MLA_Instruction_Decoded) {

}
gba_execute_MOV:: proc(ins: GBA_MOV_Instruction_Decoded) {

}
gba_execute_MRS:: proc(ins: GBA_MRS_Instruction_Decoded) {

}
gba_execute_MSR:: proc(ins: GBA_MSR_Instruction_Decoded) {

}
gba_execute_MUL:: proc(ins: GBA_MUL_Instruction_Decoded) {

}
gba_execute_MVN:: proc(ins: GBA_MVN_Instruction_Decoded) {

}
gba_execute_ORR:: proc(ins: GBA_ORR_Instruction_Decoded) {

}
gba_execute_RSB:: proc(ins: GBA_RSB_Instruction_Decoded) {

}
gba_execute_RSC:: proc(ins: GBA_RSC_Instruction_Decoded) {

}
gba_execute_SBC:: proc(ins: GBA_SBC_Instruction_Decoded) {

}
gba_execute_SMLAL:: proc(ins: GBA_SMLAL_Instruction_Decoded) {

}
gba_execute_SMULL:: proc(ins: GBA_SMULL_Instruction_Decoded) {

}
gba_execute_STM:: proc(ins: GBA_STM_Instruction_Decoded) {

}
gba_execute_STR:: proc(ins: GBA_STR_Instruction_Decoded) {

}
gba_execute_STRB:: proc(ins: GBA_STRB_Instruction_Decoded) {

}
gba_execute_STRBT:: proc(ins: GBA_STRBT_Instruction_Decoded) {

}
gba_execute_STRH:: proc(ins: GBA_STRH_Instruction_Decoded) {

}
gba_execute_STRT:: proc(ins: GBA_STRT_Instruction_Decoded) {

}
gba_execute_SUB:: proc(ins: GBA_SUB_Instruction_Decoded) {

}
gba_execute_SWI:: proc(ins: GBA_SWI_Instruction_Decoded) {

}
gba_execute_SWP:: proc(ins: GBA_SWP_Instruction_Decoded) {

}
gba_execute_SWPB:: proc(ins: GBA_SWPB_Instruction_Decoded) {

}
gba_execute_TEQ:: proc(ins: GBA_TEQ_Instruction_Decoded) {

}
gba_execute_TST:: proc(ins: GBA_TST_Instruction_Decoded) {

}
gba_execute_UMLAL:: proc(ins: GBA_UMLAL_Instruction_Decoded) {

}
gba_execute_UMULL:: proc(ins: GBA_UMULL_Instruction_Decoded) {

}