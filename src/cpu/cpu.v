module chip8_cpu (
    input clk,
    input rst,

    //Memory Wires
    input  [7:0]  mem_read_data,
    output [11:0] mem_read_addr,

    //Display Wires
    input         display_collision,
    input         display_busy,

    output reg display_draw,
    output reg [5:0] display_x,
    output reg [4:0] display_y,
    output reg [7:0] display_sprite, //one row/byte of the sprite
    output reg    display_clear

);

localparam FETCH_HI   = 3'd0;
localparam FETCH_LO   = 3'd1;
localparam LOAD       = 3'd2;
localparam EXECUTE    = 3'd3;
localparam DRAW_READ  = 3'd4;
localparam DRAW_ISSUE = 3'd5;

reg [2:0] state;

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
        state <= FETCH_HI;
        pc <= 12'h200;
        mem_addr <= 12'h200;
        opcode_hi <= 8'h00;
        opcode_lo <= 8'h00;
        ir        <= 16'h0000;
        sp <= 4'd0;
        I <= 12'h000;
        delay_timer <= 8'd0;
        sound_timer <= 8'd0;

        display_clear <= 1'b0;
        display_draw <= 0;

        display_x <= 0;
        display_y <= 0;
        display_sprite <= 8'h00;

        for (init_index = 0; init_index < 16; init_index = init_index + 1) begin
            V[init_index] <= 8'h00;
            stack[init_index] <= 12'h000;
        end

    end else begin
        display_clear <= 1'b0;
        display_draw <= 1'b0;

        if (timer_tick) begin
            if (delay_timer != 0)
                delay_timer <= delay_timer - 1;

            if (sound_timer != 0)
                sound_timer <= sound_timer - 1;
        end

        case(state) 
            FETCH_HI: begin
                opcode_hi <= mem_read_data;
                pc <= pc + 12'd1;
                mem_addr <= pc + 12'd1;
                state <= FETCH_LO;
            end

            FETCH_LO: begin
                opcode_lo <= mem_read_data;
                pc <= pc + 12'd1;
                mem_addr <= pc + 12'd1;
                state <= LOAD;
            end

            LOAD: begin
                ir <= {opcode_hi, opcode_lo};

                state <= EXECUTE;
            end

            EXECUTE: begin
                // Most opcodes return to fetch. Multi-cycle opcodes below
                // override this default after decoding.
                state <= FETCH_HI;

                case(ir[15:12])

                    4'h0: begin
                        case(ir)
                            16'h00E0: begin
                                //CLS
                                display_clear <= 1;
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
                        // V[ir[11:8]] <=
                    end

                    4'hD: begin
                        draw_row    <= 4'd0;
                        draw_height <= ir[3:0];

                        draw_x_reg  <= V[ir[11:8]][5:0];
                        draw_y_reg  <= V[ir[7:4]][4:0];

                        mem_addr <= I;

                        state <= DRAW_READ;
                    end

                    4'hE: begin
                    end

                    4'hF: begin
                        case(ir[7:0])
                            8'h07: begin
                                V[ir[11:8]] <= delay_timer;
                            end

                            8'h0A: begin
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
                            end

                            8'h33: begin
                            end

                            8'h55: begin
                            end

                            8'h65: begin
                            end

                            default: begin
                                //INVALID OPCODE
                            end
                        endcase
                    end

                    default: begin
                        state <= FETCH_HI;
                    end
                    
                endcase

            end

            DRAW_READ: begin

                display_x <= draw_x_reg;
                display_y <= draw_y_reg + draw_row;

                display_sprite <= mem_read_data;

                display_draw <= 1'b1;

                state <= DRAW_ISSUE;

            end

            DRAW_ISSUE: begin

                display_draw <= 1'b0;

                if (draw_row + 1 == draw_height) begin

                    V[15] <= {7'b0, display_collision};

                    // Sprite reads temporarily borrow the program-memory
                    // address port. Resume fetching at the current PC;
                    // otherwise sprite bytes are executed as opcodes and
                    // the XOR sprite is redrawn (toggled) repeatedly.
                    mem_addr <= pc;
                    state <= FETCH_HI;

                end
                else begin

                    draw_row <= draw_row + 1;

                    mem_addr <= I + draw_row + 1;

                    state <= DRAW_READ;

                end

            end

            default: begin
                state <= FETCH_HI;
                pc <= 12'h200;
                mem_addr <= 12'h200;
            end
        endcase

    end
    

endmodule
