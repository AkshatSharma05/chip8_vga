`timescale 1ns/1ps

module tb_video;
    reg clk_50 = 1'b0;
    reg reset_n = 1'b0;

    wire r;
    wire g;
    wire b;
    wire vga_hsync;
    wire vga_vsync;
    wire status_led;

    integer white_pixels = 0;
    integer hsync_edges = 0;
    integer vsync_edges = 0;

    top dut (
        .clk_50     (clk_50),
        .reset_n   (reset_n),
        .r          (r),
        .g          (g),
        .b          (b),
        .vga_hsync (vga_hsync),
        .vga_vsync (vga_vsync),
        .status_led(status_led)
    );

    always #10 clk_50 = ~clk_50;

    always @(negedge vga_hsync)
        if (reset_n)
            hsync_edges = hsync_edges + 1;

    always @(negedge vga_vsync)
        if (reset_n)
            vsync_edges = vsync_edges + 1;

    always @(posedge clk_50)
        if (reset_n && r && g && b)
            white_pixels = white_pixels + 1;

    initial begin
        #100;
        reset_n = 1'b1;

        // Slightly more than one 640x480 frame at a 25 MHz pixel enable.
        repeat (850000) @(posedge clk_50);

        if (hsync_edges < 500)
            $fatal(1, "VGA horizontal sync did not run");
        if (vsync_edges < 1)
            $fatal(1, "VGA vertical sync did not run");
        if (white_pixels == 0)
            $fatal(1, "frame remained black");

        $display("PASS: hsync=%0d vsync=%0d white_samples=%0d",
                 hsync_edges, vsync_edges, white_pixels);
        $finish;
    end
endmodule
