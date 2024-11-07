// Daniel Fajardo
// dfajardo@g.hmc.edu
// 11/01/2024
//

// aes
//   Top level module with SPI interface and SPI core
module aes(input  logic clk,
           input  logic sck, 
           input  logic sdi,
           output logic sdo,
           input  logic load,
           output logic done);
                    
    logic [127:0] key, plaintext, cyphertext;
            
    aes_spi spi(sck, sdi, sdo, done, key, plaintext, cyphertext);   
    aes_core core(clk, load, key, plaintext, done, cyphertext);
endmodule

// aes_spi
//   SPI interface.  Shifts in key and plaintext
//   Captures ciphertext when done, then shifts it out
//   Tricky cases to properly change sdo on negedge clk
module aes_spi(input  logic sck, 
               input  logic sdi,
               output logic sdo,
               input  logic done,
               output logic [127:0] key, plaintext,
               input  logic [127:0] cyphertext);

    logic         sdodelayed, wasdone;
    logic [127:0] cyphertextcaptured;
               
    // assert load
    // apply 256 sclks to shift in key and plaintext, starting with plaintext[127]
    // then deassert load, wait until done
    // then apply 128 sclks to shift out cyphertext, starting with cyphertext[127]
    // SPI mode is equivalent to cpol = 0, cpha = 0 since data is sampled on first edge and the first
    // edge is a rising edge (clock going from low in the idle state to high).
    always_ff @(posedge sck)
        if (!wasdone)  {cyphertextcaptured, plaintext, key} = {cyphertext, plaintext[126:0], key, sdi};
        else           {cyphertextcaptured, plaintext, key} = {cyphertextcaptured[126:0], plaintext, key, sdi}; 
    
    // sdo should change on the negative edge of sck
    always_ff @(negedge sck) begin
        wasdone = done;
        sdodelayed = cyphertextcaptured[126];
    end
    
    // when done is first asserted, shift out msb before clock edge
    assign sdo = (done & !wasdone) ? cyphertext[127] : sdodelayed;
endmodule

// aes_core
//   top level AES encryption module
//   when load is asserted, takes the current key and plaintext
//   generates cyphertext and asserts done when complete 11 cycles later
// 
//   See FIPS-197 with Nk = 4, Nb = 4, Nr = 10
//
//   The key and message are 128-bit values packed into an array of 16 bytes as
//   shown below
//        [127:120] [95:88] [63:56] [31:24]     S0,0    S0,1    S0,2    S0,3
//        [119:112] [87:80] [55:48] [23:16]     S1,0    S1,1    S1,2    S1,3
//        [111:104] [79:72] [47:40] [15:8]      S2,0    S2,1    S2,2    S2,3
//        [103:96]  [71:64] [39:32] [7:0]       S3,0    S3,1    S3,2    S3,3
//
//   Equivalently, the values are packed into four words as given
//        [127:96]  [95:64] [63:32] [31:0]      w[0]    w[1]    w[2]    w[3]
module aes_core(input  logic         clk, 
                input  logic         load,
                input  logic [127:0] key, 
                input  logic [127:0] plaintext, 
                output logic         done, 
                output logic [127:0] cyphertext);
    logic [127:0] roundkey, nextroundkey, SBin, SRin, MCin, ARKin;
    logic ARKen, SBen, SRen, MCen;

    mainfsm mainfsm(clk,load,key,plaintext,done,nextroundkey,ARKen,SBen,SRen,MCen);
    subbytes SB(state,SBen,clk,SBin);
    shiftrows SR(SBin,SRen,MCin);
    mixcolumns MC(MCin,MCen,ARKin);
    addroundkey ARK(ARKin,roundkey,ARKen,cyphertext);
    
endmodule

