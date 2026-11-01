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

         XREF     TXCHR,TXCHR_A,TXSTR,MAINWINP,T_WAIT,DEFRXBUF,DEFBELL

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
         BEQ      SCRJBLP1          ; If not, loop back
SCRJB_GT MOVE.B   (A1),D1           ; Get first byte
;         TST.B    PARITY(A6)
;         IF GE THEN
;            ANDI.B   #$7F,D1        Strip off any parity
;         ENDIF
         TST.B    XOFFMOD(A6)       ; Remote has been XOFF'ed?
         BEQ.S    TST_ESC           ; no
         MOVE.L   Q_NEXTIN(A2),D2
         SUB.L    A1,D2
         BGE.S    SCRJB_GE
         ADD.L    Q_END(A2),D2
         SUB.L    A2,D2
         SUBI.L   #Q_QUEUE,D2
SCRJB_GE CMPI.L   #32,D2            ; D2 = free space in buffer
         BGT.S    TST_ESC           ; if more than 32, turn remote on again
         MOVE.B   D1,D2
         MOVEQ    #XON,D1
         MOVEQ    #0,D3
         JSR      TXCHR_A
         MOVE.B   D2,D1
         TST.L    D0
         BNE.S    TST_ESC           ; ...but check if XON could be sent
         SF       XOFFMOD(A6)       ; successfully
TST_ESC  MOVE.L   MAINWIN(A6),A0
         MOVEQ    #-1,D3
         TST.B    ESCMOD(A6)        ; Are we in an escape sequence?
         BNE      GO_ESC            ; yes
         MOVEM.L  D1/A1,-(A7)       ; Now it looks that we've got something to
         QDOS     SD.CURS           ; print, so disable the cursor
         MOVEM.L  (A7)+,D1/A1
         CMPI.B   #$7F,D1
         BEQ.S    TST_ESC2
         CMPI.B   #$20,D1
         BHS.S    OUTCHR2           ; Jump if it's surely no ctrl code
TST_ESC2 BSR      UPD_TAIL          ; Update the queue's ptr
         BSR.S    OUT_LOGB          ; Log it if necessary
         LEA      CTRLTBL,A4
         BSR      LOOKTBL           ; Now lookup the code
         BNE.S    BAD_CTRL          ; Don't print unrecognised ctrl's
         QDOS     SD.DONL           ; Activate any pending NL's
         JSR      (A4)              ; ...and do it!
         BRA      SCRJBLP
OUTCHR   QDOS     IO.SBYTE          ; Print one character
         BRA      SCRJBLP

BAD_CTRL LOAD$    {'Unknown ctrl code '},A1
         JSR      DEBUGMSG
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
OUTCH_TP MOVEQ    #Q_QUEUE,D0
         ADD.L    A2,D0
         MOVE.L   D0,Q_NXTOUT(A2)
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
         BNE.S    BAD_VT52          If not found, reset and loop back
         LSR.W    #8,D2             MSB of D2 is # of parameters
         BEQ.S    GO_ESC1           if no parameters, just do it now
         MOVE.L   A4,ESCRTN(A6)     Else, keep address of handler and set
         MOVE.B   D2,PARNUM(A6)     number of expected parameters
         CLR.W    PB_PNT(A6)
         BRA      SCRJBLP           ... and loop back for next char

BAD_VT52 LOAD$    {'Unknown VT52 code '},A1
         JSR      DEBUGMSG
         BRA.S    ESC_END

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

EXPT_PAR ST       PARNUM(A6)        ; PARNUM=-1 to indicate 'undetermined'
         CLR.W    PB_PNT(A6)        ; reset pointer to current param
         BRA      SCRJBLP           ; loop back

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
         BEQ.S    A_SPACE           ; ???
         MOVE.W   PB_PNT(A6),D0
         CLR.B    (A3,D0.W)         ; terminate parameter list
         TST.B    ESCMOD(A6)
         IF GT THEN
            ORI.B    #$80,D1        ; SL or SR, really needed?
         ENDIF
         LEA      A_CMDTBL,A4
         BSR.S    LOOKTBL           ; Lookup code in ANSI table
         BNE.S    BAD_CSI
         MOVE.W   D2,D7
         LSR.W    #8,D7             ; D7 = default value for param
         LEA      PARBUF(A6),A3     ; parameter buffer
         BSR      A_EVAL            ; evaluate 
         BRA      GO_ESC1           ; and go to the handler routine
