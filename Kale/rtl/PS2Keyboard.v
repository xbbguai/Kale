
`include "AppleIO.h"

//Key code 
`define KEY_A	9'h1c
`define KEY_B	9'h32
`define KEY_C	9'h21
`define KEY_D	9'h23
`define KEY_E	9'h24
`define KEY_F	9'h2b
`define KEY_G	9'h34
`define KEY_H	9'h33
`define KEY_I	9'h43
`define KEY_J	9'h3b
`define KEY_K	9'h42
`define KEY_L	9'h4b
`define KEY_M	9'h3a
`define KEY_N	9'h31
`define KEY_O	9'h44
`define KEY_P	9'h4d
`define KEY_Q	9'h15
`define KEY_R	9'h2d
`define KEY_S	9'h1b
`define KEY_T	9'h2c
`define KEY_U	9'h3c
`define KEY_V	9'h2a
`define KEY_W	9'h1d
`define KEY_X	9'h22
`define KEY_Y	9'h35
`define KEY_Z	9'h1a
`define KEY_0	9'h45
`define KEY_1	9'h16
`define KEY_2	9'h1e
`define KEY_3	9'h26
`define KEY_4	9'h25
`define KEY_5	9'h2e
`define KEY_6	9'h36
`define KEY_7	9'h3d
`define KEY_8	9'h3e
`define KEY_9	9'h46
`define KEY_BACK_QUOTE	9'h0e
`define KEY_MINUS	9'h4e
`define KEY_EQUAL	9'h55
`define KEY_BACK_SLASH	9'h5d
`define KEY_BKSP	9'h66
`define KEY_SPACE	9'h29
`define KEY_TAB	9'h0d
`define KEY_CAPS	9'h58
`define KEY_LSHIFT	9'h12
`define KEY_LCTRL	9'h14
`define KEY_LGUI	9'h11f
`define KEY_LALT	9'h11
`define KEY_RSHIFT	9'h59
`define KEY_RCTRL	9'h114
`define KEY_RGUI	9'h127
`define KEY_ALT	9'h111
`define KEY_APPS	9'h12f
`define KEY_ENTER	9'h5a
`define KEY_ESC	9'h76
`define KEY_F1	9'h5
`define KEY_F2	9'h6
`define KEY_F3	9'h4
`define KEY_F4	9'hc
`define KEY_F5	9'h3
`define KEY_F6	9'hb
`define KEY_F7	9'h83
`define KEY_F8	9'ha
`define KEY_F9	9'h1
`define KEY_F10	9'h9
`define KEY_F11	9'h78
`define KEY_F12	9'h7
`define KEY_PRNT_SCRN 	9'h17c	//e0 12 e0 7c
`define KEY_SCROLL	9'h7e
//`define KEY_PAUSE
`define KEY_LSQ_BRACE	9'h54
`define KEY_INSERT	9'h170
`define KEY_HOME	9'h16c
`define KEY_PGUP	9'h17d
`define KEY_DELETE	9'h171
`define KEY_END	9'h169
`define KEY_PGDN	9'h17a
`define KEY_UP	9'h175
`define KEY_LEFT	9'h16b
`define KEY_DOWN	9'h172
`define KEY_RIGHT	9'h174
`define KEY_NUM	9'h77
`define KEY_KP_SLASH	9'h14a
`define KEY_KP_STERISTIC	9'h7c
`define KEY_KP_MINUS	9'h7b
`define KEY_KP_PLUS 	9'h79
`define KEY_KP_ENTER	9'h15a
`define KEY_KP_DOT	9'h71
`define KEY_KP_0	9'h70
`define KEY_KP_1	9'h69
`define KEY_KP_2	9'h72
`define KEY_KP_3	9'h7a
`define KEY_KP_4	9'h6b
`define KEY_KP_5	9'h73
`define KEY_KP_6	9'h74
`define KEY_KP_7	9'h6c
`define KEY_KP_8	9'h75
`define KEY_KP_9	9'h7d
`define KEY_RSQ_BRACE	9'h5b
`define KEY_SEMI_COL	9'h4c
`define KEY_QUOTE	9'h52
`define KEY_COMMA	9'h41
`define KEY_DOT	9'h49
`define KEY_SLASH	9'h4a

