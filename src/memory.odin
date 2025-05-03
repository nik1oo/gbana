package gbana
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:encoding/endian"
import "core:mem"
import "core:slice"
import "core:thread"
import "core:log"


// INTERFACE //
Memory_Read_Write:: enum u8 { WRITE, READ }
Memory_Access_Size:: enum u8 { BYTE, HALFWORD, WORD }
Memory_Interface:: struct {
	main_clock:                     Signal(bool),               // MCLK
	address:                        Signal(u32),                // A
	byte_latch_control:             Signal(u8),                 // BL
	data_out:                       Signal(u32),                // DOUT
	lock:                           Signal(bool),               // LOCK
	memory_access_size:             Signal(Memory_Access_Size), // MAS
	memory_request:                 Signal(bool),               // MREQ
	sequential_cycle:               Signal(bool),               // SEQ
	op_code_fetch:                  Signal(bool),               // OPC
	read_write:                     Signal(Memory_Read_Write)      } // RW
init_memory_interface:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	memory.interface = {}
	signal_init("MCLK", &memory.main_clock,           2, main_clock_callback,           write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("OPC",  &memory.op_code_fetch,        1, memory_op_code_fetch_callback,        write_phase = { HIGH_PHASE            })
	signal_init("A",    &memory.address,              1, memory_address_callback,              write_phase = { LOW_PHASE             })
	signal_init("DOUT", &memory.data_out,             1, memory_data_out_callback,             write_phase = { LOW_PHASE             })
	signal_init("MREQ", &memory.memory_request,       1, memory_memory_request_callback,       write_phase = { LOW_PHASE             })
	signal_init("SEQ",  &memory.sequential_cycle,     1, memory_sequential_cycle_callback,     write_phase = { LOW_PHASE             })
	signal_init("RW",   &memory.read_write,           1, memory_read_write_callback,           write_phase = { HIGH_PHASE            })
	signal_init("MAS",  &memory.memory_access_size,   1, memory_memory_access_size_callback,   write_phase = { HIGH_PHASE            })
	signal_init("BL",   &memory.byte_latch_control,   1, memory_byte_latch_control_callback,   write_phase = { LOW_PHASE             })
	signal_init("LOCK", &memory.lock,                 1, memory_lock_callback,                 write_phase = { HIGH_PHASE            })
	signal_put(&memory.main_clock, true) }


// THREAD //
memory_thread_proc:: proc(t: ^thread.Thread) { }


// SIGNAL LOGIC //
memory_op_code_fetch_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
memory_address_callback:: proc(self: ^Signal(u32), old_output, new_output: u32) { }
memory_data_out_callback:: proc(self: ^Signal(u32), old_output, new_output: u32) {  }
memory_memory_request_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
memory_sequential_cycle_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
memory_read_write_callback:: proc(self: ^Signal(Memory_Read_Write), old_output, new_output: Memory_Read_Write) { }
memory_memory_access_size_callback:: proc(self: ^Signal(Memory_Access_Size), old_output, new_output: Memory_Access_Size) {  }
memory_byte_latch_control_callback:: proc(self: ^Signal(u8), old_output, new_output: u8) {  }
memory_lock_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }


// ENDIANNESS //
// endian.Byte_Order
Endian_Word:: union { Little_Endian_Word, Big_Endian_Word }
Little_Endian_Word:: struct #raw_union {
	using words: struct { word_0: u32 },
	using halfwords: struct { halfword_0: u16, halfword_1: u16 },
	using bytes: struct { byte_0: u8, byte_1: u8, byte_2: u8, byte_3: u8 } }
Big_Endian_Word:: struct #raw_union {
	using words: struct { word_0: u32 },
	using halfwords: struct { halfword_1: u16, halfword_0: u16 },
	using bytes: struct { byte_3: u8, byte_2: u8, byte_1: u8, byte_0: u8 } }
endian_word_get_word_0:: proc(word: $T) -> u32 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.word_0 }
endian_word_get_halfword_0:: proc(word: $T) -> u16 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.halfword_0 }
endian_word_get_halfword_1:: proc(word: $T) -> u16 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.halfword_1 }
endian_word_get_byte_0:: proc(word: $T) -> u8 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.byte_0 }
endian_word_get_byte_1:: proc(word: $T) -> u8 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.byte_1 }
endian_word_get_byte_2:: proc(word: $T) -> u8 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.byte_2 }
endian_word_get_byte_3:: proc(word: $T) -> u8 {
	#assert((T == Little_Endian_Word) || (T == Big_Endian_Word))
	return word.byte_3 }


// NOTE Save data is Flash, not SRAM.
// NOTE Data format is always little-endian.


// Internal Memory
//   BIOS ROM     16 KBytes
//   Work RAM     288 KBytes (Fast 32K on-chip, plus Slow 256K on-board)
//   VRAM         96 KBytes
//   OAM          1 KByte (128 OBJs 3x16bit, 32 OBJ-Rotation/Scalings 4x16bit)
//   Palette RAM  1 KByte (256 BG colors, 256 OBJ colors)


// MEMORY REGIONS [BYTES] //
START:: 0
END::   1
SYSTEM_ROM_RANGE::             [2]u32{ 0x00000000, 0x00003fff }
BIOS_RANGE::                   [2]u32{ 0x00000000, 0x00003fff } // boot rom
EXTERNAL_WORK_RAM_RANGE::      [2]u32{ 0x02000000, 0x0203ffff } // this is the slow RAM
INTERNAL_WORK_RAM_RANGE::      [2]u32{ 0x03000000, 0x03007fff } // this is the fast RAM
INPUT_OUTPUT_RAM_RANGE::       [2]u32{ 0x04000000, 0x040003ff }
PALETTE_RAM_RANGE::            [2]u32{ 0x05000000, 0x050003ff } // is this where sprites are stored?
BACKGROUND_PALETTE_RAM_RANGE:: [2]u32{ 0x05000000, 0x050003ff }
SPRITES_PALETTE_RAM_RANGE::    [2]u32{ 0x05002000, 0x050023ff }
VIDEO_RAM_RANGE::              [2]u32{ 0x06000000, 0x06017fff } // mainly for storing the framebuffer
OAM_RANGE::                    [2]u32{ 0x07000000, 0x070003ff } // object attribute memory, for sprites control
CARTRIDGE_HEADER::             [2]u32{ 0x08000000, 0x080000BF } // 192-byte cartridge header
CARTRIDGE_GAME_DATA_0_RANGE::  [2]u32{ 0x08000000, 0x09ffffff } // this is the game cartridge ROM
CARTRIDGE_GAME_DATA_1_RANGE::  [2]u32{ 0x0a000000, 0x0bffffff } // this is a mirror of game ROM
CARTRIDGE_GAME_DATA_2_RANGE::  [2]u32{ 0x0c000000, 0x0dffffff } // this is a mirror of game ROM
CARTRIDGE_SAVE_DATA_RANGE::    [2]u32{ 0x0e000000, 0x0e00ffff } // SRAM or flash ROM, used for game save data


