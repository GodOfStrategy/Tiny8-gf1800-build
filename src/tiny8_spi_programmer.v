`default_nettype none

// SPI programmer for Tiny8.
//
// SPI mode 0, MSB first. The 10 MHz system clock oversamples SCLK;
// SCLK is NOT used as a clock. Keep external SPI at 500 kHz or slower
// for the initial implementation.
//
// uio[0] = SCLK
// uio[1] = MOSI
// uio[2] = CS_N
// uio[3] = PROG_MODE
// READY is asserted after each byte write has completed.
// FULL is asserted after 128 program bytes have been written.

module tiny8_spi_programmer (
    input  wire       clk,
    input  wire       rst,
    input  wire       spi_sclk,
    input  wire       spi_mosi,
    input  wire       spi_cs_n,
    input  wire       prog_mode,

    output reg        prog_we,
    output reg [6:0]  prog_addr,
    output reg [7:0]  prog_data,
    output wire       prog_busy,
    output wire       ready,
    output reg        full
);

    reg sclk_meta, sclk_sync, sclk_prev;
    reg mosi_meta, mosi_sync;
    reg cs_meta, cs_sync;
    reg mode_meta, mode_sync, mode_prev;

    reg [7:0] shift_reg;
    reg [3:0] bit_count;
    reg [7:0] byte_count;

    wire sclk_rise = sclk_sync & ~sclk_prev;

    // Keep the CPU in reset for the whole programming session and
    // until any final SRAM write pulse has completed.
    assign prog_busy = mode_sync | prog_we;
    assign ready = mode_sync & ~prog_we;

    always @(posedge clk) begin
        if (rst) begin
            sclk_meta <= 1'b0;
            sclk_sync <= 1'b0;
            sclk_prev <= 1'b0;
            mosi_meta <= 1'b0;
            mosi_sync <= 1'b0;
            cs_meta <= 1'b1;
            cs_sync <= 1'b1;
            mode_meta <= 1'b0;
            mode_sync <= 1'b0;
            mode_prev <= 1'b0;

            shift_reg <= 8'h00;
            bit_count <= 4'd0;
            byte_count <= 8'd0;
            prog_we <= 1'b0;
            prog_addr <= 7'd0;
            prog_data <= 8'h00;
            full <= 1'b0;
        end else begin
            // Two-flop input synchronizers into the system clock domain.
            sclk_meta <= spi_sclk;
            sclk_sync <= sclk_meta;
            sclk_prev <= sclk_sync;

            mosi_meta <= spi_mosi;
            mosi_sync <= mosi_meta;

            cs_meta <= spi_cs_n;
            cs_sync <= cs_meta;

            mode_meta <= prog_mode;
            mode_sync <= mode_meta;
            mode_prev <= mode_sync;

            // prog_we lasts one complete system-clock period. tiny8_top
            // captures it on the falling edge and the SRAM commits on
            // the next rising edge.
            if (prog_we)
                prog_we <= 1'b0;

            // A new programming session starts its byte address at zero.
            if (mode_sync && !mode_prev) begin
                shift_reg <= 8'h00;
                bit_count <= 4'd0;
                byte_count <= 8'd0;
                full <= 1'b0;
                prog_we <= 1'b0;
            end else if (!mode_sync) begin
                bit_count <= 4'd0;
                shift_reg <= 8'h00;
            end else if (cs_sync) begin
                // Discard an incomplete byte when chip-select is inactive.
                bit_count <= 4'd0;
                shift_reg <= 8'h00;
            end else if (sclk_rise && !prog_we && !full) begin
                shift_reg <= {shift_reg[6:0], mosi_sync};

                if (bit_count == 4'd7) begin
                    // The eighth sampled bit completes one byte.
                    prog_data <= {shift_reg[6:0], mosi_sync};
                    prog_addr <= byte_count[6:0];
                    prog_we <= 1'b1;
                    bit_count <= 4'd0;

                    if (byte_count == 8'd127) begin
                        byte_count <= 8'd128;
                        full <= 1'b1;
                    end else begin
                        byte_count <= byte_count + 8'd1;
                    end
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end
        end
    end

endmodule

`default_nettype wire
