// Board-neutral CHIP-8 top level for a 50 MHz Cyclone IV design.
// Pin locations and I/O standards are intentionally left to the Quartus project.
module top (
    input  wire       clk_50,
    input  wire       reset_n,
    output wire       r,
    output wire       g,
    output wire       b,
    output wire       vga_hsync,
    output wire       vga_vsync,
    output wire       status_led
);

    wire pixel_tick;
    wire [9:0] hcount;
    wire [9:0] vcount;
    wire video_active;
    wire frame_start;
    wire line_start;

    wire [11:0] memory_address;
    wire [7:0] memory_data;

    wire display_draw;
    wire [5:0] display_x;
    wire [4:0] display_y;
    wire [7:0] display_sprite;
    wire display_clear;
    wire display_collision;
    wire display_busy;

    wire framebuffer_pixel;
    wire [5:0] chip_x;
    wire [4:0] chip_y;

    // Divide the DE0-Nano's nominal 50 MHz oscillator to the 25 MHz VGA
    // pixel-enable used by the original design. All logic stays in clk_50's
    // clock domain; pixel_tick is a clock enable, not a generated clock.
    freq_div pixel_enable (
        .clk        (clk_50),
        .rst        (reset_n),
        .tick_25MHZ (pixel_tick)
    );

    vga_timing timing (
        .clk          (clk_50),
        .rst          (reset_n),
        .tick_25MHZ   (pixel_tick),
        .hcount       (hcount),
        .vcount       (vcount),
        .hsync        (vga_hsync),
        .vsync        (vga_vsync),
        .video_active (video_active),
        .frame_start  (frame_start),
        .line_start   (line_start)
    );

    chip8_cpu cpu (
        .clk               (clk_50),
        .rst               (reset_n),
        .mem_read_data     (memory_data),
        .mem_read_addr     (memory_address),
        .display_collision (display_collision),
        .display_busy      (display_busy),
        .display_draw      (display_draw),
        .display_x         (display_x),
        .display_y         (display_y),
        .display_sprite    (display_sprite),
        .display_clear     (display_clear)
    );

    chip8_memory memory (
        .clk          (clk_50),
        .read_addr    (memory_address),
        .read_data    (memory_data),
        .write_enable (1'b0),
        .write_addr   (12'h000),
        .write_data   (8'h00)
    );

    display framebuffer (
        .clk         (clk_50),
        .rst         (reset_n),
        .tick_25MHz  (pixel_tick),
        .chip_x      (chip_x),
        .chip_y      (chip_y),
        .clear       (display_clear),
        .draw        (display_draw),
        .draw_x      (display_x),
        .draw_y      (display_y),
        .draw_sprite (display_sprite),
        .busy        (display_busy),
        .collision   (display_collision),
        .pixel_on    (framebuffer_pixel)
    );

    vga_renderer renderer (
        .clk          (clk_50),
        .rst          (reset_n),
        .tick_25MHZ   (pixel_tick),
        .video_active (video_active),
        .frame_start  (frame_start),
        .line_start   (line_start),
        .hcount       (hcount),
        .vcount       (vcount),
        .pixel_on     (framebuffer_pixel),
        .chip_x       (chip_x),
        .chip_y       (chip_y),
        .r            (r),
        .g            (g),
        .b            (b)
    );

    // Simple heartbeat derived from the vertical counter.
    assign status_led = display_draw;
endmodule
