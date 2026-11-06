# Tiny8 — A Custom 8-Bit CPU on GF180MCU

**Tiny8** is a custom-designed 8-bit processor implemented in Verilog and prepared for fabrication using the **GlobalFoundries GF180MCU-D 180 nm process** through Tiny Tapeout.

The project brings together a custom instruction set, an FSM-based control unit, a shared SRAM architecture, and an SPI-based programming interface. It is designed to operate as a small, independently programmable processor rather than simply as an isolated arithmetic circuit.

8-bit Datapath · 16-bit Instructions · 32 Opcodes · 8 Registers

<img width="7112" height="3254" alt="68747470733a2f2f676f646f6673747261746567792e6769746875622e696f2f54696e79382d6766313830302d6275696c642f6764735f72656e6465722e706e67" src="https://github.com/user-attachments/assets/03578c1a-4aa9-47ab-80e8-0dd17b10429d" />

---

## 1. Project Overview

Tiny8 is an 8-bit CPU with a custom instruction set architecture (ISA). Its datapath operates on 8-bit values, while instructions are 16 bits wide.

The processor uses a finite-state machine (FSM) to control instruction fetching, decoding, execution, memory access, and stack operations.

The design includes:

- An 8-bit arithmetic and logic unit (ALU).
- Eight general-purpose 8-bit registers.
- A 16-bit instruction format.
- A 32-opcode instruction set.
- A 256 × 8-bit shared SRAM.
- Separate logical regions for program storage and data storage.
- A stack for subroutine calls and temporary data.
- Four processor status flags.
- An SPI programming interface.
- External input and output ports.
- Debug outputs exposing processor execution state.

### Design specifications

| Specification | Implementation |
|---|---|
| Processor | Tiny8 |
| Datapath width | 8 bits |
| Instruction width | 16 bits |
| Instruction set | 32 opcodes |
| General-purpose registers | 8 × 8-bit |
| Status flags | 4 |
| Memory | 256 × 8-bit SRAM |
| Program capacity | 64 instructions |
| Data memory | 128 bytes |
| Programming interface | SPI |
| SPI mode | Mode 0 |
| Recommended SPI frequency | 500 kHz or lower |
| System clock | 10 MHz |
| Technology | GF180MCU-D |
| Process node | 180 nm |
| Tiny Tapeout allocation | 2 × 2 tiles |

---

## 2. Architecture

Tiny8 uses a custom FSM-controlled processor architecture.

The processor consists of the following major components:

### Control Unit

The control unit coordinates the execution of instructions using a finite-state machine.

Its states handle:

- Instruction fetching.
- Instruction decoding.
- Instruction execution.
- SRAM read and write operations.
- Stack pushes and pops.
- Halted operation.

The FSM separates memory access from instruction execution to accommodate the synchronous SRAM interface.

### Arithmetic Logic Unit (ALU)

The ALU performs arithmetic, logical, and bitwise operations on 8-bit operands.

Supported operations include:

- Addition and subtraction.
- Bitwise AND, OR, and XOR.
- Bitwise NOT.
- Logical left and right shifts.
- Increment.
- Comparisons.

The ALU also updates the processor's status flags where appropriate.

### Register File

Tiny8 contains eight general-purpose registers:

`R0`, `R1`, `R2`, `R3`, `R4`, `R5`, `R6`, and `R7`.

Each register stores an 8-bit value.

These registers are used for arithmetic operations, data manipulation, memory transfers, and input/output operations.

### Program Counter

The program counter (PC) identifies the instruction currently being executed.

It uses a 6-bit instruction index within the 64-instruction program region. The debug output exposes the PC as an 8-bit value.

### Stack Pointer

The stack pointer (SP) manages stack operations in the data-memory region.

The stack supports subroutine calls, returns, and register push/pop operations.

### Status Flags

Tiny8 maintains four status flags:

| Flag | Description |
|---|---|
| Z | Zero flag |
| C | Carry flag |
| N | Negative flag |
| V | Overflow flag |

These flags are used by conditional branch instructions.

---

## 3. Memory Architecture

Tiny8 uses a single 256 × 8-bit SRAM macro for both program storage and data storage.

The memory is logically divided into two regions.

| Address range | Size | Purpose |
|---|---:|---|
| `0x00–0x7F` | 128 bytes | Data memory and stack |
| `0x80–0xFF` | 128 bytes | Program storage |

### Program Storage

The upper 128 bytes hold the program.

Since each instruction is 16 bits (2 bytes), the processor can store:

**128 bytes ÷ 2 = 64 instructions**

Instructions are stored high byte first, followed by the low byte.

For example, an instruction represented by `0x1005` is stored as:

| SRAM address | Stored value |
|---|---|
| `0x80` | `0x10` |
| `0x81` | `0x05` |

The processor fetches these two bytes in separate memory-access stages and combines them into its 16-bit instruction register.

