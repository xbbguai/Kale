#include <string.h>
#include "fatfs.h"
#include "Nib.h"

static int sectorInterleaves[SECTORS_PER_TRACK] =
{ 0x0, 0x7, 0xE, 0x6, 0xD, 0x5, 0xC, 0x4, 0xB, 0x3, 0xA, 0x2, 0x9, 0x1, 0x8, 0xF };

int volume = DEFAULT_VOLUME;

uint8_t nibTrackBuffer[BYTES_PER_NIB_TRACK];
uint8_t denibSectorBuffer[BYTES_PER_NIB_SECTOR];
uint8_t sectorBuffer[BYTES_PER_SECTOR];
uint8_t *auxBuffer = denibSectorBuffer;	//auxBuffer[AUX_BUF_LEN]; auxBuffer and denibSectorBuffer shares the same space.

// Encode 1 byte into two "4 and 4" bytes
static void OddEvenEncoder(uint8_t result[], int data)
{
	result[0] = ((data >> 1) & 0x55) | 0xaa;
	result[1] = (data & 0x55) | 0xaa;
}

// Decode 2 "4 and 4" bytes into 1 byte
static uint8_t OddEvenDecoder(uint8_t byte1, uint8_t byte2)
{
	return ((byte1 << 1) & 0xaa) | (byte2 & 0x55);
}

// Data for "6 and 2" translation
static uint8_t table62[0x40] = {
	// 0     1     2     3     4     5     6     7
	0x96, 0x97, 0x9a, 0x9b, 0x9d, 0x9e, 0x9f, 0xa6,
	// 8     9     a     b     c     d     e     f
	0xa7, 0xab, 0xac, 0xad, 0xae, 0xaf, 0xb2, 0xb3,
	//10    11    12    13    14    15    16    17
	0xb4, 0xb5, 0xb6, 0xb7, 0xb9, 0xba, 0xbb, 0xbc,
	//18    19    1a    1b    1c    1d    1e    1f
	0xbd, 0xbe, 0xbf, 0xcb, 0xcd, 0xce, 0xcf, 0xd3,
	//20    21    22    23    24    25    26    27
	0xd6, 0xd7, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde,
	//28    29    2a    2b    2c    2d    2e    2f
	0xdf, 0xe5, 0xe6, 0xe7, 0xe9, 0xea, 0xeb, 0xec,
	//30    31    32    33    34    35    36    37
	0xed, 0xee, 0xef, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6,
	//38    39    3a    3b    3c    3d    3e    3f
	0xf7, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff
};

static uint8_t table62b[0x80] =
{
	//8- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
	//9- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x2, 0x3, 0x0, 0x4, 0x5, 0x6,
	//a- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x7, 0x8, 0x0, 0x0, 0x0, 0x9, 0xa, 0xb, 0xc, 0xd,
	//b- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0xe, 0xf, 0x10,0x11,0x12,0x13,0x0, 0x14,0x15,0x16,0x17,0x18,0x19,0x1a,
	//c- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1b,0x0 ,0x1c, 0x1d,0x1e,
	//d- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x0, 0x1f,0x0, 0x0, 0x20,0x21,0x0, 0x22,0x23,0x24,0x25,0x26,0x27,0x28,
	//e- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x0, 0x0, 0x0, 0x29,0x2a,0x2b,0x0, 0x2c,0x2d,0x2e,0x2f,0x30,0x31,0x32,
	//f- 0    1    2    3    4    5    6    7    8    9    a    b    c    d    e    f
	 	 0x0, 0x0, 0x33,0x34,0x35,0x36,0x37,0x38,0x0, 0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f
};

//6/2 Translation
#define TRANSLATE62(x) table62[(x) & 0x3f]
//6/2 De-translation
#define DETRANSLATE62(x) table62b[(x) & 0x7f]

