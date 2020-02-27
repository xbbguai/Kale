
#include "stm32f1xx_hal.h"
#include "ffconf.h"
#include "diskio.h"
#include "disk_sdmmc.h"	

#define SD_BLOCK_SIZE 512

// MMC/SD commands
#define CMD0	(0x40+0)	// GO_IDLE_STATE
#define CMD1	(0x40+1)	// SEND_OP_COND (MMC)
#define ACMD41	(0xC0+41)	// SEND_OP_COND (SD)
#define CMD8	(0x40+8)	// SEND_IF_COND
#define CMD9	(0x40+9)	// SEND_CSD
#define CMD10	(0x40+10)	// SEND_CID
#define CMD12	(0x40+12)	// STOP_TRANSMISSION
#define ACMD13	(0xC0+13)	// SD_STATUS (SD)
#define CMD16	(0x40+16)	// SET_BLOCKLEN
#define CMD17	(0x40+17)	// READ_SINGLE_BLOCK
#define CMD18	(0x40+18)	// READ_MULTIPLE_BLOCK
#define CMD23	(0x40+23)	// SET_BLOCK_COUNT (MMC)
#define ACMD23	(0xC0+23)	// SET_WR_BLK_ERASE_COUNT (SD)
#define CMD24	(0x40+24)	// WRITE_BLOCK
#define CMD25	(0x40+25)	// WRITE_MULTIPLE_BLOCK
#define CMD55	(0x40+55)	// APP_CMD
#define CMD58	(0x40+58)	// READ_OCR

#define SD_SEL()  HAL_GPIO_WritePin(SD_CS_GPIO_Port, SD_CS_Pin, GPIO_PIN_RESET)    // SD socket CS = L
#define SD_DESEL() HAL_GPIO_WritePin(SD_CS_GPIO_Port, SD_CS_Pin, GPIO_PIN_SET)	   // SD socket CS = H

#define SD_CD 1	//0000 0001
#define SD_WP 2	//0000 0010

static volatile DSTATUS diskStatus = STA_NOINIT;	//Status
static BYTE cardType = 0;							//Card type flags

//Timers
static volatile	DWORD Timer1, Timer2;
#define SET_TIMER1(x) Timer1=(x)
#define IS_TIMER1_END() Timer1==0
#define SET_TIMER2(x) Timer2=(x)
#define IS_TIMER2_END() Timer2==0

typedef enum {FALSE = 0, TRUE = !FALSE} BOOL;

static int CheckPower()
{
	return 1;  //Always on.
}

extern SPI_HandleTypeDef hspi1;
static void InitSPI(int speed)
{
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = speed ? SPI_BAUDRATEPRESCALER_2 : SPI_BAUDRATEPRESCALER_256;	//or: 4, ..., 256. the bigger the slower.
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 7;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  SPI1->CR1 |= SPI_CR1_SPE;	//SPI Enable
}

static inline BYTE SPITransmitReceive(BYTE out)
{
	while ((SPI1->SR & SPI_FLAG_TXE) == 0);
	SPI1->DR = out;
	while ((SPI1->SR & SPI_FLAG_RXNE) == 0);
	return SPI1->DR;
}

static  BYTE WaitForReady ()
{
	BYTE res; 

	SET_TIMER2(50);	//500ms
	SPITransmitReceive(0xff);
	do
	{
		res = SPITransmitReceive(0xff);
	} while ((res != 0xff) && !IS_TIMER2_END());

	return res;
}

static void TurnOn()
{
	SD_SEL();
}

static void TurnOff ()
{
	if (!(diskStatus & STA_NOINIT))
	{
		SD_SEL();
		WaitForReady();
		SD_DESEL();
		SPITransmitReceive(0xff);
	}
	SD_DESEL();
	diskStatus |= STA_NOINIT;
}

static BOOL ReceiveDataBlock (BYTE *buff, UINT size)
{
	BYTE token;	

	SET_TIMER1(10);	//Time out = 100ms
	do 
	{
		token = SPITransmitReceive(0xff);
	} 
	while ((token == 0xff) && !IS_TIMER1_END());
	
	if (token != 0xfe)
		return FALSE;	//Invalid token

	//Receive the data block into buffer
	do
	{
		 *(buff++) = SPITransmitReceive(0xff);
	} while (--size);

	//Dummy CRC
	SPITransmitReceive(0xff);
	SPITransmitReceive(0xff);

	return TRUE;
} 

