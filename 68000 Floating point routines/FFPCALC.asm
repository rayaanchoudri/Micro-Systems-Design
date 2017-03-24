         TTL       FAST FLOATING POINT - DESK CALCULATOR DRIVER
***************************************
* (C) COPYRIGHT 1980 BY MOTOROLA INC. *
***************************************
*  MODIFIED TO BE USABLE ON M68010  6/25/85 MBODINE
 
******************************************
* THIS IS A DESK-CALCULATOR DIAGNOSTIC   *
* PROGRAM FOR THE MC68344 ROM FAST FLOAT-*
* ING POINT SUBROUTINES. THE INPUT       *
* FORMAT IS NORMAL FORTRAN EXPRESSION    *
* SYNTAX WITH AN OPTIONAL ASSIGNMENT     *
* STATEMENT FOR THE ONLY VARIABLES "X"   *
* AND "Y".  THE VARIABLES CAN BE USED IN *
* EXPRESSIONS.  NO BLANKS ALLOWED.       *
*                                        *
* A FLOATING POINT VALUE MAY BE ENTIRELY *
* SPECIFIED IN HEXADECIMAL.  THIS IS DONE*
* BY FOLLOWING A $ WITH EIGHT HEX DIGITS.*
*                                        *
* A SPECIAL DIADIC OPERATOR "?" PERFORMS *
* A COMPARISON BETWEEN TWO VALUES REPORT-*
* ING ALL VALID BRANCH CONDITIONS.       *
*                                        *
* FUNCTION 'TST( )' RETURNS A CCR RESULT *
* FOR PLUS, MINUS, NAN AND ZERO.         *
*                                        *
* FUNCTION 'NEG( )' OPERATES EXACTLY LIKE*
* THE PREFIX MINUS SIGN.                 *
*                                        *
* ROUNDING (POWER OF TEN) IS SET WITH    *
* AN "R=VALUE" STATEMENT (DEFAULT -100). *
* FOR EXAMPLE, R=-1 ROUNDS TENTHS TO     *
* UNITS.                                 *
*                                        *
*   EXAMPLES:      X=32.5                *
*                                        *
*                  SQRT(5)*2             *
*                                        *
*                  X                     *
*                                        *
*                  Y=ABS(X)**.2+3.4      *
*                                        *
*                  10E-4*COS(Y-SIN(X))   *
*                                        *
*                  X=10E10+Y             *
*                                        *
*                  $7F80012F+ATAN(2)     *
*                                        *
*                  3.1?X                 *
*                                        *
*   FUNCTIONS AVAILABLE:  SQRT LOG EXP   *
*      SIN COS TAN ATAN SINH COSH TANH   *
*      POWER (VIA ** OPERATOR) ABS NEG   *
*      INT (CONVERT TO INTEGER)          *
*                                        *
******************************************
         PAGE
         OPT       FRS,P=68010
 
         XREF      FFPAFP,FFPFPA,FFPSQRT,FFPARND,FFPFPI,FFPIFP SUBROUTINES
         XREF      FFPADD,FFPSUB,FFPDIV,FFPMUL,FFPCMP,FFPTST,FFPABS,FFPNEG
         XREF      FFPSIN,FFPCOS,FFPTAN,FFPEXP,FFPLOG,FFPPWR,FFPATAN
         XREF      FFPSINH,FFPCOSH,FFPTANH
 
         XDEF      FFPCALC
 
         SECTION   2
 
******************************************
* FAST FLOATING POINT     CALCULATOR     *
*      VERSION 1.1    4/10/81            *
******************************************
 
*
* AT LABEL 'INPUT' THE STACK POINTS TO THE INPUT BUFFER
*
* DURING CALCULATIONS A6 HOLDS THE ABOVE VALUE FOR ERROR ABORTS
*
 
