.section .text
.global load
.type load, @function

load:
        add     a4, a0, zero    // result
        add     a3, a0, zero    // Counter
        add     a2, a1, zero    // Limit
loop:
        add     a4, a3, a4      // Adding the counter value to the result
        addi    a3, a3, 1       // Increasing the counter by 1
        blt     a3, a2, loop    // If counter lower than limit then loop again
        add     a0, a4, zero    // Stores the result into a0 to be returned
        ret                     // From the documentation: Values are returned from functions in integer registers a0 and a1 and floating-point registers fa0 and fa1
