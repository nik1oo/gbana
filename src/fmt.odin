package gbana
import "core:fmt"
import "core:log"
import "core:strings"


// ANSI COLOR CODES //
ANSI_BLACK::             "\e[0;30m"
ANSI_RED::               "\e[0;31m"
ANSI_GREEN::             "\e[0;32m"
ANSI_YELLOW::            "\e[0;33m"
ANSI_BLUE::              "\e[0;34m"
ANSI_PURPLE::            "\e[0;35m"
ANSI_CYAN::              "\e[0;36m"
ANSI_WHITE::             "\e[0;37m"
ANSI_BOLD_BLACK::        "\e[1;30m"
ANSI_BOLD_RED::          "\e[1;31m"
ANSI_BOLD_GREEN::        "\e[1;32m"
ANSI_BOLD_YELLOW::       "\e[1;33m"
ANSI_BOLD_BLUE::         "\e[1;34m"
ANSI_BOLD_PURPLE::       "\e[1;35m"
ANSI_BOLD_CYAN::         "\e[1;36m"
ANSI_BOLD_WHITE::        "\e[1;37m"
ANSI_UNDERLINED_BLACK::  "\e[4;30m"
ANSI_UNDERLINED_RED::    "\e[4;31m"
ANSI_UNDERLINED_GREEN::  "\e[4;32m"
ANSI_UNDERLINED_YELLOW:: "\e[4;33m"
ANSI_UNDERLINED_BLUE::   "\e[4;34m"
ANSI_UNDERLINED_PURPLE:: "\e[4;35m"
ANSI_UNDERLINED_CYAN::   "\e[4;36m"
ANSI_UNDERLINED_WHITE::  "\e[4;37m"
ANSI_RESET::             "\e[0m"


// INSTRUCTIONS //
aprint_instruction:: proc(ins_decoded: GBA_Instruction_Decoded, allocator: = context.allocator) -> string {
	switch ins in ins_decoded {
	case GBA_ADC_Instruction_Decoded:       return aprint_ADC(ins, allocator)
	case GBA_ADD_Instruction_Decoded:       return aprint_ADD(ins, allocator)
	case GBA_AND_Instruction_Decoded:       return aprint_AND(ins, allocator)
	case GBA_B_Instruction_Decoded:         return aprint_B(ins, allocator)
	case GBA_BL_Instruction_Decoded:        return aprint_BL(ins, allocator)
	case GBA_BIC_Instruction_Decoded:       return aprint_BIC(ins, allocator)
	case GBA_BX_Instruction_Decoded:        return aprint_BX(ins, allocator)
	case GBA_CMN_Instruction_Decoded:       return aprint_CMN(ins, allocator)
	case GBA_CMP_Instruction_Decoded:       return aprint_CMP(ins, allocator)
	case GBA_EOR_Instruction_Decoded:       return aprint_EOR(ins, allocator)
	case GBA_LDM_Instruction_Decoded:       return aprint_LDM(ins, allocator)
	case GBA_LDR_Instruction_Decoded:       return aprint_LDR(ins, allocator)
	case GBA_LDRB_Instruction_Decoded:      return aprint_LDRB(ins, allocator)
	case GBA_LDRBT_Instruction_Decoded:     return aprint_LDRBT(ins, allocator)
	case GBA_LDRH_Instruction_Decoded:      return aprint_LDRH(ins, allocator)
	case GBA_LDRSB_Instruction_Decoded:     return aprint_LDRSB(ins, allocator)
	case GBA_LDRSH_Instruction_Decoded:     return aprint_LDRSH(ins, allocator)
	case GBA_LDRT_Instruction_Decoded:      return aprint_LDRT(ins, allocator)
	case GBA_MLA_Instruction_Decoded:       return aprint_MLA(ins, allocator)
	case GBA_MOV_Instruction_Decoded:       return aprint_MOV(ins, allocator)
	case GBA_MRS_Instruction_Decoded:       return aprint_MRS(ins, allocator)
	case GBA_MSR_Instruction_Decoded:       return aprint_MSR(ins, allocator)
	case GBA_MUL_Instruction_Decoded:       return aprint_MUL(ins, allocator)
	case GBA_MVN_Instruction_Decoded:       return aprint_MVN(ins, allocator)
	case GBA_ORR_Instruction_Decoded:       return aprint_ORR(ins, allocator)
	case GBA_RSB_Instruction_Decoded:       return aprint_RSB(ins, allocator)
	case GBA_RSC_Instruction_Decoded:       return aprint_RSC(ins, allocator)
	case GBA_SBC_Instruction_Decoded:       return aprint_SBC(ins, allocator)
	case GBA_SMLAL_Instruction_Decoded:     return aprint_SMLAL(ins, allocator)
	case GBA_SMULL_Instruction_Decoded:     return aprint_SMULL(ins, allocator)
	case GBA_STM_Instruction_Decoded:       return aprint_STM(ins, allocator)
	case GBA_STR_Instruction_Decoded:       return aprint_STR(ins, allocator)
	case GBA_STRB_Instruction_Decoded:      return aprint_STRB(ins, allocator)
	case GBA_STRBT_Instruction_Decoded:     return aprint_STRBT(ins, allocator)
	case GBA_STRH_Instruction_Decoded:      return aprint_STRH(ins, allocator)
	case GBA_STRT_Instruction_Decoded:      return aprint_STRT(ins, allocator)
	case GBA_SUB_Instruction_Decoded:       return aprint_SUB(ins, allocator)
	case GBA_SWI_Instruction_Decoded:       return aprint_SWI(ins, allocator)
	case GBA_SWP_Instruction_Decoded:       return aprint_SWP(ins, allocator)
	case GBA_SWPB_Instruction_Decoded:      return aprint_SWPB(ins, allocator)
	case GBA_TEQ_Instruction_Decoded:       return aprint_TEQ(ins, allocator)
	case GBA_TST_Instruction_Decoded:       return aprint_TST(ins, allocator)
	case GBA_UMLAL_Instruction_Decoded:     return aprint_UMLAL(ins, allocator)
	case GBA_UMULL_Instruction_Decoded:     return aprint_UMULL(ins, allocator)
	case GBA_Undefined_Instruction_Decoded: return aprint_UNDEF(ins, allocator)
	case:                                   log.panic("instruction badly decoded") } }