FFPCALC  LEA       STACK,SP  LOAD STACK
 
         BSR       MSG                 PUT BLANK LINE BEFORE HEADING
         DC.L      '        '          BLANK LINE
         LEA       STARTM,A0         SEND STARTUP MESSAGE
         LEA       STARTME,A1        MESSAGE END
         BSR       PUT                 CALL PUT SUBROUTINE
         LEA       STARTM2,A0         SEND STARTUP MESSAGE
         LEA       STARTM2E,A1        MESSAGE END
         BSR       PUT                 CALL PUT SUBROUTINE
         BSR       MSG       BLANK LINE AFTER HEADING
         DC.L      '        '          BLANK LINE
 
         LEA       -80(SP),SP ALLOCATE BUFFER
         MOVE.L    SP,A6     SETUP ERROR RECOVERY FRAME POINTER
 
         MOVE.L    #26,D0    SETUP EXCEPTION VECTORS
         LEA       EXCTBL,A0 TABLE ADDRESS
         TRAP      #1        TAKE EXCEPTIONS FOR ZERO DIVIDE AND OVERFLOW
         BEQ.S     INPUT
         TRAP      #15       ERROR IF SOMETHING WRONG
 
INPUT    BSR       MSG       ISSUE PROMPT
         DC.L      'READY'
         MOVE.L    SP,A0     SETUP START ADDR
         LEA       79(SP),A1 AND ENDING
         BSR       GET       READ A LINE OF INPUT
         CLR.B     OVFSET    CLEAR OVERFLOW STATUS
         CLR.B     ZDVSET    CLEAR ZERO DIVIDE STATUS
         MOVE.W    (SP),D0   GET FIRST TWO BYTES
* TEST FOR 'QUIT' COMMAND
         CMP.B     #'Q',(SP) ? "Q" COMMAND FOR QUIT
         BEQ       QUIT
* TEST FOR 'X=' ASSIGNMENT
         LEA       2(SP),A0  DEFAULT ASSIGNMENT SCAN POSITION
         CMP.W     #'X=',D0  ? ASSIGNMENT
         BNE.S     NOTXASG   BRANCH IF NOT
         BSR       INTRP     INTERPRET THE EXPRESSION
         MOVE.L    D7,X      SAVE IN X
         BRA.S     CALPRNT   PRINT OUT ITS VALUE
* TEST FOR 'Y=' ASSIGNMENT
NOTXASG  CMP.W     #'Y=',D0  ? Y ASSIGNMENT
         BNE.S     NOTASG    BR NOT ASSIGNMENT
         BSR       INTRP     INTERPRET THE EXPRESSION
         MOVE.L    D7,Y      SAVE IN Y
         BRA.S     CALPRNT    PRINT OUT ITS VALUE
* TEST FOR 'R=' ROUNDING ASSIGNMENT
NOTASG   CMP.W     #'R=',D0  ? ROUND SET
         BNE.S     NOTRND    BRANCH NOT
         BSR       INTRP     INTERPRET EXPRESSION
         MOVE.L    D7,D1     SAVE FLOAT VALUE
         BSR       FFPFPI    TO INTEGER
         MOVE.L    D7,ROUND  SAVE ROUNDING FACTOR
         MOVE.L    D1,D7     RESTORE FLOAT VALUE
         BRA.S     CALPRNT   AND PRINT IT OUT
NOTRND   LEA       (SP),A0   START SCAN AT FRONT
         BSR       INTRP     INTERPRET EXPRESSION
         BRA.S     CALPRNT   AND PRINT IT OUT
 
* DISPLAY RESULT BACK IN ASCII
HEXTBL   DC.L      '0123456789ABCDEF'
 
CALPRNT  TST.B     OVFSET    ? OVERFLOW DETECTED
         BEQ.S     CALNOV    BRANCH IF NOT
         BSR       MSG       GIVE OVERFLOW INDICATOR
         DC.L      'OVERFLOW'  EYE-CATCHER
CALNOV   TST.B     ZDVSET    ? ZERO DIVIDE DETECTED
         BEQ.S     CALNOZ    BRANCH IF NOT
         BSR       MSG       SHOW ZERO DIVIDE FOUND
         DC.L      'ZERO DIV'
