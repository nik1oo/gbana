#import "@preview/ilm:1.4.1": *
#import "@preview/wavy:0.1.3"
#set text(lang: "en")
#set list(spacing: 1em)
#show: ilm.with(
	title: [GBANA DESIGN DOC],
	author: "Version 0.1.0",
	date: datetime(year: 2025, month: 04, day: 25),
	figure-index: (enabled: true),
	table-index: (enabled: true),
	listing-index: (enabled: true))
#import "@preview/circuiteria:0.2.0": circuit, element, util, wire
#show raw: set text(size: 11pt)
#show raw.where(lang: "wavy"): it => wavy.render(it.text)
#set table(inset: 0.4em, align: top)

= #smallcaps[Classes]

#table(
	columns: (auto, auto, auto, auto),
	inset: 0.4em,
	align: top,
	table.header(
	[*Name*], [*File*], [*Type*], [*Description*],
	[*GBA Core*], [`gba_core.odin`], [Singleton Class], [The ARM7TDMI core inside the AGB ASIC.],
	[*GB Core*], [`gb_core.odin`], [Singleton Class], [The SM83 core inside the AGB ASIC.],
	[*Bus Controller*], [`bus_controller.odin`], [Singleton Class], [The bus control circuits inside the AGB ASIC.],
	[*DMA Controller*], [`dma_controller.odin`], [Singleton Class], [The direct memory access control circuits inside the AGB ASIC.],
	[*Sound Controller*], [`sound_controller.odin`], [Singleton Class], [The sound control circuits inside the AGB ASIC.],
//	[*AGB ASIC*], [`cpu.odin`], [Helper Class], [The general control circuits inside the AGB ASIC.],
	[*Memory*], [`memory.odin`], [Singleton Class], [The internal/device and\ the external/cartridge\ memory.],
	[*Buttons*], [`buttons.odin`], [Singleton Class], [The buttons and\ adjacent circuits on the device motherboard.],
//	[*Cartridge*], [`cartridge.odin`], [Singleton Class], [Emulating a GBA cartridge.],
	[*Display*], [`display.odin`], [Singleton Class], [The LCD display and adjacent circuits.],
	[*GBA Isa*], [`gba_isa.odin`], [Helper Class], [Implementation of the\ ARM4T ISA of the\ ARM7TDMI core.],
	[*GB Isa*], [`gb_isa.odin`], [Helper Class], [Implementation of the ISA of the Sharp SM83 core (a hybrid between the 8085 ISA and the Z80 ISA).],
	[*PPU*], [`ppu.odin`], [Singleton Class], [The Picture Processing\ Unit / LCD Video\ Controller inside the AGB ASIC.],
	[*Signal*], [`line_and_bus.odin`], [Instance Class], [A support class to emulate signals.],
	[*SIO Controller*], [`sio_controller.odin`], [Singleton Class], [The Serial Input/Output\ control circuits located inside the AGB ASIC.],
	[*Speakers*], [`speakers.odin`], [Singleton Class], [The audio output device\ and adjacent circuits on the device motherboard.],
	[*Util*], [`util.odin`], [Helper Class], [General utilities.]))

= #smallcaps[Block Diagram]

#align(center, circuit({
	element.group(name: text(16pt)[Device\ Motherboard], stroke: 0.75pt, fill: silver, radius: 0pt, {
		element.block(stroke: none, x: 4, y: 2.5, w: 4, h: 2, id: "block")
		element.group(name: text(16pt)[AGB ASIC], stroke: 0.75pt, fill: gray, radius: 0pt, {
			element.block(name: [GBA\ Core], x: 4, y: 0, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [GB\ Core], x: 8.25, y: 0, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [Bus\ Controller], x: 4, y: -2.25, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [DMA\ Controller], x: 8.25, y: -2.25, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [PPU], x: 4, y: -4.5, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [Sound\ Controller], x: 8.25, y: -4.5, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [Timer\ Controller], x: 4, y: -6.75, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [Interrupt\ Controller], x: 8.25, y: -6.75, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [Input\ Controller], x: 4, y: -9, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
			element.block(name: [SIO\ Controller], x: 8.25, y: -9, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
		})
		element.block(name: "Oscillator", x: 4, y: -12.1, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
		element.block(name: "Speaker", x: 8.25, y: -12.1, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
		element.block(name: "Display", x: 4, y: -14.35, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
		element.block(name: "Buttons", x: 8.25, y: -14.35, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
	})
	element.group(name: text(16pt)[Cartridge\ Motherboard], stroke: 0.75pt, fill: silver, radius: 0pt, {
		element.block(stroke: none, x: 13.35, y: 2.5, w: 4, h: 2, id: "block", fill: white)
		element.block(name: "Cartridge", x: 13.35, y: 0, w: 4, h: 2, id: "block", fill: white, stroke: 0.75pt)
	})
	element.block(name: "Memory", x: 4, y: 2.5, w: 13.35, h: 2, id: "block", fill: white, stroke: 0.75pt)
}))

Each rounded reactangle is a *component*. Each component has a state object, which holds its data. Each non-rounded rectangle is a group of components that are semantically related. Components operate concurrently and share data only by means of *signals*.

= #smallcaps[Emulating the Clock & Cycle]

*Related procedures:*
/ `test_main_clock`: Test procedure.

The core will initially be written as phase-accurate (every phase of every clock cycle is simulated), whose logic will be correct at phase bounds. Then a more high-level core will be implemented, which will be sequence-accurate, whose logic will be correct at sequence bounds, and this core will be verified against the lower-level core.

#align(center,wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
  ],
  head:{ tick:0, every:1 }
}"))

Main clock frequency: 16 MHz, ie approximately 62.5 ns per cycle. Each phase has two parts: a _start_ part, where all the signals are updated and their callback functions are called, and an _interior_ part, where the components execute their logic based on their internal state and the updated signals.

= #smallcaps[Signals]

Components may only communicate by means of *signals*. There are two ways to affect a signal: (1) by _putting_ data on it, and (2) by _forcing_ data on it. Forcing updates the output value immediately. Putting schedules an update to the output value, to occur after a certain number of ticks.

#table(
	columns: (auto, auto, auto, auto),
	inset: 0.4em,
	align: top,
	table.header(
	[*Name*], [*Class*], [*Components*], [*Description*]),
	`A`,       [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Address Bus) The *GBA Core* / *GB Core* writes an address here when it requests memory access.],
	`ABE`,     [Bus\ Controls], [*Bus Controller*], [(Address Bus Enable) The *GBA Core* sets this to high to become master of the address bus (this is effectively a mutex on `A`), and to low to make the *DMA Controller* master of the address bus.],
	`ABORT`,   [Memory\ Management\ Interface], [*GBA Core*], [The *Memory* sets this to high when the requested memory operation cannot be performed, and to low when it can.],
	`BIGEND`,  [Bus\ Controls], [*GBA Core*], [The *GBA Core* sets this to high to interpret words in memory as being big-endian, and to low to interpret them as being little-endian. On the GBA, this is always 0 (little-endian format).],
	`BL`,      [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Byte Latch) The *GBA Core* writes a bit mask here to indicate which part of the requested word is to be read/written.],
	`DBE`,     [Bus\ Controls], [*Bus Controller*], [(Data Bus Enable) The *GBA Core* sets this to high to become master of the data output bus (this is effectively a mutex on `DOUT`), and to low to make *DMA Controller* master of the address bus.],
	`DIN`,     [Memory\ Interface], [*GBA Core* /\ *Bus Controller*], [(Unidirectional Data Input Bus) The *Memory* writes data here when a read request has been made.],
	`DOUT`,    [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Unidirectional Data Output Bus) The *GBA Core* writes data here when a write request has been made.],
	`FIQ`,     [Interrupts], [*GBA Core*], [(Fast Interrupt Request) Set this to high to request a fast interrupt.],
	`ISYNC`,   [Interrupts], [*GBA Core*], [(Synchronous Interrupt) Set this to high to indicate that the requested interrupt should be synchronous to the processor clock.],
	`IRQ`,     [Interrupts], [*GBA Core*], [(Interrupt Request) Set this to high to request an interrupt.],
	`LOCK`,    [Memory\ Interface], [*Memory* /\ *Bus Controller*], [The *GBA Core* / *GB Core* sets this to high to gain exclusive access to the *Memory* (this is effectively a mutex on the *Memory* signals).],
	`MAS`,     [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Memory Access Size) The *GBA Core* / *GB Core* writes here the size of the requested data access.],
	`MCLK`,    [Clocks\ and Timing], [*GBA Core*,\ *Memory*], [(Main Clock) The main clock.],
	`M`,       [Processor\ Mode], [*GBA Core*], [(Processor Mode) The current mode of the ARM7TDMI core.],
	`MREQ`,    [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Memory Request) The *GBA Core* / *GB Core* sets this to high to to request memory access in the subsequent cycle.],
	`OPC`,     [Memory\ Interface], [*Memory*], [(Op-Code Fetch) The *GBA Core* / *GB Core* sets this to high to indicate that the requested memory access is to fetch the next instruction.],
	`RESET`,   [Bus\ Controls], [*GBA Core*], [Set this to high to initialize / restart the AMR7TDMI processor.],
	`RW`,      [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Read/Write) The *GBA Core* / *GB Core* sets this to high to indicate that the requested memory access is a read, and to low to indicate that it is a write.],
	`SEQ`,     [Memory\ Interface], [*Memory* /\ *Bus Controller*], [(Sequential Cycle) The *GBA Core* / *GB Core* sets this to high to indicate that the subsequent memory cycle will be sequential, and to low to indicate that it will be nonsequential.],
	`TBIT`,    [Processor\ State], [*GBA Core*], [(Thumb Mode Bit) Set this to high to switch the ARM7TDMI core to Thumb mode, and to low to switch it to ARM mode.],
	`WAIT`,    [Clocks\ and Timing], [*GBA Core*], [Set this to high to insert a wait cycle.])

