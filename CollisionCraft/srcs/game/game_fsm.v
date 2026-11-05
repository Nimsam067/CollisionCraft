// Main game controller. Handles the title menu, the pause menu and slow motion,
// and runs whichever mode is active (tutorial, free play or challenge). It also
// decides when a release or drain is actually allowed, shows the recipe line
// after a release, and runs the demo behind the title screen. While paused, the
// physics and the challenge timer are frozen.

// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module game_fsm (
    input wire clk,
    input wire rst,
    input wire anim_tick,
    // buttons
    input wire btn_ok, btn_up, btn_down, btn_menu, btn_hint,
    // lab status
    input wire [2:0] jb_state, jc_state,
    input wire [5:0] jb_mat, jc_mat,
    input wire lab_busy,
    input wire ja_draining,
    input wire beaker_full,
    input wire [12:0] ja_count,
    // reaction tracker
    input wire rxn_seen,
    input wire [5:0] rxn_seen_id,
    input wire [5:0] disc_count,
    input wire [12:0] target_count,
    input wire [63:0] found_mask,
    // mode
    output reg [1:0] mode,
    output wire title,
    output reg [1:0] menu_sel,
    output reg paused,
    output reg [1:0] pause_sel, // 0 RESUME, 1 RESTART, 2 QUIT
    output reg slow_mo,
    // lab commands
    output wire allow_pour,
    output wire [5:0] hint_jb,
    output wire [5:0] hint_jc,
    output wire release_cmd,
    output wire drain_cmd,
    output wire clear_lab,
    output reg clear_disc,
    output wire [5:0] target_mat,
    // JA screen text
    output reg [79:0] header_str,
    output reg [15:0] header_col,
    output wire msg_show,
    output wire [79:0] msg0, msg1, msg2, msg3,
    output wire pad_show, // tutorial five button picture
    output wire [2:0] pad_hi, // tutorial which button blinks
    // 7 segment and LEDs
    output wire [4:0] sg3, sg2, sg1, sg0,
    output wire [3:0] dp,
    output wire leds_override_en,
    output reg [15:0] leds_override,
    // title screen demo
    output wire [5:0] demo_jb_mat,
    output wire [5:0] demo_jc_mat,
    output wire demo_trickle
);

    assign title = (mode == `MODE_TITLE);

    wire is_t = (mode == `MODE_TUTORIAL);
    wire is_f = (mode == `MODE_FREE);
    wire is_c = (mode == `MODE_CHALLENGE);

    // Mode switching, pause popup and slow motion
    reg enter_tut, enter_free, enter_chal, restart_chal, sys_clear;
    reg [7:0] menu_tip; // frames left of the "< = MENU" reminder after entering a mode
    reg [7:0] fblink; // frame counter for blinking text
    wire t_exit, f_exit, c_exit;
    wire t_tour; // tutorial button tour, MENU and UP are being taught, don't act on them
    wire tour_lock = is_t & t_tour;

    always @(posedge clk) begin
        enter_tut <= 1'b0;
        enter_free <= 1'b0;
        enter_chal <= 1'b0;
        restart_chal <= 1'b0;
        sys_clear <= 1'b0;
        clear_disc <= 1'b0;

        if (rst) begin
            mode <= `MODE_TITLE;
            menu_sel <= 2'd0;
            paused <= 1'b0;
            pause_sel <= 2'd0;
            slow_mo <= 1'b0;
            menu_tip <= 8'd0;
            fblink <= 8'd0;
            sys_clear <= 1'b1;
        end else begin
            if (anim_tick) begin
                fblink <= fblink + 8'd1;
                if (menu_tip != 8'd0 && !paused) menu_tip <= menu_tip - 8'd1;
            end

            case (mode)
                // title menu
                `MODE_TITLE: begin
                    paused <= 1'b0;
                    slow_mo <= 1'b0;
                    if (btn_up) menu_sel <= (menu_sel == 2'd0) ? 2'd2 : menu_sel - 2'd1;
                    if (btn_down) menu_sel <= (menu_sel == 2'd2) ? 2'd0 : menu_sel + 2'd1;
                    if (btn_ok) begin
                        sys_clear <= 1'b1;
                        menu_tip <= 8'd200; // ~3 s of "< = MENU" reminder
                        case (menu_sel)
                            2'd0: begin mode <= `MODE_TUTORIAL; enter_tut <= 1'b1; end
                            2'd1: begin mode <= `MODE_FREE; enter_free <= 1'b1; clear_disc <= 1'b1; end
                            default: begin mode <= `MODE_CHALLENGE; enter_chal <= 1'b1; end
                        endcase
                    end
                end

                // playing
                default: begin
                    if (paused) begin
                        // the popup owns the buttons
                        if (btn_menu)
                            paused <= 1'b0; // MENU again = resume
                        else if (btn_up)
                            pause_sel <= (pause_sel == 2'd0) ? 2'd2 : pause_sel - 2'd1;
                        else if (btn_down)
                            pause_sel <= (pause_sel == 2'd2) ? 2'd0 : pause_sel + 2'd1;
                        else if (btn_ok) begin
                            paused <= 1'b0;
                            case (pause_sel)
                                2'd0: ; // resume
                                2'd1: begin // restart
                                    slow_mo <= 1'b0;
                                    sys_clear <= 1'b1;
                                    menu_tip <= 8'd200;
                                    if (is_t) enter_tut <= 1'b1;
                                    else if (is_f) begin enter_free <= 1'b1; clear_disc <= 1'b1; end
                                    else restart_chal <= 1'b1;
                                end
                                default: begin // quit
                                    slow_mo <= 1'b0;
                                    mode <= `MODE_TITLE;
                                    sys_clear <= 1'b1;
                                end
                            endcase
                        end
                    end else begin
                        if (btn_menu && !tour_lock) begin
                            paused <= 1'b1;
                            pause_sel <= 2'd0;
                        end
                        if (btn_up && !tour_lock)
                            slow_mo <= ~slow_mo;
                        if ((is_t && t_exit) || (is_f && f_exit) || (is_c && c_exit)) begin
                            mode <= `MODE_TITLE;
                            sys_clear <= 1'b1;
                            slow_mo <= 1'b0;
                        end
                    end
                end
            endcase
        end
    end

    // Buttons and the 60 Hz tick only reach the mode that is running, never
    // while paused, and never on the same press that started it.
    wire in_tut = is_t && !enter_tut && !paused;
    wire in_free = is_f && !enter_free && !paused;
    wire in_chal = is_c && !enter_chal && !paused;
    wire live_tick = anim_tick && !paused;

    // The three modes
    // outputs of each mode, prefixed t_ / f_ / c_
    wire t_rel, t_drn, t_clr, t_allow; wire [5:0] t_hb, t_hc;
    wire [79:0] t_hdr, t_m0, t_m1, t_m2, t_m3; wire [15:0] t_hcol; wire t_msg;
    wire [4:0] t_s3, t_s2, t_s1, t_s0; wire [3:0] t_dp;
    wire t_pad; wire [2:0] t_padhi;

    wire f_rel, f_drn, f_clr, f_allow;
    wire [79:0] f_hdr, f_m0, f_m1, f_m2, f_m3; wire [15:0] f_hcol; wire f_msg;
    wire [4:0] f_s3, f_s2, f_s1, f_s0; wire [3:0] f_dp;

    wire c_rel, c_drn, c_clr, c_allow; wire [5:0] c_tgt;
    wire [79:0] c_hdr, c_m0, c_m1, c_m2, c_m3; wire [15:0] c_hcol; wire c_msg;
    wire [4:0] c_s3, c_s2, c_s1, c_s0; wire [3:0] c_dp;

    game_tutorial tutorial (
        .clk(clk), .rst(rst), .anim_tick(live_tick), .enter(enter_tut),
        .btn_ok(btn_ok & in_tut), .btn_up(btn_up & in_tut), .btn_down(btn_down & in_tut),
        .btn_menu(btn_menu & in_tut), .btn_hint(btn_hint & in_tut),
        .jb_state(jb_state), .jc_state(jc_state), .lab_busy(lab_busy), .ja_draining(ja_draining),
        .ja_count(ja_count), .released(release_cmd & is_t),
        .rxn_seen(rxn_seen), .rxn_seen_id(rxn_seen_id),
        .want_release(t_rel), .want_drain(t_drn), .clear_lab(t_clr), .exit_req(t_exit),
        .allow_pour(t_allow), .hint_jb(t_hb), .hint_jc(t_hc), .tour(t_tour),
        .header_str(t_hdr), .header_col(t_hcol), .msg_show(t_msg),
        .msg0(t_m0), .msg1(t_m1), .msg2(t_m2), .msg3(t_m3),
        .pad_show(t_pad), .pad_hi(t_padhi),
        .sg3(t_s3), .sg2(t_s2), .sg1(t_s1), .sg0(t_s0), .dp(t_dp)
    );

    game_freeplay freeplay (
        .clk(clk), .rst(rst), .anim_tick(live_tick), .enter(enter_free),
        .btn_ok(btn_ok & in_free), .btn_down(btn_down & in_free), .btn_hint(btn_hint & in_free),
        .lab_busy(lab_busy), .ja_draining(ja_draining), .beaker_full(beaker_full),
        .ja_count(ja_count), .released(release_cmd & is_f),
        .disc_count(disc_count), .found_mask(found_mask),
        .want_release(f_rel), .want_drain(f_drn), .clear_lab(f_clr), .exit_req(f_exit),
        .allow_pour(f_allow),
        .header_str(f_hdr), .header_col(f_hcol), .msg_show(f_msg),
        .msg0(f_m0), .msg1(f_m1), .msg2(f_m2), .msg3(f_m3),
        .sg3(f_s3), .sg2(f_s2), .sg1(f_s1), .sg0(f_s0), .dp(f_dp)
    );

    game_challenge challenge (
        .clk(clk), .rst(rst), .anim_tick(live_tick), .enter(enter_chal), .restart(restart_chal),
        .btn_ok(btn_ok & in_chal), .btn_down(btn_down & in_chal), .btn_hint(btn_hint & in_chal),
        .released(release_cmd & is_c), .target_count(target_count),
        .want_release(c_rel), .want_drain(c_drn), .clear_lab(c_clr), .exit_req(c_exit),
        .allow_pour(c_allow), .target_mat(c_tgt),
        .header_str(c_hdr), .header_col(c_hcol), .msg_show(c_msg),
        .msg0(c_m0), .msg1(c_m1), .msg2(c_m2), .msg3(c_m3),
        .sg3(c_s3), .sg2(c_s2), .sg1(c_s1), .sg0(c_s0), .dp(c_dp)
    );

    // Forward the running mode's outputs
    wire want_release = (is_t & t_rel) | (is_f & f_rel) | (is_c & c_rel);
    wire want_drain = (is_t & t_drn) | (is_f & f_drn) | (is_c & c_drn);

    assign allow_pour = !paused && ((is_t & t_allow) | (is_f & f_allow) | (is_c & c_allow));
    assign hint_jb = is_t ? t_hb : 6'd0;
    assign hint_jc = is_t ? t_hc : 6'd0;
    assign target_mat = is_c ? c_tgt : `M_EMPTY;
    assign clear_lab = sys_clear | (is_t & t_clr) | (is_f & f_clr) | (is_c & c_clr);

    // Release / drain only when physically possible
    wire any_ready = (jb_state == `CH_READY) || (jc_state == `CH_READY);
    assign release_cmd = want_release && any_ready && !lab_busy && !ja_draining && !paused;
    assign drain_cmd = want_drain && !ja_draining && !lab_busy && (ja_count != 13'd0) && !paused;

    // Recipe line
    wire [23:0] code_b, code_c;
    mat_names nb (.mat(jb_mat), .name(), .code3(code_b), .desc(), .sig_color());
    mat_names nc (.mat(jc_mat), .name(), .code3(code_c), .desc(), .sig_color());

    reg [79:0] recipe;
    reg [23:0] prev_code; // what went into the beaker last time
    reg [7:0] recipe_timer; // frames left to show the recipe

    always @(posedge clk) begin
        if (rst || clear_lab) begin
            recipe_timer <= 8'd0;
            prev_code <= "   ";
        end else begin
            if (anim_tick && recipe_timer != 8'd0) recipe_timer <= recipe_timer - 8'd1;
            if (drain_cmd) prev_code <= "   ";
            if (release_cmd) begin
                recipe_timer <= 8'd180;
                if (jb_state == `CH_READY && jc_state == `CH_READY) begin
                    recipe <= {code_b, " + ", code_c, " "};
                    prev_code <= "MIX";
                end else begin
                    if (ja_count > 13'd40 && prev_code != "   ")
                        recipe <= {prev_code, " > ", (jb_state == `CH_READY) ? code_b : code_c, " "};
                    else
                        recipe <= {(jb_state == `CH_READY) ? code_b : code_c, "       "};
                    prev_code <= (jb_state == `CH_READY) ? code_b : code_c;
                end
            end
        end
    end

    // JA text
    wire [79:0] mode_hdr = is_t ? t_hdr : is_f ? f_hdr : c_hdr;
    wire [15:0] mode_hcol = is_t ? t_hcol : is_f ? f_hcol : c_hcol;

    // Header priority
    always @* begin
        header_str = mode_hdr;
        header_col = mode_hcol;
        if (slow_mo && fblink[6]) begin
            header_str = "SLOW-MO   ";
            header_col = {5'd6, 6'd52, 5'd31};
        end
        if (!is_t && menu_tip != 8'd0 && menu_tip[5]) begin
            header_str = "< = MENU  ";
            header_col = {5'd31, 6'd48, 5'd4};
        end
        if (recipe_timer != 8'd0) begin
            header_str = recipe;
            header_col = {5'd16, 6'd56, 5'd31};
        end
        if (paused) begin
            header_str = "C = SELECT";
            header_col = {5'd31, 6'd48, 5'd4};
        end
    end

    assign msg_show = !paused && (is_t ? t_msg : is_f ? f_msg : is_c ? c_msg : 1'b0);
    assign msg0 = is_t ? t_m0 : is_f ? f_m0 : c_m0;
    assign msg1 = is_t ? t_m1 : is_f ? f_m1 : c_m1;
    assign msg2 = is_t ? t_m2 : is_f ? f_m2 : c_m2;
    assign msg3 = is_t ? t_m3 : is_f ? f_m3 : c_m3;
    assign pad_show = is_t && t_pad && !paused;
    assign pad_hi = t_padhi;

    // 7 segment, "PLAY" on the title, "PAUS" while paused, else the mode's own
    assign sg3 = title ? `SG_P : paused ? `SG_P : is_t ? t_s3 : is_f ? f_s3 : c_s3;
    assign sg2 = title ? `SG_L : paused ? `SG_A : is_t ? t_s2 : is_f ? f_s2 : c_s2;
    assign sg1 = title ? `SG_A : paused ? `SG_U : is_t ? t_s1 : is_f ? f_s1 : c_s1;
    assign sg0 = title ? `SG_Y : paused ? `SG_S : is_t ? t_s0 : is_f ? f_s0 : c_s0;
    assign dp = (title || paused) ? 4'b0000 : is_t ? t_dp : is_f ? f_dp : c_dp;

    // Title LEDs, a "scanner" sweeping across all 16
    reg [3:0] scan_pos;
    reg scan_dir;
    reg [1:0] scan_div;
    assign leds_override_en = title;
    always @(posedge clk) begin
        if (rst) begin
            scan_pos <= 4'd0; scan_dir <= 1'b0; scan_div <= 2'd0;
        end else if (anim_tick) begin
            scan_div <= scan_div + 2'd1;
            if (scan_div == 2'd0) begin
                if (!scan_dir) begin
                    if (scan_pos == 4'd15) scan_dir <= 1'b1; else scan_pos <= scan_pos + 4'd1;
                end else begin
                    if (scan_pos == 4'd0) scan_dir <= 1'b0; else scan_pos <= scan_pos - 4'd1;
                end
            end
        end
        leds_override <= 16'd1 << scan_pos;
    end

    // Title demo, both chambers pour forever into the beaker, cycling materials
    reg [7:0] demo_frames;
    reg [2:0] demo_idx;
    reg trickle;
    always @(posedge clk) begin
        if (rst) begin
            demo_frames <= 8'd0; demo_idx <= 3'd0; trickle <= 1'b0;
        end else if (anim_tick) begin
            trickle <= ~trickle;
            if (demo_frames == 8'd239) begin
                demo_frames <= 8'd0;
                demo_idx <= (demo_idx == 3'd5) ? 3'd0 : demo_idx + 3'd1;
            end else
                demo_frames <= demo_frames + 8'd1;
        end
    end
    wire [2:0] demo_idx2 = (demo_idx >= 3'd3) ? demo_idx - 3'd3 : demo_idx + 3'd3;
    assign demo_jb_mat = {3'd0, demo_idx} + `M_WATER;
    assign demo_jc_mat = {3'd0, demo_idx2} + `M_WATER;
    assign demo_trickle = trickle;

endmodule