CALNOZ   LEA       -8(SP),SP SETUP HEX TRANSLATE AREA
         MOVE.L    #7,D0     LOOP 8 TIMES
         MOVE.L    D7,D6     COPY FLOATING VALUE
TOHEX    MOVE.B    D6,D1     TO NEXT FOUR BITS
         AND.W     #%1111,D1 STRIP REST
         MOVE.B    HEXTBL(D1),0(SP,D0) CONVERT TO HEX
         LSR.L     #4,D6     TO NEXT HEX DIGIT
         DBRA      D0,TOHEX  LOOP UNTIL DONE
         MOVE.W    #'  ',-(SP) BLANK SEPERATOR
         BSR       FFPFPA    BACK TO ASCII
         MOVE.L    ROUND,D6  SETUP ROUNDING FACTOR
         BSR       FFPARND   ROUND APPROPRIATLEY
         LEA       (SP),A0   SETUP PUT
         LEA       23(A0),A1 ARGUMENTS
         MOVE.B    #$08,IOSBLK+3 FORCE UNFORMATTED MODE TO INHIBIT CR
         BSR       PUT       SEND OUT RESULT OF CONVERSION
         CLR.B     IOSBLK+3  TURN UNFORMATTED MODE BACK OFF
         LEA       24(SP),SP DELETE WORK AREA
         MOVE.W    CCRSAVE,CCR RESTORE CCR FOR BRANCH DISPLAY
         BSR       DISPCCR   DISPLAY ALL BRANCH CONDITIONS VALID
         BRA       INPUT     BACK FOR MORE
 
* INVALID RESPONSE - TARGET THE CHARACTER IN ERROR (A0->)
ERRORSYN MOVE.L    A6,SP     RESTORE STACK BACK TO NORMAL
         SUB.L     SP,A0     FIND OFFSET TO BAD CHARACTER
         MOVE.L    A0,D0     PAD WITH BLANKS
LOOP2PD  MOVE.B    #' ',0(SP,D0) BLANK OUT FRONT END
         DBRA      D0,LOOP2PD LOOP UNTIL DONE
         MOVE.B    #'^',0(SP,A0) SET POINTER
         MOVE.B    #$0D,1(SP,A0) SET END OF LINE
         LEA       1(SP,A0),A1 END OF TEXT
         MOVE.L    SP,A0     START OF TEXT
         BSR       PUT       PLACE OUT FLAG
         BSR       MSG       SEND MESSAGE
         DC.L      'SYNTAX'
         BRA       INPUT
 
* NEGATIVE SQUARE ROOT ERROR
ERRORSQT MOVE.L    A6,SP     RESTORE STACK
         BSR       MSG       SEND MSG
         DC.L      'NEG SQRT'          EYE-CATCHER
         BRA       CALPRNT   AND PRINT RESULT
 
* DIVIDE BY ZERO ERROR
ERRORZDV MOVE.B    #1,ZDVSET SIGNAL DIVIDE BY ZERO DETECTED
         RTR       AND CONTINUE WITH DIVIDE (OVERFLOW MODE)
 
* OVERFLOW ERROR
ERRORV   MOVE.B    #1,OVFSET SIGNAL OVERFLOW DETECTED
         RTR       AND CONTINUE WITH NEXT OPERATION
 
 
****************************
* INTERPRET THE EXPRESSION *
* OUTPUT - D7              *
* IF ERRORS OCCUR WILL NOT *
* RETURN TO CALLER         *
****************************
 
INTRP    CMP.B     #$0D,(A0)           ? NULL EXPRESSION
         BEQ       ERRORSYN            ***SYNTAX ERROR***
         BSR.S     EVAL                EVAULATE AS AN EXPRESSION
         CMP.B     #$0D,(A0)           ? EXPRESSION END AT THE CR
         BNE       ERRORSYN            ***SYNTAX ERROR***
         RTS                           RETURN TO CALLER
 
