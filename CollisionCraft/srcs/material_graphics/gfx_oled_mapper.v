// Converts the OLED's pixel_index into (x, y) for portrait layout (64 wide,
// 96 tall). ROTATE picks which way the screen is turned and MIRROR flips it left
// to right. If a screen looks upside down, change ROTATE value in
// CollisionCraft_Top.v.

// Block RAM takes a few cycles to read, so this works one pixel ahead of the
// OLED and hands over the prepared pixel when the OLED moves on.

// Owner: Zi Le (Materials, Graphics & Controls)

module gfx_oled_mapper #(
    parameter ROTATE = 0,
    parameter MIRROR = 0
)(
    input wire clk, // 6.25 MHz OLED clock
    input wire [12:0] pixel_index,
    input wire sending_pixels,
    output wire advance, // OLED moved to a new pixel
    output wire start, // a new target
    output reg [6:0] lx, // coordinates of the target
    output reg [6:0] ly
);

    // Next pixel
    wire [12:0] target = !sending_pixels ? 13'd0 :
                         (pixel_index == 13'd6143) ? 13'd0 :
                                                     pixel_index + 13'd1;

    reg [12:0] idx_q = 13'd0;
    reg [12:0] tgt_q = 13'd1;

    assign advance = (pixel_index != idx_q);
    assign start = (target != tgt_q);

    // Coordinates of the target
    wire [6:0] nx = target % 13'd96; // 0..95 along the OLED's long side
    wire [5:0] ny = target / 13'd96; // 0..63 along the short side

    // Rotate into portrait
    wire [6:0] rx = (ROTATE == 0) ? (7'd63 - {1'b0, ny}) : {1'b0, ny};
    wire [6:0] ry = (ROTATE == 0) ? nx : (7'd95 - nx);
    wire [6:0] mx = (MIRROR == 1) ? (7'd63 - rx) : rx;

    always @(posedge clk) begin
        idx_q <= pixel_index;
        tgt_q <= target;
        if (start) begin
            lx <= mx;
            ly <= ry;
        end
    end

endmodule
