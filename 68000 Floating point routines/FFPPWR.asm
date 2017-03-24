         TTL       FAST FLOATING POINT POWER (FFPPWR)
***************************************
* (C) COPYRIGHT 1981 BY MOTOROLA INC. *
***************************************
 
*************************************************
*                  FFPPWR                       *
*       FAST FLOATING POINT POWER FUNCTION      *
*                                               *
*  INPUT:   D6 - FLOATING POINT EXPONENT VALUE  *
*           D7 - FLOATING POINT ARGUMENT VALUE  *
*                                               *
*  OUTPUT:  D7 - RESULT OF THE VALUE TAKEN TO   *
*                THE POWER SPECIFIED            *
*                                               *
*     ALL REGISTERS BUT D7 ARE TRANSPARENT      *
*                                               *
*  CODE SIZE:  36 BYTES   STACK WORK: 42 BYTES  *
*                                               *
* CALLS SUBROUTINES: FFPLOG, FFPEXP AND FFPMUL  *
*                                               *
*  CONDITION CODES:                             *
*        Z - SET IF THE RESULT IS ZERO          *
*        N - CLEARED                            *
*        V - SET IF OVERFLOW OCCURRED OR BASE   *
*            VALUE ARGUMENT WAS NEGATIVE        *
*        C - UNDEFINED                          *
*        X - UNDEFINED                          *
*                                               *
*  NOTES:                                       *
*    1) A NEGATIVE BASE VALUE WILL FORCE THE USE*
*       IF ITS ABSOLUTE VALUE.  THE "V" BIT WILL*
*       BE SET UPON FUNCTION RETURN.            *
*    2) IF THE RESULT OVERFLOWS THEN THE        *
*       MAXIMUM SIZE VALUE IS RETURNED WITH THE *
*       "V" BIT SET IN THE CONDITION CODE.      *
*    3) SPOT CHECKS SHOW AT LEAST SIX DIGIT     *
*       PRECISION FOR 80 PERCENT OF THE CASES.  *
*                                               *
*  TIME: (8MHZ NO WAIT STATES ASSUMED)          *
*                                               *
*        THE TIMING IS VERY DATA SENSITIVE WITH *
*        TEST SAMPLES RANGING FROM 720 TO       *
*        1206 MICROSECONDS                      *
*                                               *
*************************************************
         PAGE
FFPPWR   IDNT  1,1 FFP POWER
 
         OPT       PCS
 
         SECTION   9
 
         XDEF      FFPPWR                        ENTRY POINT
 
         XREF      9:FFPLOG,9:FFPEXP   EXPONENT AND LOG FUNCTIONS
         XREF      9:FFPMUL            MULTIPLY FUNCTION
         XREF      FFPCPYRT            COPYRIGHT STUB
 
*****************
* POWER  ENTRY  *
*****************
 
* TAKE THE LOGORITHM OF THE BASE VALUE
FFPPWR   TST.B     D7                  ? NEGATIVE BASE VALUE
         BPL.S     FPPPOS              BRANCH POSITIVE
         AND.B     #$7F,D7             TAKE ABSOLUTE VALUE
         BSR.S     FPPPOS              FIND RESULT USING THAT
*        OR.B      #$02,CCR            FORCE "V" BIT ON FOR NEGATIVE ARGUMENT
         DC.L      $003C0002           *****ASSEMBLER ERROR*****
         RTS                           RETURN TO CALLER
 
FPPPOS   BSR       FFPLOG              FIND LOG OF THE NUMBER TO BE USED
         MOVEM.L   D3-D5,-(SP)         SAVE MULTIPLY WORK REGISTERS
         BSR       FFPMUL              MULTIPLY BY THE EXPONENT
         MOVEM.L   (SP)+,D3-D5         RESTORE MULTIPLY WORK REGISTERS
* IF OVERFLOWED, FFPEXP WILL SET "V" BIT AND RETURN DESIRED RESULT ANYWAY
         BRA       FFPEXP              RESULT IS EXPONENT
 
         END