****************************
* SUB EXPRESSION EVALUATOR *
*       SUBROUTINE         *
* OUTPUT: D7 - RESULT      *
*  IF ERRORS WILL NOT      *
*  RETURN TO CALLER.       *
****************************
EVAL     BSR       TERM      OBTAIN FIRST TERM
EVALNXT  MOVE.W    CCR,CCRSAVE SAVE LAST FUNCTION CCR STATUS
         TRAPV               SET OVERFLOW HAD BIT
         MOVE.L    D7,-(SP)  SAVE FIRST ARGUMENT ON STACK
* TEST FOR DIADIC OPERATOR AND ONE MORE TERM
         MOVE.B    (A0)+,D0  LOAD NEXT CHARACTER
         CMP.B     #'+',D0    ? ADD
         BNE.S     NOTADD    BRANCH IF NOT
*  "+" ADD OPERATOR
         BSR.S     TERM      GET NEXT TERM
         TRAPV               CHECK OVERFLOW
         MOVE.L    (SP)+,D6  RELOAD ARG1 FOR ARG2
         JSR       FFPADD    ADD THEM
         BRA.S     EVALNXT   TRY FOR ANOTHER TERM
NOTADD   CMP.B     #'-',D0    ? SUBTRACT
         BNE.S     NOTSUB    BRANCH IF NOT
*  "-" SUBTRACT OPERATOR
         BSR.S     TERM      GET NEXT TERM
         TRAPV               CHECK OVERFLOW
         MOVE.L    (SP)+,D6  RELOAD ARG1
         EXG.L     D6,D7     MUST SWAP FOR CORRECT ORDER
         JSR       FFPSUB    SUBTRACT THEM
         BRA.S     EVALNXT   TRY FOR ANOTHER TERM
NOTSUB   CMP.B     #'*',D0    ? MULTIPLY
         BNE.S     NOTMULT   BRANCH IF NOT
         CMP.B     #'*',(A0) ? POWER FUNCTION
         BNE.S     ISMULT    BRANCH NO, IS MULTIPLY
*  "**" POWER OPERATOR
         ADD.L     #1,A0     STRIP OFF SECOND ASTERISK
         BSR.S     TERM      GET NEXT TERM
         TRAPV               CHECK OVERFLOW
         MOVE.L    (SP)+,D6  RELOAD BASE VALUE
         EXG.L     D6,D7     SWAP FOR FUNCTION CALL
         JSR       FFPPWR    PERFORM POWER FUNCTION
         BRA.S     EVALNXT   TRY ANOTHER ITEM
*  "*" MULTIPLY OPERATOR
ISMULT   BSR.S     TERM      GET NEXT TERM
         TRAPV               CHECK OVERFLOW
         MOVE.L    (SP)+,D6  RELOAD ARG1
         JSR       FFPMUL    MULTIPLY THEM
         BRA.S     EVALNXT   TRY ANOTHER TERM
NOTMULT  CMP.B     #'/',D0    ? DIVIDE
         BNE.S     NOTDIV    BRANCH IF NOT DIVIDE
*  "/" DIVIDE OPERATOR
         BSR.S     TERM      GET NEXT TERM
         TRAPV               CHECK OVERFLOW
         MOVE.L    (SP)+,D6  RELOAD ARG1
         EXG.L     D6,D7     SWAP ARGS (ARG2 INTO ARG1)
         JSR       FFPDIV    DIVIDE THEM
         BRA       EVALNXT   TRY FOR ANOTHER TERM
NOTDIV   CMP.B     #'?',D0   ? TEST FOR COMPARE OPERATOR
         BNE.S     EXPRTN    RETURN IF NOT
