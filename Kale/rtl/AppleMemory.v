`include "video.h"
`include "AppleIO.h"

module AppleMemory(//CPU ports 
						 input clk6502,
						 input phi_1,
						 input cpuRstN,
						 input [15:0] address,
						 input [7:0] dataIn,
						 output [7:0] dataOut,
						 input rw,
						 output rdy,
						 output DMARequestN,
						 
						 //Main memory of RAM chips
						 output [15:0] addrRAMChips,
						 output RAMReadEnable_n,
						 output RAMWriteEnable_n,
						 inout [7:0] dataRAMChips,
						 input clkMem,
						 
						 //Video memory for VGA module to scan
						 input clkVGA,
						 input [15:0] addrVGA,
						 output [7:0] dataVGA,
						 
						 //On board I/O
						 output [15:0] softSwitches,
						 output speaker,
						 input PS2Clk,
						 input PS2Din,
						 output recorderOut,
						 input recorderIn,
						 output [3:0] AN,	//Joystick AN
						 input [2:0] SW,	//Joystick SW
						 output JSSTB,		//Joystick STB
						 
 						 //main FPGA clock
						 input clk,
						 
						 //If ctrl+shift+del is pressed, hardreset will be 1
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
	
	//Memory bank switchs
	reg BANK2RE;	//Read enable
	reg BANK1RE;
	wire BANK2WE;	//Write enable
	wire BANK1WE;

	reg [1:0] BANK2WECounter;
	reg [1:0] BANK1WECounter;
	assign BANK2WE = BANK2WECounter[1] == 1;
	assign BANK1WE = BANK1WECounter[1] == 1;
	
	//Memory bank soft switches
	always @(posedge phi_1 or negedge cpuRstN) begin
		if (!cpuRstN) begin
			BANK2RE <= 0;
			BANK1RE <= 0;
			BANK2WECounter <= 0;
			BANK1WECounter <= 0;
		end
		else begin
			case (address & 16'b1111_1111_1111_1011)
				`ADD_BANK2_READONLY: begin 
						BANK2RE <= 1;
						BANK1RE <= 0;
						BANK2WECounter <= 0;
						BANK1WECounter <= 0;
					end
				`ADD_BANK1_READONLY: begin 
						BANK2RE <= 0;
						BANK1RE <= 1;
						BANK2WECounter <= 0;
						BANK1WECounter <= 0;
					end
				`ADD_BANK2_DISABLE_WRITEONLY: begin 
						BANK2RE <= 0;
						BANK1RE <= 0;
						if (BANK2WECounter < 2) begin
							BANK2WECounter <= BANK2WECounter + 2'b1;
						end
						else
							BANK2WECounter <= BANK2WECounter;
						BANK1WECounter <= 0;
					end
				`ADD_BANK1_DISABLE_WRITEONLY: begin 
						BANK2RE <= 0;
						BANK1RE <= 0;
						if (BANK1WECounter < 2) begin
							BANK1WECounter <= BANK1WECounter + 2'b1;
						end
						else
							BANK1WECounter <= BANK1WECounter;
						BANK2WECounter <= 0;
					end
				`ADD_BANK2_DISABLE: begin 
						BANK2RE <= 0;
						BANK2WECounter <= 0;
						BANK1RE <= 0;
						BANK1WECounter <= 0;
					end
				`ADD_BANK1_DISABLE: begin 
						BANK2RE <= 0;
						BANK2WECounter <= 0;
						BANK1RE <= 0;
						BANK1WECounter <= 0;
					end
				`ADD_BANK2_ENABLE: begin 
						BANK2RE <= 1;
						BANK1RE <= 0;
						if (BANK2WECounter < 2)
							BANK2WECounter <= BANK2WECounter + 2'b1;
						else
							BANK2WECounter <= BANK2WECounter;
						BANK1WECounter <= 0;
					end
				`ADD_BANK1_ENABLE: begin 
						BANK2RE <= 0;
						BANK1RE <= 1;
						if (BANK1WECounter < 2)
							BANK1WECounter <= BANK1WECounter + 2'b1;
						else
							BANK1WECounter <= BANK1WECounter;
						BANK2WECounter <= 0;
					end
				default: begin
						BANK2RE <= BANK2RE;
						BANK1RE <= BANK1RE;
						BANK2WECounter <= BANK2WECounter;
						BANK1WECounter <= BANK1WECounter;
					end
			endcase
		end
	end
	
	//address bus maps to ROM address lines
	wire [13:0] ROMAddress;
	assign ROMAddress[13:0] = { (address[12] & address[13]), !(address[12]), address[11:0] };
		
	wire [7:0] ROMDataRead;
	wire [7:0] IODataRead;
	
	assign dataOut =  
							//D000 - FFFF. Normally maps to the ROM. If BANK2 of RAM card is read enabled, maps to RAM card, which just maps to RAM chips here.
							(address[15:12] >= 4'hd) ? ((BANK2RE || BANK1RE) ? memDataOut : ROMDataRead) : 
							//C000 -CFFF. Normally maps to I/O. 
							(address[15:12] == 4'hc) ? IODataRead : 
							//0000 - BFFF. Always maps to RAM.
							memDataOut;
							
	//If BANK1 enabled, address to the RAM chips from D000 - DFFF should be mapped to C000 - CFFF
	wire [15:0] cpuAddrBus = (BANK2RE || BANK2WE) && address[15:12] == 4'hd ? {4'hc, address[11:0]} : address[15:0];
	wire cpuReN = !rw;
	//Always enable writting to 0000 - BFFF. 
	//If BANK2 or BANK2 is write enabled, should also enable writing to RAM when address is D000 - FFFF.
	wire cpuWeN = !(rw == 0 && clk6502 == 1 && (address[15:12] < 4'hc || address[15:12] >= 4'hd && (BANK2WE || BANK1WE)));	
	wire [7:0] memDataOut;
	DPRAM ram(
				.sysRstN(cpuRstN),
				
				//Connect to real RAM chip
				.memAddr(addrRAMChips),
				.memData(dataRAMChips),
				.memReN(RAMReadEnable_n),
				.memWeN(RAMWriteEnable_n),
				.memClk(clkMem),
				
				//Connect to CPU bus
				.cpuAddrBus(cpuAddrBus),
				.cpuDataIn(dataIn),
				.cpuDataOut(memDataOut),
				.cpuReN(cpuReN),
				.cpuWeN(cpuWeN),
				.phi_1(phi_1),
				
				//Connect to VGA module
				.vgaAddrBus(addrVGA),
				.vgaDataOut(dataVGA)
			);
	
	//Apple ROM
	ROM appleROM(
					 .clock(clk6502),
					 .address(ROMAddress),
					 .q(ROMDataRead)
					);
					
	//Apple I/O (Onboard and expansion slots)
	AppleIO appleIO(.clk6502(clk6502), .phi_1(phi_1), .cpuRstN(cpuRstN), 
						 .address(address), .inData(dataIn), .outData(IODataRead), .rw(rw), .rdy(rdy),
						 .softSwitches(softSwitches), .speaker(speaker),
						 .PS2Clk(PS2Clk), .PS2Din(PS2Din),
						 .recorderOut(recorderOut), .recorderIn(recorderIn),
						 .AN(AN), .SW(SW), .JSSTB(JSSTB),
						 .clk(clk), .hardReset(hardReset), .F6(F6), .F10(F10),
						 //OSD screen address and data
						 .OSDScrAddr(OSDScrAddr),
						 .OSDScrData(OSDScrData),
						 
						 .RxD(RxD), .TxD(TxD),
						 
						 .DB(DB),	//Data Bus
						 .phases(phases),	//Address Bus
						 .phaseChange(phaseChange),
						 .powerOn(powerOn),
						 .dskDEVSEL(dskDEVSEL),
						 .dskRW(dskRW),
						 .dskRdy(dskRdy)
						 );

	//DMA for special functions
	reg DMA;
	assign DMARequestN = !DMA;
	always @(negedge cpuRstN or posedge clk6502) begin 
		if (!cpuRstN)
			DMA <= 0;
		else begin
		end
	end
endmodule