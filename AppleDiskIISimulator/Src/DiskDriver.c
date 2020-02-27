#include "fatfs.h"
#include "Nib.h"
#include <string.h>
#include "DiskDrive.h"
#include "main.h"
#include "DiskOSD.h"
#include "disk_sdmmc.h"

#define FLASH_ADDRESS 0x800f800

DiskDrive diskDrives[DISK_DRIVES];
int selectedDrive = 0;

static int allDirty;
void InitDiskDrives()
{
	memset((void*)& diskDrives, 0, sizeof(diskDrives));
	diskDrives[0].headPhase = 0;
	diskDrives[1].headPhase = 0;

	int n = 1;
	allDirty = 0;
	for (int i = 0; i < SECTORS_PER_TRACK; i++)
	{
		allDirty |= n;
		n = n << 1;
	}

	//Read saved file name from flash
    int count = 0;
    while (count < _MAX_LFN)
    {
        diskDrives[0].fileName[count] = *(char *)(FLASH_ADDRESS + count * 2);
        diskDrives[1].fileName[count] = *(char *)(FLASH_ADDRESS + count * 2 + 1);
        count++;
    }
    diskDrives[0].fileName[_MAX_LFN - 1] = 0;
    diskDrives[1].fileName[_MAX_LFN - 1] = 0;

    //Load disk images.
	FRESULT res = f_open(&diskDrives[0].fileObj, diskDrives[0].fileName, FA_READ | FA_WRITE);
	if (res != FR_OK)
	{
	}
	res = f_open(&diskDrives[1].fileObj, diskDrives[1].fileName, FA_READ | FA_WRITE);
	if (res != FR_OK)
	{
	}
}

static void FlushDirtyTrack(int drive)
{
	int i;

	if (diskDrives[drive].trackFormatted)
	{
		//yes, this track is formatted. do nothing to this track and let read command reload the track.
		diskDrives[drive].trackFormatted = 0;
		diskDrives[drive].dirtySectors = 0;
	}
	else for (i = 0; i < SECTORS_PER_TRACK; i++)
	{
		uint32_t n = (1 << i);
		if ((diskDrives[drive].dirtySectors & n) > 0)
		{
			DenibblizeOneSector(&diskDrives[drive].fileObj, diskDrives[drive].dirtyTrack, i, NULL);
			diskDrives[drive].dirtySectors &= (~n);
			ShowTrackSector(diskDrives[drive].dirtyTrack, i, 0);
		}
	}
	diskDrives[drive].gapBytesWritten = 0;
}

BOOL LoadDiskFile(const char *fileName, int drive)
{
	if (diskDrives[drive].dirtySectors != 0)
		FlushDirtyTrack(drive);

	//Do not load disk file if this file has been used in the other drive.
	if (strcmp(fileName, diskDrives[drive == 0 ? 1 : 0].fileName) == 0)
		return FALSE;

	//fileName[0] is used as a flag indicating a file has been loaded.
	if (diskDrives[drive].fileName[0] != 0)
		f_close(&diskDrives[drive].fileObj);

	//Open file
	FRESULT res;
	if ((MMC_disk_status() & STA_PROTECT) == 0)
	{
		res = f_open(&diskDrives[drive].fileObj, fileName, FA_READ | FA_WRITE);
	}
	else
	{
		 res = f_open(&diskDrives[drive].fileObj, fileName, FA_READ);
	}
	if (res == FR_OK)
	{
		strcpy(diskDrives[drive].fileName, fileName);
		diskDrives[drive].sectorsNibblized = 0;

		//Write file name to flash
		FLASH_EraseInitTypeDef flash;
	    HAL_FLASH_Unlock();

	    flash.TypeErase = FLASH_TYPEERASE_PAGES;
	    flash.PageAddress = FLASH_ADDRESS;
	    flash.NbPages = 1;

	    uint32_t pageError = 0;
	    HAL_FLASHEx_Erase(&flash, &pageError);

	    uint16_t dataToWrite;
	    for (int i = 0; i < _MAX_LFN; i++)
	    {
	    	dataToWrite = diskDrives[0].fileName[i] + (diskDrives[1].fileName[i] << 8);
	    	HAL_FLASH_Program(FLASH_TYPEPROGRAM_HALFWORD, FLASH_ADDRESS + i * 2, dataToWrite);
	    }
	    HAL_FLASH_Lock();
		return TRUE;
	}
	else
	{
		diskDrives[drive].fileName[0] = 0;
		return FALSE;
	}
}