// VALIDITY //
memory_address_is_valid:: proc(address: u32) -> bool {
	switch address {
	case BIOS_RANGE[START]                  ..= BIOS_RANGE[END]:                  return true
	case EXTERNAL_WORK_RAM_RANGE[START]     ..= EXTERNAL_WORK_RAM_RANGE[END]:     return true
	case INTERNAL_WORK_RAM_RANGE[START]     ..= INTERNAL_WORK_RAM_RANGE[END]:     return true
	case INPUT_OUTPUT_RAM_RANGE[START]      ..= INPUT_OUTPUT_RAM_RANGE[END]:      return true
	case OAM_RANGE[START]                   ..= OAM_RANGE[END]:                   return true
	case PALETTE_RAM_RANGE[START]           ..= PALETTE_RAM_RANGE[END]:           return true
	case VIDEO_RAM_RANGE[START]             ..= VIDEO_RAM_RANGE[END]:             return true
	case CARTRIDGE_GAME_DATA_0_RANGE[START] ..= CARTRIDGE_GAME_DATA_2_RANGE[END]: return true
	case CARTRIDGE_SAVE_DATA_RANGE[START]   ..= CARTRIDGE_SAVE_DATA_RANGE[END]:   return true
	case:                                                                         return false } }


// MEMORY BUS WIDTH [BYTES] //
BIOS_BUS_WIDTH::              4
EXTERNAL_WORK_RAM_BUS_WIDTH:: 2
INTERNAL_WORK_RAM_BUS_WIDTH:: 4
INPUT_OUTPUT_RAM_BUS_WIDTH::  4
OAM_BUS_WIDTH::               4
PALETTE_RAM_BUS_WIDTH::       2
VIDEO_RAM_BUS_WIDTH::         2
CARTRIDGE_ROM_BUS_WIDTH::     2
CARTRIDGE_FLASH_BUS_WIDTH::   2
memory_bus_width_from_address:: proc(address: u32) -> uint {
	switch address {
	case BIOS_RANGE[START]                  ..= BIOS_RANGE[END]:                  return BIOS_BUS_WIDTH
	case EXTERNAL_WORK_RAM_RANGE[START]     ..= EXTERNAL_WORK_RAM_RANGE[END]:     return EXTERNAL_WORK_RAM_BUS_WIDTH
	case INTERNAL_WORK_RAM_RANGE[START]     ..= INTERNAL_WORK_RAM_RANGE[END]:     return INTERNAL_WORK_RAM_BUS_WIDTH
	case INPUT_OUTPUT_RAM_RANGE[START]      ..= INPUT_OUTPUT_RAM_RANGE[END]:      return INPUT_OUTPUT_RAM_BUS_WIDTH
	case OAM_RANGE[START]                   ..= OAM_RANGE[END]:                   return OAM_BUS_WIDTH
	case PALETTE_RAM_RANGE[START]           ..= PALETTE_RAM_RANGE[END]:           return PALETTE_RAM_BUS_WIDTH
	case VIDEO_RAM_RANGE[START]             ..= VIDEO_RAM_RANGE[END]:             return VIDEO_RAM_BUS_WIDTH
	case CARTRIDGE_GAME_DATA_0_RANGE[START] ..= CARTRIDGE_GAME_DATA_2_RANGE[END]: return CARTRIDGE_ROM_BUS_WIDTH
	case CARTRIDGE_SAVE_DATA_RANGE[START]   ..= CARTRIDGE_SAVE_DATA_RANGE[END]:   return CARTRIDGE_FLASH_BUS_WIDTH
	case:                                                                         return 0 } }
// TODO Add rules for this on `memory_read` and `memory_write`


// MEMORY BUS LATENCY [CYCLES] //
@(rodata) BIOS_LATENCY:              [3]int = [3]int{1, 1, 1}
@(rodata) EXTERNAL_WORK_RAM_LATENCY: [3]int = [3]int{3, 3, 6}
@(rodata) INTERNAL_WORK_RAM_LATENCY: [3]int = [3]int{1, 1, 1}
@(rodata) INPUT_OUTPUT_RAM_LATENCY:  [3]int = [3]int{1, 1, 1}
@(rodata) OAM_LATENCY:               [3]int = [3]int{1, 1, 1}
@(rodata) PALETTE_RAM_LATENCY:       [3]int = [3]int{1, 1, 2}
@(rodata) VIDEO_RAM_LATENCY:         [3]int = [3]int{1, 1, 2}
@(rodata) CARTRIDGE_ROM_LATENCY:     [3]int = [3]int{5, 5, 8}
@(rodata) CARTRIDGE_FLASH_LATENCY:   [3]int = [3]int{5, 5, 8} // Flash
memory_bus_latency_from_address:: proc(address: u32, width: uint) -> int {
	assert((width == 1) || (width == 2) || (width == 4))
	w: = (width == 1) ? 0 : (width == 2) ? 1 : 2
	switch address {
	case BIOS_RANGE[START]                  ..= BIOS_RANGE[END]:                  return BIOS_LATENCY[w]
	case EXTERNAL_WORK_RAM_RANGE[START]     ..= EXTERNAL_WORK_RAM_RANGE[END]:     return EXTERNAL_WORK_RAM_LATENCY[w]
	case INTERNAL_WORK_RAM_RANGE[START]     ..= INTERNAL_WORK_RAM_RANGE[END]:     return INTERNAL_WORK_RAM_LATENCY[w]
	case INPUT_OUTPUT_RAM_RANGE[START]      ..= INPUT_OUTPUT_RAM_RANGE[END]:      return INPUT_OUTPUT_RAM_LATENCY[w]
	case OAM_RANGE[START]                   ..= OAM_RANGE[END]:                   return OAM_LATENCY[w]
	case PALETTE_RAM_RANGE[START]           ..= PALETTE_RAM_RANGE[END]:           return PALETTE_RAM_LATENCY[w]
	case VIDEO_RAM_RANGE[START]             ..= VIDEO_RAM_RANGE[END]:             return VIDEO_RAM_LATENCY[w]
	case CARTRIDGE_GAME_DATA_0_RANGE[START] ..= CARTRIDGE_GAME_DATA_2_RANGE[END]: return CARTRIDGE_ROM_LATENCY[w]
	case CARTRIDGE_SAVE_DATA_RANGE[START]   ..= CARTRIDGE_SAVE_DATA_RANGE[END]:   return CARTRIDGE_FLASH_LATENCY[w]
	case:                                                                         return 1 } }
