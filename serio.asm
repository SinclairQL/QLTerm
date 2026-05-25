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

* Serial/IP input/output routines

         include  qdos_in_mac
         include  qlterm_in
         include  assert_inc

         xdef     rxchar,txstr,txchr,txchr_a,put_rxq,serjob,pause4,t_wait
         
         section  code

* Fetch byte from channel, taking Telnet commands into account
* Entry: D3 timeout (always uses input comms channel)
* Exit:  D0 error code, but 1 if timeout (NC). CCR set to suit.
*        D1 character got, A0 input channel ID, D2/A1 smashed.

rxchar:  move.l   tserin(a6),a0
         move.w   a0,d0
         bmi.s    rxc_eof
rxc_1    qdos     io.fbyte          ; fetch a byte
         tst.l    d0
         bne.s    rxc_rts           ; error return
         cmpi.b   #P_TELNET,port(a6) ; Observing IACs?
         bne.s    rxc_ret0          ; no, return
         tst.b    got_iac(a6)       ; previous char was IAC?
         bne.s    rxc_cmd           ; yes, go process command
         cmpi.b   #IAC,d1           ; current is IAC?
         bne.s    rxc_ret0          ; no, skip
         st       got_iac(a6)       ; signal 'got IAC'
         sf       got_cmd(a6)       ; clear command byte
         bra.s    rxc_1             ; loop back
rxc_eof  moveq    #err.ef,d0
rxc_rts  addq.l   #-err.nc,d0
         beq.s    rxc_nc            ; check for 'not complete'
         subq.l   #-err.nc,d0       ; restore error code + flags
         rts
rxc_nc   moveq    #1,d0             ; signal 'not complete' by +ve status
         rts

; character is other than IAC

rxc_ret0 sf       got_iac(a6)       ; return from escaped IAC; cancel flag
         moveq    #0,d0
         rts                        ; return

; Previous character was IAC, now consider command

rxc_cmd  move.b   got_cmd(a6),d2    ; got command byte already?
         bne.s    rxc_opt           ; yes, consider option
         cmpi.b   #IAC,d1           ; current char is IAC escape?
         beq.s    rxc_ret0          ; yes, clear flag and return escaped IAC char
         cmpi.b   #T_SE,d1          ; suboption end
         beq      rxc_se
         cmpi.b   #T_SB,d1          ; command is SB/WILL/WONT/DO/DONT?
         bcs.s    rxc_clr           ; no, eat it
         move.b   d1,got_cmd(a6)    ; else, store it
         bra      rxc_1             ; loop back for next
rxc_clr  sf       got_iac(a6)       ; clear flag
         bra      rxc_1             ; and loop back

; consider Telnet command (either SB, WILL or DO, drop other commands)
; for BINARY, ECHO and Suppress Go-Ahead options confirm WILL with DO v.v.
; for other options refuse them (answer WILL with DONT and DO with WONT)

rxc_opt  cmpi.b   #T_SB,d2          ; suboption begin
         beq      rxc_subopt        ; handle suboption
         cmpi.b   #T_WILL,d2
         beq.s    rxc_opt2
         cmpi.b   #T_DO,d2
         bne.s    rxc_clr           ; ignore other than WILL or DO
rxc_opt2 cmpi.b   #T_BINARY,d1
         beq.s    rxc_conf
         cmpi.b   #T_SUPGA,d1
         beq.s    rxc_conf          ; confirm BINARY and SUPGA
         cmpi.b   #T_TERM,d1
         beq.s    rxc_conf          ; confirm Terminal Type
         cmpi.b   #T_NAWS,d1
         beq.s    rxc_naws          ; confirm NAWS
         cmpi.b   #T_ECHO,d1
         bne.s    rxc_deny
         cmpi.b   #T_DO,d2          ; for ECHO, only confirm DO (terminals shouldn't echo!)
         beq.s    rxc_deny
rxc_conf ext.w    d1                ; make D1 word-sized
;         tst.b    conf_var(a6,d1.w) ; Have we already confirmed this option?
;         bne.s    rxc_clr           ; yes, stay silent
;         st       conf_var(a6,d1.w) ; else, set flag
         eori.b   #%00000110,d2     ; flipping bits 1 and 2 flips WILL/DO - clever!
         bra.s    rxc_send

rxc_deny ext.w    d2                ; extend D2.W to -5 for WILL or -3 for DO
         addq.w   #$100-T_WILL,d2   ; D2 is now 0 for WILL and 2 for DO
         move.b   rxc_otab(pc,d2.w),d2 ; get DONT or WONT for WILL and DO

