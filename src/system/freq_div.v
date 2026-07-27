module freq_div(
    input clk,
    input rst,
    output reg tick_25MHZ
);

    always @ (posedge clk or negedge rst) begin
        if(!rst) begin
            tick_25MHZ <= 1'b0;
        end else begin
            tick_25MHZ <= ~tick_25MHZ;
        end
    end

endmodule 
