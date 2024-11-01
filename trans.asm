
        ; Common header for transient commands taking an argument.

cmdptr  EQU  &A8

error   MACRO
        BRK
        DFB  @1
        ASC  @2
        DFB &00
        ENDM

        ORG  &0900
        LOAD *                  ; Load and execute at the start.
        EXEC *
        MSW  &FFFF              ; Run in the I/O processor.

        LDA  #&01               ; Get the address of the command line tail.
        LDX  #>cmdptr
        LDY  #<cmdptr
        JSR  OSARGS
        LDY  #&00
spcloop LDA  (cmdptr),Y         ; Skip spaces.
        CMP  #' '
        BNE  notspc
        INY
        BNE  spcloop
notspc  CMP  #&0D
        BNE  gotfn
missfn  error &CC,"Missing filename"
gotfn
