// =============================================================================
//  game_levels.v  --  The challenge levels
// -----------------------------------------------------------------------------
//  OWNER: PERSON 3  (Interactions & Game Logic)
//
//  Each level asks the player to MAKE a material. You win when at least
//  `goal` grains of it exist in the beaker at the same moment.
//  `par` is the number of releases a perfect player needs (3 stars).
//
//  The levels are ordered so each teaches something:
//    1-2  simple pairs
//    3-4  ORDER MATTERS: same ingredients as each other, opposite order
//    5-8  more pairs and orders
//    9-10 multi-step chains (make an intermediate, then react it)
//
//  To add a level: add a case, bump LEVEL_COUNT in game_challenge.v.
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module game_levels (
    input  wire [3:0]  level,          // 0-based
    output reg  [5:0]  target_mat,
    output reg  [12:0] goal,
    output reg  [2:0]  par,
    output reg  [79:0] hint0,
    output reg  [79:0] hint1
);

    always @* begin
        case (level)
            //                    target          goal     par     hint line 1     hint line 2
            4'd0: begin target_mat=`M_STEAM;    goal=13'd40;  par=3'd1; hint0="WATER AND "; hint1="LAVA      "; end
            4'd1: begin target_mat=`M_GLASS;    goal=13'd80;  par=3'd2; hint0="SAND 1ST  "; hint1="LAVA 2ND  "; end
            4'd2: begin target_mat=`M_OBSIDIAN; goal=13'd80;  par=3'd2; hint0="WATER 1ST "; hint1="LAVA 2ND  "; end
            4'd3: begin target_mat=`M_PUMICE;   goal=13'd50;  par=3'd2; hint0="LAVA 1ST  "; hint1="WATER 2ND "; end
            4'd4: begin target_mat=`M_FIRE;     goal=13'd25;  par=3'd1; hint0="OIL MEETS "; hint1="LAVA      "; end
            4'd5: begin target_mat=`M_HYDROGEN; goal=13'd40;  par=3'd1; hint0="METAL AND "; hint1="ACID      "; end
            4'd6: begin target_mat=`M_MUD;      goal=13'd120; par=3'd2; hint0="SAND 1ST  "; hint1="WATER 2ND "; end
            4'd7: begin target_mat=`M_TAR;      goal=13'd120; par=3'd2; hint0="SAND 1ST  "; hint1="OIL 2ND   "; end
            4'd8: begin target_mat=`M_BRICK;    goal=13'd60;  par=3'd3; hint0="MAKE MUD  "; hint1="ADD LAVA  "; end
            default: begin target_mat=`M_POTTERY; goal=13'd60; par=3'd2; hint0="MAKE CLAY "; hint1="ADD LAVA  "; end
        endcase
    end

endmodule

`default_nettype wire
