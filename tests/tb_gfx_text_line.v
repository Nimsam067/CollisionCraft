`timescale 1ns/1ps
module tb_gfx_text_line;
  reg [6:0] px, py;
  reg signed [8:0] ox, oy;
  reg scale2, centre;
  reg [79:0] str;
  wire on;
  gfx_text_line dut(.px(px), .py(py), .ox(ox), .oy(oy), .scale2(scale2), .centre(centre), .str(str), .on(on));
  reg [34:0] glyph;
  integer n, s, x, y, x0, dx, dy, pitch, width, col, row, expected, errors;
  task check_case;
    input integer count;
    input integer big;
    input integer centered;
    begin
      str = "          ";
      for (n=0; n<count; n=n+1) str[79-8*n -: 8] = "A";
      scale2=big; centre=centered; ox=3; oy=4;
      pitch=big ? 12 : 6;
      width=count ? count*pitch-(big ? 2 : 1) : 0;
      x0=centered ? ((64-width) >>> 1) : 3;
      for (y=0; y<20; y=y+1) begin
        for (x=0; x<64; x=x+1) begin
          px=x; py=y; #1;
          dx=x-x0; dy=y-4; expected=0;
          if (dx>=0 && dx<count*pitch && dy>=0 && dy<(big ? 14 : 7)) begin
            col=(dx%pitch)/(big ? 2 : 1); row=dy/(big ? 2 : 1);
            if (col<5) expected=glyph[34-(row*5+col)];
          end
          if (on !== expected[0]) begin
            if (errors<8) $display("FAIL count=%0d big=%0d center=%0d x=%0d y=%0d got=%b want=%0d",count,big,centered,x,y,on,expected);
            errors=errors+1;
          end
        end
      end
    end
  endtask
  initial begin
    glyph=35'b01110100011000111111100011000110001; errors=0;
    check_case(0,0,1); check_case(1,0,1); check_case(5,1,1);
    check_case(6,1,1); check_case(10,1,1); check_case(3,0,0); check_case(3,1,0);
    if (errors) $fatal(1,"%0d text pixels incorrect",errors);
    $display("PASS: blank, centred, clipped, and positioned text at both scales"); $finish;
  end
endmodule
