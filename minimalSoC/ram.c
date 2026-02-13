#include <stdint.h>
 
void main() {
    // These addresses must be within the RAM range defined in the Bus Decoder
    volatile uint32_t *magic_char = (uint32_t*)0x00001000;
    volatile uint32_t *magic_done = (uint32_t*)0x00002000;
 
    // 1. Write 'A' to the magic character address
    *magic_char = 0x41;
 
    // 2. Write the success integer
    *magic_done = 123456789;
 
    // 3. Loop forever
    while(1) { __asm__("nop"); }
}