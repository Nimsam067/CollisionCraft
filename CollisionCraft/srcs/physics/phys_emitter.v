// =============================================================================
//  phys_emitter.v  --  Pours a fixed amount of material into a funnel
// -----------------------------------------------------------------------------
//  OWNER: PERSON 2  (Physics Engine)
//
//  When the chamber controller says "start", the emitter offers grains of
//  that material to the physics engine until POUR_VOLUME grains have been
//  placed (the engine pulses `pop` for each one).
//
//  Different materials pour differently, just by changing how wide the
//  spawn area is:
//      liquids  -> a thin 2-pixel stream
//      lava     -> a thick 4-pixel gloop
//      metal    -> a 4-pixel trickle
//      sand     -> an 8-pixel sprinkle
//
//  `continuous` = 1 ignores the volume and pours forever (title screen demo).
// =============================================================================
`include "cc_defines.vh"
`default_nettype none

module phys_emitter (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,          // pulse: begin a new pour of start_mat
    input  wire [5:0] start_mat,
    input  wire       stop,           // pulse: abandon the pour
    input  wire       pause,          // hold (two switches up)
    input  wire       continuous,     // demo mode: pour forever
    input  wire [5:0] demo_mat,
    input  wire       pop,            // engine placed one grain
    output wire       valid,
    output wire [5:0] mat,
    output reg  [5:0] x0,
    output reg  [1:0] wlog,
    output wire [6:0] y,
    output wire       done            // the whole volume has been poured
);

    reg [12:0] remaining;
    reg [5:0]  pour_mat;
    reg        active;

    always @(posedge clk) begin
        if (rst || stop) begin
            remaining <= 13'd0;
            active    <= 1'b0;
            pour_mat  <= `M_EMPTY;
        end else if (start) begin
            remaining <= `POUR_VOLUME;
            active    <= 1'b1;
            pour_mat  <= start_mat;
        end else if (pop && active && remaining != 13'd0) begin
            remaining <= remaining - 13'd1;
        end
    end

    assign mat   = continuous ? demo_mat : pour_mat;
    assign valid = continuous ? 1'b1 : (active && remaining != 13'd0 && !pause);
    assign done  = active && (remaining == 13'd0);
    assign y     = 7'd26;                       // just inside the top of the funnel

    // Spawn width per material: centred on x = 32
    always @* begin
        case (mat)
            `M_SAND:  begin wlog = 2'd3; x0 = 6'd28; end   // 8 wide sprinkle
            `M_LAVA:  begin wlog = 2'd2; x0 = 6'd30; end   // 4 wide gloop
            `M_METAL: begin wlog = 2'd2; x0 = 6'd30; end   // 4 wide trickle
            default:  begin wlog = 2'd1; x0 = 6'd31; end   // 2 wide stream
        endcase
    end

endmodule

`default_nettype wire
