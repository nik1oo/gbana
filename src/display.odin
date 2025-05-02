package gbana
import		"vendor:glfw"
import gl	"vendor:OpenGL"


// REGISTERS //
DISPCNT:: bit_field u16 {
	bg_mode:                    uint                                     | 2,
	reserved_cgb_mode:          enum{ GBA, CGB }                         | 1,
	display_frame_select:       uint                                     | 1,
	h_blank_interval_free:      bool                                     | 1,
	obj_character_vram_mapping: enum{ Two_Dimensional, One_Dimensional } | 1,
	forced_blank:               bool                                     | 1,
	screen_display_bg0:         bool                                     | 1,
	screen_display_bg1:         bool                                     | 1,
	screen_display_bg2:         bool                                     | 1,
	screen_display_bg3:         bool                                     | 1,
	screen_display_obj:         bool                                     | 1,
	window_0_display_flag:      bool                                     | 1,
	window_1_display_flag:      bool                                     | 1,
	obj_window_display_flag:    bool                                     | 1 }
GSWP:: bit_field u16 {
	green_swap: bool | 1,
	_:          int  | 15 }
DISPSTAT:: bit_field u16 {
	v_blank_flag:         bool | 1,
	h_blank_flag:         bool | 1,
	v_counter_flag:       bool | 1,
	v_blank_irq_enable:   bool | 1,
	h_blank_irq_enable:   bool | 1,
	v_counter_irq_enable: bool | 1,
	_:                    int  | 1,
	_:                    int  | 1,
	v_count_setting:      uint  | 8 }
VCOUNT:: bit_field u16 {
	current_scanline: uint | 8,
	_:                int  | 8 }
BGCNT:: bit_field u16 {
	bg_priority:           uint                            | 2,
	character_base_block:  uint                            | 2,
	_:                     int                             | 2,
	mosaic:                bool                            | 1,
	colors_palettes:       enum{ Mode_16_16, Mode_256_1 }  | 1,
	screen_base_block:     uint                            | 5,
	display_area_overflow: enum{ Transparent, Wraparound } | 1,
	screen_size:           uint                            | 2 }
BG0CNT:: BGCNT
BG1CNT:: BGCNT
BG2CNT:: BGCNT
BG3CNT:: BGCNT
BGOFS:: bit_field u16 {
	offset: uint | 9,
	_:      int  | 7 }
BG0HOFS:: BGOFS
BG0VOFS:: BGOFS
BG1HOFS:: BGOFS
BG1VOFS:: BGOFS
BG2HOFS:: BGOFS
BG2VOFS:: BGOFS
BG3HOFS:: BGOFS
BG3VOFS:: BGOFS
BGREF:: bit_field u32 {
	fractional_portion: uint | 8,
	integer_portion:    uint | 19,
	sign:               int  | 1,
	_:                  uint | 4 }
BG2X:: BGREF
BG2Y:: BGREF
BG3X:: BGREF
BG3Y:: BGREF
BGPAR:: bit_field u16 {
	fractional_portion: uint | 8,
	integer_portion:    uint | 7,
	sign:               int  | 1 }
BG2PA:: BGPAR
BG2PB:: BGPAR
BG2PC:: BGPAR
BG2PD:: BGPAR
BG3PA:: BGPAR
BG3PB:: BGPAR
BG3PC:: BGPAR
BG3PD:: BGPAR
WINH:: bit_field u16 {
	x2: uint | 8,
	x1: uint | 8 }
WIN0H:: WINH
WIN1H:: WINH
WINV:: bit_field u16 {
	y2: uint | 8,
	y1: uint | 8 }
WIN0V:: WINV
WIN1V:: WINV
WININ:: bit_field u16 {
	window_0_bg0:                  bool | 1,
	window_0_bg1:                  bool | 1,
	window_0_bg2:                  bool | 1,
	window_0_bg3:                  bool | 1,
	window_0_obj:                  bool | 1,
	window_0_color_special_effect: bool | 1,
	_:                             int  | 2,
	window_1_bg0:                  bool | 1,
	window_1_bg1:                  bool | 1,
	window_1_bg2:                  bool | 1,
	window_1_bg3:                  bool | 1,
	window_1_obj:                  bool | 1,
	window_1_color_special_effect: bool | 1,
	_:                             int  | 2 }
WINOUT:: bit_field u16 {
	outside_0_bg0:                     bool | 1,
	outside_0_bg1:                     bool | 1,
	outside_0_bg2:                     bool | 1,
	outside_0_bg3:                     bool | 1,
	outside_0_obj:                     bool | 1,
	outside_0_color_special_effect:    bool | 1,
	_:                                 int  | 2,
	obj_window_1_bg0:                  bool | 1,
	obj_window_1_bg1:                  bool | 1,
	obj_window_1_bg2:                  bool | 1,
	obj_window_1_bg3:                  bool | 1,
	obj_window_1_obj:                  bool | 1,
	obj_window_1_color_special_effect: bool | 1,
	_:                                 int  | 2 }
