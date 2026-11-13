# Tiny8

An 8-bit CPU. Designed from scratch, in Verilog, for the GF180MCU-D 180 nm process.

This started as an attempt to build a processor of my own instead of just reading about how processors work. It has turned into a much bigger hardware project than I expected: custom instructions, an SRAM macro, an SPI programmer, simulations, physical design, and a GDS layout.

Tiny8 is not meant to compete with a modern microcontroller. It is a small processor that I can understand, program, simulate, and hopefully one day run on an actual chip.

<img width="7112" height="3254" alt="Tiny8 GDS render" src="https://github.com/user-attachments/assets/03578c1a-4aa9-47ab-80e8-0dd17b10429d" />

## So, what does it actually do?

Tiny8 fetches instructions from memory and executes them. It has an 8-bit datapath, but each instruction is 16 bits wide. The processor has eight general-purpose registers, an ALU, a program counter, a stack pointer, and an FSM that moves it through the steps needed to execute an instruction.

It can do the usual small-CPU things:

- Add, subtract, increment and compare values.
- Run bitwise operations (AND, OR, XOR, NOT) and shifts.
- Load values into registers and move data around.
- Read from and write to memory.
- Jump, branch on flags, call subroutines and return.
- Push and pop values on a stack.
- Read an input port and write to an output port.
- Stop when it reaches `HLT`.

There are 32 opcodes in the current instruction set. The point wasn't to make a huge ISA; it was to make a usable one and get the whole thing working end to end.

## A quick look at the hardware

| Part | What is in Tiny8 |
|---|---|
| Datapath | 8-bit |
| Instruction size | 16-bit |
| General-purpose registers | 8, each 8-bit |
| Opcodes | 32 |
| ALU | Arithmetic, logic, shifts and comparisons |
| Control | FSM |
| SRAM | 256 × 8 bits |
| Program space | 128 bytes / 64 instructions |
| Data + stack space | 128 bytes |
| Program loading | SPI, Mode 0 |
| System clock | 10 MHz |
| Target process | GF180MCU-D, 180 nm |
| Tiny Tapeout size | 2 × 2 tiles |

A little more about the memory, because this part took some work: Tiny8 uses one 256 × 8 SRAM macro. It is split logically, not physically, into two regions:

- `0x00–0x7F` — data memory and stack.
- `0x80–0xFF` — program bytes.

That upper half holds 128 bytes. Since instructions are two bytes each, that gives the CPU room for 64 instructions. Instructions are stored high byte first. The stack starts at `0x7F` and grows downwards.

The CPU has four status flags: zero, carry, negative and overflow. Conditional jumps use these flags.

## The instruction set

Here is the current opcode map. It is not a fancy assembly language yet; this is the instruction set implemented by the hardware.

| Opcode | Instruction | What it does |
|---|---|---|
| `0x00` | NOP | Do nothing |
| `0x01` | HLT | Stop execution |
| `0x02` | LDI | Load an immediate value |
| `0x03` | MOV | Copy a register |
| `0x04` | ADD | Add |
| `0x05` | SUB | Subtract |
| `0x06` | AND | Bitwise AND |
| `0x07` | OR | Bitwise OR |
| `0x08` | XOR | Bitwise XOR |
| `0x09` | NOT | Bitwise NOT |
| `0x0A` | SHL | Shift left |
| `0x0B` | SHR | Shift right |
| `0x0C` | ADDI | Add an immediate value |
| `0x0D` | SUBI | Subtract an immediate value |
| `0x0E` | LDA | Load from memory |
| `0x0F` | STA | Store to memory |
| `0x10` | JMP | Unconditional jump |
| `0x11` | JZ | Jump if zero |
| `0x12` | JNZ | Jump if not zero |
| `0x13` | JC | Jump if carry |
| `0x14` | JNC | Jump if carry is clear |
| `0x15` | JN | Jump if negative |
| `0x16` | JV | Jump if overflow |
| `0x17` | JNV | Jump if overflow is clear |
| `0x18` | CALL | Call a subroutine |
| `0x19` | RET | Return from a subroutine |
| `0x1A` | PUSH | Push a register onto the stack |
| `0x1B` | POP | Pop a value from the stack |
| `0x1C` | IN | Read the input port |
| `0x1D` | OUT | Write to the output port |
| `0x1E` | CMP | Compare values |
| `0x1F` | INC | Increment a register |

## Loading a program (SPI)

I didn't want every program to be baked into the Verilog. Tiny8 has a separate SPI programming module so an external controller can write a program into SRAM.

The interface uses SPI Mode 0, MSB first. The system clock is 10 MHz; the recommended initial SPI clock is 500 kHz or slower because the receiver samples the external clock using the system clock. SPI SCLK is not used as the CPU's clock.

