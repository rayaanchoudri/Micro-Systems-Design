       TTL     IEEE FORMAT EQUIVALENT ASCII TO FLOAT (IEFAFP)
************************************
* (C) COPYRIGHT 1981 MOTORLA INC.  *
************************************
 
***********************************************************
*  IEFAFP  -  CONVERT ASCII TO IEEE FORMAT EQUIVALENT     *
*        IEEE FORMAT EQUIVALENT FAST FLOATING POINT       *
*                                                         *
*      INPUT:  A0 - POINTER TO ASCII STRING OF A FORMAT   *
*                   DESCRIBED BELOW                       *
*                                                         *
*      OUTPUT: D7 - IEEE FORMAT FLOATING POINT EQUIVALENT *
*              A0 - POINTS TO THE CHARACTER WHICH         *
*                   TERMINATED THE SCAN                   *
*                                                         *
*      CONDITION CODES:                                   *
*                N - SET IF RESULT IS NEGATIVE            *
*                Z - SET IF RESULT IS ZERO                *
*                V - SET IF RESULT IS NAN (NOT-A-NUMBER)  *
*                C - SET IF INVALID FORMAT DETECTED       *
*                X - UNDEFINED                            *
*                                                         *
*            ALL REGISTERS ARE PRESERVED                  *
*                                                         *
*          MAXIMUM STACK USED:     48 BYTES               *
*                                                         *
*      INPUT FORMAT:                                      *
*                                                         *
*     {SIGN}{DIGITS}{'.'}{DIGITS}{'E'}{SIGN}{DIGITS}      *
*     <*********MANTISSA********><*****EXPONENT****>      *
*                                                         *
*                        - OR -                           *
*                                                         *
*                  >>  FOR POSITIVE INFINITY              *
*                  <<  FOR NEGATIVE INFINITY              *
*                  ..  FOR NAN (NOT-A-NUMBER)             *
*                                                         *
*                   SYNTAX RULES                          *
*          BOTH SIGNS ARE OPTIONAL AND ARE '+' OR '-'.    *
*          THE MANTISSA MUST BE PRESENT.                  *
*          THE EXPONENT NEED NOT BE PRESENT.              *
*          THE MANTISSA MAY LEAD WITH A DECIMAL POINT.    *
*          THE MANTISSA NEED NOT HAVE A DECIMAL POINT.    *
*                                                         *
*      EXAMPLES:  ALL OF THESE VALUES REPRESENT THE       *
*                 NUMBER ONE-HUNDRED-TWENTY.              *
*                                                         *
*                       120            .120E3             *
*                       120.          +.120E+03           *
*                      +120.          0.000120E6          *
*                   0000120.00  1200000E-4                *
*                               1200000.00E-0004          *
*                                                         *
*      FLOATING POINT RANGE:                              *
*                                                         *
*          NUMERIC INPUT OTHER THAN THE SPECIAL SYMBOLS   *
*          FOR NAN (NOT-A-NUMBER) AND INFINITY MUST BE    *
*          WITHIN THE FOLLOWING RANGES OR ZERO:           *
*                                                         *
*                   18                             -20    *
*    9.22337177 X 10   > +NUMBER >  5.42101070 X 10       *
*                                                         *
*                   18                             -20    *
*   -9.22337177 X 10   > -NUMBER > -2.71050535 X 10       *
*                                                         *
*          VALUES WHICH ARE NOT ZERO OR A SPECIAL SYMBOL  *
*          AND WHOSE MAGNITUDES ARE NOT WITHIN THE ABOVE  *
*          RANGES WILL BE FORCED TO SIGNED ZERO IF TOO    *
*          SMALL OR A SIGNED INFINITY IF TOO LARGE.       *
*                                                         *
*      PRECISION:                                         *
*                                                         *
*          THIS CONVERSION RESULTS IN A FORMAT EQUIVALENT *
*          TO IEEE SINGLE-PRECISION WITH GUARANTEED ERROR *
*          LESS THAN OR EQUAL TO ONE-HALF LEAST           *
*          SIGNIFICANT BIT (23.5 BITS) FOR VALUES WITHIN  *
*          THE ALLOWED RANGES AS DESCRIBED ABOVE.         *
*                                                         *
*      NOTES:                                             *
*          1) IF THE 'C' BIT IN THE CCR INDICATES AN      *
*             INVALID PATTERN DETECTED, THEN A0 WILL      *
*             POINT TO THE INVALID CHARACTER.             *
*                                                         *
***********************************************************
         PAGE