_aprint_instruction:: proc(name: string, fields: []string, allocator: = context.allocator) -> string {
	return fmt.aprint("[", name, "|", strings.join(fields, sep = " | "), "]") }
aprint_ADC:: proc(ins: GBA_ADC_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sADC%s   [ IF %s THEN %s = %d + %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_ADD:: proc(ins: GBA_ADD_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sADD%s   [ IF %s THEN %s = %d + %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_AND:: proc(ins: GBA_AND_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sAND%s   [ IF %s THEN %s = %d & %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_B:: proc(ins: GBA_B_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sB%s     [ IF %s THEN PC = %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.target_address) }
aprint_BL:: proc(ins: GBA_BL_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sBL%s    [ IF %s THEN PC = %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.target_address) }
aprint_BIC:: proc(ins: GBA_BIC_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sBIC%s   [ IF %s THEN %s = %d & ~ %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_BX:: proc(ins: GBA_BX_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sBX%s    [ IF %s THEN PC = %d, T = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.target_address, ins.thumb_mode ? "TRUE" : "FALSE") }
aprint_CMN:: proc(ins: GBA_CMN_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sCMN%s   [ IF %s THEN FLAGS = %d CMP -%d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.operand, ins.shifter_operand) }
aprint_CMP:: proc(ins: GBA_CMP_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sCMP%s   [ IF %s THEN FLAGS = %d CMP %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.operand, ins.shifter_operand) }
aprint_EOR:: proc(ins: GBA_EOR_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sEOR%s   [ IF %s THEN %s = %d ~ %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_LDM:: proc(ins: GBA_LDM_Instruction_Decoded, allocator: = context.allocator) -> string {
	using state: ^State = cast(^State)context.user_ptr
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 1024, allocator = context.temp_allocator)
	fmt.sbprintf(&sb, "%sLDM%s   [ IF %s THEN ", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond))
	for destination in ins.destination_registers do fmt.sbprintf(&sb, "%s ", gba_register_name(gba_core.logical_registers.array[destination]))
	fmt.sbprintf(&sb, "= (%d) ]", ins.start_address)
	return strings.to_string(sb) }
aprint_LDR:: proc(ins: GBA_LDR_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDR%s   [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_LDRB:: proc(ins: GBA_LDRB_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDRB%s  [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_LDRBT:: proc(ins: GBA_LDRBT_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDRBT%s [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_LDRH:: proc(ins: GBA_LDRH_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDRH%s  [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_LDRSB:: proc(ins: GBA_LDRSB_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDRSB%s [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_LDRSH:: proc(ins: GBA_LDRSH_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDRSH%s [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_LDRT:: proc(ins: GBA_LDRT_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sLDRT%s  [ IF %s THEN %s = (%d) ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.address) }
aprint_MLA:: proc(ins: GBA_MLA_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sMLA%s   [ IF %s THEN %s = %d * %d + %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.multiplicand, ins.addend) }
aprint_MOV:: proc(ins: GBA_MOV_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sMOV%s   [ IF %s THEN %s = %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.shifter_operand) }
aprint_MRS:: proc(ins: GBA_MRS_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sMRS%s   [ IF %s THEN %s = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), gba_register_name(ins.source)) }
aprint_MSR:: proc(ins: GBA_MSR_Instruction_Decoded, allocator: = context.allocator) -> string {
	using state: ^State = cast(^State)context.user_ptr
	return fmt.aprintf("%sMSR%s   [ IF %s THEN %s = %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(gba_core.logical_registers.array[ins.destination]), ins.operand) }
aprint_MUL:: proc(ins: GBA_MUL_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sMUL%s   [ IF %s THEN %s = %d * %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.multiplicand) }
aprint_MVN:: proc(ins: GBA_MVN_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sMVN%s   [ IF %s THEN %s = -%d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.shifter_operand) }
aprint_ORR:: proc(ins: GBA_ORR_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sOR%s    [ IF %s THEN %s = %d | %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_RSB:: proc(ins: GBA_RSB_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sRSB%s   [ IF %s THEN %s = %d - %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.shifter_operand, ins.operand) }
aprint_RSC:: proc(ins: GBA_RSC_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sRSC%s   [ IF %s THEN %s = %d - %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.shifter_operand, ins.operand) }
aprint_SBC:: proc(ins: GBA_SBC_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSBC%s   [ IF %s THEN %s = %d - %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_SMLAL:: proc(ins: GBA_SMLAL_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSMLAL%s [ IF %s THEN %s %s = %d * %d %d + %s %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destinations[0]), gba_register_name(ins.destinations[1]), ins.operand, ins.multiplicands[0], ins.multiplicands[1], gba_register_name(ins.destinations[0]), gba_register_name(ins.destinations[1])) }
aprint_SMULL:: proc(ins: GBA_SMULL_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSMLAL%s [ IF %s THEN %s %s = %d * %d %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destinations[0]), gba_register_name(ins.destinations[1]), ins.operand, ins.multiplicands[0], ins.multiplicands[1]) }
aprint_STM:: proc(ins: GBA_STM_Instruction_Decoded, allocator: = context.allocator) -> string {
	using state: ^State = cast(^State)context.user_ptr
	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, 1024, allocator = context.temp_allocator)
	fmt.sbprintf(&sb, "%sSTM%s   [ IF %s THEN (%d) = ", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.start_address)
	for destination in ins.source_registers do fmt.sbprintf(&sb, "%s ", gba_register_name(gba_core.logical_registers.array[destination]))
	fmt.sbprintf(&sb, " ]")
	return strings.to_string(sb) }
aprint_STR:: proc(ins: GBA_STR_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSTR%s   [ IF %s THEN (%d) = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.address, gba_register_name(ins.source)) }
aprint_STRB:: proc(ins: GBA_STRB_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSTRB%s  [ IF %s THEN (%d) = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.address, gba_register_name(ins.source)) }
aprint_STRBT:: proc(ins: GBA_STRBT_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSTRBT%s [ IF %s THEN (%d) = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.address, gba_register_name(ins.source)) }
aprint_STRH:: proc(ins: GBA_STRH_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSTRH%s  [ IF %s THEN (%d) = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.address, gba_register_name(ins.source)) }
aprint_STRT:: proc(ins: GBA_STRT_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSTRT%s  [ IF %s THEN (%d) = %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.address, gba_register_name(ins.source)) }
aprint_SUB:: proc(ins: GBA_SUB_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSUB%s   [ IF %s THEN %s = %d - %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destination), ins.operand, ins.shifter_operand) }
aprint_SWI:: proc(ins: GBA_SWI_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSWI%s   [ IF %s THEN THROW %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.immediate) }
aprint_SWP:: proc(ins: GBA_SWP_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSWP%s   [ IF %s THEN %s <-> %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.source_register), gba_register_name(ins.destination_register)) }
aprint_SWPB:: proc(ins: GBA_SWPB_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sSWPB%s  [ IF %s THEN %s <-> %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.source_register), gba_register_name(ins.destination_register)) }
aprint_TEQ:: proc(ins: GBA_TEQ_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sTEQ%s   [ IF %s THEN FLAGS = %d EQ %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.operand, ins.shifter_operand) }
aprint_TST:: proc(ins: GBA_TST_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sTST%s   [ IF %s THEN FLAGS = %d && %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), ins.operand, ins.shifter_operand) }
aprint_UMLAL:: proc(ins: GBA_UMLAL_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sUMLAL%s [ IF %s THEN %s %s = %d * %d %d + %s %s ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destinations[0]), gba_register_name(ins.destinations[1]), ins.operand, ins.multiplicands[0], ins.multiplicands[1], gba_register_name(ins.destinations[0]), gba_register_name(ins.destinations[1])) }
aprint_UMULL:: proc(ins: GBA_UMULL_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sUMULL%s [ IF %s THEN %s %s = %d * %d %d ]", ANSI_GREEN, ANSI_RESET, fmt.aprint(ins.cond), gba_register_name(ins.destinations[0]), gba_register_name(ins.destinations[1]), ins.operand, ins.multiplicands[0], ins.multiplicands[1]) }
aprint_UNDEF:: proc(ins: GBA_Undefined_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("%sUNDEF%s [ ]", ANSI_GREEN, ANSI_RESET) }
DIVLINE:: "-----------------------------------------------------------------------------------------------"
aprint_instruction_info_header:: proc() -> string {
	return fmt.aprint(DIVLINE, "\n  ADDR   RAW                               INS   OP\n", DIVLINE, sep = "") }
aprint_instruction_info:: proc(ins_address: u32, ins_raw: u32, ins_decoded: GBA_Instruction_Decoded, allocator: = context.allocator) -> string {
	return fmt.aprintf("  %4d   %32b  %s", ins_address, ins_raw, aprint_instruction(ins_decoded)) }