void PhaseThread(int8_t newPhase)
{
	//If phase changes
	if (newPhase != diskDrives[selectedDrive].headPhase)
	{
		int oldTrack = diskDrives[selectedDrive].track;
		//Change phaseDeviation accordingly.
		if (newPhase == 0 && diskDrives[selectedDrive].headPhase == (PHASES - 1))
			diskDrives[selectedDrive].phaseDeviation += 1;
		else if (newPhase == (PHASES - 1) && diskDrives[selectedDrive].headPhase == 0)
			diskDrives[selectedDrive].phaseDeviation -= 1;
		else
			diskDrives[selectedDrive].phaseDeviation += (newPhase - diskDrives[selectedDrive].headPhase);
		diskDrives[selectedDrive].headPhase = newPhase;

		if (diskDrives[selectedDrive].phaseDeviation >= 2)
		{
			diskDrives[selectedDrive].track++;
			diskDrives[selectedDrive].phaseDeviation -= 2;
		}
		else if (diskDrives[selectedDrive].phaseDeviation <= -2)
		{
			diskDrives[selectedDrive].track--;
			diskDrives[selectedDrive].phaseDeviation += 2;
		}

		if (diskDrives[selectedDrive].track < 0)
			diskDrives[selectedDrive].track = 0;
		if (diskDrives[selectedDrive].track >= TRACKS_PER_DISK)	//Some disks may be 36 tracks
			diskDrives[selectedDrive].track = TRACKS_PER_DISK - 1;

		if (diskDrives[selectedDrive].track == 0 && diskDrives[selectedDrive].phaseDeviation < 0)
			diskDrives[selectedDrive].phaseDeviation = 0;

		if (oldTrack != diskDrives[selectedDrive].track)
		{
			//Track changed.
			//If track changed, sectors that is nibblized should be reset to -2.
			//When track is being read, the NibberThread will check this field. If < 0, it will set it to be 0.
			diskDrives[selectedDrive].sectorsNibblized = -2;
		}
	}
}

