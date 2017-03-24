         TTL       FFPIEEE CONVERSIONS TO/FROM FFP (FFPTIEEE,FFPFIEEE)
******************************************
*  (C)  COPYRIGHT 1981 BY MOTOROLA INC.  *
******************************************
 
****************************************************
*        FFPTIEEE AND FFPFIEEE SUBROUTINES         *
*                                                  *
*   THIS MODULE CONTAINS SINGLE-PRECISION          *
*   CONVERSION ROUTINES FOR IEEE FORMAT FLOATING   *
*   POINT (DRAFT 8.0) TO AND FROM MOTOROLA FAST    *
*   FLOATING POINT (FFP) VALUES.                   *
*   THESE CAN BE USED WHEN LARGE GROUPS OF NUMBERS *
*   NEED TO BE CONVERTED BETWEEN FORMATS.  SEE     *
*   THE MC68344 USER'S GUIDE FOR A FULLER          *
*   EXPLANATION OF THE VARIOUS METHODS FOR IEEE    *
*   FORMAT SUPPORT.                                *
*                                                  *
*   THE FAST FLOATING POINT (NON-IEEE FORMAT)      *
*   PROVIDES RESULTS AS PRECISE AS THOSE REQUIRED  *
*   BY THE IEEE SPECIFICATION.  HOWEVER, THIS      *
*   FORMAT HAS SOME MINOR DIFFERENCES:             *
*    1) IF THE TRUE RESULT OF AN OPERATION         *
*       IS EXACTLY BETWEEN REPRESENTABLE           *
*       VALUES, THE FFP ROUND-TO-NEAREST           *
*       FUNCTION MAY ROUND TO EITHER EVEN OR ODD.  *
*    2) THE FFP EXPONENT ALLOWS HALF OF THE RANGE  *
*       THAT THE SINGLE-PRECISION IEEE FORMAT      *
*       PROVIDES (APPROX. 10 TO THE +-19 DECIMAL). *
*    3) THE IEEE FORMAT SPECIFIES INFINITY,        *
*       NOT-A-NUMBER, AND DENORMALIZED DATA        *
*       TYPES THAT ARE NOT DIRECTLY SUPPORTED      *
*       BY THE FFP FORMAT.  HOWEVER, THEY MAY BE   *
*       ADDED VIA CUSTOMIZING OR USED VIA THE IEEE *
*       FORMAT EQUIVALENT COMPATIBLE CALLS         *
*       DESCRIBED IN THE MC68344 USER'S GUIDE.     *
*    4) ALL ZEROES ARE CONSIDERED POSITIVE         *
*       IN FFP FORMAT.                             *
*    5) THE SLIGHTLY HIGHER PRECISION MULTIPLY     *
*       ROUTINE "FFPMUL2" SHOULD BE SUBSTITUTED    *
*       FOR THE DEFAULT ROUTINE "FFPMUL" FOR       *
*       COMPLETELY EQUIVALENT PRECISION.           *
*                                                  *
****************************************************
         PAGE
FFPIEEE  IDNT   1,1  FFP CONVERSIONS TO/FROM IEEE FORMAT
 
         SECTION   9
 
         XDEF      FFPTIEEE,FFPFIEEE
 
****************************************************
*               FFPTIEEE                           *
*                                                  *
*  FAST FLOATING POINT TO IEEE FORMAT              *
*                                                  *
*   INPUT:   D7 - FAST FLOATING POINT VALUE        *
*                                                  *
*   OUTPUT:  D7 - IEEE FORMAT FLOATING POINT VALUE *
*                                                  *
*   CONDITION CODES:                               *
*            N - SET IF THE RESULT IS NEGATIVE     *
*            Z - SET IF THE RESULT IS ZERO         *
*            V - UNDEFINED                         *
*            C - UNDEFINED                         *
*            X - UNDEFINED                         *
*                                                  *
*   NOTES:                                         *
*     1) NO WORK STORAGE OR REGISTERS REQUIRED.    *
*     2) ALL ZEROES WILL BE CONVERTED POSITIVE.    *
*     3) NO NOT-A-NUMBER, INIFINITY, DENORMALIZED, *
*        OR INDEFINITES GENERATED. (UNLESS         *
*        USER CUSTOMIZED.)                         *
*                                                  *
*   TIMES (ASSUMING IN-LINE CODE):                 *
*           VALUE ZERO      18 CYCLES              *
*           VALUE NOT ZERO  66 CYCLES              *
*                                                  *
****************************************************
 
