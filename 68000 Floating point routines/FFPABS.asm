       TTL     FAST FLOATING POINT ABS/NEG (FFPABS/FFPNEG)
***************************************
* (C) COPYRIGHT 1981 BY MOTOROLA INC. *
***************************************
 
*************************************************************
*                     FFPABS                                *
*           FAST FLOATING POINT ABSOLUTE VALUE              *
*                                                           *
*  INPUT:  D7 - FAST FLOATING POINT ARGUMENT                *
*                                                           *
*  OUTPUT: D7 - FAST FLOATING POINT ABSOLUTE VALUE RESULT   *
*                                                           *
*      CONDITION CODES:                                     *
*              N - CLEARED                                  *
*              Z - SET IF RESULT IS ZERO                    *
*              V - CLEARED                                  *
*              C - UNDEFINED                                *
*              X - UNDEFINED                                *
*                                                           *
*               ALL REGISTERS TRANSPARENT                   *
*                                                           *
*************************************************************
         PAGE
FFPABS IDNT    1,1  FFP ABS/NEG
 
         XDEF      FFPABS    FAST FLOATING POINT ABSOLUTE VALUE
 
       XREF    FFPCPYRT        COPYRIGHT NOTICE
 
         SECTION  9
 
******************************
* ABSOLUTE VALUE ENTRY POINT *
******************************
FFPABS   AND.B     #$7F,D7   CLEAR THE SIGN BIT
         RTS                 AND RETURN TO THE CALLER
         PAGE
*************************************************************
*                     FFPNEG                                *
*           FAST FLOATING POINT NEGATE                      *
*                                                           *
*  INPUT:  D7 - FAST FLOATING POINT ARGUMENT                *
*                                                           *
*  OUTPUT: D7 - FAST FLOATING POINT NEGATED RESULT          *
*                                                           *
*      CONDITION CODES:                                     *
*              N - SET IF RESULT IS NEGATIVE                *
*              Z - SET IF RESULT IS ZERO                    *
*              V - CLEARED                                  *
*              C - UNDEFINED                                *
*              X - UNDEFINED                                *
*                                                           *
*               ALL REGISTERS TRANSPARENT                   *
*                                                           *
*************************************************************
         PAGE
         XDEF      FFPNEG    FAST FLOATING POINT NEGATE
 
**********************
* NEGATE ENTRY POINT *
**********************
FFPNEG   TST.B     D7        ? IS ARGUMENT A ZERO
         BEQ.S     FFPRTN    RETURN IF SO
         EOR.B     #$80,D7   INVERT THE SIGN BIT
FFPRTN   RTS                 AND RETURN TO CALLER
 
         END