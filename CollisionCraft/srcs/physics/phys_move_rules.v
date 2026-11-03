// =============================================================================
//  phys_move_rules.v  --  "Where does this grain want to go?"
// -----------------------------------------------------------------------------
//  OWNER: PERSON 2  (Physics Engine)
//
//  The heart of the falling-sand physics. Given one grain (the centre C) and
//  its ten neighbours, pick ONE neighbour to swap places with, or stay put.
//  Pure combinational logic: no memory, no clock.
//
//  Neighbour slots (the engine reads them in this order):
//
//              UL(7)  U(6)  UR(8)
//      L2(9)   L(4)   [C]   R(5)   R2(10)
//              DL(2)  D(1)  DR(3)
//
//  RULES BY CLASS
//  --------------
//  POWDER (sand, metal...)
//    1. fall straight down if the space below is air, gas, or a LIGHTER
//       liquid (sand sinks through water, a bit slower: "drag")
//    2. if it is lighter than the liquid above, float up (pumice, slag)
//    3. otherwise slide diagonally down-left or down-right. This is what
//       makes a pile with sloped sides. "flow" controls how readily it
//       slides, so sticky mud keeps steep piles and dry sand flattens out.
//
//  LIQUID (water, oil, lava...)
//    1. fall down (through air, gas, or lighter liquid)
//    2. lighter liquids rise through heavier ones (oil floats on water)
//    3. slide diagonally down, else spread sideways up to 2 cells,
//       so the surface levels out. Viscous liquids (lava) try less often.
//
//  GAS (steam, smoke, fumes, hydrogen)
//    mostly rise (bubbling up through liquids and powders), sometimes
//    drift sideways, so plumes look wispy instead of shooting up in lines.
//
//  FIRE
//    jitters upward at random: up, up-left, up-right, sideways.
//
//  ANTI-TUNNELLING: a diagonal move is only allowed if the side cell is not
//  solid, otherwise grains could squeeze through the corners of a sloped wall.
//
//  "flush" (draining or discarding) makes solids act like powder and lets
//  everything fall out.
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module phys_move_rules (
    input  wire [5:0]  c_mat,          // the grain we are moving
    input  wire [59:0] nb_mat,         // neighbour k (1..10) at [6*(k-1) +: 6]
    input  wire        flush,
    input  wire [7:0]  rnd,
    output reg  [3:0]  tgt             // 0 = stay, else the slot to swap with
);

    // ---- Slot numbers -------------------------------------------------------------------
    localparam [3:0] S_NONE = 4'd0, S_D = 4'd1, S_DL = 4'd2, S_DR = 4'd3, S_L = 4'd4,
                     S_R = 4'd5, S_U = 4'd6, S_UL = 4'd7, S_UR = 4'd8, S_L2 = 4'd9, S_R2 = 4'd10;

    // ---- Properties of the centre grain -----------------------------------------------------
    wire [2:0] c_cls_raw, c_dens_raw;
    wire [3:0] c_flow;
    mat_properties pc (.mat(c_mat), .cls(c_cls_raw), .dens(c_dens_raw), .flow(c_flow),
                       .init_life(), .decay(), .flammable(), .glows());

    // While flushing, solids fall like heavy powder
    wire       c_solid_flush = flush && (c_cls_raw == `CL_STATIC);
    wire [2:0] c_cls  = c_solid_flush ? `CL_POWDER : c_cls_raw;
    wire [2:0] c_dens = c_solid_flush ? 3'd7       : c_dens_raw;
    wire [3:0] flow   = c_solid_flush ? 4'd15      : c_flow;

    // ---- Properties of all ten neighbours ------------------------------------------------
    wire [29:0] n_cls;     // neighbour k class at [3*(k-1) +: 3]
    wire [29:0] n_dens;
    genvar k;
    generate
        for (k = 0; k < 10; k = k + 1) begin : nprops
            mat_properties p (.mat(nb_mat[6*k +: 6]), .cls(n_cls[3*k +: 3]), .dens(n_dens[3*k +: 3]),
                              .flow(), .init_life(), .decay(), .flammable(), .glows());
        end
    endgenerate

    // Friendly names for each neighbour's class and density
    wire [2:0] d_cls  = n_cls[2:0],   d_dens  = n_dens[2:0];
    wire [2:0] dl_cls = n_cls[5:3],   dl_dens = n_dens[5:3];
    wire [2:0] dr_cls = n_cls[8:6],   dr_dens = n_dens[8:6];
    wire [2:0] l_cls  = n_cls[11:9];
    wire [2:0] r_cls  = n_cls[14:12];
    wire [2:0] u_cls  = n_cls[17:15], u_dens  = n_dens[17:15];
    wire [2:0] ul_cls = n_cls[20:18];
    wire [2:0] ur_cls = n_cls[23:21];
    wire [2:0] l2_cls = n_cls[26:24];
    wire [2:0] r2_cls = n_cls[29:27];

    // ---- Helper questions ------------------------------------------------------------------
    // Can I fall into a cell with this class/density?
    function can_fall;
        input [2:0] cls;
        input [2:0] dens;
        input [2:0] my_dens;
        can_fall = (cls == `CL_EMPTY) || (cls == `CL_SINK) || (cls == `CL_GAS) ||
                   (cls == `CL_FIRE)  || (cls == `CL_LIQUID && dens < my_dens);
    endfunction

    // Is this cell open air (or gas / fire, which we can push aside)?
    function is_open;
        input [2:0] cls;
        is_open = (cls == `CL_EMPTY) || (cls == `CL_SINK) || (cls == `CL_GAS) || (cls == `CL_FIRE);
    endfunction

    function is_solid;
        input [2:0] cls;
        is_solid = (cls == `CL_STATIC);
    endfunction

    wire go_left_first = rnd[0];

    // ---- Decide ------------------------------------------------------------------------------
    always @* begin
        tgt = S_NONE;
        case (c_cls)

            // ======================== POWDER ========================
            `CL_POWDER: begin
                if (can_fall(d_cls, d_dens, c_dens)) begin
                    // sinking through a liquid is slower (5 times in 8)
                    if (d_cls == `CL_LIQUID) tgt = (rnd[7:5] < 3'd5) ? S_D : S_NONE;
                    else                     tgt = S_D;
                end
                else if (u_cls == `CL_LIQUID && u_dens > c_dens && rnd[6])
                    tgt = S_U;                                            // float up
                else if (rnd[4:1] < flow) begin
                    if (go_left_first) begin
                        if      (can_fall(dl_cls, dl_dens, c_dens) && !is_solid(l_cls)) tgt = S_DL;
                        else if (can_fall(dr_cls, dr_dens, c_dens) && !is_solid(r_cls)) tgt = S_DR;
                    end else begin
                        if      (can_fall(dr_cls, dr_dens, c_dens) && !is_solid(r_cls)) tgt = S_DR;
                        else if (can_fall(dl_cls, dl_dens, c_dens) && !is_solid(l_cls)) tgt = S_DL;
                    end
                end
            end

            // ======================== LIQUID ========================
            `CL_LIQUID: begin
                if (can_fall(d_cls, d_dens, c_dens)) begin
                    if (d_cls == `CL_LIQUID) tgt = rnd[7] ? S_D : S_NONE;  // gentle layering
                    else                     tgt = S_D;
                end
                else if (u_cls == `CL_LIQUID && u_dens > c_dens && rnd[6])
                    tgt = S_U;                                            // lighter liquid rises
                // sliding down a slope is gravity: every liquid does it,
                // even gloopy lava, so nothing gets stuck on the hopper walls
                else if (go_left_first && can_fall(dl_cls, dl_dens, c_dens) && is_open(l_cls))
                    tgt = S_DL;
                else if (can_fall(dr_cls, dr_dens, c_dens) && is_open(r_cls))
                    tgt = S_DR;
                else if (can_fall(dl_cls, dl_dens, c_dens) && is_open(l_cls))
                    tgt = S_DL;
                // spreading sideways is where viscosity ("flow") matters
                else if (rnd[3:0] < flow) begin
                    if (go_left_first) begin
                        if      (is_open(l_cls)) tgt = is_open(l2_cls) ? S_L2 : S_L;
                        else if (is_open(r_cls)) tgt = is_open(r2_cls) ? S_R2 : S_R;
                    end else begin
                        if      (is_open(r_cls)) tgt = is_open(r2_cls) ? S_R2 : S_R;
                        else if (is_open(l_cls)) tgt = is_open(l2_cls) ? S_L2 : S_L;
                    end
                end
            end

            // ========================= GAS ==========================
            `CL_GAS: begin
                if (rnd[2:0] < 3'd5) begin
                    if (u_cls == `CL_EMPTY)
                        tgt = S_U;
                    else if ((u_cls == `CL_LIQUID || u_cls == `CL_POWDER) && rnd[3])
                        tgt = S_U;                                        // bubble up through it
                    else if (rnd[4]) begin
                        if      (ul_cls == `CL_EMPTY && l_cls != `CL_STATIC) tgt = S_UL;
                        else if (ur_cls == `CL_EMPTY && r_cls != `CL_STATIC) tgt = S_UR;
                    end else begin
                        if      (ur_cls == `CL_EMPTY && r_cls != `CL_STATIC) tgt = S_UR;
                        else if (ul_cls == `CL_EMPTY && l_cls != `CL_STATIC) tgt = S_UL;
                    end
                end else begin
                    if (rnd[4]) tgt = (l_cls == `CL_EMPTY) ? S_L : S_NONE;  // drift
                    else        tgt = (r_cls == `CL_EMPTY) ? S_R : S_NONE;
                end
            end

            // ========================= FIRE =========================
            `CL_FIRE: begin
                case (rnd[2:0])
                    3'd0, 3'd1, 3'd2, 3'd3: tgt = (u_cls  == `CL_EMPTY) ? S_U  : S_NONE;
                    3'd4:                   tgt = (ul_cls == `CL_EMPTY) ? S_UL : S_NONE;
                    3'd5:                   tgt = (ur_cls == `CL_EMPTY) ? S_UR : S_NONE;
                    3'd6:                   tgt = (l_cls  == `CL_EMPTY) ? S_L  : S_NONE;
                    default:                tgt = (r_cls  == `CL_EMPTY) ? S_R  : S_NONE;
                endcase
            end

            // STATIC, BLAST, EMPTY: never move
            default: tgt = S_NONE;
        endcase
    end

endmodule

`default_nettype wire
