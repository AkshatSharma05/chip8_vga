// SPI Mode 0 to be used 
// CPOL = 0
// CPHA = 0
//Data is sampled on the rising edge.
// Data changes on the falling edge.

//Initially the SPI Master is being run at 400 KHz -> will be changed later
// 400 * 10^3 = 50*10^6/2*N -> N = 62-64 approx

module spi_master #(
    parameter [15:0] CLK_DIV = 16'd62
)(
    input clk,
    input rst,

    input start,
    input [7:0] tx_data,
    output reg [7:0] rx_data,
    output reg busy,
    output reg done,

    // SPI pins
    output reg        spi_clk,
    output reg        spi_mosi,
    input  wire       spi_miso
);

reg [7:0] tx_shift;
reg [7:0] rx_shift;

reg [2:0] bit_count;
reg [15:0] clk_count;

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        tx_shift  <= 8'h00;
        rx_shift  <= 8'h00;
        rx_data   <= 8'h00;

        bit_count <= 3'd0;
        clk_count <= 16'd0;

        spi_clk   <= 1'b0;
        spi_mosi  <= 1'b0;

        busy      <= 1'b0;
        done      <= 1'b0;

    end else begin

        done <= 1'b0;

        if (!busy) begin

            // Start a new byte transfer
            if (start) begin
                tx_shift  <= tx_data;
                rx_shift  <= 8'h00;

                bit_count <= 3'd0;
                clk_count <= 16'd0;

                spi_clk   <= 1'b0;

                // First bit is present before the first rising clock edge.
                spi_mosi  <= tx_data[7];

                busy      <= 1'b1;
            end

        end else begin

            if (clk_count == CLK_DIV - 1'b1) begin
                clk_count <= 16'd0;

                if (spi_clk == 1'b0) begin

                    // Rising edge:
                    // sample MISO.
                    spi_clk <= 1'b1;

                    rx_shift[7 - bit_count] <= spi_miso;

                end else begin

                    // Falling edge:
                    // advance to next transmitted bit.
                    spi_clk <= 1'b0;

                    if (bit_count == 3'd7) begin

                        // Transfer complete.
                        rx_data <= rx_shift;

                        busy <= 1'b0;
                        done <= 1'b1;

                        spi_mosi <= 1'b0;

                    end else begin

                        bit_count <= bit_count + 1'b1;

                        spi_mosi <= tx_shift[6 - bit_count];

                    end
                end

            end else begin
                clk_count <= clk_count + 1'b1;
            end

        end
    end

end

endmodule