rxc_send move.l   a7,a1
         subq.l   #4,a7             ; make room on stack for 4 chars (actually 3)
         move.b   d1,-(a1)          ; The option itself
         move.b   d2,-(a1)          ; WILL/DO/WONT/DONT as appropriate
         move.b   #IAC,-(a1)        ; IAC char
         moveq    #3,d2
         bsr.s    rxc_sstr          ; send it
         addq.l   #4,a7             ; tidy stack
         bra      rxc_clr

rxc_otab dc.b     T_DONT,0,T_WONT,0

; Negotiate window size

rxc_naws move.l   a7,a1
         suba.w   #10,a7            ; 9 bytes to send + padding
         move.w   #IAC<<8+T_SE,-(a1) ; suboption end
;         move.w   win_rows(a6),-(a1) ; window height
         move.l   win_cols(a6),-(a1) ; window width + height
         move.w   #T_SB<<8+T_NAWS,-(a1) ; suboption start + NAWS
         move.b   #IAC,-(a1)
         moveq    #9,d2             ; 9 bytes to send
         bsr.s    rxc_sstr
         adda.w   #10,a7
         bra      rxc_clr           ; clear flag and loop back
         
rxc_sstr movem.l  d3/a0,-(a7)       ; save timeout and channel
         moveq    #-1,d3            ; ensure it gets sent
         move.l   tserout(a6),a0    ; get output channel (may be different)
         qdos     io.sstrg          ; send string
         movem.l  (a7)+,d3/a0       ; restore original timeout & channel
         rts

; consider suboption (code is in d1)

rxc_subopt
         move.b   got_sub(a6),d2    ; suboption code or 0
         bne.s    rxc_stst          ; already got code
         move.b   d1,got_sub(a6)    ; store code
         bra      rxc_1             ; and loop back

rxc_stst move.b   d1,sub_oper(a6)   ; store operator
         bra      rxc_clr           ; cancel IAC status

; got suboption end

rxc_se   move.b   got_sub(a6),d2    ; subnegotiation code
         sf       got_sub(a6)       ; and clear it
         cmpi.b   #T_TERM,d2        ; only send terminal type
         bne      rxc_clr
         cmpi.b   #1,sub_oper(a6)   ; operator is 'send'?
         bne      rxc_clr           ; no, do nothing
         moveq    #0,d1
         move.b   scrmod(a6),d1     ; terminal mode - 1
         addq.b   #1,d1
         add.w    d1,d1             ; double
         move.w   rxc_ttab(pc,d1.w),d1 ; get offset
         lea      rxc_ttab(pc,d1.w),a1 ; string to send
         move.w   (a1)+,d2
         bsr      rxc_sstr          ; send string
         bra      rxc_clr           ; and continue

rxc_ttab dc.w     t_ascii-rxc_ttab
         dc.w     t_vt52-rxc_ttab
         dc.w     t_ansi-rxc_ttab
t_ascii  string$  {IAC,T_SB,T_TERM,0,'ASCII',IAC,T_SE}
t_vt52   string$  {IAC,T_SB,T_TERM,0,'VT52',IAC,T_SE}
t_ansi   string$  {IAC,T_SB,T_TERM,0,'ANSI',IAC,T_SE}

* Send string: A1 pointer, D2 length

; Send a string
; We'll scan it for IAC first so we can send it as a string up to the IAC char

txstr:   movem.l  d1-d3/a0-a3,-(a7)
         tst.b    echomod(a6)
         bgt.s    txs_loc           .. 'local only' mode
         move.l   tserout(a6),a0
         move.w   a0,d0             ; valid channel?
         bmi.s    txs_rts           ; no, return
txs_1    tas      txbusy(a6)        ; set txbusy flag
         beq.s    txs_go
         bsr      pause4            ; wait 80 ms
         bra      txs_1
txs_go   moveq    #-1,d3            ; send whole string
         cmpi.b   #P_TELNET,port(a6) ; using Telnet protocol?
         bne.s    txs_out           ; no, no IACs to observe
txs_agn  move.w   d2,d0             ; initial length
         move.l   a1,a2             ; start of string
iac_loop subq.w   #1,d0             ; decrement
         blt.s    txs_out           ; end reached
         cmpi.b   #IAC,(a2)+        ; test for IAC
         bne      iac_loop          ; loop unless found
         move.w   d2,-(a7)          ; save length
         move.l   a2,d2
         sub.l    a1,d2             ; get length of string up to and including IAC
         sub.w    d2,(a7)           ; subtract from initial length
         subq.w   #1,d2             ; length before IAC
         ble.s    sps_rest          ; do not print a null string
         qdos     io.sstrg          ; send string
sps_rest moveq    #IAC,d1
         bsr      txsub             ; followed by double IAC
         move.l   a2,a1             ; step past IAC
         move.w   (a7)+,d2          ; restore remaining length
         bgt.s    txs_agn           ; loop back for any remaining part
