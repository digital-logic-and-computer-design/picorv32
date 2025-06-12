
# Overall

Use icebreaker board as example.  Targets in picorvsoc/icebreaker*

.core files provide project structure...Used/created by???

CSE 260M PicoSOC image is in

# Memory Map

RAM:   0x00000000 - 0x00020000
Flash: 0x00100000 - ???

0-?   Text (instructions) and constants
Stack starts at 0x200000


Memory Mapped I/O:


And value for "x" will work

0x02000000: FLASH Interface config
0x02000004: UART Clock divider
0x02000008: UART Data (write to transmit (blocking); read to...read!)

0x03xxxxxx: RGB LED

0x04xxxxx0: LED & Key LEDs
0x04xxxxx4: LED & Key displays 0-3
0x04xxxxx8: LED & Key displays 4-7
0x04xxxxxC: LED & Key keys

0x05000000: Enable FLASH / Disable UART  (0 in LSB = Flash, or 1 for UART)



# Linking Images

From picosvsoc directory:

```
ln -f upduino3_fw.bin ../../images/upduino3_fw.bin
ln -f upduino3.bin ../../images/upduino3.bin
```


# ICEBREAKER

Makefile: Done
firmeware.c: Done
sections.lds : Ok for initial
   // Needs to define all things for actual RAM execution
   // Replicate what's done with the .sidata (copy from flash to RAM)

start.s
  // Needs to copy .text section to RAM

picosoc relies on picorv & associate

# Makefile finds

## Dependencies

Can generate verilog FROM yosys output json file.  Verilog that matches the synthesized circuit.  Ex: `yosys -p 'read_json icebreaker.json; write_verilog icebreaker_syn.v'`

Converting .elf files to other formats:
`objcopy` can copy to .hex/.bin (verilog and deployment?)

.elf files are build from `gcc` and _sections.lds, start.s, and firmware.c (linker script, start, and c version of firmware).  Ex: `gcc $(CFLAGS) -DICEBREAKER -mabi=ilp32 -march=rv32ic -Wl,-Bstatic,-T,icebreaker_sections.lds,--strip-debug -ffreestanding -nostdlib -o icebreaker_fw.elf start.s firmware.c`

`icebreaker_sections.lds` is built from just `sections.lds`

Firmware is programmed to hardware at address 1M: `iceprog -o 1M icebreaker_fw.bin`

Full, executable image is combo of bitstream and firmware (both programmed)

sim is raw, model sym
synsim is simulation of synthesized model that is back-ported to verilog.

# Linker Stuff

To show symbols in final and if they are defined or not (t vs. u) and global (capital) or not: `riscv64-unknown-elf-nm upduino3_fw.elf`
(Everything should be local in final .elf, but perhaps locals in .o files of multifile)
B & D appear to be from sections definitions (D for initialized dat / .data and B for un-inint /.bss?)

See assemble of final:
`riscv64-unknown-elf-objdump -D upduino3_fw.elf`

(Origin version: Main is at 1011c4 AND jal to main is 1011c4)

Show load headers:
`riscv64-unknown-elf-readelf -l  upduino3_fw.elf`
And
`riscv64-unknown-elf-readelf -S  upduino3_fw.elf`


Show sections:
`riscv64-unknown-elf-objdump -h upduino3_fw.elf`







#ifdef ICEBREAKER
#  define MEM_TOTAL 0x20000 /* 128 KB */
#elif UPDUINO3
#  define MEM_TOTAL 0x20000 /* 128 KB */
#elif HX8KDEMO
#  define MEM_TOTAL 0x200 /* 2 KB */
#else
#  error "Set -DICEBREAKER or -DUPDUINO3 or -DHX8KDEMO when compiling firmware.c"
#endif

MEMORY
{
    FLASH (rx)      : ORIGIN = 0x00100000, LENGTH = 0x400000 /* entire flash, 4 MiB */
    RAM   (xrw)     : ORIGIN = 0x00000000, LENGTH = MEM_TOTAL
}

SECTIONS {
    /* Bootloader code goes in FLASH */
    .text  :
    {
        . = ALIGN(4);
        *(bootloader)
        . = ALIGN(4);
        _etext = .;  /* End of bootloader / start of text, constants, and initialized memory to copy over*/
        _sirodata = .;  /* start of init values for RO data */
    } >FLASH

    /* The program code and other data goes into RAM eventually, but is loaded from FLASH */
    .textdata :
    {
        . = ALIGN(4);
        /* All the rest of this will need load addresses distinct from virtual addresses
           It will ALL be copied to RAM before main starts */
        _srodata = .;      /* start of read only data */
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)        /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
        . = ALIGN(4);
        _sidata = .;  /* This is used by the startup in order to initialize the .data secion */
    } > RAM AT> FLASH


    /* This is the initialized data section
    The program executes knowing that the data is in the RAM
    but the loader puts the initial values in the FLASH (inidata).
    It is one task of the startup to copy the initial values from FLASH to RAM. */
    .data :
    {
        . = ALIGN(4);
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
        _ram_start = .;    /* create a global symbol at ram start for garbage collector */
        . = ALIGN(4);
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */
        *(.sdata)           /* .sdata sections */
        *(.sdata*)          /* .sdata* sections */
        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
        _erodata = .;      /* End read only data */
    } > RAM AT> FLASH

    /* Uninitialized data section */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)

        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end; used by startup code */
    } > RAM

    /* this is to define the start of the heap, and make sure we have a minimum size */
    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;    /* define a global symbol at heap start */
    } >RAM
}
