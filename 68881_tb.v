`timescale 1ns/1ps
//------------------------------------------------------------------------------
// tb_mc68881.v
//
// Testbench for mc68881_pin_wrapper.v
// Verifies DSACK behavior (active-low) for:
//  1) 32-bit F-line fetch
//  2) 32-bit FPCR write & read
//  3) 80-bit FP0 write (low32, mid32, high16) + 80-bit FP0 read (low32, mid32, high16)
//------------------------------------------------------------------------------ 
module tb_mc68881;

    // Clock & Reset
    reg  CLK = 0;
    reg  RESET = 1;

    // Wrapper ports
    reg   SIZE;
    wire  SENSE;
    reg   R_W, DS, AS, CS;
    reg  [4:0] A;
    wire [31:0] D;

    wire  DSACK0, DSACK1;

    // We need to drive D from TB when it is a CPU write (write_cycle).
    // When the wrapper drives D (during read_cycle), TB must release it to Z.
    reg  [31:0] tb_dbus;
    reg         tb_drive;   // 1=drive tb_dbus onto D; 0=tri-state

    assign D = (tb_drive ? tb_dbus : 32'hZZZZ_ZZZZ);

    // Instantiate the wrapper under test
    mc68881_pin_wrapper dut (
        .CLK    (CLK),
        .SIZE   (SIZE),
        .RESET  (RESET),
        .SENSE  (SENSE),
        .A      (A),
        .D      (D),
        .AS     (AS),
        .R_W    (R_W),
        .DS     (DS),
        .CS     (CS),
        .DSACK0 (DSACK0),
        .DSACK1 (DSACK1)
    );

    // Clock generation
    always #5 CLK = ~CLK;  // 100 MHz clock (10 ns period)

    initial begin
        // Initialize all control signals to zero/IDLE
        SIZE      = 1'b1;   // default to 32-bit mode
        AS        = 1'b0;
        DS        = 1'b0;
        R_W       = 1'b1;
        CS        = 1'b0;
        A         = 5'd0;
        tb_dbus   = 32'h0000_0000;
        tb_drive  = 1'b0;

        // Assert RESET for two clocks
        #1  RESET = 1;
        #20 RESET = 0;  
        // Now SENSE should go high on next rising edge of CLK
        wait (SENSE == 1'b1);
        $display("[%0t] => SENSE is high, wrapper ready", $time);

        // -----------------------------------------------------------------------------------
        // 1) Test 32-bit F-line fetch.
        //    Expect DSACK1=0, DSACK0=1 (active-low, 32-bit)
        // -----------------------------------------------------------------------------------
        @(posedge CLK);
        #1;
        CS  = 1'b1;
        AS  = 1'b1;
        DS  = 1'b0;    // fetch_cycle = 1 when R_W=1
        R_W = 1'b1;
        SIZE= 1'b1;    // 32-bit
        A   = 5'b10101; // some arbitrary address (unused by wrapper for fetch)
        tb_drive = 1'b1;
        tb_dbus  = 32'hCAFEBABE;  // pretend this is the FPU opcode
        $display("[%0t] --> Starting F-line fetch, expecting DSACK1=0", $time);

        // Wait for DSACK1 to go low
        wait (DSACK1 == 1'b0);
        $display("[%0t] *** DSACK1=0 (32-bit fetch ready)", $time);

        @(posedge CLK);
        #1; 
        // Deassert the cycle immediately after seeing DSACK1 low
        CS  = 1'b0;
        AS  = 1'b0;
        DS  = 1'b0;
        R_W = 1'b1;
        tb_drive = 1'b0;
        $display("[%0t] => F-line fetch completed", $time);

        // Small delay
        #20;

        // -----------------------------------------------------------------------------------
        // 2) Test 32-bit FPCR write & read.
        //    a) Write 0xA5A5A5A5 to FPCR (addr_lo = 01000). Expect DSACK1=0.
        //    b) Read  back from FPCR. Expect DSACK1=0, D=0xA5A5A5A5.
        // -----------------------------------------------------------------------------------

        // a) FPCR write
        @(posedge CLK);
        #1;
        CS  = 1'b1;
        AS  = 1'b1;
        DS  = 1'b1;    // write_cycle = 1 when R_W=0
        R_W = 1'b0;
        SIZE= 1'b1;    // 32-bit
        A   = 5'b01000; // FPCR
        tb_drive = 1'b1;
        tb_dbus  = 32'hA5A5A5A5;
        $display("[%0t] --> Starting FPCR write 0xA5A5A5A5, expect DSACK1=0", $time);

        // Wait for DSACK1 low (32-bit ready)
        wait (DSACK1 == 1'b0);
        $display("[%0t] *** DSACK1=0 (FPCR write ready)", $time);

        @(posedge CLK);
        #1;
        // Deassert cycle
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1; tb_drive = 1'b0;
        $display("[%0t] => FPCR write completed", $time);

        #20;

        // b) FPCR read
        @(posedge CLK);
        #1;
        CS  = 1'b1;
        AS  = 1'b1;
        DS  = 1'b1;   // read_cycle = 1 when R_W=1
        R_W = 1'b1;
        SIZE= 1'b1;   // 32-bit
        A   = 5'b01000; // FPCR
        tb_drive = 1'b0;  // wrapper should drive D
        $display("[%0t] --> Starting FPCR read, expect DSACK1=0 and D=0xA5A5A5A5", $time);

        // Wait for DSACK1 low
        wait (DSACK1 == 1'b0);
        #1;  // small delta so D is already driven
        $display("[%0t] *** DSACK1=0, D=0x%08X", $time, D);

        @(posedge CLK);
        #1;
        // Deassert cycle
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1; 
        $display("[%0t] => FPCR read completed", $time);

        #20;

        // -----------------------------------------------------------------------------------
        // 3) Test 80-bit FP0 write & read
        //    Write sequence (3 subcycles):
        //      1) low 32   = 0xDEADBEEF  ? expect DSACK1=0 (32-bit)
        //      2) mid 32   = 0xCAFEBABE  ? expect DSACK1=0 (32-bit)
        //      3) high 16  = 0x1234      ? expect DSACK0=0 (16-bit)
        //    Then read sequence (3 subcycles), verifying same values out.
        // -----------------------------------------------------------------------------------

        // --- FP0 write subcycle 1 (low 32 bits) ---
        @(posedge CLK);
        #1;
        CS  = 1'b1;
        AS  = 1'b1;
        DS  = 1'b1;    // write_cycle
        R_W = 1'b0;
        SIZE= 1'b1;    // 32-bit
        A   = 5'b00000; // FP0
        tb_drive = 1'b1;
        tb_dbus  = 32'hDEADBEEF;
        $display("[%0t] --> FP0 write subcycle 1 (low32=0xDEADBEEF), expect DSACK1=0", $time);

        // Wait for DSACK1=0
        wait (DSACK1 == 1'b0);
        $display("[%0t] *** DSACK1=0 (FP0 low32 write ready)", $time);

        @(posedge CLK);
        #1;
        // End subcycle 1
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1; tb_drive = 1'b0;
        $display("[%0t] => FP0 low32 write done", $time);


        // --- FP0 write subcycle 2 (mid 32 bits) ---
        #20;
        @(posedge CLK);
        #1;
        CS  = 1'b1; AS = 1'b1; DS = 1'b1; R_W = 1'b0; SIZE = 1'b1;
        A   = 5'b00000; // FP0 (same)
        tb_drive = 1'b1;
        tb_dbus  = 32'hCAFEBABE;
        $display("[%0t] --> FP0 write subcycle 2 (mid32=0xCAFEBABE), expect DSACK1=0", $time);

        wait (DSACK1 == 1'b0);
        $display("[%0t] *** DSACK1=0 (FP0 mid32 write ready)", $time);

        @(posedge CLK);
        #1;
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1; tb_drive = 1'b0;
        $display("[%0t] => FP0 mid32 write done", $time);


        // --- FP0 write subcycle 3 (high 16 bits) ---
        #20;
        @(posedge CLK);
        #1;
        CS  = 1'b1; AS = 1'b1; DS = 1'b1; R_W = 1'b0; SIZE = 1'b1;
        A   = 5'b00000; // FP0 (same)
        tb_drive = 1'b1;
        // For high16, place data in D[15:0], upper bits ignored
        tb_dbus  = 32'h0000_1234;
        $display("[%0t] --> FP0 write subcycle 3 (high16=0x1234), expect DSACK0=0", $time);

        // Wait for DSACK0=0 (active-low 16-bit)
        wait (DSACK0 == 1'b0);
        $display("[%0t] *** DSACK0=0 (FP0 high16 write ready)", $time);

        @(posedge CLK);
        #1;
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1; tb_drive = 1'b0;
        $display("[%0t] => FP0 high16 write done", $time);

        #20;


        // --- FP0 read subcycle 1 (low 32 bits) ---
        @(posedge CLK);
        #1;
        CS  = 1'b1; AS = 1'b1; DS = 1'b1; R_W = 1'b1; SIZE = 1'b1;
        A   = 5'b00000; // FP0
        tb_drive = 1'b0;  // wrapper drives D
        $display("[%0t] --> FP0 read subcycle 1 (low32), expect DSACK1=0, D=0xDEADBEEF", $time);

        wait (DSACK1 == 1'b0);
        #1; // allow wrapper to drive D
        $display("[%0t] *** DSACK1=0, D=0x%08X", $time, D);

        @(posedge CLK);
        #1;
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1;
        $display("[%0t] => FP0 low32 read done", $time);


        // --- FP0 read subcycle 2 (mid 32 bits) ---
        #20;
        @(posedge CLK);
        #1;
        CS  = 1'b1; AS = 1'b1; DS = 1'b1; R_W = 1'b1; SIZE = 1'b1;
        A   = 5'b00000; // FP0
        tb_drive = 1'b0;
        $display("[%0t] --> FP0 read subcycle 2 (mid32), expect DSACK1=0, D=0xCAFEBABE", $time);

        wait (DSACK1 == 1'b0);
        #1;
        $display("[%0t] *** DSACK1=0, D=0x%08X", $time, D);

        @(posedge CLK);
        #1;
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1;
        $display("[%0t] => FP0 mid32 read done", $time);


        // --- FP0 read subcycle 3 (high 16 bits) ---
        #20;
        @(posedge CLK);
        #1;
        CS  = 1'b1; AS = 1'b1; DS = 1'b1; R_W = 1'b1; SIZE = 1'b1;
        A   = 5'b00000; // FP0
        tb_drive = 1'b0;
        $display("[%0t] --> FP0 read subcycle 3 (high16), expect DSACK0=0, D[15:0]=0x1234", $time);

        wait (DSACK0 == 1'b0);
        #1;
        $display("[%0t] *** DSACK0=0, D=0x%08X", $time, D);

        @(posedge CLK);
        #1;
        CS  = 1'b0; AS = 1'b0; DS = 1'b0; R_W = 1'b1;
        $display("[%0t] => FP0 high16 read done", $time);

        #20;


        $display("[%0t] *** TESTBENCH COMPLETE ***", $time);
        $finish;
    end

endmodule



