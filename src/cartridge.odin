package gbana
import "core:fmt"
import "core:os"
import "core:slice"


Cartridge:: struct { }


Cartridge_Header:: struct {
    rom_entry_point:    u32,
    nintendo_logo:      [156]u8,
    game_title:         [12]u8,
    game_code:          [4]u8,
    maker_code:         [2]u8,
    fixed_value:        u8,
    main_unit_code:     u8,
    device_type:        u8,
    _:                  [7]u8,
    software_version:   u8,
    complement_check:   u8,
    _:                  [2]u8 }
#assert(size_of(Cartridge_Header) == 192)


@(private="file") make_cartridge_header_valid:: proc() {
	// 1. compare nintendo logo //
	// 2. compute correct checksum //
}


insert_cartridge:: proc(filepath: string)-> bool {
	using state: ^State = cast(^State)context.user_ptr
	fmt.println("inserted cartridge |", filepath)
	cartridge_bytes, success: = os.read_entire_file_from_filename(filepath)
	cartridge: []u32le = slice.reinterpret([]u32le, cartridge_bytes)
	if ! success do return false
	n: = len(cartridge)
	assert(n <= len(memory.cartridge_game_data_0_region))
	// fmt.println("cartridge loaded | ", fmt_units(n), "/", fmt_units(len(memory.cartridge_game_data_0_region)))
	copy_slice(memory.cartridge_game_data_0_region[0:n], cartridge[0:n])
	copy_slice(memory.cartridge_game_data_1_region[0:n], cartridge[0:n])
	copy_slice(memory.cartridge_game_data_2_region[0:n], cartridge[0:n])
	return true }