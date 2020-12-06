\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/RISC-V_MYTH_Workshop
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/RISC-V_MYTH_Workshop/c1719d5b338896577b79ee76c2f443ca2a76e14f/tlv_lib/risc-v_shell_lib.tlv'])

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV

   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program for MYTH Workshop to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  r10 (a0): In: 0, Out: final sum
   //  r12 (a2): 10
   //  r13 (a3): 1..10
   //  r14 (a4): Sum
   // 
   // External to function:
   m4_asm(ADD, r10, r0, r0)             // Initialize r10 (a0) to 0.
   // Function:
   m4_asm(ADD, r14, r10, r0)            // Initialize sum register a4 with 0x0
   m4_asm(ADDI, r12, r10, 1010)         // Store count of 10 in register a2.
   m4_asm(ADD, r13, r10, r0)            // Initialize intermediate sum register a3 with 0
   // Loop:
   m4_asm(ADD, r14, r13, r14)           // Incremental addition
   m4_asm(ADDI, r13, r13, 1)            // Increment intermediate register by 1
   m4_asm(BLT, r13, r12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   m4_asm(ADD, r10, r14, r0)            // Store final result to register a0 so that it can be read by main program
   
   // Optional:
   // m4_asm(JAL, r7, 00000000000000000000) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         
         // start signal when $reset was high at the last cycle
         // but has just passed low now
         $start = !$reset && >>1$reset;
         
         // valid when program has just started or when it was valid 3 cycles ago
         // because our transaction now takes 3 cycles to complete
         // must me 0 during reset even though it could have been valid 3 cycles before
         $valid = $reset ? 0 : ($start || >>3$valid);
         
         /***** PROGRAM COUNTER *****/
         
         $inc_pc[31:0] = >>3$pc + 32'd4;
         
         // Stores the ADDRESS of the current instruction
         $pc[31:0] = 
             // We want to make sure we start with the right instruction at address 0
             // if we said "after reset: increment by 4 bytes"
             // we would actually skip the first instruction
             // and start the program with the 2nd instruction which isn't correct
             // so we need to make sure we reset PC to 0 only if $reset was true at the previous transaction
             >>1$reset ? '0
             
             
             // If the PREVIOUS instruction was a taken branch (otherwise the value is 0)
             // then we set the value to the PREVIOUS Target Program Counter
             // Note that we're actually at stage 0 
             // and want to access a value that happened on stage 1 on the previous transaction
             // therefore we only need to get the value one clock cycle ago
             : >>3$valid_taken_br ? >>3$br_tgt_pc
             
             // Otherwise we just increment the Program Counter
             // XLEN is 32 bits so we must increment by 4 because every instruction is 4 bytes long
             // If we only add 1, PC will point to the next byte (instructions are stored as bytes in the buffer)
             // To actually get to the next valid instruction we need to skip 4 bytes
             // hence we have to add 4 
            : $inc_pc;
         
         /***** PROGRAM COUNTER END *****/
      @1  
         /***** FETCH *****/
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
         
         $imem_rd_en = !$reset;
         //$imem_rd_data[31:0] = /imem[$imem_rd_addr]$instr[31:0];
         
         $instr[31:0] = $imem_rd_data[31:0];
         /***** FETCH END*****/
         
         /***** DECODE *****/
         
         // The following decode logic is the implementation of the RISC-V ISA
         // cf: riscv-spec-20191213.pdf 2.3 Immediate Encoding Variants page 16 and 17
         
         /** Determine instruction type **/
         
         // opcode is stored in $instr[6:0] (page 16)
         // but since the first 2 bits are always 1 we simply ignore them
         // ==? TL-VERILOG feature to compare with a "don't care (x)" value
         $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                       $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==  5'b11001;
         
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         
         $is_b_instr = $instr[6:2] ==  5'b11000;
         
         $is_u_instr = $instr[6:2] ==? 5'b0x101;
         
         $is_j_instr = $instr[6:2] ==  5'b11011;
         
         $is_r_instr = $instr[6:2] ==  5'b01011 ||
                       $instr[6:2] ==? 5'b011x0 ||
                       $instr[6:2] ==  5'b10100;
         /** Determine instruction type END **/
         
         /** Form immediate value based on instruction type (page 17) **/
         // There's no immediate value in the case of an R-Type
         $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
         
      // This kind of condition is NOT like a regular `if($imm_valid){...}`
      // In case $imm_valid is false, this would feed "don't care" values to $imm[31:0]
      // In that case (and for other following fields) this is fine
      // The reason is because if a field isn't valid for a specific instruction type
      // this field will simply be ignored for further processing so its value doesn't matter
      ?$imm_valid   
         @1
            // {x,} = concatenation
            // {21{$x[31]}} = 21 times the value of bit 31 of $x
            
            $imm[31:0] =  $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } 
                        : $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] }
                        : $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } 
                        : $is_u_instr ? { $instr[31:12], 12'b000000000000 } 
                        : { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 }; // Last one must be $is_j_instr
      @1   
         /** Form immediate value based on instruction type END **/
         
         /** Form other fields' values based on instruction type (page 16) **/
         // Some fields are missing depending of the instruction type
         $funct7_valid = $is_r_instr;
         $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
         $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $funct3_valid = $rs1_valid; // they're both in the same instruction types
         $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
      ?$funct7_valid
         @1
            $funct7[6:0] = $instr[31:25];
      ?$rs2_valid
         @1
            $rs2[4:0] = $instr[24:20];
      ?$rs1_valid
         @1
            $rs1[4:0] = $instr[19:15];
      ?$funct3_valid
         @1
            $funct3[2:0] = $instr[14:12];
      ?$rd_valid
         @1
            $rd[4:0] = $instr[11:7];
      @1
         // opcode is always valid (in all instruction types)
         $opcode[6:0] = $instr[6:0];
         /** Form other fields' values based on instruction type END **/
         
         /** Instruction decode **/
         // all bits needed to decode our instruction (cf: MYTH Workshop 2 RISC-V.pdf page 13)
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};
         
         // funct7[5] bit isn't needed for some instructions so we use x (don't care)
         $is_beq  = $dec_bits ==? 11'bx_000_1100011;
         $is_bne  = $dec_bits ==? 11'bx_001_1100011;
         $is_blt  = $dec_bits ==? 11'bx_100_1100011;
         $is_bge  = $dec_bits ==? 11'bx_101_1100011;
         $is_bltu = $dec_bits ==? 11'bx_110_1100011;
         $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
         $is_addi = $dec_bits ==? 11'bx_000_0010011;
         $is_add  = $dec_bits ==  11'b0_000_0110011;
         
         // Will suppress warnings for all these variables
         `BOGUS_USE($is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_addi $is_add);
         /** Instruction decode END **/
         
         /***** DECODE END *****/
      @2
         /***** REGISTER FILE READ *****/
         
         // Inputs: reading the sources that are specified in the instructions
         // if reset: back to original zero values
         // (cf (line 123): https://raw.githubusercontent.com/stevehoover/RISC-V_MYTH_Workshop/c1719d5b338896577b79ee76c2f443ca2a76e14f/tlv_lib/risc-v_shell_lib.tlv)
         $rf_rd_en1 = $reset ? 1'b0 : $rs1_valid;
         $rf_rd_en2 = $reset ? 1'b0 : $rs2_valid;
         $rf_rd_index1[4:0] = $reset ? 5'b0 : $rs1;
         $rf_rd_index2[4:0] = $reset ? 5'b0 : $rs2;
         
         // Outputs: Reading the destination registers
         $src1_value[31:0] = $rf_rd_data1;
         $src2_value[31:0] = $rf_rd_data2;
         /***** REGISTER FILE READ END *****/
      @3   
         /***** ALU: ARITHMETIC LOGIC UNIT *****/
         $result[31:0] = 
              $is_addi ? $src1_value + $imm
            : $is_add  ? $src1_value + $src2_value
            : 32'bx;
         /***** ALU: ARITHMETIC LOGIC UNIT END *****/
         
         /***** REGISTER FILE WRITE **/
         
         // We never write in register 0
         // this register always holds the value 0 (RISC-V ISA)
         $rd_is_not_x0_register = !($rd[4:0] == 5'b0);
         
         // checking if everything is valid to write in destination register
         // with $valid we avoid writing to RF for invalid instructions
         $rf_wr_en = $valid && $rd_valid && $rd_is_not_x0_register;
         
         $rf_wr_index[4:0] = $rd[4:0];
         
         $rf_wr_data[31:0] = $result; 
         
         /***** REGISTER FILE WRITE END *****/
         
         /***** BRANCHES *****/
         
         // In RISC-V a `jump` is unconditional and a `branch` is conditional 
         
         // All B-Type instructions are branches
         // If this isn't a B-Type then it's not a branch and we default $taken_br to zero
         $taken_br = !$is_b_instr ? 1'b0 
            : $is_beq  ? ($src1_value == $src2_value) // branch equal
            : $is_bne  ? ($src1_value != $src2_value) // branch not equal
            
            // $is_blt is important here, when we perfom this instruction 
            // we check if the counter src1_value (r13) is lower than the limit src2_value (r14)
            // if that's the case then we must loop again because the computation isn't finished
            // if that's not the case then our comoutation is finished
            // and we can finally assign the final value to $value (r10)
            : $is_blt  ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) // branch lower than
            : $is_bge  ? ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) // branch greater than
            : $is_bltu ? ($src1_value < $src2_value) // branch lower than unsigned
            : $is_bgeu ? ($src1_value >= $src2_value) // branch greater than unsigned
            : 1'b0;  // I believe this should never happen. We've already tested the case when it's not a branch
         
         // only if the cycle is valid
         // AND if there is a taken branch (different than 0)
         // this will be used to avoid redirecting PC for invalid (branch) instructions
         $valid_taken_br = $valid && $taken_br;
         
         // Computing the Target address for Program Counter
         // If there's no taken branch this variable will simply not be used
         $br_tgt_pc[31:0] = $pc + $imm;
         
         /***** BRANCHES END *****/
         
         /***** TESTBENCH *****/
         
         // The sum of our calculation is stored on register 10
         // using >>5 in order not to stop the simulation immediately after the result
         // in that way we can see a little more cycles in the waveform (easier to visualize the result)
         // Check the logs to see the result
         *passed = |cpu/xreg[10]>>5$value == (1+2+3+4+5+6+7+8+9);
         
         /***** TESTBENCH END *****/

      // Note: Because of the magic we are using for visualisation, if visualisation is enabled below,
      //       be sure to avoid having unassigned signals (which you might be using for random inputs)
      //       other than those specifically expected in the labs. You'll get strange errors for these.

   
   // Assert these to end simulation (before Makerchip cycle limit).
   //*passed = *cyc_cnt > 40;
   *failed = 1'b0;
   
   // Macro instantiations for:
   //  o instruction memory
   //  o register file
   //  o data memory
   //  o CPU visualization
   |cpu
      m4+imem(@1)    // Args: (read stage)
      m4+rf(@2, @3)  // Args: (read stage, write stage) - if equal, no register bypass is required
      //m4+dmem(@4)    // Args: (read/write stage)
   
   m4+cpu_viz(@4)    // For visualisation, argument should be at least equal to the last stage of CPU logic
                       // @4 would work for all labs
\SV
   endmodule
