// Text and colours for every material: the full name, a 3 letter code for the
// recipe line, a one word description and the colour used on its name card. All
// strings are 10 characters padded with spaces.

// Owner: Zi Le (Materials, Graphics & Controls)

`include "cc_defines.vh"

module mat_names (
    input wire [5:0] mat,
    output reg [79:0] name,
    output reg [23:0] code3,
    output reg [79:0] desc,
    output reg [15:0] sig_color // RGB565
);

    // RGB Helper
    function [15:0] rgb;
        input [4:0] r;
        input [5:0] g;
        input [4:0] b;
        rgb = {r, g, b};
    endfunction

    always @* begin
        name = "?         ";
        code3 = "???";
        desc = "          ";
        sig_color = rgb(5'd20, 6'd40, 5'd20);

        case (mat)
            `M_WATER: begin name="WATER     "; code3="WAT"; desc="LIQUID    "; sig_color=rgb(5'd4, 6'd34, 5'd31); end
            `M_SAND: begin name="SAND      "; code3="SND"; desc="POWDER    "; sig_color=rgb(5'd28, 6'd50, 5'd14); end
            `M_LAVA: begin name="LAVA      "; code3="LAV"; desc="MOLTEN    "; sig_color=rgb(5'd31, 6'd24, 5'd0); end
            `M_METAL: begin name="METAL     "; code3="MTL"; desc="HEAVY     "; sig_color=rgb(5'd18, 6'd38, 5'd22); end
            `M_ACID: begin name="ACID      "; code3="ACD"; desc="CORROSIVE "; sig_color=rgb(5'd8, 6'd62, 5'd6); end
            `M_OIL: begin name="OIL       "; code3="OIL"; desc="FLAMMABLE "; sig_color=rgb(5'd26, 6'd30, 5'd2); end

            `M_STEAM: begin name="STEAM     "; code3="STM"; sig_color=rgb(5'd26, 6'd56, 5'd30); end
            `M_STONE: begin name="STONE     "; code3="STN"; sig_color=rgb(5'd16, 6'd32, 5'd16); end
            `M_OBSIDIAN: begin name="OBSIDIAN  "; code3="OBS"; sig_color=rgb(5'd14, 6'd10, 5'd24); end
            `M_PUMICE: begin name="PUMICE    "; code3="PUM"; sig_color=rgb(5'd24, 6'd46, 5'd20); end
            `M_MUD: begin name="MUD       "; code3="MUD"; sig_color=rgb(5'd18, 6'd24, 5'd6); end
            `M_CLAY: begin name="CLAY      "; code3="CLY"; sig_color=rgb(5'd26, 6'd32, 5'd14); end
            `M_RUST: begin name="RUST      "; code3="RST"; sig_color=rgb(5'd28, 6'd22, 5'd4); end
            `M_DILUTE: begin name="DILUTE    "; code3="DIL"; sig_color=rgb(5'd18, 6'd60, 5'd20); end
            `M_GLASS: begin name="GLASS     "; code3="GLS"; sig_color=rgb(5'd16, 6'd58, 5'd30); end
            `M_SANDSTONE: begin name="SANDSTONE "; code3="SST"; sig_color=rgb(5'd28, 6'd40, 5'd12); end
            `M_MOLTEN: begin name="MOLTEN    "; code3="MLT"; sig_color=rgb(5'd31, 6'd48, 5'd8); end
            `M_INGOT: begin name="INGOT     "; code3="ING"; sig_color=rgb(5'd26, 6'd52, 5'd28); end
            `M_SLAG: begin name="SLAG      "; code3="SLG"; sig_color=rgb(5'd14, 6'd14, 5'd8); end
            `M_FUMES: begin name="FUMES     "; code3="FUM"; sig_color=rgb(5'd20, 6'd60, 5'd4); end
            `M_FIRE: begin name="FIRE      "; code3="FIR"; sig_color=rgb(5'd31, 6'd36, 5'd0); end
            `M_SMOKE: begin name="SMOKE     "; code3="SMK"; sig_color=rgb(5'd12, 6'd24, 5'd12); end
            `M_HYDROGEN: begin name="HYDROGEN  "; code3="HYD"; sig_color=rgb(5'd16, 6'd44, 5'd31); end
            `M_SOLUTION: begin name="SOLUTION  "; code3="SOL"; sig_color=rgb(5'd6, 6'd48, 5'd18); end
            `M_TAR: begin name="TAR       "; code3="TAR"; sig_color=rgb(5'd10, 6'd12, 5'd4); end
            `M_EMULSION: begin name="EMULSION  "; code3="EML"; sig_color=rgb(5'd26, 6'd54, 5'd26); end
            `M_BRICK: begin name="BRICK     "; code3="BRK"; sig_color=rgb(5'd26, 6'd18, 5'd6); end
            `M_POTTERY: begin name="POTTERY   "; code3="POT"; sig_color=rgb(5'd30, 6'd34, 5'd12); end
            `M_COATED: begin name="COATED    "; code3="COT"; sig_color=rgb(5'd24, 6'd40, 5'd12); end
            `M_BLAST: begin name="BLAST     "; code3="BLS"; sig_color=rgb(5'd31, 6'd60, 5'd20); end
            `M_SPATTER: begin name="SPATTER   "; code3="SPT"; sig_color=rgb(5'd14, 6'd63, 5'd10); end
            `M_WETSAND: begin name="WET SAND  "; code3="WSD"; sig_color=rgb(5'd20, 6'd34, 5'd10); end
            `M_BEADS: begin name="BEADS     "; code3="BDS"; sig_color=rgb(5'd20, 6'd58, 5'd30); end
            default: ;
        endcase
    end

endmodule
