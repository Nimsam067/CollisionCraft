// =============================================================================
//  game_freeplay.v  --  Sandbox mode with a limited supply of reagents
// -----------------------------------------------------------------------------
//  OWNER: PERSON 3  (Interactions & Game Logic)
//
//  Experiment however you like, with two limits that keep it interesting:
//
//   * 15 RELEASES. Every press of OK that sends material into the beaker
//     uses one. The left two 7-seg digits count them down.
//   * BEAKER CAPACITY. When the beaker is full you must drain it (DOWN)
//     before you can release again.
//
//  The right two 7-seg digits count your DISCOVERIES (different reactions
//  seen). When the releases run out, the lab "closes" and shows your score.
//
//  Buttons:  OK = release    DOWN = drain
//            HINT = suggest a reaction you have NOT found yet
//                   (press again for a different one)
//  (MENU, UP/slow-motion and restarting are handled by game_fsm.v)
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module game_freeplay (
    input  wire        clk,
    input  wire        rst,
    input  wire        anim_tick,
    input  wire        enter,           // pulse: start (or restart) free play
    // buttons, by their job
    input  wire        btn_ok, btn_down, btn_hint,
    // lab status
    input  wire        lab_busy, ja_draining, beaker_full,
    input  wire [12:0] ja_count,
    input  wire        released,
    input  wire [5:0]  disc_count,
    input  wire [63:0] found_mask,      // which reactions have been discovered
    // requests to the game director
    output reg         want_release,
    output reg         want_drain,
    output reg         clear_lab,
    output reg         exit_req,
    output wire        allow_pour,
    // what to show on JA
    output reg  [79:0] header_str,
    output reg  [15:0] header_col,
    output reg         msg_show,
    output reg  [79:0] msg0, msg1, msg2, msg3,
    // 7-segment
    output wire [4:0]  sg3, sg2, sg1, sg0,
    output wire [3:0]  dp
);

    localparam RELEASE_BUDGET = 5'd15;

    reg        ended;
    reg [4:0]  left;            // releases left
    reg [8:0]  end_timer;       // wait 5 s after the last release before closing
    reg [7:0]  blink;

    // ---- hint search state ---------------------------------------------------------------
    reg        searching;       // walking through the reactions looking for an unfound one
    reg [5:0]  probe;           // reaction currently being checked
    reg [5:0]  tries;           // how many we have checked (stop after all of them)
    reg [5:0]  hint_id;         // the reaction being suggested
    reg [7:0]  hint_timer;      // frames the hint stays on screen
    reg        all_found;       // nothing left to suggest!

    // next reaction to check, wrapping 37 -> 1
    wire [5:0] probe_next = (probe >= `RX_TOTAL) ? 6'd1 : probe + 6'd1;

    wire [79:0] hint0, hint1;
    rxn_names names (.id(hint_id), .name(), .hint0(hint0), .hint1(hint1));

    assign allow_pour = !ended;

    always @(posedge clk) begin
        want_release <= 1'b0;
        want_drain   <= 1'b0;
        clear_lab    <= 1'b0;
        exit_req     <= 1'b0;

        if (rst || enter) begin
            ended      <= 1'b0;
            left       <= RELEASE_BUDGET;
            end_timer  <= 9'd0;
            blink      <= 8'd0;
            searching  <= 1'b0;
            probe      <= 6'd0;
            tries      <= 6'd0;
            hint_id    <= 6'd0;
            hint_timer <= 8'd0;
            all_found  <= 1'b0;
            clear_lab  <= enter;
        end else begin
            if (anim_tick) begin
                blink <= blink + 8'd1;
                if (hint_timer != 8'd0) hint_timer <= hint_timer - 8'd1;
            end

            if (!ended) begin
                if (btn_ok && left != 5'd0 && !beaker_full) want_release <= 1'b1;
                if (btn_down) want_drain <= 1'b1;
                if (released && left != 5'd0) left <= left - 5'd1;

                // HINT: start looking from the reaction after the last one suggested
                if (btn_hint && !searching) begin
                    searching <= 1'b1;
                    probe     <= hint_id;
                    tries     <= 6'd0;
                end

                // one reaction checked per clock (37 clocks at most - instant to a human)
                if (searching) begin
                    probe <= probe_next;
                    tries <= tries + 6'd1;
                    if (!found_mask[probe_next]) begin
                        hint_id    <= probe_next;
                        hint_timer <= 8'd240;            // show it for 4 seconds
                        all_found  <= 1'b0;
                        searching  <= 1'b0;
                    end else if (tries == `RX_TOTAL) begin
                        hint_timer <= 8'd240;
                        all_found  <= 1'b1;
                        searching  <= 1'b0;
                    end
                end

                // out of releases: give the last reaction 5 s, then close the lab
                if (left == 5'd0 && !lab_busy) begin
                    if (anim_tick) end_timer <= end_timer + 9'd1;
                    if (end_timer == 9'd300) ended <= 1'b1;
                end
            end else begin
                if (btn_ok) exit_req <= 1'b1;
            end
        end
    end

    // ---- Number helpers -------------------------------------------------------------------------
    wire [3:0] left_t  = left / 5'd10,       left_o  = left % 5'd10;
    wire [3:0] disc_t  = disc_count / 6'd10, disc_o  = disc_count % 6'd10;

    // 7-seg: "15.07" = 15 releases left, 7 discoveries
    assign sg3 = {1'b0, left_t};
    assign sg2 = {1'b0, left_o};
    assign sg1 = {1'b0, disc_t};
    assign sg0 = {1'b0, disc_o};
    assign dp  = 4'b0100;

    always @* begin
        header_str = "FREE PLAY ";
        header_col = {5'd6, 6'd52, 5'd31};
        msg_show   = 1'b0;
        msg0 = "          "; msg1 = "          "; msg2 = "          "; msg3 = "          ";

        if (ended) begin
            msg_show   = 1'b1;
            header_str = "LAB CLOSED";
            header_col = {5'd31, 6'd40, 5'd2};
            msg0 = "TIME UP!  ";
            msg1 = {"FOUND ", 8'd48 + {4'd0, disc_t}, 8'd48 + {4'd0, disc_o}, "  "};
            msg2 = "OF 37     ";
            msg3 = "C = TITLE ";
        end else if (beaker_full && !ja_draining) begin
            msg_show   = 1'b1;
            header_str = blink[4] ? "FULL!     " : "          ";
            header_col = {5'd31, 6'd12, 5'd4};
            msg0 = "BEAKER    "; msg1 = "IS FULL!  "; msg2 = "PUSH DOWN "; msg3 = "TO DRAIN  ";
        end else if (hint_timer != 8'd0) begin
            msg_show = 1'b1;
            if (all_found) begin
                msg0 = "WOW!      "; msg1 = "YOU FOUND "; msg2 = "IT ALL!   "; msg3 = "          ";
            end else begin
                msg0 = "TRY THIS: "; msg1 = hint0; msg2 = hint1; msg3 = "> = NEXT  ";
            end
        end else if (left == 5'd1) begin
            header_str = "LAST ONE! ";
            header_col = {5'd31, 6'd40, 5'd2};
        end else if (left == 5'd0) begin
            header_str = "FINAL MIX ";
            header_col = {5'd31, 6'd24, 5'd2};
        end
    end

endmodule

`default_nettype wire
