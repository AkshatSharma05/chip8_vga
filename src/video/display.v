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

    output busy,
    output reg collision,

    output pixel_on
);

reg [63:0] framebuffer [0:31] /* synthesis ramstyle = "M9K" */;

reg [63:0] pixel_row;
reg [5:0] pixel_x;

reg clearing;
reg [4:0] clear_y;

localparam DRAW_IDLE  = 2'd0;
localparam DRAW_READ  = 2'd1;
localparam DRAW_WRITE = 2'd2;

reg [1:0] draw_state;
reg [4:0] draw_y_latched;
reg [63:0] draw_mask_latched;

reg [4:0] op_addr;
reg [63:0] op_read_data;
reg [63:0] op_write_data;
reg op_write_enable;

reg [63:0] next_draw_mask;
integer i;

assign busy = clearing || (draw_state != DRAW_IDLE);
assign pixel_on = pixel_row[pixel_x];

// Port A: synchronous VGA read.
always @(posedge clk) begin
    if (tick_25MHz) begin
        pixel_row <= framebuffer[chip_y];
        pixel_x   <= chip_x;
    end
end

// Port B: synchronous read/write port used for clear and sprite drawing.
// Keeping every RAM access in these two small clocked blocks matches the
// Quartus true-dual-port RAM inference template.
always @(posedge clk) begin
    op_read_data <= framebuffer[op_addr];

    if (op_write_enable)
        framebuffer[op_addr] <= op_write_data;
end

// Convert the eight sprite bits into a 64-bit row mask. Pixels beyond the
// right edge are clipped, matching the previous implementation.
always @(*) begin
    next_draw_mask = 64'b0;
    for (i = 0; i < 8; i = i + 1)
        if ((draw_x + i) < 64)
            next_draw_mask[draw_x + i] = draw_sprite[7-i];
end

// Select the operation performed by RAM port B.
always @(*) begin
    op_addr         = draw_y_latched;
    op_write_enable = 1'b0;
    op_write_data   = 64'b0;

    if (clearing) begin
        op_addr         = clear_y;
        op_write_enable = 1'b1;
        op_write_data   = 64'b0;
    end else if (draw_state == DRAW_WRITE) begin
        op_write_enable = 1'b1;
        op_write_data   = op_read_data ^ draw_mask_latched;
    end
end

// Do not reset the RAM array directly: block RAM has no whole-array reset.
// Reset and CLS instead clear one complete row per clock (32 clocks total).
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        collision <= 1'b0;
        clearing  <= 1'b1;
        clear_y   <= 5'd0;
        draw_state <= DRAW_IDLE;
        draw_y_latched <= 5'd0;
        draw_mask_latched <= 64'b0;
    end else if (clear) begin
        collision <= 1'b0;
        clearing  <= 1'b1;
        clear_y   <= 5'd0;
        draw_state <= DRAW_IDLE;
    end else if (clearing) begin
        if (clear_y == 5'd31) begin
            clearing <= 1'b0;
        end else begin
            clear_y <= clear_y + 1'b1;
        end
    end else begin
        case (draw_state)
            DRAW_IDLE: begin
                if (draw) begin
                    draw_y_latched    <= draw_y;
                    draw_mask_latched <= next_draw_mask;
                    draw_state        <= DRAW_READ;
                end
            end

            DRAW_READ: begin
                draw_state <= DRAW_WRITE;
            end

            DRAW_WRITE: begin
                collision <= |(op_read_data & draw_mask_latched);
                draw_state <= DRAW_IDLE;
            end

            default: draw_state <= DRAW_IDLE;
        endcase
    end
end

endmodule
