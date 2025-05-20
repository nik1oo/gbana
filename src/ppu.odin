package gbana
import "core:slice"
import "core:thread"
import "core:sync"


REG_DISPCNT_ADDR::  0x04000000
REG_DISPSTAT_ADDR:: 0x04000004
REG_VCOUNT_ADDR::   0x04000006
REG_BG0CNT_ADDR::   0x04000008
REG_BG1CNT_ADDR::   0x0400000a
REG_BG2CNT_ADDR::   0x0400000c
REG_BG3CNT_ADDR::   0x0400000e
REG_BG0HOFS_ADDR::  0x04000010
REG_BG0VOFS_ADDR::  0x04000012
REG_BG1HOFS_ADDR::  0x04000014
REG_BG1VOFS_ADDR::  0x04000016
REG_BG2HOFS_ADDR::  0x04000018
REG_BG2VOFS_ADDR::  0x0400001a
REG_BG3HOFS_ADDR::  0x0400001c
REG_BG3VOFS_ADDR::  0x0400001e
REG_BG2PA_ADDR::    0x04000020
REG_BG3PA_ADDR::    0x04000030
REG_BG2PB_ADDR::    0x04000022
REG_BG3PB_ADDR::    0x04000032
REG_BG2PC_ADDR::    0x04000024
REG_BG3PC_ADDR::    0x04000034
REG_BG2PD_ADDR::    0x04000026
REG_BG3PD_ADDR::    0x04000036
REG_BG2X_ADDR::     0x04000028
REG_BG3X_ADDR::     0x04000038
REG_BG2Y_ADDR::     0x0400002c
REG_BG3Y_ADDR::     0x0400003c
REG_WIN0H_ADDR::    0x04000040
REG_WIN1H_ADDR::    0x04000042
REG_WIN0V_ADDR::    0x04000044
REG_WIN1V_ADDR::    0x04000046
REG_WININ_ADDR::    0x04000048
REG_WINOUT_ADDR::   0x0400004a
REG_MOSAIC_ADDR::   0x0400004c
REG_BLDCNT_ADDR::   0x04000050
VIDEO_MODE_3_BITMAP_START:: 0x06000000; VIDEO_MODE_3_BITMAP_END:: 0x06012bff
VIDEO_MODE_3_BITMAP_SIZE:: VIDEO_MODE_3_BITMAP_END-VIDEO_MODE_3_BITMAP_START+1
#assert(VIDEO_MODE_3_BITMAP_SIZE==0x12c00)
VIDEO_MODE_4_BITMAP_FRONT_START:: 0x06000000; VIDEO_MODE_4_BITMAP_FRONT_END:: 0x060095ff
VIDEO_MODE_4_BITMAP_FRONT_SIZE:: VIDEO_MODE_4_BITMAP_FRONT_END-VIDEO_MODE_4_BITMAP_FRONT_START+1
#assert(VIDEO_MODE_4_BITMAP_FRONT_SIZE==0x9600)
VIDEO_MODE_4_BITMAP_BACK_START:: 0x0600a000; VIDEO_MODE_4_BITMAP_BACK_END:: 0x060135ff
VIDEO_MODE_4_BITMAP_BACK_SIZE:: VIDEO_MODE_4_BITMAP_BACK_END-VIDEO_MODE_4_BITMAP_BACK_START+1
#assert(VIDEO_MODE_4_BITMAP_BACK_SIZE==0x9600)
VIDEO_MODE_5_BITMAP_FRONT_START:: 0x06000000; VIDEO_MODE_5_BITMAP_FRONT_END:: 0x06009fff
VIDEO_MODE_5_BITMAP_FRONT_SIZE:: VIDEO_MODE_5_BITMAP_FRONT_END-VIDEO_MODE_5_BITMAP_FRONT_START+1
#assert(VIDEO_MODE_5_BITMAP_FRONT_SIZE==0xa000)
VIDEO_MODE_5_BITMAP_BACK_START:: 0x0600a000; VIDEO_MODE_5_BITMAP_BACK_END:: 0x06013fff
VIDEO_MODE_5_BITMAP_BACK_SIZE:: VIDEO_MODE_5_BITMAP_BACK_END-VIDEO_MODE_5_BITMAP_BACK_START+1
#assert(VIDEO_MODE_5_BITMAP_BACK_SIZE==0xa000)
Color:: bit_field u16 {
	red:   u8 | 5,
	green: u8 | 5,
	blue:  u8 | 5 }
