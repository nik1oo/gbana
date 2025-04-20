package gbana
import "core:fmt"
import "core:os"
import "core:encoding/endian"
import "core:mem"


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
SYSTEM_ROM_RANGE::             [2]int{ 0x00000000, 0x00003fff }
BIOS_RANGE::                   [2]int{ 0x00000000, 0x00003fff } // boot rom
EXTERNAL_WORK_RAM_RANGE::      [2]int{ 0x02000000, 0x0203ffff } // this is the slow RAM
INTERNAL_WORK_RAM_RANGE::      [2]int{ 0x03000000, 0x03007fff } // this is the fast RAM
INPUT_OUTPUT_RAM_RANGE::       [2]int{ 0x04000000, 0x040003fe }
PALETTE_RAM_RANGE::            [2]int{ 0x05000000, 0x050003ff } // is this where sprites are stored?
BACKGROUND_PALETTE_RAM_RANGE:: [2]int{ 0x05000000, 0x050003ff }
SPRITES_PALETTE_RAM_RANGE::    [2]int{ 0x05002000, 0x050023ff }
VIDEO_RAM_RANGE::              [2]int{ 0x06000000, 0x06017fff } // mainly for storing the framebuffer
OAM_RANGE::                    [2]int{ 0x07000000, 0x070003ff } // object attribute memory, for sprites control
CARTRIDGE_HEADER::             [2]int{ 0x08000000, 0x080000BF } // 192-byte cartridge header
CARTRIDGE_GAME_DATA_0_RANGE::  [2]int{ 0x08000000, 0x09ffffff } // this is the game cartridge ROM
CARTRIDGE_GAME_DATA_1_RANGE::  [2]int{ 0x0a000000, 0x0bffffff } // this is a mirror of game ROM
CARTRIDGE_GAME_DATA_2_RANGE::  [2]int{ 0x0c000000, 0x0dffffff } // this is a mirror of game ROM
CARTRIDGE_SAVE_DATA_RANGE::    [2]int{ 0x0e000000, 0x0e00ffff } // SRAM or flash ROM, used for game save data


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
io_register_read_u8:: proc(register: [2]int) -> (value: u8) {
	assert(register[WIDTH] == 1)
	return u8(memory.input_output_ram_region[register[START]]) }
io_register_read_i8:: proc(register: [2]int) -> (value: i8) {
	assert(register[WIDTH] == 1)
	return i8(memory.input_output_ram_region[register[START]]) }
io_register_read_u16:: proc(register: [2]int) -> (value: u16) {
	assert(register[WIDTH] == 2)
	return try(endian.get_u16(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
io_register_read_i16:: proc(register: [2]int) -> (value: i16) {
	assert(register[WIDTH] == 2)
	return try(endian.get_i16(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
io_register_read_f16:: proc(register: [2]int) -> (value: f16) {
	assert(register[WIDTH] == 2)
	return try(endian.get_f16(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
io_register_read_u32:: proc(register: [2]int) -> (value: u32) {
	assert(register[WIDTH] == 4)
	return try(endian.get_u32(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
io_register_read_i32:: proc(register: [2]int) -> (value: i32) {
	assert(register[WIDTH] == 4)
	return try(endian.get_i32(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
io_register_read_f32:: proc(register: [2]int) -> (value: f32) {
	assert(register[WIDTH] == 4)
	return try(endian.get_f32(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], endian.Byte_Order.Little)) }
io_register_read_bytes:: proc(register: [2]int) -> (value: []u8) {
	return memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1] }
io_register_write_bytes:: proc(register: [2]int, value: []u8) {
	assert(register[WIDTH] == len(value))
	copy_slice(memory.input_output_ram_region[register[START] : register[START] + register[WIDTH] - 1], value) }


// MEMORY R/W //
memory_read:: proc(address: u32, $T: typeid) -> (value: T) {
	#assert((T == u8) || (T == u16) || (T == u32))
	when T == u16 do assert(address & 0b_1 == 0b_0)
	when T == u32 do assert(address & 0b_11 == 0b_00)
	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
	byte_index: = address - word_address
	return 0
}
memory_read_u8:: proc(address: u32) -> (value: u8) {
	word_address: u32 = cast(u32)mem.align_backward_uint(uint(address), 4)
	byte_index: = address - word_address
	word: = u32le(memory.data[word_address])
	// DICK
	return 0
}
bios_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.bios_region[address : address + width - 1], 1 }
internal_work_ram_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.internal_work_ram[address : address + width - 1], 1 }
internal_work_ram_write:: proc(address: u32, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	memory.internal_work_ram[address : address + width - 1] = value[:]
	return 1 }
input_output_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.input_output_region[address : address + width - 1], 1 }
input_output_write:: proc(address: u32, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	memory.input_output_region[address : address + width - 1] = value[:]
	return 1 }
oam_read:: proc(address: u32, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.oam_region[address : address + width - 1], 1 }
oam_write:: proc(address: u32, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 2) || (width == 4))
	memory.oam_region[address : address + width - 1] = value
	return 1 }
external_work_ram_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.external_work_ram_region[address : address + width - 1], (width != 4) ? 3 : 6 }
external_work_ram_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	value = memory.external_work_ram_region[address : address + width - 1]
	return (width != 4) ? 3 : 6 }
sprites_palette_ram_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.sprites_palette_ram_region[address : address + width - 1], (width != 4) ? 1 : 2 }
sprites_palette_ram_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 2) || (width == 4))
	memory.sprites_palette_ram_region[address : address + width - 1] = value
	return (width != 4) ? 1 : 2 }
video_ram_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.video_ram_region[address : address + width - 1], (width != 4) ? 1 : 2 }
video_ram_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 2) || (width == 4))
	memory.video_ram_region[address : address + width - 1] = value
	return (width != 4) ? 1 : 2 }
