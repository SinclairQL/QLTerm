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

         xdef     open_def,open_pre,openfile,itod_l,itoo_l,dtoi_l,otoi_l,divlong

         include  ch_inc
         include  io_inc
         include  mt_inc
         include  sv_inc
         include  err_inc

         section  utils

* Open file with optional default directory
* Entry: D3 access key, (A0) filename, A1 ptr to default directory name
* Exit : D0 error code, A0 channel ID if successful, all other regs preserved
* Default directory may be prepended to file name
* Assumes file name buffer is at least 44 bytes!

od_regs  reg      d1-d3/a0-a2
od_d3    equ      2*4               ; original d1 on stack
od_a0    equ      3*4               ; original a0 on stack
od_a1    equ      4*4               ; original a1 on stack

open_def movem.l  od_regs,-(a7)
         moveq    #-1,d1
         moveq    #io.open,d0       ; try opening filename 'as is'
         trap     #2
         tst.l    d0
         beq      of_ok             ; succeeded, exit
         cmpi.l   #err.nf,d0        ; 'not found'?
         bne      of_end            ; exit with other error
         move.l   d0,-(a7)          ; save error code
         moveq    #mt.inf,d0
         trap     #1

; check if file name starts with valid device name

         lea      sv_ddlst(a0),a2   ; start of directory driver list
         move.l   (a7)+,d0          ; restore error code
         move.l   od_a0(a7),a0      ; original file name
         cmpi.w   #5,(a0)           ; must be at least 5 chars
         blt.s    no_drv            ; if not, skip device name test
         cmpi.b   #'_',6(a0)        ; an underscore must follow dev + drive nr
         bne.s    no_drv
         move.l   2(a0),d1          ; get device name
         andi.l   #$dfdfdf00,d1     ; make it uppercase
chk_drv  move.l   (a2),d2           ; next entry in dd list
         beq.s    no_drv            ; end of list
         move.l   d2,a2
         move.l   ch_drnam+2(a2),d2 ; name of device
         andi.l   #$dfdfdf00,d2     ; only test first 3 chars
         cmp.l    d1,d2             ; does it match?
         bne      chk_drv           ; no, try next
         bra.s    of_end            ; valid device name, return error

open_pre movem.l  od_regs,-(a7)     ; entry point for prepending dir at (a1)

; no device specified; let's prepend default dir and try again

no_drv   move.l   od_a1(a7),a1      ; get pointer to default dir
         move.l   (a1),d0           ; d0 points to dir string
         beq.s    of_end            ; no dir, exit...
         move.l   d0,a1
         move.w   (a0),d0           ; length of file name
         move.w   (a1)+,d1          ; length of default dir
         move.w   d0,d2
         add.w    d1,d2             ; form total length in d2
         cmpi.w   #42,d2            ; assume max of 42 (36+5+padding)
         bgt.s    od_badnm          ; reject name if going to be too long
         move.w   d2,(a0)+          ; new length
         lea      (a0,d1.w),a2      ; new position of file name
         bra.s    od_mov1n
od_mov1l move.b   (a0,d0.w),(a2,d0.w) ; move up filename in buffer
od_mov1n dbf      d0,od_mov1l
         bra.s    od_mov2n
od_mov2l move.b   (a1)+,(a0)+       ; prepend default directory
od_mov2n dbf      d1,od_mov2l
         bra.s    of_again          ; retry open with default dir
od_badnm moveq    #err.bn,d0        ; 'bad name' if too long
         bra.s    of_end

* Open channel; D3 access key, A0 channel name
* Exit: D0 error code, A0 channel ID, other regs preserved

openfile movem.l  od_regs,-(a7)
of_again moveq    #-1,d1
         move.l   od_d3(a7),d3      ; get original name and key
         move.l   od_a0(a7),a0
         moveq    #io.open,d0
         trap     #2
         tst.l    d0
         beq.s    of_ok             ; exit if ok
         cmpi.l   #err.ex,d0        ; "already exists"?
         bne.s    of_end            ; exit if not
         cmpi.b   #io.overw,d3      ; return an error if we didn't
         bne.s    of_end            ; request an overwrite
of_delet moveq    #-1,d1            ; this code handles drivers which don't
         move.l   od_a0(a7),a0      ; support overwrite (old mdv etc)
         moveq    #io.delet,d0      ; delete old version
         trap     #2
         bra      of_again          ; loop back to open new
of_ok    move.l   a0,od_a0(a7)      ; return channel ID on exit
of_end   movem.l  (a7)+,od_regs
         tst.l    d0
         rts

* Convert d1.l to octal at (a1) (for Ymodem date)

itoo_l   moveq    #8,d0             ; set base=8
         bra.s    itoa_l
         
* Convert d1.l to decimal at (a1)

itod_l   moveq    #10,d0            ; set base=10

* Convert d1.l to ascii with base given in d0 (8 or 10)

itoa_l   movem.l  d1-d2,-(sp)       ; save regs
         cmp.l    d0,d1             ; have we got to the last digit?
         bcs.s    itoa_2            ; yes, store digit and exit
         bsr.s    divlong           ; divide by base
         bsr      itoa_l            ; handle all digits recursively
         move.b   d2,d1             ; remainder = digit
itoa_2   addi.b   #'0',d1           ; ASCIIfy
         move.b   d1,(a1)+          ; and store
         movem.l  (sp)+,d1-d2       ; restore regs
         rts

* Divide D1.L by D0.W, remainder in D2.W

divlong  moveq    #0,d2             ; prepare for division
         swap     d1
         move.w   d1,d2             ; msw to d2
         divu     d0,d2             ; divide msw
         move.w   d2,d1             ; quotient msw back to d1
         swap     d1                ; quotient msw ready
         move.w   d1,d2             ; remainder 1st div in msw & original lsw
         divu     d0,d2             ; divide again
         move.w   d2,d1             ; form complete result in d1
         swap     d2                ; now d2 holds remainder in lsw
         rts

* Convert octal at (a1) to d1.l

otoi_l   moveq    #8,d0
         bra.s    atoi_l

* Convert decimal at (a1) to d1.l

dtoi_l   moveq    #10,d0

atoi_l   movem.l  d2-d3,-(sp)
         moveq    #0,d1             ; initialise result
         moveq    #0,d2
atoi_lp  move.b   (a1),d2           ; check first digit
         subi.b   #'0',d2           ; de-ASCIIfy
         bcs.s    atoi_end          ; not a digit, so stop
         cmp.b    d0,d2             ; now compare against base (8 or 10)
         bcc.s    atoi_end          ; again not a digit, end
         move.l   d1,d3             ; running value
         swap     d3                ; msw first
         mulu     d0,d3             ; multiply msw by base
         swap     d3                ; new msw to bits 16-31
         clr.w    d3                ; discard bits 0-15
         mulu     d0,d1             ; now multiply lsw
         add.l    d3,d1             ; add result from msw
         add.l    d2,d1             ; add digit
         addq.l   #1,a1
         bra      atoi_lp           ; loop for next
         
atoi_end movem.l  (sp)+,d2-d3       ; end; restore regs
         rts
         
         end