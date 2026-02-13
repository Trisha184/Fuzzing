MEMORY
{
    /* Your RAM is 16KB = 0x4000 */
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 0x4000
}

SECTIONS
{
    .text : {
        *(.text)
        *(.text.*)
    } > RAM

    .data : { *(.data) } > RAM
    .bss : { *(.bss) } > RAM
}