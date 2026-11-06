`default_nettype none

module tt_um_godofstrategy_tiny8 (
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

    wire prog_we;
    wire [6:0] prog_addr;
    wire [7:0] prog_data;
    wire prog_busy;
    wire prog_ready;
    wire prog_full;

    wire external_reset = (~rst_n) | (~ena);
    wire prog_mode = uio_in[3];
    wire cpu_reset = external_reset | prog_mode | prog_busy;

    // SPI receiver is oversampled by clk; spi_sclk is not a clock.
    tiny8_spi_programmer programmer (
        .clk(clk),
        .rst(external_reset),
        .spi_sclk(uio_in[0]),
        .spi_mosi(uio_in[1]),
        .spi_cs_n(uio_in[2]),
        .prog_mode(prog_mode),
        .prog_we(prog_we),
        .prog_addr(prog_addr),
        .prog_data(prog_data),
        .prog_busy(prog_busy),
        .ready(prog_ready),
        .full(prog_full)
    );

    tiny8_top cpu (
        .clk(clk),
        .rst(cpu_reset),
        .port_in(ui_in),
        .prog_we(prog_we),
        .prog_addr(prog_addr),
        .prog_data(prog_data),
        .port_out(uo_out),
        .debug_pc(debug_pc),
        .debug_ir(debug_ir),
        .debug_state(debug_state),
        .debug_flags(debug_flags),
        .debug_halted(debug_halted)
    );

    // Programming mode:
    // uio[4] = READY, uio[5] = FULL, uio[7:6] = PC[7:6].
    // Execution mode:
    // uio[7:4] = PC[7:4], uio[2:0] = PC[2:0].
    // uio[3] remains an input in both modes (PROG_MODE).
    assign uio_out = prog_mode
                   ? {debug_pc[7:6], prog_full, prog_ready, 4'b0000}
                   : {debug_pc[7:4], 1'b0, debug_pc[2:0]};

    assign uio_oe = prog_mode ? 8'b11110000 : 8'b11110111;

    wire unused_signals = ^{
        debug_ir,
        debug_state,
        debug_flags,
        debug_halted
    };

endmodule

`default_nettype wire
