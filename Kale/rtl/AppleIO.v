`include "AppleIO.h"

`define DISKII_SLOT 6

module AppleIO(
					input clk6502,
					input phi_1,
					input cpuRstN,
					input[15:0] address,
					output[7:0] outData,
					input[7:0] inData,
					input rw,
					output rdy,
					
					//Soft switches. Including graphic mode controls, etc.
					output reg[15:0] softSwitches,
					
					//Onboard I/O
					output reg speaker,		//Speaker
					output reg recorderOut,	//Recorder
					input recorderIn,
					input PS2Clk,				//keyboard port
					input PS2Din,
					output reg [3:0] AN,	//Joystick AN
					input [2:0] SW,	//Joystick SW
					output reg JSSTB,		//Joystick STB
					
					//main FPGA clock
					input clk,
					
					//If ctrl + shift + del pressed, hardReset will be 1.
					output hardReset,
					//OSD
					output F6,
					output F10,
					//OSD screen address and data
					output [9:0] OSDScrAddr,
					output [7:0] OSDScrData,
					
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
	
	
	//Onboard keyboard. Has been transfered to PS/2
	wire [7:0] keyboardAscii;
	wire clearData;
	reg clearKeyboardData;	//triggers from CPU
	reg clearKeyboardDataOSD;	//triggers when OSD starts
	reg OSDF6;   //OSD F6
	reg OSDF10;  //OSD F10
	assign F6 = OSDF6;
	assign F10 = OSDF10;
	assign clearData = OSDF6 ? clearKeyboardDataOSD : clearKeyboardData;
	wire [9:0] specialKeys;
	wire keyState;
	PS2Keyboard ps2Keyboard(.clk(clk6502), .rst_n(cpuRstN), .PS2Clk(PS2Clk), .PS2Din(PS2Din), .ascii(keyboardAscii), .clearData(clearData), .keyState(keyState),
									.specialKey(specialKeys));
	assign hardReset = specialKeys[`SK_CTRLSHIFTDEL];


	//OSD signal
	wire exitOSD;
	always @(negedge cpuRstN or posedge specialKeys[`SK_KEYF6] or posedge exitOSD or posedge clk) begin
		if (!cpuRstN) begin
			OSDF6 <= 0;
		end
		else if (exitOSD)
			OSDF6 <= 0;
		else if (specialKeys[`SK_KEYF6]) begin
			OSDF6 <= 1'b1;
		end
	end
	//System OSD not implemented
/*	always @(negedge cpuRstN or posedge specialKeys[`SK_KEYF10]) begin
		if (!cpuRstN)
			OSDF10 <= 0;
		else
			OSDF10 <= ~OSDF10;
	end
