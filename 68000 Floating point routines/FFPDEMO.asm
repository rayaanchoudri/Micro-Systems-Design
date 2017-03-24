         TTL       FAST FLOATING POINT DEMO PROGRAM
***************************************
* (C) COPYRIGHT 1981 BY MOTOROLA INC. *
***************************************
 
***************************************************
* THIS IS A DEMO OF THE 68343 FAST FLOATING POINT *
***************************************************
 
         OPT       FRS
 
         XREF      FFPSQRT  EXTERNAL ROUTINES
         XREF      FFPADD,FFPDIV,FFPMUL
         XREF      FFPSINCS
         XREF      FFPAFP,FFPFPA
 
         XDEF      FFPDEMO
 
         SECTION   2
 
 
FFPDEMO  LEA       STACK,SP  LOAD STACK
 
         BSR       MSG                 BLANK LINE AT FIRST
         DC.L      '        '          BLANK LINE
         LEA       HELLO,A0            SETUP START MESSAGE
         LEA       HELLOE,A1           END OF MSG
         BSR       PUT                 PUT THIS OUT
         LEA       HELLO2,A0           SECOND MESSAGE
         LEA       HELLO2E,A1          END OF MSG
         BSR       PUT                 PUT COPYRIGHT OUT
         BSR       MSG                 ANOTHER BLANK NOW
         DC.L      '        '          BLANK LINE
 
         LEA       ASCIIPI,A0          CONVERT PI TO FLOAT
         BSR       FFPAFP
         MOVE.L    D7,D0               SAVE PI IN D0
 
         LEA       ASCIIE,A0           CONVERT 'E' TO FLOAT
         BSR       FFPAFP
         MOVE.L    D7,D1               SAVE E IN D1
 
*****************
* ADDITION DEMO *
*****************
 
         LEA       MSGADD,A0 POINT TO MESSAGE
         LEA       MSGADDE,A1 POINT TO END
         BSR       PUT       SEND TO CONSOLE
 
         MOVE.W    #50000,D2           SAVE LOOP COUNT
         MOVE.L    D0,D6               MOVE PI
 
ADDLOOP  MOVE.L    D1,D7               RELOAD E
         BSR       FFPADD              PERFORM ADD
         DBRA      D2,ADDLOOP
 
         BSR       RESULT              DISPLAY RESULT
 
 
*****************
* MULTIPLY DEMO *
*****************
 
         LEA       MSGMUL,A0 POINT TO MESSAGE
         LEA       MSGMULE,A1 AND END
         BSR       PUT SEND TO CONSOLE
 
         MOVE.W    #50000,D2 SETUP LOOP COUNT
         MOVE.L    D0,D6     SETUP PI
 
MULLOOP  MOVE.L    D1,D7     SETUP E
         BSR       FFPMUL    PERFORM MULTIPLY
         DBRA      D2,MULLOOP LOOP UNTIL DONE
 
         BSR.S     RESULT    DISPLAY RESULT
 
***************
* DIVIDE DEMO *
***************
 
         LEA       MSGDIV,A0 POINT TO MESSAGE
         LEA       MSGDIVE,A1 AND END
         BSR       PUT SEND TO CONSOLE
 
         MOVE.W    #50000,D2 SETUP LOOP COUNT
         MOVE.L    D0,D6     SETUP PI
 
DIVLOOP  MOVE.L    D1,D7     SETUP E
         BSR       FFPDIV    PERFORM DIVIDE
         DBRA      D2,DIVLOOP LOOP UNTIL DONE
 
         BSR.S     RESULT    DISPLAY RESULT
 
********************
* SQUARE ROOT DEMO *
********************
 
         LEA       MSGSQR,A0 POINT TO MESSAGE
         LEA       MSGSQRE,A1 AND END
         BSR       PUT SEND TO CONSOLE
 
         MOVE.W    #20000,D2 SETUP LOOP COUNT
 
SQRLOOP  MOVE.L    D0,D7     SETUP PI
         BSR       FFPSQRT   PERFORM SQUARE ROOT
         DBRA      D2,SQRLOOP LOOP UNTIL DONE
 
         BSR.S     RESULT    DISPLAY RESULT
 
************************
* SINE AND COSINE DEMO *
************************
 
         LEA       MSGSIN,A0 POINT TO MESSAGE
         LEA       MSGSINE,A1 AND END
         BSR.S     PUT SEND TO CONSOLE
 
         MOVE.W    #10000,D2 SETUP LOOP COUNT
 
SINLOOP  MOVE.L    D1,D7     SETUP E
         BSR       FFPSINCS  PERFORM SINE AND COSINE
         DBRA      D2,SINLOOP LOOP UNTIL DONE
 
         BSR.S     RESULT    DISPLAY COSINE
         MOVE.L    D6,D7     ALSO DISPLAY SINE
         BSR.S     RESULT    AS WELL
 
************
* END TEST *
************
QUIT     BSR.S     MSG       ISSUE DONE MESSAGE
         DC.L      '  DONE  '
         BSR.S     MSG       AND FINAL BLANK LINE
         DC.L      '        '
         MOVE.L    #15,D0    SETUP EXIT TASK CODE
         TRAP      #1        HERE
 
 
*   *
*   * RESULT DISPLAY SUBROUTINE
*   *   INPUT IS FLOAT IN D7
*   *
RESULT   BSR       FFPFPA
         MOVE.L    #'LT: ',-(SP)   MOVE RESULT HEADER
         MOVE.L    #'RESU',-(SP)   ONTO STACK
         LEA       (SP),A0   POINT TO MESSAGE
         LEA       14+8-1(SP),A1 POINT TO END OF MESSAGE
         BSR.S     PUT       ISSUE TO CONSOLE
         LEA       14+8(SP),SP         GET RID OF CONVERSION AND HEADING
         BSR.S     MSG       PUT BLANK LINE OUT
         DC.L      '        '
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
 
 
* IOS BLOCK FOR TERMINAL FORMATED SEND
IOSBLK   DC.B     0,2,0,0    WRITE FORMATTED WAIT
         DC.B     0
DEVICE   DC.B     0,0,0
         DC.L     0
BUFPTR   DC.L      0,0
BUFLEN   DC.L      0,0
 
* PI AND E ASCII CONSTANTS
ASCIIPI  DC.B      '+3.1415926535897 '
ASCIIE   DC.B      '+2.718281828459045 '
 
* MESSAGES FOR THE DEMO PARTS
HELLO    DC.W      'MOTOROLA MC68000 FAST FLOATING POINT DEMO'
HELLOE   DC.B      0
 
HELLO2   DC.W      '     (C) COPYRIGHT 1981 BY MOTOROLA'
HELLO2E  DC.B      0
 
MSGADD   DC.W      'FIFTY THOUSAND ADDITIONS OF 3.14159265 TO 2.718281828'
MSGADDE  DC.B      0
 
MSGMUL   DC.W      'FIFTY THOUSAND MULTIPLIES OF 3.14159265 WITH 2.718281828'
MSGMULE  DC.B      0
 
MSGDIV   DC.W      'FIFTY THOUSAND DIVIDES OF 3.14159265 INTO 2.718281828'
MSGDIVE  DC.B      0
 
MSGSQR   DC.W      'TWENTY THOUSAND SQUARE ROOTS OF 3.14159265'
MSGSQRE  DC.B      0
 
MSGSIN   DC.W      'TEN THOUSAND COSINES AND SINES OF 2.718281828'
MSGSINE  DC.B      0
 
* PROGRAM STACK
         DCB.W     100,0      STACK AREA
STACK    EQU       *
 
         END       FFPDEMO