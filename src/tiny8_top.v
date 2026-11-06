

module tiny8_top(
    input clk,
    input rst,
    input [7:0] port_in,
    input        prog_we,
    input [6:0]  prog_addr,
    input [7:0]  prog_data,
    output reg [7:0] port_out,
    output wire [7:0] debug_pc,
    output wire [15:0] debug_ir,
    output wire [3:0] debug_state,
    output wire [3:0] debug_flags,
    output reg debug_halted
);

// =====================================================
// OPCODES
// =====================================================

localparam OP_NOP  = 5'h00;
localparam OP_HLT  = 5'h01;
localparam OP_LDI  = 5'h02;
localparam OP_MOV  = 5'h03;
localparam OP_ADD  = 5'h04;
localparam OP_SUB  = 5'h05;
localparam OP_AND  = 5'h06;
localparam OP_OR   = 5'h07;
localparam OP_XOR  = 5'h08;
localparam OP_NOT  = 5'h09;
localparam OP_SHL  = 5'h0A;
localparam OP_SHR  = 5'h0B;
localparam OP_ADDI = 5'h0C;
localparam OP_SUBI = 5'h0D;
localparam OP_LDA  = 5'h0E;
localparam OP_STA  = 5'h0F;
localparam OP_JMP  = 5'h10;
localparam OP_JZ   = 5'h11;
localparam OP_JNZ  = 5'h12;
localparam OP_JC   = 5'h13;
localparam OP_JNC  = 5'h14;
localparam OP_JN   = 5'h15;
localparam OP_JV   = 5'h16;
localparam OP_JNV  = 5'h17;
localparam OP_CALL = 5'h18;
localparam OP_RET  = 5'h19;
localparam OP_PUSH = 5'h1A;
localparam OP_POP  = 5'h1B;
localparam OP_IN   = 5'h1C;
localparam OP_OUT  = 5'h1D;
localparam OP_CMP  = 5'h1E;
localparam OP_INC  = 5'h1F;

// =====================================================
// FSM STATES
// =====================================================

localparam FETCH          = 4'd0;
localparam FETCH_WAIT     = 4'd1;
localparam DECODE         = 4'd2;
localparam EXECUTE        = 4'd3;
localparam MEM_READ_WAIT  = 4'd4;
localparam MEM_WRITE      = 4'd5;
localparam MEM_READ_REQ   = 4'd6;
localparam STACK_PUSH     = 4'd7;
localparam STACK_POP_INC  = 4'd8;
localparam STACK_POP_REQ  = 4'd9;
localparam STACK_POP_WAIT = 4'd10;
localparam FETCH_START    = 4'd11;
localparam HALTED         = 4'd12;
localparam FETCH_LO       = 4'd13;
localparam FETCH_LO_WAIT  = 4'd14;

// =====================================================
// INTERNAL REGISTERS
// =====================================================

reg [7:0] PC;
reg [15:0] IR;

reg [7:0] registers [0:7];

reg [7:0] SP;
reg [3:0] FLAGS;

reg [3:0] state;

// Shared procedural loop variable.
// Used by the register-reset loop.
integer i;

// =====================================================
// SHARED GF180 SRAM: 128-byte data RAM + 128-byte program ROM
// =====================================================
// Physical macro: 256 x 8 bits.
// 0x00-0x7F: data and stack (128 bytes)
// 0x80-0xFF: program image (64 x 16-bit instructions)
// Program bytes are stored high-byte first, then low-byte.

reg [7:0] instruction_high;

// =====================================================
// SHARED SRAM INTERFACE
// =====================================================

wire [7:0] ram_data;
reg [7:0] ram_address;
reg [7:0] ram_write_data;
wire ram_read_enable;
wire ram_write_enable;

reg       sram_cen_n;
reg       sram_gwen_n;
reg [7:0] sram_wen_n;
reg [7:0] sram_address;
reg [7:0] sram_write_data;

