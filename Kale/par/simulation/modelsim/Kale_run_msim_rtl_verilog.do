transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/pll_clk_memory.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/UART.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/states.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/PDLFreqGenerator.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/Clock.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/CharGenerator.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/AppleDISKII.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/pll_clk.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/ROM.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/CharGeneratorROM.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/OSDScreenRAM.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/RAM.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/DPRAM.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/par/db {//Mac/Home/Documents/Windows Only/Quartus/Kale/par/db/pll_clk_altpll.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/par/db {//Mac/Home/Documents/Windows Only/Quartus/Kale/par/db/pll_clk_memory_altpll.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/VGA.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/PS2Keyboard.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/AppleMemory.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/AppleIO.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/ag_6502.v}
vlog -vlog01compat -work work +incdir+//Mac/Home/Documents/Windows\ Only/Quartus/Kale/rtl {//Mac/Home/Documents/Windows Only/Quartus/Kale/rtl/Kale.v}