MOSAIC:: bit_field u32 {
	bg_mosaic_h_size:  uint | 4,
	bg_mosaic_v_size:  uint | 4,
	obj_mosaic_h_size: uint | 4,
	obj_mosaic_v_size: uint | 4,
	_:                 int  | 16 }
BLDCNT:: bit_field u16 {
	bg0_1st_target_pixel: bool                                                                   | 1,
	bg1_1st_target_pixel: bool                                                                   | 1,
	bg2_1st_target_pixel: bool                                                                   | 1,
	bg3_1st_target_pixel: bool                                                                   | 1,
	obj_1st_target_pixel: bool                                                                   | 1,
	bd_1st_target_pixel:  bool                                                                   | 1,
	color_special_effect: enum{ None, Alpha_Blending, Brightness_Increase, Brightness_Decrease } | 2,
	bg0_2nd_target_pixel: bool                                                                   | 1,
	bg1_2nd_target_pixel: bool                                                                   | 1,
	bg2_2nd_target_pixel: bool                                                                   | 1,
	bg3_2nd_target_pixel: bool                                                                   | 1,
	obj_2nd_target_pixel: bool                                                                   | 1,
	bd_2nd_target_pixel:  bool                                                                   | 1,
	_:                    int                                                                    | 2 }
BLDALPHA:: bit_field u16 {
	eva_coefficient: uint | 5,
	_:               int  | 3,
	evb_coefficient: uint | 5,
	_:               int  | 3 }
BLDY:: bit_field u32 {
	evy_coefficient: uint | 5,
	_:               int  | 27 }


// DISPLAY I/O MEMORY //
Display:: struct {
	window_res:                            [2]i32,
	render_res:                            [2]i32,
	window:                                glfw.WindowHandle,
	lcd_control:                           ^DISPCNT,
	green_swap:                            ^GSWP,
	general_lcd_status:                    ^DISPSTAT,
	vertical_counter:                      ^VCOUNT,
	bg0_control:                           ^BG0CNT,
	bg1_control:                           ^BG1CNT,
	bg2_control:                           ^BG2CNT,
	bg3_control:                           ^BG3CNT,
	bg0_x_offset:                          ^BG0HOFS,
	bg0_y_offset:                          ^BG0VOFS,
	bg1_x_offset:                          ^BG1HOFS,
	bg1_y_offset:                          ^BG1VOFS,
	bg2_x_offset:                          ^BG2HOFS,
	bg2_y_offset:                          ^BG2VOFS,
	bg3_x_offset:                          ^BG3HOFS,
	bg3_y_offset:                          ^BG3VOFS,
	bg2_dx:                                ^BG2PA,
	bg2_dmx:                               ^BG2PB,
	bg2_dy:                                ^BG2PC,
	bg2_dmy:                               ^BG2PD,
	bg2_x:                                 ^BG2X,
	bg2_y:                                 ^BG2Y,
	bg3_dx:                                ^BG3PA,
	bg3_dmx:                               ^BG3PB,
	bg3_dy:                                ^BG3PC,
	bg3_dmy:                               ^BG3PD,
	bg3_x:                                 ^BG3X,
	bg3_y:                                 ^BG3Y,
	win0_h:                                ^WIN0H,
	win1_h:                                ^WIN1H,
	win0_v:                                ^WIN0V,
	win1_v:                                ^WIN1V,
	inside_window_0_and_1:                 ^WININ,
	inside_obj_window_and_outside_windows: ^WINOUT,
	mosaic_size:                           ^MOSAIC,
	color_special_effects_selection:       ^BLDCNT,
	alpha_blending_coefficients:           ^BLDALPHA,
	brightness_coefficient:                ^BLDY }
initialize_display:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	display.window_res = {1664, 936}
	display.render_res = {240, 160}
	glfw.Init()
	//glfw.SetErrorCallback(glfw_error_callback)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.SAMPLES, 16)
	display.window = glfw.CreateWindow(display.window_res.x, display.window_res.y, "GBANA", nil, nil)
	glfw.MakeContextCurrent(display.window)
	glfw.SwapInterval(0)
	gl.load_up_to(4, 3, glfw.gl_set_proc_address)
	//glfw.SetKeyCallback(window, key_callback)
	//glfw.SetCursorPosCallback(window, cursor_pos_callback)
	glfw.SetDropCallback(display.window, drag_and_drop_callback)
	//glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_CAPTURED)
	//glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
	framebuffer_size: [2]i32
	framebuffer_size.x, framebuffer_size.y = glfw.GetFramebufferSize(display.window)
	gl.Viewport(0, 0, framebuffer_size.x, framebuffer_size.y)
	vao: u32
	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)
	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	gl.ClearColor(f32(0xFB) / 255, f32(0xF8) / 255, f32(0xEF) / 255, 1)
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	gl.DepthFunc(gl.LESS)
	gl.FrontFace(gl.CW)
	gl.Enable(gl.CULL_FACE)
	gl.Enable(gl.MULTISAMPLE)
	gl.CullFace(gl.FRONT)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA) }


