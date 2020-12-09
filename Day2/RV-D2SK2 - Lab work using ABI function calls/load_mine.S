.section .text
.global load
.type load, @function

load:
                                // a0: Counter      a1: Limit
        addi    a4, a0, 0       // result
        //add   a3, a0, zero    // Counter: is useless because a0 already holds the value and can be our counter
        //add   a2, a1, zero    // Limit: is useless because a1 already holds the value
loop:
        add     a4, a0, a4      // Adding the counter value to the result
        addi    a0, a0, 1       // Increasing the counter by 1
        blt     a0, a1, loop    // If counter lower than limit then loop again
        addi    a0, a4, 0       // Stores the result into a0 to be returned
        ret                     // From the documentation: Values are returned from functions in integer registers a0 and a1 and floating-point registers fa0 and fa1