= #smallcaps[Sequences]

There are two fundamental types of sequence: *internal sequence* and *external sequence*. Internal cycles are initiated by the *GBA Core* by calling a `gba_initiate_<cycle_name>_cycle_request` procedure and then one or more other components respond by interpreting the signals and calling a `<component_name>_initiate_<cycle_name>_cycle_response` procedure.

Types of intervals in a timing diagram:
- _Open Unshaded_ - The line/bus is expected to remain stable throughout this interval.
  - _Writing_ occurs at the _start_ and is prohibited in the _interior_.
  - _Reading_ is allowed at the _start_ (by signals succeding it in the tick order) and in the _interior_.
- _Open Shaded_ - The line/bus is expected to change at an arbitrary time during this interval.
  - _Writing_ is prohibited at the _start_ and allowed in the _interior_.
  - Reading is allowed at the _start_ and prohibited in the _interior_.
- _Closed_ - The line/bus is disabled.
  - _Writing_ is prohibited at the _start_ and prohibited in the _interior_.
  - _Reading_ is prohibited at the _start_ and in the _interior_.

In request/response contexts, request data is in displayed in blue, and respone data is displayed in pink.

\

#pagebreak()
== #smallcaps[Memory Sequence]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_memory_sequence`,
  `gba_request_memory_sequence`,
  `memory_respond_memory_sequence`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

The Memory Sequence is an external sequence where the GBA Core requests and the Memory responds. Reads and writes have distinct logic. Word-wide bus access, halfword-wide bus access, and byte-wide bus access have distinct logic. The Memory may extend the time to fulfill the request and it may assert that a request may not be fulfilled.

#figure(caption: [Memory Sequence timing diagram], wavy.render(height: 37%, "{
  signal:
  [
    {name:'MCLK', wave:'lhlhlhlh'},
    {name:'MREQ', wave:'x.1.x...', phase: 0},
    {name:'SEQ',  wave:'x.5.x...', phase: 0},
    {name:'RW',   wave:'x..5.x..', phase: 0},
    {name:'A',    wave:'x...5.x.', phase: 0},
    {name:'DOUT', wave:'x...5.x.', phase: 0},
    {name:'WAIT', wave:'x...0.x.', phase: 0},
    {name:'ABORT',wave:'x....8x.', phase: 0},
    {name:'DIN',wave:'x....8x.', phase: 0},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response',
	'D+E post'
  ],
  head:{ tick:0, every:1 }
}"))
- The *GBA Core* must set `SEQ` to high when the access is sequential to the access performed in the previous cycle.
- The *GBA Core* must set `RW` to high for reading and to low for writing.
- The *GBA Core* must write the address to `A`.
- The *Memory* may set `WAIT` to high to delay the response cycle.
- The *Memory* may set `ABORT` to high to indicate that the request cannot be fulfilled.
- The *Memory* must put the data on `DIN` during the high phase of the response cycle.
\

#pagebreak()
== #smallcaps[Nonsequential Memory Sequence (N-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_N_cycle`,
  `gba_request_N_cycle`,
  `memory_respond_N_cycle`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 1 to 2 clock cycles]

The Nonsequential Memory Sequence (or N-Cycle) is a memory access sequence, preceded by an internal sequence or another memory access sequence to an address other than the address immediately before the current address.

#figure(caption: [Nonsequential Memory Sequence timing diagram], wavy.render(height: 36%, "{
  signal:
  [
    {name:'MCLK', wave:'lhlhlhlh'},
    {name:'MREQ', wave:'x.1.x...', phase: 0},
    {name:'SEQ',  wave:'x.0.x...', phase: 0},
    {name:'RW',    wave:'x..5.x..', phase: 0},
    {name:'A',    wave:'x...5.x.', phase: 0},
    {name:'DOUT', wave:'x...5.x.', phase: 0},
    {name:'WAIT', wave:'x...8.x.', phase: 0},
    {name:'ABORT',wave:'x....8x.', phase: 0},
    {name:'DIN',  wave:'x...z8x.', phase: 0},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response',
	'D+E post'
  ],
  head:{ tick:0, every:1 }
}"))
- The *GBA Core* must set `RW` to high for reading and to low for writing.
- The *GBA Core* must write the address to `A`.
- The *Memory* may set `WAIT` to high to delay the response cycle.
- The *Memory* may set `ABORT` to high to indicate that the request cannot be fulfilled.
- The *Memory* must put the data on `DIN` during the high phase of the response cycle.
\

#pagebreak()
== #smallcaps[Sequential Memory Sequence (S-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_S_cycle`,
  `gba_request_S_cycle`,
  `memory_respond_S_cycle`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 2 clock cycles]

The Sequential Memory Sequence (or S-Cycle) is a memory access sequence, preceded by another memory access sequence to the address immediately before the current address.

#figure(caption: [Sequential Memory Sequence timing diagram], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK', wave:'lhlhlhlhlh'},
    {name:'MREQ', wave:'x.1.....x.', phase: 0},
    {name:'SEQ',  wave:'x.0.1...x.', phase: 0},
    {name:'A',    wave:'x...5.5.5.', phase: 0},
    {name:'DOUT', wave:'x...5.5.5.', phase: 0},
    {name:'WAIT', wave:'x...8.8.8.', phase: 0},
    {name:'ABORT',wave:'x....8x8x8', phase: 0},
    {name:'DIN',  wave:'x...z8z8z8', phase: 0},
    {node:'A.B.C.D.E.F', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response 1',
	'D+E response 2',
	'E+F response 3',
  ],
  head:{ tick:0, every:1 }
}"))

