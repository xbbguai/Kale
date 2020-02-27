#ifndef _DISKOSD_H
#define _DISKOSD_H

extern uint8_t uartData;
void DiskOSDInit();
void ShowTrackSector(int track, int sector, int nf);	//nf = 1: nibblizing, = 0 :flushing
void PRINT(int x, int y, char *string, int inverse);
void SampleAndTransmitPDLData();

#endif
