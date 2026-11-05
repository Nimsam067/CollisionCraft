// Debounces a push button.

// Owner: Zi Le (Materials, Graphics & Controls)

module ui_debounce #(
    parameter CLK_HZ = 25000000,
    parameter HOLD_MS = 1000
)(
    input wire clk,
    input wire rst,
    input wire btn_raw,
    output reg level,
    output reg press,
    output reg hold
);

    localparam STABLE_CYCLES = CLK_HZ / 100; // 10 ms
    localparam HOLD_CYCLES = (CLK_HZ / 1000) * HOLD_MS;

    reg sync0, sync1;
    always @(posedge clk) begin
        sync0 <= btn_raw;
        sync1 <= sync0;
    end

    reg [$clog2(STABLE_CYCLES+1)-1:0] stable_cnt;
    reg [$clog2(HOLD_CYCLES+1)-1:0] hold_cnt;
    reg hold_fired;

    always @(posedge clk) begin
        press <= 1'b0;
        hold <= 1'b0;
        if (rst) begin
            level <= 1'b0;
            stable_cnt <= 0;
            hold_cnt <= 0;
            hold_fired <= 1'b0;
        end else begin
            // debounce
            if (sync1 == level) begin
                stable_cnt <= 0;
            end else if (stable_cnt == STABLE_CYCLES) begin
                level <= sync1;
                stable_cnt <= 0;
                if (sync1) press <= 1'b1;
            end else begin
                stable_cnt <= stable_cnt + 1'b1;
            end

            // long press
            if (!level) begin
                hold_cnt <= 0;
                hold_fired <= 1'b0;
            end else if (!hold_fired) begin
                if (hold_cnt == HOLD_CYCLES) begin
                    hold <= 1'b1;
                    hold_fired <= 1'b1;
                end else
                    hold_cnt <= hold_cnt + 1'b1;
            end
        end
    end

endmodule