- The *GBA Core* must set `RW` to high for reading and to low for writing.
- The *GBA Core* must write the address to `A`.
- The *Memory* may set `WAIT` to high to delay the next response cycle.
- The *Memory* may set `ABORT` to high to indicate that the request cannot be fulfilled.
- The *Memory* must put the data on `DIN` during the high phase of the response cycle.
\

#pagebreak()
== #smallcaps[Internal Sequence]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_I_cycle`,
  `gba_initiate_I_cycle`)

#table(
  columns: (100%),
  table.header([*Signals*]),
  [`MREQ`,`SEQ`,`A`,`DIN`,`DOUT`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 1 clock cycle]

The Internal Sequence (or I-Cycle) is a sequence that doesn't involve exchaning data with any components outside of the core.

#figure(caption: [Internal Sequence timing diagram], wavy.render(height: 22%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'x.0.x.', phase: 0},
    {name:'SEQ',wave:'x.0.x.', phase: 0},
    {name:'A',wave:'x.....', phase: 0},
    {name:'DIN, DOUT',wave:'x.z.x.', phase: 0},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C internal',
	'C+D post',
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Merged Internal-Sequential Sequence (MIS-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_MIS_cycle`,
  `gba_request_MIS_cycle`,
  `memory_respond_MIS_cycle`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 2 clock cycles]

The Merged Internal-Sequential Sequence (or Merged IS-Cycle) is an internal sequence followed immediately by a sequential memory cycle.

#figure(caption: [Merged Internal-Sequential Sequence timing diagram], wavy.render(height: 33%, "{
  signal:
  [
    {name:'MCLK', wave:'lhlhlhlh'},
    {name:'MREQ', wave:'x.0.1.x.', phase: 0},
    {name:'SEQ',  wave:'x.0.1.x.', phase: 0},
    {name:'A',    wave:'x...5.x.', phase: 0},
    {name:'DOUT', wave:'x...5.x.', phase: 0},
    {name:'WAIT', wave:'x...8.x.', phase: 0},
    {name:'ABORT',wave:'x....8x.', phase: 0},
    {name:'DIN',  wave:'x.z..8xx', phase: 0},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response',
	'D+E post'
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Depipelined Addressing]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_depipelined_addressing`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

#figure(caption: [Depipelined Addressing timing diagram], wavy.render(height: 18%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlh'},
    {name:'MREQ/SEQ',wave:'x.5.x...', phase: 0},
    {name:'A',wave:'x...5.x.', phase: 0},
    {name:'DIN',wave:'x...z8x.', phase: 0},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response',
	'D+E post'
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Data Write Sequence (DW-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_DW_cycle`,
  `gba_request_DW_cycle`,
  `memory_respond_DW_cycle`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 2 clock cycles]

A Data Write Sequence is an external sequence where a write operation is requested by the GBA Core.

#figure(caption: [Data Write Sequence timing diagram], wavy.render(height: 29%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1.x...', phase: 0},
    {name:'RW',  wave:'x0.x..', phase: 0},
    {name:'A',   wave:'x.5.x.', phase: 0},
    {name:'DOUT',wave:'x.5.x.', phase: 0},
    {name:'WAIT', wave:'x.8.x.', phase: 0},
    {name:'ABORT',wave:'x..8x.', phase: 0},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C response',
	'C+D post',
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Data Read Sequence (DR-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_DR_cycle`,
  `gba_request_DR_cycle`,
  `memory_respond_DR_cycle`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 2 clock cycles]

A Data Read Sequence is an external sequence where a read operation is requested by the GBA Core.

#figure(caption: [Data Read Sequence timing diagram], wavy.render(height: 33%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1.x...', phase: 0},
    {name:'RW',  wave:'x1.x..', phase: 0},
    {name:'A',   wave:'x.5.x.', phase: 0},
    {name:'BL',   wave:'x.5.x.', phase: 0},
    {name:'WAIT', wave:'x.8.x.', phase: 0},
    {name:'ABORT',wave:'x..8x.', phase: 0},
    {name:'DIN', wave:'x.z8x.', phase: 0},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C response',
	'C+D post',
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Halfword-Wide Memory Sequence]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_halfword_memory_sequence`,
  `gba_request_halfword_memory_sequence`,
  `memory_respond_halfword_memory_sequence`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

The Halfword-Wide Memory Sequence is the same as the basic Memory Sequence, except for memory with a 16-bit wide bus, thus requiring 2 cycles per word.

#figure(caption: [Halfword-Wide Read Memory Sequence timing diagram], wavy.render(height: 36%, "{
  signal:
  [
    {name:'MCLK',      wave:'hlhlhlhl'},
    {name:'MREQ',      wave:'x5.x....', phase: 0},
    {name:'SEQ',       wave:'x5.x....', phase: 0},
    {name:'RW',        wave:'x.1...x.', phase: 0},
    {name:'A',         wave:'x..5...x', phase: 0},
    {name:'BL',        wave:'x..5.5.x', phase: 0},
    {name:'WAIT',      wave:'x0.1.0.x', phase: 0},
    {name:'DIN[0:15]', wave:'x..z8z.x', phase: 0},
    {name:'DIN[16:31]',wave:'x..z..8x', phase: 0},
    {node:'.A.B.C.D.E.', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C response 0',
	'C+D response 1'
  ],
  head:{ tick:0, every:1 }
}"))
#figure(caption: [Halfword-Wide Write Memory Sequence timing diagram], wavy.render(height: 36%, "{
  signal:
  [
    {name:'MCLK',       wave:'hlhlhlhl'},
    {name:'MREQ',       wave:'x5.x....', phase: 0},
    {name:'SEQ',        wave:'x5.x....', phase: 0},
    {name:'RW',         wave:'x.0...x.', phase: 0},
    {name:'A',          wave:'x..5...x', phase: 0},
    {name:'BL',         wave:'x..5.5.x', phase: 0},
    {name:'WAIT',       wave:'x0.1.0.x', phase: 0},
    {name:'DOUT[0:15]', wave:'x..8.z.x', phase: 0},
    {name:'DOUT[16:31]',wave:'x..z.8.x', phase: 0},
    {node:'.A.B.C.D.E.', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C response 0',
	'C+D response 1'
  ],
  head:{ tick:0, every:1 }
}"))

\

#pagebreak()
== #smallcaps[Byte-Wide Memory Sequence]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_byte_memory_sequence`,
  `gba_request_byte_memory_sequence`,
  `memory_respond_byte_memory_sequence`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `A`, `DOUT`], [`WAIT`, `ABORT`, `DIN`])

The Byte-Wide Memory Sequence is the same as the basic Memory Sequence, except for memory with an 8-bit wide bus, thus requiring 4 cycles per word.

