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

* ++++++++++++++++++++++++++++++++++++++++
* UNIVERSAL COMMAND STRING ARGUMENT PARSER
* ----------------------------------------

* This code should be called with A1 pointing to the command string,
* and A2 pointing to a data structure containing a list of possible 
* options which can be supplied as command string arguments.

* The format each item in the list is:

*        dc.b     item type
*        dc.b     item character (option letter), or zero
*        dc.w     pointer to additional code (relative to itself)
*        dc.w     offset of variable to set (relative to A6)

* The list is terminated with a dc.w 0

* Item types:

* arg.str equ     <positive value 1-239: maximum length of string value>
arg.true equ      $f0      no values, byte set to true if option specified
arg.byte equ      $f1      byte-sized number should follow
arg.word equ      $f2      word-sized number should follow
arg.long equ      $f3      long-sized number should follow
arg.code equ      $f4      one of a list of option values should follow
arg.conf equ      $f5      take list of option values from a CONFIG CODE item
arg.max  equ      $f5      highest possible item type

* for arg.str, a standard QDOS string will be assigned to the variable
* for arg.code, the pointer to additional code should point to a list of items:

* For each list item:
*        dc.b     value ; value to assign (byte sized)
*        dc.b     'keystroke' ; (not used)
*        dc.w     stringLength,'string' ; string to match (uppercase)
* End of list:
*        dc.w     -1

* Note that this uses the same format as the 'attribute list' of a CONFIG CODE
* item. If there is a CONFIG CODE item in the program, its list of attributes
* may be used as list of option values by defining an item of type arg.conf,
* and specifying the label of the CONFIG item as pointer to additional code.
* Thus:

