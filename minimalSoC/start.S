.section .text
.global _start
_start:
    // 1. Initialize Stack Pointer to the END of your 16KB RAM
    li sp, 0x00003FFC  
    // 2. Clear the Global Pointer (standard RISC-V practice)
    li gp, 0           
    // 3. Jump to C
    jal ra, main       
_trap:
    // If main ever returns or the CPU crashes
    j _trap