txs_out  qdos     io.sstrg          ; now send it
;         tst.l    d0                ; ok?
;         beq.s    txs_echo          ; yes, check echo
;         cmpi.l   #err.nc,d0        ; 'not complete'?
;         bne.s    txs_rts           ; no, other error
;         bsr      pause4            ; wait 80 ms
;         sub.w    d1,d2             ; discount bytes sent
;         bra      txs_go            ; and repeat
txs_echo sf       txbusy(a6)        ; clear flag
         tst.b    echomod(a6)
         blt.s    txs_rts           ; done if no local echo to do
         move.l   1*4(a7),d2        ; restore original d2
         move.l   4*4(a7),a1        ; restore original a1
txs_loc  trap     #0                ; don't allow serjob to write to buffer
         move.l   rxq_base(a6),a2   ; base of queue header
         move.l   q_nextin(a6),a3   ; head of queue
txs_llp  subq.w   #1,d2             ; discount one char
         blt.s    txs_end           ; exit if done
         move.b   (a1)+,(a3)+       ; copy char
         cmpa.l   q_end(a2),a3      ; have we reached top?
         bcs.s    txs_llp           ; no, continue
         lea      q_queue(a2),a3    ; else, go back to base
         bra      txs_llp

txs_end  move.l   a3,q_nextin(a2)   ; set new head of queue
         andi.w   #$dfff,sr         ; back to user mode
txs_rts  movem.l  (a7)+,d1-d3/a0-a3
         tst.l    d0
         rts

* transmit a character, taking care of echo status

txchr:   moveq    #-1,d3
         tst.b    echomod(a6)
         blt.s    txchr_a           jump if echo off
         bsr.s    put_rxq           otherwise, put char in terminal queue
         tst.b    echomod(a6)
         beq.s    txchr_a           finished if 'local only', else xmit char
         rts

* put character in receive queue to be picked up by screen job

put_rxq: movem.l  d1/a1-a2,-(a7)
         trap     #0
         move.l   rxq_base(a6),a2
         move.l   q_nextin(a2),a1
         move.b   d1,(a1)+
         cmpa.l   q_end(a2),a1
         bcs.s    putrxq_2
         lea      q_queue(a2),a1
putrxq_2 move.l   a1,q_nextin(a2)
         andi.w   #$dfff,sr
         movem.l  (a7)+,d1/a1-a2
         rts

* transmit character in d1, taking care of all transmit modes
* on entry, d3 holds timeout - nonzero for 'wait until complete'

txchr_a  movem.l  d1-d3/a0-a3,-(a7)
         tst.w    tserout+2(a6)     ; valid transmit channel?
         bmi.s    txchr_nc          ; no, return nc
txchr_1  tas      txbusy(a6)        ; set txbusy flag
         beq.s    txchr_2           ; if it was clear, go ahead
         tst.b    11(a7)            ; test timeout
         beq.s    txchr_nc          ; return nc unless nonzero
         bsr.s    pause4            ; pause for 80 ms
         bra      txchr_1           ; loop back
txchr_2  move.l   tserout(a6),a0    ; get output channel
;         bsr      setpar            ; handle parity
         bsr.s    txsub             ; send it
         sf       txbusy(a6)        ; clear busy flag
         moveq    #0,d0             ; return ok
         bra.s    txchrend
txchr_nc moveq    #err.nc,d0
txchrend movem.l  (a7)+,d1-d3/a0-a3
         tst.l    d0
         rts

* wait 4 frames (80 ms)

pause4   moveq    #4,d3
t_wait   movem.l  d1/a0-a1,-(a7)
         moveq    #-1,d1
         suba.l   a1,a1
         qdos     mt.susjb
         movem.l  (a7)+,d1/a0-a1
         rts

* subroutine to transmit char

txsub    cmpi.b   #P_TELNET,port(a6) ; using Telnet?
         bne.s    txsub_3           ; no, skip
         cmpi.b   #IAC,d1           ; sending IAC?
         bne.s    txsub_3
         bsr.s    txsub_3           ; send IAC twice to escape
         bra.s    txsub_3
txsub_2  bsr      pause4            ; if 'not complete', wait 80 ms and try again
txsub_3  moveq    #0,d3             ; use zero timeout, do not block channel
         move.b   d1,d2             ; save byte for later
         qdos     io.sbyte
         move.b   d2,d1
         addq.l   #-err.nc,d0       ; 'not complete'?
         beq.s    txsub_2           ; yes, loop
         subq.l   #-err.nc,d0       ; restore error code
         rts

* Serial input job
* This job continually reads the input port and puts the data into the buffer
* (Which is rather needed for the standard SER ports as their buffering sucks)
* Also handles XON/XOFF handshake

serjob:  move.l   rxq_base(a6),a2       ; base of queue
         bra.s    serjb_2
         dc.w     $4afb
         string$  {'QLTerm I/O handler'}