// TODO Implement these timings on the memory access cycles. //


// memory_clone_convert:: proc(address: u32, count: uint, allocator: = context.allocator) -> []u8 {
// 	return nil
// }


// I/O REGISTER LOCATIONS [BYTES] //
// LCD Registers //
IO_Register:: enum {
	DISPCNT,
	GSWP,
	DISPSTAT,
	VCOUNT,
	BG0CNT,
	BG1CNT,
	BG2CNT,
	BG3CNT,
	BG0HOFS,
	BG0VOFS,
	BG1HOFS,
	BG1VOFS,
	BG2HOFS,
	BG2VOFS,
	BG3HOFS,
	BG3VOFS,
	BG2PA,
	BG2PB,
	BG2PC,
	BG2PD,
	BG2X,
	BG2Y,
	BG3PA,
	BG3PB,
	BG3PC,
	BG3PD,
	BG3X,
	BG3Y,
	WIN0H,
	WIN1H,
	WIN0V,
	WIN1V,
	WININ,
	WINOUT,
	MOSAIC,
	BLDCNT,
	BLDALPHA,
	BLDY,
	SOUND1CNT_L,
	SOUND1CNT_H,
	SOUND1CNT_X,
	SOUND2CNT_L,
	SOUND2CNT_H,
	SOUND3CNT_L,
	SOUND3CNT_H,
	SOUND3CNT_X,
	SOUND4CNT_L,
	SOUND4CNT_H,
	SOUNDCNT_L,
	SOUNDCNT_H,
	SOUNDCNT_X,
	SOUNDBIAS,
	WAVE_RAM,
	FIFO_A,
	FIFO_B,
	DMA0SAD,
	DMA0DAD,
	DMA0CNT_L,
	DMA0CNT_H,
	DMA1SAD,
	DMA1DAD,
	DMA1CNT_L,
	DMA1CNT_H,
	DMA2SAD,
	DMA2DAD,
	DMA2CNT_L,
	DMA2CNT_H,
	DMA3SAD,
	DMA3DAD,
	DMA3CNT_L,
	DMA3CNT_H,
	TM0CNT_L,
	TM0CNT_H,
	TM1CNT_L,
	TM1CNT_H,
	TM2CNT_L,
	TM2CNT_H,
	TM3CNT_L,
	TM3CNT_H,
	SIODATA32,
	SIOMULTI0,
	SIOMULTI1,
	SIOMULTI2,
	SIOMULTI3,
	SIOCNT,
	SIOMLT_SEND,
	SIODATA8,
	RCNT,
	JOYCNT,
	JOY_RECV,
	JOY_TRANS,
	JOYSTAT,
	KEYINPUT,
	KEYCNT,
	IE,
	IF,
	WAITCNT,
	IME,
	POSTFLG,
	HALTCNT,
	UNDOCUMENTED_0x4000800 }
