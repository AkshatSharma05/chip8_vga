/*
    START | D0 D1 D2 D3 D4 D5 D6 D7 | PARITY | STOP
    0       LSB first                 odd      1
*/

module ps2_receiver (
    input  wire       clk,
    input  wire       rst,

    input  wire       ps2_clk,
    input  wire       ps2_data,

    output reg [7:0]  scancode,
    output reg        scancode_valid
);

    // Synchronizers
    // the meta buffer is required to avoid metastability between the ps2 clk and 50 mhz fpga clk
    reg ps2_clk_meta, ps2_clk_sync, ps2_clk_prev;
    reg ps2_data_meta, ps2_data_sync;

    reg [3:0] bit_count;
    reg [10:0] shift_reg;
    reg [15:0] frame_timeout;

    wire ps2_clk_falling;

    assign ps2_clk_falling =
        ps2_clk_prev & ~ps2_clk_sync;


always @(posedge clk or negedge rst) begin
    if(!rst) begin
        ps2_clk_meta   <= 1'b1;
        ps2_clk_sync   <= 1'b1;
        ps2_clk_prev   <= 1'b1;

        ps2_data_meta  <= 1'b1;
        ps2_data_sync  <= 1'b1;

        bit_count      <= 4'd0;
        shift_reg      <= 11'd0;
        frame_timeout  <= 16'd0;

        scancode       <= 8'd0;
        scancode_valid <= 1'b0;
    end else begin
        // Synchronize PS/2 inputs
        ps2_clk_meta  <= ps2_clk;
        ps2_clk_sync  <= ps2_clk_meta;
        ps2_clk_prev  <= ps2_clk_sync;

        ps2_data_meta <= ps2_data;
        ps2_data_sync <= ps2_data_meta;

        scancode_valid <= 1'b0;

        // Recover if a frame stops before all 11 bits arrive.
        // 50,000 clocks is 1 ms at 50 MHz; normal PS/2 edges are much closer.
        if (bit_count != 0) begin
            if (frame_timeout == 16'd49_999) begin
                bit_count <= 4'd0;
                frame_timeout <= 16'd0;
            end else begin
                frame_timeout <= frame_timeout + 1'b1;
            end
        end else begin
            frame_timeout <= 16'd0;
        end

        // Sample on falling edge of PS/2 clock
        if (ps2_clk_falling) begin

            frame_timeout <= 16'd0;

            // Ignore an idle/noise edge unless it carries a low start bit.
            if ((bit_count != 0) || (ps2_data_sync == 1'b0)) begin
                shift_reg[bit_count] <= ps2_data_sync;

              if (bit_count == 4'd10) begin
                // bit 0  = start
                // bits 1-8 = data
                // bit 9  = parity
                // bit 10 = stop

                if ((shift_reg[0] == 1'b0) &&
                    (ps2_data_sync == 1'b1) &&
                    (^shift_reg[9:1])) begin

                    scancode <= shift_reg[8:1];
                    scancode_valid <= 1'b1;
                end

                bit_count <= 4'd0;
              end
              else begin
                bit_count <= bit_count + 1'b1;
              end
            end
        end
    end
end

endmodule
