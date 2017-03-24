#include "DebugMonitor.h"

/*
 * Filename: FlashRoutines.c
 *
 * Modified on February 8, 2016
 * Authors: Rayaan Choudri  46984118
 *          Tim Tseng       39443114
*/

/* erase chip by writing to address with data*/
void EraseFlashChip(void)
{
    // unsigned char *FlashPtr = (unsigned char *) (0x01000000) ;

    // //1st cycle of erase operation
    // FlashPtr[0xAAA << 1] = 0xAA ;

    // //cycle 2
    // FlashPtr[0x555 << 1] = 0x55 ;

    // //cycle 3
    // FlashPtr[0xAAA << 1] = 0x80 ;

    // //cycle 4
    // FlashPtr[0xAAA << 1] = 0xAA ;

    // //cycle 5
    // FlashPtr[0x555 << 1] = 0x55 ;

    // //cycle 6 - erases chip
    // FlashPtr[0xAAA << 1] = 0x10 ;

    // //polls chips untill erase is complete
    // while( (FlashPtr[0x0 << 1] & 0x80)!= 0x80) {}
}

void FlashReset(void)
{
    // unsigned char *FlashPtr = (unsigned char *) (0x01000000) ;
    // *FlashPtr = 0xF0 ;
}

/* erase sector by writing to address with data*/
void FlashSectorErase(int SectorAddress)
{
    // unsigned char *FlashPtr = (unsigned char *) (0x01000000) ;

    // // Must shift the sector address to be on flash address-lines 21-13
    // // For some reason if we wanted to use shift size = 13 to put it on
    // // lines 20-12 it doesn't work...might be our flash chip model
    // int sector_shift_size = 14 ;

    // //1st cycle of erase operation
    // FlashPtr[0xAAA << 1] = 0xAA;

    // //cycle 2
    // FlashPtr[0x555 << 1] = 0x55 ;

    // //cycle 3
    // FlashPtr[0xAAA << 1] = 0x80 ;

    // //cycle 4
    // FlashPtr[0xAAA << 1] = 0xAA ;

    // //cycle 5
    // FlashPtr[0x555 << 1] = 0x55 ;

    // //cycle 6 - writes to the sector address passed in for sector erase
    // FlashPtr[SectorAddress << sector_shift_size] = 0x30 ;

    // //polls chips untill erase is complete
    // while( (FlashPtr[SectorAddress << sector_shift_size] & 0x80) != 0x80) {}
}

/* program chip by writing to address with data*/
void FlashProgram(unsigned int AddressOffset, int ByteData)		// write a byte to the specified address (assumed it has been erased first)
{
    // unsigned char *FlashPtr = (unsigned char *) (0x01000000) ;

    // //1st cycle of program operation
    // FlashPtr[0xAAA << 1] = 0xAA ;

    // //cycle 2
    // FlashPtr[0x555 << 1] = 0x55 ;

    // //cycle 3
    // FlashPtr[0xAAA << 1] = 0xA0 ;

    // //cycle 4 - write byte size data to flash address
    // FlashPtr[AddressOffset << 1] = (unsigned char) ByteData  ;

    // //polls chips untill program is complete
    // while ( (FlashPtr[AddressOffset << 1] & 0x80) != (ByteData & 0x80) ) {}

}

/* program chip to read a byte */
unsigned char FlashRead(unsigned int AddressOffset)		// read a byte from the specified address (assumed it has been erased first)
{
    // unsigned char *FlashPtr = (unsigned char *) (0x01000000) ;
    // unsigned char data;
    // data = FlashPtr[AddressOffset << 1];
	// return data ; 	// return data at address
	return 0;
}