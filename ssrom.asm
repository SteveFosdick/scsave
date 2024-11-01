	PAGE 66,132
	ORG  &8000

        INCLUDE bbcmicro.asm

zpwork  EQU  &A8
cmdptr  EQU  &F2

	; ROM Header

romst	DFB  0
	DFW  reloc
	JMP  serv
	DFB  %10000010
	DFB  copyr-romst
	DFB  &00
	ASC  "Disc Screen Shot"
	DFB  &00
	ASC  "0.01 (20 Oct 2024)"
copyr	DFB  &00
	ASC  "(C) Steve Fosdick, 2024"
	DFB  &00

	; Command table.

cmdtab	ASC  "SCLoad"
	DDB  scload-1
	ASC  "SCSave"
	DDB  scsave-1
        ASC  "SCText"
        DDB  sctext-1
cmdend

	; Errors

errstk  LDA  #&00               ; Insert a BRK instruction.
        STA  &0100
        PLA                     ; Get the return address.
        STA  cmdptr
        PLA
        STA  cmdptr+1
        LDY  #&00
errloop INY                     ; Copy error number, message and terminator.
        LDA  (cmdptr),Y
        STA  &0100,Y
        BNE  errloop
        JMP  &0100

error	MACRO
        JSR  errstk
        DFB  @1
        ASC  @2
        DFB  &00
        ENDM

	; Service Entry

serv	CMP  #&04
	BEQ  oscmd
	RTS  

	; Command lookup.

oscmd	DEY
	TYA
	LDX  #&FF
cmdlp1	PHA
cmdlp2	INX
	INY
	LDA  cmdtab,X		; get character from command table.
	CMP  #'a'		; if lower case then abbreviations are now ok.
	BCS  cmdabok
	EOR  (&F2),Y		; case-insenitive comparison.
	AND  #&5F
	BEQ  cmdlp2
cmdnext INX			; skip forward to the exec address.
	LDA  cmdtab,X
	BPL  cmdnext
	PLA
	TAY
	INX
	CPX  #(cmdend-cmdtab-1)
	BNE  cmdlp1
cmdnfnd INY			; Y back to the value on entry.
	LDA  #&04		; call number, so not claimed.
	RTS
cmddone PLA
	TAY
	INY			; Y back to the value on entry.
	LDA  #&00		; zero claims the service call.
	RTS
cmdlp3	INX
	INY
cmdabok LDA  (&F2),Y		; get character from the command line.
	CMP  #'.'		; abbreviation?
	BEQ  cmddot
	EOR  cmdtab,X		; case-insenitive comparison.
	AND  #&5F
	BEQ  cmdlp3
	LDA  cmdtab,X		; get byte from table.
	BPL  cmdnext		; command finished before table entry.
cmdsplp INY
	LDA  (&F2),Y
	CMP  #' '
	BEQ  cmdsplp
	LDA  #<(cmddone-1)	; arrange return to 'cmddone' above.
	PHA
	LDA  #>(cmddone-1)
	PHA
	LDA  cmdtab,X		; push the exec address of the command.
	PHA
	LDA  cmdtab+1,X
	PHA
	RTS			; goes to the exec address.
cmdenlp INX
cmddot	LDA  cmdtab,X
	BPL  cmdenlp
	BMI  cmdsplp

	; Check for a filename.

checkfn LDA  (&F2),Y
	CMP  #&0d
	BEQ  missfn
	RTS
missfn  error &CC,"Missing filename"

        INCLUDE master.asm

palopt  EQU  1
sctext  INCLUDE savetxt.asm
scsave	JSR  checkfn
        INCLUDE savescr.asm
scload	JSR  checkfn
        INCLUDE loadscr.asm
reloc