#figure(caption: [Byte-Wide Read Memory Sequence timing diagram], wavy.render(height: 39%, "{
  signal:
  [
    {name:'MCLK',      wave:'hlhlhlhlhlhl'},
    {name:'MREQ',      wave:'x5.x........', phase: 0},
    {name:'RW',        wave:'x.1.......x.', phase: 0},
    {name:'A',         wave:'x..5.......x', phase: 0},
    {name:'WAIT',      wave:'x0.1.....0.x', phase: 0},
    {name:'DIN[0:7]',  wave:'x..z8z.....x', phase: 0},
    {name:'DIN[8:15]', wave:'x..z..8z...x', phase: 0},
    {name:'DIN[16:23]',wave:'x..z....8z.x', phase: 0},
    {name:'DIN[24:31]',wave:'x..z......8x', phase: 0},
    {name:'BL',        wave:'x..5.5.5.5.x', phase: 0},
    {node:'.A.B.C.D.E.F.', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C response 1',
	'C+D response 3',
	'D+E response 3',
	'E+F response 4'
  ],
  head:{ tick:0, every:1 }
}"))
#figure(caption: [Byte-Wide Write Memory Sequence timing diagram], wavy.render(height: 39%, "{
  signal:
  [
    {name:'MCLK',       wave:'hlhlhlhlhlhl'},
    {name:'MREQ',       wave:'x5.x........', phase: 0},
    {name:'RW',         wave:'x.0.......x.', phase: 0},
    {name:'A',          wave:'x..5.......x', phase: 0},
    {name:'WAIT',       wave:'x0.1.....0.x', phase: 0},
    {name:'DOUT[0:7]',  wave:'x..8.z.....x', phase: 0},
    {name:'DOUT[8:15]', wave:'x..z.8.z...x', phase: 0},
    {name:'DOUT[16:23]',wave:'x..z...8.z.x', phase: 0},
    {name:'DOUT[24:31]',wave:'x..z.....8.x', phase: 0},
    {name:'BL',         wave:'x..5.5.5.5.x', phase: 0},
    {node:'.A.B.C.D.E.F.', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C response 1',
	'C+D response 3',
	'D+E response 3',
	'E+F response 4'
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Reset Sequence (RS-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_RS_cycle`,
  `gba_initiate_RS_cycle`)

#table(
  columns: (50%, 50%),
  table.header([*Request Signals*], [*Response Signals*]),
  [`MREQ`, `SEQ`, `RW`, `EXEC`, `OPC`, `A`], [`WAIT`, `ABORT`, `DIN`])

#table(columns: (100%))[ #smallcaps[*Duration:*] 5 clock cycles]

#figure(caption: [Reset Sequence timing diagram], wavy.render(height: 28%, "{
  signal:
  [
    {name:'MCLK',  wave:'lhlhlhl'},
    {name:'RESET', wave:'1.0....', phase: 0},
    {name:'A',     wave:'x.5.5.5', data: ['x', 'y', 'z'], phase: 0},
    {name:'DIN',   wave:'z8z8z8z', phase: 0},
    {name:'MREQ',  wave:'0.....1', phase: 0},
    {name:'SEQ',   wave:'0......', phase: 0},
    {name:'EXEC',  wave:'0.....1', phase: 0},
    {              node:'A.B.C.DE', phase: 0.15},
  ],
  edge: [
	'A+B reset',
	'B+C internal 1',
	'C+D internal 2',
	'D+E request',
  ],
  head:{ tick:0, every:1 }
}"))
#figure(caption: [Reset Sequence timing diagram (continued)], wavy.render(height: 28%, "{
  signal:
  [
    {name:'MCLK',  wave:'hlhlhlh'},
    {name:'RESET', wave:'0......', phase: 0},
    {name:'A',     wave:'55.5.5.', data: ['z', '0', '4', '8'], phase: 0},
    {name:'DIN',     wave:'8z8z8z8', data: ['', '(0)', '(4)', '(8)'], phase: 0},
    {name:'MREQ',  wave:'1......', phase: 0},
    {name:'SEQ',   wave:'01.....', phase: 0},
    {name:'EXEC',  wave:'1......', phase: 0},
    {              node:'AB.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B request',
	'B+C fetch',
	'C+D decode',
	'D+E execute'
  ],
  head:{ tick:7, every:1 }
}"))
\

#pagebreak()
== #smallcaps[General Timing]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_general_timing`)

#table(
  columns: (50%, 50%),
  table.header([*Phase 1 Signals*], [*Phase 2 Signals*]),
  [`MREQ`, `SEQ`, `EXEC`, `EXEC`, `INSTRVALID`, `A`, `BIGEND`, `ISYNC`], [`RW`, `MAS`, `LOCK`, `M`, `TBIT`, `OPC`, `ISYNC`])

The General Timing diagram defines in which phase of the cycle each of the control signals is allowed to change.

#figure(caption: [General timing diagram], wavy.render(height: 52%, "{
  signal:
  [
    {name:'MCLK',       wave:'hlhl'},
    {name:'MREQ',       wave:'55..', phase: 0},
    {name:'SEQ',        wave:'55..', phase: 0},
    {name:'EXEC',       wave:'55..', phase: 0},
    {name:'INSTRVALID', wave:'55..', phase: 0},
    {name:'A',          wave:'55..', phase: 0},
    {name:'BIGEND',     wave:'55..', phase: 0},
    {name:'RW',         wave:'5.5.', phase: 0},
    {name:'MAS',        wave:'5.5.', phase: 0},
    {name:'LOCK',       wave:'5.5.', phase: 0},
    {name:'M',          wave:'5.5.', phase: 0},
    {name:'TBIT',       wave:'5.5.', phase: 0},
    {name:'OPC',        wave:'5.5.', phase: 0},
    {name:'ISYNC',      wave:'555.', phase: 0},
    {                   node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B cycle',
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Address Bus Control]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_address_bus_control`)

#table(
  columns: (100%),
  table.header([*Signals*]),
  [`ABE`, `A`, `RW`, `LOCK`, `OPC`, `MAS`])

#figure(caption: [Address Bus Control timing diagram], wavy.render(height: 15%, "{
  signal:
  [
    {name:'MCLK',              wave:'hlhl'},
    {name:'ABE',               wave:'10..', node:'.M..', phase: 0},
    {name:'A/RW/LOCK/OPC/MAS', wave:'5z..', node:'.N..', phase: 0},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B cycle',
	'M->N',
  ],
  head:{ tick:0, every:1 }
}"))

#figure(caption: [Address Bus Control timing diagram], wavy.render(height: 15%, "{
  signal:
  [
    {name:'MCLK',              wave:'hlhl'},
    {name:'ABE',               wave:'01..', node:'.M..', phase: 0},
    {name:'A/RW/LOCK/OPC/MAS', wave:'z5..', node:'.N..', phase: 0},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B cycle',
	'M->N',
  ],
  head:{ tick:0, every:1 }
}"))

- `ABE` may change during phase 1.
- `A`, `RW`, `LOCK`, `OPC`, and `MAS` are enabled/disabled immediately when `ABE` switches to high/low.
- `A`, `RW`, `LOCK`, `OPC`, and `MAS` must be stable at the starts of both phases.
\

#pagebreak()
== #smallcaps[Data Bus Control]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_data_bus_control`)

#table(
  columns: (100%),
  table.header([*Signals*]),
  [`DBE`, `DIN`, `DOUT`])

#figure(caption: [Data Bus Control timing diagram], wavy.render(height: 15%, "{
  signal:
  [
    {name:'MCLK',     wave:'hlhl'},
    {name:'DBE',      wave:'10..',  phase: 0, node:'.M..'},
    {name:'DIN/DOUT', wave:'8z..',  phase: 0, node:'..Q.'},
    {                 node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B cycle',
	'M->N',
	'P->Q'
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[Exception Control]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_exception_control`)

#table(
  columns: (100%),
  table.header([*Signals*]),
  [`ABORT`, `FIQ`, `IRQ`, `RESET`])

The exceptional behaviors are: (1) aborted memory access, (2) interrupt, (3) fast interrupt, (4) reset.

#figure(caption: [Exception Control timing diagram], wavy.render(height: 19%, "{
  signal:
  [
    {name:'MCLK',     wave:'hlhl'},
    {name:'ABORT',    wave:'0.10', node:'.M..', phase: 0},
    {name:'FIQ, IRQ', wave:'0.=1', phase: 0},
    {name:'RESET',    wave:'1=0.', phase: 0},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B cycle'
  ],
  head:{ tick:0, every:1 }
}"))

/ 1.: `FIQ` and `IRQ` signals must be set one cycle ahead of the cycle in which they'll be handled, during the high phase, and they must remain stable through the start of the low phase of the next cycle.

\

#pagebreak()
== #smallcaps[Address Pipeline Control]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_address_pipeline_control`)

#table(
  columns: (100%),
  table.header([*Signals*]),
  [`APE`, `A`, `RW`, `LOCK`, `OPC`, `MAS`])

