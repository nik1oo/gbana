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
#show raw.where(lang: "wavy"): it => wavy.render(it.text)

= Preface

GBANA is a Game Boy Advance emulator. Other GBA emulators exist and they make games look and feel as good as they did on the original GBA. GBANA will make them look and feel _better_ than they did on the original GBA.

= Classes

Each file represents a class. The _singleton classes_ correspond to the components in the block diagram on the next page. The _helper classes_ contain procedures that are used by the singleton classes. The _instance classes_ contain objects that are instantiated and used by the other classes.

#table(
	columns: (auto, auto, auto, auto),
	inset: 0.5em,
	align: horizon,
	table.header(
  	[*Name*], [*File*], [*Type*], [*Description*],
	[GBA Core], [`gba_core.odin`], [Singleton Class], [Emulating the ARM7TDMI core inside the AGB chip.],
	[GB Core], [`gb_core.odin`], [Singleton Class], [Emulating the SM83 core inside the AGB chip.],
	[Bus Controller], [`bus_controller.odin`], [Singleton Class], [Emulating the bus control logic inside the AGB chip.],
	[DMA Controller], [`dma_controller.odin`], [Singleton Class], [Emulating the DMA controller inside the AGB chip.],
	[Memory Controller], [`memory_controller`], [Singleton Class], [Emulating the memory controller inside the AGB chip.],
	[Cpu], [`cpu.odin`], [Helper Class], [Emulating the shared logic between the components inside the AGB chip.],
	[Memory], [`memory.odin`], [Singleton Class], [Emulating both the internal and external memory of the gba.],
	[Buttons], [`buttons.odin`], [Singleton Class], [Emulating the buttons of the GBA.],
	[Cartridge], [`cartridge.odin`], [Singleton Class], [Emulating a GBA cartridge.],
	[Display], [`display.odin`], [Singleton Class], [Emulating the display of the GBA.],
	[GBA Isa], [`gba_isa.odin`], [Helper Class], [Defining the ISA of the GBA core.],
	[GB Isa], [`gb_isa.odin`], [Helper Class], [Defining the ISA of the GB core.],
	[PPU], [`ppu.odin`], [Singleton Class], [Emulating the GBA PPU.],
	[Line and Bus], [`line_and_bus.odin`], [Instance Class], [Emulating the behavior of a line and a bus.],
	[SIO Controller], [`sio_controller.odin`], [Singleton Class], [Emulating the SIO controller.],
	[Speakers], [`speakers.odin`], [Singleton Class], [Emulating the speakers.],
	[Util], [`util.odin`], [Helper Class], [General utilities.]))

= Block Diagram

#align(center, circuit({
	element.group(name: text(16pt)[Device], stroke: (dash: "solid"), fill: aqua, {
		element.block(stroke: none, x: 4, y: 2.5, w: 4, h: 2, id: "block")
		element.group(name: text(16pt)[AGB ASIC], stroke: (dash: "solid"), fill: blue, {
			element.block(name: [GBA\ Core], x: 4, y: 0, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [GB\ Core], x: 8.25, y: 0, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [Bus\ Controller], x: 4, y: -2.25, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [DMA\ Controller], x: 8.25, y: -2.25, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [PPU], x: 4, y: -4.5, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [Sound\ Controller], x: 8.25, y: -4.5, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [Timer\ Controller], x: 4, y: -6.75, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [Interrupt\ Controller], x: 8.25, y: -6.75, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [Input\ Controller], x: 4, y: -9, w: 4, h: 2, id: "block", fill: white)
			element.block(name: [SIO\ Controller], x: 8.25, y: -9, w: 4, h: 2, id: "block", fill: white)
		})
		element.block(name: "Oscillator", x: 4, y: -12.1, w: 4, h: 2, id: "block", fill: white)
		element.block(name: "Speaker", x: 8.25, y: -12.1, w: 4, h: 2, id: "block", fill: white)
		element.block(name: "Display", x: 4, y: -14.35, w: 4, h: 2, id: "block", fill: white)
		element.block(name: "Buttons", x: 8.25, y: -14.35, w: 4, h: 2, id: "block", fill: white)
	})
	element.group(name: text(16pt)[Cartridge], stroke: (dash: "solid"), fill: teal, {
		element.block(stroke: none, x: 13.35, y: 2.5, w: 4, h: 2, id: "block", fill: white)
		element.block(name: "Cartridge", x: 13.35, y: 0, w: 4, h: 2, id: "block", fill: white)
	})
	element.block(name: "Memory", x: 4, y: 2.5, w: 13.35, h: 2, id: "block", fill: white)
}))

