#include <string.h>
#include <stdio.h>
#include "DiskDrive.h"
#include "main.h"
#include "disk_sdmmc.h"

extern UART_HandleTypeDef huart1;
extern ADC_HandleTypeDef hadc1;

#define FILENAME_CACHE_SIZE 2000
#define CHARS_PER_LINE 40
#define CACHE_CAPACITY (FILENAME_CACHE_SIZE/CHARS_PER_LINE)
#define LINES_PER_PAGE 18

#define max(x,y) (x)>(y)?(x):(y)
#define min(x,y) (x)<(y)?(x):(y)

#define MSG_YESNO 1
#define MSG_PRESSANYKEY 2
#define MSG_NOWAIT 0
#define IDYES 0xd9
#define IDNO 0xce
#define IDRETURN 0x8d
#define IDESC 0x9b

uint8_t uartData;	//Data received from main FPGA, which is keycode
static char disp[CHARS_PER_LINE + 1];	//Buffer for a line to be put to OSD screen

int cacheContentStartPosition = 0;	//Index of the first filename data in the cache
int cacheContentSize = 0;			//How many lines are filled into the cache
int pageStartLine = 0;				//Index of the first line shows on the page
int cursorLine = 0;					//Index of the cursor line
int maxLines = -1;					//Max lines of this directory. Initialize to -1 to indicate this value is unknown.
char currentDir[256];
int pathNameLen = 0;

char fileNameCache[FILENAME_CACHE_SIZE];	//Every file name occupies 40 bytes. totally 50 lines.

void CreateScreen();
void ShowPage();
void FillinCache();
int MessageBox(char *line1, char *line2, int yesNo);
void ResetAll();
void DispSelectedFile();

void DiskOSDInit()
{
	strcpy(currentDir, "\\");
	pathNameLen = 1;
	ResetAll();
	CreateScreen();
}

void ResetAll()
{
	cacheContentStartPosition = 0;
	cacheContentSize = 0;
	pageStartLine = 0;
	cursorLine = 0;
	maxLines = -1;
}

