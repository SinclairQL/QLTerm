* QLTERM TERMINAL EMULATOR
* Licenced under GPL v3 Licence (2019)
* See https://github.com/janbredenbeek/QLTerm for latest version from the author
* This should be assembled and linked using the GST/Quanta Assembler and Linker
* (see http://www.dilwyn.me.uk/asm/index.html)
*
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
*
* V2.0 -  20 April 1987
* V2.30 - 16 July 1988
* V2.31 - 23 July 1992
* V2.32 - 20 December 1993
* V2.33 - 27 September 1994
* v2.34 - 28 October 2016
* v2.35 - 09 November 2016
* v3.00b1 - 22 May 2026

         INCLUDE  MACRO_LIB
         INCLUDE  QDOS_IN_MAC
         INCLUDE  MultiConfig02
         INCLUDE  QLTERM_IN
         INCLUDE  ASSERT_INC

         XDEF     PRINTAUX,TERMBASE,GETREPLY,MAINWINP,GETMENU,DEFRXBUF

         XREF     SERJOB,SCRJOB,DOWNLOAD,UPLOAD,OPENFILE,GR_SET1
         XREF     TXCHR,TXCHR_A,TXSTR,RXCHAR,PUT_RXQ,T_WAIT

* Print a message on the command window

PRMSG    MACRO    A
[.LAB]   LEA      .S.[.L],A1
         JSR      PRINTAUX
         SECTION  MSG
.S.[.L]  STRING$  {[A]}
         SECTION  CODE
         ENDM

         SECTION  CODE

TERMBASE:
         JMP      START
         DC.W     0
         DC.W     $4AFB
         STRING$  {'QLTERM'}

* Old config section, retained for compatibility

* !!! DO NOT CHANGE THE ORDER OF THESE BYTES!

DEFBUFLN DC.W     32             FOR 32K BUFFER
DEFMODEM DC.B     1              ; not used anymore
DEFBAUD  DC.B     4              FOR 2400 BAUD
DEFPAR   DC.B     -1             FOR "NONE"
DEFECHO  DC.B     -1             FOR "FULL DUPLEX"
DEFSCR   DC.B     1              FOR "ANSI TERMINAL"
DEFCOLR  DC.B     -1             FOR "COLOUR AUTO"
DEFCONLF DC.B     1              FOR "CONVERT LINEFEEDS"
DEFCOOKD DC.B     1              FOR "COOKED LOG"
DEFPORT  DC.B     P_TELNET

* !!! DO NOT CHANGE THE DS.B BETWEEN THE FOLLOWING ENTRIES!

PORTNAME STRING$  'SER1I'
         DS.B     15
         STRING$  'SER1H'
         DS.B     15
         STRING$  'SER2I'
         DS.B     15
         STRING$  'SER2H'
         DS.B     15

CUST_CFG DC.W     48                ; Maximum length
CUST_COM STRING$  'SER3'            ; Custom comms device
         DCB.B    0,50-(*-CUST_COM)

MDM_INIT DC.W     32
         STRING$  {'ATZ|'}
MDM_DPRE DC.W     32
         STRING$  {'ATD'}
MDM_DPST DC.W     32
         STRING$  {'|'}
MDM_HUP  DC.W     32
         STRING$  {'~~+++~~ATH0|'}
         DS.W     0

* Telnet options to send when connecting

teln_opt dc.w     topt_end-*-2
         dc.b     IAC,T_DO,T_BINARY,IAC,T_WILL,T_BINARY,IAC,T_DO,T_ECHO,IAC,T_DO
         dc.b     T_SUPGA,IAC,T_WILL,T_SUPGA,IAC,T_WILL,T_TERM,IAC,T_WILL,T_NAWS
topt_end equ      *

         ds.w     0

CFG_VER  EQU      '3.00'

* New CONFIG section

        mkcfstart
        mkcfhead {Window settings},{CFG_VER}
        
          mkcfitem 'QLT1',word,'X',WIN_TLX,,,\
          {X Position of top left corner (0-511)},0,511

          mkcfitem 'QLT2',word,'Y',WIN_TLY,,,\
          {Y Position of top left corner (0-255)},0,255

          mkcfitem 'QLT3',word,'W',WIN_WID,,,\
          {Terminal window width in characters (80-255)},80,255
          
          mkcfitem 'QLT4',word,'H',WIN_HGT,,,\
          {Terminal window height in characters (24-127)},24,127

          mkcfitem 'QLT5',byte,'P',WIN_DPAP,,,\
          {Default paper colour (0-255)},0,255

          mkcfitem 'QLT6',byte,'I',WIN_DINK,,,\
          {Default ink colour (0-255)},0,255

          mkcfitem 'QLT7',byte,0,MAINWINP,,,\
          {Border colour (0-255)},0,255

         mkcfblend
         
         mkcfhead {Modem settings},{CFG_VER}

          mkcfitem 'QLT9',code,'B',DEFBAUD,,,\
          {Default baud rate}\
          0,0,{NONE},1,1,{300},2,2,{600},3,3,{1200},4,4,{2400},5,5,{4800},\
          6,6,{9600},7,7,{19200},8,8,{38400},9,9,{57600},10,A,{115200},11,B,{12H75}

          mkcfitem 'QLTL',string,0,MDM_INIT,,,\
          {Modem initialisation},cfs.sspc
          
          mkcfitem 'QLTM',string,0,MDM_DPRE,,,\
          {Modem dial prefix},cfs.sspc
          
          mkcfitem 'QLTN',string,0,MDM_DPST,,,\
          {Modem dial postfix},cfs.sspc
          
          mkcfitem 'QLTO',string,0,MDM_HUP,,,\
          {Modem hang-up command},cfs.sspc
          
         mkcfblend

         mkcfhead {Other settings},{CFG_VER}

          mkcfitem 'QLTR',word,'D',DEFRXBUF,,,\
          {Receive buffer size (KB)},0,128

          mkcfitem 'QLT8',word,'D',DEFBUFLN,,,\
          {Download buffer size (KB, not for RAMdisk)},0,64
                    
          mkcfitem 'QLTA',code,'E',DEFECHO,,,\
          {Default Local Echo setting}\
          -1,0,{Echo Off},0,1,{Echo On},1,L,{Local Only}
          
          mkcfitem 'QLTB',code,'T',DEFSCR,,,\
          {Default terminal type}\
          -1,S,{ASCII},0,V,{VT52},1,A,{VT100/ANSI}
          
          mkcfitem 'QLTC',code,'C',DEFCOLR,,,\
          {Default colour display}\
          -1,B,{Automatic},0,4,{4-colour},1,8,{8-colour}

          mkcfitem 'QLTP',code,0,DEFENTER,,,\
          {ENTER key sends}\
          0,0,{CR},1,1,{LF},2,2,{CR+LF}

          mkcfitem 'QLTQ',code,0,DEFDEL,,,\
          {BACKSPACE key sends}\
          0,0,{CTRL-H (8)},1,1,{DEL (127)}
          
          mkcfitem 'QLTD',code,0,DEFCONLF,,,\
          {Default EOL conversion for Log & Transmit}\
          0,N,{No},1,Y,{Yes}
          
          mkcfitem 'QLTE',code,0,DEFBELL,,,\
          {Make sound on receiving BEL character},\
          0,N,{No},1,Y,{Yes}
          
          mkcfitem 'QLTF',code,'L',DEFCOOKD,,,\
          {Default logging}\
          0,R,{Raw},1,C,{Cooked}
          
          mkcfitem 'QLTG',code,'S',DEFPORT,,,\
          {Default communication device}\
          0,0,{SER1I},1,1,{SER1H},2,2,{SER2I},3,3,{SER2H},4,4,{RAW TCP},5,5,{Telnet},6,6,{Custom}
          
          mkcfitem 'QLTH',string,0,CUST_CFG,,,\
          {Custom communication device},cfs.sspc
          
          mkcfitem 'QLTI',byte,0,OPENMODE,,,\
          {Mode for opening SER/TCP port},0,255
          
          mkcfitem 'QLTJ',code,0,DEFPROT,,,\
          {Default file transfer protocol}\
          0,X,{Xmodem},1,1,{Xmodem-1K},2,Y,{Ymodem},3,G,{Ymodem-G}
          
          mkcfitem 'QLTK',string,0,DLDIR_CF,,,\
          {Download directory},cfs.sspc

        mkcfblend
        
        mkcfend

WIN_TLX  DC.W     14                ; Window top left corner X
WIN_TLY  DC.W     2                 ; Window top left corner Y
WIN_WID  DC.W     80                ; Window width in characters
WIN_HGT  DC.W     24                ; Window height in characters
DEFRXBUF DC.W     64                ; Receive buffer size
DLDIR_CF DC.W     48                ; Maximum length
         STRING$  'RAM2_'           ; Download directory
         DCB.B    0,48+4-(*-DLDIR_CF)
OPENMODE DC.B     1                 ; Mode to open custom comms device
DEFPROT  DC.B     PROT_YMO          ; Default file transfer protocol
DEFBELL  DC.B     1                 ; Make sound on receiving BEL
DEFENTER DC.B     0                 ; char to send on ENTER key
DEFDEL   DC.B     1                 ; 0: send ctrl-H (8), 1: send DEL (127)

         DS.W     0                 ; Next block should be word-aligned!

* These values used when configuring above geometry fails

MAINWINP DC.B     2,1               ; Main window border colour & width
WIN_DPAP DC.B     0                 ; Main window paper colour
WIN_DINK DC.B     7                 ; Main window ink colour
         DC.W     484,242,14,2      ; Main window size & position
CMDWINP  DC.B     2,1,0,7           ; command/status window colours
         DC.W     484,12,14,244     ; ... and size & position
DEFGWIN  DC.B     0,0,0,7           ; Default window outline
         DC.W     484,254,14,2
; GWINNAM  STRING$  'SCR_484X254A014X002'
START:   ADDA.L   A6,A5             ; A5 = end of data space
         ADDA.L   A4,A6             ; A6 = start of data space
         MOVE.L   A6,A0
         MOVE.W   #VARS_END/4,D0
CLR_VARS CLR.L    (A0)+             ; clear all variables
         DBF      D0,CLR_VARS
         LEA      DEFBUFLN,A0       ; default settings
         LEA      BUFLEN(A6),A1

         ASSERT   BUFLEN,MODEMTYP-2,BAUD-3,PARITY-4,ECHOMOD-5
         ASSERT   ECHOMOD,SCRMOD-1,COLRMOD-2,CONVLF-3,L_COOKED-4
         ASSERT   L_COOKED,PORT-1

         MOVE.W   (A0)+,(A1)+       ; SET DOWNLOAD BUFFER SIZE
         MOVE.L   (A0)+,(A1)+       ; SET MODEM, BAUD, PARITY & ECHO
         MOVE.L   (A0)+,(A1)+       ; SET SCREEN, COLOUR, LF & COOKED
         MOVE.W   (A0)+,(A1)+       ; SET PORT
         MOVE.B   DEFPROT(PC),XFERPROT(A6) ; Default xfer protocol
         MOVE.B   DEFENTER(PC),ENTERKEY(A6) ; char to send on ENTER key
         MOVE.B   DEFDEL(PC),DELKEY(A6) ; char to send on Backspace key
         LEA      DLDIR_CF+2(PC),A1
         MOVE.L   A1,DLDIR(A6)      ; default download directory
         MOVE.L   2(A1),D1
         ANDI.L   #$DFDFDFF8,D1
         CMPI.L   #'RAM0',D1        ; is download dir on RAMdisk?
         BEQ.S    SET_CHAN          ; no, leave buffer size as it is
         CLR.W    BUFLEN(A6)        ; RAMdisk doesn't need buffering
;         SF       REDIR(A6)
;         SF       USE_PIPE(A6)
SET_CHAN MOVEQ    #-1,D0
         MOVE.L   D0,TSERIN(A6)     ; no channels yet
         MOVE.L   D0,TSEROUT(A6)
         MOVE.L   D0,LOGCHID(A6)
         MOVE.W   (A7)+,D0          ; number of channels passed
         BEQ.S    TSTCMD            ; zero, try command string
         ST       REDIR(A6)         ; signal 'comms device redirected'
         MOVE.L   (A7),TSERIN(A6)   ; set input channel
         SUBQ.W   #2,D0             ; two or more passed?
         BLT.S    SET_OUT           ; no, use same for output
         BEQ.S    TWO_CHAN
         SUBQ.W   #1,D0             ; three channels passed?
         BGT.S    EX_ERR            ; error if more than three
         ADDQ.W   #4,A7             ; step past input channel
         MOVE.L   (A7),LOGCHID(A6)  ; second is for logging
TWO_CHAN ADDQ.W   #4,A7             ; point to output channel
         ST       USE_PIPE(A6)      ; signal 'piped input and output'
SET_OUT  MOVE.L   (A7)+,TSEROUT(A6) ; set output channel
         BRA.S    SETRCVBF           ; go ahead

EX_ERR   SUBA.L   A0,A0
         PRINT    {'Too many files specified in EX/EW command',LF}
         BRA      QUIT2

TSTCMD   MOVE.L   A7,A4             ; A4 now points to command string
         MOVE.W   (A4)+,D0          ; is it null?
         BEQ.S    SETRCVBF          ; yes, skip it
         LEA      COMNAME(A6),A0
         MOVE.W   D0,(A0)+          ; set length
COMM_CP  MOVE.W   (A4)+,(A0)+       ; copy comms device name
         SUBQ.W   #2,D0             ; 2 bytes at a time
         BGT      COMM_CP

* Removed this, just print a warning when comms device cannot be opened
         
;SER_FAIL SUBA.L   A0,A0
;         PRINT    {'Unable to open channel to '}
;         MOVE.L   A4,A1
;         MOVE.W   UT_MTEXT,A2
;         JSR      (A2)
;         MOVEQ    #LF,D1
;         QDOS     IO.SBYTE
;         BRA      QUIT2

SETRCVBF MOVE.W   DEFRXBUF(PC),D1
         MULU     #1024,D1
         MOVEQ    #-1,D2
         QDOS     MT.ALCHP          ; allocate receive queue
         TST.L    D0
         IF NE THEN
            SUBA.L   A0,A0
            PRINT    {'Cannot allocate receive buffer. Please configure a smaller buffer',LF}
            BRA      QUIT2
         ENDIF
         MOVE.L   A0,RXQ_BASE(A6)   ; initialise queue pointer
;         MOVE.L   A2,RXQ_HEAD(A6)
;         MOVE.L   A2,RXQ_TAIL(A6)

; The next instructions mimic the IO_QSET vector, but since Minerva needlessly
; limits the size of queues to 32K bytes, we have to do it ourselves...
; we do need a larger buffer because of TCP/IP windows and possible future
; enhancements like a scroll-back buffer...

         LEA      -$10(A0,D1.L),A1  ; end of queue (discount MT.ALCHP overhead)
         MOVE.L   A0,A2
         CLR.L    (A2)+             ; clear EOF flag / link to next
         MOVE.L   A1,(A2)+          ; set q_end
         ADDA.W   #Q_QUEUE,A0       ; find start of physical queue
         MOVE.L   A0,(A2)+          ; set q_nxtin and q_nxtout
         MOVE.L   A0,(A2)+
         MOVEQ    #-1,D1
         MOVEQ    #-1,D2
         QDOS     MT.DMODE          ; test MODE
         CMPI.B   #8,D1
         IF EQ THEN
            SUBA.L   A0,A0
            PRINT    {'Sorry, this program cannot be run in MODE 8',LF}
            BRA      QUIT2
         ENDIF
         TST.B    COLRMOD(A6)
         BGE.S    OPEN_WIN          ; pre-set colour mode, skip autodetect
         CLR.B    COLRMOD(A6)       ; assume Black & White
         CMPI.B   #2,D1             ; test for 2-colour mode (SMS)
         BEQ.S    OPEN_WIN
         ADDQ.B   #1,COLRMOD(A6)    ; we have at least 4 colours available
         TST.B    D1                ; zero means MODE 4
         BEQ.S    OPEN_WIN
         ADDQ.B   #1,COLRMOD(A6)    ; we're lucky - more than 4 colours

* Open windows

OPEN_WIN: 
         MOVE.L   WIN_TLX(PC),-(A7) ; stack window top left X & Y
         MOVE.W   WIN_HGT(PC),D0
         MULU     #10,D0            ; Get pixels (NB: fails with NTSC QLs!)
         ADD.W    #10+4,D0          ; add status line height+border (4x 1 px)
         MOVE.W   D0,-(A7)
         MOVE.W   WIN_WID(PC),D0
         MULU     #6,D0             ; Get width in pixels
         ADDQ.W   #4,D0             ; add border (2x 2 px)
         MOVE.W   D0,-(A7)
         MOVE.L   DEFGWIN(PC),-(A7) ; Border colour, size, paper & strip
OPEN_GWN 
         MOVE.L   A7,A1             ; parameters for guard window
         MOVE.W   UT_SCR,A2
         JSR      (A2)              ; try opening guardian window
         MOVE.L   D0,D3             ; error code
         BEQ.S    GUARD_OK          ; OK, continue
         CMPI.L   #ERR.OR,D3        ; was it 'Out of range'?
         BNE      QUIT3             ; No, it's something serious...
         MOVE.L   DEFGWIN+4(PC),4(A7) ; Use default window size
         MOVE.L   DEFGWIN+8(PC),8(A7)
         BRA      OPEN_GWN          ; Repeat open
GUARD_OK
         MOVE.L   A0,GUARDWIN(A6)
;         MOVEQ    #-1,D3
;         QDOS     SD.CLEAR
         MOVE.L   MAINWINP(PC),(A7) ; border, paper & ink
         SUB.W    #12,6(A7)         ; subtract cmd window height
         MOVE.L   A7,A1
         MOVE.W   UT_CON,A2
         JSR      (A2)              ; open main window
         MOVE.L   D0,D3
         BNE      QUIT3             ; quit if any error
         MOVE.L   A0,MAINWIN(A6)    ; store ID
         MOVEQ    #-1,D3
         LEA      WIN_COLS(A6),A1
         QDOS     SD.CHENQ          ; record actual window geometry
         SUBA.L   A1,A1
         LEA      GR_SET1,A2        Set character set for hi-bit characters
         QDOS     SD.FOUNT
         PRINT    {'QLTERM Version [version]  Build [.date]',LF,LF}
         PRINT    {'Beta test version; please report bugs on github.com/SinclairQL/QLTerm/issues',LF,LF}
         PRINT    {'Copyright  1987-2026 by Jan Bredenbeek',LF,LF}
         PRINT    {'Colour mode: '}
         TST.B    COLRMOD(A6)
         IF EQ THEN
            PRINT    {'Black and White',LF}
         ELSE
            CMPI.B   #1,COLRMOD(A6)
            IF EQ THEN
               PRINT    {'4-colour',LF}
            ELSE
               PRINT    {'8-colour',LF}
            ENDIF
         ENDIF
         MOVE.L   CMDWINP(PC),(A7)  ; border, paper & ink for cmdwin
         MOVE.W   6(A7),10(A7)      ; cmd window comes under main window
         ADDQ.W   #2,10(A7)         ; but allow for border
         MOVE.W   #12,6(A7)         ; height = 1 char + border
         MOVE.L   A7,A1
         MOVE.W   UT_CON,A2
         JSR      (A2)
         MOVE.L   D0,D3
         BNE      QUIT3             ; quit if any error
         MOVE.L   A0,CMDWIN(A6)     ; store channel ID
         ADDA.W   #12,A7            ; clean up window params
         MOVEQ    #-1,D0
         MOVE.L   D0,SERJBID(A6)    ; no serial job yet
;         SF       XOFFMOD(A6)       ; XON/XOFF status
;         SF       DLMOD(A6)         ; download mode
;         SF       ESCMOD(A6)        ; in ESC sequence
;         SF       TXBUSY(A6)        ; TX busy
;         SF       PARNUM(A6)        ; # of parameters expected
;         SF       CONECTED(A6)      ; connected status
;         SF       IN_EOF(A6)        ; EOF in input
;         LEA      RXQ(A6),A2        ; RX queue
         MOVEQ    #-1,D1
         MOVEQ    #32,D2
         QDOS     MT.PRIOR          ; give ourselves priority 32
         LEA      SCRJOB,A1
         BSR      MAKE_JOB          ; create screen update job
         MOVE.L   D1,SCRJBID(A6)
         TST.B    REDIR(A6)         ; redirected input?
         IF EQ THEN
            BSR      SETBAUD        ; no, set baud rate
         ENDIF
         TST.B    USE_PIPE(A6)      ; piped input?
         BNE.S    ACT_SCR           ; yes, no serial job needed
         LEA      SERJOB,A1
         BSR      MAKE_JOB          ; else, create it
         MOVE.L   D1,SERJBID(A6)
         MOVEQ    #127,D2           ; use maximum priority, empty that
         MOVEQ    #0,D3             ; serial buffer asap!
         QDOS     MT.ACTIV
         BSR      OPEN_SER
ACT_SCR  MOVE.L   SCRJBID(A6),D1
         MOVEQ    #32,D2            ; start the screen update job
         MOVEQ    #0,D3
         QDOS     MT.ACTIV
MAIN_MSG BSR      STATUS            ; display status
         MOVE.L   MAINWIN(A6),A0    ; get main window ID
         MOVEQ    #-1,D3
         QDOS     SD.CURE           ; enable cursor

* Main execution loop

MAIN_LP: MOVE.L   MAINWIN(A6),A0
         MOVEQ    #0,D3
         QDOS     IO.FBYTE          Get keystroke, if any
         TST.L    D0
         BEQ.S    TST_KEY
         MOVEQ    #2,D3             If no key, wait 100 ms and retry
         BSR      T_WAIT
         TST.B    IN_EOF(A6)        ; test EOF flag
         BEQ      MAIN_LP           ; not EOF so loop back

MAIN_EOF MOVEQ    #ERR.EF,D3        ; EOF in input detected
         TST.B    USE_PIPE(A6)
         BNE      QUIT2             ; if redirected, commit suicide now
         TST.W    TSERIN+2(A6)      ; input channel already closed?
         BMI      MAIN_LP           ; yes, loop back
         BSR      DC_CLOSE          ; close input channel
         MOVE.L   MAINWIN(A6),A0
         MOVE.B   WIN_DPAP(PC),D1   ; reset colours to default
         QDOS     SD.SETPA
         QDOS     SD.SETST
         MOVE.B   WIN_DINK(PC),D1
         QDOS     SD.SETIN
         PRINT    {LF,LF,'*** Session disconnected by remote ***',LF,LF}
;         MOVE.L   SERNAME(A6),A0
;         MOVE.L   A0,D0             ; do we have a serial device?
;         BEQ      QUIT2             ; no, quit
;         QDOS     IO.OPEN           ; try reopening it
;         MOVE.L   D0,D3
;         BNE      QUIT3             ; no luck, exit
;         MOVE.L   A0,TSERIN(A6)     ; store new channel ID
;         MOVE.L   A0,TSEROUT(A6)
;         SF       IN_EOF(A6)        ; clear flag
         BRA      MAIN_MSG           ; loop back

TST_KEY  CMPI.B   #F3,D1            F3 key pressed for Menu?
         BNE.S    KEY2
         ST       DLMOD(A6)         ; do not write data to the main window
         MOVE.L   MAINWIN(A6),A0
         MOVEQ    #-1,D3
         QDOS     SD.CURS           ; disable cursor in main window
CMD_AGN  PRMSG    {'Connect, Download, Hangup, Interface, Log, Options, Quit, Upload >'}
         QDOS     SD.CURE           ; enable it for cmd window
         QDOS     IO.FBYTE          ; get keypress
         MOVE.B   D1,D2             ; save it
         QDOS     SD.CURS           ; disable cursor again
         CMPI.B   #ESC,D2           ; ESCape?
         BEQ.S    CMD_END           ; yes, go back to main
         BCLR     #5,D2             ; convert to uppercase
         LEA      CMDTBL-2,A2
CMDLOOP  ADDQ.W   #2,A2
         MOVE.W   (A2)+,D1          ; get entry for cmd letter
         BEQ      CMD_AGN           ; end of table - loop back
         CMP.B    D2,D1             ; do we have a match?
         BNE      CMDLOOP           ; no, loop back
         QDOS     SD.CLEAR          ; clear cmd window
         ADDA.W   (A2),A2           ; find address of routine
         JSR      (A2)              ; call it
CMD_END  SF       DLMOD(A6)         ; return from cmd, enable terminal
         BRA      MAIN_MSG

* 'Ordinary' key press - look for generic conversion first

KEY2     LEA      K_GEN,A1
         CMPI.B   #LF,D1            ; ENTER key
         BNE.S    KEY_DEL
         MOVE.B   ENTERKEY(A6),D0   ; get mode
         BEQ.S    KEY2LOOP          ; 0 = send CR as per conversion table
         SUBQ.B   #1,D0
         BEQ.S    SENDKEY           ; 1 = send LF unchanged
         LEA      CRLF_STR+1,A1     ; else, send CR+LF as string
         BRA.S    CTLFOUND

KEY_DEL  CMPI.B   #$C2,D1           ; DELETE (ctrl-left) ?
         BNE.S    KEY2LOOP          ; no, skip
         TST.B    DELKEY(A6)        ; DEL option?
         BNE.S    KEY2LOOP          ; yes, convert to DEL
         MOVEQ    #8,D1             ; else, send backspace
         BRA.S    SENDKEY

KEY2LOOP MOVE.W   (A1)+,D0
         BEQ.S    KEY3
         CMP.B    D1,D0
         BNE      KEY2LOOP
         MOVE.W   D0,D1
         LSR.W    #8,D1
         BRA.S    SENDKEY

CRLF_STR STRING$  {CR,LF}

* Depending on mode, do additional conversion

KEY3     LEA      K_ASC,A1
         TST.B    SCRMOD(A6)
         BLT.S    S_KTABLE
         LEA      K_VT52,A1
         BEQ.S    S_KTABLE
         LEA      K_ANSI,A1
S_KTABLE MOVE.B   (A1)+,D0
         BEQ.S    SENDKEY
         CMP.B    D1,D0
         BEQ.S    CTLFOUND
         MOVE.B   (A1)+,D0
         ADDA.W   D0,A1
         BRA      S_KTABLE
CTLFOUND MOVEQ    #0,D2
         MOVE.B   (A1)+,D2          number of chars to send
         JSR      TXSTR
         BRA      MAIN_LP

* No more conversions needed - finally send character

SENDKEY  JSR      TXCHR
         BRA      MAIN_LP

* General key conversion table
* Each pair: second byte keyboard code, first byte replacement code

K_GEN    DC.B     $0D,$0A,$7F,$C2,XOFF,F4,XON,$F6,$03,F5,0,0

* Cursor keys conversion for ASCII mode

K_ASC    DC.B     $C0,1,8           Left
         DC.B     $C8,1,9           Right
         DC.B     $D0,1,$0B         Up
         DC.B     $D8,1,LF          Down
         DC.B     0

* Cursor keys conversion for VT52

K_VT52   DC.B     $C0,2,ESC,'D'     Left
         DC.B     $C1,1,8           ALT left
         DC.B     $C8,2,ESC,'C'     Right
         DC.B     $CA,2,ESC,'K'     CTRL right
         DC.B     $D0,2,ESC,'A'     Up
         DC.B     $D1,1,$0B         ALT up
         DC.B     $D4,2,ESC,'I'     SHIFT up
         DC.B     $D8,2,ESC,'B'     Down
         DC.B     $D9,1,LF          ALT down
         DC.B     0

* Cursor keys conversion for ANSI

K_ANSI   DC.B     $FD,3,ESC,$5B,'Z'    CBT Back tab
;         DC.B     9,3,ESC,$5B,'I'      CHT Forward tab
         DC.B     $C0,3,ESC,$5B,'D'    CUB Cursor back
         DC.B     $D8,3,ESC,$5B,'B'    CUD Cursor down
         DC.B     $C8,3,ESC,$5B,'C'    CUF Cursor forward
         DC.B     $D0,3,ESC,$5B,'A'    CUU Cursor up
         DC.B     $C3,3,ESC,$5B,'M'    DL Ctrl-Alt-Left
         DC.B     $CB,3,ESC,$5B,'K'    EL Ctrl-Alt-Right
         DC.B     $CA,3,ESC,$5B,'@'    ICH Ctrl-Right
         DC.B     $DA,3,ESC,$5B,'L'    IL Ctrl-Down
         DC.B     $DC,3,ESC,$5B,'U'    NP Shift-Down
         DC.B     $D4,3,ESC,$5B,'V'    PP Shift-Up
         DC.B     $D9,3,ESC,$5B,'T'    SD Alt-Down
         DC.B     $C5,4,ESC,$5B,' @'   SL Shift-Alt-Left
         DC.B     $CD,4,ESC,$5B,' A'   SR Shift-Alt-Right
         DC.B     $D1,3,ESC,$5B,'S'    SU Alt-Up
         DC.B     0

* Table of Commands (F3 menu)

CMDTBL   DC.W     ' B'
         DC.W     SETBUF-*
         DC.W     ' C'
         DC.W     CALL-*
         DC.W     ' D'
         DC.W     DOWNLOAD-*
         DC.W     ' H'
         DC.W     HANGUP-*
         DC.W     ' I'
         DC.W     INTERFAC-*
         DC.W     ' L'
         DC.W     LOG-*
         DC.W     ' O'
         DC.W     OPTIONS-*
         DC.W     ' Q'
         DC.W     QUIT-*
         DC.W     ' T'
         DC.W     TRANSMIT-*
         DC.W     ' U'
         DC.W     UPLOAD-*
         DC.W     0

* Print message on bottom line

PRINTAUX MOVE.L   CMDWIN(A6),A0
         MOVEQ    #-1,D3
         MOVE.L   A1,-(A7)
         QDOS     SD.CLEAR
         MOVE.L   (A7)+,A1
         MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG
         RTS

* Print status on bottom line

STATUS   MOVE.L   CMDWIN(A6),A0
         MOVEQ    #-1,D3
         QDOS     SD.CLEAR
         TST.B    CONECTED(A6)
         IF NE THEN
            LOAD$    {' Online |'},A1
         ELSE
            LOAD$    {' Offline |'},A1
         ENDIF
         MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG
         MOVE.B   ECHOMOD(A6),D1
         ADDQ.B   #1,D1
         LEA      ECHOMSG,A1
         BSR.S    STA_ITEM
         MOVE.B   SCRMOD(A6),D1
         ADDQ.B   #1,D1
         LEA      SCRNMSG,A1
         BSR.S    STA_ITEM
*         LOAD$    {' Colour | '},A1
*         TST.B    COLRMOD(A6)
*         IF EQ THEN
*            LOAD$    {' B&W | '},A1
*         ENDIF
*         MOVE.W   (A1)+,D2
*         QDOS     IO.SSTRG
         MOVE.B   COLRMOD(A6),D1
         LEA      COLRMSG,A1
         BSR.S    STA_ITEM
         TST.B    REDIR(A6)         ; is comms channel redirected?
         IF EQ THEN
            MOVE.B   PORT(A6),D1    ; no, display standard device
            LEA      PORTMSG,A1
            BSR.S    STA_ITEM
         ELSE
            LOAD$    {' ReDir |'},A1 ; else, signal it
            MOVE.W   (A1)+,D2
            QDOS     IO.SSTRG
         ENDIF
         MOVE.B   BAUD(A6),D1
         LEA      BAUDMSG,A1
         BSR.S    STA_ITEM
;         MOVE.B   PARITY(A6),D1
;         ADDQ.B   #1,D1
;         LEA      PARITMSG,A1
;         BSR.S    STA_ITEM
;         MOVE.B   MODEMTYP(A6),D1
;         ADDQ.B   #1,D1
;         LEA      MODEMMSG,A1
;         BSR.S    STA_ITEM
         LOAD$    {' F3 - Menu'},A1
         MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG
         RTS

* Print item on status line
* Entry: D1: item number (0-based) (s)
*        A0: channel ID of status channel (p)
*        A1: pointer to item list (p)

STA_ITEM ADDQ.L   #2,A1             ; skipover count
STA_LP   SUBQ.B   #1,D1             ; count down, item found?
         BLO.S    STA_OUT           ; yes, print it
         MOVE.W   (A1)+,D0          ; get string length
         ADDQ.W   #1,D0
         ANDI.B   #$FE,D0           ; round up to next word
         ADDA.W   D0,A1             ; skip it and loop back
         BRA      STA_LP
STA_OUT  MOVE.W   (A1)+,D2          ; length of string
         QDOS     IO.SSTRG          ; print it
         MOVEQ    #'|',D1           ; followed by separator
         QDOS     IO.SBYTE
         RTS

* Create a (daughter) job of current job
* A1 points to start of code

MAKE_JOB MOVEQ    #-1,D1
         MOVEQ    #11,D2
         ADD.W    8(A1),D2
         BCLR     #0,D2             Code space = 10 bytes + job name (rounded)
         MOVEQ    #$7E,D3           126 bytes for stack space
         MOVE.L   A1,-(A7)
         SUBA.L   A1,A1             Note- this creates a job with its own small
         QDOS     MT.CJOB           code space. I could have set A1 to the real
         MOVE.L   D0,D3             start of code and specify 0 bytes codespace
         BNE      QUIT3             but this breaks MT.CJOB on QDOS < 1.10...
         MOVE.L   (A7)+,A1
         MOVE.L   A6,$58-$68(A0)    Set A6 of new job equal to our dataspace
         MOVE.L   $5C-$68(A0),A5    A5 = top of stack of new job
         MOVE.W   #$4EF9,(A0)+      Fill first 6 bytes of code space with JMP
         MOVE.L   A1,(A0)+          to actual code
         ADDQ.W   #6,A1
         SUBQ.L   #6,D2
MJOB_LP  MOVE.L   (A1)+,(A0)+       Now copy the name so job control utilities
         SUBQ.L   #4,D2             can see it
         BGT      MJOB_LP
         RTS

* Get menu input
* Entry: A1 points to menu table, D1 item number (0-based)
* Exit: D0 0=OK, <>0 cancelled, D1 = updated item number

GETMENU  MOVEM.L  D2-D7/A0-A3,-(A7)
         MOVE.W   (A1)+,D5          NUMBER OF ITEMS
         MOVEQ    #0,D7
         MOVE.B   D1,D7             CURRENT ITEM NO.
         MOVE.L   A1,A3
         MOVE.L   CMDWIN(A6),A0
         MOVEQ    #-1,D3
         SUBQ.L   #8,A7
         MOVE.L   A7,A1
         QDOS     SD.CHENQ
         MOVE.W   4(A7),D6          Current column pos.
         ADDQ.L   #8,A7
         MOVE.L   A3,A1
         MOVE.W   D5,D4
GM_DMENU MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG
         LSR.W    #1,D2
         IF CS THEN
            ADDQ.L   #1,A1
         ENDIF
         SUBQ.W   #1,D4
         BHI      GM_DMENU
GM_LOOP  MOVE.B   CMDWINP+3,D1
         QDOS     SD.SETST
         MOVE.B   CMDWINP+2,D1
         QDOS     SD.SETIN
         BSR.S    GM_ITEM
         MOVE.B   CMDWINP+2,D1
         QDOS     SD.SETST
         MOVE.B   CMDWINP+3,D1
         QDOS     SD.SETIN
         QDOS     IO.FBYTE
         CMPI.B   #LF,D1
         BEQ.S    GM_END
         CMPI.B   #ESC,D1
         BEQ.S    GM_NC
         MOVE.B   D1,-(A7)
         BSR.S    GM_ITEM
         MOVE.B   (A7)+,D1
         CMPI.B   #$C0,D1     CURSOR LEFT
         BEQ.S    GM_LEFT
         CMPI.B   #$C8,D1     CURSOR RIGHT
         BNE      GM_LOOP
         ADDQ.W   #1,D7
         CMP.W    D5,D7
         BLT.S    GM_LOOP
         MOVEQ    #0,D7
         BRA.S    GM_LOOP
GM_LEFT  SUBQ.W   #1,D7
         BGE.S    GM_LOOP
         MOVE.W   D5,D7
         SUBQ.W   #1,D7
         BRA      GM_LOOP
GM_NC    MOVEQ    #-1,D0
GM_END   MOVE.W   D7,D1
         MOVEM.L  (A7)+,D2-D7/A0-A3
         TST.L    D0
         RTS
GM_ITEM  MOVE.L   A3,A1
         MOVE.W   D7,D4
         MOVE.W   D6,D1
GM_ILP   SUBQ.W   #1,D4
         BLO.S    GM_IDSP
         MOVE.W   (A1)+,D0
         ADD.W    D0,D1
         ADDQ.W   #1,D0
         ANDI.B   #$FE,D0
         ADDA.W   D0,A1
         BRA      GM_ILP
GM_IDSP  MOVE.L   A1,-(A7)
         QDOS     SD.TAB
         MOVE.L   (A7)+,A1
         MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG
         RTS

* Quit program

QUIT     TST.B    CONECTED(A6)
         IF NE THEN
            BSR      HANGUP
         ENDIF
         MOVE.L   SCRJBID(A6),D1
         MOVEQ    #0,D2
         QDOS     MT.PRIOR
         MOVE.L   GUARDWIN(A6),A0
         QDOS     SD.CLEAR
QUIT2    MOVEQ    #0,D3
QUIT3    MOVEQ    #-1,D1
         QDOS     MT.FRJOB

* Set buffer size

SETBUF   PRINT    {'Current buffer size is '}
         MOVE.W   BUFLEN(A6),D1
         MOVE.W   UT_MINT,A2
         JSR      (A2)
         PRINT    {'K. New size (in K): '}
SETBUFLP LEA      TXMODBUF(A6),A1
         MOVEQ    #4,D2
         QDOS     IO.FLINE
         LEA      TXMODBUF(A6),A0
         MOVE.L   A7,A1
         SUBQ.W   #2,A7
         MOVE.L   A6,-(A7)
         SUBA.L   A6,A6
         SUBQ.W   #1,D1
         MOVEQ    #0,D7
         MOVE.W   D1,D7
         ADD.L    A0,D7
         MOVE.W   CN_DTOI,A2
         JSR      (A2)
         MOVE.L   (A7)+,A6
         MOVE.W   (A7)+,D1
         BLT.S    SETBF_ER
         TST.L    D0
         BEQ.S    SETBF_OK
SETBF_ER PRMSG    {'Invalid input, enter again: '}
         BRA      SETBUFLP
SETBF_OK MOVE.W   D1,BUFLEN(A6)
SC_END   RTS

* Send modem command (A1)

SENDCMD: MOVE.W   (A1)+,D2
SC_LOOP  SUBQ.W   #1,D2
         BLT.S    SC_END
         MOVE.B   (A1)+,D1          Get next char
         CMPI.B   #'|',D1           Replace pipe char with CR
         BNE.S    SC_NOPIP
         MOVEQ    #CR,D1
         BRA.S    SC_SEND
SC_NOPIP CMPI.B   #'\',D1           Replace backslash with LF
         BEQ.S    SC_LF
         CMPI.B   #'~',D1
         BNE.S    SC_SEND
         MOVEQ    #25,D3            and tilde char with .5 secs pause
         BRA.S    SC_PAUSE
SC_LF    MOVEQ    #LF,D1
SC_SEND  MOVE.L   A1,-(A7)
         MOVE.L   TSEROUT(A6),A0
         MOVEQ    #-1,D3
         QDOS     IO.SBYTE
         MOVE.L   (A7)+,A1
         BRA      SC_LOOP
SC_PAUSE JSR      T_WAIT
         BRA      SC_LOOP

* Disconnect

DISCON:  TST.B    USE_PIPE(A6)
         BNE.S    DC_RTS            ; Don't close pipe channels!
         TST.B    IN_EOF(A6)        ; EOF in input?
         BEQ.S    DC_CLOSE          ; yes, always close
         CMPI.B   #P_TCP,PORT(A6)   ; using TCP_IP?
         BGE.S    DC_CLOSE          ; yes, close
         LEA      MDM_HUP+2(PC),A1
         BSR      SENDCMD           ; send modem hangup command
         MOVEQ    #50,D3
         JSR      T_WAIT            ; and wait 1 second
         BRA.S    DC_RTS

DC_CLOSE MOVE.L   TSERIN(A6),A0
         QDOS     IO.CLOSE          ; close I/O channel
         MOVEQ    #-1,D1
         MOVE.L   D1,TSERIN(A6)     ; and reset channel IDs
         MOVE.L   D1,TSEROUT(A6)
         MOVE.L   RXQ_BASE(A6),A2
         MOVE.L   Q_NEXTIN(A2),Q_NXTOUT(A2) ; reset rx queue
         SF       CONECTED(A6)
DC_RTS   RTS

;ONLINE   TST.B    MODEMTYP(A6)
;         BLT.S    QM_ONLIN
;         BGT.S    SET_TX_R
;         BSR.S    HI_FREQ
;         CMPI.B   #1,BAUD(A6)
;         BNE.S    M_ON1200
;         BSR      T3.3
;         BRA      T5
;M_ON1200 BSR      T10
;         BRA      T5

* Connect to a phone number or IP address

CALL:    CMPI.B   #P_TCP,PORT(A6)
         BLT.S    CALL_2
         TST.B    CONECTED(A6)
         BEQ.S    CALL_2
         MOVE.L   CMDWIN(A6),A0
         PRINT    {'You are still connected. Disconnect'}
         BSR      GETREPLY          ; NE if N chosen
         BNE      DC_RTS            ; do not disconnect
         BSR      DISCON
CALL_2   PRMSG    {'Enter phone number, host name or IP address: '}
         LEA      TXMODBUF+2(A6),A1
         MOVEQ    #36,D2
         QDOS     IO.FLINE
         SUBA.W   D1,A1
         SUBQ.W   #1,D1
         BEQ.S    CONNECT           ; empty input, connect right away
         CMPI.B   #P_TCP,PORT(A6)
         BGE.S    CALL_TCP
         MOVE.W   D1,-(A1)          ; save length
         LEA      MDM_DPRE+2(PC),A1
         BSR      SENDCMD           ; pre-dial string ('ATD')
         LEA      TXMODBUF(A6),A1
         BSR      SENDCMD           ; send phone number
         LEA      MDM_DPST+2(PC),A1
         BSR      SENDCMD           ; post-dial string
         MOVEQ    #0,D0
         BRA.S    CALL_END          ; we'll assume
CALL_TCP
         LEA      COMNAME+2(A6),A0
         MOVE.L   #'TCP_',(A0)+
         SF       D2                ; signal 'no port number yet'
CALL_LP  CMPI.B   #':',(A1)         ; port number specified?
         BNE.S    CALL_CPY          ; not yet
         ST       D2                ; yes
CALL_CPY MOVE.B   (A1)+,(A0)+       ; copy IP address
         SUBQ.W   #1,D1
         BGT      CALL_LP
         TST.B    D2                ; port number seen?
         BNE.S    CALL_3            ; yes, do not add port
         MOVE.B   #':',(A0)+
         MOVE.B   #'2',(A0)+
         MOVE.B   #'3',(A0)+        ; add ':23'
CALL_3   MOVE.L   A0,D0
         LEA      COMNAME+2(A6),A0
         SUB.L    A0,D0             ; form length
         MOVE.W   D0,-(A0)          ; store it

CONNECT  BSR      OPEN_SER
         BNE.S    CALL_END
;         MOVE.L   RXQ_HEAD(A6),RXQ_TAIL(A6)
         SF       XOFFMOD(A6)
         SF       TXBUSY(A6)
         SF       IN_EOF(A6)
         CMPI.B   #P_TELNET,PORT(A6)
         BNE.S    CALL_END
;         MOVEQ    #50,D3
;         JSR      T_WAIT
         LEA      TELN_OPT,A1       ; Telnet default options
         MOVE.W   (A1)+,D2
         MOVEQ    #-1,D3
         QDOS     IO.SSTRG          ; don't escape IACs here!
;         MOVE.L   SCRJBID(A6),D1
;         MOVEQ    #32,D2
;         QDOS     MT.PRIOR
CALL_END RTS

* Tables used for menu commands
* Each table consists of number of entries(W) followed by entries (QDOS string)

ECHOMSG  DC.W     3
         STRING$  {' Echo Off '}
         STRING$  {' Echo On '}
         STRING$  {' Local Only '}

COLRMSG  DC.W     3
         STRING$  {' No colour '}
         STRING$  {' 4-Colour '}
         STRING$  {' 8-Colour '}

PORTMSG  DC.W     7
         STRING$  {' SER1I '}
         STRING$  {' SER1H '}
         STRING$  {' SER2I '}
         STRING$  {' SER2H '}
         STRING$  {' Custom '}
         STRING$  {' TCP '}
         STRING$  {' Telnet '}

BAUDMSG  DC.W     12
         STRING$  {' NONE '}        ; Dropped 75!
         STRING$  {' 300 '}
         STRING$  {' 600 '}
         STRING$  {' 1200 '}
         STRING$  {' 2400 '}
         STRING$  {' 4800 '}
         STRING$  {' 9600 '}
         STRING$  {' 19K2 '}
         STRING$  {' 38K4 '}
         STRING$  {' 57K6 '}
         STRING$  {' 115K2 '}
         STRING$  {' 12H75 '}

PARITMSG DC.W     5
         STRING$  {' None '}
         STRING$  {' Odd '}
         STRING$  {' Even '}
         STRING$  {' Mark '}
         STRING$  {' Space '}

; MODEMMSG DC.W     3
;         STRING$  {' Serial '}
;         STRING$  {' Telnet '}
;         STRING$  {' Buffered '}

* Baud rates (last entry is for 1200/75 using Hermes)

BAUDTBL  DC.L     0,300,600,1200,2400,4800,9600,19200,38400,57600,115200,75

* IPC command to check if Hermes present

IPC_CHKH DC.W     $0C02
         DC.L     $0000000A
         DC.B     $9F,$F7,$02

SETBAUD  MOVEQ    #0,D1
         MOVE.B   BAUD(A6),D1
         BLE.S    SB_RTS            ; 'None'
         LSL.W    #2,D1
         MOVE.L   BAUDTBL(PC,D1.W),D1
         QDOS     MT.BAUD
         CMPI.B   #BAUD_HER,BAUD(A6) ; 12H75?
         BLT.S    SB_RTS            ; No
         LEA      IPC_CHKH,A3       ; if 12H75, check if Hermes present
         QDOS     MT.IPCOM
         SUBQ.B   #8,D1
         BNE.S    SB_RTS
         MOVE.W   #$0200,-(A7)      ; Set Hermes receive baud rate to 1200
         MOVE.L   #$00080D04,-(A7)
         MOVE.B   PORT(A6),D0
         LSR.B    #1,D0
         ROR.B    #1,D0
         OR.B     D0,3(A7)
         MOVE.L   #$0C020000,-(A7)
         MOVE.L   A7,A3
         QDOS     MT.IPCOM
         ADDA.W   #10,A7
SB_RTS   RTS

INTERFAC:
         PRINT    {'Transmit Mode: '}
         MOVE.B   ECHOMOD(A6),D1
         ADDQ.B   #1,D1
         LEA      ECHOMSG,A1
         BSR      GETMENU
         BNE      SB_RTS
         SUBQ.B   #1,D1
         MOVE.B   D1,ECHOMOD(A6)
;         PRMSG    {'Modem Type: '}
;         MOVE.B   MODEMTYP(A6),D1
;         ADDQ.B   #1,D1
;         LEA      MODEMMSG,A1
;         BSR      GETMENU
;         SUBQ.B   #1,D1
;         MOVE.B   D1,MODEMTYP(A6)
         TST.B    REDIR(A6)
         BNE.S    IF_BAUD
         PRMSG    {'Port: '}
         MOVE.B   PORT(A6),D1
;         TST.B    MODEMTYP(A6)
;         IF LE THEN
;            MOVEQ    #2,D1
;         ENDIF
         LEA      PORTMSG,A1
         BSR      GETMENU
         BNE      SB_RTS
         MOVE.B   D1,PORT(A6)
         BSR      DC_CLOSE
IF_BAUD  CMPI.B   #P_TCP,PORT(A6)
         BGE.S    OPEN_SER
         PRMSG    {'Baud: '}
         LEA      BAUDMSG,A1
         MOVE.B   BAUD(A6),D1
;         MOVE.B   MODEMTYP(A6),D0
;         IF LT THEN
;            MOVEQ    #9,D1
;         ENDIF
         BSR      GETMENU
         MOVE.B   D1,BAUD(A6)
         BSR      SETBAUD
;         PRMSG    {'Parity: '}
;         MOVE.B   PARITY(A6),D1
;         ADDQ.B   #1,D1
;         LEA      PARITMSG,A1
;         BSR      GETMENU
;         SUBQ.B   #1,D1
;         MOVE.B   D1,PARITY(A6)
OPEN_SER TST.B    USE_PIPE(A6)
         BNE.S    IF_CONN           ; Do not open or close piped chans!
         LEA      COMNAME(A6),A0
         TST.W    (A0)              ; comm channel already set?
         BNE.S    OPN_SER2          ; yes, skip
         LEA      PORTNAME,A0
         MOVEQ    #0,D0
         MOVE.B   PORT(A6),D0
         MULU     #22,D0
         ADDA.W   D0,A0
         CMPI.W   #P_CUSTOM*22,D0   ; check for custom port number
         BLT.S    OPN_SER2
         BGT.S    IF_END            ; do not open TCP now
         ADDQ.L   #2,A0             ; skipover config maxlength word
OPN_SER2 MOVE.L   A0,SERNAME(A6)    ; set pointer
         MOVEQ    #-1,D1
         MOVEQ    #0,D3
         MOVE.B   OPENMODE(PC),D3
         QDOS     IO.OPEN           ; try open
         MOVE.L   D0,D4
         BEQ.S    IF_OK
         MOVE.L   MAINWIN(A6),A0
         PRINT    {LF,'*** Warning: Could not open comms device '}
         MOVE.L   SERNAME(A6),A1
         MOVE.W   UT_MTEXT,A2
         JSR      (A2)
         PRINT    {'. Try a different device.',LF,LF}
         MOVE.L   D4,D0             ; restore error code
         BRA.S    IF_END
IF_OK    MOVE.L   A0,TSERIN(A6)     ; set proper channel ids
         MOVE.L   A0,TSEROUT(A6)
IF_CONN  ST       CONECTED(A6)
         MOVEQ    #0,D0             ; exit with zero flag set
IF_END   RTS

LOG      TST.W    LOGCHID+2(A6)
         BGE.S    LOG_CLOS
         PRINT    {'Log - '}
         MOVEQ    #2,D4
         JSR      OPENFILE
         MOVE.L   A5,LOGCHID(A6)
         RTS
LOG_CLOS MOVE.L   LOGCHID(A6),A0
         QDOS     IO.CLOSE
         MOVEQ    #-1,D0
         MOVE.L   D0,LOGCHID(A6)
         MOVE.L   CMDWIN(A6),A0
         PRINT    {'Logfile closed'}
         MOVEQ    #100,D3
         BRA      T_WAIT

SCRNMSG  DC.W     3
         STRING$  {' ASCII '}
         STRING$  {' VT52 '}
         STRING$  {' ANSI '}

ENTERMSG DC.W     3
         STRING$  {' CR '}
         STRING$  {' LF '}
         STRING$  {' CR+LF '}

DELMSG   DC.W     2
         STRING$  {' CTRL-H (8) '}
         STRING$  {' DEL (127) '}

LOGMSG   DC.W     2
         STRING$  {' RAW '}
         STRING$  {' COOKED '}

CONVLFMS DC.W     2
         STRING$  {' NO '}
         STRING$  {' YES '}

OPTIONS  PRINT    {'Terminal Emulation: '}
         MOVE.B   SCRMOD(A6),D1
         ADDQ.B   #1,D1
         LEA      SCRNMSG,A1
         BSR      GETMENU
         BNE      OPT_RTS
         SUBQ.B   #1,D1
         MOVE.B   D1,SCRMOD(A6)
         PRMSG    {'Colour: '}
         MOVE.B   COLRMOD(A6),D1
         LEA      COLRMSG,A1
         BSR      GETMENU
         BNE      OPT_RTS
         MOVE.B   D1,COLRMOD(A6)
         IF EQ THEN
            MOVE.L   MAINWIN(A6),A0
            MOVE.B   MAINWINP+2,D1
            QDOS     SD.SETPA
            MOVE.B   MAINWINP+2,D1
            QDOS     SD.SETST
            MOVE.B   MAINWINP+3,D1
            QDOS     SD.SETIN
         ENDIF
         PRMSG    {'Character to send on ENTER key: '}
         MOVE.B   ENTERKEY(A6),D1
         LEA      ENTERMSG,A1
         BSR      GETMENU
         BNE.S    OPT_RTS
         MOVE.B   D1,ENTERKEY(A6)
         PRMSG    {'Character to send on Backspace key: '}
         MOVE.B   DELKEY(A6),D1
         LEA      DELMSG,A1
         BSR      GETMENU
         BNE.S    OPT_RTS
         MOVE.B   D1,DELKEY(A6)
         PRMSG    {'Logging: '}
         MOVE.B   L_COOKED(A6),D1
         LEA      LOGMSG,A1
         BSR      GETMENU
         BNE.S    OPT_RTS
         MOVE.B   D1,L_COOKED(A6)
         PRMSG    {'Convert CR/LF for LOG & TRANSMIT: '}
         MOVE.B   CONVLF(A6),D1
         LEA      CONVLFMS,A1
         BSR      GETMENU
         BNE.S    OPT_RTS
         MOVE.B   D1,CONVLF(A6)
         SF       ESCMOD(A6)
         SF       PARNUM(A6)
OPT_RTS  RTS

TRANSMIT PRINT    {'Transmit - '}
         MOVEQ    #1,D4
         JSR      OPENFILE
XMIT_LP  MOVE.L   A5,A0
         MOVEQ    #-1,D3
         QDOS     IO.FBYTE
         TST.L    D0
         BNE.S    XMIT_END
         CMPI.B   #LF,D1
         BNE.S    XMIT_2
         TST.B    CONVLF(A6)
         BEQ.S    XMIT_2
         MOVEQ    #CR,D1
XMIT_2   JSR      TXCHR
         TST.B    ECHOMOD(A6)
         IF LE AND D1 EQ.B #CR THEN
            MOVEQ    #50,D3
            BSR      T_WAIT
         ENDIF
         MOVE.L   CMDWIN(A6),A0
         MOVEQ    #0,D3
         QDOS     IO.FBYTE
         TST.L    D0
         BNE      XMIT_LP
         CMPI.B   #ESC,D1
         BNE      XMIT_LP
XMIT_END MOVE.L   A5,A0
         QDOS     IO.CLOSE
         RTS

HANGUP   PRINT    {'Disconnect line'}
         BSR.S    GETREPLY
         BEQ      DISCON
         RTS

GETREPLY PRINT    {'? (Y/N) '}
GR_GKEY  QDOS     SD.CURE
         QDOS     IO.FBYTE
         MOVEQ    #$DF,D2
         AND.B    D1,D2
         QDOS     SD.CURS
         CMPI.B   #'Y',D2
         BEQ.S    GR_RTS
         CMPI.B   #'N',D2
         BNE      GR_GKEY
         MOVEQ    #-1,D0
GR_RTS   RTS

         END