| Pin | Signal | Purpose |
|---|---|---|
| `uio[0]` | SPI_SCLK | SPI clock |
| `uio[1]` | SPI_MOSI | Program data |
| `uio[2]` | SPI_CS_N | Active-low chip select |
| `uio[3]` | PROG_MODE | Enter programming mode |
| `uio[4]` | READY | A byte has been written; ready for the next one |
| `uio[5]` | PROG_FULL | Program region is full |
| `uio[6]` | PC6_PROG | PC debug bit |
| `uio[7]` | PC7_PROG | PC debug bit |

The basic sequence is: assert `PROG_MODE`, pull `CS_N` low, send bytes on MOSI, and wait for `READY` to go high again before sending the next byte. When the transfer is over, release chip select and take `PROG_MODE` low. The CPU is held in reset during programming, so it doesn't try to execute half a program.

There is no MISO line at the moment. The programmer is write-only.

## A program that actually runs

This is the small program used in the testbench. It loads 5 and 3, adds them, writes the answer to the output port, and stops.

```asm
LDI R0, 5
LDI R1, 3
ADD R2, R0, R1
OUT R2
HLT
```

The bytes sent to the programmer are:

```text
10 05  11 03  22 04  EA 00  08 00
```

After execution, the expected state is:

- `R0 = 0x05`
- `R1 = 0x03`
- `R2 = 0x08`
- `port_out = 0x08`
- `PC = 0x05`
- CPU halted

Not a particularly useful application on its own, obviously. But it checks that program loading, instruction fetch, register writes, the ALU, output and halt all work together.

## Running the tests

The simulations live in `test/`. Run them from that directory, using an OSS CAD Suite terminal with Icarus Verilog and Cocotb available.

**RTL regression**

```sh
cd test
make clean
make
```

The RTL testbench loads the example program into the shared SRAM, releases reset and waits for the CPU to halt. Cocotb checks the output and debug state. A passing run should finish without assertion failures or a timeout.

**Gate-level wrapper test**

This needs the generated `gate_level_netlist.v` in `test/` and `PDK_ROOT` set to an installed GF180MCU PDK.

```sh
make clean
make GATES=yes
```

This is a gate-level smoke test for the wrapper and bidirectional pin configuration. It is not the same as the RTL program-execution test.

**SPI programming testbench**

There is also a standalone Verilog testbench that sends the program through the actual SPI pins rather than writing directly to the programming bus. From the `test/` directory:

```sh
iverilog -g2012 -DSIMULATION -I../src -s tb_spi -o sim_spi.vvp ../src/project.v ../src/tiny8_top.v ../src/tiny8_spi_programmer.v ../src/gf180mcu_ocd_ip_sram__sram256x8m8wm1__blackbox.v gf180_sram_sim.v tb_spi.v
vvp sim_spi.vvp
```

It should print:

```text
PASS: SPI loaded 10 bytes into Tiny8 SRAM and CPU executed program.
```

The testbench also writes `tiny8_spi.vcd`. To inspect it:

```sh
gtkwave tiny8_spi.vcd
```

## The physical side of things

Tiny8 targets the GF180MCU-D 180 nm process and uses the GF180 SRAM macro. The design was taken through the Tiny Tapeout physical-design flow for a 2 × 2 tile allocation. GDS was generated and DRC checks completed successfully.

That is a meaningful milestone, but it is worth being precise: a clean layout and successful design checks do not mean the chip has been fabricated or tested in silicon. Those steps are still ahead.

<img width="1246" height="490" alt="Tiny8 verification screenshot" src="https://github.com/user-attachments/assets/19527406-2d0c-4909-baad-78f01e158977" />

## Where the project stands

- [x] CPU architecture and RTL
- [x] Custom 32-opcode instruction set
- [x] Shared SRAM integration
- [x] SPI program loader
- [x] RTL regression
- [x] Gate-level regression
- [x] GDS generation
- [x] DRC checks
- [ ] Fabrication
- [ ] Testing on the actual chip

## What's next?

A proper assembler is probably the most useful next step. Writing raw instruction bytes gets old very quickly. A small desktop uploader and a simple emulator would also make it easier to write programs and debug them without manually inspecting waveforms every time.

There is plenty left to do. For now, Tiny8 is a working processor design that has made it through simulation and physical implementation, and the next big test is seeing it run on silicon.

## Files worth looking at

- `src/tiny8_top.v` — the CPU itself: datapath, control FSM, registers and SRAM interface.
- `src/tiny8_spi_programmer.v` — SPI receiver and program-loading logic.
- `src/project.v` — Tiny Tapeout wrapper and pin connections.
- `test/tb.v` — shared-SRAM CPU testbench.
- `test/tb_spi.v` — SPI loading and execution testbench.
- `test/gf180_sram_sim.v` — functional SRAM model for simulation.
- `info.yaml` — Tiny Tapeout metadata and pinout.
- `docs/info.md` — project operation and testing notes.

---

Built as a from-scratch processor project. Small enough to fit in a Tiny Tapeout tile allocation, complicated enough to teach me a lot along the way.
