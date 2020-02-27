`include "video.h"
`include "AppleIO.h"

module VGADriver(input clkVGA,
					  input rst_n,
					  
					  output hSync,	//horizontal synchronization
					  output fSync,	//frame synchronization
					  output [15:0] pixelOutput,	//RGB to be put to output signal.
					  
					  input [15:0] pixelInput,
					  output [9:0] xPos,	//current x position to be shown
					  output [9:0] yPos, //y position of current scanning line
					  output [9:0] xPosAhead	//xPosAhead is ahead of PREFATCH_PIXELS pixel(s) because pixel data should be read from RAM/ROM, which may take more ticks.
					 );

	parameter H_SYNC = 10'd96;	//horizontal params
	parameter H_BACK = 10'd48;
	parameter H_DISP = 10'd640;
	parameter H_FRONT = 10'd16;
	parameter H_TOTAL = 10'd800;
		
	parameter F_SYNC = 10'd2;	//frame params
	parameter F_BACK = 10'd33;
	parameter F_DISP = 10'd480;
	parameter F_FRONT = 10'd10;
	parameter F_TOTAL = 10'd525;
	
	parameter PREFATCH_PIXELS = 2;	//Ahead of x pixels for memory and other mechanisms to react.
	
	reg [9:0] hPixCounter;
	reg [9:0] vLineCounter;
	
	assign hSync = (hPixCounter < H_SYNC) ? 1'b0 : 1'b1;
	assign fSync = (vLineCounter < F_SYNC) ? 1'b0 : 1'b1;

	
	wire pixelDataRequest;
	assign pixelDataRequest = (hPixCounter >= H_SYNC + H_BACK - PREFATCH_PIXELS && hPixCounter < H_SYNC + H_BACK + H_DISP - PREFATCH_PIXELS && 
									vLineCounter >= F_SYNC + F_BACK && vLineCounter < F_SYNC + F_BACK + F_DISP) ? 1'b1 : 1'b0;
	assign xPosAhead = pixelDataRequest ? hPixCounter - H_BACK - H_SYNC + PREFATCH_PIXELS : H_TOTAL;
	
	assign yPos = pixelDataRequest ? vLineCounter - F_BACK - F_SYNC : F_TOTAL;
	assign xPos = xPosAhead >= PREFATCH_PIXELS ? xPosAhead - PREFATCH_PIXELS : 0;
	
	wire outputEnable;
	assign outputEnable = (hPixCounter >= H_SYNC + H_BACK && hPixCounter < H_SYNC + H_BACK + H_DISP && 
									vLineCounter >= F_SYNC + F_BACK && vLineCounter < F_SYNC + F_BACK + F_DISP) ? 1'b1 : 1'b0;
	
	assign pixelOutput = outputEnable ? pixelInput : 16'd0;

	//horizontal counter
	always @(posedge clkVGA or negedge rst_n) begin
		if (!rst_n)
			hPixCounter <= 10'd0;
		else
			begin
				if (hPixCounter < H_TOTAL - 10'd1)
					hPixCounter <= hPixCounter + 10'd1;
				else
					hPixCounter <= 10'd0;
			end
	end
	
	//frame counter
	always @(posedge clkVGA or negedge rst_n) begin
		if (!rst_n)
			vLineCounter <= 10'd0;
		else if (hPixCounter == H_TOTAL - 10'd1)
			begin
				if (vLineCounter < F_TOTAL - 10'd1)
					vLineCounter <= vLineCounter + 10'd1;
				else
					vLineCounter <= 10'd0;
			end
	end
endmodule
