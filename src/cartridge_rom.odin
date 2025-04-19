package gbana
import		"core:fmt"
import		"core:os"


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


make_cartridge_header_valid:: proc() {
	// 1. compare nintendo logo //
	// 2. compute correct checksum //
}


insert_cartridge:: proc(filepath: string) {
	fmt.println("inserted cartridge |", filepath)
	load_cartridge(filepath) }