*  "?" COMPARISON OPERATOR
         BSR.S     TERM      GET NEXT TERM
         TRAPV               CHECK OVERFLOW
         MOVE.L    (SP)+,D6  RESTORE FIRST ARGUMENT
         JSR       FFPCMP    DO IEEE FORMAT COMPARISON
         BSR       DISPCMP   DISPLAY CCR FOR COMPARISON
         MOVE.L    A6,SP     RESTORE STACK TO TOP LEVEL
         BRA       INPUT     AND PERFORM NEXT REQUEST
 
EXPRTN   SUB.L     #1,A0     BACK TO CURRENT POSITION
         MOVE.L    (SP)+,D7  RESTORE UNUSED ARGUMENT
         RTS                 RETURN TO CALLER
 
 
*************************
* OBTAIN A TERM (VALUE) *
*  OUTPUT: D7 - VALUE   *
*          V - OVERFLOW *
* WILL NOT RETURN TO    *
* CALLER IF ERROR       *
*************************
* SCAN FUNCTION TABLE FOR MATCH
TERM     LEA       FNCTNTBL,A1 SETUP TABLE ADDRESS
         MOVE.L    #NUMFUN,D1 COUNT TABLE ENTRIES
FNCNXT   MOVE.W    (A1)+,D2  PREPARE COMPARE LENGTH
         MOVE.L    A1,A2     PREPARE ENTRY STRING POINTER
         MOVE.L    A0,A3     WITH INPUT SCAN STRING
FNCMPR   CMP.B     (A2)+,(A3)+ ? STILL VALID MATCH
         DBNE      D2,FNCMPR LOOP IF SO
         BEQ.S     GOTFUNC   BRANCH FOR MATCH
         LEA       12(A1),A1 TO NEXT ENTRY POSITION
         DBRA      D1,FNCNXT LOOP IF MORE TO CHECK
         BRA       NOTFUNC   BRANCH NOT A FUNCTION
 
GOTFUNC  MOVE.L    8(A1),-(SP) SAVE ENTRY POINT ADDRESS
         MOVE.L    A3,A0     BUMP SCAN TO AFTER PAREN
         BSR       EVAL      OBTAIN INSIDE EXPRESSION
         MOVE.L    (SP)+,A1  LOAD FUNCTION ROUTINE ADDRESS
         JSR       (A1)      CALL APPROPRIATE ROUTINE
         MOVE.W    CCR,-(SP)  SAVE RETURN CODE
         CMP.B     #')',(A0)+  ARE THEY?
         BNE       ERRORSYN  BRANCH SYNTAX ERROR IF NOT
         RTR                 RETURN WITH CONDITION CODE
 
* FUNCTION TABLE
FNCTNTBL DC.W      0                   VANILLA PARENTHESIS
         DC.L      '(       ',FPAREN
         DC.W      4                   SQUARE ROOT
         DC.L      'SQRT(   ',FSQRT
         DC.W      3                   SINE
         DC.L      'SIN(    ',FFPSIN
         DC.W      3                   COSINE
         DC.L      'COS(    ',FFPCOS
         DC.W      3                   TANGENT
         DC.L      'TAN(    ',FFPTAN
         DC.W      3                   EXPONENT
         DC.L      'EXP(    ',FFPEXP
         DC.W      3                   LOGORITHM
         DC.L      'LOG(    ',FFPLOG
         DC.W      4                   ARCTANGENT
         DC.L      'ATAN(   ',FFPATAN
         DC.W      4                   HYPERBOLIC SINE
         DC.L      'SINH(   ',FFPSINH
         DC.W      4                   HYPERBOLIC COSINE
         DC.L      'COSH(   ',FFPCOSH
         DC.W      4                   HYPERBOLIC TANGENT
         DC.L      'TANH(   ',FFPTANH
         DC.W      3                   TST
         DC.L      'TST(    ',FFPTST
         DC.W      3                   NEGATE
         DC.L      'NEG(    ',FFPNEG
         DC.W      3                   ABSOLUTE VALUE
         DC.L      'ABS(    ',FFPABS
         DC.W      3                   INTEGER
         DC.L      'INT(    ',FINT
 
