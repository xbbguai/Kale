module Clock(input sys_clk,
				 input sys_rst_n,
				 output rst_n,
				 output clkMem,			//100MHz
				 output reg clkVGA,		//25MHz
				 output reg clk14M,		//14.343MHz
				 output reg clk7M,		//7.172MHz
				 output reg clk2M,		//2.048MHz
				 output reg clk1M,		//1.024MHz
				 output clkph1);
	
	assign clkph1 = !clk1M;
	wire clk28M;
	
	wire locked;
	wire lockedMem;
	assign rst_n = sys_rst_n & locked & lockedMem;
	
	//PLL clock that generates 28.6868MHz (for CPU and bus)
	pll_clk mainClock(.areset(~sys_rst_n),
						  .inclk0(sys_clk),
						  //.c0(clkVGA),
						  .c1(clk28M),
						  .locked(locked)
						 );
	
	//PLL clock that generates 100MHz (for memory and VGA)
	pll_clk_memory memoryClock(.areset(~sys_rst_n),
										.inclk0(sys_clk),
										.c0(clkMem),
										.locked(lockedMem)
									  ); 
	
	//Main clocks generators
	reg counter14M;
	reg [1:0]counter7M;
	reg [2:0] counter2M;
	reg [3:0] counter1M;
	always @(posedge clk28M or negedge rst_n) begin
		if (!rst_n) begin
			counter14M <= 0;
			counter7M <= 0;
			counter2M <= 0;
			counter1M <= 0;
			clk7M <= 0;
			clk2M <= 0;
			clk1M <= 0;
		end
		else begin
			if (counter14M == 1)
				clk14M <= ~clk14M;
			counter14M <= ~counter14M;
			
			if (counter7M == 2'h2)
				clk7M <= ~clk7M;
			counter7M <= counter7M + 2'b01;
				
			if (counter2M == 3'h7) begin
				counter2M <= 0;
				clk2M <= ~clk2M;
			end 
			else
				counter2M <= counter2M + 3'b001;
			
			if (counter1M == 4'd14) begin
				clk1M <= ~clk1M;
				counter1M <= 0;
			end
			else
				counter1M <= counter1M + 4'b001;
		end
	end

	//VGA clock generator (1/4 of memory clock)
	reg counter25M;
	always @(posedge clkMem or negedge rst_n) begin
		if (!rst_n) begin
			counter25M <= 0;
			clkVGA <= 0;
		end
		else begin
			counter25M <= counter25M + 1;
			if (counter25M == 0)
				clkVGA <= ~clkVGA;
		end
	end
	
endmodule