PPU:: struct {
	mutex:           sync.Recursive_Mutex,
	using registers: PPU_Registers }
PPU_Registers:: struct {
	dispcnt:  ^DISPCNT_Register,   // display control register
	dispstat: ^DISPSTAT_Register,  // display status register
	vcount:   ^i16,
	bg0cnt:   ^BGCNT_Register,
	bg1cnt:   ^BGCNT_Register,
	bg2cnt:   ^BGCNT_Register,
	bg3cnt:   ^BGCNT_Register,
	bg0hofs:  ^BGOFS_Register,
	bg0vofs:  ^BGOFS_Register,
	bg1hofs:  ^BGOFS_Register,
	bg1vofs:  ^BGOFS_Register,
	bg2hofs:  ^BGOFS_Register,
	bg2vofs:  ^BGOFS_Register,
	bg3hofs:  ^BGOFS_Register,
	bg3vofs:  ^BGOFS_Register,
	bg2pa:    ^BGORS_Register,
	bg3pa:    ^BGORS_Register,
	bg2pb:    ^BGORS_Register,
	bg3pb:    ^BGORS_Register,
	bg2pc:    ^BGORS_Register,
	bg3pc:    ^BGORS_Register,
	bg2pd:    ^BGORS_Register,
	bg3pd:    ^BGORS_Register,
	bg2x:     ^BGXY_Register,
	bg3x:     ^BGXY_Register,
	bg2y:     ^BGXY_Register,
	bg3y:     ^BGXY_Register,
	win0h:    ^WINH_Register,
	win1h:    ^WINH_Register,
	win0v:    ^WINV_Register,
	win1v:    ^WINV_Register,
	winin:    ^WININ_Register,
	winout:   ^WINOUT_Register,
	mosaic:   ^MOSAIC_Register,
	bldcnt:   ^BLDCNT_Register }