= Emulating the Clock & Cycle

GBANA is phase-accurate. Every phase of every cycle is simulated (one tick simulates one phase). Synchronization of events within the phase need not match the real GBA, but at the end of each phase, the correct phase must be produced.

#align(center,wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',wave:'n...'},
  ]
}"))

Main clock frequency: 16 MHz, ie approximately 16E6 cycles per second, or 62.5 ns per cycle. This is plenty time to emulate a single cycle on a modern computer. Each cycle has a low phase and a high phase. Each phase is one emulator tick. Each tick has two parts: a _start_ part, where all the signals are updated and their callback functions are called, and an _interior_ part, where the components execute their logic based on their internal state and the updated signals.

= Signals

Components communicate by means of two types of interface: lines and buses. A line is just a boolean bus. There are two ways to affect a line/bus: (1) by _putting_ data on it, and (2) by _forcing_ data on it. Forcing updates the output value immediately. Putting schedules an update to the output value, to occur after a certain number of ticks.

Out of the signals defined in the ARM DDI 0029G, `D` is the only bidirectional signal so I got rid of it, in favor of `DIN` and `DOUT`.

Signal classes:
- clock
- address
- request
- response
- control

#table(
	columns: (auto, auto, auto, auto),
	inset: 0.5em,
	align: top,
	table.header(
	[*Name*], [*Class*], [*Component*], [*Description*]),
	`A`,       [Memory\ Interface], [*Memory*], [The 32-bit address bus. The CPU writes an address to this but, for memory access requests.],
	`ABE`,     [Bus\ Controls], [*Bus Controller*], [],
	`ABORT`,   [Memory\ Management\ Interface], [], [The memory sets this to _high_ to tell the CPU that the memory access request cannot be fulfilled.],
	`ALE`,     [Bus\ Controls], [*Bus Controller*], [],
	`APE`,     [Bus\ Controls], [*Bus Controller*], [],
	`BIGEND`,  [Bus\ Controls], [], [],
	`BL`,      [Memory\ Interface], [*Memory*], [Byte latch control. A 4-bit bus where each bit corresponds to one of the bytes in a word. Used to indicate which part of the requested word is to be read/written.],
	`BUSDIS`,  [Bus\ Controls], [], [],
	`BUSEN`,   [Bus\ Controls], [], [],
	`DBE`,     [Bus\ Controls], [], [],
	`DIN`,     [Memory\ Interface], [*GBA Core*], [Unidirectional input data bus.],
	`DOUT`,    [Memory\ Interface], [*Memory*], [Unidirectional output data bus.],
	`ENIN`,    [Bus\ Controls], [*Bus Controller*], [],
	`ENOUT`,   [Bus\ Controls], [*Bus Controller*], [],
	`FIQ`,     [Interrupts], [*GBA Core*], [],
	`ECLK`,    [Clocks\ and Timing], [], [`MCLK` exported from the core, for debugging. Has a small latency. Irrelevant for the emulator.],
	`HIGHZ`,   [Bus\ Controls], [*Bus Controller*], [],
	`ISYNC`,   [Interrupts], [*GBA Core*], [],
	`IRQ`,     [Interrupts], [*GBA Core*], [],
	`LOCK`,    [Memory\ Interface], [*Memory*], [Locks the memory, giving exclusive access to it to the CPU. This is effectively a mutex.],
	`MAS`,     [Memory\ Interface], [*Memory*], [Memory access size.],
	`MCLK`,    [Clocks\ and Timing], [], [The main clock. Has two phases: a low phase and a high phase. Procedures can be constrained to any combination of these four: (1) the _start_ of the low phase, (2) the _interior_ of the low phase, (3) the _start_ of the high phase, and (4) the _interior_ of the high phase.],
	`M`,       [Processor\ Mode], [*GBA Core*], [],
	`MREQ`,    [Memory\ Interface], [*Memory*], [Set to _high_ to indicate that the next cycle will be used to execute a memory request.],
	`OPC`,     [Memory\ Interface], [*Memory*], [This signal is used to distinguish between next-instruction-fetch and data-read/data-write. Set to _high_ for instruction fetch request, set to _low_ for data read/write requests.],
	`RESET`,   [Bus\ Controls], [], [Used to start the processor. Must be held _high_ for at least 2 cycles, with `WAIT` set to _low_.],
	`RW`,      [Memory\ Interface], [*Memory*], [This signal is used to distinguish between memory read and memory write. Set to _high_ for read requests, set to _low_ for write requests.],
	`SEQ`,     [Memory\ Interface], [*Memory*], [Set to _high_ to indicate that the address of the next memory request will be in the same word that was accessed in the previous memory access or the word immediately after it. Sequential reads require fewer memory cycles.],
	`TBE`,     [Bus\ Controls], [], [],
	`TBIT`,    [Processor\ State], [*GBA Core*], [Set to _high_ for Thumb mode, set to _low_ for ARM mode.],
	`TRANS`,   [Memory\ Management\ Interface], [], [This signal is used to enable address translation in the memory management system. Irrelevant for the emulator.],
	`WAIT`,    [Clocks\ and Timing], [], [This signal is used to insert wait cycles. Different memory regions have different access latency, which determines how many wait cycles need to be inserted.])

