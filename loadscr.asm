
	; Macro to set the palette entries in one 16-bit file address.

decpal	MACRO
	LDA  @1,X
	JSR  setpal
	LDA  @2,X
	LSR  A
	LSR  A
	LSR  A
	JSR  setpal
	LDA  @2+1,X
	LSR  A
	LDA  @2,X
        ROR  A
        LSR  A
        LSR  A
        LSR  A
        LSR  A
        LSR  A
	JSR  setpal
	LDA  @2+1,X
	LSR  A
	JSR  setpal
	ENDM

        LDA  #&FF
	PHA			; OSFILE, file attributes.
	PHA
	PHA
	PHA
	PHA			; OSFILE, length.
	PHA
	PHA
	PHA
	PHA			; OSFILE, exec address.
	PHA
	PHA
	PHA
	PHA			; OSFILE, load address.
	PHA
	PHA
	PHA
        CLC                     ; OSFILE, filename.
        TYA
        ADC  cmdptr
        TAX
        LDA  #&00
        ADC  cmdptr+1
        PHA
        TXA
        PHA
	LDA  #&05		; OSFILE, get attributes.
	TSX  
	INX  
	LDY  #&01
	JSR  OSFILE
	CMP  #&01		; Is it a file?
	BEQ  isfile
	TAX
	BEQ  notfnd
	error &B5,"Not a file"
notfnd	error &D6,"File not found"
isfile	LDA  #&87		; Get the current screen mode.
	JSR  OSBYTE
	TSX
	LDA  &0108,X		; Get mode from EXEC address.
	LSR  A
	LSR  A
	LSR  A
	LSR  A
	STA  zpwork
	CPY  zpwork		; Already in the right mode?
	BEQ  modeok
	LDA  #&16		; Change to required mode.
	JSR  OSWRCH
	LDA  zpwork
	JSR  OSWRCH
modeok	PHA
	LDA  #&00
	STA  zpwork
	STA  zpwork+2
	STA  zpwork+3
	STA  zpwork+4
	decpal &0107,&010A
	decpal &0106,&0106
	PLA
	TAX
	LDA  #&85		; Get HIMEM for given mode.
	JSR  OSBYTE
	TXA
	TSX
	STA  &0103,X
	TYA
	STA  &0104,X
	LDA  #&00
	STA  &0107,X
	LDA  #&00		; get OS version
	JSR  OSBYTE
	TXA
	LDA  #&FF		; prepare to load file.
	TSX
	INX
	LDY  #&01
	CMP  #&03		; is it a MASTER or later?
	BCS  loadmas
	JSR  OSFILE
	JMP  scldone
loadmas master &FF
scldone TSX  
	TXA  
	CLC  
	ADC  #&12
	TAX  
	TXS  
	RTS  

	; Set one palette entry.

setpal	AND  #&07
	STA  zpwork+1		; physical colour number.
	LDA  #&0C
	LDX  #zpwork		; set the logical colour as-is.
	LDY  #0
	JSR  OSWORD
	LDA  zpwork
	ORA  #&08		; add 8 to logical colour.
	STA  zpwork
	LDA  #&0C		; set that one too.
	LDX  #zpwork
	LDY  #0
	JSR  OSWORD
	LDA  zpwork
	AND  #&07		; remove the 8 again.
	STA  zpwork
	INC  zpwork		; on to the next colour.
	TSX  
	RTS