A_SPACE  ANDI.B   #1,ESCMOD(A6)
         BRA      SCRJBLP

BAD_CSI  LOAD$    {'Unknown CSI code '},A1
         JSR      DEBUGMSG
         BRA      ESC_END

* Lookup code in a table
* Table entries: code (word) followed by handler offset (word), end marker = 0
* Call: D1.B code to lookup, A4 pointer to table
* Return: D0 error code, D2.W table entry, A4 address of handler

LOOKTBL1 ADDQ.W   #2,A4             ; skip to next entry
LOOKTBL  MOVE.W   (A4)+,D2
         BEQ.S    LKTBL_NF
         CMP.B    D1,D2
         BNE.S    LOOKTBL1
         ADDA.W   (A4),A4           ; get address of handler
         MOVEQ    #0,D0
         RTS
LKTBL_NF MOVEQ    #ERR.NF,D0        ; not found
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
* Each entry has default value in MSB followed by code in LSB

A_CMDTBL DC.B     1,'G'
         DC.W     CHA-*
         DC.B     1,'I'
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
         DC.B     1,'P'
         DC.W     DCH-*
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
         DC.B     1,'@'
         DC.W     ICH-*
         DC.B     1,'f'
         DC.W     CUP-*
         DC.B     0,'u'
         DC.W     RCP-*
         DC.B     0,'l'
         DC.W     RM-*
         DC.B     0,'s'
         DC.W     SCP-*
         DC.B     1,'T'
         DC.W     SD-*
         DC.B     0,'m'
         DC.W     SGR-*
         DC.B     1,'@'+$80
         DC.W     SL-*
         DC.B     0,'h'
         DC.W     SM-*
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
ESCAPE   ST       ESCMOD(A6)        ; set escape mode
ESC_RTS  RTS

BEEP     MOVE.B   DEFBELL(PC),D0    ; check option first
         BEQ.S    ESC_RTS
         LEA      IPC_PARM,A3
         QDOS     MT.IPCOM
         RTS
IPC_PARM DC.B     $0A,8,$55,$55,$AA,$AA,5,5,0,0,144,13,0,0,1

* VT52 escape codes

DEL      BSR.S    BSP               ; go back one char
         MOVEQ    #' ',D1           ; and rub it out
         QDOS     IO.SBYTE

BSP      MOVEQ    #SD.PCOL&$FF,D0   ; backspace
         BRA.S    DOTRP
HTAB     MOVEQ    #SD.NCOL&$FF,D0   ; horizontal tab (1 char)
         BRA.S    DOTRP
VT_UP    MOVEQ    #SD.PROW&$FF,D0   ; move cursor up
         BRA.S    DOTRP
VT_DOWN  MOVEQ    #SD.NROW&$FF,D0   ; move cursor down
         BRA.S    DOTRP
CLRSCR   MOVEQ    #SD.CLEAR&$FF,D0  ; clear window
         BRA.S    DOTRP
CLRBOT   QDOS     SD.CLRBT          ; clear to bottom of window
CLRRT    MOVEQ    #SD.CLRRT&$FF,D0  ; clear from cursor to end of line
         BRA.S    DOTRP
HOME     MOVEQ    #0,D1             ; set cursor home
         MOVEQ    #0,D2
         BRA.S    SETPOS1
SETPOS   MOVE.B   (A3)+,D2          ; set cursor position
         SUBI.B   #$20,D2
         MOVE.B   (A3),D1
         SUBI.B   #$20,D1
SETPOS1  MOVEQ    #SD.POS&$FF,D0
         BRA.S    DOTRP
TAB8     BSR      GETPOS            ; Get current position
         ADDQ.W   #8,D1             ; advance to next tab stop
         ANDI.W   #256-8,D1         ; .. which is a multiple of 8
         BRA.S    SDTAB
