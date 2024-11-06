`timescale 10ns/1ns
// Daniel Fajardo
// dfajardo@g.hmc.edu
// 11/05/2024
// testbenches for aes functions

module testbench_aes_addroundkey();
    logic clk;
    logic [127:0] ARKin,roundkey,cyphertext,expected;
    logic ARKen;

    addroundkey dut(ARKin,roundkey,ARKen,cyphertext);

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
        if (cyphertext==expected) $display ("Testbench ran successfully");
        else $display("Error: cyphertext = %h, expected %h", cyphertext, expected);
    end
endmodule

module testbench_aes_subbytes();
    logic clk;
    logic [127:0] SBin,SRin,expected;
    logic SBen;

    subbytes dut(SBin,SBen,clk,SRin);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        SBen <= 1;
        SBin <= 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
        expected <= 128'hD42711AEE0BF98F1B8B45DE51E415230;
        #22;
        if (SRin==expected) $display ("Testbench ran successfully");
        else $display("Error: SRin = %h, expected %h", SRin, expected);
    end
endmodule

module testbench_aes_shiftrows();
    logic clk;
    logic [127:0] SRin,MCin,expected;
    logic SRen;

    shiftrows dut(SRin,SRen,MCin);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        SRen <= 1;
        SRin <= 128'hD42711AEE0BF98F1B8B45DE51E415230;
        expected <= 128'hD4BF5D30E0B452AEB84111F11E2798E5;
        #22;
        if (MCin==expected) $display ("Testbench ran successfully");
        else $display("Error: MCin = %h, expected %h", MCin, expected);
    end
endmodule

module testbench_aes_mixcolumns();
    logic clk;
    logic [127:0] MCin,ARKin,expected;
    logic MCen;

    mixcolumns dut(MCin,MCen,ARKin);

    always begin 
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    initial begin
        MCen <= 1;
        MCin <= 128'hD4BF5D30E0B452AEB84111F11E2798E5;
        expected <= 128'h046681E5E0CB199A48F8D37A2806264C;
        #22;
        if (ARKin==expected) $display ("Testbench ran successfully");
        else $display("Error: ARKin = %h, expected %h", ARKin, expected);
    end
endmodule