// Keeps track of what happens in the beaker: which reactions have been
// discovered, which reaction name to show in the banner, the white flash for
// explosions, how many grains of the challenge target are in the beaker, and how
// full the beaker is.
//
// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module rxn_tracker (
    input  wire        clk,
    input  wire        rst,
    input  wire        anim_tick,       // 60 Hz
    input  wire        enable,          // only track in lab modes (not the title demo)
    input  wire        clear_disc,      // pulse: forget all discoveries
    input  wire        clear_banner,    // pulse: hide the banner (lab was reset)
    // from the JA engine
    input  wire        rxn_valid,
    input  wire [5:0]  rxn_id,
    input  wire [1:0]  rxn_fx,
    input  wire        visit_valid,
    input  wire [5:0]  visit_mat,
    input  wire        step_done,
    input  wire [12:0] ja_count,
    // what the challenge wants
    input  wire [5:0]  target_mat,
    // results
    output reg  [12:0] target_count,
    output reg  [5:0]  disc_count,
    output reg         new_disc,        // pulse: first time a reaction was seen
    output reg         rxn_seen,        // pulse: any announced reaction
    output reg  [5:0]  rxn_seen_id,
    output wire        banner_show,
    output wire [79:0] banner_str,
    output reg         banner_new,
    output reg  [15:0] banner_col,
    output reg  [3:0]  flash,
    output wire [6:0]  fill_rows,
    output wire        beaker_full,
    output wire [63:0] found_mask       // bit N = reaction N has been discovered
);

    // Discoveries
    reg [63:0] found;
    wire       is_new = !found[rxn_id];
    assign     found_mask = found;     // free play uses this to suggest new reactions

    // Banner state
    reg [5:0] ban_id;
    reg [7:0] ban_timer;       // frames left on screen
    reg [7:0] ban_age;         // frames since it appeared
    reg [5:0] cool_id;         // reaction that just timed out ...
    reg [5:0] cool_timer;      // ... and must wait before showing again

    assign banner_show = (ban_timer != 8'd0);
    rxn_names names (.id(ban_id), .name(banner_str), .hint0(), .hint1());

    // Target counting
    reg [12:0] tgt_acc;

    always @(posedge clk) begin
        new_disc <= 1'b0;
        rxn_seen <= 1'b0;

        if (rst || clear_disc) begin
            found      <= 64'd0;
            disc_count <= 6'd0;
        end
        if (rst || clear_banner) begin
            ban_timer  <= 8'd0;
            ban_age    <= 8'd0;
            ban_id     <= `RX_NONE;
            banner_new <= 1'b0;
            cool_timer <= 6'd0;
            flash      <= 4'd0;
        end

        if (rst) begin
            tgt_acc      <= 13'd0;
            target_count <= 13'd0;
            banner_col   <= 16'hFFFF;
        end else begin
            // a reaction happened
            if (enable && rxn_valid) begin
                if (rxn_fx == `FX_BOOM)       flash <= 4'd15;
                else if (rxn_fx == `FX_FLASH && flash < 4'd8) flash <= 4'd8;

                if (rxn_id != `RX_NONE) begin
                    rxn_seen    <= 1'b1;
                    rxn_seen_id <= rxn_id;

                    if (is_new) begin
                        found[rxn_id] <= 1'b1;
                        disc_count    <= disc_count + 6'd1;
                        new_disc      <= 1'b1;
                    end

                    // show it if: it's new, or nothing is showing, or a different
                    // reaction has had the banner long enough
                    if (is_new ||
                        (ban_timer == 8'd0 && !(rxn_id == cool_id && cool_timer != 6'd0)) ||
                        (rxn_id != ban_id && ban_age > 8'd45)) begin
                        if (rxn_id != ban_id || ban_timer == 8'd0 || is_new) begin
                            ban_id     <= rxn_id;
                            ban_timer  <= 8'd150;
                            ban_age    <= 8'd0;
                            banner_new <= is_new;
                            banner_col <= is_new               ? {5'd31, 6'd48, 5'd0} :
                                          (rxn_fx == `FX_BOOM) ? {5'd31, 6'd24, 5'd0} :
                                                                 {5'd6,  6'd44, 5'd31};
                        end
                    end
                end
            end

            // 60 Hz housekeeping
            if (anim_tick) begin
                if (flash != 4'd0) flash <= flash - 4'd1;
                if (ban_age != 8'd255) ban_age <= ban_age + 8'd1;
                if (ban_timer == 8'd1) begin
                    cool_id    <= ban_id;           // just timed out: start cooldown
                    cool_timer <= 6'd60;
                end
                if (ban_timer != 8'd0) ban_timer <= ban_timer - 8'd1;
                if (cool_timer != 6'd0) cool_timer <= cool_timer - 6'd1;
            end

            // count target grains each physics step
            if (step_done) begin
                target_count <= tgt_acc + ((visit_valid && visit_mat == target_mat) ? 13'd1 : 13'd0);
                tgt_acc      <= 13'd0;
            end else if (visit_valid && visit_mat == target_mat && target_mat != `M_EMPTY) begin
                tgt_acc <= tgt_acc + 13'd1;
            end
        end
    end

    // Fill level: about 54 grains fill one row of the beaker
    wire [12:0] rows = ja_count / 13'd54;
    assign fill_rows   = (rows > 13'd66) ? 7'd66 : rows[6:0];
    assign beaker_full = (ja_count >= `BEAKER_FULL);

endmodule