CRET     MOVEQ    #0,D1             ; CR
SDTAB    MOVEQ    #SD.TAB&$FF,D0
         BRA.S    DOTRP
SETIN    MOVEQ    #SD.SETIN&$FF,D0  ; set foreground
         BRA.S    SETCOL
SETST    MOVEQ    #SD.SETST&$FF,D0  ; set background
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
         CMPI.B   #'?',(A3)         ; NEW: test for private code '?'
         IF EQ THEN
            ADDQ.W   #1,A3          ; skip 
         ENDIF
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
         BNE.S    EVAL_RT           ; no, return
         ADDQ.W   #1,A3             ; skip to next char
EVAL_RT  TST.L    D0
         RTS

* Get current cursor position (D1-D2) and window size (D4-D5)

GETPOS   SUBQ.W   #8,A7
         MOVE.L   A7,A1
         QDOS     SD.CHENQ
         MOVEM.W  (A7)+,D4-D5
         MOVEM.W  (A7)+,D1-D2
         RTS

CUB      NEG.W    D7                ; cursor back
CHT                                 ; HT
CUF                                 ; cursor forward
HPR      BSR      GETPOS
         ADD.W    D7,D1
         BRA.S    A_SETPOS
CUU      NEG.W    D7                ; cursor up
CUD                                 ; cursor down
VPR      BSR      GETPOS
         ADD.W    D7,D2
         BRA.S    A_SETPOS
VPA      BSR      GETPOS
         SUBQ.W   #1,D7
         MOVE.W   D7,D2
         BRA.S    A_SETPOS
CUP      SUBQ.W   #1,D7             ; cursor position
         MOVE.W   D7,D2             ; line #
         MOVEQ    #1,D7             ; default column
         BSR      A_EVAL
         SUBQ.W   #1,D7
         MOVE.W   D7,D1             ; column #
A_SETPOS MOVE.W   D1,-(A7)          ; save column
         QDOS     SD.POS
         MOVE.W   (A7)+,D1
         TST.L    D0                ; OK?
         BEQ.S    CUP_RTS           ; yes, exit
         QDOS     SD.TAB            ; try again setting only column
CUP_RTS  RTS

CHA      
HPA      SUBQ.W   #1,D7             ; set column
         MOVE.W   D7,D1
         QDOS     SD.TAB
         RTS

CNL      BSR      GETPOS            ; move cursor down n lines
         MOVEQ    #0,D1
         ADD.W    D7,D2
         CMP.W    D5,D2             ; check against bottom line
         BLT      A_SETPOS          ; OK, in range
         MOVEQ    #1,D7
         ADD.W    D2,D7
         SUB.W    D5,D7
         BSR.S    SU                ; scroll up
         MOVEQ    #0,D1
         MOVE.W   D5,D2
         SUBQ.W   #1,D2
         BRA      A_SETPOS

CPL      BSR      GETPOS            ; move cursor up n lines
         MOVEQ    #0,D1
         SUB.W    D7,D2
         BGE      A_SETPOS
         NEG.W    D2
         MOVE.W   D2,D7
         BSR.S    SD
         MOVEQ    #0,D1
         MOVEQ    #0,D2
         BRA      A_SETPOS

SU       MULS     #-YINC,D7           ; scroll up
         BRA.S    A_SCROLL
SD       MULU     #YINC,D7            ; scroll down
A_SCROLL MOVE.W   D7,D1
         QDOS     SD.SCROL
         RTS

SL       MULS     #-XINC,D7            ; scroll left
         BRA.S    A_PAN
SR_      MULU     #XINC,D7             ; scroll right
A_PAN    MOVE.W   D7,D1
         QDOS     SD.PAN
EL_END   RTS

DCH      MULS     #-XINC,D7
         BRA.S    A_PANRT
ICH      MULU     #XINC,D7
A_PANRT  MOVE.W   D7,D1
         QDOS     SD.PANRT
         RTS

EL_AGAIN BSR      A_EVAL
         BLT      EL_END
