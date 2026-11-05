// Data for the 10 challenge levels - which material to make, how many grains of
// it are needed (goal), the par number of releases for 3 stars, and two lines of
// hint text. To add a level, add a case here and bump LEVEL_COUNT in
// game_challenge.v.

// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module game_levels (
    input wire [3:0] level, // zero based
    output reg [5:0] target_mat,
    output reg [12:0] goal,
    output reg [2:0] par,
    output reg [79:0] hint0,
    output reg [79:0] hint1
);

    always @* begin
        case (level)
            4'd0: begin target_mat=`M_STEAM; goal=13'd40; par=3'd1; hint0="WATER AND "; hint1="LAVA      "; end
            4'd1: begin target_mat=`M_GLASS; goal=13'd80; par=3'd2; hint0="SAND 1ST  "; hint1="LAVA 2ND  "; end
            4'd2: begin target_mat=`M_OBSIDIAN; goal=13'd80; par=3'd2; hint0="WATER 1ST "; hint1="LAVA 2ND  "; end
            4'd3: begin target_mat=`M_PUMICE; goal=13'd50; par=3'd2; hint0="LAVA 1ST  "; hint1="WATER 2ND "; end
            4'd4: begin target_mat=`M_FIRE; goal=13'd25; par=3'd1; hint0="OIL MEETS "; hint1="LAVA      "; end
            4'd5: begin target_mat=`M_HYDROGEN; goal=13'd40; par=3'd1; hint0="METAL AND "; hint1="ACID      "; end
            4'd6: begin target_mat=`M_MUD; goal=13'd120; par=3'd2; hint0="SAND 1ST  "; hint1="WATER 2ND "; end
            4'd7: begin target_mat=`M_TAR; goal=13'd120; par=3'd2; hint0="SAND 1ST  "; hint1="OIL 2ND   "; end
            4'd8: begin target_mat=`M_BRICK; goal=13'd60; par=3'd3; hint0="MAKE MUD  "; hint1="ADD LAVA  "; end
            default: begin target_mat=`M_POTTERY; goal=13'd60; par=3'd2; hint0="MAKE CLAY "; hint1="ADD LAVA  "; end
        endcase
    end

endmodule
