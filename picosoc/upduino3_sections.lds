MEMORY
{
    FLASH (rx) : ORIGIN = 0x00100000, LENGTH = 0x400000
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 0x20000
}
SECTIONS {
    .bootloader :
    {
        . = ALIGN(4);
        *(.bootloader)
        . = ALIGN(4);
        _etext = .;
        _sidata = _etext;
    } >FLASH
    .data : AT( _sidata )
    {
        . = ALIGN(4);
        _sdata = .;
        _ram_start = .;
        . = ALIGN(4);
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } >RAM
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >RAM
    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;
    } >RAM
}