void NibberThread()
{
	static int modeInOut = 0;	//0 = output, 1 = input
	static uint16_t latch = 0;	//Data output to bus

	while ((MMC_disk_status() & STA_NODISK) == 0)
	{
		int powerOn = (GPIOB->IDR & 0x0800) > 0;	//GPIOB Pin11 is power on/off.
		if (powerOn == 1 && diskDrives[selectedDrive].powerOn == 0)
		{
			//Disk power on
			diskDrives[selectedDrive].powerOn = 1;
		}
		else if (powerOn == 0 && diskDrives[selectedDrive].powerOn == 1)
		{
			//Disk power off
			if (diskDrives[selectedDrive].dirtySectors != 0)
				FlushDirtyTrack(selectedDrive);
			diskDrives[selectedDrive].powerOn = 0;
			//Flush file cache to disk
			if (diskDrives[selectedDrive].fileName[0] != 0)
				f_sync(&diskDrives[selectedDrive].fileObj);
			//Turn off the spinning light. The spinning light is at GPIOA Pin11
			GPIOA->ODR = GPIOA->ODR & 0xf7ff;
		}
		else if (!powerOn)
		{
			SampleAndTransmitPDLData();
		}

		//DEVSEL is at PB15
		if ((GPIOB->IDR & 0x8000) == 0)
		{
			//Let data ready line to be low.
			GPIOB->ODR = 0xdfff; //dataRdy is at PB13. Let PB13=0, others be 1. Let other lines to be 1 because these are r/w compatible ports.

			int8_t rw = (GPIOB->IDR & 0x1000) > 0;	//Read or write
			if (rw == 0)	//Write
			{
				if (modeInOut == 0)
				{
					modeInOut = 1;
					InputMode();
				}
				//Data get from bus
				uint8_t data = GPIOB->IDR & 0xff;

				nibTrackBuffer[diskDrives[selectedDrive].nibPosition] = data;
				if ((unsigned char)data == GAP_BYTE)
				{
					diskDrives[selectedDrive].gapBytesWritten++;
					if (diskDrives[selectedDrive].gapBytesWritten >= 28)
					{
						diskDrives[selectedDrive].trackFormatted = 1;
					}
				}
				else
					diskDrives[selectedDrive].gapBytesWritten = 0;

				if (diskDrives[selectedDrive].nibPosition % BYTES_PER_NIB_SECTOR > 0)
					diskDrives[selectedDrive].dirtySectors |= (1 << (diskDrives[selectedDrive].nibPosition / BYTES_PER_NIB_SECTOR));
				diskDrives[selectedDrive].nibPosition++;
				if (diskDrives[selectedDrive].nibPosition == BYTES_PER_NIB_TRACK)
					diskDrives[selectedDrive].nibPosition = 0;
				diskDrives[selectedDrive].dirtyTrack = diskDrives[selectedDrive].track;

				//Let spinning light be bit 0 of data. The spinning light is at GPIOA Pin11
				GPIOA->ODR = (GPIOA->ODR & 0xf7ff) | ((data & 0x01) << 11);
			}
			else	//Read
			{
				if (modeInOut == 1)
				{
					modeInOut = 0;
					OutputMode();
				}
				if (diskDrives[selectedDrive].sectorsNibblized < 0)	//New track
				{
					diskDrives[selectedDrive].sectorsNibblized = 0;	//Now, read begins, should nibblize.
					diskDrives[selectedDrive].nibPosition = 0;		//Rewind to start of the track.
					latch = 0;
				}
				else if (diskDrives[selectedDrive].nibPosition < diskDrives[selectedDrive].sectorsNibblized * BYTES_PER_NIB_SECTOR)
				{
					latch = nibTrackBuffer[diskDrives[selectedDrive].nibPosition];

					diskDrives[selectedDrive].nibPosition++;
					if (diskDrives[selectedDrive].nibPosition == BYTES_PER_NIB_TRACK)
					{
						diskDrives[selectedDrive].nibPosition = 0;
						diskDrives[selectedDrive].sectorsNibblized = 0;
					}
				}
				else if (diskDrives[selectedDrive].sectorsNibblized < SECTORS_PER_TRACK && diskDrives[selectedDrive].sectorsNibblized >= 0 &&
					diskDrives[selectedDrive].fileName[0] != 0)	//File is loaded
				{
					//Before nibblizing new track, should write dirty track back to disk file.
					if (diskDrives[selectedDrive].dirtySectors != 0)
						FlushDirtyTrack(selectedDrive);
					ShowTrackSector(diskDrives[selectedDrive].track, diskDrives[selectedDrive].sectorsNibblized, 1);
					//Nibblize data sector by sector.
					NibblizeOneSector(&diskDrives[selectedDrive].fileObj, diskDrives[selectedDrive].track, diskDrives[selectedDrive].sectorsNibblized);
					diskDrives[selectedDrive].sectorsNibblized += 1;

				}

				//Let spinning light be bit 0 of latch. The spinning light is at GPIOA Pin11
				GPIOA->ODR = (GPIOA->ODR & 0xf7ff) | ((latch & 0x01) << 11);
			}

			//Put latch and dataRdy to port B.
			GPIOB->ODR = (latch | 0xff00);	//0x2000 = dataRdy
		}

	}
}