WIDTH:: 1
@(init) _init_io_registers:: proc() {
	IO_REGISTER_ADDRESSES:: [len(IO_Register)][2]int{
		// Display Registers //
		IO_Register.DISPCNT =                [2]int{ 0x4000000, 2}, // LCD Control
		IO_Register.GSWP =                   [2]int{ 0x4000002, 2}, // Green Swap
		IO_Register.DISPSTAT =               [2]int{ 0x4000004, 2}, // General LCD Status (STAT,LYC)
		IO_Register.VCOUNT =                 [2]int{ 0x4000006, 2}, // Vertical Counter (LY)
		IO_Register.BG0CNT =                 [2]int{ 0x4000008, 2}, // BG0 Control
		IO_Register.BG1CNT =                 [2]int{ 0x400000A, 2}, // BG1 Control
		IO_Register.BG2CNT =                 [2]int{ 0x400000C, 2}, // BG2 Control
		IO_Register.BG3CNT =                 [2]int{ 0x400000E, 2}, // BG3 Control
		IO_Register.BG0HOFS =                [2]int{ 0x4000010, 2}, // BG0 X-Offset
		IO_Register.BG0VOFS =                [2]int{ 0x4000012, 2}, // BG0 Y-Offset
		IO_Register.BG1HOFS =                [2]int{ 0x4000014, 2}, // BG1 X-Offset
		IO_Register.BG1VOFS =                [2]int{ 0x4000016, 2}, // BG1 Y-Offset
		IO_Register.BG2HOFS =                [2]int{ 0x4000018, 2}, // BG2 X-Offset
		IO_Register.BG2VOFS =                [2]int{ 0x400001A, 2}, // BG2 Y-Offset
		IO_Register.BG3HOFS =                [2]int{ 0x400001C, 2}, // BG3 X-Offset
		IO_Register.BG3VOFS =                [2]int{ 0x400001E, 2}, // BG3 Y-Offset
		IO_Register.BG2PA =                  [2]int{ 0x4000020, 2}, // BG2 Rotation/Scaling Parameter A (dx)
		IO_Register.BG2PB =                  [2]int{ 0x4000022, 2}, // BG2 Rotation/Scaling Parameter B (dmx)
		IO_Register.BG2PC =                  [2]int{ 0x4000024, 2}, // BG2 Rotation/Scaling Parameter C (dy)
		IO_Register.BG2PD =                  [2]int{ 0x4000026, 2}, // BG2 Rotation/Scaling Parameter D (dmy)
		IO_Register.BG2X =                   [2]int{ 0x4000028, 4}, // BG2 Reference Point X-Coordinate
		IO_Register.BG2Y =                   [2]int{ 0x400002C, 4}, // BG2 Reference Point Y-Coordinate
		IO_Register.BG3PA =                  [2]int{ 0x4000030, 2}, // BG3 Rotation/Scaling Parameter A (dx)
		IO_Register.BG3PB =                  [2]int{ 0x4000032, 2}, // BG3 Rotation/Scaling Parameter B (dmx)
		IO_Register.BG3PC =                  [2]int{ 0x4000034, 2}, // BG3 Rotation/Scaling Parameter C (dy)
		IO_Register.BG3PD =                  [2]int{ 0x4000036, 2}, // BG3 Rotation/Scaling Parameter D (dmy)
		IO_Register.BG3X =                   [2]int{ 0x4000038, 4}, // BG3 Reference Point X-Coordinate
		IO_Register.BG3Y =                   [2]int{ 0x400003C, 4}, // BG3 Reference Point Y-Coordinate
		IO_Register.WIN0H =                  [2]int{ 0x4000040, 2}, // Window 0 Horizontal Dimensions
		IO_Register.WIN1H =                  [2]int{ 0x4000042, 2}, // Window 1 Horizontal Dimensions
		IO_Register.WIN0V =                  [2]int{ 0x4000044, 2}, // Window 0 Vertical Dimensions
		IO_Register.WIN1V =                  [2]int{ 0x4000046, 2}, // Window 1 Vertical Dimensions
		IO_Register.WININ =                  [2]int{ 0x4000048, 2}, // Inside of Window 0 and 1
		IO_Register.WINOUT =                 [2]int{ 0x400004A, 2}, // Inside of OBJ Window & Outside of Windows
		IO_Register.MOSAIC =                 [2]int{ 0x400004C, 2}, // Mosaic Size
		IO_Register.BLDCNT =                 [2]int{ 0x4000050, 2}, // Color Special Effects Selection
		IO_Register.BLDALPHA =               [2]int{ 0x4000052, 2}, // Alpha Blending Coefficients
		IO_Register.BLDY =                   [2]int{ 0x4000054, 2}, // Brightness (Fade-In/Out) Coefficient
		// Sound Registers //
		IO_Register.SOUND1CNT_L =            [2]int{ 0x4000060, 2 },    // Channel 1 Sweep register       (NR10)
		IO_Register.SOUND1CNT_H =            [2]int{ 0x4000062, 2 },    // Channel 1 Duty/Length/Envelope (NR11, NR12)
		IO_Register.SOUND1CNT_X =            [2]int{ 0x4000064, 2 },    // Channel 1 Frequency/Control    (NR13, NR14)
		IO_Register.SOUND2CNT_L =            [2]int{ 0x4000068, 2 },    // Channel 2 Duty/Length/Envelope (NR21, NR22)
		IO_Register.SOUND2CNT_H =            [2]int{ 0x400006C, 2 },    // Channel 2 Frequency/Control    (NR23, NR24)
		IO_Register.SOUND3CNT_L =            [2]int{ 0x4000070, 2 },    // Channel 3 Stop/Wave RAM select (NR30)
		IO_Register.SOUND3CNT_H =            [2]int{ 0x4000072, 2 },    // Channel 3 Length/Volume        (NR31, NR32)
		IO_Register.SOUND3CNT_X =            [2]int{ 0x4000074, 2 },    // Channel 3 Frequency/Control    (NR33, NR34)
		IO_Register.SOUND4CNT_L =            [2]int{ 0x4000078, 2 },    // Channel 4 Length/Envelope      (NR41, NR42)
		IO_Register.SOUND4CNT_H =            [2]int{ 0x400007C, 2 },    // Channel 4 Frequency/Control    (NR43, NR44)
		IO_Register.SOUNDCNT_L =             [2]int{ 0x4000080, 2 },    // Control Stereo/Volume/Enable   (NR50, NR51)
		IO_Register.SOUNDCNT_H =             [2]int{ 0x4000082, 2 },    // Control Mixing/DMA Control
		IO_Register.SOUNDCNT_X =             [2]int{ 0x4000084, 2 },    // Control Sound on/off           (NR52)
		IO_Register.SOUNDBIAS =              [2]int{ 0x4000088, 2 },    // Sound PWM Control
		IO_Register.WAVE_RAM =               [2]int{ 0x4000090, 0x20 }, // Channel 3 Wave Pattern RAM (2 banks!!)
		IO_Register.FIFO_A =                 [2]int{ 0x40000A0, 4 },    // Channel A FIFO, Data 0-3
		IO_Register.FIFO_B =                 [2]int{ 0x40000A4, 4 },    // Channel B FIFO, Data 0-3
		// DMA Transfer Channels //
		IO_Register.DMA0SAD =                [2]int{ 0x40000B0, 4 }, // Source Address
		IO_Register.DMA0DAD =                [2]int{ 0x40000B4, 4 }, // Destination Address
		IO_Register.DMA0CNT_L =              [2]int{ 0x40000B8, 2 }, // Word Count
		IO_Register.DMA0CNT_H =              [2]int{ 0x40000BA, 2 }, // Control
		IO_Register.DMA1SAD =                [2]int{ 0x40000BC, 4 }, // Source Address
		IO_Register.DMA1DAD =                [2]int{ 0x40000C0, 4 }, // Destination Address
		IO_Register.DMA1CNT_L =              [2]int{ 0x40000C4, 2 }, // Word Count
		IO_Register.DMA1CNT_H =              [2]int{ 0x40000C6, 2 }, // Control
		IO_Register.DMA2SAD =                [2]int{ 0x40000C8, 4 }, // Source Address
		IO_Register.DMA2DAD =                [2]int{ 0x40000CC, 4 }, // Destination Address
		IO_Register.DMA2CNT_L =              [2]int{ 0x40000D0, 2 }, // Word Count
		IO_Register.DMA2CNT_H =              [2]int{ 0x40000D2, 2 }, // Control
		IO_Register.DMA3SAD =                [2]int{ 0x40000D4, 4 }, // Source Address
		IO_Register.DMA3DAD =                [2]int{ 0x40000D8, 4 }, // Destination Address
		IO_Register.DMA3CNT_L =              [2]int{ 0x40000DC, 2 }, // Word Count
		IO_Register.DMA3CNT_H =              [2]int{ 0x40000DE, 2 }, // Control
		// Timer Registers //
		IO_Register.TM0CNT_L =               [2]int{ 0x4000100, 2 }, // Timer 0 Counter/Reload
		IO_Register.TM0CNT_H =               [2]int{ 0x4000102, 2 }, // Timer 0 Control
		IO_Register.TM1CNT_L =               [2]int{ 0x4000104, 2 }, // Timer 1 Counter/Reload
		IO_Register.TM1CNT_H =               [2]int{ 0x4000106, 2 }, // Timer 1 Control
		IO_Register.TM2CNT_L =               [2]int{ 0x4000108, 2 }, // Timer 2 Counter/Reload
		IO_Register.TM2CNT_H =               [2]int{ 0x400010A, 2 }, // Timer 2 Control
		IO_Register.TM3CNT_L =               [2]int{ 0x400010C, 2 }, // Timer 3 Counter/Reload
		IO_Register.TM3CNT_H =               [2]int{ 0x400010E, 2 }, // Timer 3 Control
		// Serial Communication //
		IO_Register.SIODATA32 =              [2]int{ 0x4000120, 4 }, // SIO Data (Normal-32bit Mode; shared with below)
		IO_Register.SIOMULTI0 =              [2]int{ 0x4000120, 2 }, // SIO Data 0 (Parent)    (Multi-Player Mode)
		IO_Register.SIOMULTI1 =              [2]int{ 0x4000122, 2 }, // SIO Data 1 (1st Child) (Multi-Player Mode)
		IO_Register.SIOMULTI2 =              [2]int{ 0x4000124, 2 }, // SIO Data 2 (2nd Child) (Multi-Player Mode)
		IO_Register.SIOMULTI3 =              [2]int{ 0x4000126, 2 }, // SIO Data 3 (3rd Child) (Multi-Player Mode)
		IO_Register.SIOCNT =                 [2]int{ 0x4000128, 2 }, // SIO Control Register
		IO_Register.SIOMLT_SEND =            [2]int{ 0x400012A, 2 }, // SIO Data (Local of MultiPlayer; shared below)
		IO_Register.SIODATA8 =               [2]int{ 0x400012A, 2 }, // SIO Data (Normal-8bit and UART Mode)
		IO_Register.RCNT =                   [2]int{ 0x4000134, 2 }, // SIO Mode Select/General Purpose Data
		IO_Register.JOYCNT =                 [2]int{ 0x4000140, 2 }, // SIO JOY Bus Control
		IO_Register.JOY_RECV =               [2]int{ 0x4000150, 4 }, // SIO JOY Bus Receive Data
		IO_Register.JOY_TRANS =              [2]int{ 0x4000154, 4 }, // SIO JOY Bus Transmit Data
		IO_Register.JOYSTAT =                [2]int{ 0x4000158, 2 }, // SIO JOY Bus Receive Status
		// Keypad Input //
		IO_Register.KEYINPUT =               [2]int{ 0x4000130, 2 }, // Key Status
		IO_Register.KEYCNT =                 [2]int{ 0x4000132, 2 }, // Key Interrupt Control
		// Interrupt, Waitstate, and Power-Down Control //
		IO_Register.IE =                     [2]int{ 0x4000200, 2 }, // Interrupt Enable Register
		IO_Register.IF =                     [2]int{ 0x4000202, 2 }, // Interrupt Request Flags / IRQ Acknowledge
		IO_Register.WAITCNT =                [2]int{ 0x4000204, 2 }, // Game Pak Waitstate Control
		IO_Register.IME =                    [2]int{ 0x4000208, 2 }, // Interrupt Master Enable Register
		IO_Register.POSTFLG =                [2]int{ 0x4000300, 1 }, // Undocumented - Post Boot Flag
		IO_Register.HALTCNT =                [2]int{ 0x4000301, 1 }, // Undocumented - Power Down Control
		IO_Register.UNDOCUMENTED_0x4000800 = [2]int{ 0x4000800, 4 }, /* Undocumented - Internal Memory Control (R/W)*/ } }