initialize_ppu:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&ppu.mutex); defer sync.recursive_mutex_unlock(&ppu.mutex)
	ppu.dispcnt =  (^DISPCNT_Register) (&slice.reinterpret([]u8, memory.data)[REG_DISPCNT_ADDR])
	ppu.dispstat = (^DISPSTAT_Register)(&slice.reinterpret([]u8, memory.data)[REG_DISPSTAT_ADDR])
	ppu.vcount =   (^i16)              (&slice.reinterpret([]u8, memory.data)[REG_VCOUNT_ADDR])
	ppu.bg0cnt =   (^BGCNT_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG0CNT_ADDR])
	ppu.bg1cnt =   (^BGCNT_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG1CNT_ADDR])
	ppu.bg2cnt =   (^BGCNT_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2CNT_ADDR])
	ppu.bg3cnt =   (^BGCNT_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3CNT_ADDR])
	ppu.bg0hofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG0HOFS_ADDR])
	ppu.bg0vofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG0VOFS_ADDR])
	ppu.bg1hofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG1HOFS_ADDR])
	ppu.bg1vofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG1VOFS_ADDR])
	ppu.bg2hofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2HOFS_ADDR])
	ppu.bg2vofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2VOFS_ADDR])
	ppu.bg3hofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3HOFS_ADDR])
	ppu.bg3vofs =  (^BGOFS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3VOFS_ADDR])
	ppu.bg2pa =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2PA_ADDR])
	ppu.bg3pa =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3PA_ADDR])
	ppu.bg2pb =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2PB_ADDR])
	ppu.bg3pb =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3PB_ADDR])
	ppu.bg2pc =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2PC_ADDR])
	ppu.bg3pc =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3PC_ADDR])
	ppu.bg2pd =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG2PD_ADDR])
	ppu.bg3pd =    (^BGORS_Register)   (&slice.reinterpret([]u8, memory.data)[REG_BG3PD_ADDR])
	ppu.bg2x =     (^BGXY_Register)    (&slice.reinterpret([]u8, memory.data)[REG_BG2X_ADDR])
	ppu.bg3x =     (^BGXY_Register)    (&slice.reinterpret([]u8, memory.data)[REG_BG3X_ADDR])
	ppu.bg2y =     (^BGXY_Register)    (&slice.reinterpret([]u8, memory.data)[REG_BG2Y_ADDR])
	ppu.bg3y =     (^BGXY_Register)    (&slice.reinterpret([]u8, memory.data)[REG_BG3Y_ADDR])
	ppu.win0h =    (^WINH_Register)    (&slice.reinterpret([]u8, memory.data)[REG_WIN0H_ADDR])
	ppu.win1h =    (^WINH_Register)    (&slice.reinterpret([]u8, memory.data)[REG_WIN1H_ADDR])
	ppu.win0v =    (^WINV_Register)    (&slice.reinterpret([]u8, memory.data)[REG_WIN0V_ADDR])
	ppu.win1v =    (^WINV_Register)    (&slice.reinterpret([]u8, memory.data)[REG_WIN1V_ADDR])
	ppu.winin =    (^WININ_Register)   (&slice.reinterpret([]u8, memory.data)[REG_WININ_ADDR])
	ppu.winout =   (^WINOUT_Register)  (&slice.reinterpret([]u8, memory.data)[REG_WINOUT_ADDR])
	ppu.mosaic =   (^MOSAIC_Register)  (&slice.reinterpret([]u8, memory.data)[REG_MOSAIC_ADDR])
	ppu.bldcnt =   (^BLDCNT_Register)  (&slice.reinterpret([]u8, memory.data)[REG_BLDCNT_ADDR])
}
DISPCNT_Register:: bit_field i16 { // display control register.
	video_mode:         Video_Mode | 3,
	gameboy_color_mode: bool       | 1,
	bit4:               bool       | 1,
	force_processing:   bool       | 1,
	sprite_dimension:   int        | 1,
	blank_display:      bool       | 1,
	enable_bg0:         bool       | 1,
	enable_bg1:         bool       | 1,
	enable_bg2:         bool       | 1,
	enable_bg3:         bool       | 1,
	enable_sprites:     bool       | 1,
	enable_win_0:       bool       | 1,
	enable_win_1:       bool       | 1,
	enable_win_obj:     bool       | 1 } // the objects window is the sprites window, right?
DISPSTAT_Register:: bit_field i16 { // display status register.
	v_refresh_status:        int  | 1, // 0 during vdraw, 1 during vblank
	h_refresh_status:        int  | 1, // 0 during hdraw, 1 during hblank
	vcount_triggered_status: int  | 1,
	lcd_vblank_irq:          bool | 1,
	lcd_hblank_irq:          bool | 1,
	vcount_trigger_irq:      bool | 1,
	bit6:                    int  | 1,
	bit7:                    int  | 1,
	vcount_line_trigger:     int  | 8 }
BGCNT_Register:: bit_field i16 { // background control register.
	priority:           int                | 2,
	tile_data_index:    int                | 2, // NOTE addr= 0x06000000 + tile_data_index * 0x4000
	bit4:               int                | 1,
	bit5:               int                | 1,
	mosaic_effect:      bool               | 1,
	color_palette_type: Color_Palette_Type | 1,
	tile_map_index:     int                | 5, // NOTE addr= 0x06000000 + tile_map_index * 0x800
	screen_over:        bool               | 1, // sth about out-of-bounds regions of rotated BGs.
	tilemap_size_index: int                | 2 }// NOTE size= *_TILEMAP_SIZES[tilemap_size_index]
