#include "custom_ops.S"
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
li a1, 0x04000004  # Display process on lower seven segment displays
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

# Update LEDs: 3 lights
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



.text
.balign 16
irq_handler:
  # Save registers
  picorv32_setq_insn(q3, x2)  # Save x2 into q3

  # la uses aiupc... bad here
  lui x2, %hi(irq_save)
	addi x2, x2, %lo(irq_save)
  sw x3, 0(x2)  # Save ra
  sw x4, 4(x2)  # Save ra
  sw x5, 8(x2)  # Save ra
  sw x6, 12(x2)  # Save ra
  sw x7, 16(x2)  # Save ra
  sw x8, 20(x2)  # Save ra
  # NOTE: x10 is a0;  Ecalls intentionally change it; Should not be used for other interrupts and not restored for ecalls
  # Use only x2-x8 below

  picorv32_getq_insn(x2, q1)  # Get the value of q1 into x2 = Interrupt source
  andi x2,x2,0b100
  beqz x2, irq_check_timer
  li x2, 0x04000004  # Display process on lower seven segment displays
  li x3, 0x7C1C6D    # buS
  sw x3, 0(x2)  # Show the PC of the ecall
irq_bus_error:
  j irq_bus_error

irq_check_timer:
  picorv32_getq_insn(x2, q1)  # Get the value of q1 into x2 = Interrupt source
  andi x2,x2,0b001
  beqz x2, irq_check_ecall
  # TODO: timer checks go here (if used)

  j irq_check_ecall


irq_check_ecall:
  picorv32_getq_insn(x2, q1)  # Get the value of q1 into t1 = Interrupt source
  andi x2,x2,0b010  # Check if it's an ecall
  beq x2, zero, irq_after_ecall

  # It's an ecall, ebreak, or invalid instruction
  picorv32_getq_insn(x2, q0)  # Get the value of q0 (PC of return)
  # zero the low bit
  # Subtract 4
  addi x2,x2,-4 # Back up 4 bytes
  # andi x2,x2,0xFFFFFFFE  # Clear the low bit (to make it a valid instruction address)
irq_load_instruction:
  li x3, 0x04000004
  mv x4, zero
  lh x4, 0(x2)  # Load the instruction's last two bytes
  li x5, 0x00000073   # Encoded 32-bit ecall
  beq x5, x4, irq_is_ecall  # If it's not an ecall, we don't handle it

  li x2, 0x04000004  # Ebreak instruction
  li x3, 0x04546D70
  sw x3, 0(x2)  # Update disp (inSt)
  li x3, 0x7C775E
  sw x3, 4(x2)  # Update disp (bad)
  j irq_freeze

irq_is_ecall:
  # check each ecall
  # RGB LEDs
  li x2, 0x160  # Set RGB LEDs
  beq a0,x2, irq_set_RGB_leds
  li x2, 0x161  # get LEDs
  beq a0,x2, irq_get_RGB_leds

  # LED & Key Board I/O
  li x2, 0x150  # Set row LEDs
  beq a0,x2, irq_set_row_leds
  li x2, 0x151  # get row LEDs
  beq a0,x2, irq_get_row_leds
  li x2, 0x152  # Set Displays 0-3
  beq a0,x2, irq_set_disp03
  li x2, 0x153  # get Displays 0-3
  beq a0,x2, irq_get_disp03
  li x2, 0x154  # Set Displays 4-7
  beq a0,x2, irq_set_disp47
  li x2, 0x155  # get Displays 4-7
  beq a0,x2, irq_get_disp47
  li x2, 0x156  # Get buttons
  beq a0,x2, irq_get_buttons

  # UART
  li x2, 0x170  # write UART
  beq a0,x2, irq_uart_write
  li x2, 0x171  # read UART
  beq a0,x2, irq_uart_read

  li x2, 4
  beq a0,x2, irq_print_string  # Ecall 4 is the print_string ecall
  li x2, 11
  beq a0,x2, irq_print_char  # Ecall 11 is the print_char ecall

  li x2, 10
  beq a0,x2, irq_exit1  # Ecall 10 is exit

  li x2, 17
  beq a0,x2, irq_exit2  # Ecall 17 is exit with return code

  li x2, 1
  beq a0,x2, irq_print_int

  # TODO: The normal terminal Ecalls : 0x130 and 0x131 for read from console. See readme.md
  # TODO:  9 is sbrk

  # Unsupported ecall message
  li x2, 0x04000004  # Displays 0-3
  li x3, 0x7C775E # bAd
  sw x3, 4(x2)
  li x3, 0x79  # E
  sw x3, 0(x2)  # Update disp (bad)
  j irq_freeze

  j irq_after_ecall

## RGB LED ecall handlers
irq_set_RGB_leds:    # 0x160
  li x2, 0x03000000  # RGB
  sw a1, 0(x2)       # Update LEDs
  j irq_after_ecall

