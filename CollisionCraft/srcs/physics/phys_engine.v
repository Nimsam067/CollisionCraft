// The falling sand physics engine, one per screen. Each step (120 per second) it
// adds new grains at the spawn points, then goes through every cell from the
// bottom row up. For each grain it checks, in order, whether it changes on its
// own (rxn_self), reacts with a neighbour (rxn_table) or moves
// (phys_move_rules). The parity bit in each cell stops a grain being moved twice
// in one step. clear_req wipes the grid, and age_req ages the order tags before
// a new release into JA.
//
// Owner: Aadi (Physics Engine)

`include "cc_defines.vh"

module phys_engine #(
    parameter        CHAMBER   = 0,               // 0 = reagent (JB/JC), 1 = beaker (JA)
    parameter        INJ_TRIES = 4,               // spawn attempts per source per step (max 8)
    parameter [31:0] SEED      = 32'hACE1_2468    // random seed (different per screen)
)(
    input  wire        clk,
    input  wire        rst,

    // control
    input  wire        step_req,        // pulse: run one physics step
    input  wire        clear_req,       // pulse: wipe the grid
    input  wire        age_req,         // pulse: next step ages the order tags
    input  wire        flush,           // draining: solids fall, gases vanish
    input  wire [1:0]  sink_mode,       // what happens at the bottom edge (SINK_*)
    input  wire        sink_block,      // transfer pipe nearly full: keep floor shut
    input  wire        valve_open,      // geometry: reagent valve
    input  wire        trapdoor_open,   // geometry: reagent trapdoor
    input  wire        drain_open,      // geometry: beaker drain

    // grain sources (spawn points)
    input  wire        src0_valid,
    input  wire [5:0]  src0_mat,
    input  wire [5:0]  src0_x0,         // left edge of the spawn area
    input  wire [1:0]  src0_wlog,       // spawn width = 1, 2, 4 or 8 pixels
    input  wire [6:0]  src0_y,
    output reg         src0_pop,        // pulse: one grain was placed
    input  wire        src1_valid,
    input  wire [5:0]  src1_mat,
    input  wire [5:0]  src1_x0,
    input  wire [1:0]  src1_wlog,
    input  wire [6:0]  src1_y,
    output reg         src1_pop,

    // grid RAM, port A
    output reg  [12:0] ram_addr,
    output reg  [15:0] ram_wdata,
    output reg         ram_we,
    input  wire [15:0] ram_rdata,

    // events for other modules
    output reg         exit_valid,      // a grain fell out of the bottom into the pipe
    output reg  [5:0]  exit_mat,
    output reg         rxn_valid,       // a reaction just happened
    output reg  [5:0]  rxn_id,
    output reg  [1:0]  rxn_fx,
    output reg         visit_valid,     // stream of every grain visited (for counting)
    output reg  [5:0]  visit_mat,
    output reg         step_done,       // pulse at the end of each step
    output reg  [12:0] cell_count,      // grains on screen after the last step
    output wire        busy
);

    // State machine
    localparam [3:0] S_IDLE    = 4'd0,
                     S_CLEAR   = 4'd1,
                     S_INJ_RD  = 4'd2,
                     S_INJ_WR  = 4'd3,
                     S_C_ISSUE = 4'd4,
                     S_NB      = 4'd5,
                     S_DECIDE  = 4'd6,
                     S_WA      = 4'd7,
                     S_WB      = 4'd8,
                     S_NEXT    = 4'd9,
                     S_DONE    = 4'd10;

    reg [3:0]  state;
    assign busy = (state != S_IDLE);

    reg        cur_par;          // parity of the current step
    reg        dir;              // 0 = sweep left to right, 1 = right to left
    reg        age_mode;         // this step only ages tags
    reg        step_pending, clear_pending, age_pending;

    reg [5:0]  sx;               // scan position
    reg [6:0]  sy;
    reg [12:0] cnt;              // grains counted in this step
    reg [12:0] clr_addr;

    // neighbour reading
    reg [3:0]  nb_idx;           // slot being requested this cycle
    reg [3:0]  pend_slot;        // slot whose data arrives this cycle
    reg        pend_ovr;         // ... and it was a wall/sink, not a RAM read
    reg [5:0]  pend_ovr_mat;
    reg [175:0] slots;           // 11 cells x 16 bits; slot k at [16*k +: 16]

    // injection
    reg        inj_src;
    reg [2:0]  inj_try;
    reg [5:0]  inj_x;
    reg [6:0]  inj_y;
    reg        inj_blocked;

    // pending writes
    reg        wa_en, wb_en;
    reg [12:0] wa_addr, wb_addr;
    reg [15:0] wa_data, wb_data;

    // Randomness
    wire [31:0] rnd;
    phys_lfsr #(.SEED(SEED)) lfsr (.clk(clk), .rnd(rnd));

    // Neighbour offsets
    // slot:  0=C 1=D 2=DL 3=DR 4=L 5=R 6=U 7=UL 8=UR 9=L2 10=R2
    function signed [3:0] off_x;
        input [3:0] s;
        case (s)
            4'd2, 4'd4, 4'd7: off_x = -4'sd1;
            4'd3, 4'd5, 4'd8: off_x =  4'sd1;
            4'd9:             off_x = -4'sd2;
            4'd10:            off_x =  4'sd2;
            default:          off_x =  4'sd0;
        endcase
    endfunction
    function signed [3:0] off_y;
        input [3:0] s;
        case (s)
            4'd1, 4'd2, 4'd3: off_y =  4'sd1;
            4'd6, 4'd7, 4'd8: off_y = -4'sd1;
            default:          off_y =  4'sd0;
        endcase
    endfunction

    // Coordinates of a slot relative to the current scan position
    function [12:0] slot_addr;
        input [3:0] s;
        input [5:0] cx;
        input [6:0] cy;
        reg   [6:0] ax, ay;
        reg   [3:0] ox, oy;
        begin
            ox = off_x(s);
            oy = off_y(s);
            ax = {1'b0, cx} + {{3{ox[3]}}, ox};   // sign extended add
            ay = cy         + {{3{oy[3]}}, oy};
            slot_addr = {ay, ax[5:0]};
        end
    endfunction

    // The "probe": the one cell we are asking about this cycle
    // (either reading it from RAM, or knowing it is a wall/sink without reading)
    reg  signed [8:0] probe_x, probe_y;
    wire [5:0] inj_mask  = (inj_src ? src1_wlog : src0_wlog) == 2'd0 ? 6'd0 :
                           (inj_src ? src1_wlog : src0_wlog) == 2'd1 ? 6'd1 :
                           (inj_src ? src1_wlog : src0_wlog) == 2'd2 ? 6'd3 : 6'd7;
    wire [5:0] inj_new_x = (inj_src ? src1_x0 : src0_x0) + (rnd[5:0] & inj_mask);
    wire [6:0] inj_new_y = inj_src ? src1_y : src0_y;

    always @* begin
        case (state)
            S_INJ_RD: begin
                probe_x = $signed({3'b0, inj_new_x});
                probe_y = $signed({2'b0, inj_new_y});
            end
            S_C_ISSUE: begin
                probe_x = $signed({3'b0, sx});
                probe_y = $signed({2'b0, sy});
            end
            default: begin   // S_NB: the neighbour we are requesting
                probe_x = $signed({3'b0, sx}) + off_x(nb_idx);
                probe_y = $signed({2'b0, sy}) + off_y(nb_idx);
            end
        endcase
    end

    wire geo_wall;
    gfx_chamber_geometry #(.CHAMBER(CHAMBER)) geo (
        .x(probe_x[6:0]), .y(probe_y[6:0]),
        .valve_open(valve_open), .trapdoor_open(trapdoor_open), .drain_open(drain_open),
        .is_wall(geo_wall), .part(), .interior()
    );

    wire probe_oob_side = (probe_x < 0) || (probe_x > 9'sd63) || (probe_y < 0);
    wire probe_below    = (probe_y > 9'sd95);
    wire sink_open      = (sink_mode != `SINK_CLOSED) && !sink_block;
    // what this probe is, if we do NOT need RAM for it
    wire       probe_ovr     = probe_oob_side || probe_below || geo_wall;
    wire [5:0] probe_ovr_mat = (probe_below && !probe_oob_side && sink_open) ? `M_SINK : `M_WALL;

    // Unpack the slots for the decision logic
    wire [15:0] c_cell  = slots[15:0];
    wire [5:0]  c_mat   = c_cell[`C_MAT];
    wire [3:0]  c_life  = c_cell[`C_LIFE];
    wire [2:0]  c_shade = c_cell[`C_SHADE];
    wire [1:0]  c_tag   = c_cell[`C_TAG];

    wire [59:0] nb_mats;
    genvar g;
    generate
        for (g = 1; g <= 10; g = g + 1) begin : unpack
            assign nb_mats[6*(g-1) +: 6] = slots[16*g +: 6];
        end
    endgenerate

    // (a) self change
    wire       s_trans;
    wire [5:0] s_mat;
    wire [3:0] s_life;
    rxn_self self_rule (
        .mat(c_mat), .life(c_life), .flush(flush), .rnd(rnd[21:14]),
        .transform(s_trans), .new_mat(s_mat), .new_life(s_life)
    );

    // (b) reaction with one random neighbour (down, left, right or up)
    reg [3:0] rx_slot;
    always @* begin
        case (rnd[5:4])
            2'd0:    rx_slot = 4'd1;   // D
            2'd1:    rx_slot = 4'd4;   // L
            2'd2:    rx_slot = 4'd5;   // R
            default: rx_slot = 4'd6;   // U
        endcase
    end
    wire [15:0] n_cell = slots[16*rx_slot +: 16];
    wire [5:0]  n_mat  = n_cell[`C_MAT];
    wire [3:0]  n_life = n_cell[`C_LIFE];
    wire [2:0]  n_shade= n_cell[`C_SHADE];
    wire [1:0]  n_tag  = n_cell[`C_TAG];

    wire       r_hit;
    wire [4:0] r_prob;
    wire [5:0] r_oc, r_on, r_id;
    wire [1:0] r_fx;
    wire       r_oc_life_en, r_on_life_en;
    wire [3:0] r_oc_life, r_on_life;
    rxn_table table_rule (
        .c_mat(c_mat), .c_tag(c_tag), .c_life(c_life),
        .n_mat(n_mat), .n_tag(n_tag), .n_life(n_life),
        .hit(r_hit), .prob(r_prob), .out_c(r_oc), .out_n(r_on), .rxn_id(r_id), .fx(r_fx),
        .oc_life_en(r_oc_life_en), .oc_life(r_oc_life),
        .on_life_en(r_on_life_en), .on_life(r_on_life)
    );
    wire r_fire = r_hit && ({1'b0, rnd[3:0]} < r_prob);

    // starting LIFE for reaction products
    wire [3:0] oc_init, on_init;
    mat_properties p_oc (.mat(r_oc), .cls(), .dens(), .flow(), .init_life(oc_init), .decay(), .flammable(), .glows());
    mat_properties p_on (.mat(r_on), .cls(), .dens(), .flow(), .init_life(on_init), .decay(), .flammable(), .glows());

    // (c) movement
    wire [3:0] mv_slot;
    phys_move_rules mover (
        .c_mat(c_mat), .nb_mat(nb_mats), .flush(flush), .rnd(rnd[13:6]), .tgt(mv_slot)
    );
    wire [15:0] t_cell = slots[16*mv_slot +: 16];

    // starting LIFE for an injected grain
    wire [5:0] inj_mat = inj_src ? src1_mat : src0_mat;
    wire [3:0] inj_life;
    mat_properties p_inj (.mat(inj_mat), .cls(), .dens(), .flow(), .init_life(inj_life), .decay(), .flammable(), .glows());
    wire [1:0] inj_tag = (CHAMBER == 1) ? `TAG_NEW : `TAG_OLD;

    // RAM port driving
    always @* begin
        ram_we    = 1'b0;
        ram_wdata = 16'd0;
        case (state)
            S_CLEAR:   begin ram_addr = clr_addr; ram_we = 1'b1; end
            S_INJ_RD:  ram_addr = {inj_new_y, inj_new_x};
            S_INJ_WR:  begin
                ram_addr  = {inj_y, inj_x};
                ram_we    = !inj_blocked && (ram_rdata[`C_MAT] == `M_EMPTY);
                ram_wdata = {inj_tag, ~cur_par, rnd[12:10], inj_life, inj_mat};
            end
            S_C_ISSUE: ram_addr = {sy, sx};
            S_NB:      ram_addr = {probe_y[6:0], probe_x[5:0]};
            S_WA:      begin ram_addr = wa_addr; ram_we = wa_en; ram_wdata = wa_data; end
            S_WB:      begin ram_addr = wb_addr; ram_we = wb_en; ram_wdata = wb_data; end
            default:   ram_addr = {sy, sx};
        endcase
    end

    // Data arriving this cycle (either from RAM or a known wall/sink)
    wire [15:0] arriving = pend_ovr ? {10'd0, pend_ovr_mat} : ram_rdata;

    // Helper: a cell word with a new material, keeping the old shade
    function [15:0] make_cell;
        input [1:0] tag;
        input       par;
        input [2:0] shade;
        input [3:0] life;
        input [5:0] mat;
        make_cell = (mat == `M_EMPTY) ? 16'd0 : {tag, par, shade, life, mat};
    endfunction

    // Sequential logic
    always @(posedge clk) begin
        // one cycle pulses default to 0
        src0_pop    <= 1'b0;  src1_pop  <= 1'b0;
        exit_valid  <= 1'b0;  rxn_valid <= 1'b0;
        visit_valid <= 1'b0;  step_done <= 1'b0;

        // remember requests that arrive while we are busy
        if (step_req)  step_pending  <= 1'b1;
        if (clear_req) clear_pending <= 1'b1;
        if (age_req)   age_pending   <= 1'b1;

        if (rst) begin
            state <= S_IDLE;
            cur_par <= 1'b0; dir <= 1'b0; age_mode <= 1'b0;
            step_pending <= 1'b0; clear_pending <= 1'b1; age_pending <= 1'b0;
            cell_count <= 13'd0; cnt <= 13'd0; clr_addr <= 13'd0;
            sx <= 6'd0; sy <= 7'd95; nb_idx <= 4'd0; pend_slot <= 4'd0;
            wa_en <= 1'b0; wb_en <= 1'b0;
        end else begin
            case (state)

                S_IDLE: begin
                    if (clear_pending || clear_req) begin
                        clr_addr <= 13'd0;
                        state    <= S_CLEAR;
                    end else if (step_pending) begin
                        step_pending <= 1'b0;
                        cur_par  <= ~cur_par;
                        dir      <= ~dir;
                        cnt      <= 13'd0;
                        age_mode <= age_pending;
                        age_pending <= 1'b0;
                        inj_src  <= 1'b0;
                        inj_try  <= 3'd0;
                        // ageing steps skip injection so new grains are not aged.
                        // sy = 96 is a marker: S_NEXT turns it into "start the sweep".
                        state    <= age_pending ? S_NEXT : S_INJ_RD;
                        sy       <= 7'd96;
                    end
                end

                S_CLEAR: begin
                    if (clr_addr == 13'd6143) begin
                        clear_pending <= 1'b0;
                        cell_count    <= 13'd0;
                        state         <= S_IDLE;
                    end else
                        clr_addr <= clr_addr + 13'd1;
                end

                // INJECTION: try to place a grain at a random spot of the spawn area
                S_INJ_RD: begin
                    if ((inj_src ? src1_valid : src0_valid)) begin
                        inj_x       <= inj_new_x;
                        inj_y       <= inj_new_y;
                        inj_blocked <= probe_ovr;
                        state       <= S_INJ_WR;
                    end else begin
                        // nothing to place from this source: move on
                        inj_try <= 3'd0;
                        if (inj_src)
                            state <= S_NEXT;          // sy is still 96: S_NEXT starts the sweep
                        else
                            inj_src <= 1'b1;
                    end
                end

                S_INJ_WR: begin
                    // ram_we is driven combinationally above; report the pop here
                    if (!inj_blocked && ram_rdata[`C_MAT] == `M_EMPTY) begin
                        if (inj_src) src1_pop <= 1'b1; else src0_pop <= 1'b1;
                    end
                    if (inj_try == INJ_TRIES - 1) begin
                        inj_try <= 3'd0;
                        if (inj_src) begin
                            state <= S_NEXT;          // sy is still 96: S_NEXT starts the sweep
                        end else begin
                            inj_src <= 1'b1;
                            state   <= S_INJ_RD;
                        end
                    end else begin
                        inj_try <= inj_try + 3'd1;
                        state   <= S_INJ_RD;
                    end
                end

                // SWEEP: request the centre cell
                S_C_ISSUE: begin
                    if (probe_ovr) begin
                        state <= S_NEXT;                 // walls are never processed
                    end else begin
                        pend_slot    <= 4'd0;
                        pend_ovr     <= 1'b0;
                        pend_ovr_mat <= `M_WALL;
                        nb_idx       <= 4'd1;
                        state        <= S_NB;
                    end
                end

                // Capture one slot per cycle while requesting the next one
                S_NB: begin
                    slots[16*pend_slot +: 16] <= arriving;

                    if (pend_slot == 4'd0) begin
                        // the centre cell has arrived: is it worth processing?
                        if (arriving[`C_MAT] == `M_EMPTY) begin
                            state <= S_NEXT;
                        end else begin
                            cnt         <= cnt + 13'd1;
                            visit_valid <= 1'b1;
                            visit_mat   <= arriving[`C_MAT];

                            if (age_mode) begin
                                // ageing sweep: just count the tag down
                                if (arriving[`C_TAG] != `TAG_OLD) begin
                                    wa_en   <= 1'b1;
                                    wa_addr <= {sy, sx};
                                    wa_data <= {arriving[`C_TAG] - 2'd1, arriving[13:0]};
                                    wb_en   <= 1'b0;
                                    state   <= S_WA;
                                end else
                                    state <= S_NEXT;
                            end
                            else if (arriving[`C_PAR] == cur_par)
                                state <= S_NEXT;          // already moved this step
                            else if (arriving[`C_MAT] == `M_STONE    || arriving[`C_MAT] == `M_OBSIDIAN ||
                                     arriving[`C_MAT] == `M_GLASS    || arriving[`C_MAT] == `M_SANDSTONE ||
                                     arriving[`C_MAT] == `M_INGOT    || arriving[`C_MAT] == `M_BRICK ||
                                     arriving[`C_MAT] == `M_POTTERY) begin
                                // cold solids can't move; their reactions are
                                // triggered from the other side instead
                                if (arriving[`C_LIFE] == 4'd0 && !flush) state <= S_NEXT;
                                else begin
                                    pend_slot <= nb_idx; pend_ovr <= probe_ovr; pend_ovr_mat <= probe_ovr_mat;
                                    nb_idx    <= nb_idx + 4'd1;
                                end
                            end else begin
                                pend_slot    <= nb_idx;
                                pend_ovr     <= probe_ovr;
                                pend_ovr_mat <= probe_ovr_mat;
                                nb_idx       <= nb_idx + 4'd1;
                            end
                        end
                    end else if (pend_slot == 4'd10) begin
                        state <= S_DECIDE;                // all ten neighbours are in
                    end else begin
                        pend_slot    <= nb_idx;
                        pend_ovr     <= probe_ovr;
                        pend_ovr_mat <= probe_ovr_mat;
                        nb_idx       <= nb_idx + 4'd1;
                    end
                end

                // DECIDE: self change > reaction > movement > life tick
                S_DECIDE: begin
                    wa_en <= 1'b0;
                    wb_en <= 1'b0;
                    wa_addr <= {sy, sx};

                    if (s_trans) begin
                        // (a) burnt out / condensed / cooled into something else
                        wa_en   <= 1'b1;
                        wa_data <= make_cell(c_tag, cur_par, c_shade, s_life, s_mat);
                    end
                    else if (r_fire) begin
                        // (b) reaction: both cells change. Products take the OLDER tag.
                        wa_en   <= 1'b1;
                        wa_data <= make_cell((c_tag < n_tag) ? c_tag : n_tag, cur_par, c_shade,
                                             r_oc_life_en ? r_oc_life : (r_oc == c_mat ? s_life : oc_init),
                                             r_oc);
                        wb_en   <= 1'b1;
                        wb_addr <= slot_addr(rx_slot, sx, sy);
                        wb_data <= make_cell((c_tag < n_tag) ? c_tag : n_tag, cur_par, n_shade,
                                             r_on_life_en ? r_on_life : (r_on == n_mat ? n_life : on_init),
                                             r_on);
                        rxn_valid <= 1'b1;
                        rxn_id    <= r_id;
                        rxn_fx    <= r_fx;
                    end
                    else if (mv_slot != 4'd0) begin
                        // (c) movement: swap with the target
                        if (t_cell[`C_MAT] == `M_SINK) begin
                            // fell out of the bottom of the screen
                            wa_en   <= 1'b1;
                            wa_data <= 16'd0;
                            if (sink_mode == `SINK_FIFO) begin
                                exit_valid <= 1'b1;
                                exit_mat   <= c_mat;
                            end
                        end else begin
                            wa_en   <= 1'b1;
                            wa_data <= (t_cell[`C_MAT] == `M_EMPTY) ? 16'd0 : {t_cell[15:14], cur_par, t_cell[12:0]};
                            wb_en   <= 1'b1;
                            wb_addr <= slot_addr(mv_slot, sx, sy);
                            wb_data <= {c_tag, cur_par, c_shade, s_life, c_mat};
                        end
                    end
                    else if (s_life != c_life) begin
                        // (d) just ticking its LIFE timer down
                        wa_en   <= 1'b1;
                        wa_data <= {c_tag, cur_par, c_shade, s_life, c_mat};
                    end
                    state <= S_WA;
                end

                S_WA: state <= wb_en ? S_WB : S_NEXT;
                S_WB: state <= S_NEXT;

                // Move to the next cell (bottom row first, alternating direction)
                S_NEXT: begin
                    wa_en <= 1'b0;
                    wb_en <= 1'b0;
                    if (sy == 7'd96) begin
                        // just finished injecting: start the sweep at the bottom row
                        sy    <= 7'd95;
                        sx    <= dir ? 6'd63 : 6'd0;
                        state <= S_C_ISSUE;
                    end else if ((!dir && sx == 6'd63) || (dir && sx == 6'd0)) begin
                        if (sy == 7'd0) begin
                            state <= S_DONE;
                        end else begin
                            sy    <= sy - 7'd1;
                            sx    <= dir ? 6'd63 : 6'd0;
                            state <= S_C_ISSUE;
                        end
                    end else begin
                        sx    <= dir ? sx - 6'd1 : sx + 6'd1;
                        state <= S_C_ISSUE;
                    end
                end

                S_DONE: begin
                    cell_count <= cnt;
                    step_done  <= 1'b1;
                    age_mode   <= 1'b0;
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
