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



 // TODOs: LED&Key board;  RGB Led drivers

`ifdef PICOSOC_V
`error "icebreaker.v must be read before picosoc.v!"
`endif

`define PICOSOC_MEM ice40up5k_spram

module upduino3 (
	// input clk,  // Clock will be internal

	// TODO: Make Internal and shared with flash
	output ser_tx,
	input ser_rx,

	output ledr_n,
	output ledg_n,
	output ledb_n,

	// output ledr_n,
	// output ledg_n,

	output flash_csb,
	output flash_clk,
	inout  flash_io0,
	inout  flash_io1,
	// inout  flash_io2,
	// inout  flash_io3

    output tm_strobe,      // TM1638 Strobe
    output tm_clock,       // TM1638 Clock
    inout  tm_dio          // TM1638 Data
);
	parameter integer MEM_WORDS = 32768;

/*

 flash_csb  must be 1 for UART
 flash_io0 is serial_txd
 flash_io1 is serial_rxd

#set_io serial_txd 14 # FPGA transmit to USB  / MISO / flash_io0
#set_io serial_rxd 15 # FPGA receive from USB / MOSI / flash_io1
#set_io spi_cs 16 # Drive high to ensure that the SPI flash is disabled / flash_csb

*/
	wire flash_io2, flash_io3;  // Not used


    // 6MHz clock
	wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b11")) inthosc(.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));

	// Reset circuit / delay
	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;
	always @(posedge clk) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	wire [7:0] leds;
	assign ledr_n = ~leds[0];
	assign ledg_n = ~leds[1];
	assign ledb_n = ~leds[2];

	wire flash_io0_oe, flash_io0_do, flash_io0_di;
	wire flash_io1_oe, flash_io1_do, flash_io1_di;
	wire flash_io2_oe, flash_io2_do, flash_io2_di;
	wire flash_io3_oe, flash_io3_do, flash_io3_di;

	// Configure the FLASH memory pins
	SB_IO #(
		.PIN_TYPE(6'b 1010_01), // Output tristate; input
		.PULLUP(1'b 0)          // No pullup
	) flash_io_buf [1:0] (
		.PACKAGE_PIN({flash_io1, flash_io0}),
		.OUTPUT_ENABLE({flash_io1_oe, flash_io0_oe}),
		.D_OUT_0({flash_io1_do, flash_io0_do}),
		.D_IN_0({flash_io1_di, flash_io0_di})
	);

	wire        iomem_valid;
	reg         iomem_ready;
	wire [3:0]  iomem_wstrb;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	reg  [31:0] iomem_rdata;

	reg [31:0] gpio;
	assign leds = gpio[7:0];

    // **** Display module interface signals & module
    wire [7:0] display0, display1, display2, display3, display4, display5, display6, display7, bleds;
    wire [7:0] keys;
    // // ************************************************
    ledandkey ledAndKey(.clock(clk), .reset(~resetn),
                        .tm_strobe(tm_strobe), .tm_clock(tm_clock), .tm_dio(tm_dio),
                        .display0(display0),
                        .display1(display1),
                        .display2(display2),
                        .display3(display3),
                        .display4(display4),
                        .display5(display5),
                        .display6(display6),
                        .display7(display7),
                        .leds(bleds),
                        .keys(keys));

	always @(posedge clk) begin
		if (!resetn) begin
			gpio <= 0;
		end else begin
			iomem_ready <= 0;
			// 0x03 00 00 00 = GPIO (LEDs)
			if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h 03) begin
				iomem_ready <= 1;
				iomem_rdata <= gpio;
				if (iomem_wstrb[0]) gpio[ 7: 0] <= iomem_wdata[ 7: 0];
				if (iomem_wstrb[1]) gpio[15: 8] <= iomem_wdata[15: 8];
				if (iomem_wstrb[2]) gpio[23:16] <= iomem_wdata[23:16];
				if (iomem_wstrb[3]) gpio[31:24] <= iomem_wdata[31:24];
			end
			// 0x04 00 00 XX = Led&Key
			if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h 04) begin
				iomem_ready <= 1;
				// Address
				//    00->03 are LEDs (only 00 used),
				//    04->07 are displays 0-4,
				//    07->0A are displays 5-7
				//    0B is keys
				// a
				case(iomem_addr[3:2])
					2'b00: begin
						iomem_rdata <= bleds[7:0]; // LEDs
						if (iomem_wstrb[0]) bleds[ 7: 0] <= iomem_wdata[ 7: 0];
					end
					2'b01: begin
						iomem_rdata <= {display3, display2, display1, display0}; // Displays 3-0
						if (iomem_wstrb[0]) display0 <= iomem_wdata[ 7: 0];
						if (iomem_wstrb[1]) display1 <= iomem_wdata[ 15: 8];
						if (iomem_wstrb[2]) display2 <= iomem_wdata[ 23: 16];
						if (iomem_wstrb[3]) display3 <= iomem_wdata[ 31: 24];
					end
					2'b10: begin
						iomem_rdata <= {display7, display6, display5, display4}; // Displays 3-0
						if (iomem_wstrb[0]) display4 <= iomem_wdata[ 7: 0];
						if (iomem_wstrb[1]) display5 <= iomem_wdata[ 15: 8];
						if (iomem_wstrb[2]) display6 <= iomem_wdata[ 23: 16];
						if (iomem_wstrb[3]) display7 <= iomem_wdata[ 31: 24];
					end
					2'b11: begin
						iomem_rdata <= keys; // Keys
					end
				endcase
			end
		end
	end

	picosoc #(
		.BARREL_SHIFTER(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_FAST_MUL(1),
		.MEM_WORDS(MEM_WORDS)
	) soc (
		.clk          (clk         ),
		.resetn       (resetn      ),

		.ser_tx       (ser_tx      ),
		.ser_rx       (ser_rx      ),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.irq_5        (1'b0        ),
		.irq_6        (1'b0        ),
		.irq_7        (1'b0        ),

		.iomem_valid  (iomem_valid ),
		.iomem_ready  (iomem_ready ),
		.iomem_wstrb  (iomem_wstrb ),
		.iomem_addr   (iomem_addr  ),
		.iomem_wdata  (iomem_wdata ),
		.iomem_rdata  (iomem_rdata )
	);
endmodule
