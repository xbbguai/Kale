`include "video.h"
`include "AppleIO.h"

module Kale(
				input sys_clk,
				input sys_rst_n,
				
				//VGA output
				output hSync,
				output fSync,
				output [15:0] pixleOutput,
				
				//Main memory of RAM chips
				output [18:0] addrRAMChips,
				output RAMReadEnable_n,
				output RAMWriteEnable_n,
				inout [7:0] dataRAMChips,

			   //Onboard I/O
				output speaker,
				input PS2Clk,
				input PS2Din,
				output recorderOut,
				input recorderIn,
				output [3:0] AN,	//Joystick AN
				input [2:0] SW,	//Joystick SW
				output JSSTB,		//Joystick STB

				//DISK II Simulator UART I/O
			   input RxD,
			   output TxD,
				inout [7:0] DB,	//Data Bus
				output [1:0] phases,	//Head phase
				output phaseChange,	//Phase change notification
				output powerOn,
				output dskDEVSEL,
				output dskRW,
				input dskRdy
			);

	assign addrRAMChips[18:16] = 3'b0;
			
	//Clocks---
	wire clkMem;	//100MHz, memory clock
	wire clkVGA;	//25.0MHz, VGA clock
	wire clk6502;	//1.0227MHz, 6502 clock
	
	//locked is a signal from PLL to indicate that PLL is ready and stable.
	//rst_n is to combine sys_rst_n with locked to generate a usable reset signal.
	wire rst_n;
	Clock mainClock(.sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
						 .rst_n(rst_n), .clkMem(clkMem), .clkVGA(clkVGA), .clk1M(clk6502));
	
	//Reset signal for CPU
	reg cpuRstN;
	reg[1:0] cpuRstCounter;
	wire hardReset;	//This signal is from AppleMemory -> AppleIO -> PS2Keyboard
	reg[3:0] hardResetSteps;
	always @(posedge clk6502 or negedge rst_n) begin 
		if (!rst_n) begin
			cpuRstN = 0;
			cpuRstCounter = 0;
			hardResetSteps <= 0;
		end
		else begin
			if (hardReset == 1'b1) begin
				//hard reset. should destroy $3f3 or $3f4 so that $fa62 subroutine will consider it a cold start.
				cpuRstN = 0;
				cpuRstCounter = 0;
				hardResetSteps <= 1;
			end
/*			else if (hardResetSteps != 0) begin
				case (hardResetSteps)
					4'b1: begin
								addrRAMChips <= 14'h3f3; 
								RAMChip0Enable_n <= 0;
								dataRAMChips <= 0;
								RAMReadEnable_n <= 1;
								RAMWriteEnable_n <= 0;
								hardResetSteps <= hardResetSteps + 1'b1;
							end
					4'b10:begin
								addrRAMChips <= 14'h3f4; 
								RAMChip0Enable_n <= 0;
								dataRAMChips <= 0;
								RAMReadEnable_n <= 1;
								RAMWriteEnable_n <= 0;
								hardResetSteps <= hardResetSteps + 1'b1;
							end
					4'b11:begin
								hardResetSteps <= 0;
							end
					default:;
				endcase
			end
*/			else begin
				cpuRstCounter <= cpuRstCounter + 2'b01;
				if (cpuRstCounter == 3) begin
					cpuRstCounter <= 0;
					cpuRstN <= 1;
				end
			end
		end
	end
	
	//CPU DMA mechanism. When DMARequest is high, clk6502 will remain low until DMARequest goes low.
	wire DMARequestN;
	wire clk6502WithDMA;
	assign clk6502WithDMA = (clk6502 & DMARequestN);
	
	//CPU and its 3 clock phases
	wire phi_1, phi_2;
	wire [15:0] address;
	wire [7:0] dataRead;
	wire [7:0] dataWrite;
	wire rw;
	wire rdy;
   ag6502_ext_clock	PhisClock(sys_clk, clk6502, phi_1, phi_2);
	ag6502 CPU( .phi_0(clk6502WithDMA),
					.phi_1(phi_1),
					.phi_2(phi_2),
					.ab(address),
					.read(rw),
					.db_in(dataRead),
					.db_out(dataWrite),
					.rdy(rdy),//locked),
					.rst(cpuRstN), 
					.irq(1'b1), 
					.nmi(1'b1),
					.so(1'b0)
					//.sync
					);

	//OSD flag
	wire OSDF6;
	wire OSDF10;
	//OSD screen data to be processed to screen
	wire [7:0] OSDDataVGA;
	//OSD video memory write signals from AppleIO.v
	wire [9:0] OSDScrAddr;
	wire [7:0] OSDScrData;

	//Memory and I/O 
	wire [7:0] dataVGA;
	reg [15:0] addrVGA;
	wire [15:0] softSwitches;
	AppleMemory appleMemory(.clk6502(clk6502),
									.phi_1(phi_1),
									.address(address),
									.dataIn(dataWrite),
									.dataOut(dataRead),
									.rw(rw),
									.rdy(rdy),
									.DMARequestN(DMARequestN),
									
									//Main memory of RAM chips
									.addrRAMChips(addrRAMChips[15:0]),
									.RAMReadEnable_n(RAMReadEnable_n),
									.RAMWriteEnable_n(RAMWriteEnable_n),
									.dataRAMChips(dataRAMChips),
									.clkMem(clkMem),
					
									.clkVGA(clkVGA),
									.cpuRstN(cpuRstN),
									.addrVGA(addrVGA),
									.dataVGA(dataVGA),
									.softSwitches(softSwitches),
									.speaker(speaker),
									.PS2Clk(PS2Clk),
									.PS2Din(PS2Din),
									.recorderOut(recorderOut),
									.recorderIn(recorderIn),
									.AN(AN),
									.SW(SW),
									.JSSTB(JSSTB),
									
									.clk(sys_clk),
									.hardReset(hardReset),
									.F6(OSDF6),
									.F10(OSDF10),
									.OSDScrAddr(OSDScrAddr),
									.OSDScrData(OSDScrData),
									.RxD(RxD),
									.TxD(TxD),
									.DB(DB),	//Data Bus
									.phases(phases),	
									.phaseChange(phaseChange),
									.powerOn(powerOn),
									.dskDEVSEL(dskDEVSEL),
									.dskRW(dskRW),
									.dskRdy(dskRdy)
									);
	//OSD Video memory
	OSDScreenRAM osdScreenRAM(
					 .clock_a(clk6502),
					 .address_a(OSDScrAddr),
					 .data_a(OSDScrData),
					 .rden_a(0),	//Never read from this port.
					 .wren_a(1),
					 
					 .address_b({addrVGA[9:0]}),
					 .clock_b(clkVGA),
					 .data_b(8'b0),
					 .q_b(OSDDataVGA),
					 .rden_b(1'b1),
					 .wren_b(1'b0)	//Never write to this port.
				);

	parameter HBLANK = 10'd40;			//Pixels left blank from left
	parameter VBLANK = 10'd48;			//Pixels left blank from top
	parameter XSCALE = 2'd2;			//Horizontal VGA pixels per apple screen pixel.
	parameter YSCALE = 2'd2;			//Vertial VGA lines per apple screen line
	parameter SCREENWIDTH = 10'd280;		//Apple screen horizontal pixels 
	parameter SCREENHEIGHT = 10'd192;	//Apple screen vetical lines
	parameter BLANKCOLOR = 16'b0000_000000_10000;	//Color to fill in the blank area out of apple screen

	reg [15:0] pixelValue;	//The pixel value to be put into VGA output
	wire [9:0] xPosAhead;	//Current VGA x position that should read data from memory (Ahead of PREFATCH_PIXELS pixels, actually)
	wire [9:0] xPos;			//Current VGA scanning x position
	wire [9:0] yPos;			//Current VGA scanning y position
	wire  pixel;					//Current apple screen pixel value, 1 or 0
	wire [9:0] appleScreenXPos;	//Current xPos mapped to apple screen
	wire [9:0] appleScreenYPos;	//Currnet yPos mapped to apple screen
	wire [4:0] appleTextLine;	//Current line number of apple text screen. From 0 to 23
	wire [6:0] appleHorzIndex;	//Current column number of apple screen, text and graphic. From 0 to 39
	wire [3:0] appleHorzIndexBit;	//Mod 7 of appleHorzIndex, indicating a pixel in a byte.
	wire [9:0] appleScreenXPosAhead;		//Current xPos - 1 mapped to apple screen. For hi-res graphic.
	wire [6:0] appleHorzIndexAhead;		//Current column number of apple screen, text and graphic. From 0 to 39. For hi-res graphic.
	
	assign appleScreenXPos = xPos < HBLANK ? 0 : (xPos - HBLANK) / XSCALE;
	assign appleScreenYPos = yPos < VBLANK ? 0 : (yPos - VBLANK) / YSCALE;
	assign appleTextLine = appleScreenYPos[7:3];	//(appleScreenYPos >> 5'd3);
	assign appleHorzIndex = appleScreenXPos / 10'd7;
	assign appleHorzIndexBit = appleScreenXPos % 4'd7;

	assign appleScreenXPosAhead = xPosAhead < HBLANK ? 0 : (xPosAhead - HBLANK) / XSCALE;
	
	assign appleHorzIndexAhead = appleScreenXPosAhead / 10'd7;
	
	//Apple video content is from memory
	always @(*) begin
		//Address will be ahead of x,y position for PREFATCH_PIXELS pixel to be ready.
		
		//OSD F6(DISK II)
		if (OSDF6) begin
			//Text mode, address starts from 0.
			addrVGA <= {6'b0, appleTextLine[2:0], appleTextLine[4:3], appleTextLine[4:3], 3'b000} + appleHorzIndexAhead;
		end
		else begin
			//Text mode or (mixed mode and text line number >= 20)
			if (softSwitches[`TEXT_MODE] == 1'b1 || softSwitches[`MIX_MODE] && appleTextLine[4:2] == 3'b101) begin  // 3'b101 means >= 20 
				if (softSwitches[`PAGE2] == 1'b0)	//Page1
					addrVGA <= 16'h400 + {6'b0, appleTextLine[2:0], appleTextLine[4:3], appleTextLine[4:3], 3'b000} + appleHorzIndexAhead;
				else	//Page2
					addrVGA <= 16'h400 + {6'b1, appleTextLine[2:0], appleTextLine[4:3], appleTextLine[4:3], 3'b000} + appleHorzIndexAhead;
			end
			else if (softSwitches[`TEXT_MODE] == 1'b0 && softSwitches[`HIRES_MODE] == 1'b0) begin	//Lo-res mode
				if (softSwitches[`PAGE2] == 1'b0)	//Page1
					addrVGA <= 16'h400 + {6'b0, appleTextLine[2:0], appleTextLine[4:3], appleTextLine[4:3], 3'b000} + appleHorzIndex;
				else	//Page2
					addrVGA <= 16'h400 +{6'b1, appleTextLine[2:0], appleTextLine[4:3], appleTextLine[4:3], 3'b000} + appleHorzIndex;
			end
			else begin	//Hi res mode
				if (softSwitches[`PAGE2] == 1'b0)	//Page1
					addrVGA <= {3'b0, appleScreenYPos[2:0], appleScreenYPos[5:3], appleScreenYPos[7:6], appleScreenYPos[7:6], 3'b000} + 16'h2000 + (xPos < HBLANK ? 0 : (xPos + 1 - HBLANK) / XSCALE) / 10'd7;
				else	//Page2
					addrVGA <= {3'b0, appleScreenYPos[2:0], appleScreenYPos[5:3], appleScreenYPos[7:6], appleScreenYPos[7:6], 3'b000} + 16'h4000 + (xPos < HBLANK ? 0 : (xPos + 1 - HBLANK) / XSCALE) / 10'd7;
			end
		end
	end	

	wire [7:0] charGenDataIn;
	assign charGenDataIn = OSDF6 ? OSDDataVGA : dataVGA;
	VGADriver coreDriver(clkVGA, rst_n, hSync, fSync, pixleOutput, pixelValue, xPos, yPos, xPosAhead);
	CharGenerator charGen(clkVGA, rst_n, charGenDataIn, appleScreenXPos, appleScreenYPos, pixel); 
	
	reg prevPixel;
	reg [15:0] pixelValueShift;
	
	always @(posedge clkVGA) begin
		if (xPos <= HBLANK || yPos < VBLANK || xPos >= HBLANK + SCREENWIDTH * XSCALE || appleScreenYPos >= SCREENHEIGHT) begin
			pixelValue <= softSwitches[`FILLED_EMPTY_BKG] ? BLANKCOLOR : 16'b0;
			prevPixel <= 0;
			pixelValueShift <= 16'b0;
		end
		else begin
			if (OSDF6 || softSwitches[`TEXT_MODE] == 1'b1 || softSwitches[`MIX_MODE] == 1'b1 && appleScreenYPos > 159) begin
				pixelValue <= (pixel && (!softSwitches[`FULL_SCAN_LINES] || yPos % 2 == 1) ? (softSwitches[`GREEN_TEXT_COLOR] ? 16'b00000_111111_00000 : OSDF6 ? 16'b11111_111111_00000 : 16'hffff) : 16'h0);
			end
			else if (softSwitches[`TEXT_MODE] == 1'b0 && softSwitches[`HIRES_MODE] == 1'b0)	begin
				if (!softSwitches[`FULL_SCAN_LINES] || yPos % 2 == 1) begin
					case ((appleScreenYPos % 10'd8) < 4 ? (dataVGA & 8'hf) : (dataVGA >> 4))
						//Colors
						0: pixelValue <= `GR_CLR_0;
						1: pixelValue <= `GR_CLR_1;
						2: pixelValue <= `GR_CLR_2;
						3: pixelValue <= `GR_CLR_3;
						4: pixelValue <= `GR_CLR_4;
						5: pixelValue <= `GR_CLR_5;
						6: pixelValue <= `GR_CLR_6;
						7: pixelValue <= `GR_CLR_7;
						8: pixelValue <= `GR_CLR_8;
						9: pixelValue <= `GR_CLR_9;
						10: pixelValue <= `GR_CLR_10;
						11: pixelValue <= `GR_CLR_11;
						12: pixelValue <= `GR_CLR_12;
						13: pixelValue <= `GR_CLR_13;
						14: pixelValue <= `GR_CLR_14;
						15: pixelValue <= `GR_CLR_15;
						default: pixelValue <= 0;
					endcase
				end
				else
					pixelValue <= 0;
			end
			else if (softSwitches[`TEXT_MODE] == 1'b0 && softSwitches[`HIRES_MODE] == 1'b1)	begin
				if (!softSwitches[`FULL_SCAN_LINES] || yPos % 2 == 1) begin
					if (dataVGA[appleHorzIndexBit] == 1'b1) begin
						if (prevPixel) begin
							case (pixelValue)
								`HGR_CLR_BLUE:		pixelValue <= `HGR_CLR_BLUE_L;
								`HGR_CLR_ORANGE:	pixelValue <= `HGR_CLR_ORANGE_L;
								`HGR_CLR_PURPLE:	pixelValue <= `HGR_CLR_PURPLE_L;
								`HGR_CLR_GREEN:	pixelValue <= `HGR_CLR_GREEN_L;
								default:	pixelValue <= `HGR_CLR_WHITE;
							endcase
						end
						else begin
							if (dataVGA[7] == 1'b1)	begin //Two different color patterns according to bit 7 of video memory.
								if (appleHorzIndexBit[0] == 1'b1 && appleHorzIndex[0] == 1'b0 || appleHorzIndexBit[0] == 1'b0 && appleHorzIndex[0] == 1'b1) begin
									pixelValueShift <= `HGR_CLR_ORANGE;	//Orange
									pixelValue <= pixelValueShift;
								end
								else begin
									pixelValueShift <= `HGR_CLR_BLUE;	//Blue
									if (appleScreenXPos == 0)
										pixelValue <= `HGR_CLR_BLUE_L;
									else
										pixelValue <= pixelValueShift;
								end
							end
							else begin
								//This pattern is even more tricky.
								//The first pixel only occupies first half of an apple pixel, the second pixel occupies second half and the next first half apple pixel, etc.
								if (appleHorzIndexBit[0] == 1'b1 && appleHorzIndex[0] == 1'b0 || appleHorzIndexBit[0] == 1'b0 && appleHorzIndex[0] == 1'b1)
									pixelValue <= `HGR_CLR_GREEN;	//Green
								else
									pixelValue <= `HGR_CLR_PURPLE;	//Purple
								pixelValueShift <= 16'b0;
							end
						end
						prevPixel <= 1'b1;
					end
					else begin
						if (pixelValueShift) begin 
							pixelValue <= pixelValueShift;
							pixelValueShift <= 16'b0;
						end
						else begin
							pixelValue <= `HGR_CLR_BLACK;
/*							case (pixelValue)
								`HGR_CLR_BLUE_L:		pixelValue <= `HGR_CLR_BLUE_S;
								`HGR_CLR_ORANGE_L:	pixelValue <= `HGR_CLR_ORANGE_S;
								`HGR_CLR_PURPLE_L:	pixelValue <= `HGR_CLR_PURPLE_S;
								`HGR_CLR_GREEN_L:	pixelValue <= `HGR_CLR_GREEN_S;
								`HGR_CLR_BLUE:		pixelValue <= `HGR_CLR_BLUE_S;
								`HGR_CLR_ORANGE:	pixelValue <= `HGR_CLR_ORANGE_S;
								`HGR_CLR_PURPLE:	pixelValue <= `HGR_CLR_PURPLE_S;
								`HGR_CLR_GREEN:	pixelValue <= `HGR_CLR_GREEN_S;
								default:	pixelValue <= `HGR_CLR_BLACK;
							endcase
*/
						end
						prevPixel <= 1'b0;
					end
				end
				else
					pixelValue <= 0;
			end
		end
	end
	
endmodule