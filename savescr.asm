
        ; Common code for saving the screen.

	; Macro to encode 4 palette entries in a 16-bit file address.

encpal	MACRO
	JSR  getpal
	STA  @1,X
	JSR  getpal
	ASL  A
	ASL  A
	ASL  A
	ORA  @1,X
	STA  @1,X
	JSR  getpal
	ASL  A
	ASL  A
	ASL  A
	ASL  A
	ASL  A
	ASL  A			; most significant bit now in carry.
	ORA  @1,X
	STA  @1,X
	PHP
	JSR  getpal
	PLP
	ROL  A
	STA  @1+2,X		; extra offset because of PHP.
	ENDM

	; Save the screen to a file on disc.

savescr LDA  #&FF
	PHA  
	PHA			; OSFILE, end of data to save.
	LDA  #&80
	PHA  
	LDA  #&00
	PHA  
	LDA  #&FF
	PHA  
	PHA			; OSFILE, start of data to save.
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
        CLC                     ; OSFILE, filename.
        TYA
        ADC  cmdptr
        TAX
        LDA  #&00
        ADC  cmdptr+1
        PHA
        TXA
        PHA
	LDA  #&87		; get current screen mode.
	JSR  OSBYTE
	TYA  
	PHA
	TAX
	LDA  #&85		; get bottom of screen memory.
	JSR  OSBYTE
	TXA  
	TSX  
	STA  &010C,X		; store as the address to save from.
	TYA  
	STA  &010D,X
	LDA  #&00
	STA  zpwork
	encpal &010A
	encpal &0106
	PLA
	ASL  A
	ASL  A
	ASL  A
	ASL  A
	TSX  
	ORA  &0108,X		; into the EXEC address (bits 12-15)
	STA  &0108,X
	LDA  #&00		; get OS version.
	JSR  OSBYTE
	TXA
	TSX			; prepare to save the file.
	INX
	LDY  #&01
	CMP  #&03		; MASTER or later?
	BCS  savemas
	LDA  #&00		; finally, save the file.
	JSR  OSFILE
	JMP  scsdone
savemas master &00
scsdone TSX  
	TXA  
	CLC  
	ADC  #&12
	TAX  
	TXS  
        RTS

	; Get one palette entry.

getpal	LDA  #&0B
	LDX  #zpwork
	LDY  #0
	JSR  OSWORD
	INC  zpwork
	LDA  zpwork+1
	AND  #&07
	TSX  
	RTS  
