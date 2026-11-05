// Generates the physics step pulse, 120 times a second (30 in slow motion). If
// an engine is still busy when the next step is due, it waits for it.

// Owner: Aadi (Physics Engine)

`include "cc_defines.vh"

module phys_step_timer (
    input wire clk,
    input wire rst,
    input wire slow, // slow motion switch
    input wire any_busy, // checking if any engine is busy
    output reg step
);

    reg [19:0] cnt;
    reg pending;
    wire [19:0] period = slow ? `STEP_DIV_SLOW : `STEP_DIV_FAST;

    always @(posedge clk) begin
        step <= 1'b0;
        if (rst) begin
            cnt <= 20'd0;
            pending <= 1'b0;
        end else begin
            if (cnt >= period) begin
                cnt <= 20'd0;
                pending <= 1'b1;
            end else
                cnt <= cnt + 20'd1;

            if (pending && !any_busy && !step) begin
                step <= 1'b1;
                pending <= 1'b0;
            end
        end
    end

endmodule
