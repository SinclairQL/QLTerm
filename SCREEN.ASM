* QLTerm Terminal Emulator
* Licenced under GPL v3 Licence (2019)
* See https://github.com/janbredenbeek/QLTerm for latest version from the author
* This should be assembled and linked using the GST/Quanta Macro Assembler and Linker
* (see http://www.dilwyn.me.uk/asm/index.html)

* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.


* QLTERM SCREEN DRIVER JOB

         INCLUDE  MACRO_LIB
         INCLUDE  QDOS_IN_MAC
         INCLUDE  QLTERM_IN

         XDEF     SCRJOB

         XREF     TXCHR,TXCHR_A,TXSTR,MAINWINP,T_WAIT,DEFRXBUF

         DATA     0

         SECTION  CODE

SCRJOB   MOVE.L   RXQ_BASE(A6),A2	; A2 always points to RX queue
	BRA.S    SCRJBLP1
         DC.W     $4AFB
         STRING$  {'QLTERM screen'}

UPD_TAIL ADDQ.L   #1,A1
         CMPA.L   Q_END(A2),A1
         BLO.S    UPDT_LO
         LEA      Q_QUEUE(A2),A1
UPDT_LO  MOVE.L   A1,Q_NXTOUT(A2)
         RTS

* Main loop entered here when queue is empty

SCRJBLP1 TST.B    USE_PIPE(A6)      When not using pipes, skip
         BEQ.S    SET_CUR
         MOVE.L   Q_NEXTIN(A2),A1
         MOVEQ    #-Q_QUEUE,D2
         ADD.L    Q_END(A2),D2
         SUB.L    A1,D2
         IF LE THEN
            ADD.L    A1,D2
            LEA      Q_QUEUE(A2),A1
         ENDIF
         CMPI.L   #$7FFF,D2
         IF GT THEN
            MOVE.L   #$7FFF,D2
         ENDIF
         MOVEQ    #0,D3
         MOVE.L   TSERIN(A6),A0
         QDOS     IO.FSTRG          and try to fetch input from pipe
         MOVE.L   A1,Q_NEXTIN(A2)
         TST.W    D1                Got any chars?
         BNE.S    SCRJBLP           no
         CMPI.L   #ERR.EF,D0
         SEQ      IN_EOF(A6)        Set EOF signal if needed

* There is no pending input, so enable the screen cursor

SET_CUR  MOVE.L   MAINWIN(A6),A0
         MOVEQ    #-1,D3
         TST.B    DLMOD(A6)         ...unless we are in file-transfer mode
         IF EQ THEN
            QDOS     SD.CURE
         ENDIF
         TST.B    USE_PIPE(A6)      Using pipes?
         BNE.S    SCRJ_WT2          yes
SCRJB_WT MOVEQ    #1,D3             Give up timeslice
         JSR      T_WAIT
         MOVE.L   Q_NXTOUT(A2),A1
         CMPA.L   Q_NEXTIN(A2),A1    Still no pending data?
         BEQ      SCRJB_WT          no, loop back
         BRA.S    SCRJB_GT          else, process it
SCRJ_WT2 MOVE.L   TSERIN(A6),A0     When using pipes, simply wait until
         MOVEQ    #-1,D3            there is data available in input pipe
         QDOS     IO.PEND
         BRA      SCRJBLP1

* Main loop; check if more data available in input buffer

SCRJBLP  MOVE.L   Q_NXTOUT(A2),A1
         CMPA.L   Q_NEXTIN(A2),A1
         BEQ      SCRJBLP1          If not, loop back
SCRJB_GT MOVE.B   (A1),D1           Get first byte
;         TST.B    PARITY(A6)
;         IF GE THEN
;            ANDI.B   #$7F,D1        Strip off any parity
;         ENDIF
         TST.B    XOFFMOD(A6)       Remote has been XOFF'ed?
         BEQ.S    TST_ESC           no
         MOVE.L   Q_NEXTIN(A2),D2
         SUB.L    A1,D2
         BGE.S    SCRJB_GE
         ADD.L    Q_END(A2),D2
         SUB.L    A2,D2
         SUBI.L   #Q_QUEUE,D2
SCRJB_GE CMPI.L   #32,D2            D2 = free space in buffer
         BGT.S    TST_ESC           if more than 32, turn remote on again
         MOVE.B   D1,D2
         MOVEQ    #XON,D1
         MOVEQ    #0,D3
         JSR      TXCHR_A
         MOVE.B   D2,D1
         TST.L    D0
         BNE.S    TST_ESC           ...but check if XON could be sent
         SF       XOFFMOD(A6)       successfully
TST_ESC  MOVE.L   MAINWIN(A6),A0
         MOVEQ    #-1,D3
         TST.B    ESCMOD(A6)        Are we in an escape sequence?
         BNE      GO_ESC            yes
         MOVEM.L  D1/A1,-(A7)       Now it looks that we've got something to
         QDOS     SD.CURS           print, so disable the cursor
         MOVEM.L  (A7)+,D1/A1
         CMPI.B   #$7F,D1
         BEQ.S    TST_ESC2
         CMPI.B   #$20,D1
         BHS.S    OUTCHR2           Jump if it's surely no ctrl code
TST_ESC2 BSR      UPD_TAIL          Update the queue's ptr
         BSR.S    OUT_LOGB          Log it if necessary
         LEA      CTRLTBL,A4
         BSR      LOOKTBL           Now lookup the code
         BNE.S    OUTCHR            If not recognised, just print it
         QDOS     SD.DONL           Activate any pending NL's
         JSR      (A4)              ...and do it!
         BRA      SCRJBLP
OUTCHR   QDOS     IO.SBYTE          Print one character
         BRA      SCRJBLP

* This loop deals with printable characters

OUTCHR2  MOVE.L   A1,A3
OUTCH_LP ADDQ.L   #1,A3
         CMPA.L   Q_END(A2),A3
         BHS.S    OUTCH_TP
         CMPA.L   Q_NEXTIN(A2),A3
         BEQ.S    OUTCH_EN
;         TST.B    PARITY(A6)
;         IF GE THEN
;            ANDI.B   #$7F,(A2)
;         ENDIF
         MOVE.B   (A3),D1
         CMPI.B   #$20,D1
         BLO.S    OUTCH_EN
         CMPI.B   #$7F,D1
         BNE      OUTCH_LP
         BRA.S    OUTCH_EN
OUTCH_TP LEA      Q_QUEUE(A2),A3
         MOVE.L   A3,Q_NXTOUT(A2)
         BRA.S    OUTCH_E2
OUTCH_EN MOVE.L   A3,Q_NXTOUT(A2)
OUTCH_E2 MOVE.L   A3,D2
         SUB.L    A1,D2
         BSR.S    OUT_LOGS
         QDOS     IO.SSTRG
         BRA      SCRJBLP

OUT_LOGB TST.W    LOGCHID+2(A6)
         BMI.S    OL_END
         CMPI.B   #CR,D1
         BNE.S    OUT_LOG2
         TST.B    CONVLF(A6)
         BNE.S    OL_END
OUT_LOG2 CMPI.B   #ESC,D1
         BNE.S    OUT_LOG3
         TST.B    L_COOKED(A6)
         BNE.S    OL_END
OUT_LOG3 MOVEQ    #IO.SBYTE&$FF,D0
         BRA.S    OUT_LOG4
OUT_LOGS TST.W    LOGCHID+2(A6)
         BMI.S    OL_END
         MOVEQ    #IO.SSTRG&$FF,D0
OUT_LOG4 MOVEM.L  D1-D3/A0-A1,-(A7)
         MOVE.L   LOGCHID(A6),A0
         MOVEQ    #-1,D3
         TRAP     #3
         MOVEM.L  (A7)+,D1-D3/A0-A1
OL_END   RTS

* Deal with escape sequences

GO_ESC   BSR      UPD_TAIL          first update queue tail
         TST.B    L_COOKED(A6)
         IF EQ THEN
            BSR      OUT_LOGB       and log if necessary
         ENDIF

* This is a modification from v2.33 to v2.34
* We no longer consider VT52 and ANSI separately depending on the mode but just
* handle them as they come in.

*         TST.B    SCRMOD(A6)
*         BGT.S    GO_ANSI

         TST.B    PARNUM(A6)        PARNUM is >=0 for VT52, -1 for CSI (ANSI)
         BLT.S    A_GETPAR          Get next parameter in ANSI mode
         BNE.S    GET_PAR           Get parameter (if any) in VT52 mode
         CMPI.B   #$5B,D1           ESC start of CSI (ANSI) sequence
         BEQ.S    EXPT_PAR          ...so start collecting parameters
         LEA      ESCTBL,A4         Lookup any other escape char in VT52 table
         BSR      LOOKTBL
         BNE.S    ESC_END           If not found, reset and loop back
         LSR.W    #8,D2             MSB of D2 is # of parameters
         BEQ.S    GO_ESC1           if no parameters, just do it now
         MOVE.L   A4,ESCRTN(A6)     Else, keep address of handler and set
         MOVE.B   D2,PARNUM(A6)     number of expected parameters
         CLR.W    PB_PNT(A6)
         BRA      SCRJBLP           ... and loop back for next char

* Handle parameters of VT52 sequence, just single character codes

GET_PAR  LEA      PARBUF(A6),A3     Point A3 to start of parameter buffer
         MOVE.W   PB_PNT(A6),D0
         ADDQ.W   #1,PB_PNT(A6)
         MOVE.B   D1,(A3,D0.W)
         SUBQ.B   #1,PARNUM(A6)     Any more parameters to expect?
         BNE      SCRJBLP           Yes, loop back
         MOVE.L   ESCRTN(A6),A4
GO_ESC1  QDOS     SD.CURS
         QDOS     SD.DONL
         JSR      (A4)              ... and jump to the handling routine
ESC_END  SF       ESCMOD(A6)        End of escape handling, reset flags
         SF       PARNUM(A6)
         BRA      SCRJBLP           and loop back

* These lines are obsolete now since we've done this test already

* GO_ANSI  TST.B    PARNUM(A6)
*          BNE.S    A_GETPAR
*          CMPI.B   #$5B,D1
*          BEQ.S    EXPT_PAR

* This code dealt with non-CSI ANSI codes and is probably obsolete...

*         LEA      A_ESCTBL,A4
*         BSR.S    LOOKTBL
*         BEQ      GO_ESC1
*         BRA      ESC_END

* Start collecting parameters for CSI ANSI sequences

EXPT_PAR ST       PARNUM(A6)        PARNUM=-1 to indicate 'undetermined'
         CLR.W    PB_PNT(A6)
         BRA      SCRJBLP

* Get next parameter

A_GETPAR LEA      PARBUF(A6),A3     ; parbuf is now > 127 bytes from A6...
         CMPI.B   #';',D1           ; Store any numbers separated by ';'
         BEQ.S    ST_SEP
         CMPI.B   #'?',D1           ; private sequence
         BEQ.S    ST_SEP
         CMPI.B   #'0',D1
         BLT.S    A_GO_RTN
         CMPI.B   #'9',D1           ; store digits
         BGT.S    A_GO_RTN
ST_SEP   MOVE.W   PB_PNT(A6),D0     ; get pointer in buffer
         CMPI.W   #79,D0
         BGE.S    SCRJBL1           ; But do not allow buffer overflow...
         MOVE.B   D1,(A3,D0.W)      ; store character
         ADDQ.W   #1,PB_PNT(A6)     ; bump pointer
SCRJBL1  BRA      SCRJBLP

* Non-numeric or separator code, so must be command

A_GO_RTN CMPI.B   #' ',D1
         BEQ.S    A_SPACE           ???
         MOVE.W   PB_PNT(A6),D0
         CLR.B    (A3,D0.W)         ; terminate parameter list
         TST.B    ESCMOD(A6)
         IF GT THEN
            ORI.B    #$80,D1        SL or SR, really needed?
         ENDIF
         LEA      A_CMDTBL,A4
         BSR.S    LOOKTBL           Lookup code in ANSI table
         BNE      ESC_END
         MOVE.W   D2,D7
         LSR.W    #8,D7             D7 = # of parameters
         LEA      PARBUF(A6),A3     ; parameter buffer
         BSR      A_EVAL            ; evaluate 
         BRA      GO_ESC1           ; and go to the handler routine
A_SPACE  ANDI.B   #1,ESCMOD(A6)
         BRA      SCRJBL1

* Lookup code in a table
* Table entries: code (word) followed by handler offset (word), end marker = 0
* Call: D1.B code to lookup, A4 pointer to table
* Return: D0 error code, D2.W table entry, A4 address of handler

LOOKTBL  MOVE.W   (A4)+,D2
         BEQ.S    LKTBL_NF
         CMP.B    D1,D2
         BEQ.S    LKTBL_FN
         ADDQ.W   #2,A4
         BRA      LOOKTBL
LKTBL_FN ADDA.W   (A4),A4
         MOVEQ    #0,D0
         RTS
LKTBL_NF MOVEQ    #ERR.NF,D0
         RTS

CTRLTBL  DC.W     7
         DC.W     BEEP-*
         DC.W     8
         DC.W     BSP-*
         DC.W     9
         DC.W     TAB8-*            ; changed to next TAB stop at 8!
         DC.W     10
         DC.W     LINEFD-*
         DC.W     11
         DC.W     VTAB-*
         DC.W     12
         DC.W     CLRSCR-*
         DC.W     13
         DC.W     CRET-*
         DC.W     27
         DC.W     ESCAPE-*
         DC.W     $7F
         DC.W     DEL-*
         DC.W     0

* Escape code table for VT52

* Each entry has # of params in MSB followed by code in LSB

ESCTBL   DC.B     0,'A'
         DC.W     VT_UP-*
         DC.B     0,'B'
         DC.W     VT_DOWN-*
         DC.B     0,'C'
         DC.W     HTAB-*
         DC.B     0,'D'
         DC.W     BSP-*
         DC.B     0,'H'
         DC.W     HOME-*
         DC.B     0,'I'
         DC.W     VTAB-*
         DC.B     0,'J'
         DC.W     CLRBOT-*
         DC.B     0,'K'
         DC.W     CLRRT-*
         DC.B     1,'T'
         DC.W     SETIN-*
         DC.B     1,'U'
         DC.W     SETST-*
         DC.B     1,'V'
         DC.W     SETPA-*
         DC.B     2,'Y'
         DC.W     SETPOS-*
         DC.W     0

* Non-CSI ANSI Escape codes
* This table is believed to be obsolete and no longer used in v2.34+

A_ESCTBL DC.B     0,'D'
         DC.W     LINEFD-*
         DC.B     0,'E'
         DC.W     LINEFD-*
         DC.B     0,'M'
         DC.W     VTAB-*
         DC.W     0

* CSI ANSI control codes
* Each entry has # of params in MSB followed by code in LSB

A_CMDTBL DC.B     1,'I'
         DC.W     CHT-*
         DC.B     1,'E'
         DC.W     CNL-*
         DC.B     1,'F'
         DC.W     CPL-*
         DC.B     1,'D'
         DC.W     CUB-*
         DC.B     1,'B'
         DC.W     CUD-*
         DC.B     1,'C'
         DC.W     CUF-*
         DC.B     1,'H'
         DC.W     CUP-*
         DC.B     1,'A'
         DC.W     CUU-*
         DC.B     0,'n'
         DC.W     DSR-*
         DC.B     0,'J'
         DC.W     ED-*
         DC.B     0,'K'
         DC.W     EL-*
         DC.B     1,$60
         DC.W     HPA-*
         DC.B     1,'a'
         DC.W     HPR-*
         DC.B     1,'f'
         DC.W     CUP-*
         DC.B     0,'u'
         DC.W     RCP-*
         DC.B     0,'s'
         DC.W     SCP-*
         DC.B     1,'T'
         DC.W     SD-*
         DC.B     0,'m'
         DC.W     SGR-*
         DC.B     1,'@'+$80
         DC.W     SL-*
         DC.B     1,'A'+$80
         DC.W     SR_-*
         DC.B     1,'S'
         DC.W     SU-*
         DC.B     1,'d'
         DC.W     VPA-*
         DC.B     1,'e'
         DC.W     VPR-*
         DC.W     0

* ESCAPE   TST.B    SCRMOD(A6)
*          BLT.S    ESC_RTS
ESCAPE   ST       ESCMOD(A6)
ESC_RTS  RTS

BEEP     LEA      IPC_PARM,A3
         QDOS     MT.IPCOM
         RTS
IPC_PARM DC.B     $0A,8,$55,$55,$AA,$AA,5,5,0,0,144,13,0,0,1

DEL      BSR.S    BSP
         MOVEQ    #' ',D1
         QDOS     IO.SBYTE

BSP      MOVEQ    #SD.PCOL&$FF,D0
         BRA.S    DOTRP
HTAB     MOVEQ    #SD.NCOL&$FF,D0
         BRA.S    DOTRP
VT_UP    MOVEQ    #SD.PROW&$FF,D0
         BRA.S    DOTRP
VT_DOWN  MOVEQ    #SD.NROW&$FF,D0
         BRA.S    DOTRP
CLRSCR   MOVEQ    #SD.CLEAR&$FF,D0
         BRA.S    DOTRP
CLRBOT   QDOS     SD.CLRBT
CLRRT    MOVEQ    #SD.CLRRT&$FF,D0
         BRA.S    DOTRP
HOME     MOVEQ    #0,D1
         MOVEQ    #0,D2
         BRA.S    SETPOS1
SETPOS   MOVE.B   (A3)+,D2
         SUBI.B   #$20,D2
         MOVE.B   (A3),D1
         SUBI.B   #$20,D1
SETPOS1  MOVEQ    #SD.POS&$FF,D0
         BRA.S    DOTRP
TAB8     BSR      GETPOS            ; Get current position
         ADDQ.W   #8,D1             ; advance to next tab stop
         ANDI.W   #256-8,D1         ; .. which is a multiple of 8
         BRA.S    SDTAB
CRET     MOVEQ    #0,D1
SDTAB    MOVEQ    #SD.TAB&$FF,D0
         BRA.S    DOTRP
SETIN    MOVEQ    #SD.SETIN&$FF,D0
         BRA.S    SETCOL
SETST    MOVEQ    #SD.SETST&$FF,D0
         BRA.S    SETCOL
SETPA    MOVEQ    #SD.SETPA&$FF,D0
SETCOL   TST.B    COLRMOD(A6)
         BEQ.S    SETCOL_R
         MOVEQ    #0,D1
         MOVE.B   (A3),D1
         SUBI.B   #$40,D1
         CMPI.B   #7,D1
         BHI.S    SETCOL_R
         MOVE.B   COL4TBL(PC,D1.W),D1
         CMPI.B   #1,COLRMOD(A6)
         BEQ.S    DOTRP
         MOVE.B   COLTBL(PC,D1.W),D1
DOTRP    TRAP     #3
SETCOL_R RTS

COL4TBL  DC.B     0,2,2,3,4,6,5,7
COLTBL   DC.B     0,2,1,3,4,6,5,7

LINEFD   MOVEQ    #SD.NROW&$FF,D0
         MOVEQ    #-10,D2
         BRA.S    DOTRP2
VTAB     MOVEQ    #SD.PROW&$FF,D0
         MOVEQ    #10,D2
DOTRP2   TRAP     #3
         TST.L    D0
         IF NE THEN
            MOVE.W   D2,D1
            QDOS     SD.SCROL
         ENDIF
         RTS

* Evaluate parameters in ANSI CSI sequences
* Call  : D7 default value, A3 pointer to buffer
* Return: D0 error code, D7 value read, A3 updated

A_EVAL   MOVEQ    #-1,D0            ; no parameter yet
         CMPI.B   #'0',(A3)
         BLT.S    EVAL_END
         CMPI.B   #'9',(A3)
         BGT.S    EVAL_END          ; return NC if no number
         MOVEQ    #0,D0
         MOVEQ    #0,D7             ; initialise value
EVAL_LP  MOVE.B   (A3),D0
         SUBI.B   #'0',D0
         CMPI.B   #9,D0             ; is next char a digit?
         BHI.S    EVAL_END          ; no, stop
         ADDQ.W   #1,A3             ; skip to next char
         MULU     #10,D7
         ADD.W    D0,D7             ; include digit
         BRA      EVAL_LP

EVAL_END CMPI.B   #';',(A3)         ; separator?
         BEQ.S    EVAL_NXT          ; yes, skip
         CMPI.B   #'?',(A3)         ; NEW: test for private code '?'
         BNE.S    EVAL_RT
EVAL_NXT ADDQ.W   #1,A3             ; skip to next char
EVAL_RT  TST.L    D0
         RTS

* Get current cursor position (D1-D2) and window size (D4-D5)

GETPOS   SUBQ.W   #8,A7
         MOVE.L   A7,A1
         QDOS     SD.CHENQ
         MOVEM.W  (A7)+,D4-D5
         MOVEM.W  (A7)+,D1-D2
         RTS

CUB      NEG.W    D7
CHT
CUF
HPR      BSR      GETPOS
         ADD.W    D7,D1
         BRA.S    A_SETPOS
CUU      NEG.W    D7
CUD
VPR      BSR      GETPOS
         ADD.W    D7,D2
         BRA.S    A_SETPOS
VPA      BSR      GETPOS
         SUBQ.W   #1,D7
         MOVE.W   D7,D2
         BRA.S    A_SETPOS
CUP      SUBQ.W   #1,D7
         MOVE.W   D7,D2
         MOVEQ    #1,D7
         BSR      A_EVAL
         SUBQ.W   #1,D7
         MOVE.W   D7,D1
A_SETPOS QDOS     SD.POS
         RTS

HPA      SUBQ.W   #1,D7
         MOVE.W   D7,D1
         QDOS     SD.TAB
         RTS

CNL      BSR      GETPOS
         MOVEQ    #0,D1
         ADD.W    D7,D2
         CMP.W    D5,D2
         BLT      A_SETPOS
         MOVEQ    #1,D7
         ADD.W    D2,D7
         SUB.W    D5,D7
         BSR.S    SU
         MOVEQ    #0,D1
         MOVE.W   D5,D2
         SUBQ.W   #1,D2
         BRA      A_SETPOS

CPL      BSR      GETPOS
         MOVEQ    #0,D1
         SUB.W    D7,D2
         BGE      A_SETPOS
         NEG.W    D2
         MOVE.W   D2,D7
         BSR.S    SD
         MOVEQ    #0,D1
         MOVEQ    #0,D2
         BRA      A_SETPOS

SU       MULS     #-10,D7
         BRA.S    A_SCROLL
SD       MULU     #10,D7
A_SCROLL MOVE.W   D7,D1
         QDOS     SD.SCROL
         RTS

SL       MULS     #-6,D7
         BRA.S    A_PAN
SR_      MULU     #6,D7
A_PAN    MOVE.W   D7,D1
         QDOS     SD.PAN
EL_END   RTS

EL_AGAIN BSR      A_EVAL
         BLT      EL_END
EL       SUBQ.B   #1,D7
         BEQ.S    EL_START
         MOVEQ    #SD.CLRLN&$FF,D0
         TST.B    D7
         BGT.S    EL_TRP3
         MOVEQ    #SD.CLRRT&$FF,D0
EL_TRP3  TRAP     #3
         BRA      EL_AGAIN
EL_START BSR.S    CLSTART
         BRA      EL_AGAIN

CLSTART  BSR      GETPOS
         MOVE.W   D1,D2
         MOVEQ    #0,D1
         QDOS     SD.TAB
EL_LOOP  MOVEQ    #' ',D1
         QDOS     IO.SBYTE
         DBF      D2,EL_LOOP
         QDOS     SD.PCOL
ED_END   RTS

ED_AGAIN BSR      A_EVAL
         BLT      ED_END
ED       SUBQ.B   #1,D7
         BGT.S    ED_CLS
         BLT.S    ED_CLE
         BSR      CLSTART
         QDOS     SD.CLRTP
         BRA      ED_AGAIN
ED_CLE   QDOS     SD.CLRRT
         QDOS     SD.CLRBT
         BRA      ED_AGAIN
ED_CLS   QDOS     SD.CLEAR
         BRA      ED_AGAIN

SGR_AGN  BSR      A_EVAL
         BLT      SGR_RTS
SGR      TST.B    D7
         BEQ.S    RES_ALL           ; code 0: reset all
         SUBQ.B   #4,D7
         BNE.S    SGR_2
         MOVEQ    #1,D1             ; code 4: set underline
         QDOS     SD.SETUL
         BRA      SGR_AGN
SGR_2    SUBQ.B   #3,D7             ; code 7: reverse video
         BNE.S    SGR_3
         MOVE.L   A2,-(A7)
         LEA      GETCOL,A2
         QDOS     SD.EXTOP
         MOVE.L   (A7)+,A2
         MOVE.W   D1,D2
         QDOS     SD.SETST
         MOVE.W   D2,D1
         LSR.W    #8,D1
         QDOS     SD.SETIN
         BRA      SGR_AGN

* Handle colour

SGR_3    TST.B    COLRMOD(A6)
         BEQ      SGR_AGN           Ignore when in B&W mode
         LEA      A_COLTB4,A4
         CMPI.B   #1,COLRMOD(A6)    4-colour mode?
         IF NE THEN
            LEA      A_COLTBL,A4    No, use 8-colour table
         ENDIF
         SUBI.B   #30-7,D7
         CMPI.B   #7,D7
         BHI.S    SGR_4
         MOVE.B   (A4,D7.W),D1      ; codes 30-37
         QDOS     SD.SETIN          Set ink colour
         BRA      SGR_AGN
SGR_4    SUBI.B   #10,D7
         CMPI.B   #7,D7
         BHI      SGR_AGN
         MOVE.B   (A4,D7.W),D1      ; codes 40-47
         QDOS     SD.SETPA          Set paper colour
         MOVE.B   (A4,D7.W),D1
         QDOS     SD.SETST          And strip colour
         BRA      SGR_AGN

* Reset all - no underline and standard colours

RES_ALL  MOVEQ    #0,D1
         QDOS     SD.SETUL
         MOVE.B   MAINWINP+2,D1
         QDOS     SD.SETPA
         MOVE.B   MAINWINP+2,D1
         QDOS     SD.SETST
         MOVE.B   MAINWINP+3,D1
         QDOS     SD.SETIN
         BRA      SGR_AGN
SGR_RTS  RTS

A_COLTB4 DC.B     0,2,4,6,2,3,5,7   Colour table for 4-colour mode
A_COLTBL DC.B     0,2,4,6,1,3,5,7   Colour table for 8-colour mode

* EXTOP call for retrieving current colours

GETCOL   LEA      $45(A0),A1
         MOVE.B   (A1)+,D1
         LSL.W    #8,D1
         MOVE.B   (A1),D1
         MOVEQ    #0,D0
         RTS

* DSR - Return cursor position

DSR_STK  EQU      16                Bytes needed on stack

DSR      SUBQ.B   #6,D7             Parameter must be 6
         BNE.S    DSR_RTS
         BSR      GETPOS
         SUBA.W   #DSR_STK,A7
         MOVE.L   A7,A1
         MOVE.B   #ESC,(A1)+
         MOVE.B   #$5B,(A1)+
         EXG      D1,D2
         ADDQ.W   #1,D1
         BSR.S    D1WTOA
         MOVE.B   #';',(A1)+
         EXG      D1,D2
         ADDQ.W   #1,D1
         BSR.S    D1WTOA
         MOVE.B   #'R',(A1)+
         MOVE.L   A1,D2
         SUB.L    A7,D2
         MOVE.L   A7,A1
         JSR      TXSTR
         ADDA.W   #DSR_STK,A7
DSR_RTS  RTS

* Convert D1.W to ASCII at (A1)

D1WTOA   MOVE.L   D1,-(A7)
         CMPI.W   #9,D1
         BLE.S    D1WTOA1
         DIVU     #10,D1
         BSR      D1WTOA
         SWAP     D1
D1WTOA1  ADDI.B   #'0',D1
         MOVE.B   D1,(A1)+
         MOVE.L   (A7)+,D1
         RTS

SCP      BSR      GETPOS
         MOVEM.W  D1-D2,CURSAV(A6)
         RTS

RCP      MOVEM.W  CURSAV(A6),D1-D2
         QDOS     SD.POS
         RTS

         END
