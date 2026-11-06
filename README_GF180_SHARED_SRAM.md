# Tiny8 GF180 shared-SRAM architecture

## Memory map

The design uses one physical `gf180mcu_ocd_ip_sram__sram256x8m8wm1` macro (256 x 8 bits):

| Address range | Size | Use |
|---|---:|---|
| `0x00-0x7F` | 128 bytes | Data RAM and descending stack |
| `0x80-0xFF` | 128 bytes | Program image: 64 instructions x 16 bits |

Instructions are stored high byte first. Instruction PC is six bits (0-63), and each instruction occupies two consecutive bytes. The data/stack address path is restricted to seven bits.

## Carrier-board programming interface (Tiny Tapeout 8:8:8 wrapper)

Programming is performed while `rst_n=0` and `ena=1`:

- `ui_in[7]`: active-high program byte write strobe
- `ui_in[6:0]`: byte offset `0..127` in the program image
- `uio_in[7:0]`: byte data
- `rst_n`: hold low for the entire programming session

The wrapper maps byte offset `n` to physical SRAM address `0x80+n`. The SRAM command is captured on the falling clock edge and commits on the next rising edge. The carrier should keep address/data/strobe stable across that capture and commit interval. Write the high byte then low byte for each instruction.

After all bytes are loaded, set `ui_in[7]=0`, then release `rst_n`. During execution, `uio_out` exposes the instruction PC and `uio_oe=8'hFF`. During reset/programming, `uio_oe=0`, so the carrier can drive the bus.

`uo_out` remains the CPU's normal 8-bit output port. During normal execution, all eight `ui_in` pins are connected to the CPU `IN` instruction. During programming, the same pins are repurposed as the write strobe and byte address because the CPU is held in reset.

## Simulation

Compile the CPU, simulation SRAM model, and new testbench together:

```sh
iverilog -g2012 -s tb_tiny8_shared_sram -o tiny8_test \
  tiny8_top_gf180.v gf180_sram_sim.v tb_tiny8_shared_sram.v
vvp tiny8_test
```

The simulation model is functional-only. Do not use `gf180_sram_sim.v` for synthesis or physical implementation. Synthesis/physical design must use the SRAM blackbox and the matching GF180 LEF, Liberty, and GDS views.

## Timing

The testbench uses a 60 ns clock period. The GF180 macro's timing constraints must be applied in the physical flow; do not assume the old 20 ns clock constraint is valid.

## Physical area caveat

The SRAM LEF previously inspected reports a macro size of 301.300 x 224.930 um (about 0.0678 mm^2). Splitting its logical address space does not reduce macro area. This design uses one macro instead of separate ROM and RAM macros, but a 2x2 tile fit is not proven until synthesis, macro placement, pin placement, and routing complete with the exact shuttle's tile dimensions and IO rules.