NUMFUN   EQU       (*-FNCTNTBL)/12
 
* PARENTHESIS EXPRESSION
FPAREN   RTS       NO FUNCTION REQUIRED
 
* SQUARE ROOT CALL
FSQRT    JSR       FFPSQRT   CALL SQUARE ROOT
         BVS       ERRORSQT  BRANCH IF NEGATIVE ARGUMENT ATTEMPTED
         RTS                 RETURN TO CALLER
 
* INTEGER FUNCTION
FINT     MOVE.L    D7,-(SP)  SAVE ORIGINAL ARGUMENT IN CASE OF OVERFLOW
         JSR       FFPFPI    CONVERT TO INTEGER
         BVC.S     FINTOK    BRANCH IF NO OVERFLOW DETECTED
* OVERFLOW - RETURN ORIGINAL ARGUMENT SINCE HAS NO FRACTION ANYWAY
         MOVE.L    (SP)+,D7  RETURN ORIGINAL ARGUMENT
         TST.B     D7        SET CCR PROPERLY
         RTS                 RETURN TO CALLER
* NO OVERFLOW - CONVERT BACK
FINTOK   JSR       FFPIFP    BACK TO FLOAT
         ADD.L     #4,SP     DELETE SAVED ARGUMENT FROM STACK
         RTS                 AND RETURN
 
* TEST FOR VARIABLES OR INFIX + AND -
NOTFUNC  MOVE.B    (A0)+,D0  LOAD NEXT CHARACTER
         MOVE.L    X,D7      DEFAULT TO X
         CMP.B     #'X',D0   IS IT?
         BEQ.S     TERMRTN   RETURN IF SO
         MOVE.L    Y,D7      DEFAULT TO Y
         CMP.B     #'Y',D0   ? IS IT
         BEQ.S     TERMRTN   RETURN IF SO
         CMP.B     #'+',D0    TEST PLUS
         BEQ       NOTFUNC   BR YES TO SKIP IT
         CMP.B     #'-',D0    INFIX MINUS
         BNE.S     NOTMINUS  NO, TRY SOMTHING ELSE
* IF THIS IS A NEGATIVE ASCII VALUE, WE MUST LET IT BE CONVERTED SINCE
* A POSITIVE VALUE HAS LESS RANGE THAN A NEGATIVE ONE
         CMP.B     #'.',(A0)  ? NUMERIC ASCII FOLLOWS
         BEQ.S     NOTMINUS  YES, LET CONVERSION HANDLE IT PROPERLY
         CMP.B     #'0',(A0)  ? ASCII NUMBER
         BLS.S     DONEG     NOPE, COMPLEMENT THE FOLLOWING VALUE
         CMP.B     #'9',(A0)  ? ASCII NUMBER
         BLS.S     NOTMINUS   YEP, ALLOW PROPER CONVERSION
DONEG    BSR       TERM      OBTAIN TERM
         JSR       FFPNEG    NEGATE THE RESULT
TERMRTN  RTS                 RETURN TO CALLER
 
* CHECK FOR DIRECT HEXADECIMAL SPECIFICATION
NOTMINUS CMP.B     #'$',D0   ? HEXADECIMAL HERE
         BNE.S     NOTHEX    BRANCH IF NOT
         CLR.L     D7        START BUILDING THE VALUE
PRSHEX   MOVE.B    (A0),D0   LOAD NEXT CHARACTER
         CMP.B     #'0',D0   ? LESS THAN ASCII ZERO
         BCS.S     TERMRTN   RETURN WITH RESULT IN D7 IF SO
         CMP.B     #'9',D0   ? GREATER THAN NINE
         BLS.S     GOTHEX    BRANCH NOT, IS A VALID DECIMAL DIGIT
         CMP.B     #'A',D0   ? LESS THAN ASCII "A"
         BCS.S     TERMRTN   RETURN RESULT IF NOT HEX DIGIT
         CMP.B     #'F',D0   ? GREATER THAN "F"
         BHI.S     TERMRTN   RETURN RESULT IF NOT HEX DIGIT
         ADD.B     #9,D0     RE-MAP INTO BINARY RANGE
