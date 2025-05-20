package gbana
import "core:thread"
import "core:sync"


Sound_Controller:: struct {
	mutex: sync.Recursive_Mutex }
initialize_sound_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&sound_controller.mutex); defer sync.recursive_mutex_unlock(&sound_controller.mutex) }


// REGISTERS //
SOUND1CNT_L:: bit_field u16 {
	number_of_sweep_shift:     uint                       | 3,
	sweep_frequency_direction: enum{ Increase, Decrease } | 1,
	sweep_time:                uint                       | 3,
	_:                         int                        | 9 }
SOUND2CNT_L:: SOUND1CNT_L
SOUND1CNT_H:: bit_field u16 {
	sound_length:               uint                       | 6,
	wave_pattern_duty:          uint                       | 2,
	envelope_step_time:         uint                       | 3,
	envelope_direction:         enum{ Decrease, Increase } | 1,
	initial_volume_of_envelope: uint                       | 4 }
SOUND2CNT_H:: SOUND1CNT_H
SOUND1CNT_X:: bit_field u32 {
	frequency:   uint | 11,
	_:           int  | 3,
	length_flag: bool | 1,
	initial:     bool | 1,
	_:           int  | 16 }
SOUND3CNT_L:: bit_field u32 {
	_:                    int  | 5,
	wave_ram_dimension:   uint | 1,
	wave_ram_bank_number: uint | 1,
	sound_channel_3_on:   bool | 1,
	_:                    int  | 8 }
SOUND3CNT_H:: bit_field u16 {
	sound_length: uint                                                    | 8,
	_:            int                                                     | 5,
	sound_volume: enum { Percent_0, Percent_100, Percent_50, Percent_25 } | 2,
	force_volume: bool                                                    | 1 }
SOUND3CNT_X:: bit_field u32 {
	sample_rate:     uint | 11,
	_:               int  | 3,
	length_flag:     bool | 1,
	initialize_flag: bool | 1,
	_:               int  | 16 }
SOUND4CNT_L:: bit_field u32 {
	sound_length:               uint | 6,
	_:                          int  | 2,
	envelope_step_time:         uint | 3,
	envelope_direction:         int  | 1,
	initial_volume_of_envelope: uint | 4,
	_:                          int  | 16 }
SOUND4CNT_H:: bit_field u32 {
	dividing_ratio_of_frequencies: uint                    | 3,
	counter_step_width:            enum{ Bits_15, Bits_7 } | 1,
	shift_clock_frequency:         uint                    | 4,
	_:                             int                     | 6,
	length_flag:                   bool                    | 1,
	initialize_flag:               bool                    | 1,
	_:                             int                     | 16 }
SOUNDCNT_L:: bit_field u16 {
	sound_master_volume_right: uint | 3,
	_:                         int  | 1,
	sound_master_volume_left:  uint | 3,
	_:                         int  | 1,
	sound_1_enable_right:      bool | 1,
	sound_2_enable_right:      bool | 1,
	sound_3_enable_right:      bool | 1,
	sound_4_enable_right:      bool | 1,
	sound_1_enable_left:       bool | 1,
	sound_2_enable_left:       bool | 1,
	sound_3_enable_left:       bool | 1,
	sound_4_enable_left:       bool | 1 }
SOUNDCNT_H:: bit_field u16 {
	sound_volume:             enum{ Percent_25, Percent_50, Percent_100 } | 2,
	dma_sound_a_volume:       enum{ Percent_50, Percent_100 }             | 1,
	dma_sound_b_volume:       enum{ Percent_50, Percent_100 }             | 1,
	_:                        int                                         | 4,
	dma_sound_a_enable_right: bool                                        | 1,
	dma_sound_a_enable_left:  bool                                        | 1,
	dma_sound_a_timer_select: uint                                        | 1,
	dma_sound_a_reset_fifo:   bool                                        | 1,
	dma_sound_b_enable_right: bool                                        | 1,
	dma_sound_b_enable_left:  bool                                        | 1,
	dma_sound_b_timer_select: uint                                        | 1,
	dma_sound_b_reset_fifo:   bool                                        | 1 }
SOUNDCNT_X:: bit_field u32 {
	sound_1_on:             bool | 1,
	sound_2_on:             bool | 1,
	sound_3_on:             bool | 1,
	sound_4_on:             bool | 1,
	_:                      int  | 3,
	psg_fifo_master_enable: bool | 1,
	_:                      int  | 24 }
SOUNDBIAS:: bit_field u32 {
	_:                    int                                    | 1,
	bias_level:           uint                                   | 9,
	_:                    int                                    | 4,
	amplitude_resolution: enum{ Bits_9, Bits_8, Bits_7, Bits_6 } | 2,
	_:                    int                                    | 16 }
WAVE_RAM:: [2][16]u8
FIFO_A:: [4]u8
FIFO_B:: FIFO_A


// THREAD //
sound_controller_thread_proc:: proc(t: ^thread.Thread) { }