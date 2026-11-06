// Tiny8 GF180 2x2 wrapper with carrier-board program loading.
// ui_in[7]   = program-byte write strobe (active high)
// ui_in[6:0] = byte offset 0..127 within program ROM
// uio_in     = program byte during loading
// Program loading is enabled only while rst_n is low.
// During execution, uio_out exposes the 8-bit instruction PC.
module tiny8_tt_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);
    wire [7:0] debug_pc;
    wire [15:0] debug_ir;
    wire [3:0] debug_state;
    wire [3:0] debug_flags;
    wire debug_halted;
    wire cpu_reset = (~rst_n) | (~ena);
    wire program_write = (~rst_n) & ena & ui_in[7];

    tiny8_top cpu (
        .clk(clk),
        .rst(cpu_reset),
        .port_in(ui_in),
        .prog_we(program_write),
        .prog_addr(ui_in[6:0]),
        .prog_data(uio_in),
        .port_out(uo_out),
        .debug_pc(debug_pc),
        .debug_ir(debug_ir),
        .debug_state(debug_state),
        .debug_flags(debug_flags),
        .debug_halted(debug_halted)
    );

    // Bidirectional bus is input during reset/programming, output at runtime.
    assign uio_out = debug_pc;
    assign uio_oe  = (rst_n && ena) ? 8'hFF : 8'h00;

    wire unused_inputs = ^{ui_in[6:0], uio_in, debug_ir, debug_state, debug_flags, debug_halted};
endmodule
