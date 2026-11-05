// Banner name and two hint lines for every reaction. The hints are used by the
// HINT button in free play. Every string is 10 characters padded with spaces,
// with at most 9 visible letters so it fits inside the banner.

// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module rxn_names (
    input wire [5:0] id,
    output reg [79:0] name,
    output reg [79:0] hint0,
    output reg [79:0] hint1
);

    always @* begin
        case (id)
            `RX_OBSIDIAN: begin name = "OBSIDIAN! "; hint0 = "WATER 1ST "; hint1 = "LAVA 2ND  "; end
            `RX_PUMICE: begin name = "PUMICE!   "; hint0 = "LAVA 1ST  "; hint1 = "WATER 2ND "; end
            `RX_STONE: begin name = "STONE     "; hint0 = "MIX WATER "; hint1 = "AND LAVA  "; end
            `RX_RIVERBED: begin name = "RIVERBED  "; hint0 = "WATER 1ST "; hint1 = "SAND 2ND  "; end
            `RX_MUD: begin name = "MUD       "; hint0 = "SAND 1ST  "; hint1 = "WATER 2ND "; end
            `RX_CLAY: begin name = "CLAY      "; hint0 = "MIX WATER "; hint1 = "AND SAND  "; end
            `RX_RUST: begin name = "RUST      "; hint0 = "METAL AND "; hint1 = "WATER     "; end
            `RX_DILUTED: begin name = "DILUTED   "; hint0 = "WATER 1ST "; hint1 = "ACID 2ND  "; end
            `RX_SPLASH: begin name = "SPLASH!   "; hint0 = "ACID 1ST  "; hint1 = "WATER 2ND "; end
            `RX_WARMMIX: begin name = "WARM MIX  "; hint0 = "MIX WATER "; hint1 = "AND ACID  "; end
            `RX_EMULSION: begin name = "EMULSION  "; hint0 = "MIX WATER "; hint1 = "AND OIL   "; end
            `RX_GLASS: begin name = "GLASS!    "; hint0 = "SAND 1ST  "; hint1 = "LAVA 2ND  "; end
            `RX_SANDSTONE: begin name = "SANDSTONE "; hint0 = "LAVA 1ST  "; hint1 = "SAND 2ND  "; end
            `RX_BEADS: begin name = "BEADS     "; hint0 = "MIX SAND  "; hint1 = "AND LAVA  "; end
            `RX_MOLTEN: begin name = "MELTDOWN  "; hint0 = "METAL 1ST "; hint1 = "LAVA 2ND  "; end
            `RX_SINKMELT: begin name = "SINK MELT "; hint0 = "LAVA 1ST  "; hint1 = "METAL 2ND "; end
            `RX_SLAG: begin name = "SLAG      "; hint0 = "MIX LAVA  "; hint1 = "AND METAL "; end
            `RX_ACIDBOIL: begin name = "ACID BOIL "; hint0 = "ACID 1ST  "; hint1 = "LAVA 2ND  "; end
            `RX_CRUST: begin name = "CRUST     "; hint0 = "LAVA 1ST  "; hint1 = "ACID 2ND  "; end
            `RX_FUMECLOUD: begin name = "FUMES!    "; hint0 = "MIX LAVA  "; hint1 = "AND ACID  "; end
            `RX_FIRECLIMB: begin name = "FIRECLIMB "; hint0 = "OIL 1ST   "; hint1 = "LAVA 2ND  "; end
            `RX_OILFIRE: begin name = "OIL FIRE  "; hint0 = "LAVA 1ST  "; hint1 = "OIL 2ND   "; end
            `RX_FIREBALL: begin name = "FIREBALL! "; hint0 = "MIX LAVA  "; hint1 = "AND OIL   "; end
            `RX_FIZZ: begin name = "FIZZ      "; hint0 = "METAL 1ST "; hint1 = "ACID 2ND  "; end
            `RX_DEEPFIZZ: begin name = "DEEP FIZZ "; hint0 = "ACID 1ST  "; hint1 = "METAL 2ND "; end
            `RX_H2CLOUD: begin name = "H2 CLOUD  "; hint0 = "MIX METAL "; hint1 = "AND ACID  "; end
            `RX_TAR: begin name = "TAR       "; hint0 = "SAND 1ST  "; hint1 = "OIL 2ND   "; end
            `RX_COATED: begin name = "COATED    "; hint0 = "METAL AND "; hint1 = "OIL       "; end
            `RX_BRICK: begin name = "BRICK!    "; hint0 = "MAKE MUD  "; hint1 = "ADD LAVA  "; end
            `RX_POTTERY: begin name = "POTTERY!  "; hint0 = "MAKE CLAY "; hint1 = "ADD LAVA  "; end
            `RX_KABOOM: begin name = "KABOOM!   "; hint0 = "MAKE H2   "; hint1 = "ADD LAVA  "; end
            `RX_QUENCH: begin name = "QUENCH    "; hint0 = "HOT METAL "; hint1 = "ADD WATER "; end
            `RX_HISS: begin name = "HISS      "; hint0 = "MAKE FIRE "; hint1 = "ADD WATER "; end
            `RX_ETCHED: begin name = "ETCHED    "; hint0 = "GET STONE "; hint1 = "ADD ACID  "; end
            `RX_RUSTGONE: begin name = "RUST GONE "; hint0 = "MAKE RUST "; hint1 = "ADD ACID  "; end
            `RX_SIZZLE: begin name = "SIZZLE    "; hint0 = "HOT ROCK  "; hint1 = "ADD WATER "; end
            `RX_BLAZE: begin name = "BLAZE     "; hint0 = "MAKE FIRE "; hint1 = "ADD OIL   "; end
            default: begin name = "          "; hint0 = "          "; hint1 = "          "; end
        endcase
    end

endmodule