module mainfsm(input  logic         clk, 
                input  logic         load,
                input  logic [127:0] key,
                input  logic [127:0] plaintext,
                output logic         done,
                output logic [127:0] nextroundkey,
                output logic ARKen, SBen, SRen, MCen);
    logic [3:0] round, nextround;
    logic [3:0] cycle;

    always_ff @(posedge clk)
      if (load) begin
        roundkey <= key;
        cycle <= 0;
      end
      else if (cycle == 1) begin
        round <= nextround;
        cycle <= 0;
      end
      else begin
        cycle <= cycle + 1;
      end
    
    // key expansion logic input: key, output: roundkey
    keyexpansion KE(round,roundkey,clk,nextroundkey);

    // nextround logic
    always_comb
      case (round)
        0: begin if (cycle==0) nextround <= 0;
          else nextround <= 1; end
        1: begin if (cycle==0) nextround <= 1;
          else nextround <= 2; end
        2: begin if (cycle==0) nextround <= 2;
          else nextround <= 3; end
        3: begin if (cycle==0) nextround <= 3;
          else nextround <= 4; end
        4: begin if (cycle==0) nextround <= 4;
          else nextround <= 5; end
        5: begin if (cycle==0) nextround <= 5;
          else nextround <= 6; end
        6: begin if (cycle==0) nextround <= 6;
          else nextround <= 7; end
        7: begin if (cycle==0) nextround <= 7;
          else nextround <= 8; end
        8: begin if (cycle==0) nextround <= 8;
          else nextround <= 9; end
        9: begin if (cycle==0) nextround <= 9;
          else nextround <= 10; end
        10: begin if (cycle==0) nextround <= 10;
          else nextround <= 0; end
        default: nextround <= 0;
      endcase
    

    // enable output logic
    always_comb
      case (round)
        0: begin ARKen <= 1; SBen <= 0; SRen <= 0; MCen <= 0; end // only ARK is enabled
        1: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end // all are enabled for rounds 1-9
        2: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        3: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        4: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        5: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        6: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        7: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        8: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        9: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 1; end
        10: begin ARKen <= 1; SBen <= 1; SRen <= 1; MCen <= 0; end // all but MC are enabled
        default: begin ARKen <= 0; SBen <= 0; SRen <= 0; MCen <= 0; end // none are enabled
      endcase

    // roundkey and cyphertext output logic
    /*always_comb
      case (round)
        0: cyphertext <= plaintext; // in first round, initial plaintext is output
        1: 
        2:
        3:
        4:
        5:
        6:
        7:
        8:
        9:
        10:
        default:
      endcase*/
endmodule

module keyexpansion(input logic [3:0] round,
                    input logic [127:0] roundkey,
                    input logic clk,
                    output logic [127:0] nextroundkey);
    logic [3:0] prevround;
    logic [31:0] temp, rwout, swin, swout, Rcon;
    logic [127:0] tempkey;

    assign prevround = 0;
    
    rotword rw(roundkey[31:0],rwout[31:0]); // rotate, subword, XOR with Rcon only done to w(i/Nk)
    assign swin = rwout;
    subword sw(swin[31:0],clk,swout[31:0]);
    
    always_comb
      case (round)
        // Round constants
        0: Rcon <= 32'h00000000;
        1: Rcon <= 32'h01000000;
        2: Rcon <= 32'h02000000;
        3: Rcon <= 32'h04000000;
        4: Rcon <= 32'h08000000;
        5: Rcon <= 32'h10000000;
        6: Rcon <= 32'h20000000;
        7: Rcon <= 32'h40000000;
        8: Rcon <= 32'h80000000;
        9: Rcon <= 32'h1b000000;
        10: Rcon <= 32'h36000000;
        default: Rcon <= 32'h00000000;
      endcase

    always_comb begin
      temp[31:0] = swout[31:0] ^ Rcon;
      tempkey[127:96] = temp[31:0] ^ roundkey[127:96];
      tempkey[95:64] = tempkey[127:96] ^ roundkey[95:64];
      tempkey[63:32] = tempkey[95:64] ^ roundkey[63:32];
      tempkey[31:0] = tempkey[63:32] ^ roundkey[31:0];
    end

    always_ff @(posedge clk) begin
      if (round!=prevround) nextroundkey = tempkey;
      else nextroundkey = roundkey;
    end
    

    /*always_comb begin
      if (round==prevround) begin
        temp[31:0] = swout[31:0] ^ Rcon;
        nextroundkey[127:96] = temp[31:0] ^ roundkey[127:96];
        nextroundkey[95:64] = nextroundkey[127:96] ^ roundkey[95:64];
        nextroundkey[63:32] = nextroundkey[95:64] ^ roundkey[63:32];
        nextroundkey[31:0] = nextroundkey[63:32] ^ roundkey[31:0];
        prevround = round;
      end
      else if (round!=prevround) begin
        nextroundkey = roundkey;
        prevround = round;
      end
      else begin
        nextroundkey = roundkey; // do not update roundkey
        prevround = 15;
      end
    end*/
    