TARGET_FPS:: 60


// VIDEO MODES //
Video_Mode_Config:: struct {
	rotation_and_scaling: enum{ No, Yes, Mixed },
	layers:               bit_set[0..<4],
	size_min:             [2]int,
	size_max:             [2]int,
	tiles:                int,
	colors_min:           union{ int, [2]int },
	colors_max:           union{ int, [2]int },
	features:             bit_set[Video_Features] }
Video_Features:: enum{ Scrolling, Flip, Mosaic, Alpha_Blending, Brightness, Priority }
VIDEO_MODE_CONFIGS: [6]Video_Mode_Config = {
	Video_Mode_Config{
		rotation_and_scaling = .No,
		layers               = { 0, 1, 2, 3 },
		size_min             = { 256, 256 },
		size_max             = { 512, 515 },
		tiles                = 1024,
		colors_min           = [2]int{ 16, 16 },
		colors_max           = [2]int{ 256, 1 },
		features             = { .Scrolling, .Flip, .Mosaic, .Alpha_Blending, .Brightness, .Priority } },
	Video_Mode_Config{
		rotation_and_scaling = .Mixed,
		layers               = { 0, 1, 2 },
		size_min             = { 128, 128 },
		size_max             = { 512, 512 },
		tiles                = 1024,
		colors_min           = [2]int{ 16, 16 },
		colors_max           = [2]int{ 256, 1 },
		features             = { .Scrolling, .Flip, .Mosaic, .Alpha_Blending, .Brightness, .Priority } },
	Video_Mode_Config{
		rotation_and_scaling = .Yes,
		layers               = { 2, 3 },
		size_min             = { 128, 128 },
		size_max             = { 1024, 1024 },
		tiles                = 256,
		colors_min           = [2]int{ 256, 1 },
		colors_max           = [2]int{ 256, 1 },
		features             = { .Scrolling, .Mosaic, .Alpha_Blending, .Brightness, .Priority } },
	Video_Mode_Config{
		rotation_and_scaling = .Yes,
		layers               = { 2 },
		size_min             = { 240, 160 },
		size_max             = { 240, 160 },
		tiles                = 1,
		colors_min           = 32768,
		colors_max           = 32768,
		features             = { .Mosaic, .Alpha_Blending, .Brightness, .Priority } },
	Video_Mode_Config{
		rotation_and_scaling = .Yes,
		layers               = { 2 },
		size_min             = { 240, 160 },
		tiles                = 2,
		colors_min           = [2]int{ 256, 1 },
		colors_max           = [2]int{ 256, 1 },
		features             = { .Mosaic, .Alpha_Blending, .Brightness, .Priority } },
	Video_Mode_Config{
		rotation_and_scaling = .Yes,
		layers               = { 2 },
		size_min             = { 160, 128 },
		size_max             = { 160, 128 },
		tiles                = 2,
		colors_min           = 32768,
		colors_max           = 32768,
		features             = { .Mosaic, .Alpha_Blending, .Brightness, .Priority } } }


// BACKGROUND SIZES //
Background_Size_Config:: struct {
	text_mode:             [2]uint,
	rotation_scaling_mode: [2]uint }
@(rodata) BACKGROUND_SIZE_CONFIGS: [4]Background_Size_Config = {
	Background_Size_Config{
		text_mode             = { 256, 256 },
		rotation_scaling_mode = { 128, 128 } },
	Background_Size_Config{
		text_mode             = { 512, 256 },
		rotation_scaling_mode = { 256, 256 } },
	Background_Size_Config{
		text_mode             = { 256, 512 },
		rotation_scaling_mode = { 512, 512 } },
	Background_Size_Config{
		text_mode             = { 512, 512 },
		rotation_scaling_mode = { 1024, 1024 } } }


// BACKGROUND TILE //
Background_Tile:: bit_field u16 {
	Tile_Number:     uint | 10,
	Horizontal_Flip: bool | 1,
	Vertical_Flip:   bool | 1,
	Palette_Number:  uint | 4 }


draw_display:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	glfw.PollEvents()
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.Clear(gl.DEPTH_BUFFER_BIT)
	//select_render_buffer(canvas_rb)
	//select_frame_buffer(0)
	//render_render_buffer(canvas_rb)
	glfw.SwapBuffers(display.window) }