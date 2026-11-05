// Tutorial mode. Part 1 goes through the five buttons one at a time, part 2 goes
// through the lab (picking, discarding, filling, releasing, draining and making
// obsidian). Each step waits until the player does the action, and HINT skips a
// step.

// Owner: Arnav (Interactions & Game Logic)

`include "cc_defines.vh"

module game_tutorial (
    input wire clk,
    input wire rst,
    input wire anim_tick,
    input wire enter, // start (or restart) the tutorial
    // buttons
    input wire btn_ok, btn_up, btn_down, btn_menu, btn_hint,
    // status
    input wire [2:0] jb_state, jc_state,
    input wire lab_busy, ja_draining,
    input wire [12:0] ja_count,
    input wire released,
    input wire rxn_seen,
    input wire [5:0] rxn_seen_id,
    // requests
    output reg want_release,
    output reg want_drain,
    output reg clear_lab,
    output reg exit_req,
    output wire allow_pour,
    output reg [5:0] hint_jb,
    output reg [5:0] hint_jc,
    output wire tour, // button tour running
    // what to show on JA
    output reg [79:0] header_str,
    output reg [15:0] header_col,
    output reg msg_show,
    output reg [79:0] msg0, msg1, msg2, msg3,
    output wire pad_show, // five button picture
    output reg [2:0] pad_hi, // which button in the picture blinks
    // 7 segment
    output wire [4:0] sg3, sg2, sg1, sg0,
    output wire [3:0] dp
);

    localparam [3:0] T_WELCOME = 4'd0, T_PAD = 4'd1, T_K_OK = 4'd2, T_K_UP = 4'd3,
                     T_K_DOWN = 4'd4, T_K_MENU = 4'd5, T_K_HINT = 4'd6, T_PICK = 4'd7,
                     T_DISCARD = 4'd8, T_FILL = 4'd9, T_RELEASE= 4'd10, T_WATCH = 4'd11,
                     T_ORDER = 4'd12, T_DRAIN = 4'd13, T_RECIPE = 4'd14, T_DONE = 4'd15;

    localparam [2:0] PAD_NONE = 3'd0, PAD_OK = 3'd1, PAD_UP = 3'd2, PAD_DOWN = 3'd3,
                     PAD_MENU = 3'd4, PAD_HINT = 3'd5;

    reg [3:0] step;
    reg [9:0] timer; // frames spent in this step
    reg saw_discard; // the trapdoor really opened
    reg saw_drain; // the drain really opened
    reg box_hidden; // hide instructions after the first release
    reg [7:0] blink;

    assign allow_pour = (step >= T_PICK) && (step != T_DONE);
    assign tour = (step >= T_PAD) && (step <= T_K_HINT);
    assign pad_show = tour;

    // 7 segment
    wire [3:0] step_t = (step >= 4'd10) ? 4'd1 : 4'd0;
    wire [3:0] step_o = (step >= 4'd10) ? step - 4'd10 : step;
    assign sg3 = `SG_T;
    assign sg2 = `SG_BLANK;
    assign sg1 = {1'b0, step_t};
    assign sg0 = {1'b0, step_o};
    assign dp = 4'b0000;

    // Step logic
    wire jb_ready = (jb_state == `CH_READY);
    wire jc_ready = (jc_state == `CH_READY);
    wire both_empty = (jb_state == `CH_EMPTY) && (jc_state == `CH_EMPTY);

    // move to the next step
    task go_next;
        begin
            step <= step + 4'd1;
            timer <= 10'd0;
        end
    endtask

    always @(posedge clk) begin
        want_release <= 1'b0;
        want_drain <= 1'b0;
        clear_lab <= 1'b0;
        exit_req <= 1'b0;

        if (rst || enter) begin
            step <= T_WELCOME;
            timer <= 10'd0;
            saw_discard <= 1'b0;
            saw_drain <= 1'b0;
            box_hidden <= 1'b0;
            blink <= 8'd0;
            clear_lab <= enter;
        end else begin
            if (anim_tick) begin
                blink <= blink + 8'd1;
                if (timer != 10'd1023) timer <= timer + 10'd1;
            end

            // skip to the next step
            if (btn_hint && step != T_DONE) begin
                go_next;
            end else begin
                case (step)
                    // the buttons
                    T_WELCOME: if (btn_ok) go_next;
                    T_PAD: if (btn_ok) go_next;
                    T_K_OK: if (btn_ok) go_next;
                    T_K_UP: if (btn_up) go_next;
                    T_K_DOWN: if (btn_down) go_next;
                    T_K_MENU: if (btn_menu) go_next;

                    // the lab
                    T_PICK: if (jb_ready || jc_ready) go_next;

                    T_DISCARD: begin
                        if (jb_state == `CH_DISCARD || jc_state == `CH_DISCARD) saw_discard <= 1'b1;
                        if (saw_discard && both_empty) go_next;
                    end

                    T_FILL: if (jb_ready && jc_ready) go_next;

                    T_RELEASE: begin
                        if (btn_ok) want_release <= 1'b1;
                        if (released) go_next;
                    end

                    T_WATCH: if (!lab_busy && timer > 10'd240) go_next;

                    T_ORDER: if (btn_ok) go_next;

                    T_DRAIN: begin
                        if (btn_down) want_drain <= 1'b1;
                        if (ja_draining) saw_drain <= 1'b1;
                        if ((saw_drain && !ja_draining) || (btn_down && ja_count == 13'd0)) begin
                            go_next;
                            box_hidden <= 1'b0;
                        end
                    end

                    T_RECIPE: begin
                        if (btn_ok) want_release <= 1'b1;
                        if (btn_down) want_drain <= 1'b1;
                        if (released) box_hidden <= 1'b1;
                        if (rxn_seen && rxn_seen_id == `RX_OBSIDIAN) go_next;
                    end

                    T_DONE: if (btn_ok) exit_req <= 1'b1;

                    default: ;
                endcase
            end
        end
    end

    // What to show
    // colours
    localparam [15:0] C_GOLD = {5'd31, 6'd48, 5'd4};
    localparam [15:0] C_WHITE = {5'd31, 6'd63, 5'd31};

    always @* begin
        header_str = "TUTORIAL  ";
        header_col = C_GOLD;
        msg_show = 1'b1;
        msg0 = "          "; msg1 = "          "; msg2 = "          "; msg3 = "          ";
        hint_jb = 6'd0;
        hint_jc = 6'd0;
        pad_hi = PAD_NONE;

        // Instructions
        if (step >= T_K_OK && step <= T_K_HINT) begin
            header_str = "PRESS IT! ";
            header_col = blink[4] ? C_WHITE : C_GOLD;
        end

        case (step)
            T_WELCOME: begin
                header_str = "C = NEXT  ";
                msg0 = "WELCOME   "; msg1 = "TO THE    "; msg2 = "LAB!      "; msg3 = "C = NEXT  ";
            end
            T_PAD: begin
                header_str = "C = NEXT  ";
                msg0 = "CONTROLS  "; msg1 = "5 BUTTONS "; msg2 = "LETS TRY  "; msg3 = "EACH ONE  ";
            end
            T_K_OK: begin
                pad_hi = PAD_OK;
                msg0 = "OK BUTTON "; msg1 = "SELECTS + "; msg2 = "RELEASES  "; msg3 = "INTO JA   ";
            end
            T_K_UP: begin
                pad_hi = PAD_UP;
                msg0 = "UP BUTTON "; msg1 = "MOVES UP  "; msg2 = "IN LAB:   "; msg3 = "SLOW-MO   ";
            end
            T_K_DOWN: begin
                pad_hi = PAD_DOWN;
                msg0 = "DOWN BTN  "; msg1 = "GOES DOWN "; msg2 = "IN LAB:   "; msg3 = "DRAINS JA ";
            end
            T_K_MENU: begin
                pad_hi = PAD_MENU;
                msg0 = "MENU BTN  "; msg1 = "PAUSE,    "; msg2 = "RESTART   "; msg3 = "OR QUIT   ";
            end
            T_K_HINT: begin
                pad_hi = PAD_HINT;
                msg0 = "HINT BTN  "; msg1 = "HINTS, OR "; msg2 = "SKIPS A   "; msg3 = "TUT STEP  ";
            end
            T_PICK: begin
                msg0 = "STEP 1/7  "; msg1 = "PICK A    "; msg2 = "MATERIAL  "; msg3 = "LEFT SIDE ";
                hint_jb = 6'b111111;
            end
            T_DISCARD: begin
                msg0 = "STEP 2/7  "; msg1 = "FLIP IT   "; msg2 = "DOWN TO   "; msg3 = "DISCARD   ";
            end
            T_FILL: begin
                msg0 = "STEP 3/7  "; msg1 = "FILL LEFT "; msg2 = "AND RIGHT "; msg3 = "CHAMBERS  ";
                if (jb_state == `CH_EMPTY) hint_jb = 6'b111111;
                if (jc_state == `CH_EMPTY) hint_jc = 6'b111111;
            end
            T_RELEASE: begin
                msg0 = "STEP 4/7  "; msg1 = "PRESS OK  "; msg2 = "TO POUR   "; msg3 = "INTO JA   ";
            end
            T_WATCH: begin
                // no box in the way, slow motion
                msg_show = 1'b0;
                header_str = blink[6] ? "^ = SLOWMO" : "WATCH IT! ";
                header_col = blink[6] ? {5'd6, 6'd52, 5'd31} : C_GOLD;
            end
            T_ORDER: begin
                header_str = "C = NEXT  ";
                msg0 = "STEP 5/7  "; msg1 = "ORDER     "; msg2 = "MATTERS!  ";
                msg3 = blink[7] ? "NEW THING " : "SWAP THEM ";
            end
            T_DRAIN: begin
                msg0 = "STEP 6/7  "; msg1 = "PUSH DOWN "; msg2 = "TO DRAIN  "; msg3 = "BEAKER    ";
                msg_show = !ja_draining;
            end
            T_RECIPE: begin
                msg0 = "STEP 7/7  "; msg1 = "WATER 1ST "; msg2 = "THEN LAVA "; msg3 = "=OBSIDIAN ";
                msg_show = !box_hidden;
                hint_jb = 6'b000001; // water
                hint_jc = 6'b000100; // lava
                header_str = blink[7] ? "~ = DRAIN " : "WATER>LAVA";
            end
            T_DONE: begin
                header_str = "C = TITLE ";
                msg0 = "AMAZING!  "; msg1 = "YOU'RE A  "; msg2 = "LAB PRO!  "; msg3 = "C = TITLE ";
            end
            default: ;
        endcase
    end

endmodule
