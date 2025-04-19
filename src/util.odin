package gbana
import		"core:fmt"
fmt_units:: proc(x: int, allocator:= context.temp_allocator)-> string {
	switch {
	case x >= 1_000_000_000:
		return fmt.aprint(int(f64(x)/1_000_000_000), " Gb", sep= "", allocator= allocator)
	case x >= 1_000_000:
		return fmt.aprint(int(f64(x)/1_000_000), " Mb", sep= "", allocator= allocator)
	case x >= 1_000:
		return fmt.aprint(int(f64(x)/1_000), " kb", sep= "", allocator= allocator)
	case:
		return fmt.aprint(x, " b", sep= "", allocator= allocator) } }
// rotate_right:: proc(value: i32, #any_int rotate: int)-> i32 {
// 	return (value>>uint(rotate)) | (value<<uint(32-rotate)) }
rotate_left:: proc(value: i32, #any_int rotate: int)-> i32 {
	return (value<<uint(rotate)) | (value>>uint(32-rotate)) }
try::proc(x:$T,ok:bool,loc:=#caller_location)->T {
	assert(ok,loc=loc)
	return x }
bit_range:: proc($start: int, $end: int) -> int {
	return end - start + 1 }


// BIT OPERATIONS //
// TODO Test these //
copy_bits:: proc { copy_bits_byte, copy_bits_halfword, copy_bits_word }
copy_bits_byte::     proc(dst: ^byte,     src: byte,     range:[2]uint) { _copy_bits(dst, src, range) }
copy_bits_halfword:: proc(dst: ^halfword, src: halfword, range:[2]uint) { _copy_bits(dst, src, range) }
copy_bits_word::     proc(dst: ^word,     src: word,     range:[2]uint) { _copy_bits(dst, src, range) }
_copy_bits:: proc(dst: ^$T, src: T, range:[2]uint) {
	assert((range[1] >= range[0]) && (range[0] >= 0) && (range[1] <= 7))
	mask: T = 0b1 << (range[1]-range[0])
	mask -= 1
	mask = mask << range[0]
	dst^ = dst^ & ~mask
	dst^ |= T(src) & mask }
insert_bits:: proc { insert_bits_byte, insert_bits_halfword, insert_bits_word }
insert_bits_byte::     proc(dst: ^byte,     src: byte,     range:[2]uint) { _insert_bits(dst, src, range) }
insert_bits_halfword:: proc(dst: ^halfword, src: halfword, range:[2]uint) { _insert_bits(dst, src, range) }
insert_bits_word::     proc(dst: ^word,     src: word,     range:[2]uint) { _insert_bits(dst, src, range) }
_insert_bits:: proc(dst: ^$T, src: T, range:[2]uint) {
	assert((range[1] >= range[0]) && (range[0] >= 0) && (range[1] <= 7))
	mask: T = 0b1 << (range[1]-range[0])
	mask -= 1
	mask = mask << range[0]
	dst^ = dst^ & ~mask
	dst^ |= (T(src) << range[0]) & mask }
copy_bit:: proc { copy_bit_byte, copy_bit_halfword, copy_bit_word }
copy_bit_byte::     proc(dst: ^byte,     src: byte,     index:uint) { _copy_bit(dst, src, index) }
copy_bit_halfword:: proc(dst: ^halfword, src: byte, index:uint) { _copy_bit(dst, src, index) }
copy_bit_word::     proc(dst: ^word,     src: byte,     index:uint) { _copy_bit(dst, src, index) }
_copy_bit:: proc(dst: ^$T, src: byte, index:uint) {
	assert((index >= 0) && (index <= 7))
	mask: T = 0b1 << index
	dst^ = dst^ & ~mask
	dst^ |= T(src) & mask }
insert_bit:: proc { insert_bit_byte, insert_bit_halfword, insert_bit_word }
insert_bit_byte::     proc(dst: ^byte,     src: byte,     index:uint) { _insert_bit(dst, src, index) }
insert_bit_halfword:: proc(dst: ^halfword, src: byte, index:uint) { _insert_bit(dst, src, index) }
insert_bit_word::     proc(dst: ^word,     src: byte,     index:uint) { _insert_bit(dst, src, index) }
_insert_bit:: proc(dst: ^$T, src: byte, index:uint) {
	assert((index >= 0) && (index <= 7))
	mask: T = 0b1 << index
	dst^ = dst^ & ~mask
	dst^ |= (T(src) << index) & mask }
rotate_right:: proc { rotate_right8, rotate_right16, rotate_right32 }
@(require_results)
rotate_right8:: proc "contextless" (x: u8,  k: uint) -> u8 {
	return x >> k | x << (8 - k) }
@(require_results)
rotate_right16:: proc "contextless" (x: u16, k: uint) -> u16 {
	return x >> k | x << (16 - k) }
@(require_results)
rotate_right32:: proc "contextless" (x: u32, k: uint) -> u32 {
	return x >> k | x << (32 - k) }