GOTHEX   ADD.L     #1,A0     BUMP PAST THIS CHARACTER
         AND.B     #$F,D0    ISOLATE HEX DIGIT
         CMP.L     #$0FFFFFFF,D7 ? WILL ANOTHER DIGIT OVERFLOW
         BHI       ERRORSYN  YES, BRANCH FOR SYNTAX ERROR
         LSL.L     #4,D7     SHIFT OVER SAFELY FOR NEXT DIGIT
         OR.B      D0,D7     OR NEW DIGIT IN LOW BYTE
         BRA.S     PRSHEX    GO PARSE ANOTHER HEX DIGIT
 
 
* ATTEMPT TO TREAT IT AS AN ASCII NUMBER
NOTHEX   SUB.L     #1,A0     ATTEMPT ASCII INPUT VALUE
         JSR       FFPAFP    ATTEMPT ASCII TO FLOAT
         BCS       ERRORSYN  SYNTAX ERROR IF NO GOOD
         RTS                 RETURN IF GOT VALUE
 
************
* END TEST *
************
QUIT     BSR.S     MSG       ISSUE DONE MESSAGE
         DC.L      '  DONE'
         MOVE.L    #15,D0    TERMINATE TASK
         TRAP      #1        HERE
 
 
*   *
*   * DISPLAY THE CCR BRANCH CONDITIONS SUBROUTINE
*   *   EVERYTHING TRANSPARENT (INCLUDING CCR)
*   *
 
DISPCMP  MOVEM.L   D0-D1/A0-A1,-(SP) SAVE WORK REGISTERS ON THE STACK
         MOVE.W    CCR,D0     SAVE CONDITION CODE REGISTER FOR TESTS
         MOVE.L    SP,A1     STACK FRAME POINTER
         MOVE.W    #'GT',-(SP)  DEFAULT CONDITION
         MOVE.W    D0,CCR    RESET CCR
         BGT.S     DISPGT    BRANCH CORRECT
         MOVE.W    #'LE',(SP) CHANGE
DISPGT   MOVE.L    #'GE  ',-(SP)  DEFAULT CONDITION
         MOVE.W    D0,CCR    RESET CCR
         BGE.S     DISPPL    BRANCH CORRECT
         MOVE.W    #'LT',(SP) CHANGE
         BRA.S     DISPPL    ENTER COMMON CODE
 
* REGULAR DISPLAY
DISPCCR  MOVEM.L   D0-D1/A0-A1,-(SP) SAVE WORK REGISTERS ON THE STACK
         MOVE.W    CCR,D0     SAVE CONDITION CODE REGISTER FOR TESTS
         MOVE.L    SP,A1     STACK FRAME POINTER
* TEST FOR OVERFLOW (V SET)
         BVC.S     NOTVS     BRANCH NOT OVERFLOW
         MOVE.L    #'FLOW',-(SP) SETUP OVERFLOW EYE-CATCHER
         MOVE.L    #'OVER',-(SP) DITTO
* SETUP ARITHMETIC COMPARISONS
NOTVS    MOVE.L    #'PL  ',-(SP)  DEFAULT CONDITION
         MOVE.W    D0,CCR    RESET CCR
         BPL.S     DISPPL    BRANCH CORRECT
         MOVE.W    #'MI',(SP) CHANGE
DISPPL   MOVE.L    #'EQ  ',-(SP)  DEFAULT CONDITION
         MOVE.W    D0,CCR    RESET CCR
         BEQ.S     DISPEQ    BRANCH CORRECT
         MOVE.W    #'NE',(SP) CHANGE