### Data Memory and Stack

The lower 128 bytes are reserved for data and stack operations.

The stack begins at `0x7F` and grows toward lower addresses.

This arrangement allows program instructions and runtime data to share one physical SRAM macro while remaining logically separated.

---

## 4. Instruction Set Architecture

Tiny8 implements 32 opcodes, ranging from `0x00` to `0x1F`.

| Opcode | Instruction | Operation |
|---|---|---|
| `0x00` | NOP | No operation |
| `0x01` | HLT | Halt processor |
| `0x02` | LDI | Load immediate value |
| `0x03` | MOV | Copy register value |
| `0x04` | ADD | Addition |
| `0x05` | SUB | Subtraction |
| `0x06` | AND | Bitwise AND |
| `0x07` | OR | Bitwise OR |
| `0x08` | XOR | Bitwise XOR |
| `0x09` | NOT | Bitwise NOT |
| `0x0A` | SHL | Shift left |
| `0x0B` | SHR | Shift right |
| `0x0C` | ADDI | Add immediate |
| `0x0D` | SUBI | Subtract immediate |
| `0x0E` | LDA | Load from memory |
| `0x0F` | STA | Store to memory |
| `0x10` | JMP | Unconditional jump |
| `0x11` | JZ | Jump if zero |
| `0x12` | JNZ | Jump if not zero |
| `0x13` | JC | Jump if carry |
| `0x14` | JNC | Jump if no carry |
| `0x15` | JN | Jump if negative |
| `0x16` | JV | Jump if overflow |
| `0x17` | JNV | Jump if no overflow |
| `0x18` | CALL | Call subroutine |
| `0x19` | RET | Return from subroutine |
| `0x1A` | PUSH | Push register onto stack |
| `0x1B` | POP | Pop value from stack |
| `0x1C` | IN | Read external input |
| `0x1D` | OUT | Write external output |
| `0x1E` | CMP | Compare operands |
| `0x1F` | INC | Increment register |

The instruction set includes arithmetic, logical, memory, control-flow, stack, and input/output operations.

---

## 5. SPI Programming Interface

Tiny8 includes an SPI-based programming module that allows an external controller, such as a microcontroller on a carrier board, to load program bytes into SRAM.

This eliminates the need to hardcode a program into the processor's RTL.

### SPI configuration

| Parameter | Value |
|---|---|
| SPI mode | Mode 0 |
| Bit order | MSB first |
| Recommended maximum initial SCLK | 500 kHz |
| System clock | 10 MHz |
| Programming capacity | 128 bytes |
| Maximum instructions | 64 |

The SPI receiver oversamples the external clock using the system clock. SPI SCLK is not used as an internal clock.

### Programming pinout

| Pin | Function | Description |
|---|---|---|
| `uio[0]` | SPI_SCLK | SPI clock |
| `uio[1]` | SPI_MOSI | Serial data input |
| `uio[2]` | SPI_CS_N | Active-low chip select |
| `uio[3]` | PROG_MODE | Enables programming mode |
| `uio[4]` | READY | Indicates that the receiver is ready for another byte |
| `uio[5]` | PROG_FULL | Indicates that all 128 program bytes have been written |
| `uio[6]` | PC6_PROG | Upper PC debug bit |
| `uio[7]` | PC7_PROG | Upper PC debug bit |

### Programming sequence

1. Assert `PROG_MODE`.
2. Keep chip select active (`SPI_CS_N = 0`).
3. Send program bytes over MOSI, most significant bit first.
4. Wait for `READY` to return high after each byte.
5. Deassert chip select after programming.
6. Deassert `PROG_MODE`.
7. The processor exits reset and begins executing the loaded program.

The programmer automatically increments the program byte address after each completed byte.

The programming module holds the CPU in reset throughout the programming session, preventing execution while the program is being loaded.

**Important:** The SPI interface currently has no MISO output. Program loading is write-only.

---

## 6. Example Program

The following example loads two values into registers, adds them, sends the result to the output port, and halts.

### Program

| Instruction | Meaning |
|---|---|
| `LDI R0, 5` | Load 5 into R0 |
| `LDI R1, 3` | Load 3 into R1 |
| `ADD R2, R0, R1` | Add R0 and R1, store in R2 |
| `OUT R2` | Write R2 to output |
| `HLT` | Halt execution |

### Program bytes

The corresponding 10-byte program image is:

```text
10 05
11 03
22 04
EA 00
08 00
```

These bytes are transmitted sequentially over SPI.

### Expected result

| Register / Signal | Expected value |
|---|---|
| R0 | `0x05` |
| R1 | `0x03` |
| R2 | `0x08` |
| Output port | `0x08` |
| Program Counter | `0x05` |
| Halted | `1` |

This program is also used by the SPI programming testbench to verify that bytes are written into SRAM and subsequently executed by the CPU.

