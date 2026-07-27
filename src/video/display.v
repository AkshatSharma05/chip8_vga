module display (
    input clk,
    input rst,
    input tick_25MHz,

    input [5:0] chip_x,
    input [4:0] chip_y,

    input clear,

    input draw,

    input [5:0] draw_x,
    input [4:0] draw_y,

    input [7:0] draw_sprite,

    output reg busy,
    output reg collision,

    output pixel_on
);

// 32 rows × 64 columns
reg framebuffer [0:31][0:63];

//verilog integers are 32 bits
integer x;
integer y;
integer i;

assign pixel_on = framebuffer[chip_y][chip_x];

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        busy <= 1'b0;
        collision <= 1'b0;

        for (y = 0; y < 32; y = y + 1)
            for (x = 0; x < 64; x = x + 1)
                framebuffer[y][x] <= 1'b0;

    end
    else if (clear) begin
        busy <= 1'b0;

        for (y = 0; y < 32; y = y + 1)
            for (x = 0; x < 64; x = x + 1)
                framebuffer[y][x] <= 1'b0;

    end
    else if (draw) begin
        busy <= 1'b0;
        collision <= 1'b0;

        for (i = 0; i < 8; i = i + 1) begin
            if ((draw_x + i) < 64) begin
                if (framebuffer[draw_y][draw_x + i] &&
                    draw_sprite[7-i])
                    collision <= 1'b1;

                framebuffer[draw_y][draw_x + i] <=
                    framebuffer[draw_y][draw_x + i] ^
                    draw_sprite[7-i];
            end
        end
    end
end

endmodule