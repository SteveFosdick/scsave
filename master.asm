master	MACRO
	LDA  ACCCON		; get state of shadow screen.
	PHA
	BIT  #&01		; is shadow bank displayed?
	BEQ  ns@0
	ORA  #&04		; select the shadow bank for OSFILE to read.
	STA  ACCCON
ns@0	LDA  #@1		; transfer the file.
	JSR  OSFILE
	PLA			; put shadow RAM back as before.
	STA  ACCCON
	ENDM