= Timing

Types of intervals in a timing diagram#footnote[ARM DDI 0029G xix]:
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

== Simple Memory Cycle #footnote[ARM DDI 0029G 3-4]

This is what a general memory cycle looks like:

#align(center, wavy.render(width: 80%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlh'},
    {name:'MREQ/SEQ',wave:'x.5.x...', phase: -0.35},
    {name:'A',wave:'x..5.x..', phase: -0.35},
    {name:'D',wave:'x....8x.', phase: -0.35},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B (0)',
	'B+C (1)',
	'C+D (2)',
	'D+E (3)'
  ]
}"))

Cycle (0) is the _pre-cycle_, cycle (1) is the _request cycle_, cycle (2) is the _response cycle_, and cycle (3) is the _post-cycle_. The term _memory cycle_ refers to cycle (2).

*General logic of a memory cycle:*

- The CPU must write `MREQ` and `SEQ` during the interior of phase 1 of the request cycle.
- The Memory may read `MREQ` and `SEQ` during phase 2 of the request cycle and/or at the start of phase 1 of the response cycle.
- The CPU must write `A` during the interior of phase 2 of the request cycle.
- The Memory may read `A` during phase 1 of the response cycle and/or at the start of phase 2 of the response cycle.
- The Memory must write `D` during the interior of phase 2 of the response cycle.
- The CPU may read `D` at the start of phase 1 of the post cycle.
\

== N-Cycle #footnote[ARM DDI 0029G 3-5]

This is what a Nonsequential Memory Cycle (N-cycle) looks like:

#align(center, wavy.render(width: 80%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlh'},
    {name:'A',wave:'x..5.x..', phase: -0.35},
    {name:'MREQ',wave:'x.1.0.x.', phase: -0.35},
    {name:'SEQ',wave:'x.0.1.x.', phase: -0.35},
    {name:'D',wave:'x.z..5zx', phase: -0.35},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B (0)',
	'B+C (1)',
	'C+D (2)',
	'D+E (3)'
  ]
}"))

Cycle (0) is the _pre-cycle_, cycle (1) is the _request cycle_, cycle (2) is the _response cycle_, and cycle (3) is the _post-cycle_. The term _nonsequential memory cycle_ refers to cycle (2).

*Specific logic of an N-Cycle:*

- General memory cycle logic.
- The CPU must set `MREQ` and `SEQ` to low during the interior of phase 1 of the request cycle.
- The Memory may extend phase 1 of the response cycle by setting the `WAIT` signal.
\

== S-Cycle #footnote[ARM DDI 0029G 3-6]

This is what a Sequential Memory Cycle (S-cycle) looks like:

#align(center, wavy.render(width: 90%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlhlh'},
    {name:'A',wave:'x..5.5.5.x', phase: -0.35},
    {name:'MREQ',wave:'x.1.......', phase: -0.35},
    {name:'SEQ',wave:'x.0.1.....', phase: -0.35},
    {name:'D',wave:'x.z..5z5z5', phase: -0.35},
    {node:'A.B.C.D.E.F', phase: 0.15},
  ],
  edge: [
	'A+B (0)',
	'B+C (1)',
	'C+D (2)',
	'D+E (3)',
	'E+F (4)',
  ]
}"))

