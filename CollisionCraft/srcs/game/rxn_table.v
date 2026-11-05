// The reaction rules. The physics engine gives us two touching grains, C and N,
// and this works out whether they react and what they turn into.
//
// Order matters: each grain in the beaker has a tag saying which release it came
// in with, so we can tell if A was there first, B was there first, or they came
// in together. For example water then lava gives obsidian, lava then water gives
// pumice, and both together give stone.
//
// A rule is written as rule(new_a, new_b, chance, reaction_id, effect), where
// chance is out of 16 per step. Always put the lower material ID first.
//
// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module rxn_table (
    input wire [5:0] c_mat,
    input wire [1:0] c_tag,
    input wire [3:0] c_life,
    input wire [5:0] n_mat,
    input wire [1:0] n_tag,
    input wire [3:0] n_life,
    output wire hit, // a rule exists for this pair
    output reg [4:0] prob, // chance per step, out of 16 (16 = always)
    output wire [5:0] out_c, // what C becomes
    output wire [5:0] out_n, // what N becomes
    output reg [5:0] rxn_id, // which reaction (RX_*), 0 = silent
    output reg [1:0] fx, // special effect (FX_*)
    output wire oc_life_en, // override LIFE of C's product
    output wire [3:0] oc_life,
    output wire on_life_en, // override LIFE of N's product
    output wire [3:0] on_life
);

    // Sort the pair so that a has the smaller material ID
    wire c_is_a = (c_mat <= n_mat);
    wire [5:0] a = c_is_a ? c_mat : n_mat;
    wire [5:0] b = c_is_a ? n_mat : c_mat;
    wire [1:0] ta = c_is_a ? c_tag : n_tag;
    wire [1:0] tb = c_is_a ? n_tag : c_tag;
    wire [3:0] la = c_is_a ? c_life : n_life;
    wire [3:0] lb = c_is_a ? n_life : c_life;

    // Context
    localparam [1:0] TOGETHER = 2'd0, A_FIRST = 2'd1, B_FIRST = 2'd2;
    wire [1:0] ctx = (ta == tb) ? TOGETHER : (ta < tb) ? A_FIRST : B_FIRST;

    // Does b glow when hot (for the generic "hot + water = steam" rule)?
    wire b_glows;
    mat_properties pb (.mat(b), .cls(), .dens(), .flow(), .init_life(), .decay(),
                       .flammable(), .glows(b_glows));

    // Results in sorted order
    reg found;
    reg [5:0] ra, rb; // what a and b become
    reg la_en, lb_en; // LIFE overrides
    reg [3:0] la_new, lb_new;

    // The rule "function": fills in all the outputs at once
    task rule;
        input [5:0] new_a;
        input [5:0] new_b;
        input [4:0] p;
        input [5:0] id;
        input [1:0] effect;
        begin
            found = 1'b1;
            ra = new_a;
            rb = new_b;
            prob = p;
            rxn_id = id;
            fx = effect;
        end
    endtask

    always @* begin
        found = 1'b0; ra = a; rb = b; prob = 5'd0; rxn_id = `RX_NONE; fx = `FX_NONE;
        la_en = 1'b0; lb_en = 1'b0; la_new = 4'd0; lb_new = 4'd0;

        // WATER (1) + ...
        if (a == `M_WATER && b == `M_SAND) begin
            case (ctx)
                A_FIRST: rule(`M_WATER, `M_WETSAND, 5'd3, `RX_RIVERBED, `FX_NONE); // sand settles under clear water
                B_FIRST: rule(`M_MUD, `M_MUD, 5'd2, `RX_MUD, `FX_NONE); // water soaks into the sand
                default: rule(`M_CLAY, `M_CLAY, 5'd2, `RX_CLAY, `FX_NONE); // swirled together
            endcase
        end
        else if (a == `M_WATER && b == `M_LAVA) begin
            case (ctx)
                A_FIRST: rule(`M_WATER, `M_OBSIDIAN,5'd6, `RX_OBSIDIAN, `FX_NONE); // lava sinks, quenched slowly
                B_FIRST: rule(`M_STEAM, `M_PUMICE, 5'd8, `RX_PUMICE, `FX_FLASH); // water hits lava: eruption
                default: rule(`M_STEAM, `M_STONE, 5'd6, `RX_STONE, `FX_NONE);
            endcase
        end
        else if (a == `M_WATER && b == `M_METAL) begin
            case (ctx)
                TOGETHER: rule(`M_WATER, `M_RUST, 5'd4, `RX_RUST, `FX_NONE); // splashing: fast rust
                default: rule(`M_WATER, `M_RUST, 5'd1, `RX_RUST, `FX_NONE); // slow rust
            endcase
        end
        else if (a == `M_WATER && b == `M_ACID) begin
            case (ctx)
                A_FIRST: rule(`M_DILUTE, `M_DILUTE, 5'd6, `RX_DILUTED, `FX_NONE); // the safe way
                B_FIRST: rule(`M_SPATTER, `M_SPATTER, 5'd8, `RX_SPLASH, `FX_FLASH); // never add water to acid!
                default: rule(`M_DILUTE, `M_STEAM, 5'd5, `RX_WARMMIX, `FX_NONE);
            endcase
        end
        else if (a == `M_WATER && b == `M_OIL) begin
            if (ctx == TOGETHER)
                rule(`M_EMULSION, `M_EMULSION, 5'd2, `RX_EMULSION, `FX_NONE);
            // otherwise: no reaction, they simply layer (oil floats)
        end
        else if (a == `M_WATER && b == `M_MOLTEN) begin
            rule(`M_STEAM, `M_INGOT, 5'd6, `RX_QUENCH, `FX_NONE);
        end
        else if (a == `M_WATER && b == `M_FIRE) begin
            rule(`M_STEAM, `M_SMOKE, 5'd10, `RX_HISS, `FX_NONE);
        end
        else if (a == `M_WATER && b == `M_BLAST) begin
            rule(`M_STEAM, `M_BLAST, 5'd8, `RX_NONE, `FX_NONE);
        end

        // SAND (2) + ...
        else if (a == `M_SAND && b == `M_LAVA) begin
            case (ctx)
                A_FIRST: rule(`M_GLASS, `M_LAVA, 5'd3, `RX_GLASS, `FX_NONE); // lava melts the sand bed
                B_FIRST: rule(`M_SANDSTONE, `M_LAVA, 5'd3, `RX_SANDSTONE, `FX_NONE); // sand crusts the lava top
                default: rule(`M_BEADS, `M_LAVA, 5'd4, `RX_BEADS, `FX_NONE);
            endcase
        end
        else if (a == `M_SAND && b == `M_OIL) begin
            case (ctx)
                A_FIRST: rule(`M_TAR, `M_TAR, 5'd2, `RX_TAR, `FX_NONE); // oil soaks into sand
                TOGETHER: rule(`M_TAR, `M_TAR, 5'd3, `RX_TAR, `FX_NONE);
                default: ; // sand just sinks through oil
            endcase
        end

        // LAVA (3) + ...
        else if (a == `M_LAVA && b == `M_METAL) begin
            case (ctx)
                A_FIRST: rule(`M_LAVA, `M_MOLTEN, 5'd4, `RX_SINKMELT, `FX_NONE); // metal sinks in and melts
                B_FIRST: rule(`M_LAVA, `M_MOLTEN, 5'd4, `RX_MOLTEN, `FX_NONE); // lava pours over metal
                default: rule(`M_SLAG, `M_MOLTEN, 5'd4, `RX_SLAG, `FX_NONE); // impurities float up
            endcase
        end
        else if (a == `M_LAVA && b == `M_ACID) begin
            case (ctx)
                A_FIRST: rule(`M_STONE, `M_FUMES, 5'd6, `RX_CRUST, `FX_NONE);
                B_FIRST: rule(`M_LAVA, `M_FUMES, 5'd8, `RX_ACIDBOIL, `FX_NONE);
                default: rule(`M_LAVA, `M_FUMES, 5'd10, `RX_FUMECLOUD, `FX_NONE);
            endcase
        end
        else if (a == `M_LAVA && b == `M_OIL) begin
            case (ctx)
                A_FIRST: rule(`M_LAVA, `M_FIRE, 5'd5, `RX_OILFIRE, `FX_NONE); // oil burns on the surface
                B_FIRST: rule(`M_LAVA, `M_FIRE, 5'd6, `RX_FIRECLIMB, `FX_NONE); // fire climbs up through oil
                default: rule(`M_LAVA, `M_BLAST, 5'd6, `RX_FIREBALL, `FX_BOOM);
            endcase
        end
        else if (a == `M_LAVA && b == `M_MUD) begin
            rule(`M_LAVA, `M_BRICK, 5'd3, `RX_BRICK, `FX_NONE);
        end
        else if (a == `M_LAVA && b == `M_CLAY) begin
            rule(`M_LAVA, `M_POTTERY, 5'd3, `RX_POTTERY, `FX_NONE);
        end
        else if (a == `M_LAVA && (b == `M_HYDROGEN)) begin
            rule(`M_LAVA, `M_BLAST, 5'd12, `RX_KABOOM, `FX_BOOM);
        end
        else if (a == `M_LAVA && b == `M_TAR) begin
            rule(`M_LAVA, `M_FIRE, 5'd4, `RX_BLAZE, `FX_NONE);
        end

        // METAL (4) + ...
        else if (a == `M_METAL && b == `M_ACID) begin
            case (ctx)
                A_FIRST: rule(`M_HYDROGEN, `M_SOLUTION, 5'd2, `RX_FIZZ, `FX_NONE);
                B_FIRST: rule(`M_HYDROGEN, `M_SOLUTION, 5'd3, `RX_DEEPFIZZ, `FX_NONE);
                default: rule(`M_HYDROGEN, `M_SOLUTION, 5'd6, `RX_H2CLOUD, `FX_NONE);
            endcase
        end
        else if (a == `M_METAL && b == `M_OIL) begin
            rule(`M_COATED, `M_OIL, 5'd3, `RX_COATED, `FX_NONE);
        end

        // ACID (5) + ...   (chain reactions with products)
        else if (a == `M_ACID && b == `M_STONE) begin
            rule(`M_DILUTE, `M_FUMES, 5'd1, `RX_ETCHED, `FX_NONE);
        end
        else if (a == `M_ACID && b == `M_RUST) begin
            rule(`M_DILUTE, `M_SOLUTION, 5'd3, `RX_RUSTGONE, `FX_NONE);
        end

        // OIL (6), FIRE (21), HYDROGEN (23), BLAST (30)
        else if (a == `M_OIL && b == `M_FIRE) begin
            rule(`M_FIRE, `M_FIRE, 5'd5, `RX_BLAZE, `FX_NONE);
        end
        else if (a == `M_OIL && b == `M_BLAST) begin
            rule(`M_FIRE, `M_BLAST, 5'd16, `RX_NONE, `FX_NONE);
        end
        else if (a == `M_MOLTEN && b == `M_HYDROGEN) begin
            rule(`M_MOLTEN, `M_BLAST, 5'd12, `RX_KABOOM, `FX_BOOM);
        end
        else if (a == `M_FIRE && b == `M_HYDROGEN) begin
            rule(`M_FIRE, `M_BLAST, 5'd12, `RX_KABOOM, `FX_BOOM);
        end
        else if (a == `M_FIRE && b == `M_TAR) begin
            rule(`M_FIRE, `M_FIRE, 5'd4, `RX_BLAZE, `FX_NONE);
        end
        else if (a == `M_HYDROGEN && b == `M_BLAST) begin
            rule(`M_BLAST, `M_BLAST, 5'd16, `RX_NONE, `FX_NONE);
        end
        else if (a == `M_TAR && b == `M_BLAST) begin
            rule(`M_FIRE, `M_BLAST, 5'd16, `RX_NONE, `FX_NONE);
        end
        // Explosion front expands into empty space, getting weaker each ring
        else if (a == `M_EMPTY && b == `M_BLAST) begin
            if (lb > 4'd3) begin
                rule(`M_BLAST, `M_BLAST, 5'd16, `RX_NONE, `FX_NONE);
                la_en = 1'b1; la_new = lb - 4'd3;
            end
        end

        // GENERIC: anything glowing hot + water = sizzle into steam
        // (only if no specific rule above matched)
        if (!found && a == `M_WATER && b_glows && lb != 4'd0) begin
            rule(`M_STEAM, b, 5'd3, `RX_SIZZLE, `FX_NONE);
            lb_en = 1'b1;
            lb_new = (lb > 4'd3) ? lb - 4'd3 : 4'd0; // and it cools down faster
        end
    end

    // Map the sorted results back onto C and N
    assign hit = found;
    assign out_c = c_is_a ? ra : rb;
    assign out_n = c_is_a ? rb : ra;
    assign oc_life_en = c_is_a ? la_en : lb_en;
    assign oc_life = c_is_a ? la_new : lb_new;
    assign on_life_en = c_is_a ? lb_en : la_en;
    assign on_life = c_is_a ? lb_new : la_new;

endmodule
