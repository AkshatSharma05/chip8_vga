/*
the CHIP-8 interpreter itself occupies the first 512 bytes of the memory space on these machines. 
For this reason, most programs written for the original system begin at memory location 512 (0x200)
 and do not access any of the memory below the location 512 (0x200). 
The uppermost 256 bytes (0xF00-0xFFF) are reserved for display refresh, 
 and the 96 bytes below that (0xEA0-0xEFF) were reserved for the call stack, internal use, and other variables.

In modern CHIP-8 implementations, 
where the interpreter is running natively outside the 4K memory space, 
there is no need to avoid the lower 512 bytes of memory (0x000-0x1FF), 
and it is common to store font data there.
*/

module chip8_memory(

    input clk,

    // Read
    input  [11:0] read_addr,
    output [7:0]  read_data,

    // Write
    input         write_enable,
    input  [11:0] write_addr,
    input  [7:0]  write_data

);

reg [7:0] mem [0:4095]; // 4K memory locations, 8 bits each
assign read_data = mem[read_addr];

integer init_address;

initial begin
    // Give every location a deterministic value. Leaving most of this
    // asynchronous ROM uninitialized causes Quartus to turn the X entries
    // into don't-cares and optimize the CPU/display path away.
    for (init_address = 0; init_address < 4096; init_address = init_address + 1)
        mem[init_address] = 8'h00;

    //all instructions are 2 bytes long
    // V0 = 20
    mem[12'h200] = 8'h60;
    mem[12'h201] = 8'h14;

    // V1 = 10
    mem[12'h202] = 8'h61;
    mem[12'h203] = 8'h0A;

    // I = 0x300
    mem[12'h204] = 8'hA3;
    mem[12'h205] = 8'h00;

    // DRW V0,V1,5
    mem[12'h206] = 8'hD0;
    mem[12'h207] = 8'h15;

    // loop forever
    mem[12'h208] = 8'h12;
    mem[12'h209] = 8'h08;

    mem[12'h300] = 8'hF0;
    mem[12'h301] = 8'h90;
    mem[12'h302] = 8'h90;
    mem[12'h303] = 8'hF0;
    mem[12'h304] = 8'h90;
end

always @(posedge clk)
    if(write_enable)
        mem[write_addr] <= write_data;

endmodule
