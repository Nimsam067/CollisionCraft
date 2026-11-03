// =============================================================================
//  gfx_material_shader.v  --  How every material LOOKS
// -----------------------------------------------------------------------------
//  OWNER: PERSON 1  (Materials, Graphics & Controls)
//
//  Called once per pixel. Input: the cell under the pixel (plus the cell
//  directly above it, so we can light up liquid surfaces) and an animation
//  frame counter. Output: an RGB565 colour and how opaque it is.
//
//  The tricks that make it look alive instead of flat:
//   * SHADE  - every grain was born with a random shade 0..7, so piles are
//              speckled like real sand.
//   * NOISE  - cheap hash functions of (x, y, frame) give moving patterns:
//              lava hot-spots that crawl, water caustics that ripple,
//              bubbles rising through acid, glints on metal.
//   * SURFACE- if the cell above is air, the pixel is a surface pixel and
//              gets a bright highlight (water) or a rainbow sheen (oil).
//   * GLOW   - hot solids (fresh obsidian, glass, ingots...) blend toward
//              orange by their LIFE value, so they visibly cool down.
//   * ALPHA  - gases and glass are drawn half-transparent.
//
//  Colour values: red 0..31, green 0..63, blue 0..31 (RGB565).
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module gfx_material_shader (
    input  wire [15:0] cell_in,
    input  wire [15:0] cell_above,
    input  wire [6:0]  lx,
    input  wire [6:0]  ly,
    input  wire [7:0]  frame,
    output reg  [15:0] rgb,
    output reg  [1:0]  alpha     // 0 = invisible, 1 = 50 % blend, 3 = solid
);

    // ---- Unpack the cell ---------------------------------------------------------
    wire [5:0] mat   = cell_in[`C_MAT];
    wire [3:0] life  = cell_in[`C_LIFE];
    wire [2:0] shade = cell_in[`C_SHADE];
    wire [5:0] above = cell_above[`C_MAT];

    // Is the cell above "air" (so this pixel is the top surface)?
    wire surface = (above == `M_EMPTY) || (above == `M_STEAM) || (above == `M_SMOKE) ||
                   (above == `M_FUMES) || (above == `M_HYDROGEN) || (above == `M_FIRE) ||
                   (above == `M_SPATTER);

    // ---- Noise sources -------------------------------------------------------------
    // h_still : fixed per pixel (sparkles that stay in place)
    // h_slow  : changes every 8 frames, on a 2x2 grid (lava crawl)
    // h_fast  : changes every frame (fire flicker)
    wire [7:0] h_still = ({1'b0, lx} * 8'd73) ^ ({1'b0, ly} * 8'd151) ^ {ly[2:0], lx[4:0]};
    wire [7:0] h_slow  = ({2'b0, lx[6:1]} * 8'd29) ^ ({2'b0, ly[6:1]} * 8'd57) ^
                         ({3'b0, frame[7:3]} * 8'd101) ^ {lx[1:0], ly[5:0]};
    wire [7:0] h_fast  = h_still ^ (frame * 8'd37);

    // Water caustics: diagonal ripples that drift with time
    wire [3:0] ripple  = lx[3:0] + ly[4:1] + frame[6:3];

    // Signed brightness offset from the grain's shade: -3 .. +4
    wire signed [4:0] var_s = $signed({2'b0, shade}) - 5'sd3;

    // Is this material one that glows while hot?
    wire glows = (mat == `M_STONE) || (mat == `M_OBSIDIAN) || (mat == `M_GLASS) ||
                 (mat == `M_SANDSTONE) || (mat == `M_INGOT) || (mat == `M_BRICK) ||
                 (mat == `M_POTTERY) || (mat == `M_SLAG) || (mat == `M_BEADS);

    // ---- Main colour selection --------------------------------------------------------
    integer r, g, b;          // working colour (may overflow, clamped at the end)
    integer heat;

    always @* begin
        r = 0; g = 0; b = 0;
        heat = 0;
        alpha = 2'd3;

        case (mat)
            // ======================= the six base materials =======================
            `M_WATER: begin
                r = 3; g = 22; b = 26 + var_s;
                if (ripple == 4'd0)      begin r = 9;  g = 40; b = 31; end   // caustic
                if (surface)             begin r = 16; g = 54; b = 31; end   // bright surface line
            end
            `M_SAND: begin
                r = 27 + var_s; g = 46 + 2*var_s; b = 13 + var_s;
            end
            `M_LAVA: begin
                if      (h_slow < 8'd40)  begin r = 31; g = 52; b = 8;  end  // yellow hot-spot
                else if (h_slow < 8'd150) begin r = 31; g = 24; b = 0;  end  // orange
                else                      begin r = 22; g = 6;  b = 0;  end  // dark crust
                if (surface && frame[4] ^ h_still[0]) begin r = 31; g = 40; b = 4; end
            end
            `M_METAL: begin
                r = 13 + 2*var_s; g = 28 + 3*var_s; b = 16 + 2*var_s;
                if (h_still == frame) begin r = 31; g = 63; b = 31; end      // travelling glint
            end
            `M_ACID: begin
                r = 7; g = 56 + var_s; b = 6;
                // little bubbles drift upward
                if (((ly + frame[6:1]) & 7'd7) == 7'd0 && lx[1:0] == shade[1:0])
                    begin r = 22; g = 63; b = 18; end
                if (surface) begin r = 16; g = 63; b = 12; end
            end
            `M_OIL: begin
                r = 14 + var_s; g = 18 + var_s; b = 1;
                if (surface) begin                                            // rainbow sheen
                    case ((lx[2:0] + frame[6:4]) % 3)
                        0: begin r = 22; g = 30; b = 8;  end
                        1: begin r = 10; g = 32; b = 18; end
                        default: begin r = 24; g = 20; b = 14; end
                    endcase
                end
            end

            // ============================ gases ============================
            `M_STEAM: begin
                r = 18 + life[3:1]; g = 40 + life; b = 22 + life[3:1];
                alpha = 2'd1;
            end
            `M_FUMES: begin
                r = 18; g = 52 + life[3:1]; b = 4;
                alpha = (h_fast[0]) ? 2'd1 : 2'd3;
            end
            `M_SMOKE: begin
                r = 6 + life[3:1]; g = 12 + life; b = 7 + life[3:1];
                alpha = 2'd1;
            end
            `M_HYDROGEN: begin
                r = 16; g = 44; b = 31;
                alpha = (lx[0] ^ ly[0]) ? 2'd1 : 2'd0;                         // sparse bubbles
            end
            `M_SPATTER: begin
                r = 16; g = 63; b = 12;
            end

            // ============================ fire ============================
            `M_FIRE: begin
                if      (life >= 4'd9) begin r = 31; g = 56; b = 12; end      // white-yellow core
                else if (life >= 4'd5) begin r = 31; g = 32; b = 0;  end      // orange
                else                   begin r = 26; g = 10; b = 0;  end      // dying red
                if (h_fast[1:0] == 2'd0) begin g = g + 8; end                 // flicker
            end
            `M_BLAST: begin
                if      (life > 4'd8)  begin r = 31; g = 63; b = 28; end
                else if (life > 4'd4)  begin r = 31; g = 52; b = 6;  end
                else                   begin r = 31; g = 26; b = 0;  end
            end

            // ============================ solids ============================
            `M_STONE: begin
                r = 13 + 2*var_s; g = 26 + 3*var_s; b = 13 + 2*var_s;
            end
            `M_OBSIDIAN: begin
                r = 4; g = 5; b = 9;
                if (shade == 3'd7 || h_still[6:0] == 7'd0) begin r = 14; g = 18; b = 26; end // glossy
            end
            `M_GLASS: begin
                r = 14; g = 54; b = 28;
                alpha = 2'd1;
                if (h_still[5:0] == {frame[7:3], 1'b0}) begin r = 31; g = 63; b = 31; alpha = 2'd3; end
            end
            `M_SANDSTONE: begin
                if (ly[1] ^ shade[0]) begin r = 26; g = 38; b = 12; end
                else                  begin r = 22; g = 32; b = 10; end
            end
            `M_INGOT: begin
                r = 22; g = 46; b = 26;
                if (((lx + ly + frame[7:2]) & 7'd15) == 7'd0) begin r = 31; g = 63; b = 31; end // gleam
            end
            `M_BRICK: begin
                // brick pattern with light mortar lines
                if (ly[1:0] == 2'd0 || ((lx + (ly[2] ? 7'd4 : 7'd0)) & 7'd7) == 7'd0)
                    begin r = 20; g = 40; b = 18; end
                else
                    begin r = 22 + var_s; g = 14 + var_s; b = 4; end
            end
            `M_POTTERY: begin
                r = 26 + var_s; g = 30 + var_s; b = 10;
                if (shade >= 3'd6 && (lx[0] ^ ly[0])) begin r = 31; g = 44; b = 18; end // glaze shine
            end

            // ====================== powders from reactions ======================
            `M_PUMICE: begin
                if (shade < 3'd2) begin r = 12; g = 22; b = 10; end           // pores
                else              begin r = 22 + var_s; g = 42 + var_s; b = 18 + var_s; end
            end
            `M_MUD:     begin r = 13 + var_s; g = 18 + var_s; b = 5;          end
            `M_CLAY:    begin r = 24 + var_s; g = 30 + var_s; b = 14;         end
            `M_RUST: begin
                r = 24 + var_s; g = 16 + 2*var_s; b = 3;
                if (shade == 3'd7) begin r = 30; g = 26; b = 4; end
            end
            `M_SLAG: begin
                r = 9 + var_s; g = 10 + var_s; b = 6;
                if (shade == 3'd7) begin r = 24; g = 20; b = 0; end           // embers
            end
            `M_COATED: begin
                r = 20 + var_s; g = 36 + 2*var_s; b = 10;
                if (h_still == frame) begin r = 31; g = 52; b = 16; end
            end
            `M_WETSAND: begin r = 18 + var_s; g = 32 + 2*var_s; b = 8 + var_s; end
            `M_BEADS: begin
                r = 18; g = 56; b = 30;
                if (shade == 3'd7) begin r = 31; g = 63; b = 31; end
            end

            // ====================== liquids from reactions ======================
            `M_DILUTE: begin
                r = 10; g = 46; b = 22;
                if (ripple == 4'd0) begin r = 16; g = 56; b = 26; end
                if (surface)        begin r = 18; g = 60; b = 28; end
            end
            `M_MOLTEN: begin
                if (h_slow < 8'd90) begin r = 31; g = 62; b = 22; end         // white-hot
                else                begin r = 31; g = 44; b = 4;  end
            end
            `M_SOLUTION: begin
                r = 4; g = 44 + var_s; b = 18;
                if (ripple == 4'd0) begin r = 10; g = 54; b = 22; end
                if (surface)        begin r = 12; g = 58; b = 24; end
            end
            `M_TAR: begin
                r = 5; g = 7; b = 2;
                if (surface || shade == 3'd7) begin r = 14; g = 16; b = 8; end
            end
            `M_EMULSION: begin
                if ((lx[3:0] + ly[3:0] + frame[6:3]) < 5'd8) begin r = 24; g = 52; b = 24; end
                else                                        begin r = 20; g = 40; b = 26; end
            end

            default: begin
                r = 0; g = 0; b = 0;
                alpha = 2'd0;                                                  // empty: show background
            end
        endcase

        // ---- Glow: hot solids blend toward orange by their LIFE value -------------
        if (glows && life != 4'd0) begin
            heat = life;                                   // 1..15
            r = (r * (16 - heat) + 31 * heat) >>> 4;
            g = (g * (16 - heat) + (14 + life) * heat) >>> 4;
            b = (b * (16 - heat)) >>> 4;
            alpha = 2'd3;
        end

        // ---- Clamp to the legal RGB565 range and pack -----------------------------
        if (r < 0) r = 0;  if (r > 31) r = 31;
        if (g < 0) g = 0;  if (g > 63) g = 63;
        if (b < 0) b = 0;  if (b > 31) b = 31;
        rgb = {r[4:0], g[5:0], b[4:0]};
    end

endmodule

`default_nettype wire
