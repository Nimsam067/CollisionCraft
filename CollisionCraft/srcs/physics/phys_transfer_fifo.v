// FIFO that carries grains from a reagent chamber down to the beaker (JA).
// Grains leaving the bottom of JB or JC are pushed in and come out at the top of
// the matching funnel in JA. dout always shows the oldest grain, and almost_full
// tells the chamber to keep its valve shut for a moment.

// Owner: Aadi (Physics Engine)

module phys_transfer_fifo #(
    parameter DEPTH_LOG2 = 9                 // 512 grains
)(
    input  wire       clk,
    input  wire       rst,                   // also used to empty the pipe
    input  wire       push,
    input  wire [5:0] din,
    input  wire       pop,
    output wire [5:0] dout,
    output wire       empty,
    output wire       almost_full
);

    localparam DEPTH = (1 << DEPTH_LOG2);

    reg [5:0]            mem [0:DEPTH-1];
    reg [DEPTH_LOG2-1:0] wr_ptr, rd_ptr;
    reg [DEPTH_LOG2:0]   count;

    assign dout        = mem[rd_ptr];
    assign empty       = (count == 0);
    assign almost_full = (count >= DEPTH - 16);

    wire do_push = push && (count != DEPTH);
    wire do_pop  = pop  && !empty;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            if (do_push) begin
                mem[wr_ptr] <= din;
                wr_ptr      <= wr_ptr + 1'b1;
            end
            if (do_pop)
                rd_ptr <= rd_ptr + 1'b1;
            case ({do_push, do_pop})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: ;
            endcase
        end
    end

endmodule