static  BOOL TransmitDataBlock (const BYTE *buff, BYTE token)
{
	BYTE resp;

	if (WaitForReady() != 0xff)
		return FALSE;

	SPITransmitReceive(token);	//Transmit token
	if (token != 0xfd)   //0xfd = data token
	{
		//transmit the data block to card
		for (int i = 0; i < SD_BLOCK_SIZE; i++)
			SPITransmitReceive(*buff++);

		//Transmit dummy CRC
		SPITransmitReceive(0xff);
		SPITransmitReceive(0xff);

		resp = SPITransmitReceive(0xff);
		if ((resp & 0x1f) != 0x05)
			return FALSE;
	}
	return TRUE;
}

static BYTE SendCommand (BYTE cmd, DWORD arg)
{
	BYTE res;

	if (cmd & 0x80)
	{
		// ACMD<n> is the command sequence of CMD55-CMD<n>
		cmd &= 0x7f;
		res = SendCommand(CMD55, 0);
		if (res > 1)
			return res;
	}

	//Prepare SD card
	SD_DESEL();
	for (int i = 0; i < 100; i++);
	SD_SEL();
	if (WaitForReady() != 0xff)
	{
		return 0xff;
	}

	// Send command packet
	SPITransmitReceive(cmd);					// Command
	SPITransmitReceive((BYTE)(arg >> 24));		// arg byte 3
	SPITransmitReceive((BYTE)(arg >> 16));		// arg byte 2
	SPITransmitReceive((BYTE)(arg >> 8));		// arg byte 1
	SPITransmitReceive((BYTE)arg);				// arg byte 0
	//CRC and stop
	BYTE i;
	if (cmd == CMD0)
		i = 0x95;			//CRC for CMD0(0)
	else if (cmd == CMD8)
		i = 0x87;			//CRC for CMD8(0x1AA)
	else
		i = 1;	//dummy
	SPITransmitReceive(i);

	// If CMD12, skip a stuff byte when stop reading
	if (cmd == CMD12)
		SPITransmitReceive(0xff);

	//Wait for a valid response
	i = 10;
	do
	{
		res = SPITransmitReceive(0xff);
	} while ((res & 0x80) && --i);

	return res;
}

DSTATUS MMC_disk_status()
{
	return diskStatus;
}

DSTATUS MMC_disk_initialize()
{
	int n;
	BYTE cmd, ocr[4];
	BYTE res;

	if (diskStatus & STA_NODISK)
		return diskStatus;	// No card in the socket */

	cardType = 0;

	//SPI interface init
	InitSPI(0);		//Low speed for card initialization
	SD_SEL();

	//Delay for power up
	for (n = 0; n < 0xff00; n++)
		asm("nop");
	//At least 74 ticks
	for (n = 0; n < 10; n++)
		SPITransmitReceive(0xff);

	n = 20;	//Try 20 times
	do
	{
	  res = SendCommand(CMD0, 0);
	} while (res != 0x01 && --n);

	if (res == 0x01)	//SD card responded with 0x01
	{
		//Entering into idle state
		SET_TIMER1(100);	//time out = 1000ms
		if (SendCommand(CMD8, 0x1aa) == 1)
		{
			//SDHC
			ocr[0] = SPITransmitReceive(0xff);		//Trailing return value of R7 response
			ocr[1] = SPITransmitReceive(0xff);
			ocr[2] = SPITransmitReceive(0xff);
			ocr[3] = SPITransmitReceive(0xff);
			if (ocr[2] == 0x01 && ocr[3] == 0xaa)
			{
				//Leaving idle state  (ACMD41 with HCS bit)
				while (!IS_TIMER1_END() && SendCommand(ACMD41, 1ul << 30));
				if (!IS_TIMER1_END() && SendCommand(CMD58, 0) == 0)
				{
					// Check CCS bit in the OCR
					ocr[0] = SPITransmitReceive(0xff);
					ocr[1] = SPITransmitReceive(0xff);
					ocr[2] = SPITransmitReceive(0xff);
					ocr[3] = SPITransmitReceive(0xff);
					cardType = (ocr[0] & 0x40) ? CT_SD2 | CT_BLOCK : CT_SD2;
				}
			}
		}
		else
		{
			//SDSC or MMC
			if (SendCommand(ACMD41, 0) <= 1)
			{
				//SDSC
				cardType = CT_SD1;
				cmd = ACMD41;
			}
			else
			{
				//MMC
				cardType = CT_MMC;
				cmd = CMD1;
			}
			//Leaving idle state
			while (!IS_TIMER1_END() && SendCommand(cmd, 0));

			//Set read/write block size (512 bytes)
			if (IS_TIMER1_END() || SendCommand(CMD16, SD_BLOCK_SIZE) != 0)
				cardType = 0;
		}
	}
	SD_DESEL();
	SPITransmitReceive(0xff);

	if (cardType)
	{
		//Initialization succeeded
		diskStatus &= ~STA_NOINIT;
		//Re-init SPI to high speed
		InitSPI(1);
	}
	else
	{
		//Initialization failed
		TurnOff();
	}

	return diskStatus;
}