---

## 7. Input and Output

Tiny8 provides an 8-bit input port and an 8-bit output port.

| Signal | Direction | Width | Function |
|---|---|---:|---|
| `ui_in` | Input | 8 bits | External input data |
| `uo_out` | Output | 8 bits | Processor output data |
| `uio_in` | Input | 8 bits | SPI and programming control |
| `uio_out` | Output | 8 bits | Status and debug information |
| `uio_oe` | Output | 8 bits | Bidirectional pin output enables |

The `IN` instruction reads the external input port into a general-purpose register.

The `OUT` instruction writes a register's value to the output port.

The bidirectional pins are shared between programming signals, status indicators, and program-counter debugging depending on the operating mode.

---

## 8. Verification and Testing

Tiny8 has been tested at the RTL and gate-level stages.
<img width="1246" height="490" alt="Screenshot 2026-11-05 224548" src="https://github.com/user-attachments/assets/19527406-2d0c-4909-baad-78f01e158977" />


### RTL Verification

The RTL testbench checks:

- Program loading through the programming interface.
- SRAM write operations.
- Instruction fetching.
- Register operations.
- ALU execution.
- Output-port behaviour.
- Correct processor halt behaviour.

The SPI testbench loads the example 10-byte program and verifies that the processor executes it successfully.

### Gate-Level Verification

The gate-level regression checks the implemented logic using the generated gate-level netlist and the GF180 SRAM model.

### Physical Design

The physical implementation flow has been completed for the intended 2 × 2 Tiny Tapeout allocation.

The project has:

- Generated a GDS layout.
- Completed the physical-design flow.
- Completed DRC checks successfully.

These results establish that the design passed the reported implementation and verification stages. They do not constitute fabrication or post-silicon validation.

---

## 9. Repository Structure

```text
Tiny8-gf1800-build/
│
├── src/
│   ├── project.v
│   ├── tiny8_top.v
│   ├── tiny8_spi_programmer.v
│   ├── gf180mcu_ocd_ip_sram__sram256x8m8wm1__blackbox.v
│   └── sram/
│
├── test/
│   ├── tb.v
│   ├── tb_spi.v
│   ├── gf180_sram_sim.v
│   ├── Makefile
│   └── ...
│
├── docs/
│   └── index.html
│
├── .github/
│   └── workflows/
│
├── info.yaml
└── README.md
```

### Important source files

| File | Purpose |
|---|---|
| `project.v` | Tiny Tapeout top-level wrapper and pin mapping |
| `tiny8_top.v` | CPU core, ALU, FSM, register file, and SRAM interface |
| `tiny8_spi_programmer.v` | SPI program-loading controller |
| SRAM blackbox | Physical SRAM macro interface |
| `gf180_sram_sim.v` | Functional SRAM model for RTL simulation |
| `tb.v` | CPU and shared-SRAM testbench |
| `tb_spi.v` | SPI programming and execution testbench |
| `info.yaml` | Tiny Tapeout project metadata and pinout |

---

## 10. Technology and Physical Implementation

Tiny8 targets the GF180MCU-D process, a 180 nm CMOS technology.

The project uses a dedicated GF180 SRAM macro rather than implementing the entire memory as flip-flops.

This is important for keeping the memory implementation compact and making use of a technology-specific memory primitive.

The design targets a 2 × 2 Tiny Tapeout tile allocation.

The final layout is generated through the Tiny Tapeout physical-design workflow.

---

## 11. Future Development

Potential directions for further development include:

- Developing a dedicated Tiny8 assembler.
- Creating a desktop program loader.
- Designing a carrier board with an SPI master.
- Developing a higher-level programming language or compiler.
- Adding peripheral interfaces.
- Improving debugging and execution visibility.
- Developing a software emulator for instruction-level testing.
- Testing the fabricated chip and validating its operation on physical hardware.

A dedicated assembler and carrier-board programming utility would make Tiny8 significantly easier to use as a standalone experimental computing platform.

---

## 12. Project Status

| Stage | Status |
|---|---|
| CPU architecture | Implemented |
| Custom ISA | Implemented |
| ALU and control unit | Implemented |
| Shared SRAM integration | Implemented |
| SPI programming interface | Implemented |
| RTL verification | Passed |
| Gate-level verification | Passed |
| GDS generation | Completed |
| DRC | Passed |
| 2 × 2 physical allocation | Completed |
| Fabrication | Pending |
| Post-silicon testing | Pending |

---

## 13. Acknowledgements

Tiny8 is an independent processor-design project developed using open-source hardware design tools and the Tiny Tapeout ecosystem.

The project uses the GF180MCU technology platform and its SRAM macro infrastructure.

---

## 14. License

Add the project's chosen open-source license here before distributing or reusing the source code.

---

**Tiny8 — A small processor, designed from the ground up.**
