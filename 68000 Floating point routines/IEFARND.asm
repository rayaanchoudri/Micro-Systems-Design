         TTL       IEEE FORMAT EQUIVALENT ASCII ROUND ROUTINE (IEFARND)
****************************************
* (C) COPYRIGHT 1981 BY MOTOROLA INC.  *
****************************************
 
***********************************************
* IEFARND - IEEE FORMAT EQUIVALENT ASCII ROUND*
*                                             *
*  THIS ROUTINE IS NORMALLY CALLED AFTER THE  *
*  'IEFFPA' FLOAT TO ASCII ROUTINE AND ACTS   *
*  UPON ITS RESULTS.                          *
*                                             *
*  INPUT:  D6 - ROUNDING MAGNITUDE IN BINARY  *
*               AS EXPLAINED BELOW.           *
*          D7 - BINARY REPRESENTATION OF THE  *
*               BASE 10 EXPONENT.             *
*          SP ->  RETURN ADDRESS AND OUTPUT   *
*                 FROM IEFFPA ROUTINE         *
*                                             *
*  OUTPUT: THE ASCII VALUE ON THE STACK IS    *
*          CORRECTLY ROUNDED                  *
*                                             *
*          THE CONDITION CODES ARE UNDEFINED  *
*                                             *
*          ALL REGISTERS TRANSPARENT          *
*                                             *
*     THE ROUNDING PRECISION REPRESENTS THE   *
*     POWER OF TEN TO WHICH THE ROUNDING WILL *
*     OCCUR.  (I.E. A -2 MEANS ROUND THE DIGIT*
*     IN THE HUNDREDTH POSITION FOR RESULTANT *
*     ROUNDING TO TENTHS.)  A POSITIVE VALUE  *
*     INDICATES ROUNDING TO THE LEFT OF THE   *
*     DECIMAL POINT (0 IS UNITS, 1 IS TENS    *
*     E.T.C.)                                 *
*                                             *
*     THE BASE TEN EXPONENT IN BINARY IS D7   *
*     FROM THE 'IEFFPA' ROUTINE OR COMPUTED BY*
*     THE CALLER.                             *
*                                             *
*     THE STACK CONTAINS THE RETURN ADDRESS   *
*     FOLLOWED BY THE ASCII NUMBER AS FROM    *
*     THE 'IEFFPA' ROUTINE.  SEE THE          *
*     DESCRIPTION OF THAT ROUTINE FOR THE     *
*     REQUIRED FORMAT.                        *
*                                             *
*  EXAMPLE:                                   *
*                                             *
*  INPUT PATTERN '+.98765432+01' = 9.8765432  *
*                                             *
*     ROUND +1 IS +.00000000+00 =  0.         *
*     ROUND  0 IS +.10000000+02 = 10.         *
*     ROUND -1 IS +.10000000+02 = 10.         *
*     ROUND -2 IS +.99000000+01 =  9.9        *
*     ROUND -3 IS +.98800000+01 =  9.88       *
*     ROUND -6 IS +.98765400+01 =  9.87654    *
*                                             *
*  NOTES:                                     *
*     1) IF THE ROUNDING DIGIT IS TO THE LEFT *
*        OF THE MOST SIGNIFICANT DIGIT, A ZERO*
*        RESULTS.  IF THE ROUNDING DIGIT IS TO*
*        THE RIGHT OF THE LEAST SIGNIFICANT   *
*        DIGIT, THEN NO ROUNDING OCCURS.      *
*     2) ROUNDING IS IGNORED FOR NAN'S (NOT-  *
*        A-NUMBER) AND INFINITIES.            *
*     3) ROUNDING IS HANDY FOR ELIMINATING THE*
*        DANGLING '999...' PROBLEM COMMON WITH*
*        FLOAT TO DECIMAL CONVERSIONS.        *
*     4) POSITIONS FROM THE ROUNDED DIGIT AND *
*        TO THE RIGHT ARE SET TO ZEROES.      *
*     5) THE EXPONENT MAY BE AFFECTED.        *
*     6) ROUNDING IS FORCED BY ADDING FIVE.   *
*     7) THE BINARY EXPONENT IN D7 MAY BE     *
*        PRE-BIASED BY THE CALLER TO PROVIDE  *
*        ENHANCED EDITING CONTROL.            *
*     8) THE RETURN ADDRESS IS REMOVED FROM   *
*        THE STACK UPON EXIT.                 *
***********************************************
         PAGE
IEFARND  IDNT      1,1       IEEE FORMAT EQUIVALENT ASCII ROUND
 
         XDEF      IEFARND   ENTRY POINT
 
         XREF      9:FFPARND FAST FLOATING POINT ROUND ROUTINE
 
         SECTION   9
 
IEFARND  CMP.B     #'>',4(SP)          ? POSITIVE INFINITY CONVERTED
         BEQ.S     IEFRTN              IGNORE ROUNDING IF SO
         CMP.B     #'<',4(SP)          ? MINUS INFINITY CONVERTED
         BEQ.S     IEFRTN              IGNORE ROUNDING IF SO
         CMP.B     #'.',4(SP)          ? NAN (NOT-A-NUMBER) CONVERTED
         BNE       FFPARND             NO, IS NORMAL NUMERIC CONVERSION
*                                                CONTINUE WITH FFP ROUTINE
IEFRTN   RTS                           RETURN TO CALLER AND IGNORE ROUNDING
 
         END