endmodule

// sbox
//   Infamous AES byte substitutions with magic numbers
//   Combinational version which is mapped to LUTs (logic cells)
//   Section 5.1.1, Figure 7
module sbox(input  logic [7:0] a,
            output logic [7:0] y);
            
    // sbox implemented as a ROM
    // This module is combinational and will be inferred using LUTs (logic cells)
    logic [7:0] sbox[0:255];

    initial   $readmemh("sbox.txt", sbox);
    assign y = sbox[a];
endmodule

// sbox
//   Infamous AES byte substitutions with magic numbers
//   Synchronous version which is mapped to embedded block RAMs (EBR)
//   Section 5.1.1, Figure 2
module sbox_sync(
	input		logic [7:0] a,
	input	 	logic 			clk,
	output 	logic [7:0] y);
            
    // sbox implemented as a ROM
    // This module is synchronous and will be inferred using BRAMs (Block RAMs)
    logic [7:0] sbox [0:255];

    initial   $readmemh("sbox.txt", sbox);
	
	  // Synchronous version
	  always_ff @(posedge clk) begin
	  	y <= sbox[a];
	  end
endmodule

// mixcolumns
//   Even funkier action on columns
//   Section 5.1.3, Figure 4
//   Same operation performed on each of four columns
module mixcolumns(input  logic [127:0] a,
                  input logic MCen,
                  output logic [127:0] y);
    logic [31:0] y0, y1, y2, y3;

    mixcolumn mc0(a[127:96], y3);
    mixcolumn mc1(a[95:64],  y2);
    mixcolumn mc2(a[63:32],  y1);
    mixcolumn mc3(a[31:0],   y0);
    always_comb begin
      if (MCen) y = {y3, y2, y1, y0};
      else y = a; // do not modulate state if not enabled
    end
endmodule

// mixcolumn
//   Perform Galois field operations on bytes in a column
//   See EQ(4) from E. Ahmed et al, Lightweight Mix Columns Implementation for AES, AIC09
//   for this hardware implementation
module mixcolumn(input  logic [31:0] a,
                 output logic [31:0] y);
                      
        logic [7:0] a0, a1, a2, a3, y0, y1, y2, y3, t0, t1, t2, t3, tmp;
        
        assign {a0, a1, a2, a3} = a;
        assign tmp = a0 ^ a1 ^ a2 ^ a3;
    
        galoismult gm0(a0^a1, t0);
        galoismult gm1(a1^a2, t1);
        galoismult gm2(a2^a3, t2);
        galoismult gm3(a3^a0, t3);
        
        assign y0 = a0 ^ tmp ^ t0;
        assign y1 = a1 ^ tmp ^ t1;
        assign y2 = a2 ^ tmp ^ t2;
        assign y3 = a3 ^ tmp ^ t3;
        assign y = {y0, y1, y2, y3};    
endmodule