module PS2Keyboard(input clk,
						 input rst_n,
						 input PS2Clk,
						 input PS2Din,
						 
						 output reg[7:0] ascii,
						 input clearData,
						 output reg keyState,	//1 = down, 0 = up
						 
						 //For extra keyboard functions
						 output reg[9:0] specialKey
						 );

	parameter DISABLE_CAPS = 1;	//For apple ii/ii+, don't enable capslock.
 	
	//PS Clock negedge detector　　
	wire negEdgePS2Clk; 
	reg clkSave0, clkSave1, clkSave2, clkSave3;
	always @ (posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			clkSave0 <= 1'b0;
			clkSave1 <= 1'b0;
			clkSave2 <= 1'b0;
			clkSave3 <= 1'b0;
		end
		else begin
			clkSave0 <= PS2Clk;
			clkSave1 <= clkSave0;
			clkSave2 <= clkSave1;
			clkSave3 <= clkSave2;
		end
	end
	assign negEdgePS2Clk = !clkSave0 & !clkSave1 & clkSave2 & clkSave3;


	//PS2 clock counter
	reg[3:0] counter;
	reg[7:0] counterReset;	//For the signal stablization.
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			counter <= 4'd0;
			counterReset <= 8'd0;
		end
		else if (counter == 4'd11)
			counter <= 4'd0;
		else if (negEdgePS2Clk) begin
			counter <= counter + 1'b1;
			counterReset <= 8'd0;
		end
		else if (counterReset >= 8'd200) begin
			counterReset <= 8'd0;	//If next clock tick does not come in 200 clks, reset counter.
			counter <= 4'd0;
		end
		else
			counterReset <= counterReset + 8'b1;
	end

	//Previous clock edge
	reg negEdgePS2Clk_Shift;
	always @(posedge clk) negEdgePS2Clk_Shift <= negEdgePS2Clk;

	//Read PS2 Din data to dataTemp
	reg[7:0] dataTemp;
	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n)	
			dataTemp <= 8'd0;
		else if (negEdgePS2Clk_Shift) begin
			case (counter)
				4'd2: dataTemp[0] <= PS2Din;
				4'd3: dataTemp[1] <= PS2Din;
				4'd4: dataTemp[2] <= PS2Din;
				4'd5: dataTemp[3] <= PS2Din;
				4'd6: dataTemp[4] <= PS2Din;
				4'd7: dataTemp[5] <= PS2Din;
				4'd8: dataTemp[6] <= PS2Din;
				4'd9: dataTemp[7] <= PS2Din;
				default: dataTemp <= dataTemp;
			endcase
		end
		else
			dataTemp <= dataTemp;
	end

	//Decode long code and break code
	reg flagBreak;
	reg flagLongCode;
	reg shift;
	reg ctrl;
	reg capslock;
	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			flagBreak <= 1'b0;
			flagLongCode <= 1'b0;
			shift <= 1'b0;
			ctrl <= 1'b0;
			capslock <= 1'b1;
			ascii <= 8'd0;
			specialKey <= 0;
			keyState <= 0;
		end
		else if (counter == 4'd11) begin
			if (dataTemp == 8'hE0)	 //Long code flag
				flagLongCode <= 1'b1; 
			else if (dataTemp == 8'hF0) begin //Break code flag
				flagBreak <= 1'b1; 
				keyState <= 0;
			end
			else begin 
				//Convert keycode to apple ii ascii
				if (dataTemp == `KEY_LSHIFT || dataTemp == `KEY_RSHIFT)
					shift <= ~flagBreak;
				if (dataTemp == `KEY_LCTRL || dataTemp == `KEY_RCTRL)
					ctrl <= ~flagBreak;
				if (dataTemp == `KEY_CAPS && !flagBreak && !DISABLE_CAPS)
					capslock <= ~capslock;
				if (flagBreak) begin
					case ({flagLongCode, dataTemp})
						`KEY_DELETE: specialKey[`SK_CTRLSHIFTDEL] <= 1'b0;
						`KEY_KP_2:	 specialKey[`SK_KEYPADDOWN] <= 1'b0;
						`KEY_KP_4:	 specialKey[`SK_KEYPADLEFT] <= 1'b0;
						`KEY_KP_6:	 specialKey[`SK_KEYPADRIGHT] <= 1'b0;
						`KEY_KP_8:	 specialKey[`SK_KEYPADUP] <= 1'b0;
						`KEY_KP_SLASH:			specialKey[`SK_KEYPADSLASH] <= 1'b0;
						`KEY_KP_STERISTIC:	specialKey[`SK_KEYPADSTERISTIC] <= 1'b0;
						`KEY_KP_MINUS:			specialKey[`SK_KEYPADMINUS] <= 1'b0;
						`KEY_F6:	 	 specialKey[`SK_KEYF6] <= 1'b0;
						`KEY_F10: 	 specialKey[`SK_KEYF10] <= 1'b0;
						default:;
					endcase
				end
				else begin
					case ({flagLongCode, dataTemp})
						`KEY_A:					ascii <= ctrl ?  8'h80 + 8'd1 : shift ? 8'h80 + 8'd65 : capslock ? 8'h80 + 8'd65 : 8'h80 + 8'd97;// 9'h1c
						`KEY_B:					ascii <= ctrl ?  8'h80 + 8'd2 : shift ? 8'h80 + 8'd66 : capslock ? 8'h80 + 8'd66 : 8'h80 + 8'd98;// 9'h32
						`KEY_C:					ascii <= ctrl ?  8'h80 + 8'd3 : shift ? 8'h80 + 8'd67 : capslock ? 8'h80 + 8'd67 : 8'h80 + 8'd99;// 9'h21
						`KEY_D:					ascii <= ctrl ?  8'h80 + 8'd4 : shift ? 8'h80 + 8'd68 : capslock ? 8'h80 + 8'd68 : 8'h80 + 8'd100;// 9'h23
						`KEY_E:					ascii <= ctrl ?  8'h80 + 8'd5 : shift ? 8'h80 + 8'd69 : capslock ? 8'h80 + 8'd69 : 8'h80 + 8'd101;// 9'h24
						`KEY_F:					ascii <= ctrl ?  8'h80 + 8'd6 : shift ? 8'h80 + 8'd70 : capslock ? 8'h80 + 8'd70 : 8'h80 + 8'd102;// 9'h2b
						`KEY_G:					ascii <= ctrl ?  8'h80 + 8'd7 : shift ? 8'h80 + 8'd71 : capslock ? 8'h80 + 8'd71 : 8'h80 + 8'd103;// 9'h34
						`KEY_H:					ascii <= ctrl ?  8'h80 + 8'd8 : shift ? 8'h80 + 8'd72 : capslock ? 8'h80 + 8'd72 : 8'h80 + 8'd104;// 9'h33
						`KEY_I:					ascii <= ctrl ?  8'h80 + 8'd9 : shift ? 8'h80 + 8'd73 : capslock ? 8'h80 + 8'd73 : 8'h80 + 8'd105;// 9'h43
						`KEY_J:					ascii <= ctrl ? 8'h80 + 8'd10 : shift ? 8'h80 + 8'd74 : capslock ? 8'h80 + 8'd74 : 8'h80 + 8'd106;// 9'h3b
						`KEY_K:					ascii <= ctrl ? 8'h80 + 8'd11 : shift ? 8'h80 + 8'd75 : capslock ? 8'h80 + 8'd75 : 8'h80 + 8'd107;// 9'h42
						`KEY_L:					ascii <= ctrl ? 8'h80 + 8'd12 : shift ? 8'h80 + 8'd76 : capslock ? 8'h80 + 8'd76 : 8'h80 + 8'd108;// 9'h4b
						`KEY_M:					ascii <= ctrl ? 8'h80 + 8'd13 : shift ? 8'h80 + 8'd77 : capslock ? 8'h80 + 8'd77 : 8'h80 + 8'd109;// 9'h3a
						`KEY_N:					ascii <= ctrl ? 8'h80 + 8'd14 : shift ? 8'h80 + 8'd78 : capslock ? 8'h80 + 8'd78 : 8'h80 + 8'd110;// 9'h31
						`KEY_O:					ascii <= ctrl ? 8'h80 + 8'd15 : shift ? 8'h80 + 8'd79 : capslock ? 8'h80 + 8'd79 : 8'h80 + 8'd111;// 9'h44
						`KEY_P:					ascii <= ctrl ? 8'h80 + 8'd16 : shift ? 8'h80 + 8'd80 : capslock ? 8'h80 + 8'd80 : 8'h80 + 8'd112;// 9'h4d
						`KEY_Q:					ascii <= ctrl ? 8'h80 + 8'd17 : shift ? 8'h80 + 8'd81 : capslock ? 8'h80 + 8'd81 : 8'h80 + 8'd113;// 9'h15
						`KEY_R:					ascii <= ctrl ? 8'h80 + 8'd18 : shift ? 8'h80 + 8'd82 : capslock ? 8'h80 + 8'd82 : 8'h80 + 8'd114;// 9'h2d
						`KEY_S:					ascii <= ctrl ? 8'h80 + 8'd19 : shift ? 8'h80 + 8'd83 : capslock ? 8'h80 + 8'd83 : 8'h80 + 8'd115;// 9'h1b
						`KEY_T:					ascii <= ctrl ? 8'h80 + 8'd20 : shift ? 8'h80 + 8'd84 : capslock ? 8'h80 + 8'd84 : 8'h80 + 8'd116;// 9'h2c
						`KEY_U:					ascii <= ctrl ? 8'h80 + 8'd21 : shift ? 8'h80 + 8'd85 : capslock ? 8'h80 + 8'd85 : 8'h80 + 8'd117;// 9'h3c
						`KEY_V:					ascii <= ctrl ? 8'h80 + 8'd22 : shift ? 8'h80 + 8'd86 : capslock ? 8'h80 + 8'd86 : 8'h80 + 8'd118;// 9'h2a
						`KEY_W:					ascii <= ctrl ? 8'h80 + 8'd23 : shift ? 8'h80 + 8'd87 : capslock ? 8'h80 + 8'd87 : 8'h80 + 8'd119;// 9'h1d
						`KEY_X:					ascii <= ctrl ? 8'h80 + 8'd24 : shift ? 8'h80 + 8'd88 : capslock ? 8'h80 + 8'd88 : 8'h80 + 8'd120;// 9'h22
						`KEY_Y:					ascii <= ctrl ? 8'h80 + 8'd25 : shift ? 8'h80 + 8'd89 : capslock ? 8'h80 + 8'd89 : 8'h80 + 8'd121;// 9'h35
						`KEY_Z:					ascii <= ctrl ? 8'h80 + 8'd26 : shift ? 8'h80 + 8'd90 : capslock ? 8'h80 + 8'd90 : 8'h80 + 8'd122;// 9'h1a
						`KEY_0:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd41 : 8'h80 + 8'd48;// 9'h45
						`KEY_1:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd33 : 8'h80 + 8'd49;// 9'h16
						`KEY_2:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd64 : 8'h80 + 8'd50;// 9'h1e
						`KEY_3:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd35 : 8'h80 + 8'd51;// 9'h26
						`KEY_4:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd36 : 8'h80 + 8'd52;// 9'h25
						`KEY_5:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd37 : 8'h80 + 8'd53;// 9'h2e
						`KEY_6:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd94 : 8'h80 + 8'd54;// 9'h36
						`KEY_7:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd38 : 8'h80 + 8'd55;// 9'h3d
						`KEY_8:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd42 : 8'h80 + 8'd56;// 9'h3e
						`KEY_9:					ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd40 : 8'h80 + 8'd57;// 9'h46
						`KEY_BACK_QUOTE:		ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd126: 8'h80 + 8'd96;// 9'h0e
						`KEY_MINUS:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd95 : 8'h80 + 8'd45;// 9'h4e
						`KEY_EQUAL:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd43 : 8'h80 + 8'd61;// 9'h55
						`KEY_BACK_SLASH:		ascii <= ctrl ? 8'h80 + 8'd28 : shift ? 8'h80 + 8'd124: 8'h80 + 8'd92;// 9'h5d
						`KEY_BKSP:				ascii <= ctrl ?8'h80 + 8'd127 : shift ?  8'h80 + 8'd8 :  8'h80 + 8'd8;// 9'h66
						`KEY_SPACE:				ascii <= ctrl ?  8'd0 : shift ?  8'd0 : 8'h80 + 8'd32;// 9'h29
						`KEY_TAB:				ascii <= ctrl ?  8'd0 : shift ?  8'h80 + 8'd9 :  8'h80 + 8'd9;// 9'h0d
						`KEY_ENTER:				ascii <= ctrl ? 8'h80 + 8'd10 : shift ? 8'h80 + 8'd13 : 8'h80 + 8'd13;// 9'h5a
						`KEY_ESC:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd27 : 8'h80 + 8'd27;// 9'h76
						`KEY_LSQ_BRACE:		ascii <= ctrl ? 8'h80 + 8'd27 : shift ? 8'h80 + 8'd123: 8'h80 + 8'd91;// 9'h54
						`KEY_DELETE:begin		ascii <= 8'h80 + 8'd127;// 9'h171
													if (ctrl)
														specialKey[`SK_CTRLSHIFTDEL] <= 1'b1;
										end
						`KEY_UP:					ascii <= 8'h80 + 8'd11;// 9'h175
						`KEY_LEFT:				ascii <= 8'h80 + 8'd8;// 9'h16b
						`KEY_DOWN:				ascii <= 8'h80 + 8'd10;// 9'h172
						`KEY_RIGHT:				ascii <= 8'h80 + 8'd21;// 9'h174
						`KEY_PGUP:				ascii <= 8'h80 + 8'h17;	//Page up/down interpreted as ctrl+q / ctrl+r
						`KEY_PGDN:				ascii <= 8'h80 + 8'h18;
						//`KEY_NUM:				ascii <= ctrl ?  0 : shift ?  0 : 0;// 9'h77
						`KEY_KP_SLASH:	begin	ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd63 : 8'h80 + 8'd47;// 9'h14a
													specialKey[`SK_KEYPADSLASH] <= 1'b1;
											end
						`KEY_KP_STERISTIC: begin	ascii <= ctrl ?  8'd0 : 8'h80 + 8'd42;// 9'h7c
													specialKey[`SK_KEYPADSTERISTIC] <= 1'b1;
											end
						`KEY_KP_MINUS:	begin	ascii <= ctrl ?  8'd0 : 8'h80 + 8'd45;// 9'h7b
													specialKey[`SK_KEYPADMINUS] <= 1'b1;
											end
						`KEY_KP_PLUS: 			ascii <= ctrl ?  8'd0 : 8'h80 + 8'd43;// 9'h79
						`KEY_KP_ENTER:			ascii <= ctrl ? 8'h80 + 8'd10 : 8'h80 + 8'd13;// 9'h15a
						`KEY_KP_DOT:			ascii <= ctrl ?  8'd0 : 8'h80 + 8'd46;// 9'h71
						`KEY_KP_0:				ascii <= ctrl ?  8'd0 : 8'h80 + 8'd48;// 9'h70
						`KEY_KP_1:				ascii <= ctrl ?  8'd0 : 8'h80 + 8'd49;// 9'h69
						`KEY_KP_2:	begin		ascii <= ctrl ?  8'd0 : 8'h80 + 8'd50;// 9'h72
													specialKey[`SK_KEYPADDOWN] <= 1'b1;
										end
						`KEY_KP_3:				ascii <= ctrl ?  8'd0 : 8'h80 + 8'd51;// 9'h7a
						`KEY_KP_4:	begin		ascii <= ctrl ?  8'd0 : 8'h80 + 8'd52;// 9'h6b
													specialKey[`SK_KEYPADLEFT] <= 1'b1;
										end
						`KEY_KP_5:				ascii <= ctrl ?  8'd0 : 8'h80 + 8'd53;// 9'h73
						`KEY_KP_6:	begin		ascii <= ctrl ?  8'd0 : 8'h80 + 8'd54;// 9'h74
													specialKey[`SK_KEYPADRIGHT] <= 1'b1;
										end
						`KEY_KP_7:				ascii <= ctrl ?  8'd0 : 8'h80 + 8'd55;// 9'h6c
						`KEY_KP_8:  begin		ascii <= ctrl ?  8'd0 : 8'h80 + 8'd56;// 9'h75
													specialKey[`SK_KEYPADUP] <= 1'b1;
										end
						`KEY_KP_9:				ascii <= ctrl ?  8'd0 : 8'd57;// 9'h7d
						`KEY_RSQ_BRACE:		ascii <= ctrl ? 8'h80 + 8'd29 : shift ? 8'h80 + 8'd125: 8'h80 + 8'd93;// 9'h5b
						`KEY_SEMI_COL:			ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd58 : 8'h80 + 8'd59;// 9'h4c
						`KEY_QUOTE:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd34 : 8'h80 + 8'd39;// 9'h52
						`KEY_COMMA:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd60 : 8'h80 + 8'd44;// 9'h41
						`KEY_DOT:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd62 : 8'h80 + 8'd46;// 9'h49
						`KEY_SLASH:				ascii <= ctrl ?  8'd0 : shift ? 8'h80 + 8'd63 : 8'h80 + 8'd47;// 9'h4a
						`KEY_F6:					specialKey[`SK_KEYF6] <= 1'b1;
						`KEY_F10:				specialKey[`SK_KEYF10] <= 1'b1;
						default: ascii <= 8'd0; 
					endcase
					keyState <= 1'b1;
				end
				
				flagLongCode <= 1'b0; 
				flagBreak <= 1'b0; 
			end
		end
		else begin
			flagBreak <= flagBreak;
			flagLongCode <= flagLongCode;
			if (clearData)
				ascii[7] <= 0;
			else
				ascii <= ascii;
		end
	end
	
endmodule