Cycle (0) is the _pre-cycle_, cycle (1) is the _request cycle_, cycle (2) is the _N-response cycle_, cycle (3) is the 1st _S-response cycle_, cycle (4) is the 2nd _S-response cycle_, etc. The term _sequential memory cycle_ refers to cycles (3), (4), etc.

*Specific logic of an N-Cycle:*

- General memory cycle logic.
- The CPU must set `MREQ` and `SEQ` to low during the interior of phase 1 of the request cycle.
- The CPU must set `SEQ` to high during the interior of phase 1 of the N-response cycle.
- The Memory may extend phase 1 of the response cycle by setting the `WAIT` signal.
\

== I-Cycle #footnote[ARM DDI 0029G 3-7]

This is what an Internal Memory Cycle (I-cycle) looks like:

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'A',wave:'x.....', phase: -0.35},
    {name:'MREQ',wave:'x.0.x.', phase: -0.35},
    {name:'SEQ',wave:'x.0.x.', phase: -0.35},
    {name:'D',wave:'z.....', phase: -0.35},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B (0)',
	'B+C (1)',
	'C+D (2)',
	'D+E (3)'
  ]
}"))

Cycle (0) is the _pre-cycle_, cycle (1) is the _internal cycle_, and cycle (2) is the _post-cycle_.

*Specific logic of an N-Cycle:*

- The CPU must set `MREQ` and `SEQ` to low during the interior of phase 1 of the request cycle.
- `D` must remain disabled.
\

== Merged IS-Cycle

This is what a Merged Internal-Sequential Memory Cycle (merged IS-cycle) looks like:

#align(center, wavy.render(width: 80%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlh'},
    {name:'A',wave:'x..5.x..', phase: -0.35},
    {name:'MREQ',wave:'x.0.1.x.', phase: -0.35},
    {name:'SEQ',wave:'x.0.1.x.', phase: -0.35},
    {name:'D',wave:'x.z..5zx', phase: -0.35},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B (0)',
	'B+C (1)',
	'C+D (2)',
	'D+E (3)'
  ]
}"))

This looks the same as an N-Cycle, except the request cycle is merged with an I-cycle.

*Specific logic of an N-Cycle:*

- The CPU may put the address on the bus a cycle earler, to give more time to the Memory to decode it.
\

== Pipelined Addresses

#align(center, wavy.render(width: 80%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlh'},
    {name:'MREQ/SEQ',wave:'x.5.x...', phase: -0.35},
    {name:'A',wave:'x..5.x..', phase: -0.35},
    {name:'D',wave:'x...z8x.', phase: -0.35},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response',
	'D+E post'
  ]
}"))
\

== Depipelined Addresses

#align(center, wavy.render(width: 80%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlh'},
    {name:'MREQ/SEQ',wave:'x.5.x...', phase: -0.35},
    {name:'A',wave:'x...5.x.', phase: -0.35},
    {name:'D',wave:'x...z8x.', phase: -0.35},
    {node:'A.B.C.D.E', phase: 0.15},
  ],
  edge: [
	'A+B pre',
	'B+C request',
	'C+D response',
	'D+E post'
  ]
}"))
\

== Bidirectional Bus Cycle

#align(center, wavy.render(width: 95%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlhlhlh'},
    {name:'D',wave:'x.z88.z8x.', phase: -0.35},
    {node:'..A.B.C.D..', phase: 0.15},
  ],
  edge: [
	'A+B read cycle',
	'B+C write cycle',
	'C+D read cycle',
  ]
}"))
\

== Data Write Bus Cycle

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',wave:'lhlhlh'},
    {name:'A',wave:'x5.x..', phase: -0.35},
    {name:'RW',wave:'10.1..', phase: -0.35},
    {name:'ENOUT',wave:'0.1.0.', phase: -0.35},
    {name:'D',wave:'z.8.z.', phase: -0.35},
    {node:'..A.B..', phase: 0.15},
  ],
  edge: [
	'A+B mem cycle',
  ]
}"))
\

== Halfword Bus Cycle