DISPEQ   MOVE.L    #'    ',-(SP) ADD BLANKS TO BEGINNING
         MOVE.L    SP,A0     START OF STRING PRINT
         SUB.L     #1,A1     POINT TO LAST CHARACTER
         BSR.S     PUT       SEND STRING TO CONSOLE
         LEA       1(A1),SP  RESTORE STACK BACK
         MOVE.W    D0,CCR  RESTORE CCR
         MOVEM.L   (SP)+,D0-D1/A0-A1 RESTORE REGISTERS
         RTS                 RETURN TO CALLER
 
*   *
*   * MSG SUBROUTINE
*   *  INPUT: (SP) POINT TO EIGHT BYTE TEXT FOLLOWING BSR/JSR
*   *
MSG      MOVEM.L   D0/A0/A1,-(SP) SAVE REGS
         MOVE.L    3*4(SP),A0 LOAD RETURN POINTER
         LEA       7(A0),A1   POINT TO BUFFER END
         BSR.S     PUT       ISSUE IOS CALL
         MOVEM.L   (SP)+,D0/A0/A1 RELOAD REGISTERS
         ADD.L     #8,(SP)   ADJUST RETURN ADDRESS
         RTS                 RETURN TO CALLER
 
*   *
*   * PUT SUBROUTINE
*   *  INPUT: A0->TEXT START, A1->TEXT END
*   *
PUT      MOVEM.L   D0/A0/A1,-(SP) SAVE REGS
         MOVEM.L   A0-A1,BUFPTR SETUP BUFFER POINTERS
         SUB.L     A0,A1     COMPUTE LENGTH-1
         LEA       1(A1),A1  ADD ONE
         MOVE.L    A1,BUFLEN INSERT LENGTH
         MOVE.B    #6,DEVICE TO OUTPUT STREAM
         MOVE.B    #2,IOSBLK+1 AND WRITE FUNCTION
         LEA       IOSBLK,A0  LOAD BLOCK ADDRESS
         TRAP      #2        ISSUE IOS CALL
         MOVEM.L   (SP)+,D0/A0/A1 RELOAD REGISTERS
         RTS                 RETURN TO CALLER
 
*   *
*   * GET SUBROUTINE
*   *   INPUT: A0->BUFFER START, A1->LAST OF BUFFER
*   *
GET      MOVEM.L   D0/A0/A1,-(SP) SAVE REGS
         MOVEM.L   A0-A1,BUFPTR PLACE BUFFER POINTERS
         MOVE.B    #1,IOSBLK+1 PERFORM READ
         MOVE.B    #5,DEVICE READ FROM INPUT DEVICE
         LEA       IOSBLK,A0 LOAD PARAMETER
         TRAP      #2        IOS CALL
         MOVEM.L   (SP)+,D0/A0/A1 RESTORE REGISTERS
         RTS                 RETURN TO CALLER
 
* IOS BLOCK FOR TERMINAL FORMATED SEND
IOSBLK   DC.B     0,2,0,0    WRITE FORMATTED WAIT
         DC.B     0
DEVICE   DC.B     0,0,0
         DC.L     0
BUFPTR   DC.L      0,0
BUFLEN   DC.L      0,0
 
* VARIABLES
X        DC.L      0
Y        DC.L      0
CCRSAVE  DC.W      0
ROUND    DC.L      -100      ROUNDING FACTOR
 
* OVERFLOW FLAGS
OVFSET   DC.B      0         OVERFLOW RETURNED FLAG
ZDVSET   DC.B      0         ZERO DIVIDE SET
 
* EXCEPTION VECTOR SUBSTITUTION
EXCTBL   DC.L      0,0,0,ERRORZDV,0,ERRORV,0,0,0
 
* STARTUP MESSAGE
STARTM   DC.W      '  FAST FLOATING POINT CALCULATOR'
STARTME  DC.W     0
STARTM2  DC.W      '(C) COPYRIGHT 1980 BY MOTOROLA INC.'
STARTM2E DC.W      0
 
* PROGRAM STACK
         DCB.W     100,0      STACK AREA
STACK    EQU       *
 
         END       FFPCALC