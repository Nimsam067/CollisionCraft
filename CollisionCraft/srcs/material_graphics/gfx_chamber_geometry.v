// Shape of the glassware on each screen (funnels, walls, floors and valves).
// The physics engine asks this module whether a pixel
// is a wall, so sand slides down the funnel and water pools against the glass.

// Part codes for the renderer: 0 none, 1 glass wall, 2 funnel, 3 floor/hopper,
// 4 closed valve, 5 spout, 6 beaker drain floor, 7 rim highlight.

// Owner: Zi Le (Materials, Graphics & Controls)

module gfx_chamber_geometry #(
    parameter CHAMBER = 0 // 0 = reagent chamber, 1 = reaction beaker
)(
    input wire [6:0] x,
    input wire [6:0] y,
    input wire valve_open, // reagent release
    input wire trapdoor_open, // reagent discard
    input wire drain_open, // beaker drain
    output reg is_wall,
    output reg [2:0] part,
    output reg interior // inside the glass
);

    // Mirror x for the right hand side so we only describe the left side once
    wire [6:0] xm = 7'd63 - x;

    // Reagent chamber
    // Funnel
    wire [7:0] r_fun_edge = 8'd9 + ({1'b0, y} - 8'd25) * 8'd2;
    wire r_fun_rows = (y >= 7'd25) && (y <= 7'd34);
    wire r_funnel = r_fun_rows &&
                      ((({1'b0, x} + 8'd2 >= r_fun_edge) && ({1'b0, x} <= r_fun_edge)) ||
                       (({1'b0, xm} + 8'd2 >= r_fun_edge) && ({1'b0, xm} <= r_fun_edge)));

    wire r_neck = (y >= 7'd35) && (y <= 7'd38) &&
                  (((x >= 7'd25) && (x <= 7'd27)) || ((xm >= 7'd25) && (xm <= 7'd27)));

    // Straight sides of the body
    wire r_side = (y >= 7'd40) && (y <= 7'd63) &&
                  (((x >= 7'd3) && (x <= 7'd5)) || ((xm >= 7'd3) && (xm <= 7'd5)));

    // Hopper
    wire [6:0] r_hop_edge = (y >= 7'd85) ? 7'd27 : (7'd6 + (y - 7'd64));
    wire r_hop_rows = (y >= 7'd64) && (y <= 7'd87);
    wire r_hopper = r_hop_rows &&
                      (((x + 7'd2 >= r_hop_edge) && (x <= r_hop_edge)) ||
                       ((xm + 7'd2 >= r_hop_edge) && (xm <= r_hop_edge)));

    wire r_valve = ((y == 7'd86) || (y == 7'd87)) && (x >= 7'd28) && (x <= 7'd35);
    wire r_spout = (y >= 7'd88) &&
                   (((x >= 7'd26) && (x <= 7'd27)) || ((xm >= 7'd26) && (xm <= 7'd27)));

    wire r_interior = ((y >= 7'd40) && (y <= 7'd63) && (x >= 7'd6) && (x <= 7'd57)) ||
                      (r_hop_rows && (x > r_hop_edge) && (xm > r_hop_edge));

    // Reaction beaker, two funnels
    wire [6:0] b_dy = y - 7'd10;
    wire b_fun_rows = (y >= 7'd10) && (y <= 7'd19);
    wire [6:0] b_outer = 7'd3 + b_dy;
    wire [6:0] b_inner = 7'd28 - b_dy;
    wire b_funnel_l = b_fun_rows &&
                      (((x + 7'd1 >= b_outer) && (x <= b_outer)) ||
                       ((x >= b_inner) && (x <= b_inner + 7'd1)));
    wire b_funnel_r = b_fun_rows &&
                      (((xm + 7'd1 >= b_outer) && (xm <= b_outer)) ||
                       ((xm >= b_inner) && (xm <= b_inner + 7'd1)));

    wire b_neck = (y >= 7'd20) && (y <= 7'd23) &&
                  (((x >= 7'd11) && (x <= 7'd12)) || ((x >= 7'd19) && (x <= 7'd20)) ||
                   ((xm >= 7'd11) && (xm <= 7'd12)) || ((xm >= 7'd19) && (xm <= 7'd20)));

    wire b_side = (y >= 7'd25) && (y <= 7'd93) &&
                   (((x >= 7'd2) && (x <= 7'd3)) || ((xm >= 7'd2) && (xm <= 7'd3)));
    wire b_rim = (y == 7'd25) &&
                   (((x >= 7'd1) && (x <= 7'd4)) || ((xm >= 7'd1) && (xm <= 7'd4)));
    wire b_floor = ((y == 7'd92) || (y == 7'd93)) && (x >= 7'd4) && (x <= 7'd59);
    wire b_spout = (y >= 7'd94) &&
                   (((x >= 7'd26) && (x <= 7'd27)) || ((xm >= 7'd26) && (xm <= 7'd27)));

    wire b_interior = (x >= 7'd4) && (x <= 7'd59) && (y >= 7'd26) && (y <= 7'd91);

    // Final
    always @* begin
        is_wall = 1'b0;
        part = 3'd0;
        interior = 1'b0;
        if (CHAMBER == 0) begin
            interior = r_interior;
            if (r_funnel || r_neck) begin is_wall = 1'b1; part = 3'd2; end
            else if (r_side) begin is_wall = 1'b1; part = 3'd1; end
            else if (r_spout) begin is_wall = 1'b1; part = 3'd5; end
            else if (r_hopper && !trapdoor_open) begin is_wall = 1'b1; part = 3'd3; end
            else if (r_valve && !valve_open && !trapdoor_open)
                                                         begin is_wall = 1'b1; part = 3'd4; end
        end else begin
            interior = b_interior;
            if (b_funnel_l || b_funnel_r || b_neck) begin is_wall = 1'b1; part = 3'd2; end
            else if (b_rim) begin is_wall = 1'b1; part = 3'd7; end
            else if (b_side) begin is_wall = 1'b1; part = 3'd1; end
            else if (b_floor && !drain_open) begin is_wall = 1'b1; part = 3'd6; end
            else if (b_spout) begin is_wall = 1'b1; part = 3'd5; end
        end
    end

endmodule