// REGISTER R/W //
// io_register_read_u8:: proc(register: [2]int) -> (value: u8) {
// 	assert(register[WIDTH] == 1)
// 	return u8(memory.input_output_ram_region[register[START]]) }
// io_register_read_i8:: proc(register: [2]int) -> (value: i8) {
// 	assert(register[WIDTH] == 1)
// 	return i8(memory.input_output_ram_region[register[START]]) }
// io_register_read_u16:: proc(register: [2]int) -> (value: u16) {
// 	assert(register[WIDTH] == 2)
// 	return try(endian.get_u16(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
// io_register_read_i16:: proc(register: [2]int) -> (value: i16) {
// 	assert(register[WIDTH] == 2)
// 	return try(endian.get_i16(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
// io_register_read_f16:: proc(register: [2]int) -> (value: f16) {
// 	assert(register[WIDTH] == 2)
// 	return try(endian.get_f16(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
// io_register_read_u32:: proc(register: [2]int) -> (value: u32) {
// 	assert(register[WIDTH] == 4)
// 	return try(endian.get_u32(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
// io_register_read_i32:: proc(register: [2]int) -> (value: i32) {
// 	assert(register[WIDTH] == 4)
// 	return try(endian.get_i32(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
// io_register_read_f32:: proc(register: [2]int) -> (value: f32) {
// 	assert(register[WIDTH] == 4)
// 	return try(endian.get_f32(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
// io_register_read_bytes:: proc(register: [2]int) -> (value: []u8) {
// 	return memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1] }
// io_register_write_bytes:: proc(register: [2]int, value: []u8) {
// 	assert(register[WIDTH] == len(value))
// 	copy_slice(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], value) }


// MEMORY ACCESS //
// memory_get_ptr_u8:: proc(address: u32) -> ^u8 {
// 	bytes: = slice.reinterpret([]u8, memory.data)
// 	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
// 	byte_index: = address - word_address
// 	word: u32be = cast(u32be)transmute(u32le)(word_address)
// 	return &bytes[word_address * 4 + 3 - byte_index] }
// memory_get_ptr_u16:: proc(address: u32) -> ^u16 {
// 	assert(address & 0b_1 == 0b_0)
// 	bytes: = slice.reinterpret([]u16, memory.data)
// 	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 2)
// 	halfword_index: = address - word_address
// 	return &bytes[word_address * 4 + 3 - halfword_index] }
// memory_read:: proc(address: u32, $T: typeid) -> (value: T) {
// 	#assert((T == u8) || (T == u16) || (T == u32))
// 	when T == u16 do assert(address & 0b_1 == 0b_0)
// 	when T == u32 do assert(address & 0b_11 == 0b_00)
// 	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
// 	byte_index: = address - word_address
// 	return 0
// }
memory_read_u8:: proc(address: u32) -> (value: u8, ok: bool) #optional_ok {
	using state: ^State = cast(^State)context.user_ptr
	if ! memory_address_is_valid(address) do return 0, false
	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
	byte_index: = address - word_address
	word: u32 = transmute(u32)cast(u32be)transmute(u32le)(memory.data[word_address / 4])
	return cast(u8)((word >> (byte_index * 8)) & 0b_11111111), true }
memory_read_u16:: proc(address: u32) -> (value: u16, ok: bool) #optional_ok {
	using state: ^State = cast(^State)context.user_ptr
	if ! memory_address_is_valid(address) do return 0, false
	address: = address & (~ u32(0b_1))
	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
	byte_index: = address - word_address
	word: u32 = transmute(u32)cast(u32be)transmute(u32le)(memory.data[word_address / 4])
	return cast(u16)((word >> (byte_index * 8)) & 0b_11111111_11111111), true }
memory_read_u32:: proc(address: u32) -> (value: u32, ok: bool) #optional_ok {
	using state: ^State = cast(^State)context.user_ptr
	if ! memory_address_is_valid(address) do return 0, false
	address: = address & (~ u32(0b_11))
	word: u32 = transmute(u32)cast(u32be)transmute(u32le)(memory.data[address / 4])
	return word, true }