//This function is called by NibberThread() when powerOn is false.
//It may conflict with uart receive interrupt, so uart interrupt is disabled here.
uint8_t adcBuf[5];
#define SAMPLECOUNTERMAX 800
int sampleCounter = SAMPLECOUNTERMAX;	//We don't have to send PDL data all the time.
void SampleAndTransmitPDLData()
{
	if (--sampleCounter > 0)
		return;
	sampleCounter = SAMPLECOUNTERMAX;
	//Convert 4 channels of ADC1 and transmit result (shrink to 8bit) to host.
	int i;
	for(i = 4; i > 0; i--)
	{
		HAL_ADC_Start(&hadc1);
		HAL_ADC_PollForConversion(&hadc1, 0xffff);

		adcBuf[i] = (uint8_t)(HAL_ADC_GetValue(&hadc1) / 16);
		if (adcBuf[i] < 2)
			adcBuf[i] = 2;
		if (adcBuf[i] >= 124 && adcBuf[i] <= 130)
			adcBuf[i] = 127;	//so that there is always a center.
		if (adcBuf[i] > 210)
			adcBuf[i] = 255;
	}
	HAL_ADC_Stop(&hadc1);
	i = 0xff;

	adcBuf[0] = 0xff;	//0xff is the start token for PDL data transfer.
	HAL_UART_Receive_IT(&huart1, (uint8_t *)&uartData, 0);   //Disable UART IT
	HAL_UART_Transmit(&huart1, adcBuf, 5, 500);	//0xff is the start token for PDL data transfer.
	HAL_UART_Receive_IT(&huart1, (uint8_t *)&uartData, 1);   //Restart the UART IT

}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
	if (!diskDrives[selectedDrive].powerOn)
	{
		if (uartData == 0x8b || uartData == 0x88)	//Up or Left arrow
		{
			cursorLine = max(0, cursorLine - 1);
			pageStartLine = min(cursorLine, pageStartLine);
			if (pageStartLine < cacheContentStartPosition)
			{
				cacheContentStartPosition = max(0, pageStartLine - LINES_PER_PAGE);
				FillinCache();
			}
			ShowPage();
		}
		else if (uartData == 0x8a || uartData == 0x95)	//Down or Right arrow
		{
			cursorLine++;
			if (cursorLine >= cacheContentStartPosition + cacheContentSize)
			{
				if (cursorLine >= maxLines && maxLines != -1)
					cursorLine--;
				else
				{
					cacheContentStartPosition = pageStartLine;
					FillinCache();
				}
			}
			if (cursorLine >= pageStartLine + LINES_PER_PAGE)
				pageStartLine = max(0, cursorLine - LINES_PER_PAGE + 1);
			ShowPage();
		}
		else if (uartData == 0x97)	//ctrl+q or Page Up
		{
			pageStartLine = max(0, pageStartLine - LINES_PER_PAGE);
			cursorLine = max(0, cursorLine - LINES_PER_PAGE);
			if (pageStartLine < cacheContentStartPosition)
			{
				cacheContentStartPosition = max(0, pageStartLine - LINES_PER_PAGE);
				FillinCache();
			}
			ShowPage();
		}
		else if (uartData == 0x98) //ctrl+r or Page Down
		{
			cursorLine += LINES_PER_PAGE;
			if (cursorLine >= maxLines && maxLines != -1)
				cursorLine = maxLines - 1;
			if (cursorLine >= cacheContentStartPosition + cacheContentSize)
			{
				cacheContentStartPosition = pageStartLine;
				FillinCache();
				if (cursorLine >= maxLines && maxLines != -1)
					cursorLine = maxLines - 1;
			}
			if (cursorLine >= pageStartLine + LINES_PER_PAGE)
				pageStartLine = min(cacheContentStartPosition + cacheContentSize - LINES_PER_PAGE, pageStartLine + LINES_PER_PAGE);
			ShowPage();
		}
		else if (uartData == 0x8d) //return
		{
			int startPos = (cursorLine - cacheContentStartPosition) * CHARS_PER_LINE;
			char fileName[16];
			for (int i = startPos; i < startPos + 15; i++)
			{
				if ((fileNameCache[i] == ' ' && i - startPos > 0) || fileNameCache[i] == '>')
				{
					fileName[i - startPos] = 0;
					break;
				}
				else
					fileName[i - startPos] = fileNameCache[i];
			}
			if (fileName[0] == '<')	//Should change directory and show the directory
			{
				if (pathNameLen < 255 - 13)
				{
					//Change dir
					if (currentDir[pathNameLen - 1] != '\\')
						strcat(currentDir, "\\");
					if (fileName[1] == '.' && fileName[2] == '.')	//Back
					{
						while (pathNameLen > 0)
						{
							pathNameLen--;
							if (currentDir[pathNameLen] == '\\')
							{
								currentDir[pathNameLen] = 0;
								break;
							}
						}
						if (pathNameLen == 0)
						{
							strcpy(currentDir, "\\");
							pathNameLen = 1;
						}
					}
					else
					{
						strcat(currentDir, fileName + 1);
						pathNameLen = strlen(currentDir);
					}
					ResetAll();
					CreateScreen();
				}
				else
					MessageBox("  PATH TOO LONG,  ", "NO ENOUGH MEMORY", MSG_PRESSANYKEY);
			}
			else if (MessageBox("   LOAD CONFIRM", fileName + 1, MSG_YESNO) == IDYES)
			{
				//Should load the file
				int len = pathNameLen;
				if (currentDir[len - 1] != '\\')
				{
					currentDir[len] = '\\';
					len++;
					currentDir[len] = 0;
				}
				strcat(currentDir, fileName + 1);
				if (LoadDiskFile(currentDir, 0))
					MessageBox("", "   IMAGE LOADED   ", MSG_PRESSANYKEY);
				else
					MessageBox("", "LOAD IMAGE FAILED", MSG_PRESSANYKEY);
				DispSelectedFile();
				currentDir[pathNameLen] = 0;
			}
		}
		else if (uartData == 0xe0)	// '`' = refresh
			CreateScreen();
	}

	if (uartData == IDESC)
	{
		uint8_t ch = 0;
		HAL_UART_Transmit(&huart1, &ch, 1, 500);	//3 zeros to mean to exit osd.
		HAL_UART_Transmit(&huart1, &ch, 1, 500);
		HAL_UART_Transmit(&huart1, &ch, 1, 500);
	}

	HAL_UART_Receive_IT(huart, (uint8_t *)&uartData, 1);   //Restart the UART IT
}

