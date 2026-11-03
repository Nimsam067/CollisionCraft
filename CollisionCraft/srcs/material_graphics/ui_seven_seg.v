// =============================================================================
//  ui_seven_seg.v  --  Drives the 4-digit 7-segment display
// -----------------------------------------------------------------------------
//  OWNER: PERSON 1  (Materials, Graphics & Controls)
//
//  The four digits share their segment wires, so we light one digit at a
//  time, very fast (about 1.5 kHz per digit), and your eye sees all four.
//
//  Inputs are glyph CODES (SG_* in cc_defines.vh), not raw segments, so the
//  game logic can just say "show P L A Y" or "show 1 5 . 0 7".
//
//  Basys3 wiring: seg[0] = segment a ... seg[6] = segment g, everything
//  active-LOW (0 = lit). an[3] is the leftmost digit.
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module ui_seven_seg (
    input  wire       clk,          // 25 MHz
    input  wire [4:0] d3,           // leftmost digit
    input  wire [4:0] d2,
    input  wire [4:0] d1,
    input  wire [4:0] d0,           // rightmost digit
    input  wire [3:0] dp_on,        // decimal points, bit 3 = leftmost
    output reg  [6:0] seg,
    output reg        dp,
    output reg  [3:0] an
);

    // Glyph code -> segments {g,f,e,d,c,b,a}, active low
    function [6:0] decode;
        input [4:0] code;
        case (code)
            `SG_0:     decode = 7'b1000000;
            `SG_1:     decode = 7'b1111001;
            `SG_2:     decode = 7'b0100100;
            `SG_3:     decode = 7'b0110000;
            `SG_4:     decode = 7'b0011001;
            `SG_5:     decode = 7'b0010010;
            `SG_6:     decode = 7'b0000010;
            `SG_7:     decode = 7'b1111000;
            `SG_8:     decode = 7'b0000000;
            `SG_9:     decode = 7'b0010000;
            `SG_A:     decode = 7'b0001000;
            `SG_B:     decode = 7'b0000011;
            `SG_C:     decode = 7'b1000110;
            `SG_D:     decode = 7'b0100001;
            `SG_E:     decode = 7'b0000110;
            `SG_F:     decode = 7'b0001110;
            `SG_H:     decode = 7'b0001001;
            `SG_I:     decode = 7'b1001111;
            `SG_L:     decode = 7'b1000111;
            `SG_N:     decode = 7'b0101011;
            `SG_O:     decode = 7'b0100011;
            `SG_P:     decode = 7'b0001100;
            `SG_R:     decode = 7'b0101111;
            `SG_S:     decode = 7'b0010010;
            `SG_T:     decode = 7'b0000111;
            `SG_U:     decode = 7'b1000001;
            `SG_Y:     decode = 7'b0010001;
            `SG_DASH:  decode = 7'b0111111;
            `SG_G:     decode = 7'b1000010;
            default:   decode = 7'b1111111;   // blank
        endcase
    endfunction

    // 16-bit counter: the top two bits pick which digit is lit
    reg [15:0] scan = 16'd0;
    always @(posedge clk) scan <= scan + 16'd1;

    always @(posedge clk) begin
        case (scan[15:14])
            2'd0: begin an <= 4'b1110; seg <= decode(d0); dp <= ~dp_on[0]; end
            2'd1: begin an <= 4'b1101; seg <= decode(d1); dp <= ~dp_on[1]; end
            2'd2: begin an <= 4'b1011; seg <= decode(d2); dp <= ~dp_on[2]; end
            default: begin an <= 4'b0111; seg <= decode(d3); dp <= ~dp_on[3]; end
        endcase
    end

endmodule

`default_nettype wire
