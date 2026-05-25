* QLTerm Terminal Emulator
* Licenced under GPL v3 Licence (2019)
* See https://github.com/janbredenbeek/QLTerm for latest version from the author
* This should be assembled and linked using the GST/Quanta Assembler and Linker
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

* XMODEM DOWNLOAD/UPLOAD ROUTINES

         INCLUDE  MACRO_LIB
         INCLUDE  QDOS_IN_MAC
         INCLUDE  QLTERM_IN

PRMSG    MACRO    A
         NOLIST
[.LAB]   LEA      .S.[.L],A1
         JSR      PRINTAUX
         SECTION  MSG
.S.[.L]  STRING$  {[A]}
         SECTION  CODE
         LIST
         ENDM

         XDEF     DOWNLOAD,UPLOAD

         XREF     TXCHR,TXSTR,T_WAIT,GETREPLY,PRINTAUX,OPEN_DEF,DTOI_L,OTOI_L
         XREF     ITOD_L,ITOO_L,CRC_TBL,GETMENU,OPEN_PRE,OPENFILE,RXCHAR

         DATA     0

         SECTION  CODE

PROTOMSG DC.W     4
         STRING$  {' XMODEM '}
         STRING$  {' XMODEM-1K '}
         STRING$  {' YMODEM '}
         STRING$  {' YMODEM-G '}

* Open a batch of files for download or upload
* Entry: D4 open key (1: upload, 2: download)
* Exit:  D0 error code, A5 channel ID if opened
* With Ymodem d/l: does not actually open a file, only sets name in FNAMBUF

OPEN_BAT MOVE.W   #-1,A5            ; signal 'no file opened yet'
         CLR.W    FNAM_OFS(A6)      ; no device name yet
         CMPI.B   #1,D4             ; are we uploading?
         BEQ.S    OF_ASK            ; yes, always ask
         CMPI.B   #PROT_YMO,XFERPROT(A6) ; using Ymodem(-G)?
         BLT.S    OF_ASK            ; no, for Xmodem always ask
         LEA      FNAMBUF(A6),A1
         MOVE.W   #8,(A1)+          ; enter a default filename in case
         MOVE.L   #'QLTD',(A1)+     ; the sender doesn't send one
         MOVE.L   #'OWN_',(A1)+     ; (e.g. Xmodem when Ymodem requested)
         RTS

OF_QUIT  MOVEQ    #ERR.NC,D0
         RTS

OF_ASK   PRINT    {'File Name: '}
         LEA      FNAMBUF+2(A6),A1
         MOVEQ    #-1,D3
         MOVEQ    #44,D2
         QDOS     IO.FLINE          ; get file name from user input
         SUBQ.W   #1,D1
         BEQ.S    OF_QUIT
         MOVE.W   D1,FNAMBUF(A6)
         CMPI.B   #2,D4             ; opening download for Xmodem?
         BEQ      OF_NEW            ; yes, go open a new file

* Open a file for upload.
* NOTE: The call to IO.OPEN has been replaced by a call to OPEN_DEF, so the
* full file name doesn't have to be specified if it's in the TK2 data default
* directory.
* This still allows for uploads from any device/directory, since the default
* directory is only prepended if the initial io.open fails with 'not found'.
* However, when using Ymodem, we do not want a possible subdirectory name sent 
* along with the file name. Hence, we need to drop the subdirectory part of
* the filename, which is a bit tricky thanks to the peculiar way QDOS/SMSQ
* handles subdirectories. Therefore we need to open first as directory and
* find out which part of the name is really the subdir name - ouch!

* On return, FNAMBUF should contain the full path+filename
* FNAM_OFS(A6) should hold the offset to the plain file name
* (after the device name + possible subdirectory name)

SV_DATAD EQU      $B0               ; offset DATAD$ pointer from sysvars base

OF_DIR   QDOS     MT.INF            ; get sysvars base
         LEA      SV_DATAD(A0),A1   ; default data directory (pointer!)
         LEA      FNAMBUF(A6),A0    ; file name + possible subdir
         MOVEQ    #1,D3             ; try opening file
         JSR      OPEN_DEF          ; returns with real dev + subdir prepended
         BNE.S    FERROR            ; bail out if already unsuccessful
         MOVE.L   A0,A5             ; save channel ID
         MOVEQ    #-1,D1
         MOVEQ    #4,D3
         LEA      FNAMBUF(A6),A0
         QDOS     IO.OPEN           ; now open again as directory
         TST.L    D0                ; successful?
         BEQ.S    OF_HDR            ; yes, get header
         LEA      FNAMBUF+2(A6),A0  ; assume no directory device
         BRA.S    OF_NSUB           ; exit
         
OF_HDR   MOVEQ    #64,D2            ; get 64 bytes of header
         MOVEQ    #-1,D3
         LEA      TXMODBUF(A6),A1   ; temporary buffer
         CLR.W    14(A1)            ; no filename yet
         QDOS     FS.HEADR          ; read the header
         QDOS     IO.CLOSE          ; close the channel
         LEA      FNAMBUF(A6),A0
         MOVE.L   2(A0),D1          ; get first 4 chars of device
         SUBI.L   #$00010000,D1
         ANDI.L   #$C0F8FF00,D1     ; match on letter+digit+underscore
         CMPI.L   #$40305F00,D1     ; is it a network drive?
         BNE.S    OF_NONET          ; no
         ST       FNAMBUF+4(A6)     ; blotch out the underscore
OF_NONET MOVE.W   (A0)+,D0          ; get length
         SUBQ.W   #1,D0
OF_UDLP  CMPI.B   #'_',(A0)+        ; find end of device name
         DBEQ     D0,OF_UDLP
         ROR.W    #8,D1
         MOVE.B   D1,FNAMBUF+4(A6)  ; restore any blotched underscore
         MOVE.W   TXMODBUF+14(A6),D0 ; length of subdir name (if any)
         BEQ.S    OF_NSUB           ; no subdir
         ADDA.W   D0,A0             ; skip subdir name
         MOVE.B   #'_',(A0)+        ; add underscore after subdir name