static void Write(int startAddress, uint8_t *data)
{
	//send start address
	uint8_t ch = startAddress & 0xff;
	HAL_UART_Transmit(&huart1, &ch, 1, 500);
	ch = (startAddress & 0x3ff) >> 8;
	HAL_UART_Transmit(&huart1, &ch, 1, 500);
	//send data and 0
	int i = 0;
	do
	{
		HAL_UART_Transmit(&huart1, data + i, 1, 500);

	} while (data[i++] != 0);
}

void PRINT(int x, int y, char *string, int inverse)
{
	int address = ((y & 0x7) << 7) + ((y & 0x18) << 2) + (y & 0x18) + x;
	int i = 0;
	while (string[i])
	{
		if (inverse)
		{
			if (string[i] < '@')
				disp[i] = string[i];
			else if (string[i] >= 'a')	//no lower case in inverse
				disp[i] = string[i] - 'a' + 'A' - '@';
			else
				disp[i] = string[i] - '@';
		}
		else
		{
			disp[i] = string[i] + 128;
		}
		i++;
	}
	disp[i] = 0;
	Write(address, (uint8_t *)disp);
}

int MessageBox(char *line1, char *line2, int yesNo)
{
	uartData = 0;

	for (int i = 8; i < 14; i++)
		PRINT(10, i, "                    ", 1);
	PRINT(11, 9,  line1, 1);
	PRINT(11, 10, line2, 1);
	if (yesNo == MSG_YESNO)
	{
		PRINT(10, 12, "  [Y]=YES  [N]=NO   ", 1);
		while (uartData != IDYES && uartData != IDNO && uartData != IDRETURN && uartData != IDESC)
		{
			HAL_UART_Receive(&huart1, &uartData, 1, 100);
		}
	}
	else if (yesNo == MSG_PRESSANYKEY)
	{
		PRINT(10, 12, "   PRESS ANY KEY    ", 1);
		while (uartData == 0)
		{
			HAL_UART_Receive(&huart1, &uartData, 1, 100);
		}
	}

	if (yesNo == MSG_NOWAIT)
		return 0;
	else
	{
		ShowPage();	//Restore screen display.
		if (uartData == IDRETURN)
			uartData = IDYES;
		else if (uartData == IDESC)
			uartData = IDNO;
		return (int)uartData;
	}
}

void DispCurrentDrive()
{
	strcpy(disp, " S6 D1 ");
	PRINT(21, 0, disp, 1);
}

void DispSelectedFile()
{
	int i = 0;
	while (i < CHARS_PER_LINE && diskDrives[0].fileName[i] != 0)
	{
		disp[i] = diskDrives[0].fileName[i];
		i++;
	}
	while (i < CHARS_PER_LINE)
		disp[i++] = ' ';
	disp[i] = 0;
	PRINT(0, 1, disp, 0);
}

