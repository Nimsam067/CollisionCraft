// State machine for one reagent chamber (JB or JC).
// EMPTY waits for a switch, POUR fills it up, READY waits for the release
// button, RELEASE opens the valve so it drains into JA, and SPENT waits for the
// switch to go back down. Turning the switch off (or picking another one) during
// POUR, HOLD or READY goes to DISCARD, which opens the trapdoor. HOLD is when two
// switches are up and pouring is paused. A state counts as drained once the
// engine has seen zero grains for two steps in a row.

// Owner: Aadi (Physics Engine)

`include "cc_defines.vh"

module phys_chamber_ctrl (
    input  wire        clk,
    input  wire        rst,               
    input  wire        step_done,         // engine finished a step
    input  wire [12:0] cell_count,        // grains in the chamber
    input  wire [1:0]  sel_state,         // from mat_switch_select
    input  wire [5:0]  sel_mat,
    input  wire        allow_pour,        // pouring is allowed
    input  wire        release_cmd,       
    input  wire        emit_done,         
    output reg  [2:0]  state,
    output reg  [5:0]  cur_mat,
    output reg         emit_start,        
    output reg         emit_stop,         
    output wire        emit_pause,
    output wire        valve_open,
    output wire        trapdoor_open,
    output wire [1:0]  sink_mode,
    output wire        flush
);

    // Outputs that follow directly from the state
    assign emit_pause    = (state == `CH_HOLD);
    assign valve_open    = (state == `CH_RELEASE);
    assign trapdoor_open = (state == `CH_DISCARD);
    assign sink_mode     = (state == `CH_RELEASE) ? `SINK_FIFO :
                           (state == `CH_DISCARD) ? `SINK_DELETE : `SINK_CLOSED;
    assign flush         = (state == `CH_DISCARD);

    // Is the chamber empty?
    reg [1:0] zero_steps;     // consecutive steps with no grains
    reg [5:0] steps_in_state; 
    reg       was_ready;      // remember if the pour had finished before HOLD
    wire      drained = (zero_steps == 2'd2) && (steps_in_state >= 6'd30);

    // Is the selection still the same switch?
    wire same_pick  = (sel_state == `SEL_ONE) && (sel_mat == cur_mat);
    wire lost_pick  = (sel_state == `SEL_NONE) || ((sel_state == `SEL_ONE) && (sel_mat != cur_mat));

    reg [2:0] prev_state;

    always @(posedge clk) begin
        emit_start <= 1'b0;
        emit_stop  <= 1'b0;

        if (rst) begin
            state          <= `CH_EMPTY;
            prev_state     <= `CH_EMPTY;
            cur_mat        <= `M_EMPTY;
            zero_steps     <= 2'd0;
            steps_in_state <= 6'd0;
            was_ready      <= 1'b0;
            emit_stop      <= 1'b1;
        end else begin
            prev_state <= state;
            if (state != prev_state) begin
                zero_steps     <= 2'd0;
                steps_in_state <= 6'd0;
            end else if (step_done) begin
                if (cell_count == 13'd0) begin
                    if (zero_steps != 2'd2) zero_steps <= zero_steps + 2'd1;
                end else
                    zero_steps <= 2'd0;
                if (steps_in_state != 6'd63) steps_in_state <= steps_in_state + 6'd1;
            end

            // Different states
            case (state)
                `CH_EMPTY: begin
                    if (allow_pour && sel_state == `SEL_ONE) begin
                        cur_mat    <= sel_mat;
                        emit_start <= 1'b1;
                        was_ready  <= 1'b0;
                        state      <= `CH_POUR;
                    end
                end

                `CH_POUR: begin
                    if (sel_state == `SEL_CONFLICT)
                        state <= `CH_HOLD;
                    else if (lost_pick) begin
                        emit_stop <= 1'b1;
                        state     <= `CH_DISCARD;
                    end else if (emit_done) begin
                        was_ready <= 1'b1;
                        state     <= `CH_READY;
                    end
                end

                `CH_HOLD: begin
                    if (same_pick)
                        state <= was_ready ? `CH_READY : `CH_POUR;
                    else if (lost_pick) begin
                        emit_stop <= 1'b1;
                        state     <= `CH_DISCARD;
                    end
                end

                `CH_READY: begin
                    if (sel_state == `SEL_CONFLICT)
                        state <= `CH_HOLD;
                    else if (lost_pick) begin
                        emit_stop <= 1'b1;
                        state     <= `CH_DISCARD;
                    end else if (release_cmd) begin
                        emit_stop <= 1'b1;
                        state     <= `CH_RELEASE;
                    end
                end

                `CH_DISCARD: begin
                    if (drained) begin
                        cur_mat <= `M_EMPTY;
                        state   <= `CH_EMPTY;
                    end
                end

                `CH_RELEASE: begin
                    if (drained)
                        state <= `CH_SPENT;
                end

                `CH_SPENT: begin
                    // the player must lower this switch before pouring again
                    if (!same_pick) begin
                        cur_mat <= `M_EMPTY;
                        state   <= `CH_EMPTY;
                    end
                end

                default: state <= `CH_EMPTY;
            endcase
        end
    end

endmodule