memory_write_u8:: proc(address: u32, value: u8) -> (ok: bool) {
	using state: ^State = cast(^State)context.user_ptr
	if ! memory_address_is_valid(address) do return false
	bytes: = slice.reinterpret([]u8, memory.data)
	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
	byte_index: = address - word_address
	bytes[word_address * 4 + 3 - byte_index] = value
	return true }
memory_write_u16:: proc(address: u32, value: u16) -> (ok: bool) {
	using state: ^State = cast(^State)context.user_ptr
	if ! memory_address_is_valid(address) do return false
	address: = address & (~ u32(0b_1))
	halfwords: = slice.reinterpret([]u16, memory.data)
	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
	halfword_index: = (address - word_address) / 2
	halfwords[word_address * 2 + 1 - halfword_index] = transmute(u16)cast(u16le)transmute(u16be)value
	return true }
memory_write_u32:: proc(address: u32, value: u32) -> (ok: bool) {
	using state: ^State = cast(^State)context.user_ptr
	if ! memory_address_is_valid(address) do return false
	address: = address & (~ u32(0b_11))
	memory.data[address / 4] = cast(u32le)transmute(u32be)value
	return true }
// bios_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.bios_region[address : address + width - 1], 1 }
// internal_work_ram_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.internal_work_ram[address : address + width - 1], 1 }
// internal_work_ram_write:: proc(address: u32, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	memory.internal_work_ram[address : address + width - 1] = value[:]
// 	return 1 }
// input_output_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.input_output_region[address : address + width - 1], 1 }
// input_output_write:: proc(address: u32, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	memory.input_output_region[address : address + width - 1] = value[:]
// 	return 1 }
// oam_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.oam_region[address : address + width - 1], 1 }
// oam_write:: proc(address: u32, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 2) || (width == 4))
// 	memory.oam_region[address : address + width - 1] = value
// 	return 1 }
// external_work_ram_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.external_work_ram_region[address : address + width - 1], (width != 4) ? 3 : 6 }
// external_work_ram_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	value = memory.external_work_ram_region[address : address + width - 1]
// 	return (width != 4) ? 3 : 6 }
// sprites_palette_ram_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.sprites_palette_ram_region[address : address + width - 1], (width != 4) ? 1 : 2 }
// sprites_palette_ram_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 2) || (width == 4))
// 	memory.sprites_palette_ram_region[address : address + width - 1] = value
// 	return (width != 4) ? 1 : 2 }
// video_ram_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.video_ram_region[address : address + width - 1], (width != 4) ? 1 : 2 }
// video_ram_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 2) || (width == 4))
// 	memory.video_ram_region[address : address + width - 1] = value
// 	return (width != 4) ? 1 : 2 }
// cartridge_game_data_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.cartridge_game_data_0_region[address : address + width - 1], (width != 4) ? 5 : 8 }
// cartridge_save_data_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
// 	#assert((width == 1) || (width == 2) || (width == 4))
// 	return memory.cartridge_save_data_region[address : address + width - 1], (width != 4) ? 5 : 8 }
// cartridge_save_data_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
// 	#assert((width == 2) || (width == 4))
// 	memory.cartridge_save_data_region[address : address + width - 1] = value
// 	return (width != 4) ? 5 : 8 }


// TRACK WIDTHS [BITS] //
SYSTEM_ROM_TRACK_WIDTH::            32
EXTERNAL_WORK_RAM_TRACK_WIDTH::     16
INTERNAL_WORK_RAM_TRACK_WIDTH::     32
INPUT_OUTPUT_RAM_TRACK_WIDTH::      64 // dual port 32
PALETTE_RAM_TRACK_WIDTH::           16
VIDEO_RAM_TRACK_WIDTH::             16
OAM_TRACK_WIDTH::                   32
CARTRIDGE_GAME_DATA_0_TRACK_WIDTH:: 16
CARTRIDGE_GAME_DATA_1_TRACK_WIDTH:: 16
CARTRIDGE_GAME_DATA_2_TRACK_WIDTH:: 16
CART_RAM_TRACK_WIDTH::              8


// WAIT STATES [CYCLES] //
SYSTEM_ROM_WAIT_STATE:: 0
CARTRIDGE_GAME_DATA_0_WAIT_STATE:: 0
CARTRIDGE_GAME_DATA_1_WAIT_STATE:: 1
CARTRIDGE_GAME_DATA_2_WAIT_STATE:: 2


// ENTRY POINTS [BYTES] //
EXTERNAL_WORK_RAM_ENTRY_POINT:: EXTERNAL_WORK_RAM_RANGE[START]
CARTRIDGE_GAME_DATA_0_ENTRY_POINT::          CARTRIDGE_GAME_DATA_0_RANGE[START]
CARTRIDGE_GAME_DATA_1_ENTRY_POINT::     0x0a000000
CARTRIDGE_GAME_DATA_2_ENTRY_POINT::     0x0c000000