static DIR	dir;	//dir and fi fail the program if being put into FillinCache.
static FILINFO fi;
void FillinCache()
{
	int line = 0;
	int addr = 0;

	cacheContentSize = 0;
	MessageBox("", "   PLEASE WAIT.", MSG_NOWAIT);

	if (f_findfirst(&dir, &fi, currentDir, "*") == FR_OK)
	{
		if (pathNameLen > 1) //not root dir
		{
			if (cacheContentStartPosition == 0)
			{
				strcpy(fileNameCache, "<..>");
				addr = strlen(fileNameCache);
				while (addr < CHARS_PER_LINE)
					fileNameCache[addr++] = ' ';
				cacheContentSize++;
			}
			line++;
		}
		do
		{
			if ((fi.fattrib & AM_HID) || (fi.fattrib & AM_SYS))
				continue;	//Hidden and system file are not shown.

			//Supports only .dsk or .do files
			int len = strlen(fi.fname);
			if (!((len > 3 && (fi.fname[len-1] == 'k' || fi.fname[len-1] == 'K') &&
					(fi.fname[len-2] == 's' || fi.fname[len-2] == 'S') &&
					(fi.fname[len-3] == 'd' || fi.fname[len-3] == 'D') &&
					fi.fname[len-4] == '.') ||
				(len > 2 && (fi.fname[len-1] == 'o' || fi.fname[len-1] == 'O') &&
					(fi.fname[len-2] == 'd' || fi.fname[len-2] == 'D') &&
					fi.fname[len-3] == '.'))
				&& !(fi.fattrib & AM_DIR))
			{
				continue;
			}

			if (line >= cacheContentStartPosition && line < cacheContentStartPosition + (FILENAME_CACHE_SIZE / CHARS_PER_LINE))
			{
				fileNameCache[addr++] = (fi.fattrib & AM_DIR) ? '<' : ' ';	//Directory or file
				int i;
				for (i = 0; i < 13; i++)
				{
					if (fi.fname[i] == 0)
						break;
					else
						fileNameCache[addr++] = fi.fname[i];
				}
				fileNameCache[addr++] = (fi.fattrib & AM_DIR) ? '>' : ' ';	//Directory or file
				i++;
				while (i < 14)
				{
					fileNameCache[addr++] = ' ';
					i++;
				}
				fileNameCache[addr++] = ' ';	//Seperator to long file name.

				int n = 0;
				while (i < CHARS_PER_LINE - 2 && fi.lfname[n])
				{
					fileNameCache[addr++] = fi.lfname[n];
					i++;
					n++;
				}
				while (i < CHARS_PER_LINE - 2)
				{
					i++;
					fileNameCache[addr++] = ' ';
				}
				cacheContentSize++;
			}
			line++;
		} while (f_findnext(&dir, &fi) == FR_OK && fi.fname[0]);
	}
	if (fi.fname[0] == 0)	//End of directory
	{
		maxLines = line;
	}
	while (addr < FILENAME_CACHE_SIZE)
		fileNameCache[addr++] = ' ';

	f_closedir(&dir);
}

void ShowPage()
{
	for (int i = 0; i < LINES_PER_PAGE; i++)
	{
		int currentLine = i + pageStartLine;
		int startCacheAddr = (currentLine - cacheContentStartPosition) * CHARS_PER_LINE;
		if (startCacheAddr >= FILENAME_CACHE_SIZE)
			break;
		for (int n = startCacheAddr; n < startCacheAddr + CHARS_PER_LINE; n++)
			disp[n - startCacheAddr] = fileNameCache[n];

		PRINT(0, i + 3, disp, currentLine == cursorLine ? 1 : 0);
	}
}

void ShowTrackSector(int track, int sector, int nf)
{
	sprintf(disp, "T%02d S%02d %s", track, sector, nf ? "N" : "F");
	PRINT(31, 0, disp, 1);
}

void CreateScreen()
{
	PRINT(0, 0, " F6 ", 1);
	PRINT(4, 0, "-DISK IMAGE                   ", 0);
	if ((MMC_disk_status() & STA_PROTECT) == 0)
		PRINT(16, 0, " RW ", 1);
	else
		PRINT(16, 0, " RO ", 1);
	DispCurrentDrive();
	ShowTrackSector(0, 0, 1);
	DispSelectedFile();
	PRINT(0, 2, "----------------------------------------", 0);
	FillinCache();
	ShowPage(pageStartLine);
	PRINT(0, 21, "----------------------------------------", 0);
	PRINT(0, 22, "[RETURN]=SELECT [ESC]=EXIT [N]=NEW IMAGE", 1);
	PRINT(0, 23, "[<-][->][PGUP/DN]=PREV/NEXT/PAGE UP/DOWN", 1);
}