#align(center, wavy.render(width: 80%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlhlhl'},
    {name:'MREQ',wave:'x5.x....', phase: -0.35},
    {name:'A',wave:'x.5...x.', phase: -0.35},
    {name:'WAIT',wave:'0..1.0..', phase: -0.35},
    {name:'D[0:15]',wave:'z...8z..', phase: -0.35},
    {name:'D[16:31]',wave:'z.....8z', phase: -0.35},
    {name:'BL',wave:'x..5.5.x', phase: -0.35},
    {node:'.A.B.C.D.E.', phase: 0.15},
  ],
  edge: [
	'A+B Q',
	'B+C A1',
	'C+D A2'
  ]
}"))
\

== Byte Bus Cycle

#align(center, wavy.render(width: 105%, "{
  signal:
  [
    {name:'MCLK',wave:'hlhlhlhlhlhl'},
    {name:'MREQ',wave:'x5.x........', phase: -0.35},
    {name:'A',wave:'x.5.......x.', phase: -0.35},
    {name:'WAIT',wave:'0..1.....0..', phase: -0.35},
    {name:'D[0:7]',wave:'z.....8z....', phase: -0.35},
    {name:'D[8:15]',wave:'z.........8z', phase: -0.35},
    {name:'BL',wave:'x..5...5...x', phase: -0.35},
    {node:'.A.B.C.D.E.F.', phase: 0.15},
  ],
  edge: [
	'A+B Q',
	'B+C W1',
	'C+D A1',
	'D+E W2',
	'E+F A2'
  ]
}"))
\

== Reset Sequence

The reset sequence should look like this:

#align(center, wavy.render(width: 120%, "{
  signal:
  [
    {name:'MCLK',  wave:'lhlhlhlhlhlhlh'},
    {name:'RESET', wave:'1.0...........', phase: -0.35},
    {name:'A',     wave:'x5.5.5.5.5.5.5', data: ['x', 'y', 'z', '0', '4', '8'], phase: -0.35},
    {name:'D',     wave:'z8z8z8z8z8z8z8', phase: -0.35},
    {name:'MREQ',  wave:'0.....1.......', phase: -0.35},
    {name:'SEQ',   wave:'0.......1.....', phase: -0.35},
    {name:'EXEC',  wave:'0.....1.......', phase: -0.35},
    {              node:'A.B.C.D.E.F.G.H', phase: 0.15},
  ],
  edge: [
	'A+B Reset',
	'B+C I-Cycle 1',
	'C+D I-Cycle 1',
	'D+E Request',
	'E+F Fetch',
	'F+G Decode',
	'G+H Execute'
  ]
}"))
\

== General Timing

#align(center, wavy.render(width: 55%, "{
  signal:
  [
    {name:'MCLK',       wave:'hlhl'},
    {name:'MREQ',       wave:'55..', phase: -0.35},
    {name:'SEQ',        wave:'55..', phase: -0.35},
    {name:'EXEC',       wave:'55..', phase: -0.35},
    {name:'INSTRVALID', wave:'55..', phase: -0.35},
    {name:'A',          wave:'8.8.', phase: -0.35},
    {name:'RW',         wave:'5.5.', phase: -0.35},
    {name:'MAS',        wave:'5.5.', phase: -0.35},
    {name:'LOCK',       wave:'5.5.', phase: -0.35},
    {name:'M',          wave:'5.5.', phase: -0.35},
    {name:'TBIT',       wave:'5.5.', phase: -0.35},
    {name:'OPC',        wave:'5.5.', phase: -0.35},
    {                   node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
  ]
}"))

/ 1.: `MREQ`, `SEQ`, `EXEC`, and `INSTRVALID` may only be updated at the start of or in the interior of phase 1.
/ 2.: `A`, `RW`, `MAS`, `LOCK`, `M`, `TBIT`, and `OPC` may only be updated at the start of or in the interior of phase 2.
\

== Address Bus Enable Control

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',              wave:'hlhl'},
    {name:'ABE',               wave:'10..', node:'.M..', phase: -0.25},
    {name:'A/RW/LOCK/OPC/MAS', wave:'5z..', node:'.N..', phase: -0.45},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
	'M->N',
  ]
}"))

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',              wave:'hlhl'},
    {name:'ABE',               wave:'01..', node:'.M..', phase: -0.25},
    {name:'A/RW/LOCK/OPC/MAS', wave:'z5..', node:'.N..', phase: -0.45},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
	'M->N',
  ]
}"))