DRESULT MMC_disk_read(BYTE *buff, DWORD sector, BYTE count)
{
	if (!count)
		return RES_PARERR;
	if (diskStatus & STA_NOINIT)
		return RES_NOTRDY;

	if (!(cardType & CT_BLOCK))
		sector *= SD_BLOCK_SIZE;	/* Convert to byte address if needed */

	if (count == 1)
	{
		//Single block
		if (SendCommand(CMD17, sector) == 0)
		{
			if (ReceiveDataBlock(buff, SD_BLOCK_SIZE))
				--count;
		}
	}
	else
	{
		//Multiple blocks
		if (SendCommand(CMD18, sector) == 0)
		{
			do
			{
				//Read block by block
				if (!ReceiveDataBlock(buff, SD_BLOCK_SIZE))
					break;
				buff += SD_BLOCK_SIZE;
			} while (--count);
			SendCommand(CMD12, 0);	//ok, all blocks done. stop.
		}
	}
	SD_DESEL();
	SPITransmitReceive(0xff);

	return count ? RES_ERROR : RES_OK;
}

DRESULT MMC_disk_write(const BYTE *buff, DWORD sector, BYTE count)
{
	if (!count)
		return RES_PARERR;
	if (diskStatus & STA_NOINIT)
		return RES_NOTRDY;
	if (diskStatus & STA_PROTECT)
		return RES_WRPRT;

	if (!(cardType & CT_BLOCK))
		sector *= SD_BLOCK_SIZE;	// Should convert sector index to byte address

	if (count == 1)
	{
		//Single block
		if ((SendCommand(CMD24, sector) == 0) && TransmitDataBlock(buff, 0xfe))
			--count;
	}
	else
	{
		//Multiple blocks
		if (cardType & (CT_SD1 | CT_SD2))
			SendCommand(ACMD23, count);
		if (SendCommand(CMD25, sector) == 0)
		{
			do
			{
				if (!TransmitDataBlock(buff, 0xfc))
					break;
				buff += SD_BLOCK_SIZE;
			} while (--count);
			if (!TransmitDataBlock(0, 0xfd))	//STOP_TRAN token
				count = 1;
		}
	}
	SD_DESEL();
	SPITransmitReceive(0xff);

	return count ? RES_ERROR : RES_OK;
}

