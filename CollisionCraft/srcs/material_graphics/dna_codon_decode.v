// AI-assisted teaching lookup; standard code, NCBI table 1.
// Standard genetic code, NCBI table 1. Encoding T=0 C=1 A=2 G=3.
// Input is a coding-strand DNA triplet in 5-prime to 3-prime order.
// RNA has identical encoding, with U displayed instead of T.
module dna_codon_decode(input wire [5:0] codon, output reg [7:0] amino, output wire stop);
always @(codon) begin
 case(codon)
 6'd0: amino = 8'd70;
 6'd1: amino = 8'd70;
 6'd2: amino = 8'd76;
 6'd3: amino = 8'd76;
 6'd4: amino = 8'd83;
 6'd5: amino = 8'd83;
 6'd6: amino = 8'd83;
 6'd7: amino = 8'd83;
 6'd8: amino = 8'd89;
 6'd9: amino = 8'd89;
 6'd10: amino = 8'd42;
 6'd11: amino = 8'd42;
 6'd12: amino = 8'd67;
 6'd13: amino = 8'd67;
 6'd14: amino = 8'd42;
 6'd15: amino = 8'd87;
 6'd16: amino = 8'd76;
 6'd17: amino = 8'd76;
 6'd18: amino = 8'd76;
 6'd19: amino = 8'd76;
 6'd20: amino = 8'd80;
 6'd21: amino = 8'd80;
 6'd22: amino = 8'd80;
 6'd23: amino = 8'd80;
 6'd24: amino = 8'd72;
 6'd25: amino = 8'd72;
 6'd26: amino = 8'd81;
 6'd27: amino = 8'd81;
 6'd28: amino = 8'd82;
 6'd29: amino = 8'd82;
 6'd30: amino = 8'd82;
 6'd31: amino = 8'd82;
 6'd32: amino = 8'd73;
 6'd33: amino = 8'd73;
 6'd34: amino = 8'd73;
 6'd35: amino = 8'd77;
 6'd36: amino = 8'd84;
 6'd37: amino = 8'd84;
 6'd38: amino = 8'd84;
 6'd39: amino = 8'd84;
 6'd40: amino = 8'd78;
 6'd41: amino = 8'd78;
 6'd42: amino = 8'd75;
 6'd43: amino = 8'd75;
 6'd44: amino = 8'd83;
 6'd45: amino = 8'd83;
 6'd46: amino = 8'd82;
 6'd47: amino = 8'd82;
 6'd48: amino = 8'd86;
 6'd49: amino = 8'd86;
 6'd50: amino = 8'd86;
 6'd51: amino = 8'd86;
 6'd52: amino = 8'd65;
 6'd53: amino = 8'd65;
 6'd54: amino = 8'd65;
 6'd55: amino = 8'd65;
 6'd56: amino = 8'd68;
 6'd57: amino = 8'd68;
 6'd58: amino = 8'd69;
 6'd59: amino = 8'd69;
 6'd60: amino = 8'd71;
 6'd61: amino = 8'd71;
 6'd62: amino = 8'd71;
 6'd63: amino = 8'd71;
 default: amino=8'd63;
 endcase
end
assign stop = amino == 8'd42;
endmodule
