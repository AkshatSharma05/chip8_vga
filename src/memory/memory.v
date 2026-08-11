/*
 * 4 KiB CHIP-8 memory.
 *
 * ROM_FILE is a whitespace-separated hexadecimal byte file. Its first byte
 * is loaded at the standard CHIP-8 program address 0x200. For example:
 *
 *   00
 *   E0
 *   12
 *   00
 *
 * is equivalent to the byte sequence 00 E0 12 00.
 */
module chip8_memory #(
    parameter ROM_FILE = "roms/rom.hex"
) (
    input clk,

    input  [11:0] read_addr,
    output [7:0]  read_data,

    input         write_enable,
    input  [11:0] write_addr,
    input  [7:0]  write_data
);

reg [7:0] mem [0:4095];
reg [7:0] read_data_reg;
integer init_address;

assign read_data = read_data_reg;

initial begin
    for (init_address = 0; init_address < 4096;
         init_address = init_address + 1)
        mem[init_address] = 8'h00;

    // External ROM disabled while testing the PS/2 keyboard.
    $readmemh(ROM_FILE, mem, 12'h200);

    // // Standard CHIP-8 hexadecimal font, used by Fx29 (addresses 0x000-0x04F).
    // mem[12'h000] = 8'hF0; mem[12'h001] = 8'h90; mem[12'h002] = 8'h90; mem[12'h003] = 8'h90; mem[12'h004] = 8'hF0;
    // mem[12'h005] = 8'h20; mem[12'h006] = 8'h60; mem[12'h007] = 8'h20; mem[12'h008] = 8'h20; mem[12'h009] = 8'h70;
    // mem[12'h00A] = 8'hF0; mem[12'h00B] = 8'h10; mem[12'h00C] = 8'hF0; mem[12'h00D] = 8'h80; mem[12'h00E] = 8'hF0;
    // mem[12'h00F] = 8'hF0; mem[12'h010] = 8'h10; mem[12'h011] = 8'hF0; mem[12'h012] = 8'h10; mem[12'h013] = 8'hF0;
    // mem[12'h014] = 8'h90; mem[12'h015] = 8'h90; mem[12'h016] = 8'hF0; mem[12'h017] = 8'h10; mem[12'h018] = 8'h10;
    // mem[12'h019] = 8'hF0; mem[12'h01A] = 8'h80; mem[12'h01B] = 8'hF0; mem[12'h01C] = 8'h10; mem[12'h01D] = 8'hF0;
    // mem[12'h01E] = 8'hF0; mem[12'h01F] = 8'h80; mem[12'h020] = 8'hF0; mem[12'h021] = 8'h90; mem[12'h022] = 8'hF0;
    // mem[12'h023] = 8'hF0; mem[12'h024] = 8'h10; mem[12'h025] = 8'h20; mem[12'h026] = 8'h40; mem[12'h027] = 8'h40;
    // mem[12'h028] = 8'hF0; mem[12'h029] = 8'h90; mem[12'h02A] = 8'hF0; mem[12'h02B] = 8'h90; mem[12'h02C] = 8'hF0;
    // mem[12'h02D] = 8'hF0; mem[12'h02E] = 8'h90; mem[12'h02F] = 8'hF0; mem[12'h030] = 8'h10; mem[12'h031] = 8'hF0;
    // mem[12'h032] = 8'hF0; mem[12'h033] = 8'h90; mem[12'h034] = 8'hF0; mem[12'h035] = 8'h90; mem[12'h036] = 8'h90;
    // mem[12'h037] = 8'hE0; mem[12'h038] = 8'h90; mem[12'h039] = 8'hE0; mem[12'h03A] = 8'h90; mem[12'h03B] = 8'hE0;
    // mem[12'h03C] = 8'hF0; mem[12'h03D] = 8'h80; mem[12'h03E] = 8'h80; mem[12'h03F] = 8'h80; mem[12'h040] = 8'hF0;
    // mem[12'h041] = 8'hE0; mem[12'h042] = 8'h90; mem[12'h043] = 8'h90; mem[12'h044] = 8'h90; mem[12'h045] = 8'hE0;
    // mem[12'h046] = 8'hF0; mem[12'h047] = 8'h80; mem[12'h048] = 8'hF0; mem[12'h049] = 8'h80; mem[12'h04A] = 8'hF0;
    // mem[12'h04B] = 8'hF0; mem[12'h04C] = 8'h80; mem[12'h04D] = 8'hF0; mem[12'h04E] = 8'h80; mem[12'h04F] = 8'h80;

    // // Keyboard test: wait for a key, clear, and draw its hexadecimal glyph.
    // mem[12'h200] = 8'h00; mem[12'h201] = 8'hE0; // CLS
    // mem[12'h202] = 8'hF0; mem[12'h203] = 8'h0A; // wait for key -> V0
    // mem[12'h204] = 8'h00; mem[12'h205] = 8'hE0; // CLS
    // mem[12'h206] = 8'h61; mem[12'h207] = 8'h1E; // V1 = 30 (x)
    // mem[12'h208] = 8'h62; mem[12'h209] = 8'h0E; // V2 = 14 (y)
    // mem[12'h20A] = 8'hF0; mem[12'h20B] = 8'h29; // I = glyph for V0
    // mem[12'h20C] = 8'hD1; mem[12'h20D] = 8'h25; // draw 5-byte glyph
    // mem[12'h20E] = 8'h12; mem[12'h20F] = 8'h02; // wait for next key
end

always @(posedge clk) begin
    read_data_reg <= mem[read_addr];

    if (write_enable)
        mem[write_addr] <= write_data;
end

endmodule
