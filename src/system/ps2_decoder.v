// Make code -> key pressed
// Break code -> key released
// ex - 1C       → A pressed
// F0 1C    → A released

module ps2_decoder (
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] scancode,
    input  wire       scancode_valid,

    output reg [15:0] keys
);

reg break_code;

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        keys       <= 16'd0;
        break_code <= 1'b0;
    end else if (scancode_valid) begin
        if (scancode == 8'hF0) begin
            break_code <= 1'b1;
        end

        else begin

            if (!break_code) begin

                case (scancode)

                    // Physical keyboard:  1 2 3 4  Q W E R  A S D F  Z X C V
                    // CHIP-8 keypad:       1 2 3 C  4 5 6 D  7 8 9 E  A 0 B F
                    8'h16: keys[4'h1] <= 1'b1; // 1
                    8'h1E: keys[4'h2] <= 1'b1; // 2
                    8'h26: keys[4'h3] <= 1'b1; // 3
                    8'h25: keys[4'hC] <= 1'b1; // 4
                    8'h15: keys[4'h4] <= 1'b1; // Q
                    8'h1D: keys[4'h5] <= 1'b1; // W
                    8'h24: keys[4'h6] <= 1'b1; // E
                    8'h2D: keys[4'hD] <= 1'b1; // R
                    8'h1C: keys[4'h7] <= 1'b1; // A
                    8'h1B: keys[4'h8] <= 1'b1; // S
                    8'h23: keys[4'h9] <= 1'b1; // D
                    8'h2B: keys[4'hE] <= 1'b1; // F
                    8'h1A: keys[4'hA] <= 1'b1; // Z
                    8'h22: keys[4'h0] <= 1'b1; // X
                    8'h21: keys[4'hB] <= 1'b1; // C
                    8'h2A: keys[4'hF] <= 1'b1; // V

                    default: ;
                endcase

            end

            else begin

                case (scancode)

                    8'h16: keys[4'h1] <= 1'b0;
                    8'h1E: keys[4'h2] <= 1'b0;
                    8'h26: keys[4'h3] <= 1'b0;
                    8'h25: keys[4'hC] <= 1'b0;
                    8'h15: keys[4'h4] <= 1'b0;
                    8'h1D: keys[4'h5] <= 1'b0;
                    8'h24: keys[4'h6] <= 1'b0;
                    8'h2D: keys[4'hD] <= 1'b0;
                    8'h1C: keys[4'h7] <= 1'b0;
                    8'h1B: keys[4'h8] <= 1'b0;
                    8'h23: keys[4'h9] <= 1'b0;
                    8'h2B: keys[4'hE] <= 1'b0;
                    8'h1A: keys[4'hA] <= 1'b0;
                    8'h22: keys[4'h0] <= 1'b0;
                    8'h21: keys[4'hB] <= 1'b0;
                    8'h2A: keys[4'hF] <= 1'b0;

                    default: ;
                endcase

                break_code <= 1'b0;
            end
        end
    end
    
end

endmodule
