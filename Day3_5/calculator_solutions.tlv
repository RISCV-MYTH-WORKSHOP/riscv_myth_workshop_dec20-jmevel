\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/RISC-V_MYTH_Workshop
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/RISC-V_MYTH_Workshop/bd1f186fde018ff9e3fd80597b7397a1c862cf15/tlv_lib/calculator_shell_lib.tlv'])

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)

\TLV
   |calc
      @0
         $reset = *reset;
         
      @1  
         $valid[0] = $reset ? 0 : >>1$valid[0] + 1;
         $valid_or_reset[0] = $valid || $reset;
      ?$valid_or_reset
         @1
            $val1[31:0] = >>2$out[31:0];
            $val2[31:0] = $rand1[3:0];
            
            $sum[31:0] = $val1 + $val2;
            $diff[31:0] = $val1 - $val2;
            $prod[31:0] = $val1 * $val2;
            $quot[31:0] = $val1 / $val2;
            
         @2
            $mem[31:0] = 
               $reset 
               ? 32'b0 
               : ($op[2:0] == 3'b101 // 5
                  ? >>2$out
                  : >>2$mem
                 );
            
            
            $out[31:0] = $reset ? 32'b0
                         : $op[2:0] == 3'b000 ? $sum  // 0
                         : $op[2:0] == 3'b001 ? $diff // 1
                         : $op[2:0] == 3'b010 ? $prod // 2
                         : $op[2:0] == 3'b011 ? $quot // 3
                         : $op[2:0] == 3'b100 ? >>2$mem // 4: recall
                         : >>2$out; // 5 or more: do nothing (mem or nothing)
            

      // Macro instantiations for calculator visualization(disabled by default).
      // Uncomment to enable visualisation, and also,
      // NOTE: If visualization is enabled, $op must be defined to the proper width using the expression below.
      //       (Any signals other than $rand1, $rand2 that are not explicitly assigned will result in strange errors.)
      //       You can, however, safely use these specific random signals as described in the videos:
      //  o $rand1[3:0]
      //  o $rand2[3:0]
      //  o $op[x:0]
      
   m4+cal_viz(@2) // Arg: Pipeline stage represented by viz, should be atleast equal to last stage of CALCULATOR logic.
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
   

\SV
   endmodule
