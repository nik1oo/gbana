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
decode_instruction:: proc(ins_ided: GBA_Instruction_Identified) -> () {

}
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
// Each instrction falls into one of these classes.
// The instruction decoder should be able to determine which class an instruction belongs to based on
// the id bits.
// In thumb mode, instructions are 16-bit wide, for memory efficiency.
// ins_class_ids:map[typeid]i32= {
// 	Instruction_Class_MU=INS_CLASS_MU_ID,
// 	Instruction_Class_ML=INS_CLASS_ML_ID,
// 	Instruction_Class_BE=INS_CLASS_BE_ID,
// 	Instruction_Class_DS=INS_CLASS_DS_ID,
// 	Instruction_Class_TR=INS_CLASS_TR_ID,
// 	Instruction_Class_TI=INS_CLASS_TI_ID,
// 	Instruction_Class_ST=INS_CLASS_ST_ID,
// 	Instruction_Class_PT=INS_CLASS_PT_ID,
// 	Instruction_Class_LS=INS_CLASS_LS_ID,
// 	Instruction_Class_UD=INS_CLASS_UD_ID,
// 	Instruction_Class_BT=INS_CLASS_BT_ID,
// 	Instruction_Class_BR=INS_CLASS_BR_ID,
// 	Instruction_Class_CT=INS_CLASS_CT_ID,
// 	Instruction_Class_CO=INS_CLASS_CO_ID,
// 	Instruction_Class_CR=INS_CLASS_CR_ID,
// 	Instruction_Class_SI=INS_CLASS_SI_ID }
// ins_class_id_masks:map[typeid]i32= {
// 	Instruction_Class_MU=INS_CLASS_MU_ID_MASK,
// 	Instruction_Class_ML=INS_CLASS_ML_ID_MASK,
// 	Instruction_Class_BE=INS_CLASS_BE_ID_MASK,
// 	Instruction_Class_DS=INS_CLASS_DS_ID_MASK,
// 	Instruction_Class_TR=INS_CLASS_TR_ID_MASK,
// 	Instruction_Class_TI=INS_CLASS_TI_ID_MASK,
// 	Instruction_Class_ST=INS_CLASS_ST_ID_MASK,
// 	Instruction_Class_PT=INS_CLASS_PT_ID_MASK,
// 	Instruction_Class_LS=INS_CLASS_LS_ID_MASK,
// 	Instruction_Class_UD=INS_CLASS_UD_ID_MASK,
// 	Instruction_Class_BT=INS_CLASS_BT_ID_MASK,
// 	Instruction_Class_BR=INS_CLASS_BR_ID_MASK,
// 	Instruction_Class_CT=INS_CLASS_CT_ID_MASK,
// 	Instruction_Class_CO=INS_CLASS_CO_ID_MASK,
// 	Instruction_Class_CR=INS_CLASS_CR_ID_MASK,
// 	Instruction_Class_SI=INS_CLASS_SI_ID_MASK }
// idcheck_ins_class:: proc {
// 	idcheck_ins_class_MU,
// 	idcheck_ins_class_ML,
// 	idcheck_ins_class_BE,
// 	idcheck_ins_class_DS,
// 	idcheck_ins_class_TR,
// 	idcheck_ins_class_TI,
// 	idcheck_ins_class_ST,
// 	idcheck_ins_class_PT,
// 	idcheck_ins_class_LS,
// 	idcheck_ins_class_UD,
// 	idcheck_ins_class_BT,
// 	idcheck_ins_class_BR,
// 	idcheck_ins_class_CT,
// 	idcheck_ins_class_CO,
// 	idcheck_ins_class_CR,
// 	idcheck_ins_class_SI }


