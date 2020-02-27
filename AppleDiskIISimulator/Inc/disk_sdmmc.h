#ifndef _SDMMC_H
#define _SDMMC_H

// MMC/SD card type flags
#define CT_MMC		0x01		// MMC
#define CT_SD1		0x02		// SD V1.xx
#define CT_SD2		0x04		// SD V2.00
#define CT_BLOCK	0x08		// Block addressing

DSTATUS MMC_disk_initialize ();
DSTATUS MMC_disk_status (void);
DRESULT MMC_disk_read (BYTE*, DWORD, BYTE);
DRESULT MMC_disk_write (const BYTE*, DWORD, BYTE);
DRESULT MMC_disk_ioctl (BYTE, void*);

#endif
