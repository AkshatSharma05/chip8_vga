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

    $readmemh(ROM_FILE, mem, 12'h200);
end

always @(posedge clk) begin
    read_data_reg <= mem[read_addr];

    if (write_enable)
        mem[write_addr] <= write_data;
end

endmodule