Memory:: struct {
	data:                                      []u32le,
	system_rom_region:                         []u32le,
	bios_region:                               []u32le,
	external_work_ram_region:                  []u32le,
	internal_work_ram_region:                  []u32le,
	input_output_ram_region:                   []u32le,
	palette_ram_region:                        []u32le,
	background_palette_ram_region:             []u32le,
	sprites_palette_ram_region:                []u32le,
	video_ram_region:                          []u32le,
	oam_region:                                []u32le,
	cartridge_header_region:                   []u32le,
	cartridge_game_data_0_region:              []u32le,
	cartridge_game_data_1_region:              []u32le,
	cartridge_game_data_2_region:              []u32le,
	cartridge_save_data_region:                []u32le,
	io_registers: struct {
		channel_1_sweep:                       ^SOUND1CNT_L,
		channel_1_duty_length_envelope:        ^SOUND1CNT_H,
		channel_1_frequency_control:           ^SOUND1CNT_X,
		channel_2_duty_length_envelope:        ^SOUND2CNT_L,
		channel_2_frequency_control:           ^SOUND2CNT_H,
		channel_3_stop_wave_ram_select:        ^SOUND3CNT_L,
		channel_3_length_volume:               ^SOUND3CNT_H,
		channel_3_frequency_control:           ^SOUND3CNT_X,
		channel_4_length_envelope:             ^SOUND4CNT_L,
		channel_4_frequency_control:           ^SOUND4CNT_H,
		control_stereo_volume_enable:          ^SOUNDCNT_L,
		control_mixing_dma_control:            ^SOUNDCNT_H,
		control_sound_on_off:                  ^SOUNDCNT_X,
		sound_pwm_control:                     ^SOUNDBIAS,
		channel_3_wave_pattern_ram:            ^WAVE_RAM,
		channel_a_fifo:                        ^FIFO_A,
		channel_b_fifo:                        ^FIFO_B,
		dma_0_source_address:                  ^DMA0SAD,
		dma_0_destination_address:             ^DMA0DAD,
		dma_0_word_count:                      ^DMA0CNT_L,
		dma_0_control:                         ^DMA0CNT_H,
		dma_1_source_address:                  ^DMA1SAD,
		dma_1_destination_address:             ^DMA1DAD,
		dma_1_word_count:                      ^DMA1CNT_L,
		dma_1_control:                         ^DMA1CNT_H,
		dma_2_source_address:                  ^DMA2SAD,
		dma_2_destination_address:             ^DMA2DAD,
		dma_2_word_count:                      ^DMA2CNT_L,
		dma_2_control:                         ^DMA2CNT_H,
		dma_3_source_address:                  ^DMA3SAD,
		dma_3_destination_address:             ^DMA3DAD,
		dma_3_word_count:                      ^DMA3CNT_L,
		dma_3_control:                         ^DMA3CNT_H,
		timer_0_counter_reload:                ^TM0CNT_L,
		timer_0_control:                       ^TM0CNT_H,
		timer_1_counter_reload:                ^TM1CNT_L,
		timer_1_control:                       ^TM1CNT_H,
		timer_2_counter_reload:                ^TM2CNT_L,
		timer_2_control:                       ^TM2CNT_H,
		timer_3_counter_reload:                ^TM3CNT_L,
		timer_3_control:                       ^TM3CNT_H,
		sio_data_normal32:                     ^SIODATA32,
		sio_data_parent:                       ^SIOMULTI0,
		sio_data_1st_child:                    ^SIOMULTI1,
		sio_data_2nd_child:                    ^SIOMULTI2,
		sio_data_3rd_child:                    ^SIOMULTI3,
		sio_control:                           ^SIOCNT,
		sio_data_local:                        ^SIOMLT_SEND,
		sio_data_normal_normal8:               ^SIODATA8,
		key_status:                            ^KEYINPUT,
		key_interrupt_control:                 ^KEYCNT,
		sio_mode_select:                       ^RCNT,
		sio_joy_bus_control:                   ^JOYCNT,
		sio_joy_bus_receive_data:              ^JOY_RECV,
		sio_joy_bus_transmit_data:             ^JOY_TRANS,
		sio_joy_bus_receive_status:            ^JOYSTAT,
		interrupt_enable:                      ^IE,
		interrupt_request_flags:               ^IF,
		game_pak_waitstate_control:            ^WAITCNT,
		interrupt_master_enable:               ^IME,
		post_boot_flag:                        ^POSTFLG,
		power_down_control:                    ^HALTCNT,
		undocumented_0x4000800:                ^UNDOCUMENTED_0x4000800 },
	using interface: Memory_Interface }
allocate_memory:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	memory.data =                          runtime.make_aligned([]u32le, len = 0x0e00ffff/4+1, alignment = 4); assert(memory.data != nil)
	memory.system_rom_region =             make_memslice(SYSTEM_ROM_RANGE)
	memory.bios_region =                   make_memslice(BIOS_RANGE)
	memory.external_work_ram_region =      make_memslice(EXTERNAL_WORK_RAM_RANGE)
	memory.internal_work_ram_region =      make_memslice(INTERNAL_WORK_RAM_RANGE)
	memory.input_output_ram_region =       make_memslice(INPUT_OUTPUT_RAM_RANGE)
	memory.palette_ram_region =            make_memslice(PALETTE_RAM_RANGE)
	memory.background_palette_ram_region = make_memslice(BACKGROUND_PALETTE_RAM_RANGE)
	memory.sprites_palette_ram_region =    make_memslice(SPRITES_PALETTE_RAM_RANGE)
	memory.video_ram_region =              make_memslice(VIDEO_RAM_RANGE)
	memory.oam_region =                    make_memslice(OAM_RANGE)
	memory.cartridge_header_region  =      make_memslice(CARTRIDGE_HEADER)
	memory.cartridge_game_data_0_region =  make_memslice(CARTRIDGE_GAME_DATA_0_RANGE)
	memory.cartridge_game_data_1_region =  make_memslice(CARTRIDGE_GAME_DATA_1_RANGE)
	memory.cartridge_game_data_2_region =  make_memslice(CARTRIDGE_GAME_DATA_2_RANGE)
	memory.cartridge_save_data_region =    make_memslice(CARTRIDGE_SAVE_DATA_RANGE) }
initialize_memory:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	init_memory_interface()
	load_bios(`C:\Games\GBA Roms\bios.bin`)
	load_cartridge(`C:\Games\GBA Roms\Doom.gba`) }


print_memory_regions::proc() {
	using state: ^State = cast(^State)context.user_ptr
	print_memslice("data                          ", memory.data)
	print_memslice("system_rom_region             ", memory.system_rom_region)
	print_memslice("bios_region                   ", memory.bios_region)
	print_memslice("external_work_ram_region      ", memory.external_work_ram_region)
	print_memslice("internal_work_ram_region      ", memory.internal_work_ram_region)
	print_memslice("input_output_ram_region       ", memory.input_output_ram_region)
	print_memslice("palette_ram_region            ", memory.palette_ram_region)
	print_memslice("background_palette_ram_region ", memory.background_palette_ram_region)
	print_memslice("sprites_palette_ram_region    ", memory.sprites_palette_ram_region)
	print_memslice("video_ram_region              ", memory.video_ram_region)
	print_memslice("oam_region                    ", memory.oam_region)
	print_memslice("cartridge_header_region       ", memory.cartridge_header_region)
	print_memslice("cartridge_game_data_0_region  ", memory.cartridge_game_data_0_region)
	print_memslice("cartridge_game_data_1_region  ", memory.cartridge_game_data_1_region)
	print_memslice("cartridge_game_data_2_region  ", memory.cartridge_game_data_2_region)
	print_memslice("cartridge_save_data_region    ", memory.cartridge_save_data_region) }


// BYTE ORDERING //
is_aligned:: proc(x: u32, $align: int) -> bool {
	when align == 2 do return x & 0b_1 == 0b_0
	when align == 4 do return x & 0b_11 == 0b_00 }
align_byte:: proc(addr: uintptr)-> uintptr {
	return bool(0b1&addr) ? addr+1 : addr }
le_to_be:: proc(le: u32) -> u32 {
	return transmute(u32)cast(u32be)transmute(u32le)le }
be_to_le:: proc(be: u32) -> u32 {
	return transmute(u32)cast(u32le)transmute(u32be)be }


