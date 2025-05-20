package gbana
import "core:thread"
import "core:sync"


SIO_Controller:: struct {
	mutex: sync.Recursive_Mutex }
initialize_sio_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&sio_controller.mutex); defer sync.recursive_mutex_unlock(&sio_controller.mutex) }


// REGISTERS //
SIODATA32:: u32
SIOMULTI0:: u16
SIOMULTI1:: SIOMULTI0
SIOMULTI2:: SIOMULTI0
SIOMULTI3:: SIOMULTI0
// TODO The unused fields should be uint //
SIOCNT:: bit_field u16 {
	baud_rate:                   enum{ BPS_9600, BPS_38400, BPS_57600, BPS_115200 } | 2,
	si_terminal:                 enum{ Parent, Child }                              | 1,
	sd_terminal:                 enum{ Bad_Connection, All_GBAs_Ready }             | 1,
	multi_player_id:             enum{ Parent, Child_1, Child_2, Child_3 }          | 2,
	multi_player_error:          bool                                               | 1,
	start_or_busy_bit:           enum{ Inactive, Start_Or_Busy }                    | 1,
	_:                           int                                                | 4,
	non_multiplayer_mode_enable: bool                                               | 1,
	multiplayer_mode_enable:     bool                                               | 1,
	irq_enable:                  bool                                               | 1,
	_:                           int                                                | 1 }
SIOMLT_SEND:: u16
SIODATA8:: struct {
	data: u8,
	_: u8 }
RCNT:: u16
JOYCNT:: bit_field u32 {
	device_reset_flag:                         bool | 1,
	receive_complete_flag:                     bool | 1,
	send_complete_flag:                        bool | 1,
	_:                                         int  | 3,
	irq_when_receiving_a_device_reset_command: bool | 1,
	_:                                         int  | 25 }
JOY_RECV:: u32
JOY_TRANS:: u32
JOYSTAT:: bit_field u32 {
	_:                      int  | 1,
	receive_status_flag:    bool | 1,
	_:                      int  | 1,
	send_status_flag:       bool | 1,
	general_purpose_flag_1: bool | 1,
	general_purpose_flag_2: bool | 1,
	_:                      int  | 26 }


// THREAD //
sio_controller_thread_proc:: proc(t: ^thread.Thread) { }