EL       SUBQ.B   #1,D7             ; CSI 1 K = erase from begin line to cursor
         BEQ.S    EL_START
         MOVEQ    #SD.CLRLN&$FF,D0
         TST.B    D7                ; CSI 1 K = erase cursor line
         BGT.S    EL_TRP3
         MOVEQ    #SD.CLRRT&$FF,D0  ; CSI 0 K = erase from cursor to end
EL_TRP3  TRAP     #3                ; do the operation
         BRA      EL_AGAIN          ; and look for more
EL_START BSR.S    CLSTART           ; clear from start to cursor
         BRA      EL_AGAIN

; subroutine to clear line from start to cursor
; unfortunately, there's no QDOS trap for this so we have to
; just print spaces :(

CLSTART  BSR      GETPOS            ; get current position
         MOVE.W   D1,D2             ; save column position
         MOVEQ    #0,D1             ; move to start of line
         QDOS     SD.TAB
EL_LOOP  MOVEQ    #' ',D1
         QDOS     IO.SBYTE          ; now print spaces
         DBF      D2,EL_LOOP        ; until current column
         QDOS     SD.PCOL           ; go back one position 
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

* CSI SGR codes

SGR_TAB  DC.W     0                 ; reset all
         DC.W     RES_ALL-*
         DC.W     1                 ; bold (or alternative colour)
         DC.W     BOLD_ON-*
         DC.W     4                 ; underline on
         DC.W     UL_ON-*
         DC.W     5
         DC.W     SGR_RTS-*         ; Blink not supported yet...
         DC.W     7                 ; Inverse
         DC.W     INV_ON-*
         DC.W     22                ; cancel bold
         DC.W     BOLD_OFF-*
         DC.W     24                ; cancel underline
         DC.W     UL_ON-*
         DC.W     25                ; cancel blinking
         DC.W     SGR_RTS-*
         DC.W     27                ; cancel inverse
         DC.W     INV_OFF-*
         DC.W     -1

* Main loop for SGR

SGR_AGN  BSR      A_EVAL            ; evaluate next param
         BLT.S    SGR_RTS           ; exit when none found

SGR      LEA      SGR_TAB(PC),A1    ; table of SGR codes
SGR_LOOP MOVE.W   (A1)+,D0          ; get code
         BMI      SGR_3             ; not in table, try colour codes
         MOVE.W   (A1)+,D1          ; offset to handler
         CMP.B    D7,D0             ; match?
         BNE      SGR_LOOP          ; no, try next
         LEA      -2(A1,D1.W),A1    ; get handler address in A1
         JSR      (A1)              ; call it
         BRA      SGR_AGN           ; and loop back

* Reset all - no underline and standard colours

RES_ALL  BSR.S    BOLD_OFF
         BSR      INV_OFF
         MOVEQ    #0,D1
         QDOS     SD.SETUL          ; reset underline script
         MOVEQ    #0,D1
         MOVEQ    #0,D2
         BSR      SET_COLR          ; reset background
         MOVEQ    #7,D1
         MOVEQ    #1,D2
         BSR      SET_COLR          ; reset foreground
SGR_RTS  RTS

BOLD_ON  TAS      BOLDFLG(A6)       ; test if already Bold
         BNE      SGR_RTS           ; yes, exit
         MOVEQ    #1,D2             ; change ink colour
         MOVEQ    #7,D1             ; assume mono mode, set to white
         TST.B    COLRMOD(A6)       ; mono mode?
         BEQ      SET_COLR          ; yes, set colour
         CMPI.B   #COL_16,COLRMOD(A6) ; using 16 colours?
         BNE      SGR_RTS           ; no, ignore
         MOVE.B   FGCOLOUR(A6),D1   ; get current ink
         CMPI.B   #7,D1             ; already using bright colours?
         BHI      SGR_RTS           ; yes, ignore
         ADDQ.B   #8,D1             ; change colour to bright variant
         BRA      SET_COLR

BOLD_OFF TST.B    BOLDFLG(A6)       ; using bold?
         BEQ      SGR_RTS           ; no, exit
         SF       BOLDFLG(A6)       ; clear flag
         MOVEQ    #1,D2             ; change ink colour
         MOVEQ    #4,D1             ; assume mono, set to green
         TST.B    COLRMOD(A6)       ; mono mode?
         BEQ.S    SET_COLR          ; yes, set ink
         CMPI.B   #COL_16,COLRMOD(A6) ; using 16 colours?
         BNE      SGR_RTS           ; no, ignore
         MOVE.B   FGCOLOUR(A6),D1   ; get current ink
         SUBQ.B   #8,D1             ; change bright colours to normal
         BLT      SGR_RTS           ; but don't change normal colours
         BRA.S    SET_COLR

UL_ON    CMPI.B   #4,D7             ; entry point for underline on/off
         SEQ      D1
         ANDI.W   #1,D1             ; parameter 4 ON, 24 OFF
         QDOS     SD.SETUL
         RTS

INV_ON   TAS      INV_VID(A6)       ; check if already inverse
         BNE      SGR_RTS
         BRA.S    INV_2
INV_OFF  TST.B    INV_VID(A6)
         BEQ      SGR_RTS
         SF       INV_VID(A6)
INV_2    MOVE.B   BGCOLOUR(A6),D4   ; save current paper/strip
         MOVE.B   FGCOLOUR(A6),D1   ; get current ink
         MOVEQ    #0,D2             ; change paper/strip
         BSR.S    SET_COLR
         MOVE.B   D4,D1             ; new ink = old paper/strip
         MOVEQ    #1,D2
         BRA.S    SET_COLR

* Handle colour codes

SGR_3    PEA      SGR_AGN           ; loop back after following handlers
         MOVE.B   COLRMOD(A6),D0
         BEQ      SGR_RTS           ; Ignore when in mono mode
         MOVE.W   D7,D1             ; save D7 for BAD_SGR
         SUBI.B   #30,D7
         BLT.S    BAD_SGR           ; reject anything < 30

; At this point, value of D7 is:
; 0-7:   standard foreground colour
; 10-17: standard background colour
; 60-67: bright foreground colour
; 70-77: bright background colour

         DIVU     #10,D7            ; separate normal & bright, fg & bg
         MOVE.L   D7,D4
         SWAP     D4                ; d4 now holds colour code 0-7
         CMPI.W   #7,D4
         BHI.S    BAD_SGR           ; but reject 8 & 9
         MOVE.W   D4,D1             ; colour goes to D1
         MOVEQ    #0,D2             ; assume background
         BCLR     D2,D7             ; test & clear fg/bg bit
         BNE.S    SGR_4
         MOVEQ    #1,D2             ; no, it's foreground
SGR_4    SUBQ.B   #COL_QL8,D0       ; check colour mode again
         BLS.S    SET_COLR          ; handle QL 4 & emulated-8 colour modes

SGR_16   TST.W    D7                ; 0 for normal colours, 6 for bright
         BEQ.S    SET_COLR
         ADDQ.W   #8,D1             ; if bright, add 8 to colour code

; continue into SET_COLR

* Set colours
* Entry: D1: ANSI colour code (0-15)
*        D2: 0 for background (paper & strip), 1 for foreground (ink)

IOW.PAPT EQU      $54               ; TRAP #3 key for setting 24-bit colour

SET_COLR LEA      BGCOLOUR(A6),A1
         ANDI.W   #$FF,D1           ; ensure MSB of D1 is zero
         MOVE.B   D1,(A1,D2.W)      ; store new colour
         MOVE.B   COLRMOD(A6),D0    ; get colour mode
         BEQ      SGR_RTS           ; do nothing in mono mode
         SUBQ.B   #COL_QL8,D0       ; test for QL 4 or emulated-8 colour modes
         BHI.S    SETCOL16          ; if >2, we are in 16 colour mode
         LEA      A_COLTBL,A4       ; presume solid colours?
         BLT.S    SETCOL1           ; yes
         LEA      A_COLTB8,A4       ; use emulated 8-colours
SETCOL1  MOVE.B   (A4,D1.W),D1      ; get QDOS colour from table
         MOVEQ    #SD.SETPA&$FF,D0  ; use SETPA/SETST/SETIN trap
         BRA.S    SETCOL2

SETCOL16 LEA      A_COLTB16,A4      ; 16-colour code table
         LSL.W    #2,D1             ; each entry has 24-bit colour code,
         MOVE.L   (A4,D1.W),D1      ; but the MSB is not used here
         MOVEQ    #IOW.PAPT,D0      ; IOW.PAPT/IOW.STRT/IOW.INKT
SETCOL2  TST.B    D2                ; are we setting foreground colour?
         BNE.S    SET_INK           ; yes
         MOVEM.L  D0/D1,-(A7)       ; save trap code & colour param
         BSR.S    SETCOL3           ; set paper
         MOVEM.L  (A7)+,D0/D1       ; restore trap code & colour
         ADDQ.W   #1,D0             ; set strip
         BRA.S    SETCOL3
SET_INK  ADDQ.W   #2,D0             ; add 2 for ink trap code
SETCOL3  MOVEQ    #-1,D2            ; UNDOCUMENTED - needed for extended TRAPs!
         TRAP     #3                ; do it
         RTS

BAD_SGR  LOAD$    {'Unknown SGR code '},A1
         BRA.S    DEBUGMSG
RM       LOAD$    {'RM code '},A1
         BRA.S    RM_SM
SM       LOAD$    {'SM code '},A1
RM_SM    MOVE.W   D7,D1

* Print debug message at (A1) followed by hex code in D1

DEBUGMSG TST.B    ADEBUG(A6)
         BEQ.S    DEBG_RTS
         MOVEM.L  D1-D3/A0-A2,-(A7)
         SUBA.L   A0,A0             ; channel 0 or 1
         MOVE.W   UT_MTEXT,A2
         JSR      (A2)              ; print message
         LEA      VARS_END+4,A0       ; scrap buffer (relative to A6)
         MOVE.L   #$00073078,-4(A6,A0.L) ; length 7 & '0x'
         LEA      2(A7),A1          ; saved value of D1.W on stack
         SUBA.L   A6,A1             ; make it relative to A6
         MOVE.W   CN_ITOHW,A2
         JSR      (A2)              ; ASCIIfy to hex
         LEA      VARS_END(A6),A1   ; point again to buffer
         MOVE.B   #LF,8(A1)         ; terminate message with LF
         SUBA.L   A0,A0
         MOVE.W   UT_MTEXT,A2
         JSR      (A2)              ; print hex code followed by LF
         MOVEM.L  (A7)+,D1-D3/A0-A2
DEBG_RTS RTS


; A_COLTB4 DC.B     0,2,4,6,2,3,5,7   Colour table for 4-colour mode
A_COLTBL DC.B     0,2,4,6,1,3,5,7   Colour table for 4-colour (no background)

* Table for converting 8-colour ANSI codes to QL colours with stipples

A_COLTB8 DC.B     0,2,4,244,255,239,223,7

* Table for converting 16-colour ANSI codes to 24-bit SMSQ/E codes
* format: RRGGBB00 - I had to find out by reverse-engineering the SMSQ/E code!

A_COLTB16: ;      $00RRGGBB
         DC.L     $00000000         ; 0 = black
         DC.L     $BF000000         ; 1 = red
         DC.L     $00BF0000         ; 2 = green
         DC.L     $BFBF0000         ; 3 = yellow
         DC.L     $0000BF00         ; 4 = blue
         DC.L     $BF00BF00         ; 5 = magenta
         DC.L     $00BFBF00         ; 6 = cyan
         DC.L     $BFBFBF00         ; 7 = white
         DC.L     $80808000         ; 8 = dark grey
         DC.L     $FF000000         ; 9 = bright red
         DC.L     $00FF0000         ; 10 = bright green
         DC.L     $FFFF0000         ; 11 = bright yellow
         DC.L     $0000FF00         ; 12 = bright blue
         DC.L     $FF00FF00         ; 13 = bright magenta
         DC.L     $00FFFF00         ; 14 = bright cyan
         DC.L     $FFFFFF00         ; 15 = bright white

* EXTOP call for retrieving current colours
* Returns: D1 msb STRIP colour, D1 lsb INK colour

GETCOL   LEA      $45(A0),A1        ; STRIP colour
         MOVE.B   (A1)+,D1
         LSL.W    #8,D1
         MOVE.B   (A1),D1           ; INK colour
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