// Instruction fetch reads two bytes from the upper 128-byte region.
// PC is an instruction index (0..63); each instruction is 16 bits.
assign ram_read_enable =
    (state == FETCH) ||
    (state == FETCH_LO) ||
    (state == MEM_READ_REQ) ||
    (state == STACK_POP_REQ);

assign ram_write_enable =
    (state == MEM_WRITE) ||
    (state == STACK_PUSH);

always @(*) begin
    ram_address = 8'h00;
    ram_write_data = 8'h00;

    case (state)
        FETCH: begin
            ram_address = 8'h80 | {PC[5:0], 1'b0};
        end
        FETCH_LO: begin
            ram_address = 8'h80 | {PC[5:0], 1'b1};
        end
        MEM_READ_REQ, MEM_WRITE: begin
            // Data pointers are restricted to 0x00-0x7F.
            ram_address = {1'b0, IR[6:0]};
        end
        STACK_PUSH, STACK_POP_REQ: begin
            ram_address = {1'b0, SP[6:0]};
        end
        default: begin
            ram_address = 8'h00;
        end
    endcase

    if (state == MEM_WRITE)
        ram_write_data = registers[IR[10:8]];
    else if (state == STACK_PUSH) begin
        if (IR[15:11] == OP_CALL)
            ram_write_data = PC;
        else
            ram_write_data = registers[IR[10:8]];
    end
end

// The carrier board loads program bytes while reset is asserted.
// prog_addr selects byte 0..127 within the upper SRAM half.
// Capture commands on the falling edge so macro controls are stable
// through the following rising-edge SRAM access.
always @(negedge clk) begin
    if (prog_we) begin
        sram_cen_n      <= 1'b0;
        sram_gwen_n     <= 1'b0;
        sram_wen_n      <= 8'h00;
        sram_address    <= 8'h80 | prog_addr;
        sram_write_data <= prog_data;
    end
    else if (rst) begin
        sram_cen_n      <= 1'b1;
        sram_gwen_n     <= 1'b1;
        sram_wen_n      <= 8'hFF;
        sram_address    <= 8'h00;
        sram_write_data <= 8'h00;
    end
    else if (ram_write_enable) begin
        sram_cen_n      <= 1'b0;
        sram_gwen_n     <= 1'b0;
        sram_wen_n      <= 8'h00;
        sram_address    <= ram_address;
        sram_write_data <= ram_write_data;
    end
    else if (ram_read_enable) begin
        sram_cen_n      <= 1'b0;
        sram_gwen_n     <= 1'b1;
        sram_wen_n      <= 8'hFF;
        sram_address    <= ram_address;
        sram_write_data <= 8'h00;
    end
    else begin
        sram_cen_n      <= 1'b1;
        sram_gwen_n     <= 1'b1;
        sram_wen_n      <= 8'hFF;
        sram_address    <= 8'h00;
        sram_write_data <= 8'h00;
    end
end


initial begin
    sram_cen_n = 1'b1;
    sram_gwen_n = 1'b1;
    sram_wen_n = 8'hFF;
    sram_address = 8'h00;
    sram_write_data = 8'h00;
end

gf180mcu_ocd_ip_sram__sram256x8m8wm1 data_ram (
    .CLK(clk),
    .CEN(sram_cen_n),
    .GWEN(sram_gwen_n),
    .WEN(sram_wen_n),
    .A(sram_address),
    .D(sram_write_data),
    .Q(ram_data)
);

// =====================================================
// ALU INPUTS
// =====================================================

wire [7:0] alu_lhs;
wire [7:0] alu_rhs;

wire [7:0] alu_result;
wire [3:0] alu_flags;

assign alu_lhs =
    (IR[15:11] == OP_ADDI ||
     IR[15:11] == OP_SUBI ||
     IR[15:11] == OP_INC)
    ? registers[IR[10:8]]
    : registers[IR[7:5]];

assign alu_rhs =
    (IR[15:11] == OP_ADDI ||
     IR[15:11] == OP_SUBI)
    ? IR[7:0]
    : (IR[15:11] == OP_INC)
    ? 8'd1
    : registers[IR[4:2]];

// =====================================================
// ALU
// =====================================================

reg [7:0] alu_out;
reg [3:0] flags_out;
reg [8:0] alu_temp;

always @(*) begin

    alu_out = 8'h00;
    flags_out = FLAGS;
    alu_temp = 9'h000;

    case (IR[15:11])

        OP_ADD, OP_ADDI: begin

            alu_temp =
                {1'b0, alu_lhs} + {1'b0, alu_rhs};

            alu_out = alu_temp[7:0];

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = alu_temp[8];
            flags_out[1] = alu_out[7];

            flags_out[0] =
                (~(alu_lhs[7] ^ alu_rhs[7])) &
                (alu_lhs[7] ^ alu_out[7]);

        end

        OP_SUB, OP_SUBI, OP_CMP: begin

            alu_temp =
                {1'b0, alu_lhs} - {1'b0, alu_rhs};

            alu_out = alu_temp[7:0];

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = (alu_lhs >= alu_rhs);
            flags_out[1] = alu_out[7];

            flags_out[0] =
                (alu_lhs[7] ^ alu_rhs[7]) &
                (alu_lhs[7] ^ alu_out[7]);

        end

        OP_INC: begin

            alu_temp =
                {1'b0, alu_lhs} + 9'd1;

            alu_out = alu_temp[7:0];

            flags_out[3] = (alu_out == 8'h00);
            flags_out[1] = alu_out[7];

            flags_out[0] =
                (alu_lhs == 8'h7F);

            // Carry is preserved for INC.

        end

        OP_AND: begin

            alu_out = alu_lhs & alu_rhs;

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = 1'b0;
            flags_out[1] = alu_out[7];
            flags_out[0] = 1'b0;

        end

        OP_OR: begin

            alu_out = alu_lhs | alu_rhs;

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = 1'b0;
            flags_out[1] = alu_out[7];
            flags_out[0] = 1'b0;

        end

        OP_XOR: begin

            alu_out = alu_lhs ^ alu_rhs;

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = 1'b0;
            flags_out[1] = alu_out[7];
            flags_out[0] = 1'b0;

        end

        OP_NOT: begin

            alu_out = ~registers[IR[7:5]];

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = 1'b0;
            flags_out[1] = alu_out[7];
            flags_out[0] = 1'b0;

        end

        OP_SHL: begin

            alu_out =
                {registers[IR[10:8]][6:0], 1'b0};

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = registers[IR[10:8]][7];
            flags_out[1] = alu_out[7];
            flags_out[0] = 1'b0;

        end

        OP_SHR: begin

            alu_out =
                {1'b0, registers[IR[10:8]][7:1]};

            flags_out[3] = (alu_out == 8'h00);
            flags_out[2] = registers[IR[10:8]][0];
            flags_out[1] = alu_out[7];
            flags_out[0] = 1'b0;

        end

        default: begin
            alu_out = 8'h00;
            flags_out = FLAGS;
        end

    endcase

end

assign alu_result = alu_out;
assign alu_flags = flags_out;

// =====================================================
// DEBUG OUTPUTS
// =====================================================

assign debug_pc = PC;
assign debug_ir = IR;
assign debug_state = state;
assign debug_flags = FLAGS;

// =====================================================
// MAIN CONTROL UNIT
// =====================================================

always @(posedge clk) begin

    if (rst) begin

        PC <= 8'h00;
        IR <= 16'h0000;
        SP <= 8'h7F;
        instruction_high <= 8'h00;
        FLAGS <= 4'b0000;
        port_out <= 8'h00;

        debug_halted <= 1'b0;

        // One bootstrap cycle ensures the first falling-edge SRAM read
        // command is issued after reset is released.
        state <= FETCH_START;

        for (i = 0; i < 8; i = i + 1)
            registers[i] <= 8'h00;

    end

    else begin

        case (state)

            FETCH_START: begin
                state <= FETCH;
            end

            FETCH: begin
                // SRAM high-byte read is launched by the registered
                // command on the falling edge.
                state <= FETCH_WAIT;
            end

            FETCH_WAIT: begin
                instruction_high <= ram_data;
                state <= FETCH_LO;
            end

            FETCH_LO: begin
                // Low-byte SRAM read is launched on the falling edge.
                state <= FETCH_LO_WAIT;
            end

            FETCH_LO_WAIT: begin
                IR <= {instruction_high, ram_data};
                PC <= {2'b00, (PC[5:0] + 6'd1)};
                state <= DECODE;
            end

            DECODE: begin
                state <= EXECUTE;
            end

            EXECUTE: begin

                case (IR[15:11])

                    OP_NOP: begin
                        state <= FETCH;
                    end

                    OP_HLT: begin

                        debug_halted <= 1'b1;
                        state <= HALTED;

                    end

                    OP_LDI: begin

                        registers[IR[10:8]] <= IR[7:0];

                        state <= FETCH;

                    end

                    OP_MOV: begin

                        registers[IR[10:8]] <=
                            registers[IR[7:5]];

                        state <= FETCH;

                    end

                    OP_ADD, OP_SUB,
                    OP_AND, OP_OR, OP_XOR,
                    OP_NOT, OP_SHL, OP_SHR,
                    OP_ADDI, OP_SUBI, OP_INC: begin

                        registers[IR[10:8]] <= alu_result;
                        FLAGS <= alu_flags;

                        state <= FETCH;

                    end

                    OP_CMP: begin

                        FLAGS <= alu_flags;

                        state <= FETCH;

                    end

                    OP_LDA: begin

                        state <= MEM_READ_REQ;

                    end

                    OP_STA: begin

                        state <= MEM_WRITE;

                    end

                    OP_JMP: begin

                        PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JZ: begin

                        if (FLAGS[3])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JNZ: begin

                        if (!FLAGS[3])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JC: begin

                        if (FLAGS[2])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JNC: begin

                        if (!FLAGS[2])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JN: begin

                        if (FLAGS[1])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JV: begin

                        if (FLAGS[0])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_JNV: begin

                        if (!FLAGS[0])
                            PC <= {2'b00, IR[8:3]};

                        state <= FETCH;

                    end

                    OP_CALL: begin

                        state <= STACK_PUSH;

                    end

                    OP_RET: begin

                        state <= STACK_POP_INC;

                    end

                    OP_PUSH: begin

                        state <= STACK_PUSH;

                    end

                    OP_POP: begin

                        state <= STACK_POP_INC;

                    end

                    OP_IN: begin

                        registers[IR[10:8]] <= port_in;

                        state <= FETCH;

                    end

                    OP_OUT: begin

                        port_out <= registers[IR[10:8]];

                        state <= FETCH;

                    end

                    default: begin

                        state <= FETCH;

                    end

                endcase

            end

            MEM_READ_REQ: begin
                state <= MEM_READ_WAIT;
            end

            MEM_READ_WAIT: begin

                registers[IR[10:8]] <= ram_data;

                state <= FETCH;

            end

            MEM_WRITE: begin
                state <= FETCH;
            end

            STACK_PUSH: begin

                SP <= SP - 8'd1;

                if (IR[15:11] == OP_CALL)
                    PC <= {2'b00, IR[8:3]};

                state <= FETCH;

            end

            STACK_POP_INC: begin

                SP <= SP + 8'd1;

                state <= STACK_POP_REQ;

            end

            STACK_POP_REQ: begin

                state <= STACK_POP_WAIT;

            end

            STACK_POP_WAIT: begin

                if (IR[15:11] == OP_RET)
                    PC <= ram_data;

                else
                    registers[IR[10:8]] <= ram_data;

                state <= FETCH;

            end

            HALTED: begin

                state <= HALTED;

            end

            default: begin

                state <= FETCH;

            end

        endcase

    end

end

endmodule