BGOFS_Register:: bit_field i16 {
	scroll_value: int | 10 }
BGORS_Register:: bit_field i16 {
	fraction: int  | 8,
	integer:  int  | 7,
	sign:     bool | 1 }
BGXY_Register:: bit_field i32 { // background (inverse) origin register.
	fraction: int  | 8,
	integer:  int  | 19,
	sign:     bool | 1,
	bit28:    int  | 1,
	bit29:    int  | 1,
	bit30:    int  | 1,
	bit31:    int  | 1 }
WINH_Register:: bit_field i16 { // window horizontal bounds.
	right: int | 8,
	left:  int | 8 }
WINV_Register:: bit_field i16 { // window vertical bounds.
	bottom: int | 8,
	top:    int | 8 }
WININ_Register:: bit_field i16 {
	bg0_in_win_0:     bool | 1,
	bg1_in_win_0:     bool | 1,
	bg2_in_win_0:     bool | 1,
	bg3_in_win_0:     bool | 1,
	sprites_in_win_0: bool | 1,
	blends_in_win_0:  bool | 1,
	bit6:             int | 1,
	bit7:             int | 1,
	bg0_in_win_1:     bool | 1,
	bg1_in_win_1:     bool | 1,
	bg2_in_win_1:     bool | 1,
	bg3_in_win_1:     bool | 1,
	sprites_in_win_1: bool | 1,
	blends_in_win_1:  bool | 1,
	bit14:            int | 1,
	bit15:            int | 1 }
WINOUT_Register:: bit_field i16 {
	bg0_in_win_out:     bool | 1,
	bg1_in_win_out:     bool | 1,
	bg2_in_win_out:     bool | 1,
	bg3_in_win_out:     bool | 1,
	sprites_in_win_out: bool | 1,
	blends_in_win_out:  bool | 1,
	bit6:               int  | 1,
	bit7:               int  | 1,
	bg0_in_win_obj:     bool | 1,
	bg1_in_win_obj:     bool | 1,
	bg2_in_win_obj:     bool | 1,
	bg3_in_win_obj:     bool | 1,
	sprites_in_win_obj: bool | 1,
	blends_in_win_obj:  bool | 1,
	bit14:              int  | 1,
	bit15:              int  | 1 }
MOSAIC_Register:: bit_field i16 { // mosaic effect
	bg_size_x:     int | 4,
	bg_size_y:     int | 4,
	sprite_size_x: int | 4,
	sprite_size_y: int | 4 }
BLDCNT_Register:: bit_field i16 { // blend control (only works if the top layer has higher priority)
	blend_bg0_source:      bool       | 1, // bg0 is the top layer
	blend_bg1_source:      bool       | 1, // bg1 is the top layer
	blend_bg2_source:      bool       | 1, // bg2 is the top layer
	blend_bg3_source:      bool       | 1, // bg3 is the top layer
	blend_sprites_source:  bool       | 1, // sprites layer is the top layer
	blend_backdrop_source: bool       | 1, // backdrop layer is the top layer
	blend_mode:            Blend_Mode | 2,
	blend_bg0_target:      bool       | 1, // bg0 is the bottom layer
	blend_bg1_target:      bool       | 1, // bg1 is the bottom layer
	blend_bg2_target:      bool       | 1, // bg2 is the bottom layer
	blend_bg3_target:      bool       | 1, // bg3 is the bottom layer
	blend_sprites_target:  bool       | 1, // sprites layer is the bottom layer
	blend_backdrop_target: bool       | 1 }// backdrop layer is the bottom layer
