/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#include <stdint.h>
#include <stdbool.h>

#if defined(ICEBREAKER) || defined(UPDUINO3)
#  define MEM_TOTAL 0x20000 /* 128 KB */
#elif HX8KDEMO
#  define MEM_TOTAL 0x200 /* 2 KB */
#else
#  error "Set -DICEBREAKER or -DHX8KDEMO when compiling firmware.c"
#endif

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)



// TODO: Cleanup
// RGB LEDs
#define rgb_leds (*(volatile uint32_t*)0x03000000)
#define leds (*(volatile uint32_t*)0x04000000)
#define disp03 (*(volatile uint32_t*)0x04000004)
#define disp47 (*(volatile uint32_t*)0x04000008)
#define keys (*(volatile uint32_t*)0x0400000C)

#define MEM(location) (*(volatile uint32_t*)(location))

// --------------------------------------------------------

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

void print(const char *p)
{
	while (*p)
		putchar(*(p++));
}

void print_hex(uint32_t v, int digits)
{
	for (int i = 7; i >= 0; i--) {
		char c = "0123456789abcdef"[(v >> (4*i)) & 15];
		if (c == '0' && i >= digits) continue;
		putchar(c);
		digits = i;
	}
}

void print_uint(uint32_t v) {
	// TODO: Fix to handle 10 character unsigned integers
	char buf[8];
	buf[7] = 0; // null-terminate
	int i=6;
	while(v>0) {
		buf[i--] = '0' + (v % 10);
		v /= 10;
	}
	print(&buf[i+1]); // print from first non-zero digit
}


void print(int32_t v) {
	if (v < 0) {
		putchar('-');
		v = -v;
	}
	char buf[12];
	buf[11] = 0; // null-terminate
	int i=10;
	while(v>0) {
		buf[i--] = '0' + (v % 10);
		v /= 10;
	}
	print(&buf[i+1]); // print from first non-zero digit
}

// void print_hex(uint32_t v) {
// 	print("0x");
// 	if (v == 0) {
// 		putchar('0');
// 		return;
// 	}
// 	while(v) {
// 		int nibble = v & 0xF;
// 		if (nibble < 10)
// 			putchar('0' + nibble);
// 		else
// 			putchar('a' + nibble - 10);
// 		v >>= 4;
// 	}
// }

void print_dec(uint32_t v)
{
	if (v >= 1000) {
		print(">=1000");
		return;
	}

	if      (v >= 900) { putchar('9'); v -= 900; }
	else if (v >= 800) { putchar('8'); v -= 800; }
	else if (v >= 700) { putchar('7'); v -= 700; }
	else if (v >= 600) { putchar('6'); v -= 600; }
	else if (v >= 500) { putchar('5'); v -= 500; }
	else if (v >= 400) { putchar('4'); v -= 400; }
	else if (v >= 300) { putchar('3'); v -= 300; }
	else if (v >= 200) { putchar('2'); v -= 200; }
	else if (v >= 100) { putchar('1'); v -= 100; }

	if      (v >= 90) { putchar('9'); v -= 90; }
	else if (v >= 80) { putchar('8'); v -= 80; }
	else if (v >= 70) { putchar('7'); v -= 70; }
	else if (v >= 60) { putchar('6'); v -= 60; }
	else if (v >= 50) { putchar('5'); v -= 50; }
	else if (v >= 40) { putchar('4'); v -= 40; }
	else if (v >= 30) { putchar('3'); v -= 30; }
	else if (v >= 20) { putchar('2'); v -= 20; }
	else if (v >= 10) { putchar('1'); v -= 10; }

	if      (v >= 9) { putchar('9'); v -= 9; }
	else if (v >= 8) { putchar('8'); v -= 8; }
	else if (v >= 7) { putchar('7'); v -= 7; }
	else if (v >= 6) { putchar('6'); v -= 6; }
	else if (v >= 5) { putchar('5'); v -= 5; }
	else if (v >= 4) { putchar('4'); v -= 4; }
	else if (v >= 3) { putchar('3'); v -= 3; }
	else if (v >= 2) { putchar('2'); v -= 2; }
	else if (v >= 1) { putchar('1'); v -= 1; }
	else putchar('0');
}

