`timescale 1ns/1ps
`default_nettype none

module tb_spi;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ena = 1'b1;
    reg [7:0] ui_in = 8'h00;
    reg [7:0] uio_in = 8'h0C; // PROG_MODE=1, CS_N=1, SCLK=0
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    integer i;
    integer j;

    always #50 clk = ~clk; // 10 MHz system clock

    tt_um_godofstrategy_tiny8 dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // SPI mode 0, MSB first. 2 us period = 500 kHz.
    task send_byte(input [7:0] value);
        begin
            for (j = 7; j >= 0; j = j - 1) begin
                uio_in[1] = value[j];
                #1000;
                uio_in[0] = 1'b1;
                #1000;
                if (j == 7) begin
                    // Confirm the receiver has started this byte.
                    wait (uio_out[4] == 1'b0);
                end
                uio_in[0] = 1'b0;
            end

            // READY returns high only after the byte's SRAM write.
            wait (uio_out[4] == 1'b1);
        end
    endtask

    initial begin
        $dumpfile("tiny8_spi.vcd");
        $dumpvars(0, tb_spi);

        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // Allow PROG_MODE to pass through the input synchronizer.
        repeat (5) @(posedge clk);
        if (uio_out[4] !== 1'b1)
            $fatal(1, "READY did not assert at start of programming");

        // Select the SPI programmer and load:
        // LDI R0,5; LDI R1,3; ADD R2,R0,R1; OUT R2; HLT
        uio_in[2] = 1'b0;
        send_byte(8'h10);
        send_byte(8'h05);
        send_byte(8'h11);
        send_byte(8'h03);
        send_byte(8'h22);
        send_byte(8'h04);
        send_byte(8'hEA);
        send_byte(8'h00);
        send_byte(8'h08);
        send_byte(8'h00);

        // End programming. The synchronized mode signal keeps the CPU
        // reset asserted until the programmer has safely exited.
        uio_in[2] = 1'b1;
        uio_in[3] = 1'b0;

        for (i = 0; i < 500; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut.cpu.debug_halted) begin
                if (dut.cpu.registers[0] !== 8'h05)
                    $fatal(1, "R0 mismatch: %h", dut.cpu.registers[0]);
                if (dut.cpu.registers[1] !== 8'h03)
                    $fatal(1, "R1 mismatch: %h", dut.cpu.registers[1]);
                if (dut.cpu.registers[2] !== 8'h08)
                    $fatal(1, "R2 mismatch: %h", dut.cpu.registers[2]);
                if (uo_out !== 8'h08)
                    $fatal(1, "port_out mismatch: %h", uo_out);
                $display("PASS: SPI loaded 10 bytes into Tiny8 SRAM and CPU executed program.");
                $finish;
            end
        end

        $fatal(1, "Timeout: Tiny8 did not halt. PC=%h IR=%h state=%h",
               dut.cpu.debug_pc, dut.cpu.debug_ir, dut.cpu.debug_state);
    end
endmodule

`default_nettype wire