FFPTIEEE EQU       *
 
         ADD.L     D7,D7     DELETE MANTISSA HIGH BIT
         BEQ.S     DONE1     BRANCH ZERO AS FINISHED
         EOR.B     #$80,D7   TO TWOS COMPLEMENT EXPONENT
         ASR.B     #1,D7     FORM 8-BIT EXPONENT
         SUB.B     #$82,D7   ADJUST 64 TO 127 AND EXCESSIZE
         SWAP.W    D7        SWAP FOR HIGH BYTE PLACEMENT
         ROL.L     #7,D7     SET SIGN+EXP IN HIGH BYTE
DONE1    EQU       *
 
         RTS                 RETURN TO CALLER
         PAGE
************************************************************
*                     FFPFIEEE                             *
*         FAST FLOATING POINT FROM IEEE FORMAT             *
*                                                          *
*   INPUT:   D7 - IEEE FORMAT FLOATING POINT VALUE         *
*   OUTPUT:  D7 - FFP FORMAT FLOATING POINT VALUE          *
*                                                          *
*   CONDITION CODES:                                       *
*            N - UNDEFINED                                 *
*            Z - SET IF THE RESULT IS ZERO                 *
*            V - SET IF RESULT OVERFLOWED FFP FORMAT       *
*            C - UNDEFINED                                 *
*            X - UNDEFINED                                 *
*                                                          *
*   NOTES:                                                 *
*     1) REGISTER D5 IS USED FOR WORK STORAGE AND NOT      *
*        TRANSPARENT.                                      *
*     2) NOT-A-NUMBER, INIFINITY, AND DENORMALIZED         *
*        TYPES AS WELL AS AN EXPONENT OUTSIDE OF FFP RANGE *
*        GENERATE A BRANCH TO A SPECIFIC PART OF THE       *
*        ROUTINE.  CUSTOMIZING MAY EASILY BE DONE THERE.   *
*                                                          *
*        THE DEFAULT ACTIONS FOR THE VARIOUS TYPES ARE:    *
*      LABEL      TYPE         DEFAULT SUBSTITUTION        *
*      -----      ----         --------------------        *
*       NAN    NOT-A-NUMBER    ZERO                        *
*       INF    INFINITY        LARGEST FFP VALUE SAME SIGN *
*                              ("V" SET IN CCR)            *
*       DENOR  DENORMALIZED    ZERO                        *
*       EXPHI  EXP TOO LARGE   LARGEST FFP VALUE SAME SIGN *
*                              ("V" SET IN CCR)            *
*       EXPLO  EXP TOO SMALL   ZERO                        *
*                                                          *
*   TIMES (ASSUMING IN-LINE CODE):                         *
*           VALUE ZERO      78 CYCLES                      *
*           VALUE NOT ZERO  72 CYCLES                      *
*                                                          *
************************************************************
 
VBIT     EQU       $02       CONDITION CODE REGISTER "V" BIT MASK
 
FFPFIEEE EQU       *
 
         SWAP.W    D7        SWAP WORD HALVES
         ROR.L     #7,D7     EXPONENT TO LOW BYTE
         MOVE.L    #-128,D5  LOAD $80 MASK IN WORK REGISTER
         EOR.B     D5,D7     CONVERT FROM EXCESS 127 TO TWO'S-COMPLEMENT
         ADD.B     D7,D7     FROM 8 TO 7 BIT EXPONENT
         BVS.S     FFPOVF    BRANCH WILL NOT FIT
         ADD.B     #2<<1+1,D7 ADJUST EXCESS 127 TO 64 AND SET MANTISSA HIGH BIT
         BVS.S     EXPHI     BRANCH EXPONENT TOO LARGE (OVERFLOW)
         EOR.B     D5,D7     BACK TO EXCESS 64
         ROR.L     #1,D7     TO FAST FLOAT REPRESENTATION ("V" CLEARED)
DONE2    EQU       *
 
         RTS                 RETURN TO CALLER
         PAGE
