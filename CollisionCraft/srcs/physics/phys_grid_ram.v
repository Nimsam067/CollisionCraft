// =============================================================================
//  phys_grid_ram.v  --  The memory that holds one screen's worth of grains
// -----------------------------------------------------------------------------
//  OWNER: PERSON 2  (Physics Engine)
//
//  6144 cells x 16 bits. Vivado turns this into 3 block RAMs.
//
//  Port A (core clock, read + write): used by the physics engine.
//  Port B (OLED clock, read only)   : used by the renderer to draw the screen.
//
//  Both ports have one cycle of read latency: put an address in, the data
//  comes out on the next clock edge. The two ports run on different clocks,
//  which block RAM handles natively, so the physics and the drawing never
//  have to wait for each other.
// =============================================================================
`default_nettype none

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

`default_nettype wire
