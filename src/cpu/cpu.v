module chip8_cpu (
    input clk,
    input rst,
    input instruction_tick,
    input [15:0] keys,

    //Memory Wires
    input  [7:0]  mem_read_data,
    output [11:0] mem_read_addr,
    
    output reg        mem_write_enable,
    output reg [11:0] mem_write_addr,
    output reg [7:0]  mem_write_data,

    //Display Wires
    input         display_collision,
    input         display_busy,

    output reg display_draw,
    output reg [5:0] display_x,
    output reg [4:0] display_y,
    output reg [7:0] display_sprite, //one row/byte of the sprite
    output reg    display_clear

);

localparam FETCH_HI_REQ     = 4'd0;
localparam FETCH_HI_WAIT    = 4'd1;
localparam FETCH_HI_CAPTURE = 4'd2;
localparam FETCH_LO_WAIT    = 4'd3;
localparam FETCH_LO_CAPTURE = 4'd4;
localparam EXECUTE          = 4'd5;
localparam DRAW_WAIT        = 4'd6;
localparam DRAW_CAPTURE     = 4'd7;
localparam DRAW_ISSUE       = 4'd8;
localparam DRAW_FINISH      = 4'd9;
localparam DRAW_COMPLETE    = 4'd10;
localparam CLEAR_ISSUE      = 4'd11;
localparam CLEAR_WAIT       = 4'd12;
localparam STORE_REGS       = 4'd13;
localparam LOAD_REGS_WAIT   = 4'd14;
localparam LOAD_REGS_CAPTURE = 4'd15;

reg [3:0] state;

//INTERNALS
reg [11:0] pc; //Program Counter
reg [15:0] ir; // Instruction Register
reg [7:0] V [0:15]; //16 V Registers
reg [11:0] I; //Index Register -> In order to specify the memory addresses containing the data for a given sprite, there must be some way to store an address for later use. The sixteen data registers (V0 - VF) provided by CHIP-8 are only eight bits in length, and therefore could only store addresses 00 to FF. Therefore, CHIP-8 provides a special register that is used only to store memory addresses.
reg [11:0] stack [0:15]; //Stack
reg [3:0] sp; //Stack Pointer

reg [7:0] delay_timer;
reg [7:0] sound_timer;

reg [7:0] opcode_hi;
reg [7:0] opcode_lo;

//INTERMEDIATES
reg [8:0] sum_temp; //9 bit addition intermediate to detect overflow
integer init_index;

reg [19:0] timer_div;
reg timer_tick;

reg [11:0] mem_addr;
assign mem_read_addr = mem_addr;

reg [3:0] draw_row;
reg [3:0] draw_height;
reg [5:0] draw_x_reg;
reg [4:0] draw_y_reg;
reg draw_collision_accum;

reg [7:0] lfsr;
reg [3:0] transfer_index;
reg [3:0] transfer_last;
integer key_index;
reg [3:0] pressed_key;
reg key_is_pressed;

// Select the lowest-numbered pressed CHIP-8 key.
always @* begin
    pressed_key = 4'h0;
    key_is_pressed = 1'b0;
    for (key_index = 0; key_index < 16; key_index = key_index + 1) begin
        if (!key_is_pressed && keys[key_index]) begin
            pressed_key = key_index[3:0];
            key_is_pressed = 1'b1;
        end
    end
end

always @(posedge clk or negedge rst)
    if(!rst)
        lfsr <= 8'hA5;
    else
        lfsr <= {lfsr[6:0],
                 lfsr[7]^lfsr[5]^lfsr[4]^lfsr[3]};