#figure(caption: [Address Pipeline Control timing diagram], wavy.render(height: 16%, "{
  signal:
  [
    {name:'MCLK',                  wave:'hlhl'},
    {name:'APE',                   wave:'=0..',  phase: 0},
    {name:'A, RW, LOCK, OPC, MAS', wave:'5..5',  phase: 0},
    {                              node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B cycle'
  ],
  head:{ tick:0, every:1 }
}"))
\

#pagebreak()
== #smallcaps[General Instruction Cycle]

#figure(caption: [General Instruction Cycle timing diagram], wavy.render(height: 22%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'x.0.x.', phase: 0},
    {name:'SEQ',wave:'x.0.x.', phase: 0},
    {name:'A',wave:'x.....', phase: 0},
    {name:'DIN/DOUT',wave:'z.....', phase: 0},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C cycle',
	'C+D post',
  ],
  head:{ tick:0, every:1 }
}"))

/ 1.: There are two types of request signals: request type signals and request address signals, which are broadcast at least one tick ahead of the response cycle.
/ 2.: The request type signals (`MREQ` and `SEQ`) are pipelined up to 2 ticks ahead of the cycle to which they apply.
/ 3.: The request address signals (`A`, `MAS`, `RW`, `OPC`, and `TBIT`) are pipelined up to 1 tick ahead of the cycle to which they apply.
/ 4.: The instruction cycle is the response cycle.
/ 5.: When `OPC` is high, the address is incremented each cycle (epistemic status: _guess_).
\

