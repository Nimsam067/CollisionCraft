// Changes that happen to a grain on its own over time, without a neighbour. When
// a grain's LIFE timer runs out, steam can condense back into water, fire turns
// into smoke, gases fade away, molten metal sets into an ingot and so on. When
// flush is on (draining or discarding), gases and fire disappear straight away.
//
// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module rxn_self (
    input  wire [5:0] mat,
    input  wire [3:0] life,
    input  wire       flush,
    input  wire [7:0] rnd,
    output reg        transform,     // the material changed
    output reg  [5:0] new_mat,
    output reg  [3:0] new_life
);

    wire [2:0] cls, decay;
    mat_properties p (.mat(mat), .cls(cls), .dens(), .flow(), .init_life(), .decay(decay),
                      .flammable(), .glows());

    // Starting LIFE for whatever we turn into
    reg  [5:0] product;
    wire [3:0] product_life;
    mat_properties pp (.mat(product), .cls(), .dens(), .flow(), .init_life(product_life),
                       .decay(), .flammable(), .glows());

    // Does the timer tick this step?   decay 1 = always ... 7 = 1 in 64
    reg tick;
    always @* begin
        case (decay)
            3'd1:    tick = 1'b1;
            3'd2:    tick = (rnd[0]   == 1'b0);
            3'd3:    tick = (rnd[1:0] == 2'b0);
            3'd4:    tick = (rnd[2:0] == 3'b0);
            3'd5:    tick = (rnd[3:0] == 4'b0);
            3'd6:    tick = (rnd[4:0] == 5'b0);
            3'd7:    tick = (rnd[5:0] == 6'b0);
            default: tick = 1'b0;
        endcase
    end

    // What does each material become when its timer runs out?
    always @* begin
        case (mat)
            `M_STEAM:    product = rnd[6] ? `M_WATER : `M_EMPTY;
            `M_FIRE:     product = rnd[6] ? `M_SMOKE : `M_EMPTY;
            `M_SMOKE:    product = `M_EMPTY;
            `M_FUMES:    product = `M_EMPTY;
            `M_HYDROGEN: product = `M_EMPTY;
            `M_SPATTER:  product = `M_DILUTE;
            `M_BLAST:    product = `M_SMOKE;
            `M_EMULSION: product = rnd[6] ? `M_WATER : `M_OIL;
            `M_MOLTEN:   product = `M_INGOT;
            default:     product = mat;            // just cools down
        endcase
    end

    always @* begin
        transform = 1'b0;
        new_mat   = mat;
        new_life  = life;

        if (flush && (cls == `CL_GAS || cls == `CL_FIRE || cls == `CL_BLAST)) begin
            // draining: gases and flames disappear immediately
            transform = 1'b1;
            new_mat   = `M_EMPTY;
            new_life  = 4'd0;
        end
        else if (tick) begin
            if (life != 4'd0)
                new_life = life - 4'd1;
            else if (product != mat) begin
                transform = 1'b1;
                new_mat   = product;
                new_life  = product_life;
            end
        end
    end

endmodule