* cfg.this dc.l     cfg.id   ; config ID (v2)
*          dc.b     4        ; CODE item
*          dc.b     'keystroke'
*          dc.w     cfg.item-* ; configuration byte to set
*          dc.w     prepr-*  ; pre-processing routine
*          dc.w     postpr-* ; post-processing routine
*          dc.w     descr-*  ; description string
*          dc.w     attr-*   ; start of attribute list
* For each attribute list item:
*          dc.b     value    ; code value
*          dc.b     'keystroke'
*          dc.w     stringLength,'string'
* End of list:
*          dc.w     -1
*
*        (or just use the MultiConfig02 macro mkcfitem!)
*
* Then, the option list item would be something like:
*
*          dc.b     arg.conf,'a' ; '-a' option
*          dc.w     cfg.this-*   ; rel pointer to CONFIG item
*          dc.w     THISVAR      ; variable byte to set
*
* The parser will then take the relative pointer attr-* as a pointer to the
* list of option values.
*
* At present, optional arguments on the command string MUST start with a 
* dash '-', and may have only one letter (case is significant!). 
* A space between the option letter and option value is optional 
* (i.e. '-t4' and '-t 4' are treated the same).
* String values containing spaces must be enclosed in quotes, either single
* or double, e.g. -s "This is Fred's argument"
* If an argument on the command string is encountered that doesn't start with a
* dash, it is taken as a positional argument and will match the first item in
* the option list that has its item character set to zero (null). Subsequent
* arguments not starting with a dash will be assigned to the next option with
* a null item character, and so on.
*
* Return values in D0:
*
* - 0 (OK), all arguments processed without error
* - ERR.BP (unknown option specified, may be used to display usage info)
* - ERR.OR (argument's value out of range, e.g. string too long, 
*           number too large, or CODE argument's value not in list).
* In case of error, a message with the offending argument will be printed 
* on channel 0 or 1.
*
* Most other registers will be smashed, except A4, A5 and A6.
*
* Variables will only be set if a corresponding argument has been given.
* You have to fill in default values yourself before calling this routine.
*
* REVISION HISTORY:
*
* 2026-10-28      First version
*

         xdef     argparse

         include  qdos_in_mac
         include  assert_inc

optlist  equ      -4
pos_list equ      -8
arg_ptr  equ      -12
arg_end  equ      -16
stk_size equ      -16

         section  argparse

skipspc  cmp.l    d7,a1
         bcc.s    ss_eol
         cmpi.b   #' ',(a1)+
         beq      skipspc
         subq.l   #1,a1
         moveq    #0,d0
         rts
ss_eol   moveq    #err.ef,d0
         rts

* Entry point is here

argparse link     a5,#stk_size      ; make some room on the stack
         move.l   a2,optlist(a5)    ; save ptr to option list
         move.l   a2,pos_list(a5)   ; also current item in list
         moveq    #0,d7
         move.w   (a1)+,d7          ; length of option string
         beq.s    ap_end            ; nothing to do!
         add.l    a1,d7             ; set d7 to end
                                    
ap_loop  bsr      skipspc           ; skip spaces
         bne.s    ap_end            ; end reached
         move.l   a1,arg_ptr(a5)    ; save item pointer
         move.l   a1,arg_end(a5)    ; initialise to null
         cmpi.b   #'-',(a1)         ; is it an optional item?
         beq.s    ap_opt            ; yes
         move.l   pos_list(a5),a2   ; get current item
ap_poslp move.w   (a2)+,d2          ; next item type + char
         beq.s    ap_iopt           ; end reached?
         tst.b    d2                ; positional item?
         beq.s    ap_ppos           ; yes, process it
         addq.l   #4,a2             ; else, skip
         bra      ap_poslp          ; and loop back

; process positional items

ap_ppos  move.l   a2,pos_list(a5)   ; save current pos
         addq.l   #4,pos_list(a5)   ; update to next item
ap_popt  bsr.s    aprocess          ; process parameter
         beq      ap_loop           ; loop back if OK
         bra.s    ap_rprt

; invalid option specified
         
ap_iopt  move.l   a1,arg_end(a5)
         lea      iopt_msg,a1
         moveq    #err.bp,d0
ap_rprt  move.l   d0,-(sp)          ; save error code
         suba.l   a0,a0             ; report error on #0 or #1
         move.w   ut_mtext,a2
         jsr      (a2)
         assert   arg_end,arg_ptr-4
         movem.l  arg_end(a5),d2/a1 ; retrieve argument start/end
         sub.l    a1,d2             ; length
         qdos     io.sstrg          ; print it
         moveq    #10,d1            ; followed by LF
         qdos     io.sbyte
         move.l   (sp)+,d0          ; restore error code
         bra.s    ap_err

ap_end   moveq    #0,d0             ; end of parsing, no error
ap_err   unlk     a5                ; error exit
         tst.l    d0                ; set ccr according to status
         rts

; process optional items

ap_opt   addq.l   #1,a1             ; step past '-'
         cmp.l    d7,a1             ; check for end
         bcc.s    ap_iopt           ; invalid option
         move.b   (a1)+,d1          ; get option letter
         move.l   optlist(a5),a2    ; option list
ap_optlp move.w   (a2)+,d2          ; next type + char
         beq.s    ap_iopt           ; end of list, invalid option
         cmp.b    d1,d2             ; does it match?
         beq.s    ap_popt           ; yes
         addq.l   #4,a2             ; step to next item
         bra      ap_optlp

; process one option
; entry: d7 end of cmd string
;        a1 current position on cmd string
;        a2 second word of option list entry (additional info)
; exit:  d0 error code or 0
;        a1 pointer to error message if d0 <> 0
;        arg_end(a5) should point to end of current argument

aprocess move.w   2(a2),d6          ; variable offset
         bsr      skipspc
         bne.s    app_ok
         lsr.w    #8,d2             ; get type in lsb
         cmpi.b   #arg.true,d2      ; string argument?
         bcc.s    app_num           ; no, else d2 = max length (1-239)
         moveq    #0,d3             ; counter
         lea      2(a6,d6.w),a0     ; point to start of destination string
         moveq    #' ',d1           ; separator, default=space
         cmpi.b   #'"',(a1)
         beq.s    app_sep
         cmpi.b   #$27,(a1)         ; string argument may be quoted
         bne.s    app_s_lp
app_sep  move.b   (a1)+,d1          ; take single or double quote as separator

app_s_lp cmp.l    d7,a1             ; end of cmd line?
         bcc.s    app_s_en          ; yes
         move.b   (a1)+,d0          ; get next char
         cmp.b    d1,d0             ; is it the separator?
         beq.s    app_s_en          ; yes, done
         addq.b   #1,d3             ; bump length
         cmp.b    d2,d3             ; does it still fit?
         bhi.s    app_s_er          ; no, error exit
         move.b   d0,(a0)+          ; store it
         bra      app_s_lp

app_s_en move.w   d3,(a6,d6.w)      ; end of string, store length
app_ok   moveq    #0,d0             ; OK
         rts
app_s_er move.l   a1,arg_end(a5)    ; set end
         lea      irng_msg,a1       ; message
         moveq    #err.or,d0        ; 'out of range'
         rts

app_num  move.w   d2,d0             ; copy item type
         subi.w   #arg.true,d0      ; take away base
         cmpi.w   #arg.max-arg.true,d0 ; sanity check for type
         bhi      app_ok            ; don't process unknown types
         add.w    d0,d0             ; double the index
         move.w   ttab(pc,d0.w),d0  ; get offset to handler
         jmp      ttab(pc,d0.w)     ; call it

ttab     dc.w     arg_true-ttab     ; true if option present
         dc.w     arg_byte-ttab     ; byte number
         dc.w     arg_word-ttab     ; word number
         dc.w     arg_long-ttab     ; long number
         dc.w     arg_code-ttab     ; list of code items
         dc.w     arg_conf-ttab     ; take code list from CONFIG item

arg_true st       (a6,d6.w)         ; no argument, just set variable to true
         bra      app_ok

arg_byte moveq    #1,d0             ; byte argument
         bra.s    dtoi_l

arg_word moveq    #2,d0             ; word argument
         bra.s    dtoi_l

arg_long moveq    #4,d0             ; longword argument

* Convert decimal number at (a1) and store at (a6,d6.w)
* Entry: D0 size (1 byte, 2 word, 4 long)
* Exit: D0 error code (0 or err.or), value stored at (a0)
*       A1 pointing past number, D1 smashed

dtoi_l   movem.l  d2-d3,-(sp)
         moveq    #0,d1             ; initialise result
         moveq    #0,d2
dtoi_lp  cmp.l    d7,a1             ; end of buffer reached?
         bcc.s    dtoi_end          ; yes, stop
         move.b   (a1),d2           ; check next digit
         subi.b   #'0',d2           ; de-ASCIIfy
         bcs.s    dtoi_end          ; not a digit, so stop
         cmpi.b   #'9',d2           ; test against '9'
         bhi.s    dtoi_end          ; again not a digit, end
         move.l   d1,d3             ; running value
         swap     d3                ; msw first
         mulu     #10,d3            ; multiply msw by base
         swap     d3                ; new msw to bits 16-31
         clr.w    d3                ; discard bits 0-15
         mulu     #10,d1            ; now multiply lsw
         add.l    d3,d1             ; add result from msw
         add.l    d2,d1             ; add digit
         addq.l   #1,a1
         bra      dtoi_lp           ; loop for next
         
dtoi_end lea      (a6,d6.w),a0
         adda.w   d0,a0             ; point past last byte
dtoi_sto move.b   d1,-(a0)          ; fill in bytes
         lsr.l    #8,d1             ; shift next byte to lsb
         subq.w   #1,d0
         bne      dtoi_sto          ; loop for 1, 2 or 4 bytes
         movem.l  (sp)+,d2-d3       ; end; restore regs
         tst.l    d1                ; d1 will be zero if it fitted
         bne      app_s_er          ; else, report error
         bra      app_ok

* Handle CONFIG argument

arg_conf adda.w   (a2),a2
         adda.w   #14,a2            ; just skip to attribute list pointer
                                    ; (no sanity check!)
* Handle code argument

arg_code adda.w   (a2),a2           ; start of list
ac_loop  move.w   (a2)+,d3
         cmpi.w   #-1,d3            ; end reached?
         beq.s    app_c_er          ; yes, bad parameter
         lsr.w    #8,d3             ; get value
         move.w   (a2),d0           ; length of string
         subq.w   #1,d0             ; subtract 1 for dbne
         lea      2(a2),a3          ; point to first char
         move.l   a1,a0             ; a0 runs from a1
ac_comp  cmp.l    d7,a0             ; check end of cmd string
         bcc.s    ac_next           ; no match if already at end
         move.b   (a3)+,d1          ; compare next char
         bsr.s    toupper
         move.b   d1,d2
         move.b   (a0)+,d1
         bsr.s    toupper
         cmp.b    d1,d2
         dbne     d0,ac_comp        ; loop while they match
         beq.s    ac_ckend          ; all done, check end
ac_next  move.w   (a2)+,d0          ; get length of string again
         addq.w   #1,d0             ; make length even
         bclr     #0,d0
         adda.w   d0,a2             ; step to next list item
         bra      ac_loop

ac_ckend cmp.l    d7,a0             ; end of cmd string?
         bcc.s    ac_match          ; yes, full match
         cmpi.b   #' ',(a0)+        ; next char must be whitespace
         bne      ac_next           ; if not, no match
ac_match move.l   a0,a1             ; got a match, advance a1
         move.b   d3,(a6,d6.w)      ; set variable
         moveq    #0,d0             ; signal 'success'
         rts

app_c_er cmp.l    d7,a1
         bcc.s    app_c_en
         cmpi.b   #' ',(a1)+        ; skip to end of argument
         bne      app_c_er
app_c_en bra      app_s_er          ; 'Argument out of range'

toupper  cmpi.b   #'a',d1
         bcs.s    toup_end
         cmpi.b   #'z',d1
         bcc.s    toup_end
         subi.b   #'a'-'A',d1
toup_end rts

iopt_msg string$  {'Unknown option: '}
irng_msg string$  {'Argument out of range: '}

         dc.w     0

         end
         