// TODO Where are the condition flags? Define a proc that checks the condition flags and determines if
// a given condition is met.
Instruction_Cond:: enum i8 {
	EQ=    0b0000, // Equal
	NE=    0b0001, // Not equal
	CS_HS= 0b0010, // Carry set / unsigned greater than or equal
	CC_LO= 0b0011, // Carry clear / unsigned lesser than
	MI=    0b0100, // Minus / negative
	PL=    0b0101, // Plus / positive or zero
	VS=    0b0110, // Overflow
	VC=    0b0111, // No overflow
	HI=    0b1000, // Unsigned greater than
	LS=    0b1001, // Unsigned lesser than or equal
	GE=    0b1010, // Signed greater than or equal
	LT=    0b1011, // Signed lesser than
	GT=    0b1100, // Signed greater than
	LE=    0b1101, // Signed lelsser than or equal
	AL=    0b1110, // Always (ie, true)
	NV=    0b1111 }// Never (ie, false)
// NOTE Instruction is executed only if this returns true.
// ins_condcheck:: proc(ins: i32)-> (condition_met: bool) {
// 	return inscond_check(Instruction_Cond(ins>>28)) }
// inscond_check:: proc(cond: Instruction_Cond)-> (condition_met: bool) {
// 	if cond==.EQ {
// 		return gba_core.cpsr.zero_equal==true
// 	} else if cond==.NE {
// 		return gba_core.cpsr.zero_equal==false
// 	} else if cond==.CS_HS {
// 		return gba_core.cpsr.carry_borrow_extend==true
// 	} else if cond==.CC_LO {
// 		return gba_core.cpsr.carry_borrow_extend==false
// 	} else if cond==.MI {
// 		return gba_core.cpsr.negative_lesser==true
// 	} else if cond==.PL {
// 		return gba_core.cpsr.negative_lesser==false
// 	} else if cond==.VS {
// 		return gba_core.cpsr.overflow==true
// 	} else if cond==.VC {
// 		return gba_core.cpsr.overflow==false
// 	} else if cond==.HI {
// 		return (gba_core.cpsr.carry_borrow_extend==true) && (gba_core.cpsr.zero_equal==false)
// 	} else if cond==.LS {
// 		return (gba_core.cpsr.carry_borrow_extend==false) && (gba_core.cpsr.zero_equal==true)
// 	} else if cond==.GE {
// 		return gba_core.cpsr.negative_lesser==gba_core.cpsr.overflow
// 	} else if cond==.LT {
// 		return gba_core.cpsr.negative_lesser!=gba_core.cpsr.overflow
// 	} else if cond==.GT {
// 		return (gba_core.cpsr.zero_equal==false) && (gba_core.cpsr.negative_lesser==gba_core.cpsr.overflow)
// 	} else if cond==.LE {
// 		return (gba_core.cpsr.zero_equal==true) && (gba_core.cpsr.negative_lesser!=gba_core.cpsr.overflow)
// 	} else if cond==.AL {
// 		return true
// 	} else if cond==.NV {
// 		return false
// 	} else {
// 		return false } }
// What is a shifter operand?
OPERAND_2_MASK:: 0b00000000_00000000_00001111_11111111
parse_immediate_operand:: proc(operand: i32) {
	assert(operand & ~i32(OPERAND_2_MASK) != 0) }
// Immediate Operand                                     | I
// Register Operand                                      | R
// Register Operand, Logical Shift Left by Immediate     | R_LSL_I
// Register Operand, Logical Shift Left by Register      | R_LSL_R
// Register Operand, Logical Shift Right by Immediate    | R_LSR_I
// Register Operand, Logical Shift Right by Register     | R_LSR_R
// Register Operand, Arithmetic Shift Right by Immediate | R_ASR_I
// Register Operand, Arithmetic Shift Right by Register  | R_ASR_R
// Register Operand, Rotate Right by Immediate           | R_RR_I
// Register Operand, Rotate Right by Register            | R_RR_R
// Register Operand, Rotate Right with Extend            | R_RRX
idcheck_operand:: proc {
	idcheck_operand_I,
	idcheck_operand_R,
	idcheck_operand_R_LSL_I,
	idcheck_operand_R_LSL_R,
	idcheck_operand_R_LSR_I,
	idcheck_operand_R_LSR_R,
	idcheck_operand_R_ASR_I,
	idcheck_operand_R_ASR_R,
	idcheck_operand_R_RR_I,
	idcheck_operand_R_RR_R,
	idcheck_operand_R_RRX }