Blend_Mode:: enum {
	OFF= 0b00,
	ALPHA_BLEND= 0b01,
	LIGHTEN= 0b10,     // blend w/ white
	DARKEN= 0b11 }     // blend w/ black
TEXT_TILEMAP_SIZES:[4][2]int: {
	{256,256},
	{512,256},
	{256,512},
	{512,512} }
SCALE_ROTATE_BG_TILEMAP_SIZES:[4][2]int: {
	{128,  128},
	{256,  256},
	{512,  512},
	{1024,1024} }
Color_Palette_Type:: enum {
	STD_256,    // 1 palette of 256 colors
	ALT_16X16 } // 16 palettes of 16 colors
Rendering_Order:: enum {
	BACKDROP,
	BG_PRIORITY_3,
	SPRITE_PRIORITY_3,
	BG_PRIORITY_2,
	SPRITE_PRIORITY_2,
	BG_PRIORITY_1,
	SPRITE_PRIORITY_1,
	BG_PRIORITY_0,
	SPRITE_PRIORITY_0 }
Video_Mode:: enum {
	VIDEO_MODE_0, // 4 text backgrounds, cannot be scaled or rotated.
	VIDEO_MODE_1, // 2 text backgrounds, 1 scale/rotate background.
	VIDEO_MODE_2, // 2 scale/rotate backgrounds
	VIDEO_MODE_3, // 1 16-bit non-paletted bitmapped background
	VIDEO_MODE_4, // 1 8-bit paletted bitmapped background
	VIDEO_MODE_5  /* low-res 16-bit non-paletted bitmapped background */ }
Background_Type:: enum {
	TEXT,         // 8x8 bitmap font sheets for display in text mode. palette-indexed color values.
	SCALE_ROTATE, // sprites stored in tilesheets that may be scaled or rotated, 128 to 1024 res.
	BITMAP,       /* bitmap sprites. */ }
Text_Tile:: bit_field u16 {
	tile_number:       int  | 10,
	flip_horizontally: bool | 1,
	flip_vertically:   bool | 1,
	palette_number:    int  | 4 }
Scale_Rotate_Tile:: bit_field u8 {
	tile_number: int | 8 }
// Scene = 4 background layers + sprites
// Each background has a tilemap.
@(private="file") query_text_tile:: proc(background_tilemap: []Text_Tile, background_type: Background_Type, background_size: [2]int, tilemap_size: [2]int, x, y: int)-> Text_Tile {
	switch {
	case (background_size=={256,256}) || (background_size=={256,512}):
		return background_tilemap[(y*32) + x]
	case (background_type==.TEXT):
		return background_tilemap[(y*32) + (x-32) + 32*32]
	case (tilemap_size.y >= 33): // mode 11 (wtf is mode 11?)
		return background_tilemap[((y-32)*32) + x + 2*32*32]
	case (tilemap_size.y >= 33) && (tilemap_size.x >= 33):
		return background_tilemap[((y-32)*32) + (x-32) + 3*32*32]
	case: return {} } }
MAX_SPRITE_COUNT:: 128
MAX_SPRITE_SIZE:[2]int: {64, 64}
MAX_SCALE_ROTATE_ATTRIBUTES:: 32
// How big is one pixel? 32 bits?
Sprite:: struct {
	using attribute_0: Sprite_Attribute_0,
	using attribute_1: Sprite_Attribute_1,
	using attribute_2: Sprite_Attribute_2,
}
// sprite origin position :
//  - upper-left corner for regular sprites
//  - center for scale/rotate sprites
Sprite_Attribute_0:: bit_field u16 {
	origin_y:       int   | 8, // y-coordinate of the origin point
	scale_rotate:   bool  | 1,
	padding:        bool  | 1, // double sprite bounds (16x16->32x32) to avoid clipping on rot/scale.
	type: enum{
		NORMAL= 0b00,
		SEMI_TRANSPARENT= 0b01,
		OBJ_WINDOW= 0b10,
		ILLEGAL= 0b11 } | 2,
	mosaic:         bool  | 1,
	color_256:      bool  | 1,
	shape_hi:       i8    | 2 }
