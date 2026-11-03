// =============================================================================
//  game_challenge.v  --  "Make this material!" puzzle mode
// -----------------------------------------------------------------------------
//  OWNER: PERSON 3  (Interactions & Game Logic)
//
//  For each level:
//
//    INTRO   "LEVEL 3 / MAKE: / OBSIDIAN / C = START"       7-seg: L  3
//    PLAY    90-second countdown, header shows the target,  7-seg: 3-75
//            OK = release, DOWN = drain, HINT = hint (costs 10 s)
//    WIN     stars depend on how many releases you used     7-seg: PASS
//            (par = 3 stars, par+1 = 2 stars, more = 1)
//    FAIL    time ran out                                   7-seg: FAIL
//    DONE    after the last level                           7-seg: donE
//
//  The MENU button's pause pop-up is handled by game_fsm.v. Its RESTART
//  option pulses `restart`, which sends you back to the start of the
//  CURRENT level (not level 1). While paused, game_fsm stops anim_tick
//  reaching this module, so the countdown freezes too.
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module game_challenge (
    input  wire        clk,
    input  wire        rst,
    input  wire        anim_tick,
    input  wire        enter,           // pulse: start the challenge from level 1
    input  wire        restart,         // pulse: restart the current level
    // buttons, by their job
    input  wire        btn_ok, btn_down, btn_hint,
    // lab status
    input  wire        released,
    input  wire [12:0] target_count,    // grains of the target material in the beaker
    // requests to the game director
    output reg         want_release,
    output reg         want_drain,
    output reg         clear_lab,
    output reg         exit_req,
    output wire        allow_pour,
    output wire [5:0]  target_mat,
    // what to show on JA
    output reg  [79:0] header_str,
    output reg  [15:0] header_col,
    output reg         msg_show,
    output reg  [79:0] msg0, msg1, msg2, msg3,
    // 7-segment
    output reg  [4:0]  sg3, sg2, sg1, sg0,
    output reg  [3:0]  dp
);

    localparam [3:0] LEVEL_COUNT = 4'd10;
    localparam [6:0] TIME_LIMIT  = 7'd90;

    localparam [2:0] C_INTRO = 3'd0, C_PLAY = 3'd1, C_WIN = 3'd2, C_FAIL = 3'd3, C_DONE = 3'd4;

    reg [2:0]  phase;
    reg [3:0]  level;
    reg [6:0]  secs;            // seconds left
    reg [5:0]  sub;             // frames within the current second
    reg [3:0]  used;            // releases used this attempt
    reg [1:0]  stars;
    reg [7:0]  hint_timer;      // frames the hint stays visible
    reg [7:0]  blink;

    assign allow_pour = (phase == C_PLAY);

    // ---- Level data ------------------------------------------------------------------------------
    wire [12:0] goal;
    wire [2:0]  par;
    wire [79:0] hint0, hint1;
    game_levels levels (.level(level), .target_mat(target_mat), .goal(goal), .par(par),
                        .hint0(hint0), .hint1(hint1));

    wire [79:0] tname;
    mat_names names (.mat(target_mat), .name(tname), .code3(), .desc(), .sig_color());

    // ---- Game flow -------------------------------------------------------------------------------
    always @(posedge clk) begin
        want_release <= 1'b0;
        want_drain   <= 1'b0;
        clear_lab    <= 1'b0;
        exit_req     <= 1'b0;

        if (rst || enter) begin
            phase      <= C_INTRO;
            level      <= 4'd0;
            secs       <= TIME_LIMIT;
            sub        <= 6'd0;
            used       <= 4'd0;
            stars      <= 2'd0;
            hint_timer <= 8'd0;
            blink      <= 8'd0;
            clear_lab  <= enter;
        end else if (restart) begin
            // pause menu -> RESTART: back to this level's intro with a clean lab
            phase      <= C_INTRO;
            hint_timer <= 8'd0;
            clear_lab  <= 1'b1;
        end else begin
            if (anim_tick) begin
                blink <= blink + 8'd1;
                if (hint_timer != 8'd0) hint_timer <= hint_timer - 8'd1;
            end

            case (phase)
                C_INTRO: begin
                    if (btn_ok) begin
                        clear_lab  <= 1'b1;            // fresh lab for every attempt
                        secs       <= TIME_LIMIT;
                        sub        <= 6'd0;
                        used       <= 4'd0;
                        hint_timer <= 8'd0;
                        phase      <= C_PLAY;
                    end
                end

                C_PLAY: begin
                    if (btn_ok)   want_release <= 1'b1;
                    if (btn_down) want_drain   <= 1'b1;
                    if (released && used != 4'd15) used <= used + 4'd1;
                    if (btn_hint) begin                  // hint costs 10 seconds
                        hint_timer <= 8'd240;
                        secs       <= (secs > 7'd11) ? secs - 7'd10 : 7'd1;
                    end

                    // clock
                    if (anim_tick) begin
                        if (sub == 6'd59) begin
                            sub <= 6'd0;
                            if (secs != 7'd0) secs <= secs - 7'd1;
                        end else
                            sub <= sub + 6'd1;
                    end

                    // win / lose
                    // (ignore the first half second while the old count refreshes)
                    if (target_count >= goal && (secs != TIME_LIMIT || sub > 6'd30)) begin
                        stars <= (used <= {1'b0, par})        ? 2'd3 :
                                 (used <= {1'b0, par} + 4'd1) ? 2'd2 : 2'd1;
                        phase <= C_WIN;
                    end else if (secs == 7'd0) begin
                        phase <= C_FAIL;
                    end
                end

                C_WIN: begin
                    if (btn_ok) begin
                        clear_lab <= 1'b1;
                        if (level == LEVEL_COUNT - 4'd1)
                            phase <= C_DONE;
                        else begin
                            level <= level + 4'd1;
                            phase <= C_INTRO;
                        end
                    end
                end

                C_FAIL: begin
                    if (btn_ok) begin
                        clear_lab <= 1'b1;
                        phase     <= C_INTRO;
                    end
                end

                C_DONE: if (btn_ok) exit_req <= 1'b1;

                default: phase <= C_INTRO;
            endcase
        end
    end

    // ---- Display -----------------------------------------------------------------------------------
    wire [4:0] lvl_disp = (level == 4'd9) ? `SG_A : {1'b0, level + 4'd1};   // 1..9, then A
    wire [7:0] lvl_ascii_t = (level == 4'd9) ? "1" : " ";
    wire [7:0] lvl_ascii_o = (level == 4'd9) ? "0" : (8'd49 + {4'd0, level});
    wire [3:0] secs_t = secs / 7'd10, secs_o = secs % 7'd10;

    always @* begin
        header_str = "CHALLENGE ";
        header_col = {5'd31, 6'd24, 5'd28};
        msg_show = 1'b1;
        msg0 = "          "; msg1 = "          "; msg2 = "          "; msg3 = "          ";
        sg3 = `SG_BLANK; sg2 = `SG_BLANK; sg1 = `SG_BLANK; sg0 = `SG_BLANK;
        dp = 4'b0000;

        case (phase)
            C_INTRO: begin
                // header alternates to remind the player where the hint button is
                header_str = blink[6] ? "> = HINT  " : "CHALLENGE ";
                header_col = blink[6] ? {5'd6, 6'd52, 5'd31} : {5'd31, 6'd24, 5'd28};
                msg0 = (level == 4'd9) ? {"LEVEL ", lvl_ascii_t, lvl_ascii_o, "  "}
                                       : {"LEVEL ", lvl_ascii_o, "   "};
                msg1 = "MAKE:     ";
                msg2 = tname;
                msg3 = "C = START ";
                sg3 = `SG_L; sg2 = `SG_BLANK;
                sg1 = (level == 4'd9) ? `SG_1 : `SG_BLANK;
                sg0 = (level == 4'd9) ? `SG_0 : {1'b0, level + 4'd1};
            end
            C_PLAY: begin
                header_str = tname;
                header_col = blink[5] ? {5'd31, 6'd52, 5'd4} : {5'd31, 6'd60, 5'd20};
                msg_show = (hint_timer != 8'd0);
                msg0 = "HINT:     "; msg1 = hint0; msg2 = hint1; msg3 = "-10 SECS  ";
                sg3 = lvl_disp; sg2 = `SG_DASH;
                sg1 = {1'b0, secs_t}; sg0 = {1'b0, secs_o};
            end
            C_WIN: begin
                header_str = "SUCCESS!  ";
                header_col = {5'd8, 6'd60, 5'd8};
                msg0 = "SUCCESS!  ";
                msg1 = (stars == 2'd3) ? "* * *     " : (stars == 2'd2) ? "* *       " : "*         ";
                msg2 = {"STEPS: ", 8'd48 + ((used > 4'd9) ? 8'd9 : {4'd0, used}), "  "};
                msg3 = (level == LEVEL_COUNT - 4'd1) ? "C = DONE  " : "C = NEXT  ";
                sg3 = `SG_P; sg2 = `SG_A; sg1 = `SG_S; sg0 = `SG_S;
            end
            C_FAIL: begin
                header_str = "TIME UP!  ";
                header_col = {5'd31, 6'd12, 5'd4};
                msg0 = "TIME UP!  "; msg1 = "SO CLOSE! "; msg2 = "          "; msg3 = "C = RETRY ";
                sg3 = `SG_F; sg2 = `SG_A; sg1 = `SG_I; sg0 = `SG_L;
            end
            default: begin // C_DONE
                header_str = "ALL DONE! ";
                header_col = {5'd31, 6'd52, 5'd4};
                msg0 = "ALL DONE! "; msg1 = "MASTER    "; msg2 = "CRAFTER!  "; msg3 = "C = TITLE ";
                sg3 = `SG_D; sg2 = `SG_O; sg1 = `SG_N; sg0 = `SG_E;
            end
        endcase
    end

endmodule

`default_nettype wire