OF_NSUB  MOVE.L   A0,D0             ; A0 now points to plain file name
         LEA      FNAMBUF+2(A6),A0
         SUB.L    A0,D0             ; find offset from start
         MOVE.W   D0,FNAM_OFS(A6)   ; and store
         MOVEQ    #0,D0             ; assume no error
         RTS

FERROR   MOVE.L   D0,-(A7)          ; print error message
         PRMSG    {'ERROR: '}
         MOVE.L   (A7),D0
         MOVE.W   UT_ERR,A1
         JSR      (A1)
         MOVE.W   #150,D3
         JSR      T_WAIT
         MOVE.L   (A7)+,D0
         RTS

* Open a new file for download
* Always creates in DLDIR directory
* For Ymodem, this will be called for each file to be downloaded
* Returns: D0 error code 
*          A5 channel ID if successful, else -1

OF_NEW   LEA      DLDIR(A6),A1
         MOVE.L   (A1),A0
         MOVE.W   (A0),FNAM_OFS(A6) ; set offset to file name
         MOVEQ    #2,D3             ; open key
         MOVE.W   #-1,A5            ; no channel ID yet
         LEA      FNAMBUF(A6),A0
         JSR      OPEN_PRE          ; prepend dev+dir and open
         BEQ.S    OF_EXIT
OF_EXIST CMPI.L   #ERR.EX,D0        ; already exists?
         BNE.S    FERROR            ; no, other error
         BSR.S    CHK_DUP           ; rename any duplicate names
         LEA      FNAMBUF(A6),A0
         JSR      OPENFILE          ; retry
         BNE      OF_EXIST          ; and loop if still no success

OF_EXIT  MOVE.L   A0,A5             ; transfer channel ID to A5
WAIT_IO  MOVEM.L  D0-D3/A0-A1,-(A7)
         MOVE.L   FNAMBUF+2(A6),D1  ; check device name
         SUBQ.B   #1,D1
         ANDI.L   #$DFDFDFF8,D1
         CMPI.L   #'RAM0',D1        ; is it on RAMdisk?
         BEQ.S    OF_RTS            ; yes, return immediately
         MOVEQ    #100,D3           ; else, wait 2 seconds for the hardware to
         JSR      T_WAIT            ; write it to the media
         QDOS     MT.INF            ; (really only needed on QL-like hardware)
         REPEAT                     ; wait for any MDV activity to stop 
            TST.B    $EE(A0)        ; NB: This could also be the SD card driver!
         UNTIL EQ
OF_RTS   MOVEM.L  (A7)+,D0-D3/A0-A1
         TST.L    D0
         RTS

* Rename duplicate file names (add _dup1, _dup2 etc)

CHK_DUP  LEA      FNAMBUF(A6),A1
         ADDA.W   (A1)+,A1          ; point past file name
         MOVE.L   A1,-(A7)          ; save for later
         SUBQ.W   #5,A1             ; end of name -5
         MOVEQ    #3,D0             ; at most 4 chars to compare
         LEA      DUP(PC),A0
CHKD_LP  CMPM.B   (A0)+,(A1)+       ; check if _dup extension already exists
         DBNE     D0,CHKD_LP
         MOVE.L   (A7)+,A1          ; restore end of name ptr
         BEQ.S    CHKD_INC          ; if _dup extension exists, increment counter
         LEA      DUP(PC),A0
         MOVEQ    #4,D0             ; 5 chars to copy (_dup and count)
CHKD_CP  MOVE.B   (A0)+,(A1)+
         DBF      D0,CHKD_CP
         ADDQ.W   #5,FNAMBUF(A6)    ; file name is now 5 chars longer
CHKD_INC ADDQ.B   #1,-1(A1)         ; increment number for each call
         RTS

DUP      DC.B     '_dup0'

* Display progress: file name, running/total bytes, status messages
* Entry: A1 pointer to status message or null
*        D5 bytes send/rcvd so far, file header variables must be set
*        D7 bit XM..CLR set if status message to be cleared
* Exit:  D0 != 0 and flag NE if user pressed CTRL-X to abort transfer
*        All other regs preserved

BLOCKMSG MOVEM.L  D1-D3/A0-A1,-(A7)
         MOVE.L   CMDWIN(A6),A0
         MOVEQ    #0,D3             ; use zero timeout so don't hang on ctl-c
         MOVEQ    #0,D1
         QDOS     SD.TAB
         LOAD$    {'File: '},A1
         MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG
         LEA      FNAMBUF(A6),A1
         MOVE.W   (A1)+,D2
         ADDA.W   FNAM_OFS(A6),A1
         SUB.W    FNAM_OFS(A6),D2
         QDOS     IO.SSTRG          ; print file name
         SUBA.W   #32,A7
         MOVE.L   A7,A1
         MOVE.L   D5,D1
         MOVE.B   #' ',(A1)+
         JSR      ITOD_L
         MOVE.L   FILELEN(A6),D1
         BMI.S    BM_NOLEN
         MOVE.B   #'/',(A1)+
         JSR      ITOD_L
BM_NOLEN MOVE.B   #' ',(A1)+
         MOVE.B   #' ',(A1)+
         MOVE.L   A1,D2
         MOVE.L   A7,A1
         SUB.L    A1,D2
         QDOS     IO.SSTRG          ; print progress
         ADDA.W   #32,A7
         MOVE.L   16(A7),D0         ; original A1
         BNE.S    BM_MSG
         BCLR     #XM..CLR,D7       ; set to clear status msg
         BNE.S    BM_CLR
BM_MSG   MOVE.L   D0,A1
         MOVE.W   (A1)+,D2
         QDOS     IO.SSTRG          ; print status message (if any)