* OVERFLOW DETECTED - CAUSED BY ONE OF THE FOLLOWING:
*        - FALSE OVERFLOW DUE TO DIFFERENCE BETWEEN EXCESS 127 AND 64 FORMAT
*        - EXPONENT TOO HIGH OR LOW TO FIT IN 7 BITS (EXPONENT OVER/UNDERFLOW)
*        - AN EXPONENT OF $FF REPRESENTING AN INFINITY
*        - AN EXPONENT OF $00 REPRESENTING A ZERO, NAN, OR DENORMALIZED VALUE
FFPOVF   BCC.S     FFPOVLW   BRANCH IF OVERFLOW (EXPONENT $FF OR TOO LARGE)
* OVERFLOW - CHECK FOR POSSIBLE FALSE OVERFLOW DUE TO DIFFERENT EXCESS FORMATS
         CMP.B     #$7C,D7   ? WAS ORIGINAL ARGUMENT REALLY IN RANGE
         BEQ.S     FFPOVFLS  YES, BRANCH FALSE OVERFLOW
         CMP.B     #$7E,D7   ? WAS ORIGINAL ARGUMENT REALLY IN RANGE
         BNE.S     FFPTOVF   NO, BRANCH TRUE OVERFLOW
FFPOVFLS ADD.B     #$80+2<<1+1,D7  EXCESS 64 ADJUSTMENT AND MANTISSA HIGH BIT
         ROR.L     #1,D7     FINALIZE TO FAST FLOATING POINT FORMAT
         TST.B     D7        INSURE NO ILLEGAL ZERO SIGN+EXPONENT BYTE
         BNE.S     DONE2     DONE IF DOES NOT SET S+EXP ALL ZEROES
         BRA.S     EXPLO     TREAT AS UNDERFLOWED EXPONENT OTHERWISE
* EXPONENT LOW - CHECK FOR ZERO, DENORMALIZED VALUE, OR TOO SMALL AN EXPONENT
FFPTOVF  AND.W     #$FEFF,D7 CLEAR SIGN BIT OUT
         TST.L     D7        ? ENTIRE VALUE NOW ZERO
         BEQ.S     DONE2     BRANCH IF VALUE IS ZERO
         TST.B     D7        ? DENORMALIZED NUMBER (SIGNIFICANT#0, EXP=0)
         BEQ.S     DENOR     BRANCH IF DENORMALIZED
 
***************
*****EXPLO - EXPONENT TO SMALL FOR FFP FORMAT
***************
*  THE SIGN BIT WILL BE BIT 8.
EXPLO    MOVE.L    #0,D7     DEFAULT ZERO FOR THIS CASE ("V" CLEARED)
         BRA.S     DONE2     RETURN TO MAINLINE
 
***************
*****DENOR - DENORMALIZED NUMBER
***************
DENOR    MOVE.L    #0,D7     DEFAULT IS TO RETURN A ZERO ("V" CLEARED)
         BRA.S     DONE2     RETURN TO MAINLINE
 
* EXPONENT HIGH - CHECK FOR EXPONENT TOO HIGH, INFINITY, OR NAN
FFPOVLW  CMP.B     #$FE,D7   ? WAS ORIGINAL EXPONENT $FF
         BNE.S     EXPHI     NO, BRANCH EXPONENT TOO LARGE
         LSR.L     #8,D7     SHIFT OUT EXPONENT
         LSR.L     #1,D7     SHIFT OUT SIGN
         BNE.S     NAN       BRANCH NOT-A-NUMBER
 
***************
*****INF - INFINITY
***************
*  THE CARRY AND X BIT REPRESENT THE SIGN
INF      MOVE.L    #-1,D7    SETUP MAXIMUM FFP VALUE
         ROXR.B    #1,D7     SHIFT IN SIGN
         OR.B      #VBIT,SR  SHOW OVERFLOW OCCURED
         BRA.S     DONE2     RETURN WITH MAXIMUM SAME SIGN TO MAINLINE
 
***************
*****EXPHI - EXPONENT TO LARGE FOR FFP FORMAT
***************
*  THE SIGN BIT WILL BE BIT 8.
EXPHI    LSL.W     #8,D7     SET X BIT TO SIGN
         MOVE.L    #-1,D7    SETUP MAXIMUM NUMBER
         ROXR.B    #1,D7     SHIFT IN SIGN
         OR.B      #VBIT,SR  SHOW OVERFLOW OCURRED
         BRA.S     DONE2     RETURN MAXIMUM SAME SIGN TO MAINLINE
 
***************
*****NAN - NOT-A-NUMBER
***************
* BITS 0 THRU 22 CONTAIN THE NAN DATA FIELD
NAN      MOVE.L    #0,D7     DEFAULT TO A ZERO ("V" BIT CLEARED)
         BRA.S     DONE2     RETURN TO MAINLINE
 
         END