serjb_2  move.l   #$7fff,d7             ; maximum for io.fstrg
         move.l   a2,d0                 ; is there really a queue?
         bne.s    serjb_lp              ; OK
         moveq    #-1,d1                ; oops! no queue!
         moveq    #err.om,d3
         qdos     mt.frjob              ; so commit suicide...
         
; main loop
         
serjb_lp moveq    #0,d4                 ; nothing got yet
         move.l   tserin(a6),a0         ; serial input channel
         move.w   a0,d0                 ; valid channel?
         bmi      serjb_wt              ; no, don't waste time on it
         cmpi.b   #P_TELNET,port(a6)    ; using Telnet?
         bne.s    sj_ser                ; no, use string I/O

; Telnet is non-transparent, we have to get it from the port byte by byte :(

         move.w   io_qtest,a3
         jsr      (a3)                  ; get free space in D2

sj_rxchr subq.l   #1,d2                 ; check if there is room
         ble.s    sj_wait               ; if not, wait and loop back
         moveq    #0,d3                 ; only poll
         bsr      rxc_1                 ; already checked channel validity
         bne.s    sj_wait
         move.w   io_qin,a3
         jsr      (a3)                  ; put byte into queue
         addq.l   #1,d4
         bra      sj_rxchr              ; loop back

; Non-Telnet, we assume input channel is transparent so we can use string I/O
; Note that we enter supervisor mode here, because the display job may have
; updated q_nxtout in between. Also check free queue space and send XON/XOFF
; if necessary

sj_ser:   
;        trap     #0                    ; enter supervisor mode
         move.l   q_nextin(a2),a1        ; first free location in queue
sj_lp2   move.l   q_end(a2),d2
         sub.l    a1,d2                 ; get space between q_nextin and q_end
         bgt.s    sj_getsp              ; should not fetch beyond end of queue!
         lea      q_queue(a2),a1        ; wrap back to start
sj_getsp move.l   q_nxtout(a2),d1
         sub.l    a1,d1                 ; check against q_nxtout
         ble.s    sj_fetch              ; q_nextin is above q_nxtout, OK
         move.l   d1,d2                 ; available space is now nxtout-nxtin
         subq.l   #1,d2                 ; but avoid bumping into nxtout
         ble.s    sj_wait               ; no room in queue, wait
sj_fetch cmp.l    d7,d2                 ; test against $7fff
         bls.s    sj_lp2
         move.l   d7,d2                 ; io.fstrg cannot handle more
sj_fstr  moveq    #0,d3                 ; .. in one try
         qdos     io.fstrg              ; get string, at most d2 bytes
         and.w    d7,d1                 ; ensure msw of d1 is zero
         add.l    d1,d4                 ; add to total
         tst.l    d0                    ; can we fetch more?
         beq      sj_lp2                ; yes, loop back
         move.l   a1,q_nextin(a2)        ; set new q_nextin

sj_wait  tst.l    d4                    ; have we got any bytes?
         beq.s    serjb_er              ; no, check for eof
         move.l   q_nextin(a2),a1        ; new q_nextin
         suba.l   q_nxtout(a2),a1       ; find nxtin-nxtout, possibly wrapped
;         andi     #$dfff,sr             ; back to user mode
         moveq    #-q_queue,d2
         add.l    q_end(a2),d2
         sub.l    a2,d2                 ; get queue length excl. header
         move.l   a1,d1                 ; # of bytes in queue, possibly wrapped
         beq.s    serjb_wt              ; nothing in queue, wait for next loop
         bpl.s    sj_pos                ; was head-tail positive?
         add.l    d2,d1                 ; no, wrapped so add queue size
sj_pos   lsr.l    #1,d2                 ; divide queue size by 2
         move.l   d2,d0
         lsr.l    #1,d0
         add.l    d2,d0                 ; form (queue size)*3/4 in d0
         cmp.l    d0,d1                 ; is queue filled for > 75%?
         blt.s    serjb_wt              ; no, skip
         tst.b    xoffmod(a6)           ; xoff already sent?
         bne.s    serjb_wt              ; yes, don't hammer with xoffs
         moveq    #xoff,d1
         jsr      txchr_a               ; else, send it!
         bne.s    serjb_wt              ; sent successfully?
         st       xoffmod(a6)           ; yes, set flag
         bra.s    serjb_wt
serjb_er addq.l   #1,d0                 ; was input status 'not complete'?
         bge.s    serjb_wt              ; yes, sleep 1/50th second
         cmpi.l   #err.ef+1,d0          ; check for eof
         bne.s    serjb_wt
         tas      in_eof(a6)            ; if eof, set flag
serjb_wt moveq    #1,d3
         bsr      t_wait                ; sleep 1/50th second
         bra      serjb_lp

         end
