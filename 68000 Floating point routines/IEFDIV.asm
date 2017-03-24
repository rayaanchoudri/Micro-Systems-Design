       TTL     IEEE FORMAT EQUIVALENT DIVIDE (IEFDIV)
***************************************
* (C) COPYRIGHT 1981 BY MOTOROLA INC. *
***************************************
 
*************************************************************
*                        IEFDIV                             *
*     FAST FLOATING POINT IEEE FORMAT EQUIVALENT DIVIDE     *
*                                                           *
*  INPUT:  D6 - IEEE FORMAT NUMBER DIVISOR (SOURCE)         *
*          D7 - IEEE FORMAT NUMBER DIVIDEND (DESTINATION)   *
*                                                           *
*  OUTPUT: D7 - IEEE FORMAT FLOATING RESULT OF REGISTER D6  *
*               DIVIDED INTO REGISTER D7                    *
*                                                           *
*  CONDITION CODES:                                         *
*          N - RESULT IS NEGATIVE                           *
*          Z - RESULT IS ZERO                               *
*          V - RESULT IS NAN (NOT-A-NUMBER)                 *
*          C - UNDEFINED                                    *
*          X - UNDEFINED                                    *
*                                                           *
*               ALL REGISTERS TRANSPARENT                   *
*                                                           *
*            MAXIMUM STACK USAGE:  24 BYTES                 *
*                                                           *
*  RESULT MATRIX:              ARG 2                        *
*                  OTHERS    ZERO    INFINITY      NAN      *
*     ARG 1      ****************************************   *
*   OTHERS       *   A    *    B    *    C     *    F   *   *
*   ZERO         *   C    *    D    *    C     *    F   *   *
*   INFINITY     *   B    *    B    *    D     *    F   *   *
*   NAN          *   E    *    E    *    E     *    F   *   *
*                ****************************************   *
*       A = RETURN DIVIDE RESULT, OVERFLOWING TO INFINITY,  *
*           UNDERFLOWING TO ZERO WITH PROPER SIGN           *
*       B = RETURN ZERO WITH PROPER SIGN                    *
*       C = RETURN INFINITY WITH PROPER SIGN                *
*       D = RETURN NEWLY CREATED NAN (NOT-A-NUMBER)         *
*       E = RETURN ARG1 (NAN) UNCHANGED                     *
*       F = RETURN ARG2 (NAN) UNCHANGED                     *
*                                                           *
*  NOTES:                                                   *
*    1) SEE THE MC68344 USER'S GUIDE FOR A DESCRIPTION OF   *
*       THE POSSIBLE DIFFERENCES BETWEEN THE RESULTS        *
*       RETURNED HERE VERSUS THOSE REQUIRED BY THE          *
*       IEEE STANDARD.                                      *
*                                                           *
*************************************************************
         PAGE
IEFDIV IDNT    1,1  IEEE FORMAT EQUIVALENT DIVIDE
 
         OPT       PCS
 
         XDEF      IEFDIV    IEEE FORMAT EQUIVALENT DIVIDE
 
         XREF      9:IEFDOP  DOUBLE ARGUMENT CONVERSION ROUTINE
         XREF      9:IEFRTNAN CREATE AND RETURN NAN RESULT ROUTINE
         XREF      9:IEFTIEEE RETURN AND CONVERT BACK TO IEEE FORMAT
         XREF      9:IEFRTSZE RETURN SIGNED ZERO WITH EXCLUSIVE OR SIGNS
         XREF      9:IEFRTIE  RETURN INFINITY WITH EXCLUSIVE OR SIGNS
         XREF      9:FFPDIV    REFERENCE FAST FLOATING POINT DIVIDE ROUTINE
       XREF    FFPCPYRT        COPYRIGHT NOTICE
 
         SECTION  9
 
**********************
* DIVIDE ENTRY POINT *
**********************
IEFDIV   BSR       IEFDOP    DECODE BOTH OPERANDS
         BRA.S     IEFNRM    +0 BRANCH NORMALIZED
         BRA.S     IEFRTINF  +2 BRANCH ARG2 INFINITY
         BRA.S     IEFRTZRO  +4 BRANCH ARG1 INFINITY
* BOTH ARE INFINITY - RETURN A NAN      +6 BOTH ARE INFINITY
         BRA       IEFRTNAN  RETURN A NAN FOR INFINITY INTO INFINITY
 
* ARG1 INFINITY - RETURN ZERO WITH PROPER SIGN
IEFRTZRO BRA       IEFRTSZE  RETURN ZERO WITH EXCLUSIVE OR'ED SIGN
 
* ARG2 INFINITY BUT NOT ARG1 - RETURN INFINITY WITH PROPER SIGN
IEFRTINF BRA       IEFRTIE   RETURN INFINITY WITH EXCLUSIVE OR'ED SIGN
 
* NORMALIZED NUMBERS - TEST FOR ZEROES
IEFNRM   TST.L     D7        ? DIVIDEND ZERO (ARG2)
         BNE.S     IEF2NZ    NO, GO TEST DIVISOR FOR ZERO
         TST.L     D6        ? ARE BOTH ZERO
         BNE.S     IEFRTZRO  NO, JUST DIVIDEND - RETURN A ZERO
         BRA       IEFRTNAN  RETURN A NAN FOR ZERO INTO ZERO
 
* DIVIDEND (ARG2) NOT ZERO
IEF2NZ   TST.L     D6        ? DIVISOR ZERO (ARG1) BUT NOT DIVIDEND (ARG2)
         BEQ.S     IEFRTINF  YES, RETURN INFINITY WITH PROPER SIGN
 
* BOTH ARGUMENTS NON ZERO AND NORMALIZED - DO THE DIVIDE
         BSR       FFPDIV    DO FAST FLOATING POINT DIVIDE
         BEQ       IEFRTZRO  IF RESULT IS ZERO RETURN A PROPER SIGN ZERO
         BRA       IEFTIEEE  CONVERT RESULT BACK TO IEEE FORMAT
 
         END