// AI-assisted coding-strand codon explorer. No protein sequence accumulation.
module gfx_dna_explorer(input wire [5:0] codon,
 output wire [79:0] line0, line1, line2, line3);
 wire [7:0] amino; wire stop;
 dna_codon_decode lookup(.codon(codon),.amino(amino),.stop(stop));
 function [7:0] base;
 input [1:0] b; input rna;
 begin case(b)
 0: base=rna ? "U" : "T";
 1: base="C"; 2: base="A"; 3: base="G";
 endcase end
 endfunction
 assign line0={"DNA ",base(codon[5:4],0),base(codon[3:2],0),base(codon[1:0],0),"   "};
 assign line1={"RNA ",base(codon[5:4],1),base(codon[3:2],1),base(codon[1:0],1),"   "};
 assign line2=stop ? "STOP      " : {"AMINO ",amino,"   "};
 assign line3=(codon==6'd35) ? "AUG START " : "SW5..0 SET";
endmodule
