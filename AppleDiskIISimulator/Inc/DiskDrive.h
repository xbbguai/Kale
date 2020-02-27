#ifndef _DISKDRIVE_H
#define _DISKDRIVE_H

#include "Nib.h"

#define DISK_DRIVES 2

typedef enum {FALSE = 0, TRUE = 1} BOOL;

void InitDiskDrives();
BOOL LoadDiskFile(const char *fileName, int drive);

void PhaseThread(int8_t newPhase);
void NibberThread();

typedef struct _DiskDrive
{
	int  powerOn;
	int  headPhase;			//Phase of r/w head.
	int  phaseDeviation;	//Accumulates according to head phase change. When == 2, increase track by 1; when == -2, decrease track by 1.
	int  track;				//Current working track.
	int  gapBytesWritten;	//How many gap bytes continously written into this track
	int  trackFormatted;	//Is this track formatted
	int  sectorsNibblized;	//When track changed, set to -1. When read starts, set to 0 to nibblize track data from dsk file.
	int  dirtySectors;		//Max sectors per track not supposed to exceed 32. Per bit per sector, indicating a sector is dirty.
	int  dirtyTrack;		//The track that is dirty.
	int  nibPosition;		//Current nib buffer r/w position.
	char fileName[_MAX_LFN+1];
	FIL  fileObj;
} DiskDrive;

extern DiskDrive diskDrives[DISK_DRIVES];
extern int selectedDrive;

#define PHASES          4
/*
//Disk II control addrs
#define PHASE_OFF 		0x0
#define PHASE_ON  		0x1
#define POWER_OFF  		0x8
#define POWER_ON   		0x9
#define SELECT_D1  		0xA
#define SELECT_D2  		0xB
#define NIB_READ   		0xC
#define NIB_WRITE  		0xD
#define READ_ENABLE 	0xE
#define WRITE_ENABLE 	0xF
*/

#endif
