// Draws one line of text, up to 10 characters. For each pixel it says whether
// that pixel is part of a letter. Text can be normal or double size, and can be
// centred on the screen or placed.

// Owner: Zi Le (Materials, Graphics & Controls)

module gfx_text_line (
    input wire [6:0] px, // pixel x (0..63)
    input wire [6:0] py, // pixel y (0..95)
    input wire signed [8:0] ox,
    input wire signed [8:0] oy,
    input wire scale2,
    input wire centre,
    input wire [79:0] str,
    output wire on
);

    // Number of characters used
    reg [3:0] len;
    integer i;
    always @* begin
        len = 4'd0;
        for (i = 0; i < 10; i = i + 1)
            if (str[79 - 8*i -: 8] != " " && str[79 - 8*i -: 8] != 8'd0)
                len = i + 1;
    end

    // Text starts
    // Width in pixels, normal letters (5+1), big ones (10+2)
    wire [7:0] width = (len == 0) ? 8'd0 :
                       scale2 ? (len * 8'd12 - 8'd2) : (len * 8'd6 - 8'd1);
    // Signed subtraction so text wider than the screen stays centred and clips
    wire signed [8:0] cx = (9'sd64 - $signed({1'b0, width})) >>> 1;
    wire signed [8:0] x0 = centre ? cx : ox;

    // Position of this pixel relative to the text's top left corner
    wire signed [9:0] dx = $signed({3'b0, px}) - x0;
    wire signed [9:0] dy = $signed({3'b0, py}) - oy;

    // Which character, which column inside it, which row
    wire [7:0] dxu = dx[7:0];
    wire [7:0] dyu = dy[7:0];

    wire [3:0] char_idx = scale2 ? (dxu / 8'd12) : (dxu / 8'd6);
    wire [3:0] col_in = scale2 ? ((dxu % 8'd12) >> 1) : (dxu % 8'd6);
    wire [2:0] row_in = scale2 ? dyu[3:1] : dyu[2:0];

    wire within_text = (dx >= 0) && (dy >= 0) &&
                  (scale2 ? (dx < len * 12 && dy < 14)
                          : (dx < len * 6 && dy < 7));

    // Look the character up in the font
    wire [7:0] ch = str[79 - 8*char_idx -: 8];
    wire [4:0] bits;

    gfx_font_rom font (
        .ch (ch),
        .row (row_in),
        .bits (bits)
    );

    assign on = within_text && (col_in < 4'd5) && bits[3'd4 - col_in[2:0]];

endmodule
