// =============================================================================
//  gfx_oled_mapper.v  --  Turns the OLED's pixel_index into portrait (x, y)
// -----------------------------------------------------------------------------
//  OWNER: PERSON 1  (Materials, Graphics & Controls)
//
//  The OLED is natively 96 wide x 64 tall and sends pixels row by row.
//  We stand it up on its side, so our "logical" screen is 64 wide x 96 tall.
//
//  ROTATE = 0 :  lx = 63 - ny,  ly = nx        (one way round)
//  ROTATE = 1 :  lx = ny,       ly = 95 - nx   (the other way round)
//  MIRROR = 1 :  additionally flips left/right
//
//  >>> If a screen shows up upside-down on the board, flip its ROTATE
//      parameter in CollisionCraft_Top.v. Nothing else needs to change. <<<
//
//  LOOK-AHEAD
//  ----------
//  Our pixels come out of block RAM, which takes a few clock cycles to read.
//  Oled_Display grabs pixel_data at the very start of each pixel. So we
//  always prepare the NEXT pixel in advance:
//
//    * "target" is the index we are preparing (current + 1, wrapping to 0)
//    * start      = target just changed  -> begin preparing (lx, ly)
//    * advance    = the OLED moved on    -> present what we prepared
//
//  Oled_Display changes pixel_index on the FALLING clock edge and latches
//  pixel_data on the next falling edge. We act on the RISING edge in between,
//  so `advance` (which is combinational) gives us exactly half a clock to
//  copy the prepared pixel into the output register. That is plenty.
// =============================================================================
`default_nettype none

module gfx_oled_mapper #(
    parameter ROTATE = 0,
    parameter MIRROR = 0
)(
    input  wire        clk,             // 6.25 MHz OLED clock
    input  wire [12:0] pixel_index,
    input  wire        sending_pixels,
    output wire        advance,         // OLED moved to a new pixel (combinational)
    output wire        start,           // a new target needs preparing (combinational)
    output reg  [6:0]  lx,              // logical coordinates of the target
    output reg  [6:0]  ly
);

    // ---- Which pixel should we prepare next? ---------------------------------------
    wire [12:0] target = !sending_pixels          ? 13'd0 :
                         (pixel_index == 13'd6143) ? 13'd0 :
                                                     pixel_index + 13'd1;

    reg [12:0] idx_q = 13'd0;
    reg [12:0] tgt_q = 13'd1;

    assign advance = (pixel_index != idx_q);
    assign start   = (target != tgt_q);

    // ---- Native coordinates of the target ---------------------------------------------
    wire [6:0] nx = target % 13'd96;     // 0..95 along the OLED's long side
    wire [5:0] ny = target / 13'd96;     // 0..63 along the short side

    // ---- Rotate into portrait ---------------------------------------------------------
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

`default_nettype wire
