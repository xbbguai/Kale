`ifndef _APPLE_IO_h
`define _APPLE_IO_h

`define ADD_TEXT_MODE_OFF 16'hc050
`define ADD_TEXT_MODE_ON 16'hc051
`define ADD_MIX_MODE_OFF 16'hc052
`define ADD_MIX_MODE_ON 16'hc053
`define ADD_PAGE2_OFF 16'hc054
`define ADD_PAGE2_ON 16'hc055
`define ADD_HIRES_MODE_OFF 16'hc056
`define ADD_HIRES_MODE_ON 16'hc057
`define ADD_AN0_OFF 16'hc058
`define ADD_AN0_ON 16'hc059
`define ADD_AN1_OFF 16'hc05a
`define ADD_AN1_ON 16'hc05b
`define ADD_AN2_OFF 16'hc05c
`define ADD_AN2_ON 16'hc05d
`define ADD_AN3_OFF 16'hc05e
`define ADD_AN3_ON 16'hc05f

`define ADD_KEYBOARD_IN 16'hc000
`define ADD_KEYBOARD_CLR 16'hc010
`define ADD_RCD_OUT 16'hc020
`define ADD_SPK_OUT 16'hc030
`define ADD_GAMEPORT_STB 16'hc040
`define ADD_RCD_IN1 16'hc060
`define ADD_RCD_IN2 16'hc068
`define ADD_SW01 16'hc061
`define ADD_SW02 16'hc069
`define ADD_SW11 16'hc062
`define ADD_SW12 16'hc06a
`define ADD_SW21 16'hc063
`define ADD_SW22 16'hc06b
`define ADD_PLD01 16'hc064
`define ADD_PLD02 16'hc06c
`define ADD_PLD11 16'hc065
`define ADD_PLD12 16'hc06d
`define ADD_PLD21 16'hc066
`define ADD_PLD22 16'hc06e
`define ADD_PLD31 16'hc067
`define ADD_PLD32 16'hc06f
`define ADD_PLD_TRIG 16'hc070

//Memory expansion
`define ADD_BANK2_READONLY 16'hc080
`define ADD_BANK1_READONLY 16'hc088
`define ADD_BANK2_DISABLE_WRITEONLY 16'hc081
`define ADD_BANK1_DISABLE_WRITEONLY 16'hc089
`define ADD_BANK2_DISABLE 16'hc082
`define ADD_BANK1_DISABLE 16'hc08a
`define ADD_BANK2_ENABLE 16'hc083
`define ADD_BANK1_ENABLE 16'hc08b


//Soft switches of APPLE II
`define TEXT_MODE 0
`define MIX_MODE  1
`define PAGE2	   2
`define HIRES_MODE 3
`define RESV0	4
`define RESV1	5
`define RESV2 6
`define RESV3	7
//Extended switches of my Apple II
`define FULL_SCAN_LINES 8			//Write C000 0 = FULL, 1 = INTERLACE  //50% scan lines so that it looks just like Apple II.
`define FILLED_EMPTY_BKG 9			//Write C000 2 = black, 3 = dark blue,( 4 = dark green, 3 = grey, 4 = dark amber)
`define GREEN_TEXT_COLOR 10		//Write C000 10 = white, 11 = green

//Special key definition
`define SK_CTRLSHIFTDEL 0
`define SK_KEYPADUP 1
`define SK_KEYPADDOWN 2
`define SK_KEYPADLEFT 3
`define SK_KEYPADRIGHT 4
`define SK_KEYPADSLASH 5	// '/'
`define SK_KEYPADSTERISTIC 6	// '*'
`define SK_KEYPADMINUS 7	// '-'
`define SK_KEYF6 8			// F6 for DISK II OSD
`define SK_KEYF10 9			// F10 for system OSD

`endif