// galoismult
//   Multiply by x in GF(2^8) is a left shift
//   followed by an XOR if the result overflows
//   Uses irreducible polynomial x^8+x^4+x^3+x+1 = 00011011
module galoismult(input  logic [7:0] a,
                  output logic [7:0] y);

    logic [7:0] ashift;
    
    assign ashift = {a[6:0], 1'b0};
    assign y = a[7] ? (ashift ^ 8'b00011011) : ashift;
endmodule

// addroundkey
//   a round key is combined with the state by applying the bitwise XOR operation
//   each round key consists of four words from the key schedule
//   Section 5.1.4, Figure 5
module addroundkey(input logic [127:0] a,
                  input logic [127:0] w,
                  input logic ARKen,
                  output logic [127:0] y);
    always_comb begin
      if (ARKen) y = a ^ w;
      else y = a; // do not modulate state if not enabled
    end
endmodule

// shiftrows
//   the bytes in the last three rows of the state are cyclically shifted
//        S0,0    S0,1    S0,2    S0,3        S0,0    S0,1    S0,2    S0,3
//        S1,0    S1,1    S1,2    S1,3        S1,1    S1,2    S1,3    S1,0
//        S2,0    S2,1    S2,2    S2,3   =>   S2,2    S2,3    S2,0    S2,1
//        S3,0    S3,1    S3,2    S3,3        S3,3    S3,0    S3,1    S3,2
//   Section 5.1.2, Figure 3
module shiftrows(input logic [127:0] a,
                input logic SRen,
                output logic [127:0] y);
    /*logic [31:0] row0, row1, row2, row3, rowp0, rowp1, rowp2, rowp3;
    assign {row0, row1, row2, row3} = a;*/
    logic [7:0] s00,s01,s02,s03,s10,s11,s12,s13,s20,s21,s22,s23,s30,s31,s32,s33;
    assign {s00,s10,s20,s30,s01,s11,s21,s31,s02,s12,s22,s32,s03,s13,s23,s33} = a;
    always_comb begin
      if (SRen) begin
        y[127:96] = {s00,s11,s22,s33};
        y[95:64] = {s01,s12,s23,s30};
        y[63:32] = {s02,s13,s20,s31};
        y[31:0] = {s03,s10,s21,s32};
        /*assign rowp0 = row0;
        assign rowp1 = {row1[23:0], row1[31:24]};
        assign rowp2 = {row2[15:0], row2[31:16]};
        assign rowp3 = {row3[7:0], row3[31:8]};
        assign y = {rowp0, rowp1, rowp2, rowp3};*/
      end
      else y = a; // do not modulate state if not enabled
    end
endmodule

// keyexpansion
//   The output of the routine consists of a linear array of words, denoted by w[i], where i is in the range 0 ≤ i < 4 ∗ (Nr +1)
//   
//   Section 5.2
/*module keyexpansion(input logic [127:0] key,
                  output logic [1407:0] w); // w has length 128*11
    logic i = 0;
    logic [127:0] temp;
    logic Rcon
    //// put in main fsm
    always_comb
      while i < (4-1) begin // (Nk-1)
        w[4*128*i+383:4*128*i] = key[128*i+127:128*i]; // w[Nk*Nb*i+Nk*3*Nb:Nk*Nb*i]
        i = i + 1;
      end
      while i < (4*10+3) begin // (4*Nr+3)
        temp = w[128*i+127:128*i];
          if (i%4==0) begin
            temp = rotword(temp[127:0],temp[127:0]); // cannot call modules like this, put in always ff block
            temp = subword(temp[127:0],temp[127:0]);
            temp = temp ^ Rcon[i/Nk];
          end
          w[4*128*i+383:4*128*i] = [4*128*(i-Nk)+383:4*128*(i-Nk)] ^ temp;
          i = i + 1;
      end
endmodule*/

// rotword
//   rotword([a0,a1,a2,a3]) = [a1,a2,a3,a0]
module rotword(input logic [31:0] a,
                  output logic [31:0] y);
    logic [7:0] a0, a1, a2, a3, y0, y1, y2, y3;
    assign {a0, a1, a2, a3} = a;
    
    assign y0 = a1;
    assign y1 = a2;
    assign y2 = a3;
    assign y3 = a0;
    
    assign y = {y0, y1, y2, y3};
endmodule

// subword
//   subword([a0,...,a3]) = [sbox(a0),sbox(a1),sbox(a2),sbox(a3)]
module subword(input logic [31:0] a,
              input logic clk,
              output logic [31:0] y);
    logic [7:0] a0, a1, a2, a3, y0, y1, y2, y3;
    assign {a0, a1, a2, a3} = a;

    sbox_sync byte0(a0, clk, y0);
    sbox_sync byte1(a1, clk, y1);
    sbox_sync byte2(a2, clk, y2);
    sbox_sync byte3(a3, clk, y3);

    assign y = {y0, y1, y2, y3};
endmodule

// subbytes
//   calls subword 4 times to modulate full 128-bit state
module subbytes(input logic [127:0] a,
                input logic SBen,
                input logic clk,
                output logic [127:0] y);
    logic [31:0] ax0, ax1, ax2, ax3;
    logic [31:0] yx0, yx1, yx2, yx3;
    assign {ax0, ax1, ax2, ax3} = a;

    subword subword0(ax0,clk,yx0);
    subword subword1(ax1,clk,yx1);
    subword subword2(ax2,clk,yx2);
    subword subword3(ax3,clk,yx3);

    always_comb begin
      if (SBen) y = {yx0, yx1, yx2, yx3};
      else y = a; // do not modulate state if not enabled
    end
endmodule
