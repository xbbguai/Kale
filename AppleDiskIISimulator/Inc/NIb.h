#ifndef _NIB_H
#define _NIB_H
#include "fatfs.h"

//typedef unsigned char uint8_t;

#define TRACKS_PER_DISK     35
#define SECTORS_PER_TRACK   16
#define BYTES_PER_SECTOR    256
#define BYTES_PER_TRACK     4096
#define DSK_LEN             143360L

#define AUX_BUF_LEN 		86
#define DATA_LEN            (BYTES_PER_SECTOR + AUX_BUF_LEN)

#define GAP1_LEN            48
#define GAP2_LEN            5

#define BYTES_PER_NIB_SECTOR 416
#define BYTES_PER_NIB_TRACK  6656

#define DEFAULT_VOLUME      254
#define GAP_BYTE 			0xFF
#define PROLOG0 			0xD5
#define PROLOG1 			0xAA
#define PROLOG2_ADDR 		0x96
#define PROLOG2_DATA 		0xAD
#define EPILOG0 			0xDE
#define EPILOG1 			0xAA
#define EPILOG2 			0xEB

typedef struct
{
	uint8_t prolog0;
	uint8_t prolog1;
	uint8_t prolog2;
	uint8_t volume[2];
	uint8_t track[2];
	uint8_t sector[2];
	uint8_t checksum[2];
	uint8_t epilog0;
	uint8_t epilog1;
	uint8_t epilog2;
} AddrPart;

typedef struct
{
	uint8_t prolog0;
	uint8_t prolog1;
	uint8_t prolog2;
	uint8_t data[DATA_LEN];
	uint8_t data_checksum;
	uint8_t epilog0;
	uint8_t epilog1;
	uint8_t epilog2;
} DataPart;

typedef struct
{
	uint8_t	 gap1[GAP1_LEN];
	AddrPart addrPart;
	uint8_t	 gap2[GAP2_LEN];
	DataPart dataPart;
} NibSector;

extern uint8_t nibTrackBuffer[BYTES_PER_NIB_TRACK];
extern uint8_t dskTrackBuffer[BYTES_PER_TRACK];

void NibblizeOneSector(FIL* pFile, int track, int sector);
void DenibblizeOneSector(FIL* pFile, int track, int sector, NibSector *pNibSector);

#endif
