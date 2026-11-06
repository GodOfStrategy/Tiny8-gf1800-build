`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 1;
    reg [7:0] port_in = 0;
    reg prog_we = 0;
    reg [6:0] prog_addr = 0;
    reg [7:0] prog_data = 0;
    wire [7:0] port_out;
    wire [7:0] debug_pc;
    wire [15:0] debug_ir;
    wire [3:0] debug_state;
    wire [3:0] debug_flags;
    wire debug_halted;
    integer n;

    always #30 clk = ~clk; // 60 ns period for GF180 SRAM timing

    tiny8_top dut (
        .clk(clk), .rst(rst), .port_in(port_in),
        .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data),
        .port_out(port_out), .debug_pc(debug_pc), .debug_ir(debug_ir),
        .debug_state(debug_state), .debug_flags(debug_flags),
        .debug_halted(debug_halted)
    );

    // Program: LDI R0,5; LDI R1,3; ADD R2,R0,R1; OUT R2; HLT
    // Each instruction is loaded high byte first into byte offsets 0..9.
    task write_program_byte(input [6:0] a, input [7:0] d);
        begin
            // Change the bus just after a rising edge. The core captures
            // the write command on the next falling edge and the SRAM
            // commits it on the following rising edge.
            @(posedge clk);
            prog_addr = a;
            prog_data = d;
            prog_we = 1;
            @(posedge clk);
            #1 prog_we = 0;
        end
    endtask

    initial begin
        $dumpfile("tiny8_shared_sram.vcd");
        $dumpvars(0, tb);

        // Hold reset while loading the upper half of the SRAM.
        repeat (2) @(negedge clk);
        write_program_byte(0, 8'h10);
        write_program_byte(1, 8'h05);
        write_program_byte(2, 8'h11);
        write_program_byte(3, 8'h03);
        write_program_byte(4, 8'h22);
        write_program_byte(5, 8'h04);
        write_program_byte(6, 8'hEA);
        write_program_byte(7, 8'h00);
        write_program_byte(8, 8'h08);
        write_program_byte(9, 8'h00);

        // Allow the last write to complete, then start execution.
        repeat (2) @(negedge clk);
        rst = 0;

        for (n = 0; n < 300; n = n + 1) begin
            @(negedge clk);
            if (debug_halted) begin
                if (dut.registers[0] !== 8'h05) $fatal(1, "R0 mismatch: %h", dut.registers[0]);
                if (dut.registers[1] !== 8'h03) $fatal(1, "R1 mismatch: %h", dut.registers[1]);
                if (dut.registers[2] !== 8'h08) $fatal(1, "R2 mismatch: %h", dut.registers[2]);
                if (port_out !== 8'h08) $fatal(1, "port_out mismatch: %h", port_out);
                if (debug_pc !== 8'h05) $fatal(1, "PC mismatch: %h", debug_pc);
                if (debug_ir !== 16'h0800) $fatal(1, "IR mismatch: %h", debug_ir);
                $display("PASS: program loaded into SRAM ROM half and executed; data RAM half remains separate.");
                $finish;
            end
        end
        $fatal(1, "Timeout waiting for HLT; PC=%h IR=%h state=%h", debug_pc, debug_ir, debug_state);
    end
endmodule
