// =============================================================================
//  gfx_text_line.v  --  Draws one line of text (up to 10 characters)
// -----------------------------------------------------------------------------
//  OWNER: PERSON 1  (Materials, Graphics & Controls)
//
//  For every pixel the screen asks "is this pixel part of a letter?".
//  This module answers that for ONE line of text.
//
//    str     : 10 ASCII characters (80 bits), leftmost character in the top
//              byte. Trailing spaces are ignored when centring.
//    scale2  : 0 = normal 5x7 letters on a 6-pixel grid
//              1 = double size 10x14 letters on a 12-pixel grid
//    centre  : 1 = centre the text horizontally on the 64-pixel-wide screen
//              (ox is ignored)
//    ox, oy  : top-left corner of the text (signed so text can slide in
//              from off-screen)
// =============================================================================
`default_nettype none

module gfx_text_line (
    input  wire [6:0]        px,      // pixel x (0..63)
    input  wire [6:0]        py,      // pixel y (0..95)
    input  wire signed [8:0] ox,
    input  wire signed [8:0] oy,
    input  wire              scale2,
    input  wire              centre,
    input  wire [79:0]       str,
    output wire              on
);

    // ---- 1. How many characters are really used? (ignore trailing spaces) ----
    reg [3:0] len;
    integer i;
    always @* begin
        len = 4'd0;
        for (i = 0; i < 10; i = i + 1)
            if (str[79 - 8*i -: 8] != " " && str[79 - 8*i -: 8] != 8'd0)
                len = i + 1;
    end

    // ---- 2. Work out where the text starts -----------------------------------
    // Width in pixels: normal letters are 5 wide + 1 gap, big ones 10 + 2.
    wire [7:0] width   = scale2 ? (len * 8'd12 - 8'd2) : (len * 8'd6 - 8'd1);
    wire signed [8:0] cx = $signed({1'b0, 8'd64 - width}) >>> 1;
    wire signed [8:0] x0 = centre ? cx : ox;

    // Position of this pixel relative to the text's top-left corner
    wire signed [9:0] dx = $signed({3'b0, px}) - x0;
    wire signed [9:0] dy = $signed({3'b0, py}) - oy;

    // ---- 3. Which character, which column inside it, which row ------------------
    wire [7:0] dxu = dx[7:0];
    wire [7:0] dyu = dy[7:0];

    wire [3:0] char_idx = scale2 ? (dxu / 8'd12) : (dxu / 8'd6);
    wire [3:0] col_in   = scale2 ? ((dxu % 8'd12) >> 1) : (dxu % 8'd6);
    wire [2:0] row_in   = scale2 ? dyu[3:1] : dyu[2:0];

    wire inside = (dx >= 0) && (dy >= 0) &&
                  (scale2 ? (dx < len * 12 && dy < 14)
                          : (dx < len * 6  && dy < 7));

    // ---- 4. Look the character up in the font -----------------------------------
    wire [7:0] ch = str[79 - 8*char_idx -: 8];
    wire [4:0] bits;

    gfx_font_rom font (
        .ch   (ch),
        .row  (row_in),
        .bits (bits)
    );

    // Column 5 is the 1-pixel gap between letters
    assign on = inside && (col_in < 4'd5) && bits[3'd4 - col_in[2:0]];

endmodule

`default_nettype wire