- `ABE` can change during phase 1.
- `A`, `RW`, `LOCK`, `OPC`, and `MAS` are enabled/disabled immediately when `ABE` switches to high/low.
- `A`, `RW`, `LOCK`, `OPC`, and `MAS` must be stable at the starts of both phases.
\

== Bidirectional Data Write Cycle

#align(center, wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',  wave:'hlhl'},
    {name:'ENOUT', wave:'x1.x', phase: -0.35},
    {name:'D',     wave:'z8.z', phase: -0.35},
    {              node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
  ]
}"))

/ 1.: The CPU must enable `ENOUT` during the interior of phase 1.
/ 2.: The data must remain stable until the end of phase 1 of the post-cycle.
\

== Bidirectional Data Read Cycle

#align(center, wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',  wave:'hlhl'},
    {name:'ENOUT', wave:'x0.x',  phase: -0.35},
    {name:'BL',    wave:'x5.x',  phase: -0.35},
    {name:'D',     wave:'z.8z',  phase: -0.35},
    {              node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
  ]
}"))

/ 1.: The CPU must disable `ENOUT` during the interior of phase 1.
/ 2.: The data must remain stable until the end of phase 1 of the post-cycle.
\

== Data Bus Control

#align(center, wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',  wave:'hlhl'},
    {name:'ENOUT', wave:'10..',  phase: -0.45, node:'.N..'},
    {name:'DBE',   wave:'10..',  phase: -0.25, node:'.M..'},
    {name:'D',     wave:'8.z.',  phase: -0.45, node:'..Q.'},
    {name:'ENIN',  wave:'1.0.',  phase: -0.25, node:'..P.'},
    {              node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
	'M->N',
	'P->Q'
  ]
}"))

/ 1.: `ENIN` immediately disables `D` when it goes low.
/ 2.: `ENOUT` doesn't affect `D`.
/ 3.: `DBE` immediately disables `ENOUT` when it goes low.
\

== Configuration Pin Timing

#align(center, wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',   wave:'lhlh'},
    {name:'BIGEND', wave:'55..', node:'.M..', phase: -0.35},
    {name:'ISYNC',  wave:'x5x.', phase: -0.35},
    {                          node:'A.B.C', phase: 0.15},
  ],
  edge: [
	'A+B Cycle',
	'B+C Cycle',
  ]
}"))

/ 1.: `BIGEN` may be updated during phase 2.
/ 2.: `ISYNC` must be stable at the start of phase 1, it may be written at any other time.
\

== Exception Timing

#align(center, wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',     wave:'hlhl'},
    {name:'ABORT',    wave:'0.10', node:'.M..', phase: -0.35},
    {name:'FIQ, IRQ', wave:'0.=1', phase: -0.35},
    {name:'RESET',    wave:'1=0.', phase: -0.35},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle'
  ]
}"))
\

== Synchronous Interrupt Timing

#align(center, wavy.render(width: 50%, "{
  signal:
  [
    {name:'MCLK',     wave:'hlhl'},
    {name:'FIQ, IRQ', wave:'0.=1', phase: -0.35},
    {                          node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle'
  ]
}"))
\

== Memory Clock Timing

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',      wave:'hlhlhl'},
    {name:'WAIT',      wave:'01.0..', phase: -0.35},
    {name:'MREQ, SEQ', wave:'55....', phase: -0.35},
    {name:'A',         wave:'5...5.', phase: -0.35},
    {                  node:'.A.B.C.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle 1',
	'B+C Cycle 2'
  ]
}"))
\

== Address Latch Enable Control

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',                  wave:'hlhl'},
    {name:'ALE',                   wave:'010.',  phase: -0.35},
    {name:'A, RW, LOCK, OPC, MAS', wave:'55..',  phase: -0.35},
    {                              node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle 1'
  ]
}"))
\

== Address Pipeline Enable Control

#align(center, wavy.render(width: 65%, "{
  signal:
  [
    {name:'MCLK',                  wave:'hlhl'},
    {name:'APE',                   wave:'=0..',  phase: -0.35},
    {name:'A, RW, LOCK, OPC, MAS', wave:'5..5',  phase: -0.35},
    {                              node:'.A.B.', phase: 0.15},
  ],
  edge: [
	'A+B Cycle 1'
  ]
}"))