#pagebreak()
== #smallcaps[Branch and Branch with Link Instruction Cycle (BABLI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`B`, `BL`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_BABLI_cycle`,
  [`gba_request_BABLI_cycle`],
  `memory_respond_BABLI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $3$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `alu`, [The instruction operand---ie, the address to jump to.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.])

#figure(caption: [Branch and Branch with Link Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1...', phase: 0},
    {name:'SEQ', wave:'0.1.', phase: 0},
    {name:'OPC', wave:'1...', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc+ 2L', 'alu']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', 'i']},
    {name:'DIN', wave:'z8z8', phase: 0, data: ['(pc + 2L)', '(alu)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
  ],
  head:{ tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Branch and Branch with Link Instruction Cycle (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'1.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['alu + L', 'alu + 2L']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z8x.', phase: 0, data: ['(alu + L)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C post',
  ],
  head:{ tick:4, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Thumb Branch with Link Instruction Cycle (TBLI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_TBLI_cycle`,
  `gba_request_TBLI_cycle`,
  `memory_respond_TBLI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $4$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `alu`, [The instruction operand---ie, the address to jump to.])

#figure(caption: [Thumb Branch with Link Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'1....', phase: 0},
    {name:'SEQ', wave:'1.0.1', phase: 0},
    {name:'OPC', wave:'1....', phase: 0},
    {name:'RW',  wave:'1....', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc+4', 'pc+6', 'alu']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['1', '1', '1']},
    {name:'DIN', wave:'z8z8z', phase: 0, data: ['(pc+4)', '(pc+6)']},
    {node:'A.B.CD', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Thumb Branch with Link Instruction Cycle (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlx'},
    {name:'MREQ',wave:'1..x.', phase: 0},
    {name:'SEQ', wave:'1..x.', phase: 0},
    {name:'OPC', wave:'1..x.', phase: 0},
    {name:'RW',  wave:'1..x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['alu', 'alu+2', 'alu+4']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['1', '1']},
    {name:'DIN', wave:'8z8x.', phase: 0, data: ['(alu)', '(alu+2)']},
    {node:'AB.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C cycle 4',
	'C+D post',
  ],
  head:{ tick:5, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Branch and Exchange Instruction Cycle (BAEI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`BX`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_BAEI_cycle`,
  `gba_request_BAEI_cycle`,
  `memory_respond_BAEI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $3$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `alu`, [The instruction operand---ie, the address to jump to.],
  `I`, [MAS before executing the instruction.],
  `i`, [MAS after executing the instruction.],
  `W`, [Instruction width before executing the instruction.],
  `w`, [Instruction width after executing the instruction.],
  `T`, [TBIT before executing the instruction.],
  `t`, [TBIT after executing the instruction.])

#figure(caption: [Branch and Exchange Instruction Cycle], wavy.render(height: 36%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1...', phase: 0},
    {name:'SEQ', wave:'0.1.', phase: 0},
    {name:'OPC', wave:'1...', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'TBIT',wave:'5.5.', phase: 0, data: ['T', 't']},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2W', 'alu']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['I', 'i']},
    {name:'DIN', wave:'z8z8', phase: 0, data: ['(pc+ 2W)', '(alu)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
  ],
  head:{ tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Branch and Exchange Instruction Cycle (continued)], wavy.render(height: 36%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'1.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'TBIT',wave:'5.x.', phase: 0, data: ['t']},
    {name:'A',   wave:'5.5.', phase: 0, data: ['alu + w', 'alu + 2w']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z8x.', phase: 0, data: ['(alu + w)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C post',
  ],
  head:{ tick:4, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Data Processing Instruction Cycle (DPI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`ADC`, `ADD`, `AND`, `BIC`, `CMN`, `CMP`, `EOR`, `MOV`, `MRS`, `MSR`, `MVN`, `ORR`, `RSB`, `RSC`, `SBC`, `SUB`, `TEQ`, `TST`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_DPI_cycle`,
  `gba_request_DPI_cycle`,
  `memory_respond_DPI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $1$ to $4$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `alu`, [The instruction operand---ie, the address of the shifter operand.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.])

#figure(caption: [Data Processing Instruction Cycle (normal)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0.0},
    {name:'SEQ', wave:'1.x.', phase: 0.0},
    {name:'OPC', wave:'1.x.', phase: 0.0},
    {name:'RW',  wave:'1.x.', phase: 0.0},
    {name:'A',   wave:'5.5.', phase: 0.0, data: ['pc + 2L', 'pc + 3L']},
    {name:'MAS', wave:'5.x.', phase: 0.0, data: ['i']},
    {name:'DIN', wave:'z8x.', phase: 0.0, data: ['(pc + 2L)']},
    {node:'A.B.C.D.', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Data Processing Instruction Cycle (dest=pc)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1...', phase: 0},
    {name:'SEQ', wave:'0.1.', phase: 0},
    {name:'OPC', wave:'1...', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2L', 'alu']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', 'i']},
    {name:'DIN', wave:'z8z8', phase: 0, data: ['(pc+ 2L)', '(alu)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Data Processing Instruction Cycle (dest=pc) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'1.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['alu + L', 'alu + 2L']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z8x.', phase: 0, data: ['(alu + L)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Data Processing Instruction Cycle (shift(RS))], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'0.1.x.', phase: 0},
    {name:'SEQ', wave:'0.1.x.', phase: 0},
    {name:'OPC', wave:'1.0.x.', phase: 0},
    {name:'RW',  wave:'1...x.', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc + 2L', 'pc + 3L', 'pc + 3L']},
    {name:'MAS', wave:'5.5.x.', phase: 0, data: ['i', 'i']},
    {name:'DIN', wave:'z8z.x.', phase: 0, data: ['(pc+ 2L)']},
    {node:'A.B.C.D.', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))

#figure(caption: [Data Processing Instruction Cycle (shift(Rs) dest=pc)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'0.1..', phase: 0},
    {name:'SEQ', wave:'0...1', phase: 0},
    {name:'OPC', wave:'1.0.1', phase: 0},
    {name:'RW',  wave:'1....', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc + 8', 'pc + 12', 'alu']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['2', '2', '2']},
    {name:'DIN', wave:'z8z..', phase: 0, data: ['(pc + 8)']},
    {node:'A.B.CD', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Data Processing Instruction Cycle (shift(Rs) dest=pc) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlh'},
    {name:'MREQ',wave:'1..x.', phase: 0},
    {name:'SEQ', wave:'1..x.', phase: 0},
    {name:'OPC', wave:'1..x.', phase: 0},
    {name:'RW',  wave:'1..x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['alu', 'alu + 4', 'alu + 8']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['2', '2']},
    {name:'DIN', wave:'8z8x.', phase: 0, data: ['(alu)', '(alu + 4)']},
    {node:'AB.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C cycle 4',
	'C+D post',
  ],
  head:{ text:'', tick:5, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Multiply and Multiply Accumulate Instruction Cycle (MAMAI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`MLA`, `MUL`, `SMLAL`, `SMULL`, `UMLAL`, `UMULL`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_MAMAI_cycle`,
  `gba_request_MAMAI_cycle`,
  `memory_respond_MAMAI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $3$ to $4$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.])

#figure(caption: [Multiply Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'0...', phase: 0},
    {name:'SEQ', wave:'0...', phase: 0},
    {name:'OPC', wave:'1.0.', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2L', 'pc + 3L']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', 'i']},
    {name:'DIN', wave:'z8z.', phase: 0, data: ['(pc+ 2L)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2 ... m',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Multiply Instruction Cycle (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'0.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 3L', 'pc + 3L']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z.x.', phase: 0},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle m + 1',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))

#figure(caption: [Multiply Accumulate Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'0....', phase: 0},
    {name:'SEQ', wave:'0....', phase: 0},
    {name:'OPC', wave:'1.0..', phase: 0},
    {name:'RW',  wave:'1....', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc + 8', 'pc + 8', 'pc + 12']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['2', '2', '2']},
    {name:'DIN', wave:'z8z..', phase: 0, data: ['(pc + 8)']},
    {node:'A.B.CD', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3 ... m + 1',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Multiply Accumulate Instruction Cycle (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlh'},
    {name:'MREQ',wave:'01.x.', phase: 0},
    {name:'SEQ', wave:'01.x.', phase: 0},
    {name:'OPC', wave:'0..x.', phase: 0},
    {name:'RW',  wave:'1..x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['pc + 12', 'pc + 12', 'pc + 12']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['2', '2']},
    {name:'DIN', wave:'z..x.', phase: 0},
    {node:'AB.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3 ... m + 1',
	'B+C cycle m + 2',
	'C+D post',
  ],
  head:{ text:'', tick:5, every:1 },
  config: { hscale: 2 }
}"))

#figure(caption: [Multiply Long Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'0...', phase: 0},
    {name:'SEQ', wave:'0...', phase: 0},
    {name:'OPC', wave:'1.0.', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 8', 'pc + 12']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', 'i']},
    {name:'DIN', wave:'z8z.', phase: 0, data: ['(pc+ 8)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2 ... m + 1',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Multiply Long Instruction Cycle (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'0.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 12', 'pc + 12']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z.x.', phase: 0},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle m + 2',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))

#figure(caption: [Multiply Accumlate Long Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'0....', phase: 0},
    {name:'SEQ', wave:'0....', phase: 0},
    {name:'OPC', wave:'1.0..', phase: 0},
    {name:'RW',  wave:'1....', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc + 8', 'pc + 8', 'pc + 12']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['2', '2', '2']},
    {name:'DIN', wave:'z8z..', phase: 0, data: ['(pc + 8)']},
    {node:'A.B.CD', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3 ... m + 2',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Multiply Accumulate Long Instruction Cycle (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlh'},
    {name:'MREQ',wave:'01.x.', phase: 0},
    {name:'SEQ', wave:'01.x.', phase: 0},
    {name:'OPC', wave:'0..x.', phase: 0},
    {name:'RW',  wave:'1..x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['pc + 12', 'pc + 12', 'pc + 12']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['2', '2']},
    {name:'DIN', wave:'z..x.', phase: 0},
    {node:'AB.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3 ... m + 2',
	'B+C cycle m + 3',
	'C+D post',
  ],
  head:{ text:'', tick:5, every:1 },
  config: { hscale: 2 }
}"))
\

#pagebreak()
== #smallcaps[Load Register Instruction Cycle (LRI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`LDR`, `LDRB`, `LDRBT`, `LDRH`, `LDRSB`, `LDRSH`, `LDRT`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_LRI_cycle`,
  `gba_request_LRI_cycle`,
  `memory_respond_LRI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $3$ to $5$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `alu`, [The instruction operand---ie, the first source address.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.],
  `s`, [MAS variable (`BYTE`, `HALFWORD`, or `WORD`).])

#figure(caption: [Load Register Instruction Cycle (normal)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.0.', phase: 0},
    {name:'SEQ', wave:'0...', phase: 0},
    {name:'OPC', wave:'1.0.', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2L', 'alu']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', 's']},
    {name:'DIN', wave:'z8z8', phase: 0, data: ['(pc+ 2L)', '(alu)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Register Instruction Cycle (normal) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'0.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 3L', 'pc + 3L']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z.x.', phase: 0},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))


#figure(caption: [Load Register Instruction Cycle (dest=pc)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1.0.1.', phase: 0},
    {name:'SEQ', wave:'0.....', phase: 0},
    {name:'OPC', wave:'1.0...', phase: 0},
    {name:'RW',  wave:'1.....', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc + 8', 'alu', 'pc + 12']},
    {name:'MAS', wave:'5.x.5.', phase: 0, data: ['2', '2']},
    {name:'DIN', wave:'z8z8z.', phase: 0, data: ['(pc+8)', '(pc\')']},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Register Instruction Cycle (dest=pc) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1...x.', phase: 0},
    {name:'SEQ', wave:'1...x.', phase: 0},
    {name:'OPC', wave:'1...x.', phase: 0},
    {name:'RW',  wave:'1...x.', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc\'', 'pc\' + 4', 'pc\' + 8']},
    {name:'MAS', wave:'5.5.x.', phase: 0, data: ['2', '2']},
    {name:'DIN', wave:'z8z8x.', phase: 0, data: ['(pc\')', '(pc\'+4)']},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 4',
	'B+C cycle 5',
	'C+D post',
  ],
  head:{ text:'', tick:6, every:1 },
  config: { hscale: 2 }
}"))
\

#pagebreak()
== #smallcaps[Store Register Instruction Cycle (SRI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`STR`, `STRB`, `STRBT`, `STRH`, `STRT`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_SRI_cycle`,
  `gba_request_SRI_cycle`,
  `memory_respond_SRI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $2$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `alu`, [The instruction operand---ie, the first target address.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.],
  `s`, [MAS variable (`BYTE`, `HALFWORD`, or `WORD`).])

#figure(caption: [Store Register Instruction Cycle], wavy.render(height: 36%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1...x.', phase: 0},
    {name:'SEQ', wave:'0...x.', phase: 0},
    {name:'OPC', wave:'1.0.x.', phase: 0},
    {name:'RW',  wave:'1.0.x.', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc + 2L', 'alu', 'pc + 3L']},
    {name:'MAS', wave:'5.5.x.', phase: 0, data: ['i', 's']},
    {name:'DIN', wave:'z8z...', phase: 0, data: ['(pc+ 2L)']},
    {name:'DOUT', wave:'z.8.x.', phase: 0, data: ['Rd']},    {node:'A.B.C.D.', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D post',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
\

#pagebreak()
== #smallcaps[Load Multiple Register Instruction Cycle (LMRI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`LDM`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_LMRI_cycle`,
  `gba_request_LMRI_cycle`,
  `memory_respond_LMRI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $3$ to $6$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `alu`, [The instruction operand---ie, the first source address.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.],
  `s`, [MAS variable (`BYTE`, `HALFWORD`, or `WORD`).])

#figure(caption: [Load Multiple Register Instruction Cycle (single register)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.0.', phase: 0},
    {name:'SEQ', wave:'0...', phase: 0},
    {name:'OPC', wave:'1.0.', phase: 0},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2L', 'alu']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', '2']},
    {name:'DIN', wave:'z8z8', phase: 0, data: ['(pc+ 2L)', '(alu)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Multiple Register Instruction Cycle (single register) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'0.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 3L', 'pc + 3L']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z.x.', phase: 0},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Multiple Register Instruction Cycle (single regiser dest=pc)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1.0.1.', phase: 0},
    {name:'SEQ', wave:'0.....', phase: 0},
    {name:'OPC', wave:'1.0...', phase: 0},
    {name:'RW',  wave:'1.....', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc + 2L', 'alu', 'pc + 3L']},
    {name:'MAS', wave:'5.5.5.', phase: 0, data: ['i', '2', 'i']},
    {name:'DIN', wave:'z8z8z.', phase: 0, data: ['(pc + 2L)', 'pc\'']},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Multiple Register Instruction Cycle (single register dest=pc) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1...x.', phase: 0},
    {name:'SEQ', wave:'1...x.', phase: 0},
    {name:'OPC', wave:'1...x.', phase: 0},
    {name:'RW',  wave:'1...x.', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc\'', 'pc\' + L', 'pc\' + 2L']},
    {name:'MAS', wave:'5.5.x.', phase: 0, data: ['i', 'i']},
    {name:'DIN', wave:'z8z8x.', phase: 0, data: ['(pc\')', '(pc\' + L)']},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 4',
	'B+C cycle 5',
	'C+D post',
  ],
  head:{ text:'', tick:6, every:1 },
  config: { hscale: 2 }
}"))

#figure(caption: [Load Multiple Register Instruction Cycle (n registers)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'1...0', phase: 0},
    {name:'SEQ', wave:'0.1.0', phase: 0},
    {name:'OPC', wave:'1.0..', phase: 0},
    {name:'RW',  wave:'1....', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc + 2L', 'alu + 4 (k - 2)', 'alu + 4 n']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['i', '2', '2']},
    {name:'DIN', wave:'z8z8z', phase: 0, data: ['(pc + 2L)', '(alu+4(k-2))']},
    {node:'A.B.CD', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle k (2 ... n)',
	'C+D cycle n + 1',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Multiple Register Instruction Cycle (n registers) (continued)], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlh'},
    {name:'MREQ',wave:'01.x.', phase: 0},
    {name:'SEQ', wave:'01.x.', phase: 0},
    {name:'OPC', wave:'0..x.', phase: 0},
    {name:'RW',  wave:'1..x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['alu + 4 n', 'pc + 3L', 'pc + 3L']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['2', 'i']},
    {name:'DIN', wave:'8z.x.', phase: 0, data: ['(alu+4n)']},
    {node:'AB.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle n + 1',
	'B+C cycle n + 2',
	'C+D post',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Multiple Register Instruction Cycle (n registers including pc)], wavy.render(height: 30%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhl'},
    {name:'MREQ',wave:'1...0.1', phase: 0},
    {name:'SEQ', wave:'0.1.0..', phase: 0},
    {name:'OPC', wave:'1.0....', phase: 0},
    {name:'RW',  wave:'1......', phase: 0},
    {name:'A',   wave:'5.5.5.5', phase: 0, data: ['pc + 2L', 'alu + 4(k - 2)', 'alu + 4 n', 'pc + 3L']},
    {name:'MAS', wave:'5.5.5.5', phase: 0, data: ['i', '2', '2', 'i']},
    {name:'DIN', wave:'z8z8z8z', phase: 0, data: ['(pc + 2L)', '(alu + 4(k - 2))', 'pc\'']},
    {node:'A.B.C.DE', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle k (2 ... n)',
	'C+D cycle n + 1',
	'D+E cycle n + 2',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Load Multiple Register Instruction Cycle (n registers including pc) (continued)], wavy.render(height: 30%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlhlh'},
    {name:'MREQ',wave:'1....x.', phase: 0},
    {name:'SEQ', wave:'01...x.', phase: 0},
    {name:'OPC', wave:'01...x.', phase: 0},
    {name:'RW',  wave:'1....x.', phase: 0},
    {name:'A',   wave:'55.5.x.', phase: 0, data: ['pc\'', 'pc\' + L', 'pc\' + 2L']},
    {name:'MAS', wave:'55.5.x.', phase: 0, data: ['i', 'i', 'i']},
    {name:'DIN', wave:'zz8z8x.', phase: 0, data: ['(pc\')', '(pc\' + L)']},
    {node:'AB.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B cycle n + 2',
	'B+C cycle n + 3',
	'C+D cycle n + 4',
	'D+E post',
  ],
  head:{ text:'', tick:7, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Store Multiple Register Instruction Cycle (SMRI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`STM`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_SMRI_cycle`,
  `gba_request_SMRI_cycle`,
  `memory_respond_SMRI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $2$ to $3$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `alu`, [The instruction operand---ie, the first target address.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.],
  `s`, [MAS variable (`BYTE`, `HALFWORD`, or `WORD`).],
  `R[k]`, [The value in the $k$-th register.])

#figure(caption: [Store Multiple Register Instruction Cycle (single register)], wavy.render(height: 35%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'MREQ',wave:'1...x.', phase: 0},
    {name:'SEQ', wave:'0...x.', phase: 0},
    {name:'OPC', wave:'1.0.x.', phase: 0},
    {name:'RW',  wave:'1.0.x.', phase: 0},
    {name:'A',   wave:'5.5.5.', phase: 0, data: ['pc + 2L', 'alu', 'pc + 3L']},
    {name:'MAS', wave:'5.5.x.', phase: 0, data: ['i', '2']},
    {name:'DIN', wave:'z8z...', phase: 0, data: ['(pc+ 2L)']},
    {name:'DOUT', wave:'z.8.x.', phase: 0, data: ['Ra']},
    {node:'A.B.C.D.', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D post',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Store Multiple Register Instruction Cycle (n registers)], wavy.render(height: 35%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1...', phase: 0},
    {name:'SEQ', wave:'0.1.', phase: 0},
    {name:'OPC', wave:'1.0.', phase: 0},
    {name:'RW',  wave:'1.0.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 8', 'alu + 4(k - 2)']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', '2']},
    {name:'DIN', wave:'z8z.', phase: 0, data: ['(pc+ 2L)', 'R[k-2]']},
    {name:'DOUT', wave:'z.8.', phase: 0, data: ['R[k-2]']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle k (2 ... n)',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Store Multiple Register Instruction Cycle (n registers) (continued)], wavy.render(height: 35%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'0.x.', phase: 0},
    {name:'OPC', wave:'0.x.', phase: 0},
    {name:'RW',  wave:'0.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['alu + 4 n', 'pc + 12']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['2']},
    {name:'DIN', wave:'z...', phase: 0},
    {name:'DOUT', wave:'8.x.', phase: 0, data: ['R[k-2]']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle n + 1',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Data Swap Instruction Cycle (DSI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`SWP`, `SWPB`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_DSI_cycle`,
  `gba_request_DSI_cycle`,
  `memory_respond_DSI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $4$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `alu`, [The instruction operand---ie, the first target address.],
  `s`, [MAS variable (`BYTE` or `WORD`).],
  `R[k]`, [The value in the $k$-th register.])

#figure(caption: [Data Swap Instruction Cycle], wavy.render(height: 39%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'1...0', phase: 0},
    {name:'SEQ', wave:'0....', phase: 0},
    {name:'OPC', wave:'1.0..', phase: 0},
    {name:'RW',  wave:'1...0', phase: 0},
    {name:'LOCK',wave:'0.1..', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc + 8', 'R[n]', 'R[n]']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['2', 's', 's']},
    {name:'DIN', wave:'z8z8z', phase: 0, data: ['(pc + 8)', '(R[n])']},
    {name:'DOUT', wave:'z...8', phase: 0, data: ['R[m]']},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Data Swap Instruction Cycle (continued)], wavy.render(height: 39%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlh'},
    {name:'MREQ',wave:'01.x.', phase: 0},
    {name:'SEQ', wave:'01.x.', phase: 0},
    {name:'OPC', wave:'0..x.', phase: 0},
    {name:'RW',  wave:'01.x.', phase: 0},
    {name:'LOCK',wave:'10.x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['R[n]', 'pc + 12', 'pc + 12']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['s', '2']},
    {name:'DIN', wave:'z..x.', phase: 0},
    {name:'DOUT', wave:'8z.x.', phase: 0, data: ['R[m]']},
    {node:'A.B.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C cycle 4',
	'C+D post',
  ],
  head:{ text:'', tick:5, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Software Interrupt and Exception Instruction Cycle (SIAEI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Instructions*]),
  [`SWI`])

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_SIAEI_cycle`,
  `gba_request_SIAEI_cycle`,
  `memory_respond_SIAEI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $3$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `old`, [The processor mode, before executing the instruction],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.],
  `T`, [TBIT, before executing the instruction.],
  `Xn`, [The exception address.])

#figure(caption: [Software Interrupt and Exception Instruction Cycle], wavy.render(height: 41%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1...', phase: 0},
    {name:'SEQ', wave:'0.1.', phase: 0},
    {name:'OPC', wave:'1...', phase: 0},
    {name:'TBIT',wave:'5.5.', phase: 0, data: ['T', '0']},
    {name:'M',   wave:'5.5.', phase: 0, data: ['old', 'exception']},
    {name:'RW',  wave:'1...', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2L', 'Xn']},
    {name:'MAS', wave:'5.5.', phase: 0, data: ['i', '2']},
    {name:'DIN', wave:'z8z8', phase: 0, data: ['(pc + 2L)', '(Xn)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Software Interrupt and Exception Instruction Cycle (continued)], wavy.render(height: 41%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'1.x.', phase: 0},
    {name:'OPC', wave:'1.x.', phase: 0},
    {name:'TBIT',wave:'5.x.', phase: 0, data: ['0']},
    {name:'M',   wave:'5.x.', phase: 0, data: ['exception']},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['Xn + 4', 'Xn + 8']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['2']},
    {name:'DIN', wave:'z8x.', phase: 0, data: ['(Xn + 4)']},
    {node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C post',
  ],
  head:{ text:'', tick:4, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Undefined Instruction Cycle (UDI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_UDI_cycle`,
  `gba_request_UDI_cycle`,
  `memory_respond_UDI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $4$ clock cycles]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `old`, [The processor mode, before executing the instruction],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.],
  `T`, [TBIT, before executing the instruction.],
  `Xn`, [The exception address.])

#figure(caption: [Undefined Instruction Cycle], wavy.render(height: 35%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhl'},
    {name:'MREQ',wave:'0.1..', phase: 0},
    {name:'SEQ', wave:'0...1', phase: 0},
    {name:'OPC', wave:'1....', phase: 0},
    {name:'TBIT',wave:'5.5.5', phase: 0, data: ['T', 'T', '0', '0']},
    {name:'M',wave:'5.5.5', phase: 0, data: ['old', 'old', '00100']},
    {name:'RW',  wave:'1....', phase: 0},
    {name:'A',   wave:'5.5.5', phase: 0, data: ['pc + 2L', 'pc + 2L', 'Xn']},
    {name:'MAS', wave:'5.5.5', phase: 0, data: ['i', 'i', '2']},
    {name:'DIN', wave:'z8z.z', phase: 0, data: ['(pc + 2L)']},
    {node:'A.B.CD', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C cycle 2',
	'C+D cycle 3',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
#figure(caption: [Undefined Instruction Cycle (continued)], wavy.render(height: 35%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlh'},
    {name:'MREQ',wave:'1..x.', phase: 0},
    {name:'SEQ', wave:'1..x.', phase: 0},
    {name:'OPC', wave:'1..x.', phase: 0},
    {name:'TBIT',wave:'55.x.', phase: 0, data: ['0', '0']},
    {name:'M',wave:'55.x.', phase: 0, data: ['00100', '00100']},
    {name:'RW',  wave:'1..x.', phase: 0},
    {name:'A',   wave:'55.5.', phase: 0, data: ['Xn', 'Xn + 4', 'Xn + 8']},
    {name:'MAS', wave:'55.x.', phase: 0, data: ['2', '2']},
    {name:'DIN', wave:'8z8x.', phase: 0, data: ['(Xn)', '(Xn + 4)']},
    {node:'AB.C.D', phase: 0.15},
  ],
  edge: [
	'A+B cycle 3',
	'B+C cycle 4',
	'C+D post',
  ],
  head:{ text:'', tick:5, every:1 },
  config: { hscale: 2 }
}"))

#pagebreak()
== #smallcaps[Unexecuted Instruction Cycle (UEI-Cycle)]

#table(
  columns: (100%),
  table.header([*Related Procedures*]),
  `test_UEI_cycle`,
  `gba_request_UEI_cycle`,
  `memory_respond_UEI_cycle`)

#table(columns: (100%))[ #smallcaps[*Duration:*] $1$ clock cycle]

#table(
  columns: (8%, 92%),
  table.header([], [*Parameters*]),
  `pc`, [Program counter, before executing the instruction.],
  `L`, [Instruction length, $4$ for ARM state, $2$ for Thumb state.],
  `i`, [MAS, $2$ for ARM state, $1$ for Thumb state.])

#figure(caption: [Unexecuted Instruction Cycle], wavy.render(height: 32%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlh'},
    {name:'MREQ',wave:'1.x.', phase: 0},
    {name:'SEQ', wave:'0.x.', phase: 0},
    {name:'OPC', wave:'1.x.', phase: 0},
    {name:'RW',  wave:'1.x.', phase: 0},
    {name:'A',   wave:'5.5.', phase: 0, data: ['pc + 2L', 'pc + 3L']},
    {name:'MAS', wave:'5.x.', phase: 0, data: ['i']},
    {name:'DIN', wave:'z8x.', phase: 0, data: ['(pc + 2L)']},
    {node:'A.B.C.', phase: 0.15},
  ],
  edge: [
	'A+B cycle 1',
	'B+C post',
  ],
  head:{ text:'', tick:0, every:1 },
  config: { hscale: 2 }
}"))
