// =============================================================================
//  clock_gen.v  --  Clock dividers and power-on reset
// -----------------------------------------------------------------------------
//  OWNER: shared
//
//  The Basys3 gives us one 100 MHz clock. We divide it with a simple counter:
//
//      div[1] -> 25 MHz   "core" clock: physics, reactions, game logic
//      div[3] -> 6.25 MHz "oled" clock: what Oled_Display.v expects
//
//  Why not run everything at 100 MHz? The physics engine makes a lot of
//  decisions in one clock cycle (where can this grain move? does it react?).
//  25 MHz gives that logic 40 ns, which is very comfortable, and it is still
//  fast enough to run 120 physics steps per second on all three screens.
//
//  Both clocks come from the same counter, so they are related. The XDC file
//  tells Vivado about them (create_generated_clock) so timing is checked.
// =============================================================================
`default_nettype none

module clock_gen (
    input  wire clk100,      // 100 MHz board clock
    output wire clk_core,    // 25 MHz
    output wire clk_oled,    // 6.25 MHz
    output reg  rst_core     // active-high reset, held for ~2.6 ms after power-up
);

    // ---- Free-running divider -------------------------------------------------
    reg [3:0] div = 4'd0;
    always @(posedge clk100)
        div <= div + 4'd1;

    assign clk_core = div[1];
    assign clk_oled = div[3];

    // ---- Power-on reset ---------------------------------------------------------
    // The FPGA powers up with every register at its initial value. We hold
    // reset for 65535 core cycles so every module starts from a known state.
    reg [15:0] por_count = 16'd0;
    initial rst_core = 1'b1;

    always @(posedge clk_core) begin
        if (por_count != 16'hFFFF) begin
            por_count <= por_count + 16'd1;
            rst_core  <= 1'b1;
        end else begin
            rst_core  <= 1'b0;
        end
    end

endmodule

`default_nettype wire
