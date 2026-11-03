// =============================================================================
//  CollisionCraft_Top.v  --  TOP LEVEL: wires the whole lab together
// -----------------------------------------------------------------------------
//  OWNER: shared
//
//   SWITCHES                          SCREENS
//   sw15..sw10  JB material (left)    JB  left reagent chamber
//   sw9         (unused)              JC  right reagent chamber
//   sw8, sw7    1-OLED test view      JA  reaction beaker + menus
//   sw6         (unused)              (see SINGLE-OLED TEST MODE below)
//   sw5..sw0    JC material (right)
//     order on BOTH sides, left to right:  WATER SAND LAVA METAL ACID OIL
//   The four LEDs above sw9..sw6 stay lit as a "barricade" between the sides.
//
//   BUTTONS - the board is held turned 90 degrees anticlockwise, so each
//   button is named by where it sits from the PLAYER's point of view:
//     board btnC  -> OK    : select / RELEASE ready chambers into the beaker
//     board btnR  -> UP    : move up    (in the lab: SLOW MOTION on/off)
//     board btnL  -> DOWN  : move down  (in the lab: DRAIN the beaker)
//     board btnU  -> MENU  : pause pop-up (resume / restart / quit)
//     board btnD  -> HINT  : hints (challenge, free play) / skip tutorial step
//   To change which board button does what, edit "Buttons" below only.
//
//  DATA FLOW (one arrow = one module boundary)
//
//   switches -> mat_switch_select -> phys_chamber_ctrl -> phys_emitter
//                                                            |
//                     phys_engine (JB) <---------------------+
//                          |  grains falling out of the valve
//                          v
//                    phys_transfer_fifo  --> phys_engine (JA) <-> rxn_table
//                                                 |                  rxn_self
//                                                 v
//                                            rxn_tracker --> game_fsm
//                                                                |
//   phys_grid_ram (x3) --> gfx_*_screen (x3) --> Oled_Display (x3)
//
//  >>> SCREEN ORIENTATION: if a screen is upside down on your board, change
//      its *_ROTATE value below (0 <-> 1). Nothing else needs touching. <<<
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module CollisionCraft_Top (
    input  wire        clk,          // 100 MHz
    input  wire [15:0] sw,
    input  wire        btnC, btnU, btnD, btnL, btnR,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an,
    output wire [7:0]  JA,
    output wire [7:0]  JB,
    output wire [7:0]  JC
);

    localparam JB_ROTATE = 1;
    localparam JC_ROTATE = 1;
    localparam JA_ROTATE = 0;     // JA sits on the opposite edge of the board

    // =================================================================================
    //  Clocks, reset and timing ticks
    // =================================================================================
    wire clk_core, clk_oled, rst;
    clock_gen u_clocks (.clk100(clk), .clk_core(clk_core), .clk_oled(clk_oled), .rst_core(rst));

    // 60 Hz animation tick for LEDs, timers and banners
    reg [18:0] anim_cnt = 19'd0;
    reg        anim_tick = 1'b0;
    always @(posedge clk_core) begin
        anim_tick <= 1'b0;
        if (anim_cnt == `ANIM_DIV) begin
            anim_cnt  <= 19'd0;
            anim_tick <= 1'b1;
        end else
            anim_cnt <= anim_cnt + 19'd1;
    end

    // =================================================================================
    //  Buttons  (Person 1)
    //  Physical board button -> job. This is the ONLY place that knows which
    //  physical button is which; everything else uses the job names.
    // =================================================================================
    wire ok_press, up_press, down_press, menu_press, hint_press;
    ui_debounce db_ok   (.clk(clk_core), .rst(rst), .btn_raw(btnC), .level(), .press(ok_press),   .hold());
    ui_debounce db_up   (.clk(clk_core), .rst(rst), .btn_raw(btnR), .level(), .press(up_press),   .hold());
    ui_debounce db_down (.clk(clk_core), .rst(rst), .btn_raw(btnL), .level(), .press(down_press), .hold());
    ui_debounce db_menu (.clk(clk_core), .rst(rst), .btn_raw(btnU), .level(), .press(menu_press), .hold());
    ui_debounce db_hint (.clk(clk_core), .rst(rst), .btn_raw(btnD), .level(), .press(hint_press), .hold());

    // =================================================================================
    //  Signals shared between the sections
    // =================================================================================
    // game director outputs
    wire [1:0]  mode, menu_sel, pause_sel;
    wire        paused, slow_mo, pad_show;
    wire [2:0]  pad_hi;
    wire [63:0] found_mask;
    wire        title, allow_pour, release_cmd, drain_cmd, clear_lab, clear_disc;
    wire [5:0]  hint_jb, hint_jc, target_mat, demo_jb_mat, demo_jc_mat;
    wire        demo_trickle;
    wire [79:0] header_str, msg0, msg1, msg2, msg3;
    wire [15:0] header_col;
    wire        msg_show;
    wire [4:0]  sg3, sg2, sg1, sg0;
    wire [3:0]  sg_dp;
    wire        leds_override_en;
    wire [15:0] leds_override;

    // the beaker pops grains out of the two transfer pipes
    wire        ja_pop0, ja_pop1;

    // the lab is held in reset on the title screen and when a mode wipes it
    wire lab_reset = rst | clear_lab | title;

    // physics step heartbeat (slow motion comes from the UP button via game_fsm)
    wire step_raw;
    wire jb_busy, jc_busy, ja_busy;
    phys_step_timer stepper (.clk(clk_core), .rst(rst), .slow(slow_mo),
                             .any_busy(jb_busy | jc_busy | ja_busy), .step(step_raw));
    // while the pause pop-up is open the whole lab freezes
    wire step = step_raw & ~paused;

    // =================================================================================
    //  LEFT reagent chamber: JB
    // =================================================================================
    // Physical switches sw15..sw10 -> bit 0 (WATER) .. bit 5 (OIL)
    wire [5:0] jb_sw = {sw[10], sw[11], sw[12], sw[13], sw[14], sw[15]};
    wire [1:0] jb_sel_state;  wire [5:0] jb_sel_mat, jb_led;
    wire [2:0] jb_state;      wire [5:0] jb_mat;
    wire       jb_emit_start, jb_emit_stop, jb_emit_pause, jb_emit_done;
    wire       jb_valve, jb_trap, jb_ctl_flush;  wire [1:0] jb_ctl_sink;
    wire       jb_src_valid, jb_pop;   wire [5:0] jb_src_mat, jb_src_x0;
    wire [1:0] jb_src_wlog;            wire [6:0] jb_src_y;
    wire       jb_step_done;           wire [12:0] jb_count;
    wire       jb_exit_valid;          wire [5:0] jb_exit_mat;
    wire       fifo_jb_empty, fifo_jb_afull;  wire [5:0] fifo_jb_dout;

    mat_switch_select sel_jb (
        .clk(clk_core), .rst(rst), .anim_tick(anim_tick), .sw_raw(jb_sw),
        .ch_state(jb_state), .ch_mat(jb_mat), .allow(allow_pour), .hint(hint_jb),
        .sel_state(jb_sel_state), .sel_mat(jb_sel_mat), .led(jb_led)
    );

    phys_chamber_ctrl ctl_jb (
        .clk(clk_core), .rst(lab_reset), .step_done(jb_step_done), .cell_count(jb_count),
        .sel_state(jb_sel_state), .sel_mat(jb_sel_mat), .allow_pour(allow_pour),
        .release_cmd(release_cmd), .emit_done(jb_emit_done),
        .state(jb_state), .cur_mat(jb_mat),
        .emit_start(jb_emit_start), .emit_stop(jb_emit_stop), .emit_pause(jb_emit_pause),
        .valve_open(jb_valve), .trapdoor_open(jb_trap), .sink_mode(jb_ctl_sink), .flush(jb_ctl_flush)
    );

    phys_emitter em_jb (
        .clk(clk_core), .rst(lab_reset), .start(jb_emit_start), .start_mat(jb_mat),
        .stop(jb_emit_stop), .pause(jb_emit_pause), .continuous(title), .demo_mat(demo_jb_mat),
        .pop(jb_pop), .valid(jb_src_valid), .mat(jb_src_mat), .x0(jb_src_x0), .wlog(jb_src_wlog),
        .y(jb_src_y), .done(jb_emit_done)
    );

    wire [12:0] jb_ra_addr;  wire [15:0] jb_ra_wdata, jb_ra_rdata;  wire jb_ra_we;
    wire [12:0] jb_rb_addr;  wire [15:0] jb_rb_data;

    phys_engine #(.CHAMBER(0), .INJ_TRIES(6), .SEED(32'h1234_ABCD)) eng_jb (
        .clk(clk_core), .rst(rst), .step_req(step), .clear_req(clear_lab), .age_req(1'b0),
        .flush(title | jb_ctl_flush),
        .sink_mode(title ? `SINK_DELETE : jb_ctl_sink), .sink_block(fifo_jb_afull),
        .valve_open(jb_valve), .trapdoor_open(title | jb_trap), .drain_open(1'b0),
        .src0_valid(jb_src_valid), .src0_mat(jb_src_mat), .src0_x0(jb_src_x0),
        .src0_wlog(jb_src_wlog), .src0_y(jb_src_y), .src0_pop(jb_pop),
        .src1_valid(1'b0), .src1_mat(6'd0), .src1_x0(6'd0), .src1_wlog(2'd0), .src1_y(7'd0), .src1_pop(),
        .ram_addr(jb_ra_addr), .ram_wdata(jb_ra_wdata), .ram_we(jb_ra_we), .ram_rdata(jb_ra_rdata),
        .exit_valid(jb_exit_valid), .exit_mat(jb_exit_mat),
        .rxn_valid(), .rxn_id(), .rxn_fx(), .visit_valid(), .visit_mat(),
        .step_done(jb_step_done), .cell_count(jb_count), .busy(jb_busy)
    );

    phys_grid_ram ram_jb (
        .clk_a(clk_core), .addr_a(jb_ra_addr), .we_a(jb_ra_we), .din_a(jb_ra_wdata), .dout_a(jb_ra_rdata),
        .clk_b(clk_oled), .addr_b(jb_rb_addr), .dout_b(jb_rb_data)
    );

    phys_transfer_fifo fifo_jb (
        .clk(clk_core), .rst(rst | clear_lab), .push(jb_exit_valid), .din(jb_exit_mat),
        .pop(ja_pop0 & ~title), .dout(fifo_jb_dout), .empty(fifo_jb_empty), .almost_full(fifo_jb_afull)
    );

    // =================================================================================
    //  RIGHT reagent chamber: JC  (identical to JB)
    // =================================================================================
    // Physical switches sw5..sw0 -> bit 0 (WATER) .. bit 5 (OIL)
    wire [5:0] jc_sw = {sw[0], sw[1], sw[2], sw[3], sw[4], sw[5]};
    wire [1:0] jc_sel_state;  wire [5:0] jc_sel_mat, jc_led;
    wire [2:0] jc_state;      wire [5:0] jc_mat;
    wire       jc_emit_start, jc_emit_stop, jc_emit_pause, jc_emit_done;
    wire       jc_valve, jc_trap, jc_ctl_flush;  wire [1:0] jc_ctl_sink;
    wire       jc_src_valid, jc_pop;   wire [5:0] jc_src_mat, jc_src_x0;
    wire [1:0] jc_src_wlog;            wire [6:0] jc_src_y;
    wire       jc_step_done;           wire [12:0] jc_count;
    wire       jc_exit_valid;          wire [5:0] jc_exit_mat;
    wire       fifo_jc_empty, fifo_jc_afull;  wire [5:0] fifo_jc_dout;

    mat_switch_select sel_jc (
        .clk(clk_core), .rst(rst), .anim_tick(anim_tick), .sw_raw(jc_sw),
        .ch_state(jc_state), .ch_mat(jc_mat), .allow(allow_pour), .hint(hint_jc),
        .sel_state(jc_sel_state), .sel_mat(jc_sel_mat), .led(jc_led)
    );

    phys_chamber_ctrl ctl_jc (
        .clk(clk_core), .rst(lab_reset), .step_done(jc_step_done), .cell_count(jc_count),
        .sel_state(jc_sel_state), .sel_mat(jc_sel_mat), .allow_pour(allow_pour),
        .release_cmd(release_cmd), .emit_done(jc_emit_done),
        .state(jc_state), .cur_mat(jc_mat),
        .emit_start(jc_emit_start), .emit_stop(jc_emit_stop), .emit_pause(jc_emit_pause),
        .valve_open(jc_valve), .trapdoor_open(jc_trap), .sink_mode(jc_ctl_sink), .flush(jc_ctl_flush)
    );

    phys_emitter em_jc (
        .clk(clk_core), .rst(lab_reset), .start(jc_emit_start), .start_mat(jc_mat),
        .stop(jc_emit_stop), .pause(jc_emit_pause), .continuous(title), .demo_mat(demo_jc_mat),
        .pop(jc_pop), .valid(jc_src_valid), .mat(jc_src_mat), .x0(jc_src_x0), .wlog(jc_src_wlog),
        .y(jc_src_y), .done(jc_emit_done)
    );

    wire [12:0] jc_ra_addr;  wire [15:0] jc_ra_wdata, jc_ra_rdata;  wire jc_ra_we;
    wire [12:0] jc_rb_addr;  wire [15:0] jc_rb_data;

    phys_engine #(.CHAMBER(0), .INJ_TRIES(6), .SEED(32'h5EED_C0DE)) eng_jc (
        .clk(clk_core), .rst(rst), .step_req(step), .clear_req(clear_lab), .age_req(1'b0),
        .flush(title | jc_ctl_flush),
        .sink_mode(title ? `SINK_DELETE : jc_ctl_sink), .sink_block(fifo_jc_afull),
        .valve_open(jc_valve), .trapdoor_open(title | jc_trap), .drain_open(1'b0),
        .src0_valid(jc_src_valid), .src0_mat(jc_src_mat), .src0_x0(jc_src_x0),
        .src0_wlog(jc_src_wlog), .src0_y(jc_src_y), .src0_pop(jc_pop),
        .src1_valid(1'b0), .src1_mat(6'd0), .src1_x0(6'd0), .src1_wlog(2'd0), .src1_y(7'd0), .src1_pop(),
        .ram_addr(jc_ra_addr), .ram_wdata(jc_ra_wdata), .ram_we(jc_ra_we), .ram_rdata(jc_ra_rdata),
        .exit_valid(jc_exit_valid), .exit_mat(jc_exit_mat),
        .rxn_valid(), .rxn_id(), .rxn_fx(), .visit_valid(), .visit_mat(),
        .step_done(jc_step_done), .cell_count(jc_count), .busy(jc_busy)
    );

    phys_grid_ram ram_jc (
        .clk_a(clk_core), .addr_a(jc_ra_addr), .we_a(jc_ra_we), .din_a(jc_ra_wdata), .dout_a(jc_ra_rdata),
        .clk_b(clk_oled), .addr_b(jc_rb_addr), .dout_b(jc_rb_data)
    );

    phys_transfer_fifo fifo_jc (
        .clk(clk_core), .rst(rst | clear_lab), .push(jc_exit_valid), .din(jc_exit_mat),
        .pop(ja_pop1 & ~title), .dout(fifo_jc_dout), .empty(fifo_jc_empty), .almost_full(fifo_jc_afull)
    );

    // =================================================================================
    //  Reaction beaker: JA
    // =================================================================================
    wire        ja_draining, bk_drain_open, bk_flush;  wire [1:0] bk_sink;
    wire        ja_step_done;  wire [12:0] ja_count;
    wire        ja_rxn_valid;  wire [5:0] ja_rxn_id;   wire [1:0] ja_rxn_fx;
    wire        ja_visit_valid; wire [5:0] ja_visit_mat;

    phys_beaker_ctrl beaker (
        .clk(clk_core), .rst(lab_reset), .step_done(ja_step_done), .cell_count(ja_count),
        .drain_cmd(drain_cmd), .draining(ja_draining), .drain_open(bk_drain_open),
        .sink_mode(bk_sink), .flush(bk_flush)
    );

    wire [12:0] ja_ra_addr;  wire [15:0] ja_ra_wdata, ja_ra_rdata;  wire ja_ra_we;
    wire [12:0] ja_rb_addr;  wire [15:0] ja_rb_data;

    // On the title screen the beaker is fed by the demo instead of the pipes
    phys_engine #(.CHAMBER(1), .INJ_TRIES(4), .SEED(32'hBEEF_F00D)) eng_ja (
        .clk(clk_core), .rst(rst), .step_req(step), .clear_req(clear_lab),
        .age_req(release_cmd),          // everything already in the beaker becomes "first"
        .flush(title | bk_flush),
        .sink_mode(title ? `SINK_DELETE : bk_sink), .sink_block(1'b0),
        .valve_open(1'b0), .trapdoor_open(1'b0), .drain_open(title | bk_drain_open),
        // left funnel <- JB pipe
        .src0_valid(title ? demo_trickle : !fifo_jb_empty),
        .src0_mat  (title ? demo_jb_mat  : fifo_jb_dout),
        .src0_x0(6'd14), .src0_wlog(2'd2), .src0_y(7'd11), .src0_pop(ja_pop0),
        // right funnel <- JC pipe
        .src1_valid(title ? demo_trickle : !fifo_jc_empty),
        .src1_mat  (title ? demo_jc_mat  : fifo_jc_dout),
        .src1_x0(6'd46), .src1_wlog(2'd2), .src1_y(7'd11), .src1_pop(ja_pop1),
        .ram_addr(ja_ra_addr), .ram_wdata(ja_ra_wdata), .ram_we(ja_ra_we), .ram_rdata(ja_ra_rdata),
        .exit_valid(), .exit_mat(),
        .rxn_valid(ja_rxn_valid), .rxn_id(ja_rxn_id), .rxn_fx(ja_rxn_fx),
        .visit_valid(ja_visit_valid), .visit_mat(ja_visit_mat),
        .step_done(ja_step_done), .cell_count(ja_count), .busy(ja_busy)
    );

    phys_grid_ram ram_ja (
        .clk_a(clk_core), .addr_a(ja_ra_addr), .we_a(ja_ra_we), .din_a(ja_ra_wdata), .dout_a(ja_ra_rdata),
        .clk_b(clk_oled), .addr_b(ja_rb_addr), .dout_b(ja_rb_data)
    );

    // "busy" = something is still flowing down to the beaker
    wire lab_busy = (jb_state == `CH_RELEASE) || (jc_state == `CH_RELEASE) ||
                    !fifo_jb_empty || !fifo_jc_empty;

    // =================================================================================
    //  Reactions bookkeeping and game director  (Person 3)
    // =================================================================================
    wire [12:0] target_count;
    wire [5:0]  disc_count, rxn_seen_id;
    wire        new_disc, rxn_seen;
    wire        banner_show, banner_new, beaker_full;
    wire [79:0] banner_str;
    wire [15:0] banner_col;
    wire [3:0]  flash;
    wire [6:0]  fill_rows;

    rxn_tracker tracker (
        .clk(clk_core), .rst(rst), .anim_tick(anim_tick), .enable(!title),
        .clear_disc(clear_disc), .clear_banner(clear_lab),
        .rxn_valid(ja_rxn_valid), .rxn_id(ja_rxn_id), .rxn_fx(ja_rxn_fx),
        .visit_valid(ja_visit_valid), .visit_mat(ja_visit_mat), .step_done(ja_step_done),
        .ja_count(ja_count), .target_mat(target_mat),
        .target_count(target_count), .disc_count(disc_count), .new_disc(new_disc),
        .rxn_seen(rxn_seen), .rxn_seen_id(rxn_seen_id),
        .banner_show(banner_show), .banner_str(banner_str), .banner_new(banner_new),
        .banner_col(banner_col), .flash(flash), .fill_rows(fill_rows), .beaker_full(beaker_full),
        .found_mask(found_mask)
    );

    game_fsm director (
        .clk(clk_core), .rst(rst), .anim_tick(anim_tick),
        .btn_ok(ok_press), .btn_up(up_press), .btn_down(down_press),
        .btn_menu(menu_press), .btn_hint(hint_press),
        .jb_state(jb_state), .jc_state(jc_state), .jb_mat(jb_mat), .jc_mat(jc_mat),
        .lab_busy(lab_busy), .ja_draining(ja_draining), .beaker_full(beaker_full), .ja_count(ja_count),
        .rxn_seen(rxn_seen), .rxn_seen_id(rxn_seen_id), .disc_count(disc_count), .target_count(target_count),
        .found_mask(found_mask),
        .mode(mode), .title(title), .menu_sel(menu_sel),
        .paused(paused), .pause_sel(pause_sel), .slow_mo(slow_mo),
        .allow_pour(allow_pour), .hint_jb(hint_jb), .hint_jc(hint_jc),
        .release_cmd(release_cmd), .drain_cmd(drain_cmd), .clear_lab(clear_lab), .clear_disc(clear_disc),
        .target_mat(target_mat),
        .header_str(header_str), .header_col(header_col), .msg_show(msg_show),
        .msg0(msg0), .msg1(msg1), .msg2(msg2), .msg3(msg3),
        .pad_show(pad_show), .pad_hi(pad_hi),
        .sg3(sg3), .sg2(sg2), .sg1(sg1), .sg0(sg0), .dp(sg_dp),
        .leds_override_en(leds_override_en), .leds_override(leds_override),
        .demo_jb_mat(demo_jb_mat), .demo_jc_mat(demo_jc_mat), .demo_trickle(demo_trickle)
    );

    // =================================================================================
    //  Screens  (Person 1)
    // =================================================================================
    wire        jb_fb, jb_sp;  wire [12:0] jb_pi;  wire [15:0] jb_pd;
    wire        jc_fb, jc_sp;  wire [12:0] jc_pi;  wire [15:0] jc_pd;
    wire        ja_fb, ja_sp;  wire [12:0] ja_pi;  wire [15:0] ja_pd;

    gfx_reagent_screen #(.ROTATE(JB_ROTATE)) screen_jb (
        .clk(clk_oled), .pixel_index(jb_pi), .sending_pixels(jb_sp), .frame_begin(jb_fb),
        .ram_addr(jb_rb_addr), .ram_data(jb_rb_data),
        .ch_state(title ? `CH_POUR : jb_state), .ch_mat(title ? demo_jb_mat : jb_mat),
        .valve_open(jb_valve), .trapdoor_open(title | jb_trap), .demo(title),
        .pixel_data(jb_pd)
    );

    gfx_reagent_screen #(.ROTATE(JC_ROTATE)) screen_jc (
        .clk(clk_oled), .pixel_index(jc_pi), .sending_pixels(jc_sp), .frame_begin(jc_fb),
        .ram_addr(jc_rb_addr), .ram_data(jc_rb_data),
        .ch_state(title ? `CH_POUR : jc_state), .ch_mat(title ? demo_jc_mat : jc_mat),
        .valve_open(jc_valve), .trapdoor_open(title | jc_trap), .demo(title),
        .pixel_data(jc_pd)
    );

    gfx_reaction_screen #(.ROTATE(JA_ROTATE)) screen_ja (
        .clk(clk_oled), .pixel_index(ja_pi), .sending_pixels(ja_sp), .frame_begin(ja_fb),
        .ram_addr(ja_rb_addr), .ram_data(ja_rb_data),
        .title_view(title), .menu_sel(menu_sel),
        .header_str(header_str), .header_col(header_col),
        .msg_show(msg_show), .msg0(msg0), .msg1(msg1), .msg2(msg2), .msg3(msg3),
        .banner_show(banner_show), .banner_str(banner_str), .banner_new(banner_new),
        .banner_col(banner_col), .flash(flash), .fill_rows(fill_rows),
        .drain_open(title | bk_drain_open),
        .pause_show(paused), .pause_sel(pause_sel),
        .pad_show(pad_show), .pad_hi(pad_hi),
        .pixel_data(ja_pd)
    );

    // ---- SINGLE-OLED TEST MODE ------------------------------------------------------------------
    //  Only one OLED? Plug it into ANY of JA / JB / JC and pick what it shows with sw8, sw7:
    //     sw8 sw7 = 0 0 : normal (each header shows its own screen)
    //               0 1 : every header shows JB (left chamber)
    //               1 0 : every header shows JC (right chamber)
    //               1 1 : every header shows JA (reaction beaker)
    //  This works because all three OLED drivers share one clock and start together, so
    //  they always ask for the same pixel at the same moment.
    wire [1:0]  view_sel = {sw[8], sw[7]};
    wire [15:0] view_pd  = (view_sel == 2'd1) ? jb_pd :
                           (view_sel == 2'd2) ? jc_pd : ja_pd;
    wire [15:0] jb_out   = (view_sel == 2'd0) ? jb_pd : view_pd;
    wire [15:0] jc_out   = (view_sel == 2'd0) ? jc_pd : view_pd;
    wire [15:0] ja_out   = (view_sel == 2'd0) ? ja_pd : view_pd;

    // ---- The three OLED drivers (given module, unmodified) ------------------------------------
    //  Pmod pin order: 0 cs, 1 sdin, 2 (unused), 3 sclk, 4 d_cn, 5 resn, 6 vccen, 7 pmoden
    Oled_Display oled_jb (
        .clk(clk_oled), .reset(1'b0), .frame_begin(jb_fb), .sending_pixels(jb_sp),
        .sample_pixel(), .pixel_index(jb_pi), .pixel_data(jb_out),
        .cs(JB[0]), .sdin(JB[1]), .sclk(JB[3]), .d_cn(JB[4]), .resn(JB[5]), .vccen(JB[6]), .pmoden(JB[7])
    );
    assign JB[2] = 1'b0;

    Oled_Display oled_jc (
        .clk(clk_oled), .reset(1'b0), .frame_begin(jc_fb), .sending_pixels(jc_sp),
        .sample_pixel(), .pixel_index(jc_pi), .pixel_data(jc_out),
        .cs(JC[0]), .sdin(JC[1]), .sclk(JC[3]), .d_cn(JC[4]), .resn(JC[5]), .vccen(JC[6]), .pmoden(JC[7])
    );
    assign JC[2] = 1'b0;

    Oled_Display oled_ja (
        .clk(clk_oled), .reset(1'b0), .frame_begin(ja_fb), .sending_pixels(ja_sp),
        .sample_pixel(), .pixel_index(ja_pi), .pixel_data(ja_out),
        .cs(JA[0]), .sdin(JA[1]), .sclk(JA[3]), .d_cn(JA[4]), .resn(JA[5]), .vccen(JA[6]), .pmoden(JA[7])
    );
    assign JA[2] = 1'b0;

    // =================================================================================
    //  LEDs and 7-segment
    // =================================================================================
    // Explosions flash every LED for a moment; the title screen runs its scanner.
    // Otherwise: left switch LEDs | solid "barricade" over sw9..sw6 | right switch LEDs
    wire led_burst = (flash >= 4'd12);
    assign led = led_burst        ? 16'hFFFF :
                 leds_override_en ? leds_override :
                 { jb_led[0], jb_led[1], jb_led[2], jb_led[3], jb_led[4], jb_led[5],   // led15..10
                   4'b1111,                                                            // led9..6 barricade
                   jc_led[0], jc_led[1], jc_led[2], jc_led[3], jc_led[4], jc_led[5] }; // led5..0

    ui_seven_seg sevenseg (
        .clk(clk_core), .d3(sg3), .d2(sg2), .d1(sg1), .d0(sg0), .dp_on(sg_dp),
        .seg(seg), .dp(dp), .an(an)
    );

endmodule

`default_nettype wire
