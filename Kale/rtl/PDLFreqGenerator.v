module PDLFreqGenerator(input sys_clk,
								input start,
								input [7:0] dataToGenerate,
								output reg pulse);
	
	//10.8us = one. 0 = 4us, 255 = 255 * 10.8 + 4 = 2758us.
	//One clock tick = 0.02us. 4us = 200ticks. 2758us = 137900ticks
	reg [31:0] counter;
	 
	
	always @(posedge sys_clk or posedge start) begin
		if (start) begin
			counter <= dataToGenerate * 32'd149000 / 32'd256 + 32'd200;
			pulse <= 1;
		end 
		else begin 
			if (counter == 0)
				pulse <= 0;
			else
				counter <= counter - 13'b1;
		end
	end
								
endmodule