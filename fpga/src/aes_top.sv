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

    mainfsm mainfsm(clk,load,key,plaintext,current,done,cyphertext,KEen,ARKen,SBen,SRen,MCen)
    addroundkey(a,w,y);
    
endmodule

module mainfsm(input  logic         clk, 
                input  logic         load,
                input  logic [127:0] key,
                input  logic [127:0] plaintext,
                input  logic [127:0] current,
                output logic         done, 
                output logic [127:0] cyphertext,
                output logic [127:0] roundkey,
                output logic ARKen, SBen, SRen, MCen);
    logic state, nextstate;
    logic [3:0] counter;

    always_ff @(posedge clk)
      if (load) begin 
        state <= nextstate;
        couter <= 0;
      end
      else begin
        state <= nextstate;
        counter <= counter + 1;
      end
    
    // key expansion logic input: key, output: roundkey
    

    // nextstate logic
    always_comb
      case (state)
        // keyexpansion
        0: w[127:0] <= key[127:0];
        //
        1: 
      endcase
    
    // output logic
    always_comb
    
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

    if (MCen) begin
      mixcolumn mc0(a[127:96], y[127:96]);
      mixcolumn mc1(a[95:64],  y[95:64]);
      mixcolumn mc2(a[63:32],  y[63:32]);
      mixcolumn mc3(a[31:0],   y[31:0]);
    end
    else assign y = a; // do not modulate state if not enabled
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
    if (ARKen) assign y = a ^ w;
    else assign y = a; // do not modulate state if not enabled
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
    logic [31:0] row0, row1, row2, row3, rowp0, rowp1, rowp2, rowp3;
    assign {row0, row1, row2, row3} = a;

    if (SRen) begin
      assign rowp0 = row0;
      assign rowp1 = {row1[95:0], row1[127:96]};
      assign rowp2 = {row2[63:0], row2[127:64]};
      assign rowp3 = {row3[31:0], row3[127:32]};
      assign y = {rowp0, rowp1, rowp2, rowp3};
    end
    else assign y = a; // do not modulate state if not enabled
endmodule

// keyexpansion
//   The output of the routine consists of a linear array of words, denoted by w[i], where i is in the range 0 ≤ i < 4 ∗ (Nr +1)
//   
//   Section 5.2
module keyexpansion(input logic [127:0] key,
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
endmodule

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
                  output logic [31:0 y]);
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
                output logic [127:0] y)
    logic [31:0] ax0, ax1, ax2, ax3;
    logic [31:0] yx0, yx1, yx2, yx3;
    assign {ax0, ax1, ax2, ax3} = a;
    assign {yx0, yx1, yx2, yx3} = y;
    if (SBen) begin
      subword subword0(ax0,yx0);
      subword subword1(ax1,yx1);
      subword subword2(ax2,yx2);
      subword subword3(ax3,yx3);
      assign y = {yx0, yx1, yx2, yx3};
    end
    else assign y = a; // do not modulate state if not enabled
endmodule