BM_CLR   QDOS     SD.CLRRT
BM_INP   QDOS     IO.FBYTE          ; check for any keypress
         TST.L    D0
         BNE.S    BM_OK
         CMPI.B   #CAN,D1           ; CTRL-X
         BNE.S    BM_OK
         MOVE.B   D1,D0
         BRA.S    BM_END
BM_OK    MOVEQ    #0,D0
BM_END   MOVEM.L  (A7)+,D1-D3/A0-A1
         RTS

* Calculate and check checksum/CRC
* Entry: D7.W length of block, bit 0 set for CRC mode
* Returns EQ when check/crc matches, stores calculated value

CALCHK   MOVEQ    #0,D3             ; initialise checksum/CRC
         LEA      CRC_TBL,A0        ; table of pre-calculated CRC values
         LEA      TXMODBUF+2(A6),A1 ; start of data in buffer
         MOVE.W   D7,D0             ; block size (+1 for CRC)
         BCLR     D3,D0             ; test and clear CRC bit
         BNE.S    CRCCOUNT          ; go calculate the CRC
         SUBQ.W   #1,D0             ; discount 1 byte for DBF
CHKLOOP  ADD.B    (A1)+,D3          ; else, simply add each byte value
         DBF      D0,CHKLOOP
         MOVE.B   (A1),D1           ; get checksum (if received)
         MOVE.B   D3,(A1)           ; store new checksum
         CMP.B    D1,D3             ; return EQ if they match
         RTS

CRCLOOP  MOVEQ    #0,D1
         MOVE.B   (A1)+,D1          ; get next byte
         ROL.W    #8,D3             ; swap lsb & msb
         EOR.B    D3,D1             ; xor with old msb
         ADD.W    D1,D1             ; index into table
         MOVE.W   (A0,D1.W),D1      ; get pre-calculated value
         CLR.B    D3                ; clear lsb
         EOR.W    D1,D3             ; xor with running msb
CRCCOUNT DBF      D0,CRCLOOP
         MOVE.W   (A1),D1           ; get crc from block
         MOVE.W   D3,(A1)           ; store new crc (NB: MUST be word-aligned!)
         CMP.W    D1,D3             ; return EQ if they match
         RTS

* Download one or more files (called from main menu)

DOWNLOAD MOVE.B   XFERPROT(A6),D1
         LEA      PROTOMSG,A1
         JSR      GETMENU           ; ask for protocol
         MOVE.B   D1,XFERPROT(A6)   ; store as default for later
         PRMSG    {'Download - '}
         MOVEQ    #2,D4
         BSR      OPEN_BAT          ; create new file (Xmodem only)
         MOVEQ    #0,D2
         BSR      SP_SERJB          ; stop serial input job
         MOVEQ    #0,D1
         LEA      TXMODBUF+2(A6),A2 ; preset A2 to start of tx/rx buffer data
         MOVE.L   D1,A3             ; preset A3 and A4 to null
         MOVE.L   D1,A4
         MOVE.W   BUFLEN(A6),D1     ; get receive buffer length in K
         BEQ.S    DL_NXFIL          ; no receive buffer, just direct I/O
         SWAP     D1
         LSR.L    #6,D1
         MOVEQ    #-1,D2
         QDOS     MT.ALCHP          ; allocate buffer
         TST.L    D0
         BEQ.S    DL_BF_OK
         PRMSG    {'No room for download buffer'}
         BRA      DL_CAN

DL_BF_OK MOVE.L   A0,A4             ; set start of download buffer
         MOVE.L   A4,A2             ; start of running pointer
         LEA      -$10(A4,D1.L),A3  ; set end of download buffer

DL_NXFIL MOVEQ    #0,D4             ; error counter
         MOVEQ    #0,D5             ; file position
         MOVEQ    #0,D6             ; block counter
         CMPI.B   #PROT_YMO,XFERPROT(A6) ; Ymodem?
         SGT      YMODEM_G(A6)      ; set G option according to protocol
         BGE.S    DL_BLKSZ          ; yes, expect a zero block
         MOVEQ    #1,D6             ; else, ignore zero block
DL_BLKSZ MOVEQ    #1,D7             ; try crc mode first
         ST       FILELEN(A6)       ; file length unknown yet
         BRA.S    DL_START

DL_ACK1  ADDQ.L   #1,D6             ; ACK Ymodem file descriptor block
         ANDI.W   #1,D7             ; discard block length bits, keep CRC bit
         TST.B    YMODEM_G(A6)
         BNE.S    DL_START          ; Don't ACK descriptor block with Ymodem-G
         MOVEQ    #ACK,D1
         JSR      TXCHR
DL_START LOAD$    {'Waiting for sender...'},A1
         BSR      BLOCKMSG
         BNE      DL_CAN
DL_PURG1 MOVEQ    #50,D3            ; This loop added because there are
         JSR      RXCHAR            ; braindead implementations which send
         BEQ      DL_PURG1          ; the first block already after block 0
         BSET     #XM..CLR,D7       ; has been ACKed :(.
         MOVEQ    #'G',D2
         TST.B    YMODEM_G(A6)      ; Trying Ymodem-G?
         BNE.S    DL_CW             ; yes, activate xfer with 'G'
DL_CMODE MOVEQ    #'C',D2           ; else, try CRC mode
DL_CW    ADDQ.B   #1,D4             ; increase try counter
         CMPI.B   #5,D4             ; try 5x C/G
         BGT.S    DL_NO_C           ; sender apparently doesn't do CRC mode :(
         MOVE.B   D2,D1             ; send 'G' or 'C' as appropriate
         JSR      TXCHR
         MOVE.W   #250,D3           ; wait at most 5 seconds for reply
         JSR      RXCHAR
         BGT.S    DL_CW             ; no response, poll remote again
         BLT      DL_ABORT
         CMPI.B   #CAN,D1           ; got CAN?
         BNE.S    DL_CKSOH          ; no, check further
         BSET     #XM..CAN,D7       ; set CAN flag
         BEQ      DL_CW             ; first CAN, loop back
         BRA      DL_ABORT          ; abort if another CAN got

