         TTL       IEEE FORMAT EQUIVALENT LOG (IEFLOG)
***************************************
* (C) COPYRIGHT 1981 BY MOTOROLA INC. *
***************************************
 
*************************************************
*                  IEFLOG                       *
*       FAST FLOATING POINT LOGORITHM           *
*                                               *
*  INPUT:   D7 - IEEE FORMAT INPUT ARGUMENT     *
*                                               *
*  OUTPUT:  D7 - IEEE FORMAT LOGORITHMIC RESULT *
*                                               *
*     ALL OTHER REGISTERS TOTALLY TRANSPARENT   *
*                                               *
*  CONDITION CODES:                             *
*        Z - SET IF RESULT IS ZERO              *
*        N - SET IF RESULT IS NEGATIVE          *
*        V - SET IF RESULT IS NAN (NOT-A-NUMBER)*
*            (NEGATIVE OR NAN ARGUMENT)         *
*        C - UNDEFINED                          *
*        X - UNDEFINED                          *
*                                               *
*         ALL OTHER REGISTERS TRANSPARENT       *
*                                               *
*         MAXIMUM STACK USED:   54 BYTES        *
*                                               *
*  NOTES:                                       *
*    1) SEE THE MC68344 USER'S GUIDE FOR DETAILS*
*       CONCERNING IEEE FORMAT NORMALIZED RANGE *
*       SUPPORT LIMITATIONS.                    *
*    2) SPOT CHECKS SHOW RELATIVE ERRORS BOUNDED*
*       BY 5 X 10**-8.                          *
*    2) NEGATIVE ARGUMENTS ARE ILLEGAL AND CAUSE*
*       A NAN (NOT-A-NUMBER) TO BE RETURNED.    *
*    3) A ZERO ARGUMENT RETURNS MINUS INFINITY. *
*                                               *
*************************************************
         PAGE
IEFLOG   IDNT  1,1 IEEE FORMAT EQUIVALENT LOGORITHM
 
         OPT       PCS
         SECTION   9
 
         XDEF      IEFLOG                        ENTRY POINT
 
         XREF      9:FFPLOG            FFP LOGORITHM ROUTINE
         XREF      9:IEFSOP            FRONT-END OPERAND CONVERSION ROUTINE
         XREF      9:IEFTIEEE          BACK-END CONVERT TO IEEE AND RETURN
         XREF      9:IEFRTNAN          BACK-END RETURN NAN ROUTINE
         XREF      9:IEFRTOD7          RETURN ORIGINAL D7 FROM THE CALLER
         XREF      FFPCPYRT            COPYRIGHT STUB
 
**************
* LOG ENTRY  *
**************
IEFLOG   BSR       IEFSOP    CONVERT THE OPERAND
         BRA.S     IEFNRM    +0  BRANCH NORMALIZED VALUE
* INPUT ARGUMENT IS INFINITY               +8
         BMI       IEFRTNAN  RETURN A NAN FOR A NEGATIVE ARGUMENT
         BRA       IEFRTOD7  RETURN PLUS INFINITY AS THE RESULT
 
* ARGUMENT IS NORMALIZED
IEFNRM   BMI       IEFRTNAN  RETURN A NAN IF ARGUMENT IS NEGATIVE
         BSR       FFPLOG    CALL FAST FLOATING POINT LOG ROUTINE
         BRA       IEFTIEEE  AND RETURN RESULT IN IEEE FORMAT
 
         END