make_memslice:: proc(range: [2]u32, loc: = #caller_location)-> []u32le {
	using state: ^State = cast(^State)context.user_ptr
	assert(is_aligned(range[START], 4) && is_aligned(range[END]+1, 4), loc = loc)
	return memory.data[range[START]/4:range[END]/4+1] }
print_memslice:: proc(name: string, memslice: []u32le) {
	fmt.printfln("%s | %x - %x | %s ", name, memslice_region_start(memslice), memslice_region_end(memslice), fmt_units(len(memslice))) }
memslice_region:: proc(memslice: []u32le)-> (region: [2]uint) {
	return { memslice_region_start(memslice), memslice_region_end(memslice) } }
memslice_region_start:: proc(memslice: []u32le)-> uint {
	using state: ^State = cast(^State)context.user_ptr
	return uint(uintptr(&memslice[0]) - uintptr(&memory.data[0])) }
memslice_region_end:: proc(memslice: []u32le)-> uint {
	using state: ^State = cast(^State)context.user_ptr
	return uint(uintptr(&memslice[len(memslice)-1]) - uintptr(&memory.data[0])) }


Memory_Cycle_Type:: enum {
	IDLE,
	NONSEQUENTIAL,
	SEQUENTIAL,
	COPROCESSOR_REGISTER_TRANSFER }
Instruction_Set:: enum {
	ARM_32,
	THUMB_16 }


load_bios:: proc(filename: string)-> bool {
	using state: ^State = cast(^State)context.user_ptr
	bios_bytes, success: = os.read_entire_file_from_filename(filename)
	bios: []u32le = slice.reinterpret([]u32le, bios_bytes)
	if ! success do return false
	n: = len(bios)
	assert(n <= len(memory.bios_region) * 4)
	// fmt.println("bios loaded | ", fmt_units(n), "/", fmt_units(len(memory.bios_region)))
	copy_slice(memory.bios_region[0:n], bios[0:n])
	return true }
load_cartridge:: proc(filename: string)-> bool {
	using state: ^State = cast(^State)context.user_ptr
	cartridge_bytes, success: = os.read_entire_file_from_filename(filename)
	cartridge: []u32le = slice.reinterpret([]u32le, cartridge_bytes)
	if ! success do return false
	n: = len(cartridge)
	assert(n <= len(memory.cartridge_game_data_0_region))
	// fmt.println("cartridge loaded | ", fmt_units(n), "/", fmt_units(len(memory.cartridge_game_data_0_region)))
	copy_slice(memory.cartridge_game_data_0_region[0:n], cartridge[0:n])
	copy_slice(memory.cartridge_game_data_1_region[0:n], cartridge[0:n])
	copy_slice(memory.cartridge_game_data_2_region[0:n], cartridge[0:n])
	return true }


// SEQUENCES //
memory_respond_memory_sequence:: proc(sequential_cycle: bool = LOW, read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD) {
	using state: ^State = cast(^State)context.user_ptr
	assert(phase_index == 0, "Sequence may only be initiated in phase 1")
	access_latency: = memory_bus_latency_from_address(address = address, width = 4/*memory.memory_access_size.output*/)
	read_write: = memory.read_write.output
	if access_latency == 1 do signal_force(&gba_core.wait, LOW)
	else {
		signal_force(&gba_core.wait, HIGH)
		// log.info("wait scheduled to go low after", (access_latency - 1) * 2 + 1)
		signal_put(&gba_core.wait, LOW, latency_override = (access_latency - 1) * 2) }
	switch read_write {
	case .READ:
		data_in, ok: = memory_read_u32(address)
		if ok do signal_put(&gba_core.data_in, data_in, latency_override = (access_latency - 1) * 2 + 1)
		else do signal_put(&gba_core.abort, HIGH, latency_override = (access_latency - 1) * 2 + 1)
	case .WRITE:
		ok: = memory_write_u32(address = address, value = data_out)
		if ! ok do signal_put(&gba_core.abort, HIGH, latency_override = (access_latency - 1) * 2 + 1) } }
memory_respond_n_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD) {
	memory_respond_memory_sequence(false, read_write, address, data_out, memory_access_size) }
memory_respond_s_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD) {
	memory_respond_memory_sequence(true, read_write, address, data_out, memory_access_size) }
memory_respond_merged_is_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD) {
	memory_respond_memory_sequence(true, read_write, address, data_out, memory_access_size) }
memory_respond_data_write_cycle:: proc() { }
memory_respond_data_read_cycle:: proc() { }
memory_respond_halfword_memory_sequence:: proc() { }
memory_respond_byte_memory_sequence:: proc() { }






memory_respond_reset_sequence:: proc() { }
memory_respond_branch_and_branch_with_link_instruction_cycle:: proc(instruction: GBA_Branch_and_Link_Instruction_Decoded) { }
memory_respond_thumb_branch_with_link_instruction_cycle:: proc() { }
memory_respond_branch_and_exchange_instruction_cycle:: proc(instruction: GBA_Branch_and_Exchange_Instruction_Decoded) { }
memory_respond_data_processing_instruction_cycle:: proc(alu: u32, destination_is_pc: bool, shift_specified_by_register: bool, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Data Write Sequence response may only be initiated in the LOW phase.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	switch {
	// normal //
	case (! shift_specified_by_register) && (! destination_is_pc):
		signal_put(&gba_core.data_in, memory_read_u32(pc + 2 * L), latency_override = 1)
	// dest=pc //
	case (! shift_specified_by_register) && destination_is_pc:
	// shift(RS) //
	case shift_specified_by_register && (! destination_is_pc):
	// shift(RS) dest=pc //
	case shift_specified_by_register && destination_is_pc:
	case:
	}
}
memory_respond_multiply_and_multiply_accumulate_instruction_cycle:: proc(instruction: GBA_Multiply_and_Multiply_Accumulate_Instruction_Decoded) { }
memory_respond_load_register_instruction_cycle:: proc(instruction: GBA_Load_Register_Instruction_Decoded) { }
memory_respond_store_register_instruction_cycle:: proc(instruction: GBA_Store_Register_Instruction_Decoded) { }
memory_respond_load_multiple_register_instruction_cycle:: proc(instruction: GBA_Load_Multiple_Register_Instruction_Decoded) { }
memory_respond_store_multiple_register_instruction_cycle:: proc(instruction: GBA_Store_Multiple_Register_Instruction_Decoded) { }
memory_respond_data_swap_instruction_cycle:: proc(instruction: GBA_Data_Swap_Instruction_Decoded) { }
memory_respond_software_interrupt_and_exception_instruction_cycle:: proc(instruction: GBA_Software_Interrupt_Instruction_Decoded) { }
memory_respond_undefined_instruction_cycle:: proc() { }
memory_respond_unexecuted_instruction_cycle:: proc() { }