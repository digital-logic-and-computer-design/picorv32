.section .bootloader

start:
# Update LEDs: RGB off
li a0, 0x03000000
li a1, 0x00000000  # Light white?
sw a1, 0(a0)

# zero-initialize register file
addi x1, zero, 0
# x2 (sp) is initialized by reset
addi x3, zero, 0
addi x4, zero, 0
addi x5, zero, 0
addi x6, zero, 0
addi x7, zero, 0
addi x8, zero, 0
addi x9, zero, 0
addi x10, zero, 0
addi x11, zero, 0
addi x12, zero, 0
addi x13, zero, 0
addi x14, zero, 0
addi x15, zero, 0
addi x16, zero, 0
addi x17, zero, 0
addi x18, zero, 0
addi x19, zero, 0
addi x20, zero, 0
addi x21, zero, 0
addi x22, zero, 0
addi x23, zero, 0
addi x24, zero, 0
addi x25, zero, 0
addi x26, zero, 0
addi x27, zero, 0
addi x28, zero, 0
addi x29, zero, 0
addi x30, zero, 0
addi x31, zero, 0

# LED & Key: left light
li a0, 0x04000000
li a1, 0x1
sw a1, 0(a0)

# zero initialize entire scratchpad memory
li a1, 0x04000004
li a0, 0x00000000
setmemloop:
sw a0, 0(a0)
sw a0, 0(a1)
addi a0, a0, 4
blt a0, sp, setmemloop

# Update LEDs: 2 lights
li a0, 0x04000000
li a1, 0x3
sw a1, 0(a0)

# copy data section
la a0, _sidata
la a1, _sdata
la a2, _edata
bge a1, a2, end_init_data
loop_init_data:
lw a3, 0(a0)
sw a3, 0(a1)
addi a0, a0, 4
addi a1, a1, 4
blt a1, a2, loop_init_data
end_init_data:

# Update LEDs: 3lights
li a0, 0x04000000
li a1, 0x7
sw a1, 0(a0)

# zero-init bss section
la a0, _sbss
la a1, _ebss
bge a0, a1, end_init_bss
loop_init_bss:
sw zero, 0(a0)
addi a0, a0, 4
blt a0, a1, loop_init_bss
end_init_bss:

# Update LEDs: 4 lights
li a0, 0x04000000
li a1, 0xF
sw a1, 0(a0)

# Call _start & main  (WILL NOT RETURN)
call _start


.global flashio_worker_begin
.global flashio_worker_end

.balign 4

flashio_worker_begin:
# a0 ... data pointer
# a1 ... data length
# a2 ... optional WREN cmd (0 = disable)

# address of SPI ctrl reg
li   t0, 0x02000000

# Set CS high, IO0 is output
li   t1, 0x120
sh   t1, 0(t0)

# Enable Manual SPI Ctrl
sb   zero, 3(t0)

# Send optional WREN cmd
beqz a2, flashio_worker_L1
li   t5, 8
andi t2, a2, 0xff
flashio_worker_L4:
srli t4, t2, 7
sb   t4, 0(t0)
ori  t4, t4, 0x10
sb   t4, 0(t0)
slli t2, t2, 1
andi t2, t2, 0xff
addi t5, t5, -1
bnez t5, flashio_worker_L4
sb   t1, 0(t0)

# SPI transfer
flashio_worker_L1:
beqz a1, flashio_worker_L3
li   t5, 8
lbu  t2, 0(a0)
flashio_worker_L2:
srli t4, t2, 7
sb   t4, 0(t0)
ori  t4, t4, 0x10
sb   t4, 0(t0)
lbu  t4, 0(t0)
andi t4, t4, 2
srli t4, t4, 1
slli t2, t2, 1
or   t2, t2, t4
andi t2, t2, 0xff
addi t5, t5, -1
bnez t5, flashio_worker_L2
sb   t2, 0(a0)
addi a0, a0, 1
addi a1, a1, -1
j    flashio_worker_L1
flashio_worker_L3:

# Back to MEMIO mode
li   t1, 0x80
sb   t1, 3(t0)

ret

.balign 4
flashio_worker_end:

.text
_start:
# Clear LEDs
li a0, 0x03000000
sw zero, 0(a0)  # Update LEDs: RGB off
# Clear IO Board LEDs / 7-segments
li a0, 0x04000000
sw zero, 0(a0)  # Update LEDs: RGB off
sw zero, 4(a0)  # Update LEDs: RGB off
sw zero, 8(a0)  # Update LEDs: RGB off

# Disable FLASH
li a0, 0x02000000
sw zero, 0(a0)  # Disable FLASH

# Enable UART / Disconnect flash
li a0, 0x05000000
li a1, 1
sw a1, 0(a0)

# call main (reset all used registers)
addi a0, zero, 0
addi a1, zero, 0
addi a2, zero, 0
addi a3, zero, 0
addi a4, zero, 0
call main

li a0, 0x04000004
li a1, 0x5E3F5479 # dOnE
sw a1, 0(a0)  # Update LEDs: RGB on
sw zero, 4(a0)  # Update LEDs: RGB off
loop:
j loop


# ************************************************************************
# ** RUNTIME SUPPORT
# RISC-V GCC runtime library functions for 32-bit unsigned division and modulo
.global __udivsi3
__udivsi3:
    divu a0, a0, a1
    jr ra

 .global __umodsi3
__umodsi3:
  /* Compute __udivdi3((uint32_t)a0, (uint32_t)a1); cast a1 to uint32_t.  */
    remu a0, a0, a1
    jr ra