IEFAFP IDNT    1,1  IEEE FORMAT EQUIVALENT ASCII TO FLOAT
 
         OPT       PCS
 
         XDEF      IEFAFP    ENTRY POINT DEFINITION
 
      XREF    9:FFPAFP    FAST FLOATING POINT CONVERSION ROUTINE
         XREF      9:IEFTIEEE FFP CONVERSION TO IEEE FORMAT
         XREF      9:IEFRTNAN INTERNAL RETURN A GENERATED NAN ROUTINE
      XREF    FFPCPYRT    COPYRIGHT NOTICE
 
         SECTION    9
 
EXPMSK   EQU       $7F800000 IEEE FORMAT EXPONENT LOCATION MASK
NEGZERO  EQU       $80000000 IEEE FORMAT NEGATIVE ZERO VALUE
 
***************************************
* ASCII TO IEEE FLOATING POINT FORMAT *
***************************************
IEFAFP   MOVEM.L   D3-D7,-(SP)         SAVE CALLER'S REGISTERS
         MOVE.B    (A0)+,D3  LOAD FIRST CHAR
* ISOLATE NEGATIVE VALUES TO FORCE PROPER SIGN FOR ZERO
         CMP.B     #'-',D3   ? BRANCH NEGATIVE - NOT SPECIAL SYMBOL
         BEQ.S     IEFMINUS  BRANCH IF MINUS NUMERIC VALUE
* CHECK FOR INFINITY OR NAN TYPES
         LSL.W     #8,D3     SHIFT OVER A BYTE
         MOVE.B    (A0)+,D3  LOAD NEXT BYTE
         MOVE.L    #0,D7     ASSUME POSITIVE INFINITY
         CMP.W     #'>>',D3  ? PLUS INFINITY
         BEQ.S     IEFGOTI   BRANCH IF SO
         CMP.W     #'<<',D3  ? MINUS INFINITY
         BNE.S     IEFTRYN   NO, TRY NAN
         MOVE.L    #-1,D7    SHOW NEGATIVE INFINITY
* RETURN PLUS OR MINUS INFINITY
IEFGOTI  LSL.L     #1,D7     SET "X" TO SIGN BIT
         MOVE.L    #EXPMSK<<1,D7  SET EXPONENT BITS ALL ONES AND OVER TO LEFT
         ROXR.L    #1,D7     INSERT PROPER SIGN IN
         MOVEM.L   (SP)+,D3-D6 RESTORE REGISTERS
         ADD.L     #4,SP     SKIP STORED D7
         RTS                 RETURN TO CALLER "C" CLEARED
 
* NEGATIVE VALUE - DO CONVERSION AND FORCE MINUS SIGN IF ZERO
IEFMINUS SUB.L     #1,A0     BACK TO START OF MINUS SIGN
         BSR       FFPAFP    CONVERT REMAINDER TO FLOATING POINT
         BCS.S     IEFFAIL   BRANCH IF ERROR IN CONVERSION
         BNE.S     IEFGOOD   BRANCH IF GOOD AND NOT ZERO
         MOVE.L    #NEGZERO,D7 RETURN NEGATIVE ZERO
         MOVE.L    #0,D6     SET CONDITION CODE FOR ZERO RETURN
         MOVEM.L   (SP)+,D3-D6  RESTORE ALL BUT D7
         ADD.L     #4,SP     SKIP D7 ON STACK
         RTS                 RETURN TO CALLER WITH SIGNED ZERO
 
* TRY A NAN
IEFTRYN  CMP.W     #'..',D3  ? NAN HERE
         BEQ       IEFRTNAN  YES, RETURN A NAN TO THE CALLER
* NOT A SPECIAL CASE - CONVERT IT
         SUB.L     #2,A0     BACK TO ORIGINAL POINTER POSITION
         BSR       FFPAFP    CONVERT TO FAST FLOATING POINT
IEFGOOD  BCC       IEFTIEEE  AND FINALLY TO IEEE FORMAT AND RETURN
* CONVERSION FAILED - RETURN TO CALLER WITH "C" BIT SET IN CCR
IEFFAIL  MOVEM.L   (SP)+,D3-D7         RESTORE CALLERS REGISTERS
         RTS                 AND RETURN WITH "C" BIT SET IN CCR
 
         END