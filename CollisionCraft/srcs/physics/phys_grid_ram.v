// Dual port block RAM holding one screen of cells (6144 x 16 bits). Port A is
// used by the physics engine on the core clock and port B is read by the
// renderer on the OLED clock. Both have one cycle of read latency.
//
// Owner: Aadi (Physics Engine)

module phys_grid_ram (
    // physics side
    input  wire        clk_a,
    input  wire [12:0] addr_a,
    input  wire        we_a,
    input  wire [15:0] din_a,
    output reg  [15:0] dout_a,
    // renderer side
    input  wire        clk_b,
    input  wire [12:0] addr_b,
    output reg  [15:0] dout_b
);

    (* ram_style = "block" *)
    reg [15:0] mem [0:6143];

    // Start completely empty
    integer i;
    initial begin
        for (i = 0; i < 6144; i = i + 1)
            mem[i] = 16'd0;
    end

    always @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    always @(posedge clk_b) begin
        dout_b <= mem[addr_b];
    end

endmodule
