`timescale 1ns/1ps

module tb_spi_master;
    localparam integer CLK_DIV = 3;

    reg        clk = 1'b0;
    reg        rst = 1'b0;
    reg        start = 1'b0;
    reg  [7:0] tx_data = 8'h00;
    reg        spi_miso = 1'b0;

    wire [7:0] rx_data;
    wire       busy;
    wire       done;
    wire       spi_clk;
    wire       spi_mosi;

    reg  [7:0] slave_response = 8'h00;
    reg  [7:0] captured_mosi = 8'h00;
    integer    rising_edges = 0;
    integer    done_pulses = 0;
    integer    clocks_since_edge = 0;
    reg        previous_spi_clk = 1'b0;
    reg        saw_spi_edge = 1'b0;

    spi_master #(
        .CLK_DIV(CLK_DIV)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .busy     (busy),
        .done     (done),
        .spi_clk  (spi_clk),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

    always #5 clk = ~clk;

    // Mode-0 slave model: sample MOSI on rising edges and change MISO on
    // falling edges. The first MISO bit is installed before the first edge.
    always @(posedge spi_clk) begin
        captured_mosi[7-rising_edges] = spi_mosi;
        rising_edges = rising_edges + 1;
    end

    always @(negedge spi_clk) begin
        if (busy && (rising_edges < 8))
            spi_miso = slave_response[7-rising_edges];
    end

    // Check that every SPI half-period is exactly CLK_DIV input clocks.
    always @(negedge clk) begin
        if (!rst || !busy) begin
            clocks_since_edge = 0;
            previous_spi_clk = spi_clk;
            saw_spi_edge = 1'b0;
        end else begin
            clocks_since_edge = clocks_since_edge + 1;
            if (spi_clk != previous_spi_clk) begin
                // The start-acceptance clock is outside a full half-period;
                // compare only distances between actual SPI edges.
                if (saw_spi_edge && (clocks_since_edge != CLK_DIV))
                    $fatal(1, "SPI half-period was %0d clocks, expected %0d",
                           clocks_since_edge, CLK_DIV);
                clocks_since_edge = 0;
                previous_spi_clk = spi_clk;
                saw_spi_edge = 1'b1;
            end
        end

        if (done)
            done_pulses = done_pulses + 1;
    end

    task transfer_and_check;
        input [7:0] master_byte;
        input [7:0] slave_byte;
        begin
            captured_mosi = 8'h00;
            rising_edges = 0;
            slave_response = slave_byte;
            spi_miso = slave_byte[7];
            tx_data = master_byte;

            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            if (!busy)
                $fatal(1, "busy did not assert after start");

            @(posedge done);
            #1;

            if (busy)
                $fatal(1, "busy remained asserted after transfer");
            if (spi_clk !== 1'b0 || spi_mosi !== 1'b0)
                $fatal(1, "SPI pins did not return to idle");
            if (rising_edges != 8)
                $fatal(1, "saw %0d rising SPI edges, expected 8", rising_edges);
            if (captured_mosi !== master_byte)
                $fatal(1, "MOSI mismatch: got %02h expected %02h",
                       captured_mosi, master_byte);
            if (rx_data !== slave_byte)
                $fatal(1, "MISO mismatch: got %02h expected %02h",
                       rx_data, slave_byte);

            @(posedge clk);
            #1;
            if (done)
                $fatal(1, "done was asserted for more than one clock");
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        #1;
        if (busy !== 1'b0 || done !== 1'b0 || spi_clk !== 1'b0 ||
            spi_mosi !== 1'b0 || rx_data !== 8'h00)
            $fatal(1, "outputs were not reset to their idle values");

        rst = 1'b1;
        transfer_and_check(8'hA5, 8'h3C);
        transfer_and_check(8'h00, 8'hFF);
        transfer_and_check(8'hFF, 8'h00);

        // A start pulse during a transfer must not replace the active byte.
        captured_mosi = 8'h00;
        rising_edges = 0;
        slave_response = 8'h96;
        spi_miso = slave_response[7];
        tx_data = 8'h5A;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        repeat (5) @(negedge clk);
        tx_data = 8'hC3;
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        @(posedge done);
        #1;
        if (captured_mosi !== 8'h5A || rx_data !== 8'h96)
            $fatal(1, "start while busy disturbed the active transfer");

        @(posedge clk);
        #1;
        if (done_pulses != 4)
            $fatal(1, "saw %0d done pulses, expected 4", done_pulses);

        $display("PASS: spi_master completed all Mode-0 transfers");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "testbench timed out");
    end
endmodule
