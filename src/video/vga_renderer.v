module vga_renderer(
    input clk,
    input rst,
    input tick_25MHZ,

    input video_active,
    input frame_start,
    input line_start,

    input [9:0] hcount,
    input [9:0] vcount,

    input pixel_on,
    output [5:0] chip_x,
    output [4:0] chip_y,

    output r,
    output g,
    output b
);

    localparam WHITE = 3'b111;
    localparam BLACK = 3'b000;
    localparam DISPLAY_TOP = 10'd80;

    reg [2:0] rgb;

    assign r = rgb[2];
    assign g = rgb[1];
    assign b = rgb[0];

    wire display_active;

    wire [9:0] chip_x_tmp;
    wire [9:0] chip_y_tmp;

    assign chip_x_tmp = hcount / 10;
    assign chip_y_tmp = (vcount - DISPLAY_TOP) / 10;

    assign chip_x = display_active ? chip_x_tmp[5:0] : 6'd0;
    assign chip_y = display_active ? chip_y_tmp[4:0] : 5'd0;

    assign display_active = (hcount < 10'd640) &&
                            (vcount >= DISPLAY_TOP) &&
                            (vcount < DISPLAY_TOP + 10'd320);

    // Register the DAC-facing signals. The framebuffer lookup and the /10
    // coordinate scaling are sizeable combinational paths; exposing them
    // directly on the VGA pins lets decode hazards become visible streaks.
    // Holding RGB for the complete pixel-enable interval removes those
    // sub-pixel glitches.
    always @(posedge clk or negedge rst) begin
        if (!rst)
            rgb <= BLACK;
        else if (tick_25MHZ) begin
            if (video_active && display_active && pixel_on)
                rgb <= WHITE;
            else
                rgb <= BLACK;
        end
    end

endmodule