*/	
	//OSD F6 (DISK)
	reg OSDKeyStroke;
	reg [7:0] OSDKeyAscii;
	always @(negedge cpuRstN or posedge clk6502) begin
		if (!cpuRstN) begin
			clearKeyboardDataOSD <= 0;
			OSDKeyStroke <= 0;
		end
		else begin
			if (keyboardAscii[7] == 0) begin
				clearKeyboardDataOSD <= 0;
				OSDKeyStroke <= 0;
			end
			else begin
				clearKeyboardDataOSD <= 1'b1;
				if (OSDF6) begin
					OSDKeyAscii <= keyboardAscii;
					OSDKeyStroke <= 1'b1;
				end
			end
		end
	end

	//Onboard PDL pulse generators
	reg pdlStarts;
	reg [7:0] pdlData0;	//Final pdl data to be send to freq. generator. (may be from keyboard or real pdl ports)
	reg [7:0] pdlData1;
	reg [7:0] pdlData2;
	reg [7:0] pdlData3;
	wire [3:0] pdlOutput;
	wire [7:0] pdlPortData0;	//PDL data from real PDL ports
	wire [7:0] pdlPortData1;
	wire [7:0] pdlPortData2;
	wire [7:0] pdlPortData3;
	
	PDLFreqGenerator pdlFG0(.sys_clk(clk), .start(pdlStarts), .dataToGenerate(pdlPortData0), .pulse(pdlOutput[0]));
	PDLFreqGenerator pdlFG1(.sys_clk(clk), .start(pdlStarts), .dataToGenerate(pdlPortData1), .pulse(pdlOutput[1]));
	PDLFreqGenerator pdlFG2(.sys_clk(clk), .start(pdlStarts), .dataToGenerate(pdlPortData2), .pulse(pdlOutput[2]));
	PDLFreqGenerator pdlFG3(.sys_clk(clk), .start(pdlStarts), .dataToGenerate(pdlPortData3), .pulse(pdlOutput[3]));
	
	//Onboard I/O handler
	always @(negedge phi_1 or negedge cpuRstN) begin
		if (!cpuRstN) begin
			softSwitches <= 10'b0000_0001_0000_0001;	//Inialize to TEXT mode.
			speaker <= 0;
			clearKeyboardData <= 0;
			recorderOut <= 0;
			pdlData0 <= 8'h7f;
			pdlData1 <= 8'h7f;
			pdlData2 <= 8'h7f;
			pdlData3 <= 8'h7f;
			pdlStarts <= 0;
			AN[3:0] <= 4'b0;
		end
		else begin
			case (address & 16'hfff0)
				`ADD_SPK_OUT:			speaker <= ~speaker;
				`ADD_KEYBOARD_IN:		clearKeyboardData <= 1'b0;
				`ADD_KEYBOARD_CLR:	clearKeyboardData <= 1'b1;
				`ADD_RCD_OUT:			recorderOut <= ~recorderOut;
				default:;
			endcase
			case (address) 
				`ADD_TEXT_MODE_OFF:	softSwitches[`TEXT_MODE] <= 1'b0;
				`ADD_TEXT_MODE_ON:	softSwitches[`TEXT_MODE] <= 1'b1;
				`ADD_MIX_MODE_OFF:	softSwitches[`MIX_MODE] <= 1'b0;
				`ADD_MIX_MODE_ON:		softSwitches[`MIX_MODE] <= 1'b1;
				`ADD_PAGE2_OFF:		softSwitches[`PAGE2] <= 1'b0;
				`ADD_PAGE2_ON:			softSwitches[`PAGE2] <= 1'b1;
				`ADD_HIRES_MODE_OFF:	softSwitches[`HIRES_MODE] <= 1'b0;
				`ADD_HIRES_MODE_ON:	softSwitches[`HIRES_MODE] <= 1'b1;
				`ADD_AN0_OFF:			AN[0] <= 1'b0;
				`ADD_AN0_ON:			AN[0] <= 1'b1;
				`ADD_AN1_OFF:			AN[1] <= 1'b0;
				`ADD_AN1_ON:			AN[1] <= 1'b1;
				`ADD_AN2_OFF:			AN[2] <= 1'b0;
				`ADD_AN2_ON:			AN[2] <= 1'b1;
				`ADD_AN3_OFF:			AN[3] <= 1'b0;
				`ADD_AN3_ON:			AN[3] <= 1'b1;
				`ADD_PLD_TRIG:			pdlStarts <= 1'b1;
				default: 				pdlStarts <= 0;
			endcase
			if (rw == 0) begin
				if (address == `ADD_KEYBOARD_IN) begin
					case (inData)
						8'd0:	softSwitches[`FULL_SCAN_LINES] <= 1'b0;
						8'd1:	softSwitches[`FULL_SCAN_LINES] <= 1'b1;
						8'd2:	softSwitches[`FILLED_EMPTY_BKG] <= 1'b0;
						8'd3:	softSwitches[`FILLED_EMPTY_BKG] <= 1'b1;
						8'd10: softSwitches[`GREEN_TEXT_COLOR] <= 1'b0;
						8'd11: softSwitches[`GREEN_TEXT_COLOR] <= 1'b1;
						default: softSwitches <= softSwitches;
					endcase
				end
