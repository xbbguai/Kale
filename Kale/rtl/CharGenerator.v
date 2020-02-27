module FlashTimer(input clkVGA,
						input rst_n,
						output reg flash);
	parameter TIME_ELAPSE = 24'd8119270;
	
	reg [23:0] counter;
	
	always @(posedge clkVGA or negedge rst_n) begin
		if (!rst_n)
			begin
				counter <= TIME_ELAPSE;
				flash <= 1'b0;
			end
		else
			begin
				if (counter > 24'b0)
					counter <= counter - 24'b1;
				else
					begin
						counter <= TIME_ELAPSE;
						flash <= !flash;
					end
			end
	end
endmodule

module CharGenerator(input clkVGA,
							input rst_n,
						   input [7:0] charApple,
							input [9:0] xPos,
							input [9:0] yPos,
							output  pixel);

	wire [9:0] address;
	wire [6:0] data;
	wire inverse;
	wire flash;
	wire flashTimerSignal;
	reg shouldInverse;
	
	assign inverse = charApple < 8'd64;
	assign flash = charApple < 8'd128 && !inverse;
	assign address = ((inverse ? (charApple < 8'd32 ? charApple + 8'd32 : charApple - 8'd32) : 
							(flash ? (charApple < 8'd96 ? charApple - 8'd32 : charApple - 8'd96) : 
							charApple > 8'd159 ? charApple - 8'd160 : charApple - 8'd96)) << 3) + (yPos & 10'h7);
	
	CharGeneratorROM charROM(.clock(clkVGA), .address(address), .q(data));
	FlashTimer flashTimer(clkVGA, rst_n, flashTimerSignal);
	
	always @(posedge clkVGA or negedge rst_n) begin
		if (!rst_n) begin
			shouldInverse <= 0;
		end 
		else begin
			shouldInverse <= inverse || (flashTimerSignal && flash);
		end
	end
//	always @(posedge clkVGA)
	assign	pixel = (data & (7'b1000000 >> (xPos % 7))) > 0 ? (shouldInverse ? 1'b0 : 1'b1) : (shouldInverse ? 1'b1 : 1'b0);

endmodule