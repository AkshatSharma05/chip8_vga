// Board-neutral CHIP-8 top level for a 50 MHz Cyclone IV design.
// Pin locations and I/O standards are intentionally left to the Quartus project.
module top #(
    parameter CPU_INSTRUCTIONS_PER_SECOND = 700
) (
    input  wire       clk_50,
    input  wire       reset_n,
    input  wire       reset_key1_n,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output wire       r,
    output wire       g,
    output wire       b,
    output wire       vga_hsync,
    output wire       vga_vsync,
    output wire       status_led
);

    wire pixel_tick;
    reg instruction_tick;
    reg [25:0] instruction_rate_count;
    localparam CPU_TICK_CYCLES =
        50_000_000 / CPU_INSTRUCTIONS_PER_SECOND;
    wire [9:0] hcount;
    wire [9:0] vcount;
    wire video_active;
    wire frame_start;
    wire line_start;

    wire [11:0] memory_address;
    wire [7:0] memory_data;
    wire memory_write_enable;
    wire [11:0] memory_write_address;
    wire [7:0] memory_write_data;

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
    wire system_reset_n;
    wire [7:0] ps2_scancode;
    wire ps2_scancode_valid;
    wire [15:0] chip8_keys;

    // Both DE0-Nano pushbuttons are active-low. Either KEY0 (J15) or
    // KEY1 (E1) resets the complete design.
    assign system_reset_n = reset_n & reset_key1_n;

    ps2_receiver keyboard_receiver (
        .clk            (clk_50),
        .rst            (system_reset_n),
        .ps2_clk        (ps2_clk),
        .ps2_data       (ps2_data),
        .scancode       (ps2_scancode),
        .scancode_valid (ps2_scancode_valid)
    );

    ps2_decoder keyboard_decoder (
        .clk            (clk_50),
        .rst            (system_reset_n),
        .scancode       (ps2_scancode),
        .scancode_valid (ps2_scancode_valid),
        .keys           (chip8_keys)
    );

    // A full blink takes one second: 500 ms off followed by 500 ms on.
    // Reset turns the LED off immediately and restarts the blink interval.
    reg [24:0] heartbeat_count;
    reg        heartbeat_led;

    always @(posedge clk_50 or negedge system_reset_n) begin
        if (!system_reset_n) begin
            heartbeat_count <= 25'd0;
            heartbeat_led   <= 1'b0;
        end else if (heartbeat_count == 25'd24_999_999) begin
            heartbeat_count <= 25'd0;
            heartbeat_led   <= ~heartbeat_led;
        end else begin
            heartbeat_count <= heartbeat_count + 1'b1;
        end
    end

    // Instruction-heavy demos can need more than the historically
    // conservative 500-700 instructions/second. The default is 2,000:
    //
    //     50,000,000 / 25,000 = 2,000 Hz
    //
    // This is a one-clock enable pulse. It is not a generated clock.
    always @(posedge clk_50 or negedge system_reset_n) begin
        if (!system_reset_n) begin
            instruction_rate_count <= 26'd0;
            instruction_tick <= 1'b0;
        end else if (instruction_rate_count == CPU_TICK_CYCLES - 1) begin
            instruction_rate_count <= 26'd0;
            instruction_tick <= 1'b1;
        end else begin
            instruction_rate_count <= instruction_rate_count + 1'b1;
            instruction_tick <= 1'b0;
        end
    end

    // Divide the DE0-Nano's nominal 50 MHz oscillator to the 25 MHz VGA
    // pixel-enable used by the original design. All logic stays in clk_50's
    // clock domain; pixel_tick is a clock enable, not a generated clock.
    freq_div pixel_enable (
        .clk        (clk_50),
        .rst        (system_reset_n),
        .tick_25MHZ (pixel_tick)
    );

    vga_timing timing (
        .clk          (clk_50),
        .rst          (system_reset_n),
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
        .rst               (system_reset_n),
        .instruction_tick  (instruction_tick),
        .keys              (chip8_keys),
        .mem_read_data     (memory_data),
        .mem_read_addr     (memory_address),
        .mem_write_enable  (memory_write_enable),
        .mem_write_addr    (memory_write_address),
        .mem_write_data    (memory_write_data),
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
        .write_enable (memory_write_enable),
        .write_addr   (memory_write_address),
        .write_data   (memory_write_data)
    );

    display framebuffer (
        .clk         (clk_50),
        .rst         (system_reset_n),
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
        .rst          (system_reset_n),
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

    assign status_led = heartbeat_led;
endmodule