Sprite_Attribute_1:: bit_field u16 {
	origin_x:       int   | 8, // x-coordinate of the origin point
	flip_h:         bool  | 1,
	flip_v:         bool  | 1,
	rotate_index:   uint  | 5, // rotation data is stored separately.
	shape_lo:       i8    | 1 }
Sprite_Attribute_2:: bit_field u16 {
	tile_number:    uint  | 10, // index into the tile data area, points to start of bitmap.
	priority:       uint  | 2,  // priority for determining rendering order.
	palette_number: uint  | 4, /* palette index */ }
Sprite_Attribute_3:: bit_field u16 { // < float representing a rotation/scaling parameter.
	fraction:       int   | 8,       // origin for sprites is center. origin for backgrounds is
	integer:        int   | 7,       // upper-left corner.
	sign:           bool  | 1 }
Scale_Rotate_Attribute_Index:: enum {
	SPRITE_0_DX=  0, // scale on X-axis by 1/value.
	SPRITE_1_DMX= 0, // vertical shear.
	SPRITE_2_DY=  0, // horizontal shear.
	SPRITE_3_DMY= 0 }// scale on Y-axis by 1/value.
Window_Index:: enum {
	WIN_0= 0,    // rendered above WIN_1.
	WIN_1= 1,    // rendered above WIN_OBJ.
	WIN_OBJ= 2,  // rendered above WIN_OUT.
	WIN_OUT= 3 } // rendered bellow everything else.
@(private="file") decode_sprite_shape:: proc(shape_lo: i8, shape_hi: i8)-> (shape: [2]int) {
	switch (shape_hi<<2)|shape_lo {
	case 0b0000: return { 8, 8}
	case 0b0001: return {16,16}
	case 0b0010: return {32,32}
	case 0b0011: return {64,64}
	case 0b0100: return {16, 8}
	case 0b0101: return {32, 8}
	case 0b0110: return {32,16}
	case 0b0111: return {64,32}
	case 0b1000: return { 8,16}
	case 0b1001: return { 8,32}
	case 0b1010: return {16,32}
	case 0b1011: return {32,64}
	case 0b1100: return {-1,-1}
	case 0b1101: return {-1,-1}
	case 0b1110: return {-1,-1}
	case 0b1111: return {-1,-1}
	case:        return {-1,-1} } }
SPRITE_SHAPES:[12][2]int: {
	{ 8, 8},
	{16,16},
	{32,32},
	{64,64},
	{16, 8},
	{32, 8},
	{32,16},
	{64,32},
	{ 8,16},
	{ 8,32},
	{16,32},
	{32,64} }
@(private="file") tilemap_1d:: proc(tile_number: int, shape: [2]int)-> (tilemap: [][]int) {
	tilemap= make([][]int, shape.x/8)
	for i in 0 ..< shape.y/8 {
		tilemap[i]= make([]int, shape.y/8) }
	index: int= tile_number
	for row in 0 ..< shape.y/8 {
		for col in 0 ..< shape.x/8 {
			tilemap[col][row]= index
			index+= 1 } }
	return tilemap }
@(private="file") tilemap_2d:: proc(tile_number: int, shape: [2]int)-> (tilemap: [][]int) {
	tilemap= make([][]int, shape.x/8)
	for i in 0 ..< shape.y/8 {
		tilemap[i]= make([]int, shape.y/8) }
	index: int
	for row in 0 ..< shape.y/8 {
		index= 32*row + tile_number
		for col in 0 ..< shape.x/8 {
			tilemap[col][row]= index
			index+= 1 } }
	return tilemap }


// THREAD //
ppu_thread_proc:: proc(t: ^thread.Thread) { }