`timescale 1ns/1ps
module tb_dna_explorer;
reg [5:0] codon;
wire [79:0] a,b,c,d;
reg [511:0] expected;
reg [7:0] aa;
integer i;
gfx_dna_explorer dut(codon,a,b,c,d);
initial begin
// NCBI table 1 in T,C,A,G order for each base.
expected="FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG";
for(i=0;i<64;i=i+1) begin
 codon=i; #1; aa=expected[511-8*i -: 8];
 if(aa=="*") begin
  if(c!=="STOP      ") $fatal(1,"Missing stop %0d",i);
 end else if(c!=={"AMINO ",aa,"   "}) $fatal(1,"Wrong amino %0d",i);
end
codon=35; #1;
if(a!=="DNA ATG   " || b!=="RNA AUG   " || d!=="AUG START ") $fatal(1,"ATG example");
codon=0; #1;
if(a!=="DNA TTT   " || b!=="RNA UUU   ") $fatal(1,"TTT example");
$display("PASS: all 64 codon outcomes and DNA/RNA examples"); $finish;
end
endmodule