//60Hz timer generator
always @(posedge clk or negedge rst)
    if (!rst) begin
        timer_div  <= 0;
        timer_tick <= 0;
    end
    else begin
        if (timer_div == 20'd833332) begin
            timer_div  <= 0;
            timer_tick <= 1;
        end
        else begin
            timer_div  <= timer_div + 1;
            timer_tick <= 0;
        end
    end


always @(posedge clk or negedge rst)
    if(!rst) begin
        state <= FETCH_HI_REQ;
        pc <= 12'h200;
        mem_addr <= 12'h200;
        opcode_hi <= 8'h00;
        opcode_lo <= 8'h00;
        ir        <= 16'h0000;
        sp <= 4'd0;
        I <= 12'h000;
        delay_timer <= 8'd0;
        sound_timer <= 8'd0;

        mem_write_enable <= 1'b0;
        mem_write_addr   <= 12'h000;
        mem_write_data   <= 8'h00;

        display_clear <= 1'b0;
        display_draw <= 0;

        display_x <= 0;
        display_y <= 0;
        display_sprite <= 8'h00;
        draw_collision_accum <= 1'b0;
        transfer_index <= 4'd0;
        transfer_last <= 4'd0;

        for (init_index = 0; init_index < 16; init_index = init_index + 1) begin
            V[init_index] <= 8'h00;
            stack[init_index] <= 12'h000;
        end

    end else begin
        // Memory writes are single-clock pulses. An instruction that writes
        // RAM sets these three outputs in its execute state.
        mem_write_enable <= 1'b0;

        display_clear <= 1'b0;
        display_draw <= 1'b0;

        if (timer_tick) begin
            if (delay_timer != 0)
                delay_timer <= delay_timer - 1;

            if (sound_timer != 0)
                sound_timer <= sound_timer - 1;
        end

        case(state) 
            FETCH_HI_REQ: begin
                // Instruction pacing happens only between instructions.
                // Once started, all memory/draw microstates run at clk speed.
                if (instruction_tick) begin
                    mem_addr <= pc;
                    state <= FETCH_HI_WAIT;
                end
            end

            FETCH_HI_WAIT: begin
                state <= FETCH_HI_CAPTURE;
            end

            FETCH_HI_CAPTURE: begin
                opcode_hi <= mem_read_data;
                mem_addr <= pc + 12'd1;
                state <= FETCH_LO_WAIT;
            end

            FETCH_LO_WAIT: begin
                state <= FETCH_LO_CAPTURE;
            end

            FETCH_LO_CAPTURE: begin
                opcode_lo <= mem_read_data;
                ir <= {opcode_hi, mem_read_data};
                pc <= pc + 12'd2;
                state <= EXECUTE;
            end

            EXECUTE: begin
                // Most opcodes return to fetch. Multi-cycle opcodes below
                // override this default after decoding.
                state <= FETCH_HI_REQ;

                case(ir[15:12])

                    4'h0: begin
                        case(ir)
                            16'h00E0: begin
                                //CLS
                                display_clear <= 1;
                                state <= CLEAR_ISSUE;
                            end

                            16'h00EE: begin
                                sp <= sp - 1;
                                pc <= stack[sp - 1];
                                mem_addr <= stack[sp - 1];
                            end

                            default: begin
                                // Illegal or unimplemented opcode
                            end

                        endcase
                    end

                    4'h1: begin
                        pc <= ir[11:0];
                        mem_addr <= ir[11:0];
                    end

                    4'h2: begin
                        /*
                        It does two things:

                        Save the address of the next instruction on the stack.
                        Jump to the subroutine.
                        */

                        stack[sp] <= pc;
                        sp <= sp + 1;
                        pc <= ir[11:0];
                        mem_addr <= ir[11:0];
                    end

                    4'h3: begin
                        if(V[ir[11:8]] == ir[7:0]) begin
                            pc <= pc + 12'd2;
                            mem_addr <= pc + 12'd2;
                        end
                    end

                    4'h4: begin
                        if(V[ir[11:8]] != ir[7:0]) begin
                            pc <= pc + 12'd2;
                            mem_addr <= pc + 12'd2;
                        end
                    end

                    4'h5: begin
                        if (ir[3:0] == 4'h0) begin
                            if (V[ir[11:8]] == V[ir[7:4]]) begin
                                pc <= pc + 12'd2;
                                mem_addr <= pc + 12'd2;
                            end
                        end
                    end
                    
                    4'h6: begin
                        V[ ir[11:8] ] <= ir[7:0];
                    end

                    4'h7: begin
                        V[ ir[11:8] ] <= V[ ir[11:8] ] + ir[7:0];
                    end

                    4'h8: begin
                        case(ir[3:0])
                            4'h0: begin
                                V[ir[11:8]] <= V[ir[7:4]];
                            end

                            4'h1: begin
                                V[ir[11:8]] <= V[ir[11:8]] | V[ir[7:4]];
                            end

                            4'h2: begin
                                V[ir[11:8]] <= V[ir[11:8]] & V[ir[7:4]];
                            end

                            4'h3: begin
                                V[ir[11:8]] <= V[ir[11:8]] ^ V[ir[7:4]];
                            end

                            4'h4: begin
                                sum_temp = V[ir[11:8]] + V[ir[7:4]];
                                V[ir[11:8]] <= sum_temp[7:0];
                                V[15] <= {7'b0, sum_temp[8]};
                            end

                            4'h5: begin
                                V[ir[11:8]] <= V[ir[11:8]] - V[ir[7:4]];
                                V[15] <= {7'b0, (V[ir[11:8]] >= V[ir[7:4]])};
                            end

                            4'h6: begin
                                V[15] <= {7'b0, V[ir[11:8]][0]};
                                V[ir[11:8]] <= V[ir[11:8]] >> 1;
                            end

                            4'h7: begin
                                V[ir[11:8]] <= V[ir[7:4]] - V[ir[11:8]];
                                V[15] <= {7'b0, (V[ir[11:8]] <= V[ir[7:4]])};
                            end

                            4'hE: begin
                                V[15] <= {7'b0, V[ir[11:8]][7]};
                                V[ir[11:8]] <= V[ir[11:8]] << 1;
                            end

                            default: begin
                                //INVALID OPCODE
                            end
                        endcase
                    end

                    4'h9: begin
                        if (ir[3:0] == 4'h0) begin
                            if (V[ir[11:8]] != V[ir[7:4]]) begin
                                pc <= pc + 12'd2;
                                mem_addr <= pc + 12'd2;
                            end
                        end
                    end

                    4'hA: begin
                        I <= ir[11:0];
                    end

                    4'hB: begin
                        pc <= {4'b0, V[0]} + ir[11:0];
                        mem_addr <= {4'b0, V[0]} + ir[11:0];
                    end

                    4'hC: begin
                        V[ir[11:8]] <= lfsr & ir[7:0];
                    end

                    4'hD: begin
                        draw_row    <= 4'd0;
                        draw_height <= ir[3:0]; //N
                        draw_collision_accum <= 1'b0;

                        draw_x_reg  <= V[ir[11:8]][5:0]; //VX
                        draw_y_reg  <= V[ir[7:4]][4:0]; //VY

                        mem_addr <= I; //location of sprite

                        state <= DRAW_WAIT;
                    end

                    4'hE: begin
                        case (ir[7:0])
                            8'h9E: begin
                                if (keys[V[ir[11:8]][3:0]]) begin
                                    pc <= pc + 12'd2;
                                    mem_addr <= pc + 12'd2;
                                end
                            end

                            8'hA1: begin
                                if (!keys[V[ir[11:8]][3:0]]) begin
                                    pc <= pc + 12'd2;
                                    mem_addr <= pc + 12'd2;
                                end
                            end

                            default: begin
                            end
                        endcase
                    end

                    4'hF: begin
                        case(ir[7:0])
                            8'h07: begin
                                V[ir[11:8]] <= delay_timer;
                            end

                            8'h0A: begin
                                if (key_is_pressed) begin
                                    V[ir[11:8]] <= {4'h0, pressed_key};
                                end else begin
                                    // Repeat Fx0A until a key is pressed.
                                    pc <= pc - 12'd2;
                                    mem_addr <= pc - 12'd2;
                                end
                            end

                            8'h15: begin
                                delay_timer <= V[ir[11:8]];
                            end

                            8'h18: begin
                                sound_timer <= V[ir[11:8]];
                            end

                            8'h1E: begin
                                I <= I + {4'b0, V[ir[11:8]]};
                            end

                            8'h29: begin
                                I <= {4'b0,V[ir[11:8]]} * 12'd5;
                            end

                            8'h33: begin
                            end

                            8'h55: begin
                                // FX55: store V0 through VX at I..I+X.
                                // I is intentionally left unchanged.
                                transfer_index <= 4'd0;
                                transfer_last <= ir[11:8];
                                mem_write_addr <= I;
                                mem_write_data <= V[0];
                                mem_write_enable <= 1'b1;
                                state <= STORE_REGS;
                            end

                            8'h65: begin
                                // FX65: load V0 through VX from I..I+X.
                                // The RAM read port is synchronous, so each
                                // byte uses a wait state before capture.
                                transfer_index <= 4'd0;
                                transfer_last <= ir[11:8];
                                mem_addr <= I;
                                state <= LOAD_REGS_WAIT;
                            end

                            default: begin
                                //INVALID OPCODE
                            end
                        endcase
                    end

                    default: begin
                        state <= FETCH_HI_REQ;
                    end
                    
                endcase

            end

            DRAW_WAIT: begin
                state <= DRAW_CAPTURE;
            end

            DRAW_CAPTURE: begin
                if (!display_busy) begin
                    display_x <= draw_x_reg;
                    display_y <= draw_y_reg + draw_row;
                    display_sprite <= mem_read_data;
                    display_draw <= 1'b1;
                    state <= DRAW_ISSUE;
                end

            end

            DRAW_ISSUE: begin

                display_draw <= 1'b0;
                state <= DRAW_COMPLETE;
            end

            DRAW_COMPLETE: begin
                if (!display_busy) begin
                    draw_collision_accum <=
                        draw_collision_accum | display_collision;

                    if (draw_row + 1 == draw_height) begin
                        state <= DRAW_FINISH;
                    end else begin
                        draw_row <= draw_row + 1'b1;
                        mem_addr <= I + draw_row + 1'b1;
                        state <= DRAW_WAIT;
                    end
                end
            end

            CLEAR_ISSUE: begin
                display_clear <= 1'b0;
                state <= CLEAR_WAIT;
            end

            CLEAR_WAIT: begin
                if (!display_busy)
                    state <= FETCH_HI_REQ;
            end

            DRAW_FINISH: begin
                V[15] <= {7'b0, draw_collision_accum};

                // Sprite reads temporarily borrow the program-memory port.
                mem_addr <= pc;
                state <= FETCH_HI_REQ;
            end

            STORE_REGS: begin
                if (transfer_index == transfer_last) begin
                    mem_addr <= pc;
                    state <= FETCH_HI_REQ;
                end else begin
                    transfer_index <= transfer_index + 1'b1;
                    mem_write_addr <= I + {8'd0, transfer_index} + 12'd1;
                    mem_write_data <= V[transfer_index + 1'b1];
                    mem_write_enable <= 1'b1;
                end
            end

            LOAD_REGS_WAIT: begin
                state <= LOAD_REGS_CAPTURE;
            end

            LOAD_REGS_CAPTURE: begin
                V[transfer_index] <= mem_read_data;

                if (transfer_index == transfer_last) begin
                    mem_addr <= pc;
                    state <= FETCH_HI_REQ;
                end else begin
                    transfer_index <= transfer_index + 1'b1;
                    mem_addr <= I + {8'd0, transfer_index} + 12'd1;
                    state <= LOAD_REGS_WAIT;
                end
            end

            default: begin
                state <= FETCH_HI_REQ;
                pc <= 12'h200;
                mem_addr <= 12'h200;
            end
        endcase

    end
    

endmodule
