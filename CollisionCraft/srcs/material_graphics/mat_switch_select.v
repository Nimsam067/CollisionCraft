// Reads the six material switches for one chamber and drives the six LEDs above
// them. One switch up selects that material, and two or more up is a conflict
// which pauses pouring. The LEDs show what the chamber is doing using different
//blink and fade patterns. Bit 0 is always WATER and bit 5 is always OIL

// Owner: Zi Le (Materials, Graphics & Controls)

`include "cc_defines.vh"

module mat_switch_select (
    input wire clk,
    input wire rst,
    input wire anim_tick, // 60 Hz pulse
    input wire [5:0] sw_raw, // bit 0 = WATER ... bit 5 = OIL
    input wire [2:0] ch_state,
    input wire [5:0] ch_mat, // material currently in the chamber
    input wire allow, // the game currently allows pouring
    input wire [5:0] hint, // tutorial hint
    output reg [1:0] sel_state,
    output reg [5:0] sel_mat,
    output reg [5:0] led
);

    reg [5:0] sw_s0, sw_s1, sw;
    always @(posedge clk) begin
        sw_s0 <= sw_raw;
        sw_s1 <= sw_s0;
        if (rst) sw <= 6'd0;
        else if (anim_tick) sw <= sw_s1;
    end

    // Work out the selection
    reg [2:0] n_up;
    reg [2:0] first_up;
    integer i;
    always @* begin
        n_up = 3'd0;
        first_up = 3'd0;
        for (i = 5; i >= 0; i = i - 1)
            if (sw[i]) begin
                n_up = n_up + 3'd1;
                first_up = i;
            end
    end

    always @(posedge clk) begin
        if (rst) begin
            sel_state <= `SEL_NONE;
            sel_mat <= `M_EMPTY;
        end else begin
            if (n_up == 3'd0) begin sel_state <= `SEL_NONE; sel_mat <= `M_EMPTY; end
            else if (n_up == 3'd1) begin sel_state <= `SEL_ONE; sel_mat <= {3'd0, first_up} + `M_WATER; end
            else begin sel_state <= `SEL_CONFLICT; sel_mat <= `M_EMPTY; end
        end
    end

    // Animation timers
    reg [7:0] t; // frame counter
    reg [2:0] dot; // selection animation dot
    reg dot_dir; // 0 = moving right, 1 = moving left
    always @(posedge clk) begin
        if (rst) begin
            t <= 8'd0; dot <= 3'd0; dot_dir <= 1'b0;
        end else if (anim_tick) begin
            t <= t + 8'd1;
            if (t[2:0] == 3'd0) begin
                if (!dot_dir) begin
                    if (dot == 3'd5) begin dot_dir <= 1'b1; dot <= 3'd4; end else dot <= dot + 3'd1;
                end else begin
                    if (dot == 3'd0) begin dot_dir <= 1'b0; dot <= 3'd1; end else dot <= dot - 3'd1;
                end
            end
        end
    end

    // Light design for when tutorial asks you to select something
    wire [3:0] breathe = t[4] ? ~t[3:0] : t[3:0];

    // Material LED
    wire [2:0] cur_idx = ch_mat[2:0] - 3'd1;

    // Brightness of each LED
    reg [23:0] bright;
    integer k;
    always @* begin
        bright = 24'd0;
        for (k = 0; k < 6; k = k + 1) begin
            if (sel_state == `SEL_CONFLICT || ch_state == `CH_HOLD) begin
                // Conflict or hold blinking
                if (sw[k]) bright[4*k +: 4] = (t[3] ^ k[0]) ? 4'd15 : 4'd0;
            end else begin
                case (ch_state)
                    `CH_EMPTY: begin
                        if (hint != 6'd0)
                            bright[4*k +: 4] = hint[k] ? breathe : 4'd0;
                        else if (allow) begin
                            if (k == dot) bright[4*k +: 4] = 4'd15;
                            else if (k == dot + 1 || k + 1 == dot) bright[4*k +: 4] = 4'd2;
                        end
                    end
                    `CH_POUR: if (k == cur_idx) bright[4*k +: 4] = t[2] ? 4'd15 : 4'd3;
                    `CH_READY: bright[4*k +: 4] = (k == cur_idx) ? 4'd15 : 4'd1;
                    `CH_DISCARD: if (k == cur_idx) bright[4*k +: 4] = 4'd15 - t[3:0];
                    `CH_RELEASE: if (k == cur_idx) bright[4*k +: 4] = t[1] ? 4'd15 : 4'd0;
                    `CH_SPENT: if (k == cur_idx)
                                     bright[4*k +: 4] = (t[5:2] == 4'd0 || t[5:2] == 4'd2) ? 4'd15 : 4'd0;
                    default: ;
                endcase
            end
        end
    end

    // PWM
    reg [3:0] pwm = 4'd0;
    integer j;
    always @(posedge clk) begin
        pwm <= pwm + 4'd1;
        for (j = 0; j < 6; j = j + 1)
            led[j] <= (pwm < bright[4*j +: 4]);
    end

endmodule