DRESULT MMC_disk_ioctl(BYTE ctrl, void *buff)
{
	DRESULT res;
	BYTE n, csd[16];
	BYTE *ptr = (BYTE *)buff;
	WORD csize;

	res = RES_ERROR;

	if (ctrl == CTRL_POWER)
	{
		switch (ptr[0])	//ptr[0] (buff[0]) = subcontrol code
		{
		case 0:		// 0 = POWER_OFF
			if (CheckPower())
				TurnOff();
			res = RES_OK;
			break;
		case 1:		// 1 = POWER_ON
			TurnOn();
			res = RES_OK;
			break;
		case 2:		// 2 = POWER_GET
			ptr[1] = (BYTE)CheckPower();
			res = RES_OK;
			break;
		default :
			res = RES_PARERR;
		}
	}
	else
	{
		if (diskStatus & STA_NOINIT)
			return RES_NOTRDY;

		switch (ctrl)
		{
		case CTRL_SYNC :		// Make sure that no pending write process
			SD_SEL();
			if (WaitForReady() == 0xff)
				res = RES_OK;
			break;
		case GET_SECTOR_COUNT :	// Get number of sectors on the disk (DWORD)
			if ((SendCommand(CMD9, 0) == 0) && ReceiveDataBlock(csd, 16))
			{
				if ((csd[0] >> 6) == 1)
				{
					// SDC V2.00
					csize = csd[9] + ((WORD)csd[8] << 8) + 1;
					*(DWORD*)buff = (DWORD)csize << 10;
				}
				else
				{
					// SDC V1.X or MMC
					n = (csd[5] & 15) + ((csd[10] & 128) >> 7) + ((csd[9] & 3) << 1) + 2;
					csize = (csd[8] >> 6) + ((WORD)csd[7] << 2) + ((WORD)(csd[6] & 3) << 10) + 1;
					*(DWORD*)buff = (DWORD)csize << (n - 9);
				}
				res = RES_OK;
			}
			break;

		case GET_SECTOR_SIZE :	// Get R/W sector size (WORD)
			*(WORD*)buff = SD_BLOCK_SIZE;
			res = RES_OK;
			break;

		case GET_BLOCK_SIZE :	// Get erase block size in unit of sector (DWORD)
			if (cardType & CT_SD2)
			{
				// SDC V2.00
				if (SendCommand(ACMD13, 0) == 0)
				{
					// Read SD status
					SPITransmitReceive(0xff);
					if (ReceiveDataBlock(csd, 16))
					{
						// Read partial block
						for (n = 64 - 16; n; n--)
							SPITransmitReceive(0xff);	/* Purge trailing data */
						*(DWORD*)buff = 16UL << (csd[10] >> 4);
						res = RES_OK;
					}
				}
			}
			else
			{
				// SDC v1.XX or MMC
				if ((SendCommand(CMD9, 0) == 0) && ReceiveDataBlock(csd, 16))
				{
					//Read CSD
					if (cardType & CT_SD1)
					{
						//SDC V1.XX
						*(DWORD*)buff = (((csd[10] & 63) << 1) + ((WORD)(csd[11] & 128) >> 7) + 1) << ((csd[13] >> 6) - 1);
					}
					else
					{
						//MMC
						*(DWORD*)buff = ((WORD)((csd[10] & 124) >> 2) + 1) * (((csd[11] & 3) << 3) + ((csd[11] & 224) >> 5) + 1);
					}
					res = RES_OK;
				}
			}
			break;

		case MMC_GET_TYPE :		// Get card type flags (1 byte)
			*ptr = cardType;
			res = RES_OK;
			break;

		case MMC_GET_CSD :		// Receive CSD as a data block (16 bytes)
			if (SendCommand(CMD9, 0) == 0 && ReceiveDataBlock(ptr, 16))
				res = RES_OK;
			break;

		case MMC_GET_CID :		// Receive CID as a data block (16 bytes)
			if (SendCommand(CMD10, 0) == 0 && ReceiveDataBlock(ptr, 16))
				res = RES_OK;
			break;

		case MMC_GET_OCR :		// Receive OCR as an R3 resp (4 bytes)
			if (SendCommand(CMD58, 0) == 0)
			{
				for (n = 0; n < 4; n++)
					*ptr++ = SPITransmitReceive(0xff);
				res = RES_OK;
			}
			break;

		case MMC_GET_SDSTAT :	// Receive SD status as a data block (64 bytes)
			if (SendCommand(ACMD13, 0) == 0)
			{
				SPITransmitReceive(0xff);
				if (ReceiveDataBlock(ptr, 64))
					res = RES_OK;
			}
			break;

		default:
			res = RES_PARERR;
		}

		SD_DESEL();
		SPITransmitReceive(0xff);
	}

	return res;
}

/*DWORD get_fattime ()
{
	DWORD res;
	
	res =  (((DWORD)2012 - 1980) << 25)
			| ((DWORD)12 << 21)
			| ((DWORD)3 << 16)
			| (WORD)(10 << 11)
			| (WORD)(10 << 5)
			| (WORD)(10 >> 1);

	return res;
}
*/

//This function will be called every 10ms in the timer1 interruption
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
	static BYTE socketSwitchs;
	BYTE ssSave;

	//Timers
	if (Timer1)
		Timer1--;
	if (Timer2)
		Timer2--;

	//To get stable socket switches status
	ssSave = socketSwitchs;
	socketSwitchs = HAL_GPIO_ReadPin(GPIOC, SD_CD_Pin) * SD_CD | HAL_GPIO_ReadPin(GPIOC, SD_WP_Pin) * SD_WP;

	if (ssSave == socketSwitchs)
	{
		//Yes, stable
		if (socketSwitchs & SD_WP)      // WP is H (write protected)
			diskStatus |= STA_PROTECT;
		else                            // WP is L (write enabled)
			diskStatus &= ~STA_PROTECT;

		if (socketSwitchs & SD_CD)      // CP is H (Socket empty)
			diskStatus |= (STA_NODISK | STA_NOINIT);
		else                            // CP is L (Card inserted)
			diskStatus &= ~STA_NODISK;
	}
}