DL_CKSOH BCLR     #XM..CAN,D7       ; clear CAN flag
         CMPI.B   #SOH,D1           ; got SOH?
         BEQ      DL_BLK1           ; yes, expect 128-byte block
         CMPI.B   #STX,D1           ; got STX?
         BEQ      DL_BLK1K          ; yes, expect 1K block
         BRA.S    DL_CW             ; nothing interesting, poll again

DL_NO_C  MOVEQ    #1,D4             ; reset try counter
         SF       YMODEM_G(A6)      ; clear Ymodem-G flag
         CMPI.B   #'G',D2           ; tried Ymodem-G?
         BEQ      DL_CMODE          ; try again without G
         BCLR     #XM..CRC,D7       ; reset CRC flag
DL_NAK   MOVEQ    #50,D3
DL_PURGE JSR      RXCHAR            ; purge all input
         BEQ.S    DL_PURGE
         MOVEQ    #NAK,D1           ; send NAK
         BRA.S    DL_OUT

DL_ACK   MOVEQ    #ACK,D1           ; send ACK
         TST.B    YMODEM_G(A6)
         BNE.S    DL_STAT           ; Don't ACK blocks in Ymodem-G
DL_OUT   JSR      TXCHR
DL_STAT  SUBA.L   A1,A1             ; no status to display
         BSR      BLOCKMSG          ; display progress
         BNE      DL_CAN            ; oops...
DL_SOHW  MOVE.L   TSERIN(A6),A0
         MOVE.W   #500,D3           ; wait 10 seconds for block
         JSR      RXCHAR
         BGT      DL_TIMO           ; fail if nothing got in 10 seconds
         BLT      DL_ABORT          ; abort if other error (EOF?)
         CMPI.B   #CAN,D1           ; got CAN?
         BNE.S    DL_CKEOT          ; no, check further
         BSET     #XM..CAN,D7       ; set CAN flag
         BEQ      DL_SOHW           ; first CAN; eat it and loop back
         BRA      DL_ABORT          ; but abort if another CAN got

DL_CKEOT BCLR     #XM..CAN,D7       ; reset CAN flag
         CMPI.B   #EOT,D1           ; end of file?
         BNE.S    DL_BLK            ; no, check further
         TST.B    YMODEM_G(A6)
         BNE      DL_END            ; No NAK for EOT with Ymodem-G
         BSET     #XM..EOT,D7       ; set flag
         BEQ      DL_NAK            ; NAK first EOT (avoid premature end)
         BRA      DL_END

DL_BLK   AND.W    #1,D7             ; only keep crc bit + flags
         CMPI.B   #SOH,D1           ; got SOH?
         BEQ.S    DL_BLK1           ; yes, prepare for 128-byte block
         CMPI.B   #STX,D1
         BNE      DL_SOHW
DL_BLK1K OR.W     #1024,D7          ; set 1K block length
         BRA.S    DL_RBLK
DL_BLK1  OR.W     #128,D7           ; set 128 byte block length
DL_RBLK  MOVEQ    #3,D2             ; block size + header + checksum
         ADD.W    D7,D2             ; add one byte if CRC mode
         MOVE.W   #10*50,D3         ; 10 second timeout
         LEA      TXMODBUF(A6),A1
         CMPI.B   #P_TELNET,PORT(A6) ; using Telnet?
         BEQ.S    DL_RTLP           ; yes, use byte I/O
DL_RBLKL QDOS     IO.FSTRG          ; else, just fetch whole block at once
         TST.L    D0
         BNE.S    DL_TIMO
         BRA.S    DL_CKSUM
