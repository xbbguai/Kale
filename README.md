# Kale
An Apple II+ Retro

This is an FPGA project that implements an Apple II+ (may be able to upgrade to IIe/c later on)  computer with the following features:

* Disk II simulator which supports .DSK disk image files 
* VGA video output capable of 16bit color depth
* PS2 keyboard port
* Cassette recorder in/out
* Joystick socket
* 512k RAM



## General Description of Kale

The core of Kale is an Altera Cyclone IV EP4CE10F17C8N FPGA chip, which implements a 6502 CPU, Apple II+ ROM, character generator and all other on board I/O circuits including VGA output, PS2 keyboard, speaker, etc.

Kale uses one single 512k * 8 bits/10ns SRAM chip as its main memory. At this moment, only 64k bytes are used. I’m going to use another 64k bytes so that it has 128k memory just like an Apple IIe. There are still 384k memory left, I’m considering using these bytes to implements some extended video modes.

Kale uses an STM32F103C8T6 microcontroller to simulate disk I/O. FatFs is integrated
 to manage a file system on SD/MMC card. The disk simulator can read/write/format a .dsk disk image file.

Three development environments are required: </br>
* Quartus II 64-Bit Version 14.1.0 Build 186 Web Edition</br>
	This is the environment for developing Altera Cyclone IV applications.</br>
* STM32CubeIDE Version 1.2.0</br>
	This is the official IDE from ST for STM32 microcontrollers.</br>
* LcEDA (or EasyEDA)</br>
	This is a free online EDA software.(  https://lceda.cn )

This project uses the ag_6502 ip core written by Oleg Odintsov. (https://opencores.org/projects/ag_6502)

## The Files in This Repository

Files are separated into 3 parts:</br>
* The schematic/PCB drawings.</br>
> /EDA</br>
>> /PDF		: The schematic and pcb drawings in PDF format.</br>
>> /Lceda		: The LcEDA json file.</br>
>> /Gerber	: The pcb gerber file. </br>
* Verilog HDL source codes</br>
> /Kale</br>
>> /rtl		: Source code files</br>
>> /ROMs		: ROM images</br>
>> \par		: Project and environment files</br>
* STM32F103 Ksource codes (for disk simulator)</br>
> /AppleDiskIISimulator</br>
>> /Drivers	:STM32F103 CMSIS and HAL library</br>
>> /Inc		:Include files</br>
>> /Middleware	:Middle ware(s) used in this project. FatFS.</br>
>> /Src		:Source code files</br>
>> /Startup	:STM32F103C8Tx start up file</br>

NOTE: Apple II+ ROM image is NOT INCLUDED in this repository. It’s easy to get this ROM image, for example you can download one from AppleWin project, and convert it to .mif format for Quartus II to load. The ROM file name should be “apple2_plus.mif” and must be put in /Kale/ROMs folder.


## Technical Notes

### Video

The core VGA video module can generate frames of 640*480 pixels with 16bit color.
Since Apple II shares its main memory with video memory, the VGA module should be able to read the main memory without interfering with the 6502 CPU during its read/write cycle. 

A PLL is used to generate a 100MHz clock and then divided by 4 to be 25MHz for the VGA module. There are 4 100MHz cycles (each one 10ns) in every 25MHz cycle (40ns). Two 10ns cycles are allocated to VGA module to read main memory, the other 2 cycles are used as CPU read/write cycles. For each two cycles, the first cycle is used to put address to memory chip’s address port, the second cycle is used to read/write data.

As max video resolution of Apple II+ is 280 * 192, every pixel is multiplied by 2, both horizontally and vertically so that it becomes 560 * 384. Compares to the standard VGA resolution of 640 * 480, there are still 80 horizontal pixels and 96 vertical pixels not used, I just left them blank.

### Disk simulator

It’s simple if there is only one disk image file in the SD card. But I think it is better to let Kale has the ability to manage a file system on the SD card, and capable of selecting disk image files from the file system. It requires a microcontroller. Trying to build a file system with only FPGA is crazy, though there are people who have succeeded.

I preferred STM32F103 microcontroller and FatFs file system. I did not use Nios because I’m not familiar with it and I’m not sure if the FPGA chip I chose has enough resources left to hold an Nios mcu.

It turns out to be extremely tricky to implement an Apple II disk driver simulator. Encoder and decoder are needed because the disk format is not straightforward. Data are nibblized to be stored on the media. The read/write procedure is time critical, but I still have problems on synchronizing data and status when STM32 disk simulator program communicates with FPGA hardware. I used the 6502 CPU rdy signal, it worked but dramatically affects the write back performance.  

I made on OSD page for the disk simulator. Anytime you press F6 on the keyboard, you’ll see the OSD page on the screen. You can choose a .dsk image file to be “inserted” into the disk drive. Press ESC to exit the OSD screen. Please note that you cannot select a new disk image file when the disk simulator is reading/writing.

### Joystick

Standard Apple II joystick port has 5V logic. Kale does not supply 5V on the joystick port, instead it has 3.3V output. This does not affect a standard joystick but if your joystick needs 5V power supply for any purpose, it may not work.

I did not use time base chip/circuits to read the analog potentiometers as Apple II does. There are A/D ports in STM32 chip, I just used the A/D functions and send data to FPGA through serial port.

