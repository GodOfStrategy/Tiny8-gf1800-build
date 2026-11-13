<!---
This file is used to generate your project datasheet.
-->

## How it works

Tiny8 is an 8-bit CPU. It fetches 16-bit instructions from SRAM, decodes them, and carries them out using its register file, ALU, and control unit. The control unit is an FSM, so an instruction may take several clock cycles as the CPU fetches data, performs an operation, or accesses memory.

There are eight 8-bit general-purpose registers. The ALU handles arithmetic and logic operations, while the status flags record zero, carry, negative, and overflow results for conditional branches. The instruction set also includes memory access, jumps, subroutine calls, stack operations, and input/output instructions.

The 256 × 8 SRAM is shared by the program and the running program's data. Addresses `0x80–0xFF` hold up to 128 bytes of program code (64 instructions); `0x00–0x7F` are used for data and the stack. Each instruction is stored as two bytes, high byte first.

Programs can be loaded through the SPI interface. Set `PROG_MODE` high and send the program over SPI in Mode 0, most-significant bit first. The CPU stays in reset while programming is active. The `READY` signal tells the programmer when a byte has been written and the next one can be sent. Once programming is finished, deassert chip select and `PROG_MODE`; the CPU then starts executing from the beginning of program memory.

## How to test

The simulations are run from the `test` directory. Use the OSS CAD Suite environment so that Icarus Verilog and the Cocotb tools are on your PATH.

### RTL test

On Windows, open the OSS CAD Suite terminal, move into the repository's test directory, and run:

```sh
cd test
make clean
make
```

This runs the RTL regression. The Verilog testbench loads a short program into the shared SRAM, releases the CPU from reset, and waits for it to halt. Cocotb then checks the output and debug state. The example program loads 5 and 3, adds them, writes the result to the output port, and halts. The expected output is `0x08`.

A successful run ends with a Cocotb test pass and no assertion or timeout errors.

### Gate-level test

To run the gate-level wrapper test, make sure the generated `gate_level_netlist.v` is present in `test`, and that `PDK_ROOT` points to an installed GF180MCU PDK. Then run:

```sh
make clean
make GATES=yes
```

This checks the gate-level design's wrapper and bidirectional pin configuration. It is a smoke test; it does not replace the RTL program-execution test.

### SPI programming testbench

There is also a standalone Verilog testbench, `tb_spi.v`, which exercises the actual SPI programming path. From the `test` directory, compile and run it with Icarus Verilog:

```sh
iverilog -g2012 -DSIMULATION -I../src -s tb_spi -o sim_spi.vvp ../src/project.v ../src/tiny8_top.v ../src/tiny8_spi_programmer.v ../src/gf180mcu_ocd_ip_sram__sram256x8m8wm1__blackbox.v gf180_sram_sim.v tb_spi.v
vvp sim_spi.vvp
```

It sends the ten bytes for the same add-and-output program over SPI and checks that the CPU reaches `HLT` with an output of `0x08`. The testbench prints a `PASS` message if the load and execution both succeed. It also writes `tiny8_spi.vcd`, which can be opened in GTKWave:

```sh
gtkwave tiny8_spi.vcd
```

## External hardware

No external hardware is needed to run the simulations. To program a physical Tiny8 chip, an SPI master is needed to drive `SCLK`, `MOSI`, `CS_N`, and `PROG_MODE`. The chip's `READY` output can be used to pace the byte transfers.
