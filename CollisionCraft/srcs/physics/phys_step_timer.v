// =============================================================================
//  phys_step_timer.v  --  The heartbeat of the simulation
// -----------------------------------------------------------------------------
//  OWNER: PERSON 2  (Physics Engine)
//
//  Produces a "step" pulse 120 times a second (30 in slow motion).
//  All three engines step together. If an engine is somehow still busy when
//  the next beat arrives, we wait for it instead of piling up requests.
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module phys_step_timer (
    input  wire clk,
    input  wire rst,
    input  wire slow,          // slow-motion switch
    input  wire any_busy,      // OR of all engines' busy flags
    output reg  step
);

    reg [19:0] cnt;
    reg        pending;
    wire [19:0] period = slow ? `STEP_DIV_SLOW : `STEP_DIV_FAST;

    always @(posedge clk) begin
        step <= 1'b0;
        if (rst) begin
            cnt     <= 20'd0;
            pending <= 1'b0;
        end else begin
            if (cnt >= period) begin
                cnt     <= 20'd0;
                pending <= 1'b1;
            end else
                cnt <= cnt + 20'd1;

            if (pending && !any_busy && !step) begin
                step    <= 1'b1;
                pending <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