irq_get_RGB_leds:    # 0x161
  li x2, 0x03000000  # RGB
  lw a0, 0(x2)       # Get value
  j irq_after_ecall

## Led & Key Board I/O ecall handlers
irq_set_row_leds:    # 0x150
  li x2, 0x04000000  # Row of leds
  sw a1, 0(x2)       # Update LEDs
  j irq_after_ecall

irq_get_row_leds:   # 0x151
  li x2, 0x04000000  # row of
  lw a0, 0(x2)       # Get value
  j irq_after_ecall

irq_set_disp03:   # 0x152
  li x2, 0x04000004  # Displays 0-3
  sw a1, 0(x2)       # Update Displays
  j irq_after_ecall

irq_get_disp03:   # 0x153
  li x2, 0x04000004  # Displays 0-3
  lw a0, 0(x2)       # Get value
  j irq_after_ecall

irq_set_disp47:   # 0x154
  li x2, 0x04000008  # Displays 4-7
  sw a1, 0(x2)       # Update Displays
  j irq_after_ecall

irq_get_disp47:   # 0x155
  li x2, 0x04000008  # Displays 4-7
  lw a0, 0(x2)       # Get value
  j irq_after_ecall

irq_get_buttons:   # 0x156
  li x2, 0x0400000C  # Buttons
  lw a0, 0(x2)       # Get value
  j irq_after_ecall

### UART ecall handlers
irq_uart_write:   # 0x170
irq_print_char:   # 11 (0xB)
  li x2, 0x02000008  # UART
  sb a1, 0(x2)       # Write byte to UART
  j irq_after_ecall

irq_uart_read:   # 0x171
  li x2, 0x02000008  # UART
  lb a0, 0(x2)       # Read byte from UART
  j irq_after_ecall

irq_print_string:
  # a1 = address of string to print
  li x2, 0x02000008  # UART
  li x3, 0          # index
irq_print_string_loop:
  lb x4, 0(a1)      # Load byte from string
  beqz x4, irq_after_ecall  # If null terminator, exit
  sb x4, 0(x2)      # Write byte to UART
  addi a1, a1, 1    # Move to next byte in string
  j irq_print_string_loop

irq_exit1:  # Ecall 10 is exit
  li x2, 0x04000004  # Display process on lower seven segment displays
  li x3, 0x5E3F5479    # dOnE
  sw x3, 4(x2)  # Show the "done" of the ecall
  li x3, 0
  sw x3, 0(x2)  # No result to show
  j irq_freeze

irq_exit2:  # Ecall 17 is exit
  li x2, 0x04000004  # Display process on lower seven segment displays
  li x3, 0x5E3F54F9    # dOnE
  sw x3, 4(x2)  # Show the "done of the ecall
  mv x3, a1
  sw x3, 0(x2)  # The result to show
  j irq_freeze

irq_print_int:
  li x2, 0x02000008  # UART     # if a1 is negative, print '-' first
  bgez a1, irq_print_int_positive
irq_print_int_negative:
  neg a1, a1        # Make a1 positive
  li x3, '-'
  sb x3, 0(x2)      # Write '-' to UART
irq_print_int_positive:
  # a1 is now positive, print it
  li x3, 10         # Base 10
  la x5, irq_print_int_buffer_end  # Buffer for printing integers
  sb zero, -1(x5)  # Null-terminate the buffer
  addi x5, x5, -1   # Move buffer pointer back
irq_print_int_loop:
  divu x4, a1, x3   # Divide a1 by 10
  remu a6, a1, x3   # Get the remainder (last digit)
  addi a6, a6, '0'  # Convert to ASCII
  sb a6, -1(x5)     # Store the digit in the buffer
  addi x5, x5, -1   # Move buffer pointer back
  mv a1, x4         # Update a1 to the quotient
  bnez a1, irq_print_int_loop  # If a1 is not zero, continue
  # Print the buffer
  mv a1, x5  # Move buffer pointer to a1
  j irq_print_string  # Call the print_string handler

irq_after_ecall:
irq_handler_done:
  lui x2, %hi(irq_save)
	addi x2, x2, %lo(irq_save)
  lw x3, 0(x2)
  lw x4, 4(x2)
  lw x5, 8(x2)
  lw x6, 12(x2)
  lw x7, 16(x2)
  lw x8, 20(x2)

	picorv32_getq_insn(x2, q3)  # Get the value of q3 into x2 (restore sp)
	picorv32_retirq_insn()

irq_freeze:
  j irq_freeze


# ************************************************************************
_start:
# Enable IRQs (all)
picorv32_maskirq_insn(zero, zero)
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

# Set UART clock divider for 9600 bps
li a0, 0x02000004
li a1, 625
sw a1, 0(a0)  # Set UART clock divider for 9600 bps

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

.data
irq_save:
.align 4
    .space 128  # Space for saving registers during IRQ handling
irq_print_int_buffer:
    .space 12  # Buffer for printing integers (max 10 digits + sign + null terminator)
irq_print_int_buffer_end:
    .align 4
