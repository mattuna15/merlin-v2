`timescale 1ns/1ps
//------------------------------------------------------------------------------
// mc68881_pin_wrapper.v
//
// "Drop-in" wrapper whose port list and DSACK0/DSACK1 behavior exactly match
// the MC68881/MC68882 pinout (Figure 9-1).  Internally, hook this up to:
//   • an 80-bit cycle-accurate IEEE-754 core ("fpu_core")
//   • a decoder ("fpu_decoder_68881") that splits the 32-bit F-opcode
//   • an 8×80-bit register file, plus 32-bit FPCR/FPSR
//   • small FSMs to collect/distribute the three 32/32/16-bit chunks
//------------------------------------------------------------------------------ 
module mc68881_pin_wrapper (
    //???????????????????????????????????????????????????????????????????????????
    // CORE CLOCK / SIZE / RESET / SENSE
    //???????????????????????????????????????????????????????????????????????????
    input         CLK,      // Pin 1: Clock (e.g. 68 MHz)
    input         SIZE,     // Pin 2: Size select (byte vs. word/long)
    input         RESET,    // Pin 3: Active-high reset
    output        SENSE,    // Pin 4: "Sense OK" (goes high after RESET)

    //???????????????????????????????????????????????????????????????????????????
    // ADDRESS LINES A0-A4 (for register/memory decode)
    //???????????????????????????????????????????????????????????????????????????
    input  [4:0]  A,        // Pins 5-6, 14-16: A0…A4

    //???????????????????????????????????????????????????????????????????????????
    // DATA LINES D0-D31 (bidirectional)
    //???????????????????????????????????????????????????????????????????????????
    inout [31:0]  D,        // Pins 17-48: D0…D31

    //???????????????????????????????????????????????????????????????????????????
    // CONTROL INPUTS (from CPU)
    //???????????????????????????????????????????????????????????????????????????
    input         AS,       // Pin 49: Address Strobe (active high)
    input         R_W,      // Pin 50: Read(1)/Write(0)
    input         DS,       // Pin 51: Data Strobe (active high)
    input         CS,       // Pin 52: Chip Select (active high)

    //???????????????????????????????????????????????????????????????????????????
    // DATA STROBE ACKNOWLEDGE OUTPUTS (Pins 53 & 54)
    // DSACK1/DSACK0 together encode "I'm ready" + bus-cycle size
    // (active-low)
    //???????????????????????????????????????????????????????????????????????????
    output        DSACK0,   // Pin 53: DSACK0 (active-low: size/handshake bit 0)
    output        DSACK1    // Pin 54: DSACK1 (active-low: size/handshake bit 1)
);

    //==========================================================================
    // 1) "SENSE" Line
    //    Hold low during RESET.  When RESET goes low, drive SENSE=1.
    //==========================================================================
    reg sense_reg;
    assign SENSE = sense_reg;
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            sense_reg <= 1'b0;
        end else begin
            sense_reg <= 1'b1;
        end
    end

    //==========================================================================
    // 2) Bus-Cycle Decoding
    //    A valid bus cycle when (CS=1 & AS=1). Then:
    //      • fetch_cycle = (CS & AS & ~DS &  R_W) ? F-line fetch (32-bit)
    //      • write_cycle = (CS & AS &  DS & ~R_W) ? Write FPCR or FPn (80-bit)
    //      • read_cycle  = (CS & AS &  DS &  R_W) ? Read  FPCR or FPn (80-bit)
    //==========================================================================
    wire bus_cycle   = CS & AS;
    wire fetch_cycle = bus_cycle & (~DS) & R_W;   // F-line fetch
    wire write_cycle = bus_cycle &  DS  & (~R_W); // Write FPCR/FPn
    wire read_cycle  = bus_cycle &  DS  &  R_W;   // Read  FPCR/FPn

    // For selecting FPCR/FPSR/FP0…FP7, use addr_lo = A[4:0]
    wire [4:0] addr_lo = A;

    //==========================================================================
    // 3) Latch the 32-bit F-LINE OPCODE
    //    On fetch_cycle, D[31:0] = 32-bit FPU instruction. Latch into f_opcode.
    //==========================================================================
    reg  [31:0] f_opcode;
    reg         latch_op;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            f_opcode <= 32'd0;
            latch_op <= 1'b0;
        end else begin
            if (fetch_cycle) begin
                f_opcode <= D;       // Grab 32-bit FPU opcode
                latch_op <= 1'b1;    // One-cycle pulse for decoder
            end else begin
                latch_op <= 1'b0;
            end
        end
    end

    //==========================================================================
    // 4) DECODE f_opcode ? (dec_fpu_op, dec_rmode, dec_fmt, idx_ra, idx_rb, idx_rc, dec_illegal)
    //    You will implement fpu_decoder_68881.v to follow MC68881 tables.
    //    Its outputs:
    //      • dec_fpu_op[3:0] : floating-point operation code
    //      • dec_rmode [1:0] : rounding mode
    //      • dec_fmt   [1:0] : precision format (00=single,01=double,10=extended)
    //      • idx_ra    [2:0] : register Rx
    //      • idx_rb    [2:0] : register Ry
    //      • idx_rc    [2:0] : register Rz
    //      • dec_illegal    : high if opcode is invalid/reserved
    //==========================================================================
    wire [3:0]  dec_fpu_op;
    wire [1:0]  dec_rmode;
    wire [1:0]  dec_fmt;
    wire [2:0]  idx_ra;
    wire [2:0]  idx_rb;
    wire [2:0]  idx_rc;
    wire        dec_illegal;

//    fpu_decoder_68881 u_decoder (
//        .opcode  (f_opcode),
//        .fpu_op  (dec_fpu_op),
//        .rmode   (dec_rmode),
//        .fmt     (dec_fmt),
//        .ra      (idx_ra),
//        .rb      (idx_rb),
//        .rc      (idx_rc),
//        .illegal (dec_illegal)
//    );

    //==========================================================================
    // 5) REGISTER FILE + FPCR + FPSR
    //    • 8 × 80-bit FP registers ? fp_regs[0…7]
    //    • 32-bit FPCR register   ? fpcr_reg
    //    • 32-bit FPSR register   ? fpsr_reg (updated when fpu_done pulses)
    //
    //    We also need FSM state for FPn read/write:
    //
    //      fpn_write_phase:  2-bit state for CPU?FPn write:
    //         00 = idle
    //         01 = latch low  32 bits
    //         10 = latch mid  32 bits
    //         11 = latch high 16 bits
    //
    //      fpn_write_index:  3-bit index of which FP register (0…7) is being written
    //
    //      fpn_read_phase/read_index similarly for reads.
    //==========================================================================
    reg [79:0] fp_regs [0:7];
    reg [31:0] fpcr_reg;
    reg [31:0] fpsr_reg;

    reg [1:0]  fpn_write_phase;
    reg [2:0]  fpn_write_index;

    reg [1:0]  fpn_read_phase;
    reg [2:0]  fpn_read_index;

    //----------------------------------------------------------------------
    // (a) FPCR/FPn WRITE FSM
    //----------------------------------------------------------------------
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            fpcr_reg        <= 32'd0;
            fpsr_reg        <= 32'd0;
            fpn_write_phase <= 2'b00;
            fpn_write_index <= 3'd0;
            // Zero out all FP registers:
            fp_regs[0] <= 80'd0;
            fp_regs[1] <= 80'd0;
            fp_regs[2] <= 80'd0;
            fp_regs[3] <= 80'd0;
            fp_regs[4] <= 80'd0;
            fp_regs[5] <= 80'd0;
            fp_regs[6] <= 80'd0;
            fp_regs[7] <= 80'd0;
        end else begin
            if (write_cycle) begin
                case (addr_lo)
                    // --------------------------------------------------------
                    // Write to FPCR (single 32-bit)
                    // --------------------------------------------------------
                    5'b01000: begin
                        fpcr_reg <= D;
                    end

                    // --------------------------------------------------------
                    // Write to FP0…FP7 (80-bit multi-cycle). Index = A[2:0].
                    // Subcycles:
                    //   phase=00 ? 01 (low 32 bits)
                    //   phase=01 ? 10 (mid 32 bits)
                    //   phase=10 ? 11 (high 16 bits)
                    //   phase=11 ? 00 (idle)
                    // --------------------------------------------------------
                    5'b00000, 5'b00001, 5'b00010, 5'b00011,
                    5'b00100, 5'b00101, 5'b00110, 5'b00111: begin
                        // Which FP register? (0…7)
                        fpn_write_index = addr_lo[2:0];

                        if (fpn_write_phase == 2'b00) begin
                            // Subcycle 1: latch low 32 bits
                            fp_regs[fpn_write_index][31:0] <= D;
                            fpn_write_phase               <= 2'b01;
                        end
                        else if (fpn_write_phase == 2'b01) begin
                            // Subcycle 2: latch mid 32 bits
                            fp_regs[fpn_write_index][63:32] <= D;
                            fpn_write_phase                <= 2'b10;
                        end
                        else if (fpn_write_phase == 2'b10) begin
                            // Subcycle 3: latch high 16 bits
                            fp_regs[fpn_write_index][79:64] <= D[15:0];
                            fpn_write_phase                <= 2'b11;
                        end
                        else if (fpn_write_phase == 2'b11) begin
                            // Done ? return to idle
                            fpn_write_phase <= 2'b00;
                        end
                    end

                    default: begin
                        // Reserved/no-op
                    end
                endcase
            end else begin
                // If not in write_cycle, remain in current subphase.
            end
        end
    end

    //----------------------------------------------------------------------
    // (b) FPCR/FPn READ FSM
    //----------------------------------------------------------------------
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            fpn_read_phase <= 2'b00;
            fpn_read_index <= 3'd0;
        end else begin
            if (read_cycle) begin
                case (addr_lo)
                    // --------------------------------------------------------
                    // Read FPCR or FPSR (single 32-bit) ? do nothing to FSM
                    // --------------------------------------------------------
                    5'b01000, 5'b01001: begin end

                    // --------------------------------------------------------
                    // Read FP0…FP7 (80-bit multi-cycle):
                    //   phase=00?01 (low 32), 01?10 (mid 32), 10?11 (high 16), 11?00 (idle)
                    // --------------------------------------------------------
                    5'b00000, 5'b00001, 5'b00010, 5'b00011,
                    5'b00100, 5'b00101, 5'b00110, 5'b00111: begin
                        fpn_read_index = addr_lo[2:0];

                        if (fpn_read_phase == 2'b00) begin
                            fpn_read_phase <= 2'b01;
                        end else if (fpn_read_phase == 2'b01) begin
                            fpn_read_phase <= 2'b10;
                        end else if (fpn_read_phase == 2'b10) begin
                            fpn_read_phase <= 2'b11;
                        end else if (fpn_read_phase == 2'b11) begin
                            fpn_read_phase <= 2'b00;
                        end
                    end

                    default: begin
                        // Reserved
                    end
                endcase
            end
        end
    end

    //----------------------------------------------------------------------
    // (c) Drive the bidirectional data bus D[31:0] during read_cycle
    //----------------------------------------------------------------------
    reg [31:0] dbus_out;
    reg        dbus_drive;  // =1 ? drive D=dbus_out;  =0 ? D=Z

    always @(*) begin
        dbus_out   = 32'd0;
        dbus_drive = 1'b0;

        if (read_cycle) begin
            case (addr_lo)
                // ----------------------------------------
                // Read FPSR (addr_lo=01001) ? 32-bit
                // ----------------------------------------
                5'b01001: begin
                    dbus_out   = fpsr_reg;
                    dbus_drive = 1'b1;
                end

                // ----------------------------------------
                // Read FPCR (addr_lo=01000) ? 32-bit
                // ----------------------------------------
                5'b01000: begin
                    dbus_out   = fpcr_reg;
                    dbus_drive = 1'b1;
                end

                // ----------------------------------------
                // Read FP0…FP7 (addr_lo=00000..00111) ? 80-bit in 3 subcycles
                // ----------------------------------------
                5'b00000, 5'b00001, 5'b00010, 5'b00011,
                5'b00100, 5'b00101, 5'b00110, 5'b00111: begin
                    if (fpn_read_phase == 2'b01) begin
                        // Subcycle 1: low 32 bits
                        dbus_out   = fp_regs[fpn_read_index][31:0];
                        dbus_drive = 1'b1;
                    end else if (fpn_read_phase == 2'b10) begin
                        // Subcycle 2: mid 32 bits
                        dbus_out   = fp_regs[fpn_read_index][63:32];
                        dbus_drive = 1'b1;
                    end else if (fpn_read_phase == 2'b11) begin
                        // Subcycle 3: high 16 bits in D[15:0], zero upper half
                        dbus_out   = {16'd0, fp_regs[fpn_read_index][79:64]};
                        dbus_drive = 1'b1;
                    end
                end

                default: begin
                    // Reserved
                end
            endcase
        end
    end

    // Tri-state driver for D:
    assign D = (dbus_drive) ? dbus_out : 32'hZZZZ_ZZZZ;

    //==========================================================================
    // 6) (Stub) Instantiate 80-bit FPU Core & Write-Back on fpu_done
    //
    //    When you add your real fpu_core, it will:
    //      • Accept (CLK,RESET,start,dec_fpu_op,dec_rmode,dec_fmt,opa,opb)
    //      • After N cycles, pulse done=1 for one clock
    //      • Output fpu_result[79:0] plus IEEE flags.
    //    On fpu_done, we write fpu_result back to fp_regs[idx_rc] & update FPSR.
    //==========================================================================
    wire        fpu_start = latch_op & (~dec_illegal);
    wire        fpu_done;
    wire [79:0] fpu_result;
    wire        flag_snan, flag_qnan, flag_inf;
    wire        flag_zero, flag_ine, flag_over, flag_under, flag_div0;

    wire [79:0] opa = fp_regs[idx_ra];
    wire [79:0] opb = fp_regs[idx_rb];

//    fpu_core u_fpu_core (
//        .clk       (CLK),
//        .rst       (RESET),
//        .start     (fpu_start),
//        .fpu_op    (dec_fpu_op),
//        .rmode     (dec_rmode),
//        .fmt       (dec_fmt),
//        .opa       (opa),
//        .opb       (opb),
//        .result    (fpu_result),
//        .done      (fpu_done),
//        .flag_snan (flag_snan),
//        .flag_qnan (flag_qnan),
//        .flag_inf  (flag_inf),
//        .flag_zero (flag_zero),
//        .flag_ine  (flag_ine),
//        .flag_over (flag_over),
//        .flag_under(flag_under),
//        .flag_div0 (flag_div0)
//    );

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // Nothing extra (fp_regs already cleared)
        end else begin
            if (fpu_done) begin
                // Write back 80-bit result
                fp_regs[idx_rc] <= fpu_result;
                // Update FPSR sticky bits:
                fpsr_reg[0] <= flag_zero;    // Zero
                fpsr_reg[1] <= flag_ine;     // Inexact
                fpsr_reg[2] <= flag_div0;    // Div0
                fpsr_reg[3] <= flag_under;   // Underflow
                fpsr_reg[4] <= flag_over;    // Overflow
                fpsr_reg[5] <= flag_inf;     // Infinity
                fpsr_reg[6] <= flag_qnan;    // QNaN
                fpsr_reg[7] <= flag_snan;    // SNaN
            end
        end
    end

    //==========================================================================
    // 9) DSACK1 / DSACK0 - ACTIVE-LOW, COMBINATIONAL
    //
    //   Implements Figure 10-2 and Sections 10.1.1-10.1.3, **plus**:
    //     • Any FPn subcycle 1 or 2 ? force 32-bit  
    //     • Any FPn subcycle 3      ? force 16-bit  
    //     • FPCR (01000) & FPSR (01001) ? always 32-bit  
    //     • SIZE=1 & A[0]=1           ? normal 32-bit  
    //     • SIZE=1 & A[0]=0 & not FPn/FMCR ? 16-bit  
    //     • SIZE=0 ? 8-bit
    //==========================================================================
    // (A) Identify "is FP register" (addr_lo in 00000..00111)
    wire is_fp_reg = (addr_lo[4:1] == 4'b0000);

    // (B) Compute "effective port size":
    wire effective_32b =
           // (1) FPCR or FPSR always 32-bit
           (addr_lo == 5'b01000) 
        || (addr_lo == 5'b01001)
           // (2) Any FPn subcycle 1 or 2 ? 32-bit
        || (is_fp_reg && write_cycle && (fpn_write_phase == 2'b00 || fpn_write_phase == 2'b01))
        || (is_fp_reg &&  read_cycle && (fpn_read_phase  == 2'b01 || fpn_read_phase  == 2'b10))
           // (3) Normal long-word if SIZE=1 & A[0]=1
        || ((SIZE == 1'b1) && (A[0] == 1'b1));

    wire effective_16b =
           // (1) Any FPn subcycle 3 ? 16-bit
           (is_fp_reg && write_cycle && (fpn_write_phase == 2'b10))
        || (is_fp_reg &&  read_cycle && (fpn_read_phase  == 2'b11))
           // (2) Normal word if SIZE=1 & A[0]=0, but NOT FPCR/FPSR
        || ( (SIZE == 1'b1) && (A[0] == 1'b0)
             && (addr_lo != 5'b01000)
             && (addr_lo != 5'b01001) );

    wire effective_8b  = (SIZE == 1'b0);

    // (C) "data_ready" signals (unchanged):
    wire data_ready_32 = 
           fetch_cycle
        || (write_cycle && (addr_lo == 5'b01000))
        || (read_cycle  && (addr_lo == 5'b01000 || addr_lo == 5'b01001))
        || (write_cycle && (addr_lo[4:1] == 4'b0000) 
              && (fpn_write_phase == 2'b00 || fpn_write_phase == 2'b01))
        || (read_cycle  && (addr_lo[4:1] == 4'b0000) 
              && (fpn_read_phase  == 2'b01 || fpn_read_phase  == 2'b10));

    wire data_ready_16 = 
           (write_cycle && (addr_lo[4:1] == 4'b0000) && (fpn_write_phase == 2'b10))
        || (read_cycle  && (addr_lo[4:1] == 4'b0000) && (fpn_read_phase  == 2'b11));

    wire data_ready_8  = 
           (SIZE == 1'b0) && (write_cycle || read_cycle);

    // (D) Drive DSACK1/DSACK0 active-low:
    wire dsack1_comb = (effective_32b && data_ready_32);
    wire dsack0_comb = (effective_16b && data_ready_16)
                     || (effective_8b  && data_ready_8);

    assign DSACK1 = dsack1_comb ? 1'b0 : 1'b1;  // 0 = "32-bit ready," 1 = wait
    assign DSACK0 = dsack0_comb ? 1'b0 : 1'b1;  // 0 = "16-bit or 8-bit ready," 1 = wait

endmodule
