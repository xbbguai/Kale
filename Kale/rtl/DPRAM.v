//Dualport RAM adaptor
module DPRAM(
				
				input sysRstN,
				
				//Connect to real RAM chip
				output [15:0] memAddr,
				inout [7:0] memData,
				output memReN,
				output memWeN,
				input memClk,
				
				//Connect to CPU bus
				input [15:0] cpuAddrBus,
				input [7:0] cpuDataIn,
				output reg [7:0] cpuDataOut,
				input cpuReN,
				input cpuWeN,
				input phi_1,
				
				//Connect to VGA module
				input [15:0] vgaAddrBus,
				output reg [7:0] vgaDataOut
			);
	
	
	//4 phases.
	//Phase 0: VGA read phase
	//Phase 1: CPU address phase
	//Phase 2: CPU r/w phase
	//Phase 3: VGA address phase
	reg [3:0] phases;
	always @(posedge memClk or negedge sysRstN) begin
		if (!sysRstN) 
			phases <= 4'b1;
		else if (phases == 4'b1000)
			phases <= 4'b1;
		else
			phases <= (phases << 1);
	end
		
	assign memData = (memWeN == 1'b1) ? 8'bzzzzzzzz : cpuDataIn; 
	
	assign memReN = phases == 4'b0001 ? 1'b0 :				//VGA read
						 phases == 4'b0010 ? cpuReN :				//CPU r/w
						 phases == 4'b0100 ? cpuReN :				//CPU r/w
						 phases == 4'b1000 ? 1'b0 : 1'b1;		//VGA read
						 
	assign memWeN = phases == 4'b0001 ? 1'b1 :				//
						 phases == 4'b0010 ? cpuWeN :				//CPU r/w
						 phases == 4'b0100 ? cpuWeN :				//CPU r/w
						 phases == 4'b1000 ? 1'b1 : 1'b1;		//
						 
	assign memAddr = phases == 4'b0001 ? vgaAddrBus :		//VGA 
						  phases == 4'b0010 ? cpuAddrBus :		//CPU
						  phases == 4'b0100 ? cpuAddrBus :		//CPU
						  phases == 4'b1000 ? vgaAddrBus : 16'b0;	//VGA
						 
						 
	//Read phases. Read to registers instead.
	always @(posedge memClk) begin
		case (phases)
			4'b0001: begin
					//Rise edge of VGA clock, perform read for VGA
					vgaDataOut <= memData;
				end
			4'b0100: begin
					//perform read for CPU
					if (!cpuReN && phi_1 == 0) begin
						cpuDataOut <= memData;
					end
				end
		endcase
	end
	
endmodule