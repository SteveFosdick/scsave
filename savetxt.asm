
        DSECT
        ORG  &A8
file    DS   1
left    DS   1
bottom  DS   1
right   DS   1
top     DS   1
last    DS   1
mode    EQU  last
col     DS   1
flag    DS   1
        DEND

        DSECT
        ORG  &A9
tab     DS   1
pcol    DS   1
owblk   DS   5
        DEND

        ; Common code to save the screen as text.

savetxt LDA  #&00               ; Clear palette flag.
        STA  flag
        LDA  (cmdptr),Y
        IF   palopt
        CMP  #'-'
        BNE  notopt
        INY
        LDA  (cmdptr),Y
        CMP  #'P'
        BEQ  gotpal
        error &CB,"Bad option"
gotpal  LDA  #&80               ; Record the palette flag.
        STA  flag
palspc  INY                     ; Skip spaces after the option.
        LDA  (cmdptr),Y
        CMP  #' '
        BEQ  palspc
        CMP  #&0D               ; Check there is a filename after option.
        BEQ  missfn
        FI
notopt  CLC                     ; Get filename address into X,Y
        TYA
        ADC  cmdptr
        TAX
        LDA  #&00
        ADC  cmdptr+1
        TAY
        LDA  #&80               ; Open the file for writing.
        JSR  OSFIND
        CMP  #&00
        BNE  isopen
        error &D6,"Unable to open file"
isopen  STA  file
        LDA  #&86               ; Get the current cursor position.
        JSR  OSBYTE
        TYA                     ; Save cursor position on stack.
        PHA
        TXA
        PHA
        LDA  #&A0               ; Read text window left and bottom.
        LDX  #&08
        JSR  OSBYTE
        STX  left
        STY  bottom
        LDA  #&A0               ; Read text window right and top.
        LDX  #&0A
        JSR  OSBYTE
        STX  right
        STY  top
        LDA  #&87               ; Get the current mode.
        JSR  OSBYTE
        TYA
        AND  #&07               ; Remove any shadow bit.
        STA  mode
        LDA  left               ; Is the default window smaller than the
        BNE  window             ; whole screen?
        LDA  top
        BNE  window
        LDA  right
        CMP  lastx,Y
        BNE  window
        LDA  bottom
        CMP  lasty,Y
        BEQ  defwin
window  LDA  flag               ; Note the smaller window in the flags.
        ORA  #&40
        STA  flag
        LDA  top                ; Save the text window to restore later.
        PHA
        LDA  right
        PHA
        LDA  bottom
        PHA
        LDA  left
        PHA
        LDA  #&1C               ; Reset the window to the whole screen.
        JSR  OSWRCH
        LDA  #&00
        JSR  OSWRCH
        LDA  lasty,Y
        JSR  OSWRCH
        LDA  lastx,Y
        JSR  OSWRCH
        LDA  #&00
        JSR  OSWRCH
defwin  IF   palopt
        LDA  flag               ; Save the mode and palette?
        BMI  savepal
        JMP  nopal
savepal LDA  #&16               ; VDU mode command to file.
        LDY  file
        JSR  OSBPUT
        LDA  mode
        JSR  OSBPUT
nswin   LDA  flag
        PHA
        LDA  mode
        CMP  #&07
        BCS  mode7
        PHA
        TAX
        LDA  modetab,X          ; Get the table of default colours
        STA  tab                ; for the current mode.
        LDA  #&00
        STA  owblk              ; Start with logical colour 0.
palloop LDX  tab
        LDA  modetab,X          ; Get the default physical colour
        BMI  paldone            ; End of physical colour table?
        STA  pcol
        LDA  #&0B               ; Get the current physical colour.
        LDX  #>owblk
        LDY  #<owblk
        JSR  OSWORD
        LDA  owblk+1            ; Is the current colour the default?
        CMP  pcol
        BEQ  samecol
        LDA  #&13               ; VDU code to set palette entry.
        LDY  file
        JSR  OSBPUT
        LDA  owblk              ; Logical colour to file.
        JSR  OSBPUT
        LDA  owblk+1            ; Physical colour to file.
        JSR  OSBPUT
        LDA  #&00               ; Trailing (for exansion) zeros.
        JSR  OSBPUT
        JSR  OSBPUT
        JSR  OSBPUT
samecol INC  tab                ; Move on to next logical colour.
        INC  owblk
        BNE  palloop
paldone PLA
        STA  mode
mode7   PLA
        STA  flag
        FI

nopal   LDX  mode
        LDA  lastx,X
        STA  right
        LDA  lasty,X
        STA  bottom
        TAX
botloop JSR  lastcol            ; Find the last column used.
        BNE  botfnd             ; Branch if characters in line.
        DEC  bottom             ; Move up a line.
        LDX  bottom
        BNE  botloop
        BEQ  empty              ; Got to the top with no characters.
botfnd  LDX  #&00
        STX  top
rowloop JSR  lastcol
        BEQ  rowend
        LDA  #&00
        STA  col
        LDA  #&0D               ; go to the start of the line.
colloop JSR  OSWRCH
        LDA  #&87               ; read character at cursor position.
        JSR  OSBYTE
        TXA
        LDY  file
        JSR  OSBPUT             ; write it to the file.
        LDA  col
        CMP  last
        BCS  rowend
        INC  col
        LDA  #&09               ; move forward one character
        BNE  colloop
rowend  LDA  #&0D
        LDY  file
        JSR  OSBPUT
        BIT  flag               ; For palette file, we also send LF.
        BPL  skiplf
        LDA  #&0A
        JSR  OSBPUT
skiplf  INC  top
        LDX  top
        CPX  bottom
        BCC  rowloop
        BEQ  rowloop
empty   BIT  flag
        BVC  norest             ; No need to restore text window.
        LDA  #&1C
        LDX  #&04
        IF   palopt
        BIT  flag
        BPL  noput1
        JSR  OSBPUT
noput1  JSR  OSWRCH
winlp   PLA
        BIT  flag
        BPL  noput2
        JSR  OSBPUT
noput2  JSR  OSWRCH
        DEX
        BNE  winlp
        ELSE
        JSR  OSWRCH
winlp   PLA
        JSR  OSWRCH
        DEX
        BNE  winlp
        FI
norest  LDA  #&00               ; Close the file.
        LDY  file
        JSR  OSFIND
        LDA  #&1F               ; Restore the cursor position.
        JSR  OSWRCH
        PLA
        JSR  OSWRCH
        PLA
        JMP  OSWRCH

lastcol LDA  #&1F               ; VDU code for go to X,Y
        JSR  OSWRCH
        LDA  right
        JSR  OSWRCH
        TXA
        JSR  OSWRCH
        LDA  right
        STA  last
rtloop  LDA  #&87               ; read character at cursor position.
        JSR  OSBYTE
        TXA
        BEQ  notend             ; unrecognised character.
        CMP  #' '
        BEQ  notend             ; not space, found the end of the text.
gotlast RTS
notend  DEC  last
        LDA  last
        BEQ  gotlast            ; reached the left with no useful characters.
        LDA  #&08
        JSR  OSWRCH             ; move left one character.
        JMP  rtloop

lastx   DFB  79,39,19,79,39,19,39,39
lasty   DFB  31,31,31,24,31,31,24,24
modetab DFB  two-modetab,four-modetab,sixteen-modetab,two-modetab
        DFB  two-modetab,four-modetab,two-modetab
two     DFB  0,7,&FF
four    DFB  0,1,3,7,&FF
sixteen DFB  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,&FF
