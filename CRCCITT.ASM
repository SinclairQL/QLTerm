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

* Table of 16-bit CRC-CCITT values

         XDEF     CRC_TBL

         SECTION  CODE

CRC_TBL  DC.W     $0000,$1021,$2042,$3063,$4084,$50A5,$60C6,$70E7
         DC.W     $8108,$9129,$A14A,$B16B,$C18C,$D1AD,$E1CE,$F1EF
         DC.W     $1231,$0210,$3273,$2252,$52B5,$4294,$72F7,$62D6
         DC.W     $9339,$8318,$B37B,$A35A,$D3BD,$C39C,$F3FF,$E3DE
         DC.W     $2462,$3443,$0420,$1401,$64E6,$74C7,$44A4,$5485
         DC.W     $A56A,$B54B,$8528,$9509,$E5EE,$F5CF,$C5AC,$D58D
         DC.W     $3653,$2672,$1611,$0630,$76D7,$66F6,$5695,$46B4
         DC.W     $B75B,$A77A,$9719,$8738,$F7DF,$E7FE,$D79D,$C7BC
         DC.W     $48C4,$58E5,$6886,$78A7,$0840,$1861,$2802,$3823
         DC.W     $C9CC,$D9ED,$E98E,$F9AF,$8948,$9969,$A90A,$B92B
         DC.W     $5AF5,$4AD4,$7AB7,$6A96,$1A71,$0A50,$3A33,$2A12
         DC.W     $DBFD,$CBDC,$FBBF,$EB9E,$9B79,$8B58,$BB3B,$AB1A
         DC.W     $6CA6,$7C87,$4CE4,$5CC5,$2C22,$3C03,$0C60,$1C41
         DC.W     $EDAE,$FD8F,$CDEC,$DDCD,$AD2A,$BD0B,$8D68,$9D49
         DC.W     $7E97,$6EB6,$5ED5,$4EF4,$3E13,$2E32,$1E51,$0E70
         DC.W     $FF9F,$EFBE,$DFDD,$CFFC,$BF1B,$AF3A,$9F59,$8F78
         DC.W     $9188,$81A9,$B1CA,$A1EB,$D10C,$C12D,$F14E,$E16F
         DC.W     $1080,$00A1,$30C2,$20E3,$5004,$4025,$7046,$6067
         DC.W     $83B9,$9398,$A3FB,$B3DA,$C33D,$D31C,$E37F,$F35E
         DC.W     $02B1,$1290,$22F3,$32D2,$4235,$5214,$6277,$7256
         DC.W     $B5EA,$A5CB,$95A8,$8589,$F56E,$E54F,$D52C,$C50D
         DC.W     $34E2,$24C3,$14A0,$0481,$7466,$6447,$5424,$4405
         DC.W     $A7DB,$B7FA,$8799,$97B8,$E75F,$F77E,$C71D,$D73C
         DC.W     $26D3,$36F2,$0691,$16B0,$6657,$7676,$4615,$5634
         DC.W     $D94C,$C96D,$F90E,$E92F,$99C8,$89E9,$B98A,$A9AB
         DC.W     $5844,$4865,$7806,$6827,$18C0,$08E1,$3882,$28A3
         DC.W     $CB7D,$DB5C,$EB3F,$FB1E,$8BF9,$9BD8,$ABBB,$BB9A
         DC.W     $4A75,$5A54,$6A37,$7A16,$0AF1,$1AD0,$2AB3,$3A92
         DC.W     $FD2E,$ED0F,$DD6C,$CD4D,$BDAA,$AD8B,$9DE8,$8DC9
         DC.W     $7C26,$6C07,$5C64,$4C45,$3CA2,$2C83,$1CE0,$0CC1
         DC.W     $EF1F,$FF3E,$CF5D,$DF7C,$AF9B,$BFBA,$8FD9,$9FF8
         DC.W     $6E17,$7E36,$4E55,$5E74,$2E93,$3EB2,$0ED1,$1EF0

         END         