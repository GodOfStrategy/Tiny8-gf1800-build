// Functional simulation model for the GF180 256x8 SRAM interface.
// Use this file for RTL simulation only. Do NOT include it in synthesis;
// physical implementation must use the GF180 macro LEF/GDS/lib and blackbox.
module gf180mcu_ocd_ip_sram__sram256x8m8wm1 (
    input wire CLK,
    input wire CEN,
    input wire GWEN,
    input wire [7:0] WEN,
    input wire [7:0] A,
    input wire [7:0] D,
    output reg [7:0] Q
);
    reg [7:0] mem [0:255];
    integer k;
    initial begin
        Q = 8'h00;
        for (k = 0; k < 256; k = k + 1)
            mem[k] = 8'h00;
    end
    always @(posedge CLK) begin
        if (!CEN) begin
            if (!GWEN) begin
                if (!WEN[0]) mem[A][0] <= D[0];
                if (!WEN[1]) mem[A][1] <= D[1];
                if (!WEN[2]) mem[A][2] <= D[2];
                if (!WEN[3]) mem[A][3] <= D[3];
                if (!WEN[4]) mem[A][4] <= D[4];
                if (!WEN[5]) mem[A][5] <= D[5];
                if (!WEN[6]) mem[A][6] <= D[6];
                if (!WEN[7]) mem[A][7] <= D[7];
            end else begin
                Q <= mem[A];
            end
        end
    end
endmodule
