/*
    TARGET: 640x480 @ 60 FPS

    -> HORIZONTAL
        - Visible: 640
        - Front Porch: 16
        - HSYNC: 96         #The Sync signals are pulled low to signal the end of the line (or end of frame for vsync)
        - Back Porch: 48
        - TOTAL: 800 Pixel Clock Cycles

    -> VERTICAL
        - Visible: 480
        - Front Porch: 10
        - VSYNC: 2
        - Back Porch: 33
        - TOTAL: 525 Pixel Clock Cycles

    -> EACH FRAME -> 800 * 525 = 420000 Clocks
    -> For 60 FPS -> 420000 Clocks * 60 = 25 MHz approx

    The horizontal line time is:

        800 pixels ÷ 25 MHz ≈ 32 µs

    The frame time is:

        525 × 32 µs ≈ 16.8 ms

    which corresponds to about 59.5 Hz with a 25 MHz pixel clock (very close to the nominal 60 Hz).
*/

module vga_timing(
    //all signals are wire if not specified
    input clk,
    input rst,
    input tick_25MHZ,

    //use reg when signals have to be directly assigned in an always block
    output reg [9:0] hcount,
    output reg [9:0] vcount,

    output reg hsync,
    output reg vsync,

    output video_active,  // high when signals are in the visible range
    output frame_start,
    output line_start
);
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    always @ (posedge clk or negedge rst) begin
        if (!rst) begin
            hcount <= 0;
            vcount <= 0;
            hsync  <= 1'b1;
            vsync  <= 1'b1;
        end else if (tick_25MHZ) begin
            // Register both monitor-facing sync signals. Combinational
            // comparisons against a changing binary counter can briefly
            // glitch at multi-bit transitions and make a monitor lose lock.
            hsync <= ~((hcount >= H_VISIBLE + H_FRONT) &&
                       (hcount <  H_VISIBLE + H_FRONT + H_SYNC));
            vsync <= ~((vcount >= V_VISIBLE + V_FRONT) &&
                       (vcount <  V_VISIBLE + V_FRONT + V_SYNC));

            if (hcount == H_TOTAL - 1) begin
                hcount <= 0;

                if (vcount == V_TOTAL - 1)
                    vcount <= 0;
                else
                    vcount <= vcount + 1;
            end
            else
                hcount <= hcount + 1;
        end
    end

    assign video_active = (hcount < H_VISIBLE) && (vcount < V_VISIBLE);

    assign frame_start = (hcount == 0) &&
                         (vcount == 0) && 
                         tick_25MHZ;

    assign line_start = (hcount == 0) && tick_25MHZ;                  
endmodule 
