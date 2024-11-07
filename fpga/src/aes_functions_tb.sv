`timescale 10ns/1ns
// Daniel Fajardo
// dfajardo@g.hmc.edu
// 11/05/2024
// testbenches for aes functions

module testbench_aes_keyexpansion();
    logic clk;
    logic [127:0] roundkey,nextroundkey,expected;
    logic [3:0] round;

    keyexpansion dut(round,roundkey,clk,nextroundkey);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        round <= 0;
        roundkey <= 128'h2B7E151628AED2A6ABF7158809CF4F3C;
        expected <= 128'hA0FAFE1788542CB123A339392A6C7605;
        #32;
        round <= 1;
        if (nextroundkey==expected) $display ("roundkey 1 successful");
        else $display("Error: nextroundkey = %h, expected %h", nextroundkey, expected);
        expected <= 128'hA0FAFE1788542CB123A339392A6C7605;
        #32;
        round <= 2;
        if (nextroundkey==expected) $display ("roundkey 1 successful");
        else $display("Error: nextroundkey = %h, expected %h", nextroundkey, expected);
    end
endmodule

module testbench_aes_addroundkey();
    logic clk;
    logic [127:0] ARKin,roundkey,ARKout,expected;
    logic ARKen;

    addroundkey dut(ARKin,roundkey,ARKen,ARKout);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        ARKen <= 1;
        roundkey <= 128'h2B7E151628AED2A6ABF7158809CF4F3C;
        ARKin <= 128'h3243F6A8885A308D313198A2E0370734;
        expected <= 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
        #22;
        if (ARKout==expected) $display ("Testbench ran successfully");
        else $display("Error: ARKout = %h, expected %h", ARKout, expected);
    end
endmodule

module testbench_aes_subbytes();
    logic clk;
    logic [127:0] SBin,SBout,expected;
    logic SBen;

    subbytes dut(SBin,SBen,clk,SBout);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        SBen <= 1;
        SBin <= 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
        expected <= 128'hD42711AEE0BF98F1B8B45DE51E415230;
        #22;
        if (SBout==expected) $display ("Testbench ran successfully");
        else $display("Error: SBout = %h, expected %h", SBout, expected);
    end
endmodule

module testbench_aes_shiftrows();
    logic clk;
    logic [127:0] SRin,SRout,expected;
    logic SRen;

    shiftrows dut(SRin,SRen,SRout);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        SRen <= 1;
        SRin <= 128'hD42711AEE0BF98F1B8B45DE51E415230;
        expected <= 128'hD4BF5D30E0B452AEB84111F11E2798E5;
        #22;
        if (SRout==expected) $display ("Testbench ran successfully");
        else $display("Error: SRout = %h, expected %h", SRout, expected);
    end
endmodule

module testbench_aes_mixcolumns();
    logic clk;
    logic [127:0] MCin,MCout,expected;
    logic MCen;

    mixcolumns dut(MCin,MCen,MCout);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        MCen <= 1;
        MCin <= 128'hD4BF5D30E0B452AEB84111F11E2798E5;
        expected <= 128'h046681E5E0CB199A48F8D37A2806264C;
        #22;
        if (MCout==expected) $display ("Testbench ran successfully");
        else $display("Error: MCout = %h, expected %h", MCout, expected);
    end
endmodule

module testbench_aes_rotword();
    logic clk;
    logic [31:0] RWin,RWout,expected;

    rotword dut(RWin,RWout);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        RWin <= 32'h09CF4F3C;
        expected <= 32'hCF4F3C09;
        #22;
        if (RWout==expected) $display ("Testbench ran successfully");
        else $display("Error: RWout = %h, expected %h", RWout, expected);
    end
endmodule

module testbench_aes_subword();
    logic clk;
    logic [31:0] SWin,SWout,expected;

    subword dut(SWin,clk,SWout);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        SWin <= 32'hCF4F3C09;
        expected <= 32'h8A84EB01;
        #22;
        if (SWout==expected) $display ("Testbench ran successfully");
        else $display("Error: SWout = %h, expected %h", SWout, expected);
    end
endmodule