void NibblizeOneSector(FIL* pFile, int track, int sector)
{
	UINT len;
	NibSector* pNibSector;
	FRESULT res;
	uint8_t *pSector;

	int softSector = sectorInterleaves[sector];
	//Read one sector
	f_lseek(pFile, track * BYTES_PER_TRACK + softSector * BYTES_PER_SECTOR);
	res = f_read(pFile, sectorBuffer, BYTES_PER_SECTOR, &len);

	//If data valid
	if (len == BYTES_PER_SECTOR && res == FR_OK)
	{
		pSector = sectorBuffer;
		int checkSum;
		int i, index, section;
		uint8_t pair;

		//Prepare and initialize the sector. pNibSector = start address.
		pNibSector = (NibSector*)(nibTrackBuffer + sector * sizeof(NibSector));
		//Prologs and Epilogs
		pNibSector->addrPart.prolog0 = PROLOG0;
		pNibSector->addrPart.prolog1 = PROLOG1;
		pNibSector->addrPart.prolog2 = PROLOG2_ADDR;
		pNibSector->addrPart.epilog0 = EPILOG0;
		pNibSector->addrPart.epilog1 = EPILOG1;
		pNibSector->addrPart.epilog2 = EPILOG2;
		pNibSector->dataPart.prolog0 = PROLOG0;
		pNibSector->dataPart.prolog1 = PROLOG1;
		pNibSector->dataPart.prolog2 = PROLOG2_DATA;
		pNibSector->dataPart.epilog0 = EPILOG0;
		pNibSector->dataPart.epilog1 = EPILOG1;
		pNibSector->dataPart.epilog2 = EPILOG2;
		//Gap bytes
		memset(pNibSector->gap1, GAP_BYTE, GAP1_LEN);
		memset(pNibSector->gap2, GAP_BYTE, GAP2_LEN);
		OddEvenEncoder(pNibSector->addrPart.volume, volume);

		//Address part
		checkSum = volume ^ track ^ sector;
		OddEvenEncoder(pNibSector->addrPart.track, track);
		OddEvenEncoder(pNibSector->addrPart.sector, sector);
		OddEvenEncoder(pNibSector->addrPart.checksum, checkSum);

		// Nibbilize data into buffer
		memset(auxBuffer, 0, AUX_BUF_LEN);
		for (i = 0; i < BYTES_PER_SECTOR; i++)
		{
			index = i % AUX_BUF_LEN;
			section = i / AUX_BUF_LEN;

			pair = ((pSector[i] & 2) >> 1) | ((pSector[i] & 1) << 1);   // swap the lowest 2 bits
			pSector[i] = pSector[i] >> 2;
			auxBuffer[index] |= pair << (section * 2);
		}

		// Xor pairs of nibbilized bytes in correct order
		index = 0;
		pNibSector->dataPart.data[index++] = TRANSLATE62(auxBuffer[0]);
		for (i = 1; i < AUX_BUF_LEN; i++)
			pNibSector->dataPart.data[index++] = TRANSLATE62(auxBuffer[i] ^ auxBuffer[i - 1]);

		pNibSector->dataPart.data[index++] = TRANSLATE62(pSector[0] ^ auxBuffer[AUX_BUF_LEN - 1]);

		for (i = 1; i < BYTES_PER_SECTOR; i++)
			pNibSector->dataPart.data[index++] = TRANSLATE62(pSector[i] ^ pSector[i - 1]);

		pNibSector->dataPart.data_checksum = TRANSLATE62(pSector[BYTES_PER_SECTOR - 1]);
	}
}

void DenibblizeOneSector(FIL* pFile, int track, int sector, NibSector *pNibSector)
{
	int i;
	uint8_t checksum;
	uint8_t volumn;
	uint8_t lowBits;
	int softSector = sectorInterleaves[sector];

	if (pNibSector == NULL)
		pNibSector = (NibSector*)(nibTrackBuffer + sector * sizeof(NibSector));

	//Data in the address area
	if (sector != OddEvenDecoder(pNibSector->addrPart.sector[0], pNibSector->addrPart.sector[1]))
	{
		//Invalid sector.
	}
	volumn = OddEvenDecoder(pNibSector->addrPart.volume[0], pNibSector->addrPart.volume[1]);
	checksum = OddEvenDecoder(pNibSector->addrPart.checksum[0], pNibSector->addrPart.checksum[1]);
	if (checksum != (volumn ^ (uint8_t)sector ^ (uint8_t)track))
	{
		//Invalid address area checksum!
	}

	//Detranslate 62
	denibSectorBuffer[0] = DETRANSLATE62(pNibSector->dataPart.data[0]);
	for (i = 1; i < BYTES_PER_NIB_SECTOR; i++)
	{
		denibSectorBuffer[i] = DETRANSLATE62(pNibSector->dataPart.data[i]) ^ denibSectorBuffer[i - 1];
	}
	pNibSector->dataPart.data_checksum = DETRANSLATE62(pNibSector->dataPart.data_checksum);

	//Decode
	for (i = 0; i < BYTES_PER_SECTOR; i++)
	{
		int index = i % AUX_BUF_LEN;
		switch (i / AUX_BUF_LEN)
		{
		case 0:
			lowBits = ((denibSectorBuffer[index] & 2) >> 1) | ((denibSectorBuffer[index] & 1) << 1);
			break;
		case 1:
			lowBits = ((denibSectorBuffer[index] & 8) >> 3) | ((denibSectorBuffer[index] & 4) >> 1);
			break;
		case 2:
			lowBits = ((denibSectorBuffer[index] & 0x20) >> 5) | ((denibSectorBuffer[index] & 0x10) >> 3);
			break;
		}
		sectorBuffer[i] = (denibSectorBuffer[i + AUX_BUF_LEN] << 2) | lowBits;
	}

	//Write back to pFile
	f_lseek(pFile,  track * BYTES_PER_TRACK + BYTES_PER_SECTOR * softSector);
	UINT len;
	FRESULT res = f_write(pFile, sectorBuffer, BYTES_PER_SECTOR, &len);
	if (res != FR_OK)
	{
		//File written failed.
	}
}
