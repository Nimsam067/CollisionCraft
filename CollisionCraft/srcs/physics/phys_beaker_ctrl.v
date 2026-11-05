// Drain for the reaction beaker (JA). Pressing DOWN opens the drain, everything
// falls out (flush is on so solids fall too), and it closes again once the
// beaker has been empty for two steps.
//
// Owner: Aadi (Physics Engine)

`include "cc_defines.vh"

module phys_beaker_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire        step_done,
    input  wire [12:0] cell_count,
    input  wire        drain_cmd,      // pulse
    output reg         draining,
    output wire        drain_open,
    output wire [1:0]  sink_mode,
    output wire        flush
);

    assign drain_open = draining;
    assign sink_mode  = draining ? `SINK_DELETE : `SINK_CLOSED;
    assign flush      = draining;

    reg [1:0] zero_steps;
    reg [5:0] steps;

    always @(posedge clk) begin
        if (rst) begin
            draining   <= 1'b0;
            zero_steps <= 2'd0;
            steps      <= 6'd0;
        end else if (!draining) begin
            zero_steps <= 2'd0;
            steps      <= 6'd0;
            if (drain_cmd) draining <= 1'b1;
        end else if (step_done) begin
            if (steps != 6'd63) steps <= steps + 6'd1;
            if (cell_count == 13'd0) begin
                if (zero_steps == 2'd1 && steps >= 6'd30) draining <= 1'b0;
                else if (zero_steps != 2'd2) zero_steps <= zero_steps + 2'd1;
            end else
                zero_steps <= 2'd0;
        end
    end

endmodule
