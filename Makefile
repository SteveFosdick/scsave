CFLAGS	= -O2 -Wall

all: scload scsave sctext ssrom.rom bbc2png

scload: scload.asm bbcmicro.asm trans.asm loadscr.asm
	laxasm -o scload -l scload.lst scload.asm

scsave: scsave.asm bbcmicro.asm trans.asm savescr.asm
	laxasm -o scsave -l scsave.lst scsave.asm

sctext: sctext.asm bbcmicro.asm trans.asm savetxt.asm
	laxasm -o sctext -l sctext.lst sctext.asm

ssrom.rom: bbcmicro.asm ssrom.asm loadscr.asm savescr.asm savetxt.asm
	laxasm -o ssrom.rom -l ssrom.lst ssrom.asm

bbc2png: bbc2png.o
	$(CC) $(CFLAGS) -o bbc2png bbc2png.o -lpng
