// Draws one reagent chamber (JB or JC): the name card for the chosen material, a
// short description, the funnel, the status text and the material itself. Each
// pixel is read from grid RAM, shaded, and then the UI is drawn on top.

// Owner: Zi Le (Materials, Graphics & Controls)

`include "cc_defines.vh"

module gfx_reagent_screen #(
    parameter ROTATE = 0,
    parameter MIRROR = 0
)(
    input wire clk, // 6.25 MHz
    input wire [12:0] pixel_index,
    input wire sending_pixels,
    input wire frame_begin,
    // grid RAM read port
    output reg [12:0] ram_addr,
    input wire [15:0] ram_data,
    // chamber status
    input wire [2:0] ch_state,
    input wire [5:0] ch_mat,
    input wire valve_open,
    input wire trapdoor_open,
    input wire demo, // title screen
    // to Oled_Display
    output reg [15:0] pixel_data
);

    // Status signals
    reg [2:0] st_q; reg [5:0] mat_q; reg valve_q, trap_q, demo_q;
    always @(posedge clk) begin
        st_q <= ch_state; mat_q <= ch_mat; valve_q <= valve_open;
        trap_q <= trapdoor_open; demo_q <= demo;
    end

    // Animation frame counter (60 Hz)
    reg [7:0] frame = 8'd0;
    always @(posedge clk) if (frame_begin) frame <= frame + 8'd1;

    // Name card animation
    // slide, card drops in from above the screen
    // dissolve, card crumbles away while discarding
    reg [5:0] card_mat = 6'd0;
    reg [3:0] slide = 4'd0;
    reg [3:0] dissolve = 4'd0;
    wire has_card = (st_q != `CH_EMPTY) && (mat_q != `M_EMPTY);

    always @(posedge clk) begin
        if (frame_begin) begin
            if (!has_card) begin
                slide <= 4'd0; dissolve <= 4'd0;
            end else if (mat_q != card_mat) begin
                card_mat <= mat_q; slide <= 4'd0; dissolve <= 4'd0;
            end else begin
                if (slide != 4'd15) slide <= slide + 4'd1;
                if (st_q == `CH_DISCARD) begin
                    if (dissolve != 4'd15 && frame[0]) dissolve <= dissolve + 4'd1;
                end else
                    dissolve <= 4'd0;
            end
        end
    end
    wire [3:0] offset = 4'd15 - slide;

    // Pixel being prepared
    wire advance, start;
    wire [6:0] lx, ly;
    gfx_oled_mapper #(.ROTATE(ROTATE), .MIRROR(MIRROR)) mapper (
        .clk(clk), .pixel_index(pixel_index), .sending_pixels(sending_pixels),
        .advance(advance), .start(start), .lx(lx), .ly(ly)
    );

    // Read centre cell, then the cell above
    localparam P_IDLE = 3'd0, P_RD_C = 3'd1, P_RD_U = 3'd2, P_CAP_U = 3'd3, P_MIX = 3'd4;
    reg [2:0] pstate = P_IDLE;
    reg [15:0] cell_c, cell_u;
    reg [15:0] next_pix;

    always @* begin
        case (pstate)
            P_RD_C: ram_addr = {ly, lx[5:0]};
            P_RD_U: ram_addr = (ly == 7'd0) ? 13'd0 : {ly - 7'd1, lx[5:0]};
            default: ram_addr = {ly, lx[5:0]};
        endcase
    end

    // Geometry, shading and text
    wire is_wall, in_body;
    wire [2:0] part;
    gfx_chamber_geometry #(.CHAMBER(0)) geo (
        .x(lx), .y(ly), .valve_open(valve_q), .trapdoor_open(trap_q),
        .drain_open(1'b0), .is_wall(is_wall), .part(part), .interior(in_body)
    );

    wire [15:0] mat_rgb;
    wire [1:0] mat_alpha;
    gfx_material_shader shader (
        .cell_in(cell_c), .cell_above((ly == 7'd0) ? 16'd0 : cell_u),
        .lx(lx), .ly(ly), .frame(frame), .rgb(mat_rgb), .alpha(mat_alpha)
    );

    wire [79:0] m_name, m_desc;
    wire [23:0] m_code;
    wire [15:0] m_col;
    mat_names names (.mat(card_mat), .name(m_name), .code3(m_code), .desc(m_desc), .sig_color(m_col));

    // Status line text and colour
    reg [79:0] status_str;
    reg [15:0] status_col;
    always @* begin
        status_str = "          ";
        status_col = 16'h0000;
        if (!demo_q) begin
            case (st_q)
                // Status line at most 8 characters
                `CH_POUR: begin
                    status_str = "POURING   ";
                    status_col = frame[4] ? m_col : {5'd31, 6'd63, 5'd31};
                end
                `CH_READY: begin status_str = "~READY~   ";
                                   status_col = frame[5] ? {5'd10, 6'd63, 5'd10} : {5'd4, 6'd44, 5'd4}; end
                `CH_DISCARD: begin status_str = "DUMPING   "; status_col = {5'd31, 6'd14, 5'd4}; end
                `CH_RELEASE: begin status_str = "FLOWING   "; status_col = {5'd6, 6'd52, 5'd31}; end
                `CH_SPENT: begin status_str = frame[4] ? "FLIP OFF  " : "          ";
                                   status_col = {5'd31, 6'd40, 5'd2}; end
                `CH_HOLD: begin status_str = frame[3] ? "ONE ONLY  " : "          ";
                                   status_col = {5'd31, 6'd60, 5'd4}; end
                default: ;
            endcase
        end
    end

    reg [79:0] t_str;
    reg signed [8:0] t_oy;
    reg t_big, t_en;
    reg [15:0] t_col;
    always @* begin
        t_str = "          "; t_oy = 9'sd0; t_big = 1'b0; t_en = 1'b0; t_col = 16'hFFFF;
        if (has_card && ly <= 7'd15) begin
            t_str = m_name; t_oy = 9'sd1 - $signed({5'b0, offset}); t_big = 1'b1; t_en = 1'b1;
            t_col = {5'd31, 6'd63, 5'd31};
        end else if (!has_card && ly >= 7'd3 && ly <= 7'd9) begin
            t_str = "SELECT    "; t_oy = 9'sd3; t_en = 1'b1;
            t_col = frame[5] ? {5'd24, 6'd50, 5'd26} : {5'd14, 6'd30, 5'd16};
        end else if (!has_card && ly >= 7'd11 && ly <= 7'd17) begin
            t_str = "MATERIAL  "; t_oy = 9'sd11; t_en = 1'b1;
            t_col = frame[5] ? {5'd24, 6'd50, 5'd26} : {5'd14, 6'd30, 5'd16};
        end else if (!has_card && ly >= 7'd19 && ly <= 7'd26) begin
            t_str = "~ ~ ~     "; t_oy = 9'sd19 + $signed({8'b0, frame[5]}); t_en = 1'b1;
            t_col = {5'd10, 6'd30, 5'd20};
        end else if (has_card && ly >= 7'd17 && ly <= 7'd23) begin
            t_str = m_desc; t_oy = 9'sd17; t_en = 1'b1;
            t_col = {5'd16, 6'd34, 5'd20};
        end else if (ly >= 7'd43 && ly <= 7'd49) begin
            t_str = status_str; t_oy = 9'sd43; t_en = 1'b1; t_col = status_col;
        end
    end

    wire text_on;
    gfx_text_line text (
        .px(lx), .py(ly), .ox(9'sd0), .oy(t_oy), .scale2(t_big), .centre(1'b1),
        .str(t_str), .on(text_on)
    );

    // Helpers
    // Average two RGB colours
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

    // Quarter brightness of a colour
    function [15:0] dim4;
        input [15:0] a;
        dim4 = {2'b0, a[15:13], 2'b0, a[10:7], 2'b0, a[4:2]};
    endfunction

    // For crumbling card animation
    wire [7:0] h_pix = ({1'b0, lx} * 8'd73) ^ ({1'b0, ly} * 8'd151);

    // Final composition of one pixel
    reg [15:0] bg, out;
    wire [6:0] card_y = ly + {3'b0, offset};
    wire in_card = has_card && (card_y <= 7'd15) && (lx >= 7'd1) && (lx <= 7'd62) &&
                    !((lx == 7'd1 || lx == 7'd62) && (card_y == 7'd0 || card_y == 7'd15)) &&
                    !(dissolve != 4'd0 && h_pix[3:0] < dissolve);
    wire card_edge = (lx == 7'd1) || (lx == 7'd62) || (card_y == 7'd0) || (card_y == 7'd15);

    // Trapdoor flaps
    wire flap = trap_q && (ly >= 7'd64) && (ly <= 7'd78) &&
                    ((lx == 7'd5) || (lx == 7'd6) || (lx == 7'd57) || (lx == 7'd58));

    always @* begin
        // background
        if (in_body)
            bg = (lx == 7'd9 || lx == 7'd10) ? {5'd3, 6'd9, 5'd8} : {5'd1, 6'd4, 5'd5};
        else
            bg = {5'd0, 6'd1, 5'd2};

        // material on top of background
        case (mat_alpha)
            2'd3: out = mat_rgb;
            2'd1: out = blend(mat_rgb, bg);
            default: out = bg;
        endcase

        // glass
        if (is_wall) begin
            case (part)
                3'd1: out = (lx == 7'd5 || lx == 7'd58) ? {5'd18, 6'd46, 5'd28} : {5'd9, 6'd26, 5'd18};
                3'd2: out = {5'd12, 6'd34, 5'd24};
                3'd3: out = {5'd10, 6'd24, 5'd16};
                3'd4: out = {5'd24, 6'd10, 5'd6}; // closed valve: dull red
                3'd5: out = (ly <= 7'd89) ? (valve_q ? {5'd4, 6'd54, 5'd8} : {5'd28, 6'd6, 5'd4})
                                          : {5'd8, 6'd20, 5'd14};
                default: out = {5'd9, 6'd26, 5'd18};
            endcase
        end
        if (flap) out = {5'd12, 6'd28, 5'd18}; // trapdoor flaps hanging open

        // name
        if (in_card)
            out = card_edge ? m_col : blend(dim4(m_col), {5'd1, 6'd2, 5'd3});

        // text on top
        if (t_en && text_on) begin
            if (has_card && ly <= 7'd15)
                out = (dissolve != 4'd0 && h_pix[3:0] < dissolve) ? out : blend(t_col, m_col);
            else
                out = t_col;
        end
    end

    // Run the pipeline
    always @(posedge clk) begin
        // the OLED has moved on: hand over the pixel we prepared
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