Operand_I:: bit_field i16 { // NOTE Immediate Operand //
	immediate: i16 | 8,
	rotate:    i16 | 4 }
OPERAND_I_ID::   0b0000_00000000
OPERAND_I_MASK:: 0b0000_00000000
idcheck_operand_I:: proc(operand: Operand_I)-> bool {
	return (i16(operand) & OPERAND_I_MASK) == OPERAND_I_ID }
address_operand_I:: proc(operand: Operand_I, Rn: ^i32, $pre_indexed: bool)-> (address: u32) { // NOTE Rn is base register.
	// Why is it "+/-" in the spec? Where does the sign originate?
	address= u32(Rn^) + u32(rotate_right(i32(operand.immediate), operand.rotate))
	when pre_indexed { Rn^= address }
	return address }
//TODO Write fetch operand proc.
Operand_R:: bit_field i16 { // NOTE Register Operand //
	Rm: i8 | 4,
	id: i8 | 8 }
OPERAND_R_ID::   0b0000_00000000
OPERAND_R_MASK:: 0b1111_11110000
idcheck_operand_R:: proc(operand: Operand_R)-> bool {
	return (i16(operand) & OPERAND_R_MASK) == OPERAND_R_ID }
address_operand_R:: proc(operand: Operand_R, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32(cpu_register_by_index(operand.Rm)^)
	when pre_indexed { Rn^= address }
	return address }
Operand_R_LSL_I:: bit_field i16 { // NOTE Register Operand, Logical Shift Left by Immediate //
	Rm:              i8 | 4,
	id:              i8 | 3,
	shift_immediate: i8 | 5 }
OPERAND_R_LSL_I_ID::   0b0000_00000000
OPERAND_R_LSL_I_MASK:: 0b0000_01110000
idcheck_operand_R_LSL_I:: proc(operand: Operand_R_LSL_I)-> bool {
	return (i16(operand) & OPERAND_R_LSL_I_MASK) == OPERAND_R_LSL_I_ID }
