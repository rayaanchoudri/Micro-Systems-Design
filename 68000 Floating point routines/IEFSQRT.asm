      TTL    IEEE FORMAT EQUIVALENT SQUARE ROOT (IEFSQRT)
*******************************************
* (C)  COPYRIGHT 1981 BY MOTOROLA INC.    *
*******************************************
 
*************************************************
*                IEFSQRT                        *
*      IEEE FORMAT EQUIVALENT SQUARE ROOT       *
*                                               *
* INPUT:                                        *
*          D7 - IEEE FORMAT ARGUMENT            *
*                                               *
* OUTPUT:                                       *
*          D7 - IEEE FORMAT SQUARE ROOT         *
*                                               *
* CONDITION CODES:                              *
*                                               *
*   IF THE RESULT IS VALID -                    *
*          N - CLEARED                          *
*          Z - SET IF RESULT IS ZERO            *
*          V - CLEARED                          *
*          C - UNDEFINED                        *
*          X - UNDEFINED                        *
*                                               *
*   IF THE RESULT IS INVALID DUE TO A           *
*   NEGATIVE NON-ZERO OR NAN INPUT ARGUMENT-    *
*          N - UNDEFINED                        *
*          Z - CLEARED                          *
*          V - SET                              *
*          C - UNDEFINED                        *
*          X - UNDEFINED                        *
*                                               *
*        ALL REGISTERS ARE TRANSPARENT          *
*                                               *
*        MAXIMUM STACK USED:   24 BYTES         *
*                                               *
* NOTES:                                        *
*   1) VALID RESULTS ARE OBTAINED UNLESS        *
*      THE INPUT ARGUMENT WAS A NEGATIVE        *
*      NON-ZERO NUMBER OR NAN (NOT-A-           *
*      NUMBER) WHICH CAN BE DETERMINED BY       *
*      THE "V" BIT SETTING IN THE CCR.          *
*   2) SEE THE MC68344 USER'S GUIDE FOR         *
*      DETAILS ON THE RANGES HANDLED BY         *
*      THE FAST FLOATING POINT EQUIVALENT       *
*      ROUTINES.                                *
*                                               *
*************************************************
         PAGE
IEFSQRT  IDNT 1,1  IEEE FORMAT EQUIVALENT SQUARE ROOT
 
       SECTION   9
 
      XDEF   IEFSQRT   ENTRY POINT
 
         XREF      9:FFPSQRT FAST FLOATING POINT SQUARE ROOT ROUTINE
         XREF      9:IEFSOP  SINGLE OPERAND FRONT-END HANDLER
         XREF      9:IEFTIEEE BACK-END HANDLER TO RETURN IEEE FORMAT
         XREF      9:IEFRTNAN ERROR HANDLER TO RETURN A NAN (NOT-A-NUMBER)
         XREF      9:IEFRTOD7 RETURN ORIGINAL CALLER'S D7
      XREF   FFPCPYRT  COPYRIGHT NOTICE
 
*********************
* SQUARE ROOT ENTRY *
*********************
IEFSQRT  BSR       IEFSOP    CONVERT THE OPERAND
         BRA.S     IEFNRM    BRANCH BOTH NORMALIZED
* ARGUMENT WAS INFINITY - RETURN A NAN IF MINUS
         BMI       IEFRTNAN  RETURN NAN IF IT IS MINUS INFINITY
         BRA       IEFRTOD7  JUST RETURN INPUT ARGUMENT IF PLUS INFINITY
 
* ARGUMENT WAS NORMALIZED
IEFNRM   BMI       IEFRTNAN  RETURN NAN FOR INVALID NEGATIVE ARGUMENT
         MOVE.L    16(SP),D5 INSURE WAS NOT A NEGATIVE VERY SMALL NUMBER
         BPL.S     IEFSDOIT  BRANCH WAS POSITIVE
         ADD.L     D5,D5     RID SIGN BYTE TO CHECK IF WAS NEGATIVE ZERO
         BNE       IEFRTNAN  RETURN NAN FOR VERY SMALL NEGATIVE NUMBERS ALSO
IEFSDOIT BSR       FFPSQRT   PERFORM SQUARE ROOT
         BRA       IEFTIEEE  AND RETURN IEEE FORMAT BACK TO CALLER
 
         END