cartridge_game_data_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.cartridge_game_data_0_region[address : address + width - 1], (width != 4) ? 5 : 8 }
cartridge_save_data_read:: proc(address: u16, $width: int) -> (value: [width]u8, cycles: int) {
	#assert((width == 1) || (width == 2) || (width == 4))
	return memory.cartridge_save_data_region[address : address + width - 1], (width != 4) ? 5 : 8 }
cartridge_save_data_write:: proc(address: u16, $width: int, value: [width]u8) -> (cycles: int) {
	#assert((width == 2) || (width == 4))
	memory.cartridge_save_data_region[address : address + width - 1] = value
	return (width != 4) ? 5 : 8 }


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
	data:                                      []u8,
	system_rom_region:                         []u8,
	bios_region:                               []u8,
	external_work_ram_region:                  []u8,
	internal_work_ram_region:                  []u8,
	input_output_ram_region:                   []u8,
	palette_ram_region:                        []u8,
	background_palette_ram_region:             []u8,
	sprites_palette_ram_region:                []u8,
	video_ram_region:                          []u8,
	oam_region:                                []u8,
	cartridge_header_region:                   []u8,
	cartridge_game_data_0_region:              []u8,
	cartridge_game_data_1_region:              []u8,
	cartridge_game_data_2_region:              []u8,
	cartridge_save_data_region:                []u8,
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
		undocumented_0x4000800:                ^UNDOCUMENTED_0x4000800 } }
memory: ^Memory


init_memory:: proc() {
	memory= new(Memory)
	memory.data= make([]u8, 0x0e00ffff+1); assert(memory.data != nil)
	memory.system_rom_region=             make_memslice(SYSTEM_ROM_RANGE)
	memory.bios_region=                   make_memslice(BIOS_RANGE)
	memory.external_work_ram_region=      make_memslice(EXTERNAL_WORK_RAM_RANGE)
	memory.internal_work_ram_region=      make_memslice(INTERNAL_WORK_RAM_RANGE)
	memory.input_output_ram_region=       make_memslice(INPUT_OUTPUT_RAM_RANGE)
	memory.palette_ram_region=            make_memslice(PALETTE_RAM_RANGE)
	memory.background_palette_ram_region= make_memslice(BACKGROUND_PALETTE_RAM_RANGE)
	memory.sprites_palette_ram_region=    make_memslice(SPRITES_PALETTE_RAM_RANGE)
	memory.video_ram_region=              make_memslice(VIDEO_RAM_RANGE)
	memory.oam_region=                    make_memslice(OAM_RANGE)
	memory.cartridge_header_region =      make_memslice(CARTRIDGE_HEADER)
	memory.cartridge_game_data_0_region=  make_memslice(CARTRIDGE_GAME_DATA_0_RANGE)
	memory.cartridge_game_data_1_region=  make_memslice(CARTRIDGE_GAME_DATA_1_RANGE)
	memory.cartridge_game_data_2_region=  make_memslice(CARTRIDGE_GAME_DATA_2_RANGE)
	memory.cartridge_save_data_region=    make_memslice(CARTRIDGE_SAVE_DATA_RANGE)
	load_bios(`C:\Games\GBA Roms\bios.bin`)
	load_cartridge(`C:\Games\GBA Roms\Doom.gba`) }


print_memory_regions::proc() {
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


make_memslice:: proc(range: [2]int)-> []u8 {
	return memory.data[range[START]:range[END]+1] }
print_memslice:: proc(name: string, memslice: []u8) {
	fmt.printfln("%s | %x - %x | %s ", name, memslice_region_start(memslice), memslice_region_end(memslice), fmt_units(len(memslice))) }
memslice_region:: proc(memslice: []u8)-> (region: [2]uint) {
	return { memslice_region_start(memslice), memslice_region_end(memslice) } }
memslice_region_start:: proc(memslice: []u8)-> uint {
	return uint(uintptr(&memslice[0]) - uintptr(&memory.data[0])) }
memslice_region_end:: proc(memslice: []u8)-> uint {
	return uint(uintptr(&memslice[len(memslice)-1]) - uintptr(&memory.data[0])) }


align_byte:: proc(addr: uintptr)-> uintptr {
	return bool(0b1&addr) ? addr+1 : addr }


Memory_Cycle_Type:: enum {
	IDLE,
	NONSEQUENTIAL,
	SEQUENTIAL,
	COPROCESSOR_REGISTER_TRANSFER }
Instruction_Set:: enum {
	ARM_32,
	THUMB_16 }


load_bios:: proc(filename: string)-> bool {
	bios, success: = os.read_entire_file_from_filename(filename)
	if ! success do return false
	n: = len(bios)
	assert(n <= len(memory.bios_region))
	fmt.println("bios loaded | ", fmt_units(n), "/", fmt_units(len(memory.bios_region)))
	copy_slice(memory.bios_region[0:n], bios[0:n])
	return true }
load_cartridge:: proc(filename: string)-> bool {
	cartridge, success: = os.read_entire_file_from_filename(filename)
	if ! success do return false
	n: = len(cartridge)
	assert(n <= len(memory.cartridge_game_data_0_region))
	fmt.println("cartridge loaded | ", fmt_units(n), "/", fmt_units(len(memory.cartridge_game_data_0_region)))
	copy_slice(memory.cartridge_game_data_0_region[0:n], cartridge[0:n])
	copy_slice(memory.cartridge_game_data_1_region[0:n], cartridge[0:n])
	copy_slice(memory.cartridge_game_data_2_region[0:n], cartridge[0:n])
	return true }