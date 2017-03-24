#include "DebugMonitor.h"

// pointers to internal graphics registers

#define GraphicsCommandReg   	(*(volatile unsigned short int *)(0xFF100000))
#define GraphicsStatusReg   		(*(volatile unsigned short int *)(0xFF100000))
#define GraphicsX1Reg   		(*(volatile unsigned short int *)(0xFF100002))
#define GraphicsY1Reg   		(*(volatile unsigned short int *)(0xFF100004))
#define GraphicsX2Reg   		(*(volatile unsigned short int *)(0xFF100006))
#define GraphicsY2Reg   		(*(volatile unsigned short int *)(0xFF100008))
#define GraphicsX3Reg   		(*(volatile unsigned short int *)(0xFF10000A))
#define GraphicsY3Reg   		(*(volatile unsigned short int *)(0xFF10000C))
#define GraphicsColourReg   		(*(volatile unsigned short int *)(0xFF10000E))
#define GraphicsBackGroundColourReg   (*(volatile unsigned short int *)(0xFF100010))
#define GraphicsModeReg   		(*(volatile unsigned short int *)(0xFF100012))

// the following register controls vertical scrolling. However it not implemented on your design
// however you should still write 0 to this register at start of program

#define VScrollRegister 		(*(volatile unsigned short int *)(0xFF100020))

// graphics command values – write these values to the command register to get it to draw a shape
// not all shapes are implemented only putpixel and getpixel. Part of this assignment is to design
// some of the others

#define DrawHLine			1
#define DrawVLine			2
#define DrawLine			3
#define DrawCircle 			4
#define DrawFilledCircle		5
#define DrawChar			6
#define DrawCharBackGroundFill 	7
#define DrawFilledTriangle	 	8
#define DrawFilledRectangle		9
#define PutAPixel			0xA
#define GetAPixel			0xB

// /********************************************************************************************
// **	Colours for graphics display (add as required)
// **
// ** each number is an entry into the colour pallette which define a 24 bit RGB value
// *********************************************************************************************/

// // see --http://www.rapidtables.com/web/color/RGB_Color.htm for example colours

// #define	BLACK_X		0
// #define	WHITE_X		1
// #define	RED_X		2
// #define	GREEN_X		3
// #define	BLUE_X		4
// #define	YELLOW_X	5
// #define	CYAN_X		6
// #define	MAGENTA_X 	7
// // etc.


/***********************************************************************************************
** This macro pauses your program until the graphics chip is idle and ready for a new command
** call this before accessing any registers in the graphics chip to make sure it is idle
***********************************************************************************************/

#define WAIT_FOR_GRAPHICS	while((GraphicsStatusReg & 0x0001) != 0x0001);

/***********************************************************************************************
* This function writes a single pixel to the x,y coords  in the colour specified
***********************************************************************************************/
void WriteAPixel(int x, int y, int Colour)
{
	WAIT_FOR_GRAPHICS;

	GraphicsX1Reg = x;				// write coords to x1, y1
	GraphicsY1Reg = y;
	GraphicsColourReg = Colour;		
	GraphicsCommandReg = PutAPixel; 	// write pixel
}

/***********************************************************************************************
* This function reads a single pixel from the x,y coords specified
***********************************************************************************************/

int ReadAPixel(int x, int y)
{
	WAIT_FOR_GRAPHICS;				// is graphics ready for new command

	GraphicsX1Reg = x;					// write coords to x1, y1
	GraphicsY1Reg = y;
	GraphicsCommandReg = GetAPixel;			// write a get pixel command

	WAIT_FOR_GRAPHICS;				// is graphics done
return (int)(GraphicsColourReg) ;
}

/***********************************************************************************************
* This function draws a horizontal line from coordinate (x1, y1) to (x2, y2)
* y2 needs to be equal to y1
***********************************************************************************************/

void DrawHLineCommand(int x1, int y1, int x2, int y2, int Colour)
{
	WAIT_FOR_GRAPHICS;

	GraphicsX1Reg = x1;				// write coords to x1, y1
	GraphicsY1Reg = y1;
	GraphicsX2Reg = x2;				// write coords to x1, y1
	GraphicsY2Reg = y2;
	GraphicsColourReg = Colour;		
	GraphicsCommandReg = DrawHLine; 	// write pixel
}

void DrawVLineCommand(int x1, int y1, int x2, int y2, int Colour)
{
	WAIT_FOR_GRAPHICS;

	GraphicsX1Reg = x1;				// write coords to x1, y1
	GraphicsY1Reg = y1;
	GraphicsX2Reg = x2;				// write coords to x1, y1
	GraphicsY2Reg = y2;
	GraphicsColourReg = Colour;		
	GraphicsCommandReg = DrawVLine; 	// write pixel
}

void DrawAnyLineCommand(int x1, int y1, int x2, int y2, int Colour)
{
	WAIT_FOR_GRAPHICS;

	GraphicsX1Reg = x1;				// write coords to x1, y1
	GraphicsY1Reg = y1;
	GraphicsX2Reg = x2;				// write coords to x1, y1
	GraphicsY2Reg = y2;
	GraphicsColourReg = Colour;		
	GraphicsCommandReg = DrawLine; 	// write pixel
}

// int main(void)
// {

	// WriteAPixel(100,100, RED_X) ;					// write colour ‘2’ to [100,100]
	// printf("Read pixel value %d\n",ReadAPixel(100,100));		// should read 2 back
	
	// DrawHLineCommand(100,100,200,100,BLUE_X) ;
	
	// DrawHLineCommand(100,300,200,300,GREEN_X) ;

	// return 0 ;
// }
