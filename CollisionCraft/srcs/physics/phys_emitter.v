// Pours a set amount of material (POUR_VOLUME grains) into the top of the
// funnel. The width of the stream depends on the material, so liquids come out
// thin and sand sprinkles out wide. continuous = 1 keeps pouring forever, which
// is used for the title screen demo.

// Owner: Aadi (Physics Engine)

`include "cc_defines.vh"

module phys_emitter (
    input wire clk,
    input wire rst,
    input wire start, // being a new pour
    input wire [5:0] start_mat,
    input wire stop, // stop the pour
    input wire pause, // hold (two switches up)
    input wire continuous, // demo mode: pour forever (opening screen)
    input wire [5:0] demo_mat,
    input wire pop,
    output wire valid,
    output wire [5:0] mat,
    output reg [5:0] x0,
    output reg [1:0] wlog,
    output wire [6:0] y,
    output wire done // the whole volume has been poured
);

    reg [12:0] remaining;
    reg [5:0] pour_mat;
    reg active;

    always @(posedge clk) begin
        if (rst || stop) begin
            remaining <= 13'd0;
            active <= 1'b0;
            pour_mat <= `M_EMPTY;
        end else if (start) begin
            remaining <= `POUR_VOLUME;
            active <= 1'b1;
            pour_mat <= start_mat;
        end else if (pop && active && remaining != 13'd0) begin
            remaining <= remaining - 13'd1;
        end
    end

    assign mat = continuous ? demo_mat : pour_mat;
    assign valid = continuous ? 1'b1 : (active && remaining != 13'd0 && !pause);
    assign done = active && (remaining == 13'd0);
    assign y = 7'd26; // just inside the top of the funnel

    // Spawn width per material: centred on x = 32
    always @* begin
        case (mat)
            `M_SAND: begin wlog = 2'd3; x0 = 6'd28; end // 8 wide sprinkle
            `M_LAVA: begin wlog = 2'd2; x0 = 6'd30; end // 4 wide gloop
            `M_METAL: begin wlog = 2'd2; x0 = 6'd30; end // 4 wide trickle
            default: begin wlog = 2'd1; x0 = 6'd31; end // 2 wide stream
        endcase
    end

endmodule