DL_RTLP  MOVEM.L  D2/A1,-(A7)       ; rxchar smashes D2/A1
         JSR      RXCHAR            ; read one byte at a time, escaped chars
         MOVEM.L  (A7)+,D2/A1       ; are a bitch :(
         BNE.S    DL_TIMO
         MOVE.B   D1,(A1)+          ; store it
         SUBQ.W   #1,D2
         BNE      DL_RTLP           ; and loop
DL_CKSUM BSR      CALCHK            ; checksum OK?
         BEQ.S    DL_LBLK           ; yes
         LOAD$    {'Checksum/CRC error'},A1
         BRA.S    DL_CKERR

DL_TIMO  LOAD$    {'Timeout'},A1
DL_CKERR TST.B    YMODEM_G(A6)      ; block error, fatal with Ymodem-G
         BNE.S    DL_FAIL
         BSR      BLOCKMSG          ; display progress + error message
         BNE      DL_CAN            ; user wants to bail out...
         BSET     #XM..CLR,D7       ; clear error on next call
         ADDQ.B   #1,D4             ; bump error counter
         CMPI.B   #10,D4
         BLE      DL_NAK            ; NAK it unless more than 10 errors
         MOVEQ    #0,D4             ; ask user
         PRMSG    {'10X Transmit error. Retry'}
         JSR      GETREPLY
         BEQ      DL_NAK
         BRA      DL_CAN

; finally got block OK, now check if it's the right one

DL_LBLK  MOVEQ    #0,D4             ; reset error count
         LEA      TXMODBUF(A6),A1
         CMP.B    (A1),D6           ; test block number against expected
         BHI      DL_ACK            ; earlier block, just ACK it
         BEQ.S    DL_CHKB           ; expected block, check batch
         TST.B    D6                ; expected block # not wrapped to zero?
         BNE.S    DL_FAIL           ; yes, abort with sync error
         TST.L    D5                ; are we waiting for first block?
         BGT      DL_ACK            ; no, ACK it

; We expected a Ymodem descriptor block but got first Xmodem block instead..
; so create a file with default name

         BSR      OF_NEW
         BNE.S    DL_CAN
         BRA.S    DL_COPY

; if all else fails...

DL_FAIL  PRMSG    {'FATAL ERROR: Synchronisation loss'}
         BRA.S    DL_CAN

; Correct block received, now process it

DL_CHKB  TST.L    D6                ; file descriptor block?
         BNE.S    DL_COPY           ; no, copy it
         BSR      DL_DESC           ; process descriptor block
         CMPI.L   #ERR.EF,D0        ; end of batch?
         BEQ.S    DL_END            ; yes, ACK it
         TST.L    D0                ; Other errors?
         BEQ      DL_ACK1           ; no, ACK it and get next file
         BRA.S    DL_CAN            ; oops...

DL_COPY  MOVE.W   D7,D2             ; size of this block
         ANDI.L   #$FFFE,D2         ; discard the crc bit + flags
         MOVE.L   A4,D0             ; is there a download buffer?
         BEQ.S    DL_WRITE          ; no, write the block
         LEA      (A2,D2.W),A0      ; point to end of block in buffer
         CMPA.L   A3,A0             ; past end of buffer?         
         BLS.S    DL_COPY2          ; no, just copy new block
DL_WRITE BSR      DL_SAVE           ; write buffer
         BNE.S    DL_CAN            ; cancel if error
         BSR      WAIT_IO           ; wait for I/O to finish
DL_COPY2 MOVE.L   A4,D0             ; test again for download buffer
         BEQ.S    DL_NEXT
         LEA      TXMODBUF+2(A6),A1 ; source of new block
         MOVE.W   D2,D0             ; length of block
DL_FILL  MOVE.L   (A1)+,(A2)+       ; copy to buffer
         SUBQ.W   #4,D0             ; ...either 128 or 1024 bytes
         BGT      DL_FILL
DL_NEXT  ADD.L    D2,D5             ; bump file position
         ADDQ.L   #1,D6             ; and block number (long!)
         BRA      DL_ACK            ; and ACK it

DL_END   PRMSG    {'Download OK'}   ; got EOT
         MOVEQ    #ACK,D1           ; ack EOT
         BRA.S    DL_AKEOT

DL_ABORT PRMSG    {'Download aborted by remote'}
DL_CAN   MOVEQ    #CAN,D1           ; fatal error...
         JSR      TXCHR             ; send CAN twice
DL_AKEOT MOVE.B   D1,D4             ; save as flag
         JSR      TXCHR
         MOVE.W   A5,D0             ; received a file?
         BMI.S    DL_EXIT           ; no, exit
         BSR.S    DL_SAVE           ; yes, save what remains of it
         MOVE.L   A5,A0             ; file channel ID
         QDOS     IO.CLOSE
         MOVE.W   #-1,A5            ; 'no file yet'
         CMPI.B   #CAN,D4           ; was download cancelled?
         BEQ.S    DL_EXIT           ; yes, exit
         CMPI.B   #PROT_YMO,XFERPROT(A6) ; Ymodem(-G)?
         BGE      DL_NXFIL          ; yes, get next file
DL_EXIT  MOVEQ    #100,D3
         JSR      T_WAIT            ; wait 2 seconds         
         MOVE.L   A4,D0             ; buffer address
         IF NE THEN
            MOVE.L   D0,A0          ; release it unless no buffer
            QDOS     MT.RECHP
         ENDIF
         MOVEQ    #32,D2
         BSR      SP_SERJB          ; re-activate serial input
         RTS

* Get pointer to block to be saved in A1
* Returns: A1 start of data (either in TXMODBUF or download buffer)
*          D0 download buffer address or null
*          D2 length of downloaded block

DL_GETBF LEA      TXMODBUF+2(A6),A1 ; assume start of block
         MOVE.L   A4,D0             ; do we have a download buffer?
         BEQ.S    DL_BF_EN          ; no, return D2 unchanged
         MOVE.L   D0,A1             ; set A1 to start of download buffer
         MOVE.L   A2,D2
         SUB.L    A1,D2             ; return length of downloaded block in D2
DL_BF_EN RTS

* Save contents of download buffer to file
* Handles Qemulator/QPC2 header

* Entry: D2.L length of this block
*        D5.L length of file received so far
*        A2.L end of block in buffer
*        A4.L address of download buffer (or 0)
*        A5.L channel ID of file to be saved
* Exit:  D0 error status
*        A2 reset to start of buffer
*        D1/D3/A0-A1 smashed

DL_SAVE  MOVE.L   D2,-(A7)          ; save block length
         BSR      DL_GETBF          ; get start in A1 and length in D2
         BSET     #XM..HD,D7        ; first block already processed?
         BNE.S    DL_NOHDR          ; yes, skip
         LEA      QDOS_HDR(PC),A0   ; check for QDOS header (Qemulator/QPC2)
         MOVE.L   A1,-(A7)
         MOVEQ    #HD_MKLEN-1,D0
LOOK_HDR CMPM.B   (A0)+,(A1)+       ; check for marker
         DBNE     D0,LOOK_HDR
         BNE.S    DL_NOHD2          ; no header, just save
         MOVEQ    #0,D0
         MOVE.B   1(A1),D0          ; total header length / 2
         ADD.W    D0,D0
         MOVE.L   D0,-(A7)
         MOVE.L   A5,A0             ; channel ID
         SUBQ.L   #2,A1             ; start of header data
         CLR.L    (A1)              ; clear 'length' long word (needed?)
         MOVEQ    #-1,D3
         QDOS     FS.HEADS          ; set file header
         MOVE.L   (A7)+,D0          ; restore header length
         MOVE.L   (A7)+,A1          ; and pointer to start
         ADDA.W   D0,A1             ; point past header data
         SUB.L    D0,D5             ; discount header length from file pos
         SUB.L    D0,D2             ; .. and from block length
         SUB.L    D0,FILELEN(A6)    ; .. and from file length
         BRA.S    DL_SBYTS

; At this point:
; D2.L: length of block, either in download buffer or txmodbuf
; A1: pointer to start of data in download buffer or txmodbuf

DL_NOHD2 MOVE.L   (A7)+,A1          ; restore start of block
DL_NOHDR TST.B    FILELEN(A6)       ; is real file length known?
         BLT.S    DL_SBYT2          ; no, just save it (with up to 127 bytes garbage)
DL_SBYTS MOVE.L   D5,D1             ; length of received file so far
         SUB.L    FILELEN(A6),D1    ; subtract real length
         BLE.S    DL_SBYT2          ; no residual bytes leftover
         SUB.L    D1,D2             ; else, discount them from block length
         BGE.S    DL_SBYT2          ; D2 should be zero or positive
         MOVEQ    #0,D2             ; anything else is probably an error!
DL_SBYT2 MOVEQ    #-1,D3            ; timeout
         MOVE.L   A5,A0             ; channel ID
         QDOS     FS.SAVE           ; save buffer
         TST.L    D0
         IF NE THEN
            MOVE.L   D0,-(A7)
            PRMSG    {'FILE ERROR: '}
            MOVE.L   (A7)+,D0
            MOVE.W   UT_ERR,A1
            JSR      (A1)
         ENDIF
         MOVE.L   A4,D1
         BEQ.S    DLS_END
         MOVE.L   A4,A2             ; reset buffer pointer
DLS_END  MOVE.L   (A7)+,D2          ; restore block length
         TST.L    D0
         RTS

* Process received Ymodem file descriptor block

DL_DESC  LEA      TXMODBUF+2(A6),A0 ; start of received file name
         TST.B    (A0)              ; null name?
         BEQ.S    DLD_EF            ; yes, return EOF
         LEA      FNAMBUF+2(A6),A1  ; buffer to copy to
         MOVEQ    #35,D0            ; maximum length - 1
DLD_CPFN MOVE.B   (A0)+,(A1)+
         DBEQ     D0,DLD_CPFN       ; copy filename + terminating null
         BEQ.S    DLD_FNAM          ; skip if it fits
         MOVE.B   #'*',-1(A1)       ; replace last char with '*'
DLD_SKIP TST.B    (A0)+             ; skip rest of name
         BNE      DLD_SKIP
DLD_FNAM MOVE.L   A0,-(A7)          ; save buffer position
         MOVE.L   A1,D0
         LEA      FNAMBUF+2(A6),A1
         SUB.L    A1,D0             ; form total length
         SUBQ.W   #1,D0             ; discount final null
         MOVE.W   D0,-(A1)          ; set length
         BSR      OF_NEW            ; create file
         MOVE.L   (A7)+,A1          ; restore buffer pointer
         BNE.S    DLD_RTS           ; oops...
         JSR      DTOI_L            ; get file length
         TST.L    D1                ; real length?
         BEQ.S    DLD_DATE          ; no, skip
         MOVE.L   D1,FILELEN(A6)    ; store it
DLD_DATE ADDQ.L   #1,A1             ; skip space
         JSR      OTOI_L            ; get date (octal number)
         TST.L    D1                ; real date?
         BEQ.S    DLD_OK            ; no, skip it
         ADDI.L   #3287*86400,D1    ; add difference between 1961 and 1970
         MOVEQ    #0,D2             ; set update date
         MOVE.L   A5,A0
         MOVEQ    #-1,D3
         QDOS     IOF.DATE
DLD_OK   MOVEQ    #0,D0             ; cancel any error
DLD_RTS  RTS
DLD_EF   MOVEQ    #ERR.EF,D0        ; end of batch
         RTS
DLD_BN   MOVEQ    #ERR.BN,D0        ; 'bad name'
         RTS

* File header used by Qemulator, QPC2 etc on non-QDOS file systems
* This consists of an 18-byte marker, followed by a version and length byte,
* followed by bytes 4 to 13 (inclusive) of the QDOS file header.
* Note that the file length, file name, and update date are NOT included.
* These have to be extracted from the Ymodem descriptor block (if present).

QDOS_HDR DC.B     ']!QDOS File Header' ; marker: 18 bytes
HD_MKLEN EQU      *-QDOS_HDR
HD_VER   DC.B     0,15              ; version + total length / 2
HD_TLEN  EQU      30                ; total length including data

* Get next file block in upload buffer

GETBUFF  LEA      TXMODBUF(A6),A1
         MOVE.B   D6,(A1)+          ; store block number + complement
         MOVE.B   D6,(A1)
         NOT.B    (A1)+
         MOVE.W   #128,D2           ; assume 128 byte block
         TST.B    XFERPROT(A6)      ; XMODEM gives 0
         BEQ.S    GTB_XMO           ; .. and always 128 byte blocks
         TST.L    D6                ; Ymodem block 0?
         BEQ.S    GTB_XMO           ; yes, send short block
         ASL.W    #3,D2             ; 1K block size for XMODEM-1K and Ymodem
GTB_XMO  ANDI.W   #1,D7             ; only keep CRC flag
         OR.W     D2,D7             ; transfer block size bits to D7
         MOVE.L   D6,D0
         SUBQ.L   #1,D0             ; is this block #1?
         BNE.S    GTB_FTCH          ; no, go fetch it
         TST.B    FILETYPE+1(A6)    ; any QDOS header information?
         BEQ.S    GTB_FTCH          ; no, regular file
         MOVEQ    #HD_MKLEN+2-1,D0  ; marker + HD_VER
         LEA      QDOS_HDR(PC),A0
GTB_HDLP MOVE.B   (A0)+,(A1)+       ; copy marker + version + length
         DBF      D0,GTB_HDLP
         LEA      FILETYPE(A6),A0
         MOVE.W   (A0)+,(A1)+       ; file access + type
         MOVE.L   (A0)+,(A1)+       ; data size
         MOVE.L   (A0)+,(A1)+       ; extra long word
         SUBI.W   #HD_TLEN,D2       ; discount from bytes to get from file
GTB_FTCH MOVE.L   A5,A0
         MOVEQ    #-1,D3
         QDOS     IO.FSTRG
         TST.L    D0
         BEQ.S    GTB_CHK
         CMPI.L   #ERR.EF,D0
         BEQ.S    GTB_EOF
         MOVE.L   D0,-(A7)
         PRMSG    {'FILE ERROR: '}
         MOVE.L   (A7)+,D0
GTB_ERR  MOVE.W   UT_ERR,A2
         JSR      (A2)
         BRA.S    GTB_END

GTB_EOF  TST.W    D1                ; EOF, got anything?
         BEQ.S    GTB_END           ; no, return EOF
         CMPI.W   #128,D1           ; does it fit in 128 bytes?
         BGT.S    GTB_1K            ; no
         ANDI.W   #1,D7
         ORI.W    #128,D7           ; send last short block
GTB_1K   MOVE.W   D7,D0
         SUB.W    D1,D0
GTB_FILL MOVE.B   #$1A,(A1)+        ; fill rest of buffer with CTRL-Z
         DBF      D0,GTB_FILL
GTB_CHK  ANDI.L   #$FFFF,D1         ; mask off msw
         ADD.L    D1,D5             ; set D5 to new file position
         BSR      CALCHK            ; calculate checksum/crc
         MOVEQ    #0,D0             ; cancel any EOF status
GTB_END  TST.L    D0
         RTS

UPLOAD   MOVE.B   XFERPROT(A6),D1
         LEA      PROTOMSG,A1
         JSR      GETMENU
         MOVE.B   D1,XFERPROT(A6)
         PRMSG    {'Upload - '}
         MOVEQ    #1,D4
         BSR      OPEN_BAT          ; open file for read
         BNE.S    UL_FAIL
         MOVEQ    #0,D2
         BSR      SP_SERJB          ; stop serial input job
UL_NXFIL MOVEQ    #0,D5             ; file position
         MOVEQ    #1,D6             ; starting block
         MOVE.L   #128,D7           ; assume 128 byte block + no crc + no flags
         CMPI.B   #PROT_YMO,XFERPROT(A6) ; using Xmodem?
         BLT.S    UL_HEAD           ; yes, file already opened
         MOVEQ    #0,D6             ; Ymodem, start with block 0
;         MOVE.W   #-1,A5            ; no file yet
         TST.W    FNAMBUF(A6)       ; null name marks end of batch
         BEQ.S    UL_EOB
;         BSR      OPEN_BAT          ; open file
         BRA.S    UL_HEAD

UL_FAIL  MOVEQ    #ERR.NC,D1
         CMP.L    D0,D1
         BEQ      UL_QUIT
         MOVE.L   D0,-(A7)
         PRMSG    {'Failed to open file '}
         LEA      FNAMBUF(A6),A1
         MOVE.W   UT_MTEXT,A2
         JSR      (A2)
         PRMSG    {': '}
         MOVE.L   (A7)+,D0
         MOVE.W   UT_ERR,A2
         JSR      (A2)
         BRA      UL_QUIT
         
UL_HEAD  MOVE.L   A5,A0
         MOVEQ    #-1,D3
         MOVEQ    #64,D2
         LEA      TXMODBUF(A6),A1
         QDOS     FS.HEADR          ; read file header
         SUBA.W   D1,A1
         LEA      FILELEN(A6),A2
         MOVE.L   (A1)+,(A2)+       ; copy length
         MOVE.W   (A1)+,(A2)+       ; copy access + type
         MOVE.L   (A1)+,(A2)+       ; copy data size
         MOVE.L   (A1)+,(A2)+       ; copy spare long word
         MOVE.L   $34-$0E(A1),(A2)+ ; update date
         CMPI.B   #PROT_X1K,XFERPROT(A6)
         BLE.S    UL_XMOD           ; jump with Xmodem or Xmodem-1K
UL_EOB   LEA      TXMODBUF(A6),A1
         MOVE.W   #$00FF,(A1)+      ; block number zero
         MOVEQ    #128/4-1,D0
UL_CLR   CLR.L    (A1)+             ; preset block to all-zeros
         DBF      D0,UL_CLR
         LEA      FNAMBUF(A6),A0    ; else, prepare Ymodem descriptor block
         MOVE.W   (A0)+,D1
         BEQ.S    UL_CHKS           ; null file name, end of batch
         MOVE.W   FNAM_OFS(A6),D0
         ADDA.W   D0,A0             ; step past device+directory name
         SUB.W    D0,D1
         LEA      TXMODBUF+2(A6),A1
UL_NAME  MOVE.B   (A0)+,(A1)+       ; copy bare file name
         SUBQ.W   #1,D1
         BGT      UL_NAME
         CLR.B    (A1)+             ; null separator
         MOVE.L   FILELEN(A6),D1
         TST.B    FILETYPE+1(A6)    ; EXECable file?
         BEQ.S    UL_FLEN           ; no, just send plain length
         ADDI.L   #HD_TLEN,D1       ; else, add header length
UL_FLEN  JSR      ITOD_L            ; file length in decimal
         MOVE.B   #' ',(A1)+        ; space separator
         MOVE.L   FILE_UPD(A6),D1
         BEQ.S    UL_UDATE          ; null update date remains 0
         SUBI.L   #3287*86400,D1    ; convert QDOS date to Unix (1961-1970)
UL_UDATE JSR      ITOO_L            ; date in octal
UL_CHKS  BSR      CALCHK            ; calculate checksum
         BRA.S    UL_PRBLK          ; go sending Ymodem block 0

UL_XMOD  BSR      GETBUFF           ; get first data block
         BNE      UL_QUIT
UL_PRBLK PRMSG    {'Waiting for receiver...'}
         MOVEQ    #0,D4
UL_ACKW  MOVEQ    #0,D3             ; timeout 0
         BTST     #XM..YMG,D7       ; Ymodem-G?
         BEQ.S    UL_EAT            ; no, wait for ACK
         BTST     #XM..ACK,D7       ; first block ACKed?
         BEQ.S    UL_WAIT           ; no, wait
         JSR      RXCHAR            ; try getting a character
         BNE.S    UL_NEXT           ; got nothing, send next block
         BRA.S    UL_CANCK          ; else, check for CAN

UL_EAT   JSR      RXCHAR            ; test if a character is available
         BEQ      UL_EAT            ; eat it         
UL_WAIT  MOVE.W   #3000,D3          ; wait at most 1 minute
UL_FBYTE JSR      RXCHAR            ; get response from receiver
         BNE      UL_ABORT          ; timeout or other error
         CMPI.B   #NAK,D1           ; got NAK?
         BEQ.S    UL_XMIT           ; yes, resend block
UL_CANCK CMPI.B   #CAN,D1           ; CAN?
         BEQ      UL_CAN            ; yes, but check flag first
         BCLR     #XM..CAN,D7       ; else, clear it
         CMPI.B   #'C',D1           ; 'C'?
         BEQ.S    UL_CRC            ; yes, set CRC mode
         CMPI.B   #'G',D1           ; Ymodem-G?
         BNE.S    TST_ACK           ; no, check for ACK
         BSET     #XM..YMG,D7       ; set Ymodem-G flag
         BNE.S    UL_NEXT           ; if already set, this is first block's ACK
UL_CRC   BTST     #XM..ACK,D7       ; first block ACKed?
         BNE.S    UL_XMIT           ; yes, OK to send
         ORI.W    #1,D7             ; set CRC mode
         BSR      CALCHK            ; re-calculate CRC
         BRA.S    UL_XMIT           ; send it

TST_ACK  CMPI.B   #ACK,D1           ; got ACK?
         BNE.S    UL_ACKW           ; nothing sensible, eat it and wait again
UL_NEXT  BTST     #XM..EOF,D7       ; last block sent?
         BEQ.S    UL_NEXT1          ; no, get next block
         CMPI.B   #PROT_YMO,XFERPROT(A6) ; Xmodem?
         BLT.S    UL_OK             ; yes, finished
         MOVE.L   A5,D0             ; end of batch?
         BMI.S    UL_OK             ; yes, finished
         MOVE.L   D0,A0
         QDOS     IO.CLOSE          ; close file
         MOVE.W   #-1,A5            ; mark end of batch
         CLR.W    FNAMBUF(A6)       ; prepare for sending EOB block
         BRA      UL_NXFIL          ; loop back
         
UL_NEXT1 ADDQ.L   #1,D6             ; bump block number
         BSET     #XM..ACK,D7       ; signal 'first block ACKed'
         MOVE.W   A5,D0             ; -1 means end of batch
         BMI.S    UL_OK
         BSR      GETBUFF           ; get next block from file
         BEQ.S    UL_XMIT0
         CMPI.L   #ERR.EF,D0        ; end of file?
         BNE.S    UL_QUIT           ; no, other error
         BSET     #XM..EOF,D7       ; flag 'send EOT'
UL_XMIT0 MOVEQ    #0,D4             ; reset error counter
UL_XMIT  ADDQ.W   #1,D4             ; increase it with every try
         SUBA.L   A1,A1
         BSR      BLOCKMSG          ; display progress
         BTST     #XM..EOF,D7       ; test EOF flag
         BEQ.S    UL_XMBLK          ; no EOF, send block
         MOVEQ    #EOT,D1
         JSR      TXCHR             ; else, send EOT
         BRA      UL_ACKW           ; and wait for ACK

UL_XMBLK LEA      XMBLKTYP(A6),A1   ; block type (XMODBUF-1)
         MOVE.B   #SOH,(A1)         ; assume 128b block (SOH)
         BTST     #XM..1K,D7
         BEQ.S    UL_SSTRG
         ADDQ.B   #STX-SOH,(A1)     ; 1K block starts with STX
UL_SSTRG MOVEQ    #4,D2             ; SOH/STX + blk# + ~blk# + checksum
         ADD.W    D7,D2             ; add block size + 1 if CRC
         JSR      TXSTR             ; send it
         BRA      UL_ACKW           ; wait for ACK

UL_ABORT LEA      ABORTMSG,A1
         BRA.S    UL_MSG
UL_CAN   BSET     #XM..CAN,D7        ; already got a CAN?
         BEQ      UL_ACKW           ; no, wait for second CAN
         LEA      CANMSG,A1
         BRA.S    UL_MSG
UL_OK    LEA      ULOKMSG,A1
UL_MSG   JSR      PRINTAUX
         BRA.S    UL_EXIT
UL_QUIT  MOVEQ    #CAN,D1
         JSR      TXCHR
UL_EXIT  MOVEQ    #32,D2
         BSR.S    SP_SERJB
         MOVE.L   A5,A0
         MOVE.W   A0,D0
         BMI.S    UL_END
         QDOS     IO.CLOSE
UL_END   MOVE.L   CMDWIN(A6),A0
         MOVE.W   #100,D3
         QDOS     IO.FBYTE
         RTS

SP_SERJB MOVE.L   SERJBID(A6),D1
         TST.W    D1
         BLT.S    SP_1
         QDOS     MT.PRIOR
         RTS
SP_1     MOVE.L   SCRJBID(A6),D1
         QDOS     MT.PRIOR
         TST.B    D2
         IF EQ THEN
            QDOS     MT.RELJB
         ENDIF
         RTS

         SECTION  MSG
ULOKMSG  STRING$  {'Upload OK'}
ABORTMSG STRING$  {'Xmit Timeout - Aborted'}
CANMSG   STRING$  {'Aborted by remote'}
         DC.W     0

         END