//				else
//					softSwitches <= softSwitches;
			end
			//Keyboard to PDL simulation
			if (specialKeys[`SK_KEYPADLEFT]) 
				pdlData0 <= 0;
			else if (specialKeys[`SK_KEYPADRIGHT]) 
				pdlData0 <= 8'd255;
			else 
				pdlData0 <= 8'd127;
			if (specialKeys[`SK_KEYPADUP]) 
				pdlData1 <= 0;
			else if (specialKeys[`SK_KEYPADDOWN]) 
				pdlData1 <= 8'd255;
			else 
				pdlData1 <= 8'd127;
		end
	end
	
	//Gameport STB signal is handled seperately
	always @(*) begin
		JSSTB <= !(address == `ADD_GAMEPORT_STB && clk6502 == 1);
	end
	
	//Expand I/O slots
	wire [7:0] ioSlotOuputs[7:0]; //I/O slot outputs
	wire IOSTB_n;	//I/O Strobe. When address is $c800-$cfff, IOSTB_n should be 0 on phi_2 == 1.
	assign IOSTB_n = !(phi_1 == 0 && address >= 16'hc800 && address <= 16'hcfff);
	
	wire [7:0] IOSEL_n;	//I/O Select. When address is $cx00-$cxfff, IOSEL_n should be 0 on phi_2 == 1.
	
	assign IOSEL_n[0] = !(phi_1 == 0 && address >= 16'hc000 && address <= 16'hc0ff);
	assign IOSEL_n[1] = !(phi_1 == 0 && address >= 16'hc100 && address <= 16'hc1ff);
	assign IOSEL_n[2] = !(phi_1 == 0 && address >= 16'hc200 && address <= 16'hc2ff);
	assign IOSEL_n[3] = !(phi_1 == 0 && address >= 16'hc300 && address <= 16'hc3ff);
	assign IOSEL_n[4] = !(phi_1 == 0 && address >= 16'hc400 && address <= 16'hc4ff);
	assign IOSEL_n[5] = !(phi_1 == 0 && address >= 16'hc500 && address <= 16'hc5ff);
	assign IOSEL_n[6] = !(phi_1 == 0 && address >= 16'hc600 && address <= 16'hc6ff);
	assign IOSEL_n[7] = !(phi_1 == 0 && address >= 16'hc700 && address <= 16'hc7ff);
		
	wire [7:0] DEVSEL_n;	//Device Select. When address is $c0x0 - $c0xf, DEVSEL_n should be 0 on phi_2 == 1.
	assign DEVSEL_n[0] = !(phi_1 == 0 && address >= 16'hc080 && address <= 16'hc08f);
	assign DEVSEL_n[1] = !(phi_1 == 0 && address >= 16'hc090 && address <= 16'hc09f);
	assign DEVSEL_n[2] = !(phi_1 == 0 && address >= 16'hc0a0 && address <= 16'hc0af);
	assign DEVSEL_n[3] = !(phi_1 == 0 && address >= 16'hc0b0 && address <= 16'hc0bf);
	assign DEVSEL_n[4] = !(phi_1 == 0 && address >= 16'hc0c0 && address <= 16'hc0cf);
	assign DEVSEL_n[5] = !(phi_1 == 0 && address >= 16'hc0d0 && address <= 16'hc0df);
	assign DEVSEL_n[6] = !(phi_1 == 0 && address >= 16'hc0e0 && address <= 16'hc0ef);
	assign DEVSEL_n[7] = !(phi_1 == 0 && address >= 16'hc0f0 && address <= 16'hc0ff);
	
	//Slot 6 assigned to DISK II
	AppleDISKII diskII(.clk6502(clk6502),
							 .phi_1(phi_1),
//						 input clk2M,
//						 input clk7M,
							.RstN(cpuRstN),
							.address(address),
							.dataIn(inData),
							.dataOut(ioSlotOuputs[`DISKII_SLOT]),
							.rw(rw),
							.IOSEL_n(IOSEL_n[`DISKII_SLOT]),
							.IOSTB_n(IOSTB_n),
							.DEVSEL_n(DEVSEL_n[`DISKII_SLOT]),
							.rdy(rdy),
						 
							//For communication with disk ii simulator through UART
							.clk(clk),
							.TxD(TxD),
							.RxD(RxD),
							.OSDScrAddr(OSDScrAddr),
							.OSDScrData(OSDScrData),
							.OSDKeyAscii(OSDKeyAscii),
							.OSDKeyStroke(OSDKeyStroke),
							.exitOSD(exitOSD),
							.pdlData0(pdlPortData0),
							.pdlData1(pdlPortData1),
							.pdlData2(pdlPortData2),
							.pdlData3(pdlPortData3),
							
							.DB(DB),	//Data Bus
							.phases(phases),	//phases
							.phaseChange(phaseChange),
							.powerOn(powerOn),
							.dskDEVSEL(dskDEVSEL),
							.dskRW(dskRW),
							.dskRdy(dskRdy)
							);
	
	//I/O data output to the bus
	assign outData = (address & 16'hfff0) == `ADD_KEYBOARD_IN ? (OSDF6 ? 8'h0 : keyboardAscii) :
							(address & 16'hfff0) == `ADD_KEYBOARD_CLR ? (OSDF6 ? 8'h0 : {keyState, keyboardAscii[6:0]}) :
							(address == `ADD_RCD_IN1 || address == `ADD_RCD_IN2) ? {recorderIn, 7'b0} : 
							(address == `ADD_PLD01 || address == `ADD_PLD02) ? {pdlOutput[0], 7'b0} : 
							(address == `ADD_PLD11 || address == `ADD_PLD12) ? {pdlOutput[1], 7'b0} : 
							(address == `ADD_PLD21 || address == `ADD_PLD22) ? {pdlOutput[2], 7'b0} : 
							(address == `ADD_PLD31 || address == `ADD_PLD32) ? {pdlOutput[3], 7'b0} : 
							(address == `ADD_SW01 || address == `ADD_SW02) ? ({specialKeys[`SK_KEYPADMINUS], 7'b0}     | (SW[0] << 7)) : 
							(address == `ADD_SW11 || address == `ADD_SW12) ? ({specialKeys[`SK_KEYPADSTERISTIC], 7'b0} | (SW[1] << 7)) : 
							(address == `ADD_SW21 || address == `ADD_SW22) ? ({specialKeys[`SK_KEYPADSLASH], 7'b0}     | (SW[2] << 7)) : 
//							(!DEVSEL_n[0] || !IOSEL_n[0]) ? ioSlotOuputs[0] : 
							(!DEVSEL_n[1] || !IOSEL_n[1]) ? ioSlotOuputs[1] : 
							(!DEVSEL_n[2] || !IOSEL_n[2]) ? ioSlotOuputs[2] : 
							(!DEVSEL_n[3] || !IOSEL_n[3]) ? ioSlotOuputs[3] : 
							(!DEVSEL_n[4] || !IOSEL_n[4]) ? ioSlotOuputs[4] : 
							(!DEVSEL_n[5] || !IOSEL_n[5]) ? ioSlotOuputs[5] : 
							(!DEVSEL_n[6] || !IOSEL_n[6]) ? ioSlotOuputs[6] : 
							(!DEVSEL_n[7] || !IOSEL_n[7]) ? ioSlotOuputs[7] : 
							8'h0;



endmodule