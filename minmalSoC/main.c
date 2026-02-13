#include <stdint.h>
 
// Base address must match Slave 1 in top.v
#define AES_BASE      0x10000000
 
// Using array indexing for cleaner code
volatile uint32_t *aes_regs = (volatile uint32_t*)AES_BASE;
 
// Register Offsets (divided by 4 for uint32_t pointer arithmetic)
#define AES_START_IDX   (0x00 / 4)
#define AES_PT_IDX      (0x04 / 4)
#define AES_KEY_IDX     (0x14 / 4)
#define AES_DONE_IDX    (0x2C / 4)
#define AES_CT_IDX      (0x30 / 4)
 
// For testbench visibility
#define MAGIC_RAM_DONE 0x00002000

const uint32_t expected_ct[4] = {
    0xf846cbfa,
    0x37db417b,
    0xf1da2d58,
    0x1fe33cc9,
};

// uint32_t swap32(uint32_t val) {
//     return ((val >> 24) & 0xFF) | 
//            ((val << 8)  & 0xFF0000) | 
//            ((val >> 8)  & 0xFF00) | 
//            ((val << 24) & 0xFF000000);
// }
 
void main() {
    // 1. Set the 192-bit Key (6 Words)
    aes_regs[AES_KEY_IDX + 0] = 0x8e73b0f7;
    aes_regs[AES_KEY_IDX + 1] = 0xda0e6452;
    aes_regs[AES_KEY_IDX + 2] = 0xc810f32b;
    aes_regs[AES_KEY_IDX + 3] = 0x809079e5;
    aes_regs[AES_KEY_IDX + 4] = 0x62f8ea32;
    aes_regs[AES_KEY_IDX + 5] = 0x9739b9ad;
 
    // 2. Set the 128-bit Plaintext (4 Words)
    aes_regs[AES_PT_IDX + 0] = 0x00112233;
    aes_regs[AES_PT_IDX + 1] = 0x44556677;
    aes_regs[AES_PT_IDX + 2] = 0x8899aabb;
    aes_regs[AES_PT_IDX + 3] = 0xccddeeff;
 
    // 3. Start the AES Core
    // We write 1 to start, then 0 to clear the start signal
    aes_regs[AES_START_IDX] = 1;
    aes_regs[AES_START_IDX] = 0;
 
    // 4. Wait for Valid Output (Polling)
    // We check the LSB (bit 0) of the DONE register
    while ((aes_regs[AES_DONE_IDX] & 0x1) == 0) {
        __asm__ volatile ("nop");
    }

    int match = 1;

    for (int i = 0; i < 4; i++)
    {
        if (aes_regs[AES_CT_IDX + i] != expected_ct[i])
        {
            match = 0;
            break;
        }
        
    }

    // uint32_t ct[4];

    // ct[0] = aes_regs[AES_CT_IDX + 0];
    // ct[1] = aes_regs[AES_CT_IDX + 1];
    // ct[2] = aes_regs[AES_CT_IDX + 2];
    // ct[3] = aes_regs[AES_CT_IDX + 3];

    // uint32_t expected_word0 = 0x8aad4db0;
    
 
    // 5. Read back one word of Ciphertext just to trigger a bus read
    // volatile uint32_t dummy = aes_regs[AES_CT_IDX];
 
    // 6. Signal Success to the Testbench
    volatile uint32_t *success = (volatile uint32_t*)MAGIC_RAM_DONE;
    if (match)
    {
        *success = 123456789;
    } else
    {
        *success = 0xDEADBEEF;
    }
    
    
    
 
    while(1) { 
        __asm__ volatile ("nop"); 
    }
}