char getchar_prompt(char *prompt)
{
	int32_t c = -1;

	uint32_t cycles_begin, cycles_now, cycles;
	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));

	if (prompt)
		print(prompt);

	while (c == -1) {
		__asm__ volatile ("rdcycle %0" : "=r"(cycles_now));
		cycles = cycles_now - cycles_begin;
		if (cycles > 12000000) {
			if (prompt)
				print(prompt);
			cycles_begin = cycles_now;
		}
		c = reg_uart_data;
	}
	return c;
}

char getc() {
	int c = reg_uart_data;
	while(c==-1) {
		c = reg_uart_data;
	}
	while(reg_uart_data!= -1) {
		// wait for the next character
	}
	return (char)c;
}

char getc_echo() {
	char c = getc();
	putchar(c);
	return c;
}

char fullLine[80];

char *getLine() {
	int i=0;
	char c = getc();
	while(c != '\r' && c != '\n' && i < 79) {
		if (c == 8 || c == 127) { // backspace
			if (i > 0) {
				i--;
				putchar('\b');
				putchar(' ');
				putchar('\b');
			}
		} else {
			fullLine[i++] = c;
			putchar(c);
		}
		c = getc();
	}
	if (c == '\r' || c == '\n') {
		putchar('\n');
	}
	fullLine[i] = 0; // null-terminate
	return fullLine;
}


char getchar()
{
	return getchar_prompt(0);
}


uint32_t xorshift32(uint32_t *state)
{
	/* Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs" */
	uint32_t x = *state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	*state = x;

	return x;
}

void cmd_echo()
{
	print("Return to menu by sending '!'\n\n");
	char c;
	while ((c = getchar()) != '!')
		putchar(c);
}

// --------------------------------------------------------

void delay_1s() {
	for(int k=0;k<125000;k++) {
	}
}

void delay_10ms() {
	for(int k=0;k<1250;k++) {
	}
}




void main()
{
// rgb_leds = 0x00FF00;
	// int i=0;
	// int k=0;
	// int l=0;
	// int max = 0xFF;
	// for(k=0;k<=16;k+=8) {
	// 	for(i=0;i<=max;i++) {
	// 		reg_leds = i << k;
	// 		delay_10ms();
	// 		delay_10ms();
	// 		delay_10ms();
	// 	}
	// 	for(i=0;i<=max;i++) {
	// 		reg_leds = (max-i) << k;
	// 		delay_10ms();
	// 		delay_10ms();
	// 		delay_10ms();
	// 	}
	// }
	// reg_leds = 0x000000; // turn off LED0


	// LEDs
	// leds = 0x5A;

	//
	disp03 = 0x7930305C; // disp03
	disp47 = 0x74; // disp47

	int last_keys = keys;
	while(keys!=1) { // wait for key press
		if(keys != last_keys) {
			last_keys = keys;
			leds = keys;
		}
	}













	// 104 = 57600
	// 52 = 115.2kbs
	reg_uart_clkdiv = 625;  // 9600
	delay_10ms(); // wait for UART to be ready

	print("\n");
	print("  ____  _          ____         ____\n");
	print(" |  _ \\(_) ___ ___/ ___|  ___  / ___|\n");
	print(" | |_) | |/ __/ _ \\___ \\ / _ \\| |\n");
	print(" |  __/| | (_| (_) |__) | (_) | |___\n");
	print(" |_|   |_|\\___\\___/____/ \\___/ \\____|\n");
	print("\n");

	print("Total memory: ");
	print_dec(MEM_TOTAL / 1024);
	print(" KiB\n");
	print("\n");


	print("First inst. in RAM: ");
	print_hex(MEM(0x04000004), 4);
	delay_10ms(); // wait for UART to be ready
	delay_10ms(); // wait for UART to be ready

	print("What's your name?\n");
	char *name = getLine();
	print("Hello ");
	print(name);
	print("!\n");

	return;
}
