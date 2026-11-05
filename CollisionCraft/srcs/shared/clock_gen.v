// Makes the clocks and the power on reset. The 100 MHz board clock is divided
// down to 25 MHz for the core logic and 6.25 MHz for the OLEDs.
//
// Owner: shared

module clock_gen (
    input wire clk100, // 100 MHz board clock
    output wire clk_core, // 25 MHz
    output wire clk_oled, // 6.25 MHz
    output reg rst_core // active high reset, held for ~2.6 ms after power up
);

    // Free running divider
    reg [3:0] div = 4'd0;
    always @(posedge clk100)
        div <= div + 4'd1;

    assign clk_core = div[1];
    assign clk_oled = div[3];

    // Power on reset
    reg [15:0] por_count = 16'd0;
    initial rst_core = 1'b1;

    always @(posedge clk_core) begin
        if (por_count != 16'hFFFF) begin
            por_count <= por_count + 16'd1;
            rst_core <= 1'b1;
        end else begin
            rst_core <= 1'b0;
        end
    end

endmodule
