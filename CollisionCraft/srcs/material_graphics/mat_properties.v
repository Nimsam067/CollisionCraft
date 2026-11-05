// How each material behaves physically. The physics engine (Aadi) and the
// reaction rules (Arnav) both read this, so changing a value here changes how
// that material feels everywhere.
//
// cls        how it moves (static, powder, liquid, gas, fire, blast)
// dens       density 0 to 7, heavier things sink through lighter liquids
// flow       0 to 15, how easily it spreads sideways
// init_life  starting value of the LIFE timer
// decay      how fast LIFE counts down (0 never, 1 every step, 2 every 2nd
//            step, up to 7 = every 64th step)
// flammable  can be set on fire by fire or lava
// glows      drawn red hot while LIFE > 0
//
// Owner: Zi Le (Materials, Graphics & Controls)

`include "cc_defines.vh"

module mat_properties (
    input  wire [5:0] mat,
    output reg  [2:0] cls,
    output reg  [2:0] dens,
    output reg  [3:0] flow,
    output reg  [3:0] init_life,
    output reg  [2:0] decay,
    output reg        flammable,
    output reg        glows
);

    always @* begin
        // Defaults describe "empty space"
        cls       = `CL_EMPTY;
        dens      = 3'd0;
        flow      = 4'd0;
        init_life = 4'd0;
        decay     = 3'd0;
        flammable = 1'b0;
        glows     = 1'b0;

        case (mat)
            //                         class          dens   flow   life   decay
            // the six pourable materials
            `M_WATER:     begin cls=`CL_LIQUID; dens=3'd3; flow=4'd15;                          end
            `M_SAND:      begin cls=`CL_POWDER; dens=3'd5; flow=4'd14;                          end
            `M_LAVA:      begin cls=`CL_LIQUID; dens=3'd6; flow=4'd3;                           end
            `M_METAL:     begin cls=`CL_POWDER; dens=3'd7; flow=4'd10;                          end
            `M_ACID:      begin cls=`CL_LIQUID; dens=3'd4; flow=4'd13;                          end
            `M_OIL:       begin cls=`CL_LIQUID; dens=3'd2; flow=4'd8;  flammable=1'b1;          end

            // gases (rise, then fade)
            `M_STEAM:     begin cls=`CL_GAS;    init_life=4'd15; decay=3'd5;                    end
            `M_FUMES:     begin cls=`CL_GAS;    init_life=4'd15; decay=3'd5;                    end
            `M_SMOKE:     begin cls=`CL_GAS;    init_life=4'd12; decay=3'd4;                    end
            `M_HYDROGEN:  begin cls=`CL_GAS;    init_life=4'd15; decay=3'd6; flammable=1'b1;    end
            `M_SPATTER:   begin cls=`CL_GAS;    init_life=4'd6;  decay=3'd2;                    end

            // fire and explosions
            `M_FIRE:      begin cls=`CL_FIRE;   init_life=4'd12; decay=3'd2;                    end
            `M_BLAST:     begin cls=`CL_BLAST;  init_life=4'd12; decay=3'd1;                    end

            // solids (never move)
            `M_STONE:     begin cls=`CL_STATIC; dens=3'd7; init_life=4'd12; decay=3'd5; glows=1'b1; end
            `M_OBSIDIAN:  begin cls=`CL_STATIC; dens=3'd7; init_life=4'd15; decay=3'd5; glows=1'b1; end
            `M_GLASS:     begin cls=`CL_STATIC; dens=3'd7; init_life=4'd15; decay=3'd5; glows=1'b1; end
            `M_SANDSTONE: begin cls=`CL_STATIC; dens=3'd7; init_life=4'd8;  decay=3'd5; glows=1'b1; end
            `M_INGOT:     begin cls=`CL_STATIC; dens=3'd7; init_life=4'd15; decay=3'd5; glows=1'b1; end
            `M_BRICK:     begin cls=`CL_STATIC; dens=3'd7; init_life=4'd15; decay=3'd5; glows=1'b1; end
            `M_POTTERY:   begin cls=`CL_STATIC; dens=3'd7; init_life=4'd15; decay=3'd5; glows=1'b1; end

            // powders made by reactions
            `M_PUMICE:    begin cls=`CL_POWDER; dens=3'd1; flow=4'd12;                          end // floats!
            `M_MUD:       begin cls=`CL_POWDER; dens=3'd5; flow=4'd4;                           end
            `M_CLAY:      begin cls=`CL_POWDER; dens=3'd5; flow=4'd3;                           end
            `M_RUST:      begin cls=`CL_POWDER; dens=3'd6; flow=4'd8;                           end
            `M_SLAG:      begin cls=`CL_POWDER; dens=3'd2; flow=4'd6;  init_life=4'd10; decay=3'd5; glows=1'b1; end
            `M_COATED:    begin cls=`CL_POWDER; dens=3'd7; flow=4'd10;                          end
            `M_WETSAND:   begin cls=`CL_POWDER; dens=3'd5; flow=4'd5;                           end
            `M_BEADS:     begin cls=`CL_POWDER; dens=3'd5; flow=4'd14; init_life=4'd15; decay=3'd5; glows=1'b1; end

            // liquids made by reactions
            `M_DILUTE:    begin cls=`CL_LIQUID; dens=3'd3; flow=4'd15;                          end
            `M_MOLTEN:    begin cls=`CL_LIQUID; dens=3'd7; flow=4'd5;  init_life=4'd15; decay=3'd5; end
            `M_SOLUTION:  begin cls=`CL_LIQUID; dens=3'd4; flow=4'd14;                          end
            `M_TAR:       begin cls=`CL_LIQUID; dens=3'd4; flow=4'd2;  flammable=1'b1;          end
            `M_EMULSION:  begin cls=`CL_LIQUID; dens=3'd3; flow=4'd10; init_life=4'd15; decay=3'd5; end

            // geometry pseudo materials
            `M_WALL:      begin cls=`CL_STATIC; dens=3'd7;                                      end
            `M_SINK:      begin cls=`CL_SINK;                                                   end

            default:      ; // M_EMPTY and unused IDs behave as empty space
        endcase
    end

endmodule