address_operand_R_LSL_I:: proc(operand: Operand_R_LSL_I, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32((cpu_register_by_index(operand.Rm)^)<<u8(operand.shift_immediate))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_LSL_R:: bit_field i16 { // NOTE Register Operand, Logical Shift Left by Register //
	Rm: i8 | 4,
	id: i8 | 4,
	Rs: i8 | 4 }
OPERAND_R_LSL_R_ID::   0b0000_00010000
OPERAND_R_LSL_R_MASK:: 0b0000_11110000
idcheck_operand_R_LSL_R:: proc(operand: Operand_R_LSL_R)-> bool {
	return (i16(operand) & OPERAND_R_LSL_R_MASK) == OPERAND_R_LSL_R_ID }
address_operand_R_LSL_R:: proc(operand: Operand_R_LSL_R, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32((cpu_register_by_index(operand.Rm)^)<<u32((cpu_register_by_index(operand.Rs)^)))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_LSR_I:: bit_field i16 { // NOTE Register Operand, Logical Shift Right by Immediate //
	Rm:              i8 | 4,
	id:              i8 | 3,
	shift_immediate: i8 | 5 }
OPERAND_R_LSR_I_ID::   0b0000_00100000
OPERAND_R_LSR_I_MASK:: 0b0000_01110000
idcheck_operand_R_LSR_I:: proc(operand: Operand_R_LSR_I)-> bool {
	return (i16(operand) & OPERAND_R_LSR_I_MASK) == OPERAND_R_LSR_I_ID }
address_operand_R_LSR_I:: proc(operand: Operand_R_LSR_I, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32((cpu_register_by_index(operand.Rm)^)>>u8(operand.shift_immediate))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_LSR_R:: bit_field i16 { // NOTE Register Operand, Logical Shift Right by Register //
	Rm: i8 | 4,
	id: i8 | 4,
	Rs: i8 | 4 }
OPERAND_R_LSR_R_ID::   0b0000_00110000
OPERAND_R_LSR_R_MASK:: 0b0000_11110000
idcheck_operand_R_LSR_R:: proc(operand: Operand_R_LSR_R)-> bool {
	return (i16(operand) & OPERAND_R_LSR_R_MASK) == OPERAND_R_LSR_R_ID }
address_operand_R_LSR_R:: proc(operand: Operand_R_LSR_R, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32((cpu_register_by_index(operand.Rm)^)>>u32((cpu_register_by_index(operand.Rs)^)))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_ASR_I:: bit_field i16 { // NOTE Register Operand, Arithmetic Shift Right by Immediate //
	Rm:              i8 | 4,
	id:              i8 | 3,
	shift_immediate: i8 | 5 }
OPERAND_R_ASR_I_ID::   0b0000_01000000
OPERAND_R_ASR_I_MASK:: 0b0000_01110000
idcheck_operand_R_ASR_I:: proc(operand: Operand_R_ASR_I)-> bool {
	return (i16(operand) & OPERAND_R_ASR_I_MASK) == OPERAND_R_ASR_I_ID }
address_operand_R_ASR_I:: proc(operand: Operand_R_ASR_I, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32(i32(cpu_register_by_index(operand.Rm)^)>>u8(operand.shift_immediate))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_ASR_R:: bit_field i16 { // NOTE Register Operand, Arithmetic Shift Right by Register //
	Rm: i8 | 4,
	id: i8 | 4,
	Rs: i8 | 4 }
OPERAND_R_ASR_R_ID::   0b0000_01010000
OPERAND_R_ASR_R_MASK:: 0b0000_11110000
idcheck_operand_R_ASR_R:: proc(operand: Operand_R_ASR_R)-> bool {
	return (i16(operand) & OPERAND_R_ASR_R_MASK) == OPERAND_R_ASR_R_ID }
address_operand_R_ASR_R:: proc(operand: Operand_R_ASR_R, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32(i32(cpu_register_by_index(operand.Rm)^)>>u32((cpu_register_by_index(operand.Rs)^)))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_RR_I:: bit_field i16 { // NOTE Register Operand, Rotate Right by Immediate //
	Rm:              i8 | 4,
	id:              i8 | 3,
	shift_immediate: i8 | 5 }
OPERAND_R_RR_I_ID::   0b0000_01100000
OPERAND_R_RR_I_MASK:: 0b0000_01110000
idcheck_operand_R_RR_I:: proc(operand: Operand_R_RR_I)-> bool {
	return (i16(operand) & OPERAND_R_RR_I_MASK) == OPERAND_R_RR_I_ID }
address_operand_R_RR_I:: proc(operand: Operand_R_RR_I, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32(rotate_right(cpu_register_by_index(operand.Rm)^, u8(operand.shift_immediate)))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_RR_R:: bit_field i16 { // NOTE Register Operand, Rotate Right by Register //
	Rm: i8 | 4,
	id: i8 | 4,
	Rs: i8 | 4 }
OPERAND_R_RR_R_ID::   0b0000_01110000
OPERAND_R_RR_R_MASK:: 0b0000_11110000
idcheck_operand_R_RR_R:: proc(operand: Operand_R_RR_R)-> bool {
	return (i16(operand) & OPERAND_R_RR_R_MASK) == OPERAND_R_RR_R_ID }
address_operand_R_RR_R:: proc(operand: Operand_R_RR_R, Rn: ^i32, $pre_indexed: bool)-> (address: u32) {
	address= u32(Rn^) + u32(rotate_right(cpu_register_by_index(operand.Rm)^, (cpu_register_by_index(operand.Rs)^)))
	when pre_indexed { Rn^= address }
	return address }
Operand_R_RRX:: bit_field i16 { // NOTE Register Operand, Rotate Right with Extend //
	Rm: i8 | 4,
	id: i8 | 8 }
OPERAND_R_RRX_ID::   0b0000_01100000
OPERAND_R_RRX_MASK:: 0b1111_11110000
idcheck_operand_R_RRX:: proc(operand: Operand_R_RRX)-> bool {
	return (i16(operand) & OPERAND_R_RRX_MASK) == OPERAND_R_RRX_ID }