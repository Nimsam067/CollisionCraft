// Draws the JA screen. In the lab this is the beaker, the two funnels, the
// recipe header, the fill gauge and the reaction banner. It also draws the title
// screen and its menu, the pause menu, the message box for tutorial and
// challenge text, the button picture for the tutorial, and the white flash for
// explosions.

// Owner: Zi Le (Materials, Graphics & Controls)

`include "cc_defines.vh"

module gfx_reaction_screen #(
    parameter ROTATE = 1,
    parameter MIRROR = 0
)(
    input wire clk, // 6.25 MHz
    input wire [12:0] pixel_index,
    input wire sending_pixels,
    input wire frame_begin,
    // grid RAM read port
    output reg [12:0] ram_addr,
    input wire [15:0] ram_data,
    input wire title_view,
    input wire [1:0] menu_sel,
    input wire [79:0] header_str,
    input wire [15:0] header_col,
    input wire msg_show,
    input wire [79:0] msg0,
    input wire [79:0] msg1,
    input wire [79:0] msg2,
    input wire [79:0] msg3,
    input wire banner_show,
    input wire [79:0] banner_str,
    input wire banner_new,
    input wire [15:0] banner_col,
    input wire [3:0] flash,
    input wire [6:0] fill_rows,
    input wire drain_open,
    input wire pause_show, // pause popup
    input wire [1:0] pause_sel, // 0 RESUME, 1 RESTART, 2 QUIT
    input wire pad_show, // five button picture
    input wire [2:0] pad_hi, // 0 none, 1 OK, 2 UP, 3 DOWN, 4 MENU, 5 HINT
    // to Oled_Display
    output reg [15:0] pixel_data
);

    // UI Signals
    reg title_q, msg_q, ban_q, new_q, drain_q;
    reg [1:0] sel_q;
    reg [79:0] hdr_q, m0_q, m1_q, m2_q, m3_q, ban_str_q;
    reg [15:0] hcol_q, bcol_q;
    reg [3:0] flash_q;
    reg [6:0] fill_q;
    reg pause_q, pad_q;
    reg [1:0] psel_q;
    reg [2:0] padhi_q;
    always @(posedge clk) begin
        pause_q <= pause_show; psel_q <= pause_sel; pad_q <= pad_show; padhi_q <= pad_hi;
        title_q <= title_view; sel_q <= menu_sel; hdr_q <= header_str; hcol_q <= header_col;
        msg_q <= msg_show; m0_q <= msg0; m1_q <= msg1; m2_q <= msg2; m3_q <= msg3;
        ban_q <= banner_show; ban_str_q <= banner_str; new_q <= banner_new; bcol_q <= banner_col;
        flash_q <= flash; fill_q <= fill_rows; drain_q <= drain_open;
    end

    // Frame counter and open animation
    reg [7:0] frame = 8'd0;
    reg [3:0] ban_age = 4'd0;
    reg [79:0] ban_last = 80'd0;
    always @(posedge clk) begin
        if (frame_begin) begin
            frame <= frame + 8'd1;
            if (!ban_q || ban_str_q != ban_last) begin
                ban_age <= 4'd0;
                ban_last <= ban_str_q;
            end else if (ban_age != 4'd15)
                ban_age <= ban_age + 4'd1;
        end
    end

    wire [5:0] ban_half = (ban_age >= 4'd8) ? 6'd31 : {ban_age, 2'b00};

    // Pixel addressing
    wire advance, start;
    wire [6:0] lx, ly;
    gfx_oled_mapper #(.ROTATE(ROTATE), .MIRROR(MIRROR)) mapper (
        .clk(clk), .pixel_index(pixel_index), .sending_pixels(sending_pixels),
        .advance(advance), .start(start), .lx(lx), .ly(ly)
    );

    localparam P_IDLE = 3'd0, P_RD_C = 3'd1, P_RD_U = 3'd2, P_CAP_U = 3'd3, P_MIX = 3'd4;
    reg [2:0] pstate = P_IDLE;
    reg [15:0] cell_c, cell_u, next_pix;

    always @* begin
        case (pstate)
            P_RD_U: ram_addr = (ly == 7'd0) ? 13'd0 : {ly - 7'd1, lx[5:0]};
            default: ram_addr = {ly, lx[5:0]};
        endcase
    end

    // Geometry and material colour
    wire is_wall;
    wire [2:0] part;
    gfx_chamber_geometry #(.CHAMBER(1)) geo (
        .x(lx), .y(ly), .valve_open(1'b0), .trapdoor_open(1'b0),
        .drain_open(drain_q), .is_wall(is_wall), .part(part), .interior()
    );

    wire [15:0] mat_rgb;
    wire [1:0] mat_alpha;
    gfx_material_shader shader (
        .cell_in(cell_c), .cell_above((ly == 7'd0) ? 16'd0 : cell_u),
        .lx(lx), .ly(ly), .frame(frame), .rgb(mat_rgb), .alpha(mat_alpha)
    );

    // Header, message box, title, menu
    // Menu item rows
    localparam [6:0] MENU_Y0 = 7'd46, MENU_Y1 = 7'd58, MENU_Y2 = 7'd70;
    wire pause_on = pause_q && !title_q;
    wire [1:0] bar_sel = pause_on ? psel_q : sel_q;
    wire [6:0] sel_y = (bar_sel == 2'd0) ? MENU_Y0 : (bar_sel == 2'd1) ? MENU_Y1 : MENU_Y2;

    reg [79:0] a_str;
    reg signed [8:0] a_oy;
    reg a_big, a_en;
    reg [15:0] a_col;
    reg [2:0] a_kind;
    always @* begin
        a_str = "          "; a_oy = 9'sd0; a_big = 1'b0; a_en = 1'b0;
        a_col = {5'd31, 6'd63, 5'd31}; a_kind = 3'd0;
        if (title_q) begin
            if (ly >= 7'd6 && ly <= 7'd12) begin
                a_str = "COLLISION "; a_oy = 9'sd6; a_en = 1'b1; a_kind = 3'd1;
            end else if (ly >= 7'd16 && ly <= 7'd29) begin
                a_str = "CRAFT     "; a_oy = 9'sd16; a_big = 1'b1; a_en = 1'b1; a_kind = 3'd2;
            end else if (ly >= 7'd34 && ly <= 7'd40) begin
                a_str = "* LAB *   "; a_oy = 9'sd34; a_en = 1'b1; a_col = {5'd10, 6'd24, 5'd16};
            end else if (ly >= MENU_Y0 && ly <= MENU_Y0 + 7'd6) begin
                a_str = "TUTORIAL  "; a_oy = $signed({2'b0, MENU_Y0}); a_en = 1'b1;
                a_col = (sel_q == 2'd0) ? {5'd31, 6'd63, 5'd31} : {5'd12, 6'd26, 5'd16};
            end else if (ly >= MENU_Y1 && ly <= MENU_Y1 + 7'd6) begin
                a_str = "FREE PLAY "; a_oy = $signed({2'b0, MENU_Y1}); a_en = 1'b1;
                a_col = (sel_q == 2'd1) ? {5'd31, 6'd63, 5'd31} : {5'd12, 6'd26, 5'd16};
            end else if (ly >= MENU_Y2 && ly <= MENU_Y2 + 7'd6) begin
                a_str = "CHALLENGE "; a_oy = $signed({2'b0, MENU_Y2}); a_en = 1'b1;
                a_col = (sel_q == 2'd2) ? {5'd31, 6'd63, 5'd31} : {5'd12, 6'd26, 5'd16};
            end else if (ly >= 7'd86 && ly <= 7'd92) begin
                a_str = "C = START "; a_oy = 9'sd86; a_en = frame[5];
                a_col = {5'd14, 6'd32, 5'd20};
            end
        end else if (pause_on) begin
            // pause popup
            if (ly >= 7'd1 && ly <= 7'd7) begin
                a_str = hdr_q; a_oy = 9'sd1; a_en = 1'b1; a_col = hcol_q;
            end else if (ly >= 7'd32 && ly <= 7'd38) begin
                a_str = "PAUSED    "; a_oy = 9'sd32; a_en = 1'b1; a_col = {5'd31, 6'd52, 5'd8};
            end else if (ly >= MENU_Y0 && ly <= MENU_Y0 + 7'd6) begin
                a_str = "RESUME    "; a_oy = $signed({2'b0, MENU_Y0}); a_en = 1'b1;
                a_col = (psel_q == 2'd0) ? {5'd31, 6'd63, 5'd31} : {5'd12, 6'd26, 5'd16};
            end else if (ly >= MENU_Y1 && ly <= MENU_Y1 + 7'd6) begin
                a_str = "RESTART   "; a_oy = $signed({2'b0, MENU_Y1}); a_en = 1'b1;
                a_col = (psel_q == 2'd1) ? {5'd31, 6'd63, 5'd31} : {5'd12, 6'd26, 5'd16};
            end else if (ly >= MENU_Y2 && ly <= MENU_Y2 + 7'd6) begin
                a_str = "QUIT      "; a_oy = $signed({2'b0, MENU_Y2}); a_en = 1'b1;
                a_col = (psel_q == 2'd2) ? {5'd31, 6'd63, 5'd31} : {5'd12, 6'd26, 5'd16};
            end else if (ly >= 7'd82 && ly <= 7'd88) begin
                a_str = "< RESUME  "; a_oy = 9'sd82; a_en = 1'b1; a_col = {5'd14, 6'd32, 5'd20};
            end
        end else begin
            if (ly >= 7'd1 && ly <= 7'd7) begin
                a_str = hdr_q; a_oy = 9'sd1; a_en = 1'b1; a_col = hcol_q;
            end else if (msg_q && ly >= 7'd30 && ly <= 7'd36) begin
                a_str = m0_q; a_oy = 9'sd30; a_en = 1'b1; a_col = {5'd31, 6'd52, 5'd8};
            end else if (msg_q && ly >= 7'd38 && ly <= 7'd44) begin
                a_str = m1_q; a_oy = 9'sd38; a_en = 1'b1;
            end else if (msg_q && ly >= 7'd46 && ly <= 7'd52) begin
                a_str = m2_q; a_oy = 9'sd46; a_en = 1'b1;
            end else if (msg_q && ly >= 7'd54 && ly <= 7'd60) begin
                a_str = m3_q; a_oy = 9'sd54; a_en = 1'b1; a_col = {5'd16, 6'd44, 5'd31};
            end
        end
    end

    wire a_on;
    gfx_text_line text_a (
        .px(lx), .py(ly), .ox(9'sd0), .oy(a_oy), .scale2(a_big), .centre(1'b1),
        .str(a_str), .on(a_on)
    );

    // Reaction banner
    reg [79:0] b_str;
    reg signed [8:0] b_oy;
    reg b_en;
    reg [15:0] b_col;
    always @* begin
        b_str = "          "; b_oy = 9'sd0; b_en = 1'b0; b_col = bcol_q;
        if (!title_q && !pause_on && ban_q && ban_age >= 4'd6) begin
            if (new_q && ly >= 7'd38 && ly <= 7'd44) begin
                b_str = "NEW!      "; b_oy = 9'sd38; b_en = 1'b1;
                b_col = frame[3] ? {5'd31, 6'd60, 5'd4} : {5'd31, 6'd40, 5'd0};
            end else if (ly >= 7'd50 && ly <= 7'd56) begin
                b_str = ban_str_q; b_oy = 9'sd50; b_en = 1'b1; b_col = {5'd31, 6'd63, 5'd31};
            end
        end
    end

    wire b_on;
    gfx_text_line text_b (
        .px(lx), .py(ly), .ox(9'sd0), .oy(b_oy), .scale2(1'b0), .centre(1'b1),
        .str(b_str), .on(b_on)
    );

    // Five button picture in tutorial
    reg [79:0] p_str;
    reg signed [8:0] p_ox, p_oy;
    reg [2:0] p_key;
    always @* begin
        p_str = "          "; p_ox = 9'sd0; p_oy = 9'sd0; p_key = 3'd0;
        if (ly >= 7'd64 && ly <= 7'd73) begin
            if (lx >= 7'd26 && lx <= 7'd38) begin p_key = 3'd2; p_str = "UP        "; p_ox = 9'sd27; p_oy = 9'sd65; end
        end else if (ly >= 7'd75 && ly <= 7'd84) begin
            if (lx <= 7'd24) begin p_key = 3'd4; p_str = "MENU      "; p_ox = 9'sd1; p_oy = 9'sd76; end
            else if (lx >= 7'd26 && lx <= 7'd38) begin p_key = 3'd1; p_str = "OK        "; p_ox = 9'sd27; p_oy = 9'sd76; end
            else if (lx >= 7'd40) begin p_key = 3'd5; p_str = "HINT      "; p_ox = 9'sd41; p_oy = 9'sd76; end
        end else if (ly >= 7'd86) begin
            if (lx >= 7'd20 && lx <= 7'd44) begin p_key = 3'd3; p_str = "DOWN      "; p_ox = 9'sd21; p_oy = 9'sd87; end
        end
    end

    wire p_on;
    gfx_text_line text_p (
        .px(lx), .py(ly), .ox(p_ox), .oy(p_oy), .scale2(1'b0), .centre(1'b0),
        .str(p_str), .on(p_on)
    );

    wire pad_here = pad_q && !title_q && !pause_on && (p_key != 3'd0);
    wire pad_lit = (p_key == padhi_q); // the button being taught

    // Helpers
    function [15:0] blend;
        input [15:0] a, b;
        reg [5:0] sr;
        reg [6:0] sg;
        reg [5:0] sb;
        begin
            sr = a[15:11] + b[15:11];
            sg = a[10:5] + b[10:5];
            sb = a[4:0] + b[4:0];
            blend = {sr[5:1], sg[6:1], sb[5:1]};
        end
    endfunction

    function [15:0] dim2; // half brightness
        input [15:0] a;
        dim2 = {1'b0, a[15:12], 1'b0, a[10:6], 1'b0, a[4:1]};
    endfunction

    function [15:0] add_flash;
        input [15:0] a;
        input [3:0] lvl;
        reg [6:0] r, g, b;
        begin
            r = a[15:11] + {lvl, 1'b0};
            g = a[10:5] + {lvl, 2'b0};
            b = a[4:0] + {lvl, 1'b0};
            add_flash = {(r > 7'd31) ? 5'd31 : r[4:0],
                         (g > 7'd63) ? 6'd63 : g[5:0],
                         (b > 7'd31) ? 5'd31 : b[4:0]};
        end
    endfunction

    // Collision logo gradient
    reg [15:0] rainbow;
    always @* begin
        case (((lx >> 3) + {4'b0, frame[6:4]}) & 7'd3)
            7'd0: rainbow = {5'd6, 6'd52, 5'd31};
            7'd1: rainbow = {5'd10, 6'd30, 5'd31};
            7'd2: rainbow = {5'd22, 6'd22, 5'd31};
            default: rainbow = {5'd30, 6'd18, 5'd26};
        endcase
    end
    // Craft logo gradient
    wire [6:0] craft_row = ly - 7'd16;
    wire [5:0] craft_g = 6'd60 - {craft_row[4:0], 2'b0};
    wire shimmer = (((lx - ly + {frame, 1'b0}) & 7'd63) < 7'd4);

    // Final
    wire in_beaker = (lx >= 7'd4) && (lx <= 7'd59) && (ly >= 7'd26) && (ly <= 7'd91);
    wire [6:0] depth = 7'd91 - ly; // 0 at the floor
    wire tick_row = (depth[2:0] == 3'd0) && (depth != 7'd0) && (ly > 7'd27);
    wire in_gauge = (lx >= 7'd62) && (ly >= 7'd26) && (ly <= 7'd91);

    // Text fit, text never touches or crosses a border
    wire in_msgbox = msg_q && !title_q && (lx >= 7'd1) && (lx <= 7'd62) && (ly >= 7'd27) && (ly <= 7'd63);
    wire msg_border = (lx == 7'd1) || (lx == 7'd62) || (ly == 7'd27) || (ly == 7'd63);
    wire [6:0] bx_lo = 7'd32 - {1'b0, ban_half};
    wire [6:0] bx_hi = 7'd31 + {1'b0, ban_half};
    wire in_banner = ban_q && !title_q && (lx >= bx_lo) && (lx <= bx_hi) && (ly >= 7'd46) && (ly <= 7'd60);
    wire ban_border = (lx == bx_lo) || (lx == bx_hi) || (ly == 7'd46) || (ly == 7'd60);
    wire in_newtag = ban_q && new_q && !title_q && ban_age >= 4'd6 &&
                       (lx >= 7'd18) && (lx <= 7'd45) && (ly >= 7'd36) && (ly <= 7'd46);
    wire in_pausebox = pause_on && (lx >= 7'd4) && (lx <= 7'd59) && (ly >= 7'd27) && (ly <= 7'd91);
    wire pause_edge = (lx == 7'd4) || (lx == 7'd59) || (ly == 7'd27) || (ly == 7'd91);
    // highlight bar
    wire [6:0] bar_l = pause_on ? 7'd6 : 7'd3;
    wire [6:0] bar_r = pause_on ? 7'd57 : 7'd60;
    wire in_menubar = (title_q || pause_on) && (lx >= bar_l) && (lx <= bar_r) &&
                       (ly + 7'd3 >= sel_y) && (ly <= sel_y + 7'd9);
    wire menubar_edge= (lx == bar_l) || (lx == bar_r) || (ly + 7'd3 == sel_y) || (ly == sel_y + 7'd9);
    // little blinking arrow pointing at the selected item
    wire [6:0] arrow_x0 = pause_on ? 7'd7 : 7'd0;
    wire [6:0] arrow_dy = (ly > sel_y + 7'd3) ? (ly - sel_y - 7'd3) : (sel_y + 7'd3 - ly);
    wire menu_arrow = (title_q || pause_on) && frame[4] && (lx >= arrow_x0) && (lx <= arrow_x0 + 7'd2) &&
                       (arrow_dy <= (arrow_x0 + 7'd2 - lx));

    reg [15:0] bg, out;
    always @* begin
        // background
        if (in_beaker)
            bg = (lx == 7'd7 || lx == 7'd8) ? {5'd3, 6'd9, 5'd8} : {5'd1, 6'd4, 5'd5};
        else if (ly <= 7'd8)
            bg = {5'd0, 6'd0, 5'd3};
        else
            bg = {5'd0, 6'd1, 5'd2};

        // beaker details
        if (in_beaker && tick_row && (lx <= 7'd6))
            bg = {5'd12, 6'd30, 5'd20};

        // material
        case (mat_alpha)
            2'd3: out = mat_rgb;
            2'd1: out = blend(mat_rgb, bg);
            default: out = bg;
        endcase

        // glassware
        if (is_wall) begin
            case (part)
                3'd1: out = (lx == 7'd3 || lx == 7'd60) ? {5'd18, 6'd46, 5'd28} : {5'd9, 6'd26, 5'd18};
                3'd2: out = {5'd12, 6'd34, 5'd24};
                3'd3: out = {5'd10, 6'd24, 5'd16};
                3'd5: out = drain_q ? {5'd4, 6'd54, 5'd8} : {5'd28, 6'd6, 5'd4};
                3'd6: out = {5'd10, 6'd24, 5'd16}; // beaker floor
                3'd7: out = {5'd24, 6'd56, 5'd30};
                default: out = {5'd9, 6'd26, 5'd18};
            endcase
        end

        // fill gauge on the right edge
        if (in_gauge && !title_q) begin
            if (depth < fill_q)
                out = (depth < 7'd33) ? {5'd6, 6'd50, 5'd8} :
                      (depth < 7'd50) ? {5'd28, 6'd52, 5'd4} : {5'd30, 6'd12, 5'd4};
            else
                out = {5'd2, 6'd6, 5'd4};
        end

        // title screen dims the simulation so the logo stands out
        if (title_q) out = dim2(out);

        // pause dims everything, the popup box comes
        if (pause_on) out = dim2(out);
        if (in_pausebox)
            out = pause_edge ? {5'd31, 6'd44, 5'd4} : blend({5'd1, 6'd3, 5'd8}, dim2(out));

        if (in_menubar)
            out = menubar_edge ? {5'd6, 6'd40, 5'd30} : {5'd2, 6'd14, 5'd12};
        if (menu_arrow) out = {5'd31, 6'd52, 5'd8};

        // message box
        if (in_msgbox)
            out = msg_border ? {5'd10, 6'd36, 5'd28} : blend({5'd1, 6'd3, 5'd8}, dim2(out));

        // text layer A
        if (a_en && a_on) begin
            case (a_kind)
                3'd1: out = rainbow;
                3'd2: out = shimmer ? {5'd31, 6'd63, 5'd28} : {5'd31, craft_g, 5'd2};
                default: out = a_col;
            endcase
        end

        // banner box, NEW! tag and banner text
        if (in_newtag && !pause_on)
            out = {5'd10, 6'd8, 5'd0};
        if (in_banner && !pause_on)
            out = ban_border ? bcol_q : blend(dim2(dim2(bcol_q)), {5'd1, 6'd2, 5'd4});
        if (b_en && b_on)
            out = b_col;

        // tutorial button picture
        if (pad_here) begin
            if (pad_lit && frame[4])
                out = p_on ? {5'd2, 6'd4, 5'd2} : {5'd31, 6'd48, 5'd4}; // blinking gold
            else if (pad_lit)
                out = p_on ? {5'd31, 6'd63, 5'd31} : {5'd10, 6'd30, 5'd28}; // bright blue
            else if (padhi_q == 3'd0)
                out = p_on ? {5'd31, 6'd63, 5'd31} : {5'd4, 6'd18, 5'd16}; // overview: all lit
            else
                out = p_on ? {5'd14, 6'd32, 5'd20} : {5'd2, 6'd8, 5'd8}; // the others, dim
        end

        // explosion flash over everything
        if (flash_q != 4'd0)
            out = add_flash(out, flash_q);
    end

    // Run it
    always @(posedge clk) begin
        if (advance)
            pixel_data <= next_pix;
        case (pstate)
            P_IDLE: if (start) pstate <= P_RD_C;
            P_RD_C: pstate <= P_RD_U;
            P_RD_U: begin cell_c <= ram_data; pstate <= P_CAP_U; end
            P_CAP_U: begin cell_u <= ram_data; pstate <= P_MIX; end
            P_MIX: begin next_pix <= out; pstate <= P_IDLE; end
            default: pstate <= P_IDLE;
        endcase
    end

endmodule
