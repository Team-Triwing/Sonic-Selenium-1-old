	include "configuration.asm"
	include "macros.asm"
	include "equates.asm"

ROM	section org(0)

Z80_Space = $812	    ; The amount of space reserved for Z80 driver. The compressor tool may ask you to increase the size...

	include "AMPS/lang.asm"
	include "AMPS/code/macro.asm"
	include "error/debugger.asm"
; ---------------------------------------------------------------------------
StartOfROM:
	dc.l (StackPointer)&$FFFFFF, GameInit, BusErr, AddressErr
	dc.l IllegalInstr, ZeroDiv, ChkInstr, TrapvInstr, PrivilegeViol
	dc.l Trace, LineAEmu, LineFEmu, ErrorException, ErrorException
	dc.l ErrorException, ErrorException, ErrorException, ErrorException
	dc.l ErrorException, ErrorException, ErrorException, ErrorException
	dc.l ErrorException, ErrorException, ErrorException, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, hint, ErrorTrap, vint, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap
	dc.l ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap, ErrorTrap
	dc.l ErrorTrap, ErrorTrap
	dc.b 'SEGA Genesis    '             			; Console name
	dc.b 'RPNTMLD         '             			; Copyright/release date (placeholder for romfix)
	dc.b '                                                '	; Domestic name (placeholder for romfix)
	dc.b '                                                '	; International name (placeholder for romfix)
	dc.b 'GM XXXXXXXX-XX'               			; Serial code (placeholder for romfix)
Checksum:dc.w 0                      				; Checksum
	dc.b 'J               '					; I/O support
	dc.l StartOfROM
RomEndLoc:dc.l	EndOfROM-1	       				; ROM region
	dc.l RAM_START, RAM_END 	  			; RAM region
	if DEMO_RECORD=0
	dc.l $202020
	dc.l $202020
	dc.l $202020
	else
	dc.b "RA",$E0,$20
	dc.l $200000
	dc.l $20FFFF
	endif
Notes:	dc.b '                                                    ' ; Notes (unused, anything can be put in this space, but it has to be 52 bytes.)
	dc.b 'JU              '	; Region (Country code)
EndOfHeader:
	even
; ---------------------------------------------------------------------------

GameInit:
	btst	#6,(HW_version).l		; Check for PAL or NTSC, 0=60Hz, 1=50Hz
	bne.s	jmpLockout			; if !=0, branch to lockout

	jsr	MSUMD_DRV
	tst.b	d0				; if 1: no CD Hardware found
	bne.s	jmpLockout			; if no, branch to lockout

	move.w	#(MSUc_VOLUME|255),MCD_CMD	; Set CD Volume to MAX
	addq.b	#1,MCD_CMD_CK			; Increment command clock
	move.w	#(MSUc_NOSEEK|1),MCD_CMD	; Set seek time emulation to off
	addq.b	#1,MCD_CMD_CK			; Increment command clock

	bra.s	msuOK				; skip jmpLockout

jmpLockout:
	jmp	msuLockout.l

msuOK:
	tst.l	($A10008).l

loc_20C:
	bne.w	MainProgram
	tst.w	($A1000C).l
	bne.s	loc_20C
	lea InitValues(pc),a5
	movem.l (a5)+,d5-a4
	move.w	-$1100(a1),d0
	andi.w	#$F00,d0
	beq.s	loc_232
	move.l	#'SEGA',$2F00(a1)

loc_232:
	move.w	(a4),d0
	moveq	#0,d0
	movea.l d0,a6
	move.l	a6,usp
	rept $18
	move.b	(a5)+,d5
	move.w	d5,(a4)
	add.w	d7,d5
	endr
	move.l	#VRAM_ADDR_CMD,(a4)
	move.w	d0,(a3)
	move.w	d7,(a1)
	move.w	d7,(a2)

loc_252:
	btst	d0,(a1)
	bne.s	loc_252
	moveq	#endinit-initz80-1,d2

loc_258:
	move.b	(a5)+,(a0)+
	dbf	d2,loc_258
	move.w	d0,(a2)
	move.w	d0,(a1)
	move.w	d7,(a2)

loc_264:
	move.l	d0,-(a6)
	dbf d6,loc_264
	move.l	#$81048F02,(a4)
	move.l	#CRAM_ADDR_CMD,(a4)
	rept $20
	move.l	d0,(a3)
	endr
	move.l	#VSRAM_ADDR_CMD,(a4)
	rept $14
	move.l	d0,(a3)
	endr
	moveq	#3,d5

loc_28E:
	move.b	(a5)+,$10(a3)
	dbf d5,loc_28E
	move.w	d0,(a2)
	movem.l (a6),d0-a6
	disable_ints
	bra.s	MainProgram
; ---------------------------------------------------------------------------

InitValues: dc.l VDPREG_MODE1, $3FFF, $100
	dc.l z80_ram				; Z80 RAM
	dc.l z80_bus_request			; Z80 bus release
	dc.l z80_reset				; Z80 reset
	dc.l VdpData				; VDP data port
	dc.l VdpCtrl				; VDP command port
	dc.b %00110000, %11110100, $30, $3C, 7, $6C, 0, 0, 0, 0, $FF, 0, $81  ; VDP values
	dc.b $37, 0, 1, 1, 0, 0, $FF, $FF, 0, 0, $80

initz80 z80prog 0
	di
	im  1
	ld  hl,YM_Buffer1			; we need to clear from YM_Buffer1
	ld  de,(YM_BufferEnd-YM_Buffer1)/8	; to end of Z80 RAM, setting it to 0FFh

.loop
	ld  a,0FFh				; load 0FFh to a
	rept 8
		ld  (hl),a			; save a to address
		inc hl				; go to next address
	endr

	zdec	de				; decrease loop counter
	ld  a,d 	    			; load d to a
	zor e		    			; check if both d and e are 0
	jrnz .loop	    			; if no, clear more memory
.pc	jr  .pc 	    			; trap CPU execution
	z80prog
	even
endinit

	dc.b $9F, $BF, $DF, $FF 	    	; PSG volumes (1, 2, 3 and 4)
	even
; ---------------------------------------------------------------------------

MainProgram:
	waitDMA
	btst	#6,(IO_C_CTRL).l

DoChecksum:
	movea.w	#EndOfHeader,a0 	; prepare start address
	move.l	(RomEndLoc).w,d7 	; load size
	sub.l	a0,d7 			; minus start address
	move.b	d7,d5 			; copy end nybble
	andi.w	#$F,d5 			; get only the remaining nybble
	lsr.l	#4,d7 			; divide the size by 20
	move.w	d7,d6 			; load lower word size
	swap	d7 			; get upper word size
	moveq	#0,d4 			; clear d4

CS_MainBlock:
	rept 8
	add.w	(a0)+,d4 		; modular checksum (8 words)
	endr
	dbf	d6,CS_MainBlock 	; repeat until all main block sections are done
	dbf	d7,CS_MainBlock 	; ''
	subq.w	#1,d5 			; decrease remaining nybble for dbf
	bpl.s	CS_Finish 		; if there is no remaining nybble, branch

CS_Remains:
	add.w	(a0)+,d4 		; add remaining words
	dbf	d5,CS_Remains 		; repeat until the remaining words are done

CS_Finish:
	cmp.w	(Checksum).w,d4 	; does the checksum match?
	bne.s	CheckSumError 		; if not, branch

loc_36A:
	command	mus_Stop
	clrRAM	RAM_START,RAM_END
	jsr	InitDMAQueue
	bsr.w	vdpInit
	bsr.w	padInit
	jsr	LoadDualPCM
	clr.b	(GameMode).w

ScreensLoop:
	move.b	(HW_VERSION).l,d0
	andi.b	#$C0,d0
	move.b	d0,(ConsoleRegion).w
	move.b	(GameMode).w,d0
	andi.w	#$7C,d0
	movea.l ScreensArray(pc,d0.w),a0
	jsr	(a0)
	bra.s	ScreensLoop
; ---------------------------------------------------------------------------

ScreensArray:
	dc.l	sSega
; ---------------------------------------------------------------------------
	dc.l	sTitle
; ---------------------------------------------------------------------------
	dc.l	sLevel
; ---------------------------------------------------------------------------
	dc.l	sLevel
; ---------------------------------------------------------------------------
	dc.l	sSpecial
; ---------------------------------------------------------------------------

ChecksumError:
	music	mus_Continue, 1
	bsr.w	padInit
	Console.Run	ChecksumErr_ConsProg
	even

ChecksumErr_ConsProg:
	Console.SetXY	#7,#8
	Console.WriteLine   "The checksum is %<pal1>incorrect!"
	Console.BreakLine
	Console.WriteLine   "%<pal0>Calculated Checksum: %<pal3>$%<.w d4>"
	move.w	Checksum,d7
	Console.WriteLine   "  %<pal0>Checksum in ROM: %<pal3>$%<.w d7>"
	Console.BreakLine
	Console.WriteLine   " %<pal0>Any error report sent"
	Console.WriteLine   "might be %<pal1>harder %<pal0>to patch"
	Console.WriteLine   "  with a %<pal1>bad %<pal0>checksum."
	Console.WriteLine   "%<pal0>so redownloading the ROM"
	Console.WriteLine   " is %<pal2>highly recommended."
	Console.BreakLine
	Console.WriteLine   "%<pal0>You can try and continue"
	Console.WriteLine   "	 by pressing %<pal3>START%<pal0>"
	Console.WriteLine   "but it's %<pal1>not %<pal0>recommended."
	rts

ConsoleHandler:
	bsr.w 	padRead
	cmpi.b	#J_S,(padPress1).w 		; is Start pressed?
	beq.w	loc_36A    			; if true, branch
	bra.s 	ConsoleHandler
; ---------------------------------------------------------------------------
ArtText:    incbin "unsorted/debugtext.unc"
	even
ArtLSText:  incbin "unsorted/levelselecttext.unc"
	even
; ---------------------------------------------------------------------------

vint:
	pusha
	tst.b	(VintRoutine).w
	beq.s	loc_B58
	move.w	(VdpCtrl).l,d0
	move.l	#VSRAM_ADDR_CMD,(VdpCtrl).l
	move.l	(dword_FFF616).w,(VdpData).l

loc_B3C:
	move.b	(VintRoutine).w,d0
	clr.b	(VintRoutine).w
	st.b	(HintFlag).w
	andi.w	#$3E,d0
	move.w	off_B6A(pc,d0.w),d0
	jsr	off_B6A(pc,d0.w)

loc_B58:
	enable_ints			; enable interrupts (we can accept horizontal interrupts from now on)
	tas	(word_FFF644).w    	; set "SMPS running flag"
	bne.s	VBla_Exit		; if it was set already, don't call another instance of SMPS
	jsr	UpdateAMPS		; run SMPS
	clr.b	(word_FFF644).w       	; reset "SMPS running flag"
VBla_Exit:	
	addq.l	#1,(VintCounter).w
	popa
	rte
; ---------------------------------------------------------------------------

nullsub_3:
	rts
; ---------------------------------------------------------------------------

off_B6A:    dc.w nullsub_3-off_B6A, loc_B7E-off_B6A, sub_B90-off_B6A, sub_BAA-off_B6A, loc_BBA-off_B6A
	dc.w loc_CBC-off_B6A, sub_D88-off_B6A, sub_E58-off_B6A, sub_BB0-off_B6A, sub_E70-off_B6A
; ---------------------------------------------------------------------------

loc_B7E:
	bsr.w	sub_E78
	subq.w	#1,(GlobalTimer).w
	rts
; ---------------------------------------------------------------------------

sub_B90:
	bsr.w	sub_E78
	bsr.w	sub_43B6
	bsr.w	sub_1438
	subq.w	#1,(GlobalTimer).w
	rts
; ---------------------------------------------------------------------------

sub_BB0:
	cmpi.b	#$10,(GameMode).w
	beq.w	loc_CBC

loc_BBA:
	bsr.w	padRead
	dma68k	Palette,0,$80,CRAM
	dma68k	SprTableBuff,vram_sprites,$280,VRAM
	dma68k	ScrollTable,vram_hscroll,$400,VRAM
	pea	(ProcessDMAQueue).l

loc_C7A:
	bsr.w	mapLevelLoad
	jsr	ZoneAnimTiles
	jsr	UpdateHUD
	bsr.w	loc_1454
	subq.w	#1,(GlobalTimer).w
	rts
; ---------------------------------------------------------------------------

loc_CBC:
	bsr.w	padRead
	dma68k	Palette,0,$80,CRAM
	dma68k	SprTableBuff,vram_sprites,$280,VRAM
	dma68k	ScrollTable,vram_hscroll,$400,VRAM
	pea (ProcessDMAQueue).l

loc_D7A:
	subq.w	#1,(GlobalTimer).w

locret_D86:
	rts
; ---------------------------------------------------------------------------

sub_D88:
	bsr.w	padRead
	dma68k	Palette,0,$80,CRAM
	dma68k	SprTableBuff,vram_sprites,$280,VRAM
	dma68k	ScrollTable,vram_hscroll,$400,VRAM
	pea (ProcessDMAQueue).l

loc_E3A:
	bsr.w	mapLevelLoad
	jsr	ZoneAnimTiles
	jsr	UpdateHUD
	bra.w	sub_1438
; ---------------------------------------------------------------------------

sub_E58:
	bsr.s	sub_E78
	jsr   	RunObjects
	jsr   	ProcessMaps
	move.b	#$E,(VintRoutine).w
	rts
; ---------------------------------------------------------------------------

sub_E70:
	bsr.s	sub_E78
	bra.w	sub_1438
; ---------------------------------------------------------------------------

sub_BAA:
sub_E78:
	bsr.w	padRead
	dma68k	Palette,0,$80,CRAM
	dma68k	SprTableBuff,vram_sprites,$280,VRAM
	dma68k	ScrollTable,vram_hscroll,$400,VRAM
	rts
; ---------------------------------------------------------------------------

hint:
	tst.b	(HintFlag).w
	beq.s	locret_F3A
	dma68k	Palette,0,$80,CRAM
	clr.b	(HintFlag).w

locret_F3A:
	rte
; ---------------------------------------------------------------------------

padInit:
	z80Bus
	moveq	#$40,d0
	move.b	d0,(IO_A_CTRL).l
	move.b	d0,(IO_B_CTRL).l
	move.b	d0,(IO_C_CTRL).l
	z80Start
	rts
; ---------------------------------------------------------------------------

padRead:
	z80Bus
	lea (padHeld1).w,a0
	lea (IO_A_DATA).l,a1
	bsr.s	sub_FDC
	addq.w	#2,a1
; ---------------------------------------------------------------------------

sub_FDC:
	move.b	#0,(a1)
	nop
	nop
	move.b	(a1),d0
	lsl.b	#2,d0
	andi.b	#$C0,d0
	move.b	#$40,(a1)
	nop
	nop
	move.b	(a1),d1
	andi.b	#$3F,d1
	or.b	d1,d0
	not.b	d0
	move.b	(a0),d1
	eor.b	d0,d1
	move.b	d0,(a0)+
	and.b	d0,d1
	move.b	d1,(a0)+
	z80Start
	rts
; ---------------------------------------------------------------------------

vdpInit:
	lea (VdpCtrl).l,a0
	lea (VdpData).l,a1
	lea (vdpInitRegs).l,a2
	rept $12
	move.w	(a2)+,(a0)
	endr
	move.w	(vdpInitRegs+2).l,d0
	move.w	d0,(ModeReg2).w
	moveq	#0,d0
	move.l	#CRAM_ADDR_CMD,(VdpCtrl).l
	rept $3F
	move.w	d0,(a1)
	endr
	clr.l	(dword_FFF616).w
	clr.l	(dword_FFF61A).w
	move.l	d1,-(sp)
	lea (VdpCtrl).l,a5
	move.w	#$8F01,(a5)
	dmaFill	0,0,$FFFF,a5
	move.w	#$8F02,(a5)
	move.l	(sp)+,d1
	rts
; ---------------------------------------------------------------------------

vdpInitRegs:
	dc.w $8004, $8134, $8230, $8328, $8407
	dc.w $857C, $8600, $8700, $8800, $8900
	dc.w $8A00, $8B00, $8C81, $8D3F, $8E00
	dc.w $8F02, $9001, $9100, $9200
	
; -------------------------------------------------------------------------
; Add a DMA transfer command to the DMA queue
; -------------------------------------------------------------------------
; PARAMETERS:
;	d1.l	- Source in 68000 memory
;	d2.w	- Destination in VRAM
;	d3.w	- Transfer length in words
; -------------------------------------------------------------------------

; This option makes the function work as a drop-in replacement of the original
; functions. If you modify all callers to supply a position in words instead of
; bytes (i.e., divide source address by 2) you can set this to 0 to gain 10(1/0)
AssumeSourceAddressInBytes	EQU	0

; This option (which is disabled by default) makes the DMA queue assume that the
; source address is given to the function in a way that makes them safe to use
; with RAM sources. You need to edit all callers to ensure this.
; Enabling this option turns off UseRAMSourceSafeDMA, and saves 14(2/0).
AssumeSourceAddressIsRAMSafe	EQU	1

; This option (which is enabled by default) makes source addresses in RAM safe
; at the cost of 14(2/0). If you modify all callers so as to clear the top byte
; of source addresses (i.e., by ANDing them with $FFFFFF).
UseRAMSourceSafeDMA		EQU	0&(AssumeSourceAddressIsRAMSafe=0)

; This option breaks DMA transfers that crosses a 128kB block into two. It is disabled by default because you can simply align the art in ROM
; and avoid the issue altogether. It is here so that you have a high-performance routine to do the job in situations where you can't align it in ROM.
Use128kbSafeDMA			EQU	0

; Option to mask interrupts while updating the DMA queue. This fixes many race conditions in the DMA funcion, but it costs 46(6/1) cycles. The
; better way to handle these race conditions would be to make unsafe callers (such as S3&K's KosM decoder) prevent these by masking off interrupts
; before calling and then restore interrupts after.
UseVIntSafeDMA			EQU	0

; Like vdpComm, but starting from an address contained in a register

vdpCommReg macro reg, type, rwd, clr
	lsl.l	#2,\reg				; Move high bits into (word-swapped) position, accidentally moving everything else
	if ((v\type\&v\rwd\)&3)<>0
	addq.w	#(v\type\&v\rwd\)&3,\reg	; Add upper access type bits
	endif
	ror.w	#2,\reg				; Put upper access type bits into place, also moving all other bits into their correct (word-swapped) places
	swap	\reg				; Put all bits in proper places
	if \clr<>0
	andi.w	#3,\reg				; Strip whatever junk was in upper word of reg
	endif
	if ((v\type\&v\rwd\)&$FC)=$20
	tas.b	\reg				; Add in the DMA flag -- tas fails on memory, but works on registers
	elseif ((v\type\&v\rwd\)&$FC)<>0
	ori.w	#((v\type\&v\rwd\)&$FC)<<2,\reg	; Add in missing access type bits
	endif
	endm

; -------------------------------------------------------------------------

	rsreset
DMAEntry.Reg94		rs.b	1
DMAEntry.Size		rs.b	0
DMAEntry.SizeH		rs.b	1
DMAEntry.Reg93		rs.b	1
DMAEntry.Source		rs.b	0
DMAEntry.SizeL		rs.b	1
DMAEntry.Reg97		rs.b	1
DMAEntry.SrcH		rs.b	1
DMAEntry.Reg96		rs.b	1
DMAEntry.SrcM		rs.b	1
DMAEntry.Reg95		rs.b	1
DMAEntry.SrcL		rs.b	1
DMAEntry.Command	rs.l	1
DMAEntry.len		rs.b	0

; -------------------------------------------------------------------------

QueueSlotCount	EQU	(r_DMA_Slot-r_DMA_Queue)/DMAEntry.len

; -------------------------------------------------------------------------

loadDMA macro src, length, dest

	if ((\src)&1)<>0
		inform 2,"DMA queued from odd source $\$src\!"
	endif
	if ((\length)&1)<>0
		inform 2,"DMA an odd number of bytes $\length\!"
	endif
	if (\length)=0
		inform 2,"DMA transferring 0 bytes (becomes a 128kB transfer). If you really mean it, pass 128kB instead."
	endif
	if (((\src)+(\length)-1)>>17)<>((\src)>>17)
		inform 2,"DMA crosses a 128kB boundary. You should either split the DMA manually or align the source adequately."
	endif
	if UseVIntSafeDMA=1
		move.w	sr,-(sp)		; Save current interrupt mask
		move	#$2700,sr		; Mask off interrupts
	endif
	movea.w	r_DMA_Slot.w,a1
	cmpa.w	#r_DMA_Slot,a1
	beq.s	.Done\@				; Return if there's no more room in the queue

						; Write top byte of size/2
	move.b	#((((\length)>>1)&$7FFF)>>8)&$FF,DMAEntry.SizeH(a1)
						; Set d0 to bottom byte of size/2 and the low 3 bytes of source/2
	move.l	#(((((\length)>>1)&$7FFF)&$FF)<<24)|(((\src)>>1)&$7FFFFF),d0
	movep.l	d0,DMAEntry.SizeL(a1)		; Write it all to the queue
	lea	DMAEntry.Command(a1),a1		; Seek to correct RAM address to store VDP DMA command
	vdpCmd	move.l,\dest,VRAM,DMA,(a1)+	; Write VDP DMA command for destination address
	move.w	a1,r_DMA_Slot.w			; Write next queue slot

.Done\@:
	if UseVIntSafeDMA=1
		move.w	(sp)+,sr		; Restore interrupts to previous state
	endif

	endm

; -------------------------------------------------------------------------

resetDMA macros
	move.w	#r_DMA_Queue,r_DMA_Slot.w

; -------------------------------------------------------------------------

QueueDMA:
QueueDMATransfer:
	if UseVIntSafeDMA=1
		move.w	sr,-(sp)		; Save current interrupt mask
		move	#$2700,sr		; Mask off interrupts
	endif
	movea.w	r_DMA_Slot.w,a1
	cmpa.w	#r_DMA_Slot,a1
	beq.s	.Done				; Return if there's no more room in the queue

	if AssumeSourceAddressInBytes<>0
		lsr.l	#1,d1			; Source address is in words for the VDP registers
	endif
	if UseRAMSourceSafeDMA<>0
		bclr.l	#23,d1			; Make sure bit 23 is clear (68k->VDP DMA flag)
	endif
	movep.l	d1,DMAEntry.Source(a1)		; Write source address; the useless top byte will be overwritten later
	moveq	#0,d0				; We need a zero on d0

	if Use128kbSafeDMA<>0
		; Detect if transfer crosses 128KB boundary
		; Using sub+sub instead of move+add handles the following edge cases:
		; (1) d3.w == 0 => 128kB transfer
		;   (a) d1.w == 0 => no carry, don't split the DMA
		;   (b) d1.w != 0 => carry, need to split the DMA
		; (2) d3.w != 0
		;   (a) if there is carry on d1.w + d3.w
		;     (* ) if d1.w + d3.w == 0 => transfer comes entirely from current 128kB block, don't split the DMA
		;     (**) if d1.w + d3.w != 0 => need to split the DMA
		;   (b) if there is no carry on d1.w + d3.w => don't split the DMA
		; The reason this works is that carry on d1.w + d3.w means that
		; d1.w + d3.w >= $10000, whereas carry on (-d3.w) - (d1.w) means that
		; d1.w + d3.w > $10000.
		sub.w	d3,d0			; Using sub instead of move and add allows checking edge cases
		sub.w	d1,d0			; Does the transfer cross over to the next 128kB block?
		bcs.s	.doubletransfer		; Branch if yes
	endif
	; It does not cross a 128kB boundary. So just finish writing it.
	movep.w	d3,DMAEntry.Size(a1)		; Write DMA length, overwriting useless top byte of source address

.finishxfer:
	; Command to specify destination address and begin DMA
	move.w	d2,d0				; Use the fact that top word of d0 is zero to avoid clearing on vdpCommReg
	vdpCommReg	d0,VRAM,DMA,0		; Convert destination address to VDP DMA command
	lea	DMAEntry.Command(a1),a1		; Seek to correct RAM address to store VDP DMA command
	move.l	d0,(a1)+			; Write VDP DMA command for destination address
	move.w	a1,r_DMA_Slot.w			; Write next queue slot

.Done:
	if UseVIntSafeDMA=1
		move.w	(sp)+,sr		; Restore interrupts to previous state
	endif
	rts

	if Use128kbSafeDMA=1
.doubletransfer:
	; We need to split the DMA into two parts, since it crosses a 128kB block
	add.w	d3,d0				; Set d0 to the number of words until end of current 128kB block
	movep.w	d0,DMAEntry.Size(a1)		; Write DMA length of first part, overwriting useless top byte of source addres

	cmpa.w	#r_DMA_Slot-DMAEntry.len,a1	; Does the queue have enough space for both parts?
	beq.s	.finishxfer			; Branch if not

	; Get second transfer's source, destination, and length
	sub.w	d0,d3				; Set d3 to the number of words remaining
	add.l	d0,d1				; Offset the source address of the second part by the length of the first part
	add.w	d0,d0				; Convert to number of bytes
	add.w	d2,d0				; Set d0 to the VRAM destination of the second part

	; If we know top word of d2 is clear, the following vdpCommReg can be set to not
	; clear it. There is, unfortunately, no faster way to clear it than this.
	vdpCommReg d2,VRAM,DMA,1		; Convert destination address of first part to VDP DMA command
	move.l	d2,DMAEntry.Command(a1)		; Write VDP DMA command for destination address of first part

	; Do second transfer
						; Write source address of second part; useless top byte will be overwritten later
	movep.l	d1,DMAEntry.len+DMAEntry.Source(a1)
						; Write DMA length of second part, overwriting useless top byte of source address
	movep.w	d3,DMAEntry.len+DMAEntry.Size(a1)

	; Command to specify destination address and begin DMA
	vdpCommReg d0,VRAM,DMA,0		; Convert destination address to VDP DMA command; we know top half of d0 is zero
						; Seek to correct RAM address to store VDP DMA command of second part
	lea	DMAEntry.len+DMAEntry.Command(a1),a1
	move.l	d0,(a1)+			; Write VDP DMA command for destination address of second part

	move.w	a1,r_DMA_Slot.w			; Write next queue slot
	if UseVIntSafeDMA=1
		move.w	(sp)+,sr		; Restore interrupts to previous state
	endif
	rts
	endif

; -------------------------------------------------------------------------
; Process all the DMA commands queued
; -------------------------------------------------------------------------

ProcessDMA:
ProcessDMAQueue:
	lea	VDP_CTRL,a5
	movea.w	r_DMA_Slot.w,a1
	jmp	.jump_table-r_DMA_Queue(a1)

; -------------------------------------------------------------------------

.jump_table:
	rts
	rept 6
		rts											; Just in case
	endr

; -------------------------------------------------------------------------

c = 1
	rept QueueSlotCount
		lea	VDP_CTRL,a5
		lea	r_DMA_Queue.w,a1
		if c<>QueueSlotCount
			bra.w	.jump0-(c*8)
		endif
c = c+1
	endr

; -------------------------------------------------------------------------

	rept QueueSlotCount
		move.l	(a1)+,(a5)									; Transfer length
		move.l	(a1)+,(a5)									; Source address high
		move.l	(a1)+,(a5)									; Source address low + destination high
		move.w	(a1)+,(a5)									; Destination low, trigger DMA
	endr

.jump0:
	resetDMA
	rts

; -------------------------------------------------------------------------
; Initialize the DMA queue
; -------------------------------------------------------------------------

InitDMA:
InitDMAQueue:
	lea	r_DMA_Queue.w,a0
	move.b	#$94,d0
	move.l	#$93979695,d1
c = 0
	rept QueueSlotCount
		move.b	d0,c+DMAEntry.Reg94(a0)
		movep.l	d1,c+DMAEntry.Reg93(a0)
c = c+DMAEntry.len
	endr

	resetDMA
	rts
; ---------------------------------------------------------------------------

ClearScreen:
	lea (VdpCtrl).l,a5
	move.w	#$8F01,(a5)
	dmaFill	0,vram_fg,$FFF,a5
	dmaFill	0,vram_bg,$FFF,a5
	move.w	#$8F02,(a5)
	clr.l	(dword_FFF616).w
	clr.l	(dword_FFF61A).w
	clrRAM	SprTableBuff
	clrRAM	ScrollTable
	rts
; ---------------------------------------------------------------------------

PauseGame:
	tst.b	(Lives).w
	beq.s	loc_1206
	tst.b	(PauseFlag).w
	bne.s	loc_11CC
	btst	#JbS,(padPress1).w
	beq.s	locret_120C

loc_11CC:
	st.b  	(PauseFlag).w
	AMPS_MUSPAUSE
	waitmsu
	move.w	#(MSUc_PAUSE|8),MCD_CMD.l
	addq.b	#1,MCD_CMD_CK ; Increment command clock

loc_11D2:
	move.b	#$10,(VintRoutine).w
	vsync
	btst	#JbA,(padPress1).w
	beq.s	loc_11EE
	move.b	#4,(GameMode).w
	bra.s	loc_1206
; ---------------------------------------------------------------------------

loc_11EE:
	btst	#JbB,(padHeld1).w
	bne.s	loc_120E
	btst	#JbC,(padPress1).w
	bne.s	loc_120E
	btst	#JbS,(padPress1).w
	beq.s	loc_11D2

loc_1206:
	clr.b	(PauseFlag).w
	AMPS_MUSUNPAUSE
	waitmsu
	move.w	#MSUc_RESUME,MCD_CMD.l
	addq.b	#1,MCD_CMD_CK ; Increment command clock

locret_120C:
	rts
; ---------------------------------------------------------------------------

loc_120E:
	st.b  	(PauseFlag).w
	AMPS_MUSPAUSE
	waitmsu
	move.w	#(MSUc_PAUSE|8),MCD_CMD.l
	addq.b	#1,MCD_CMD_CK ; Increment command clock
	rts
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Load a plane map
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d0.l	- VDP command for writing the data to VRAM
;	d1.w	- Width in tiles (minus 1)
;	d2.w	- Height in tiles (minus 1)
;	d3.w	- Base tile properties for each tile
;	d6.l	- Delta value for drawing to the next row (only required for just LoadPlaneMap_Custom)
;	a1.l	- Plane map address
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------

LoadPlaneMap:
LoadPlaneMap_H64:
		move.l	#$800000,d6			; For planes with 64 tile width
		bra.s	LoadPlaneMap_Custom		; Load the map

LoadPlaneMap_H32:
		move.l	#$400000,d6			; For planes with 32 tile width
		bra.s	LoadPlaneMap_Custom		; Load the map

LoadPlaneMap_H128:
		move.l	#$1000000,d6			; For planes with 128 tile width

LoadPlaneMap_Custom:
.RowLoop:
		move.l	d0,VDP_CTRL			; Set VDP command
		move.w	d1,d4				; Store width

.TileLoop:
		move.w	(a1)+,d5			; Get tile ID and properties
		add.w	d3,d5				; Add base tile properties
		move.w	d5,VDP_DATA			; Save in VRAM
		dbf	d4,.TileLoop			; Loop until the row has been drawn
		add.l	d6,d0				; Next row
		dbf	d2,.RowLoop			; Loop until the plane has been drawn
		rts
; ---------------------------------------------------------------------------

; ==============================================================================
; ------------------------------------------------------------------------------
; Nemesis decompression routine
; ------------------------------------------------------------------------------
; Optimized by vladikcomper
; ------------------------------------------------------------------------------

NemDec_RAM:
	movem.l d0-a1/a3-a6,-(sp)
	lea NemDec_WriteRowToRAM(pc),a3
	bra.s	NemDec_Main

; ------------------------------------------------------------------------------
NemesisDec:
	movem.l d0-a1/a3-a6,-(sp)
	lea	VdpData,a4	    			; load VDP Data Port
	lea	NemDec_WriteRowToVDP(pc),a3

NemDec_Main:
	lea NemBuffer,a1				; load Nemesis decompression buffer
	move.w	(a0)+,d2				; get number of patterns
	bpl.s	.0	   	 			; are we in Mode 0?
	lea $A(a3),a3	    				; if not, use Mode 1
.0 	lsl.w	#3,d2
	movea.w d2,a5
	moveq	#7,d3
	moveq	#0,d2
	moveq	#0,d4
	bsr.w	NemDec4
	move.b	(a0)+,d5				; get first byte of compressed data
	asl.w	#8,d5					; shift up by a byte
	move.b	(a0)+,d5				; get second byte of compressed data
	move.w	#$10,d6 				; set initial shift value
	bsr.s	NemDec2
	movem.l	(sp)+,d0-a1/a3-a6
	rts

; ---------------------------------------------------------------------------
; Part of the Nemesis decompressor, processes the actual compressed data
; ---------------------------------------------------------------------------

NemDec2:
	move.w	d6,d7
	subq.w	#8,d7					; get shift value
	move.w	d5,d1
	lsr.w	d7,d1					; shift so that high bit of the code is in bit position 7
	cmpi.b	#%11111100,d1	    			; are the high 6 bits set?
	bcc.s	NemDec_InlineData   			; if they are, it signifies inline data
	andi.w	#$FF,d1
	add.w	d1,d1
	sub.b	(a1,d1.w),d6	    			; ~~ subtract from shift value so that the next code is read next time around
	cmpi.w	#9,d6					; does a new byte need to be read?
	bcc.s	.0	    				; if not, branch
	addq.w	#8,d6
	asl.w	#8,d5
	move.b	(a0)+,d5				; read next byte
.0  	move.b	1(a1,d1.w),d1
	move.w	d1,d0
	andi.w	#$F,d1					; get palette index for pixel
	andi.w	#$F0,d0

NemDec_GetRepeatCount:
	lsr.w	#4,d0					; get repeat count

NemDec_WritePixel:
	lsl.l	#4,d4					; shift up by a nybble
	or.b	d1,d4					; write pixel
	dbf	d3,NemDec_WritePixelLoop		; ~~
	jmp	(a3)	    				; otherwise, write the row to its destination
; ---------------------------------------------------------------------------

NemDec3:
	moveq	#0,d4					; reset row
	moveq	#7,d3					; reset nybble counter

NemDec_WritePixelLoop:
	dbf d0,NemDec_WritePixel
	bra.s	NemDec2
; ---------------------------------------------------------------------------

NemDec_InlineData:
	subq.w	#6,d6					; 6 bits needed to signal inline data
	cmpi.w	#9,d6
	bcc.s	.0
	addq.w	#8,d6
	asl.w	#8,d5
	move.b	(a0)+,d5
.0  	subq.w	#7,d6					; and 7 bits needed for the inline data itself
	move.w	d5,d1
	lsr.w	d6,d1					; shift so that low bit of the code is in bit position 0
	move.w	d1,d0
	andi.w	#$F,d1					; get palette index for pixel
	andi.w	#$70,d0 				; high nybble is repeat count for pixel
	cmpi.w	#9,d6
	bcc.s	NemDec_GetRepeatCount
	addq.w	#8,d6
	asl.w	#8,d5
	move.b	(a0)+,d5
	bra.s	NemDec_GetRepeatCount

; ---------------------------------------------------------------------------
; Subroutines to output decompressed entry
; Selected depending on current decompression mode
; ---------------------------------------------------------------------------

NemDec_WriteRowToVDP:
sub_12F8:
	move.l	d4,(a4) 				; write 8-pixel row
	subq.w	#1,a5
	move.w	a5,d4					; have all the 8-pixel rows been written?
	bne.s	NemDec3 				; if not, branch
	rts
; ---------------------------------------------------------------------------

NemDec_WriteRowToVDP_XOR:
	eor.l	d4,d2					; XOR the previous row by the current row
	move.l	d2,(a4) 				; and write the result
	subq.w	#1,a5
	move.w	a5,d4
	bne.s	NemDec3
	rts
; ---------------------------------------------------------------------------

NemDec_WriteRowToRAM:
	move.l	d4,(a4)+				; write 8-pixel row
	subq.w	#1,a5
	move.w	a5,d4					; have all the 8-pixel rows been written?
	bne.s	NemDec3 				; if not, branch
	rts
; ---------------------------------------------------------------------------

NemDec_WriteRowToRAM_XOR:
	eor.l	d4,d2					; XOR the previous row by the current row
	move.l	d2,(a4)+				; and write the result
	subq.w	#1,a5
	move.w	a5,d4
	bne.s	NemDec3
	rts

; ---------------------------------------------------------------------------
; Part of the Nemesis decompressor, builds the code table (in RAM)
; ---------------------------------------------------------------------------

NemDec4:
	move.b	(a0)+,d0				; read first byte

.ChkEnd:cmpi.b	#$FF,d0 				; has the end of the code table description been reached?
	bne.s	.NewPalIndex	    			; if not, branch
	rts
; ---------------------------------------------------------------------------

.NewPalIndex:
	move.w	d0,d7

.ItemLoop:
	move.b	(a0)+,d0				; read next byte
	bmi.s	.ChkEnd 				; ~~
	move.b	d0,d1
	andi.w	#$F,d7					; get palette index
	andi.w	#$70,d1 				; get repeat count for palette index
	or.w	d1,d7					; combine the two
	andi.w	#$F,d0					; get the length of the code in bits
	move.b	d0,d1
	lsl.w	#8,d1
	or.w	d1,d7					; combine with palette index and repeat count to form code table entry
	moveq	#8,d1
	sub.w	d0,d1					; is the code 8 bits long?
	bne.s	.ItemShortCode	    			; if not, a bit of extra processing is needed
	move.b	(a0)+,d0				; get code
	add.w	d0,d0					; each code gets a word-sized entry in the table
	move.w	d7,(a1,d0.w)	    			; store the entry for the code
	bra.s	.ItemLoop				; repeat
; ---------------------------------------------------------------------------

.ItemShortCode:
	move.b	(a0)+,d0				; get code
	lsl.w	d1,d0					; shift so that high bit is in bit position 7
	add.w	d0,d0					; get index into code table
	moveq	#1,d5
	lsl.w	d1,d5
	subq.w	#1,d5					; d5 = 2^d1 - 1
	lea	(a1,d0.w),a6				; ~~

.ItemShortCodeLoop:
	move.w	d7,(a6)+				; ~~ store entry
	dbf d5,.ItemShortCodeLoop   			; repeat for required number of entries
	bra.s	.ItemLoop
; ---------------------------------------------------------------------------

plcAdd:
	movem.l a1-a2,-(sp)
	lea (plcArray).l,a1
	add.w	d0,d0
	move.w	(a1,d0.w),d0
	lea	(a1,d0.w),a1
	lea	(plcList).w,a2

loc_138E:
	tst.l	(a2)
	beq.s	loc_1396
	addq.w	#6,a2
	bra.s	loc_138E
; ---------------------------------------------------------------------------

loc_1396:
	move.w	(a1)+,d0
	bmi.s	loc_13A2

loc_139A:
	move.l	(a1)+,(a2)+
	move.w	(a1)+,(a2)+
	dbf d0,loc_139A

loc_13A2:
	movem.l (sp)+,a1-a2
	rts
; ---------------------------------------------------------------------------

plcReplace:
	movem.l a1-a2,-(sp)
	lea (plcArray).l,a1
	add.w	d0,d0
	move.w	(a1,d0.w),d0
	lea (a1,d0.w),a1
	bsr.s	ClearPLC
	lea (plcList).w,a2
	move.w	(a1)+,d0
	bmi.s	loc_13CE

loc_13C6:
	move.l	(a1)+,(a2)+
	move.w	(a1)+,(a2)+
	dbf d0,loc_13C6

loc_13CE:
	movem.l (sp)+,a1-a2
	rts
; ---------------------------------------------------------------------------

ClearPLC:
	lea (plcList).w,a2
	moveq	#$1F,d0

loc_13DA:
	clr.l	(a2)+
	dbf d0,loc_13DA
	rts
; ---------------------------------------------------------------------------

ProcessPLC:
	tst.l	(plcList).w
	beq.s	locret_1436
	tst.w	(unk_FFF6F8).w
	bne.s	locret_1436
	movea.l (plcList).w,a0
	lea (sub_12F8).l,a3
	lea (NemBuffer).w,a1
	move.w	(a0)+,d2
	bpl.s	loc_1404
	adda.w	#$A,a3

loc_1404:
	andi.w	#$7FFF,d2
	bsr.w	NemDec4
	move.b	(a0)+,d5
	asl.w	#8,d5
	move.b	(a0)+,d5
	moveq	#$10,d6
	moveq	#0,d0
	move.l	a0,(plcList).w
	move.l	a3,(unk_FFF6E0).w
	move.l	d0,(unk_FFF6E4).w
	move.l	d0,(unk_FFF6E8).w
	move.l	d0,(unk_FFF6EC).w
	move.l	d5,(unk_FFF6F0).w
	move.l	d6,(unk_FFF6F4).w
	move.w	d2,(unk_FFF6F8).w

locret_1436:
	rts
; ---------------------------------------------------------------------------

sub_1438:
	tst.w	(unk_FFF6F8).w
	beq.w	locret_14D0
	move.w	#9,(unk_FFF6FA).w
	moveq	#0,d0
	move.w	(plcList+4).w,d0
	addi.w	#$120,(plcList+4).w
	bra.s	loc_146C
; ---------------------------------------------------------------------------

loc_1454:
	tst.w	(unk_FFF6F8).w
	beq.s	locret_14D0
	move.w	#3,(unk_FFF6FA).w
	moveq	#0,d0
	move.w	(plcList+4).w,d0
	addi.w	#$60,(plcList+4).w

loc_146C:
	lea (VdpCtrl).l,a4
	lsl.l	#2,d0
	lsr.w	#2,d0
	ori.w	#$4000,d0
	swap	d0
	move.l	d0,(a4)
	subq.w	#4,a4
	movea.l (plcList).w,a0
	movea.l (unk_FFF6E0).w,a3
	move.l	(unk_FFF6E4).w,d0
	move.l	(unk_FFF6E8).w,d1
	move.l	(unk_FFF6EC).w,d2
	move.l	(unk_FFF6F0).w,d5
	move.l	(unk_FFF6F4).w,d6
	lea (NemBuffer).w,a1

loc_14A0:
	movea.w #8,a5
	bsr.w	NemDec3
	subq.w	#1,(unk_FFF6F8).w
	beq.s	ShiftPLC
	subq.w	#1,(unk_FFF6FA).w
	bne.s	loc_14A0
	move.l	a0,(plcList).w

loc_14B8:
	move.l	a3,(unk_FFF6E0).w
	move.l	d0,(unk_FFF6E4).w
	move.l	d1,(unk_FFF6E8).w
	move.l	d2,(unk_FFF6EC).w
	move.l	d5,(unk_FFF6F0).w
	move.l	d6,(unk_FFF6F4).w

locret_14D0:
	rts
; ---------------------------------------------------------------------------

ShiftPLC:
	lea (plcList).w,a0
	moveq	#$15,d0

loc_14D8:
	move.l	6(a0),(a0)+
	dbf d0,loc_14D8
	rts
; ---------------------------------------------------------------------------

sub_14E2:
	lea (plcArray).l,a1
	add.w	d0,d0
	move.w	(a1,d0.w),d0
	lea (a1,d0.w),a1
	move.w	(a1)+,d1

loc_14F4:
	movea.l (a1)+,a0
	moveq	#0,d0
	move.w	(a1)+,d0
	lsl.l	#2,d0
	lsr.w	#2,d0
	ori.w	#$4000,d0
	swap	d0
	move.l	d0,(VdpCtrl).l
	bsr.w	NemesisDec
	dbf d1,loc_14F4
	rts
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------
; uncompressed art to VRAM loader - AuroraFields
;
; INPUT:
;   a0 - Source Offset
;   d0 - length in tiles
; ---------------------------------------------------------------
LoadUncArt:
	disable_ints			; disable interrupts
	lea (VdpData).l,a6		; get VDP data port

LoadArt_Loop:
	rept 8
	move.l	(a0)+,(a6)	 	; transfer 1 full tile (32 bytes)
	endr
	dbf	d0,LoadArt_Loop		; loop until d0 = 0
	enable_ints			; enable interrupts
	rts
; ---------------------------------------------------------------------------
EnigmaDec:		include	"compression/Enigma.asm"
; ---------------------------------------------------------------------------
KosinskiPlusDec:	include	"compression/KosinskiPlus.asm"
; ---------------------------------------------------------------------------
TwizzlerDec:		include	"compression/Twizzler.asm"
; ---------------------------------------------------------------------------

PaletteCycle:
	moveq	#0,d2
	moveq	#0,d0
	move.b	(curzone).w,d0
	add.w	d0,d0
	move.w	.levels(pc,d0.w),d0
	jmp .levels(pc,d0.w)
; ---------------------------------------------------------------------------

.levels:    dc.w PalCycGHZ-.levels, PalCycLZ-.levels, PalCycMZ-.levels, PalCycSLZ-.levels
	dc.w PalCycSYZ-.levels, PalCycSBZ-.levels, PalCycEnding-.levels
; ---------------------------------------------------------------------------

PalCycTitle:
; ---------------------------------------------------------------------------

PalCycGHZ:
	lea (word_186C).l,a0

loc_1760:
	subq.w	#1,(PalCycWait).w
	bpl.s	locret_1786
	move.w	#5,(PalCycWait).w
	move.w	(PalCycOffset).w,d0
	addq.w	#1,(PalCycOffset).w
	andi.w	#3,d0
	lsl.w	#3,d0
	lea ((Palette+$50)).w,a1
	move.l	(a0,d0.w),(a1)+
	move.l	4(a0,d0.w),(a1)

locret_1786:
	rts
; ---------------------------------------------------------------------------

PalCycLZ:
; ---------------------------------------------------------------------------

PalCycMZ:
	rts
; ---------------------------------------------------------------------------

PalCycSLZ:
	subq.w	#1,(PalCycWait).w
	bpl.s	locret_17F6
	move.w	#$F,(PalCycWait).w
	move.w	(PalCycOffset).w,d0
	addq.w	#1,d0
	cmpi.w	#6,d0
	bcs.s	loc_17D6
	moveq	#0,d0

loc_17D6:
	move.w	d0,(PalCycOffset).w
	move.w	d0,d1
	add.w	d1,d1
	add.w	d1,d0
	add.w	d0,d0
	lea (word_18F4).l,a0
	lea ((Palette+$56)).w,a1
	move.w	(a0,d0.w),(a1)
	move.l	2(a0,d0.w),4(a1)

locret_17F6:
	rts
; ---------------------------------------------------------------------------

PalCycSYZ:
	subq.w	#1,(PalCycWait).w
	bpl.s	locret_1846
	move.w	#5,(PalCycWait).w
	move.w	(PalCycOffset).w,d0
	move.w	d0,d1
	addq.w	#1,(PalCycOffset).w
	andi.w	#3,d0
	lsl.w	#3,d0
	lea (word_1918).l,a0
	lea ((Palette+$6E)).w,a1
	move.l	(a0,d0.w),(a1)+
	move.l	4(a0,d0.w),(a1)
	andi.w	#3,d1
	move.w	d1,d0
	add.w	d1,d1
	add.w	d0,d1
	add.w	d1,d1
	lea (word_1938).l,a0
	lea ((Palette+$76)).w,a1
	move.l	(a0,d1.w),(a1)
	move.w	4(a0,d1.w),6(a1)

locret_1846:
	rts
; ---------------------------------------------------------------------------

PalCycSBZ:
	rts
; ---------------------------------------------------------------------------

PalCycEnding:
	rts
; ---------------------------------------------------------------------------
word_186C:  incbin "unknown/0186C.pal"
	even
word_18F4:  incbin "unknown/018F4.pal"
	even
word_1918:  incbin "unknown/01918.pal"
	even
word_1938:  incbin "unknown/01938.pal"
	even
; ---------------------------------------------------------------------------

Pal_FadeTo:
	move.w	#$3F,(word_FFF626).w
; ---------------------------------------------------------------------------

Pal_FadeTo2:
	moveq	#0,d0
	lea (Palette).w,a0
	move.b	(word_FFF626).w,d0
	adda.w	d0,a0
	moveq	#0,d1
	move.b	(word_FFF626+1).w,d0

Pal_ToBlack:
	move.w	d1,(a0)+
	dbf d0,Pal_ToBlack
	move.w	#$14,d4

loc_1972:
	bsr.w	ProcessPLC
	move.b	#$12,(VintRoutine).w
	vsync
	bchg	#0,d6		      	; MJ: change delay counter
	beq.s	loc_1972		; MJ: if null, delay a frame
	bsr.s	Pal_FadeIn
	subq.b	#2,d4		      	; MJ: decrease colour check
	bne.s	loc_1972		; MJ: if it has not reached null, branch
	move.b	#$12,(VintRoutine).w
	vsync
	dbf d4,loc_1972
	rts
; ---------------------------------------------------------------------------

Pal_FadeIn:
	moveq	#0,d0
	lea (Palette).w,a0
	lea (PaletteTarget).w,a1
	move.b	(word_FFF626).w,d0
	adda.w	d0,a0
	adda.w	d0,a1
	move.b	(word_FFF626+1).w,d0

loc_199E:
	bsr.s	Pal_AddColor
	dbf d0,loc_199E
	rts
; ---------------------------------------------------------------------------

Pal_AddColor:
	move.b	(a1),d5 		; MJ: load blue
	move.w	(a1)+,d1		; MJ: load green and red
	move.b	d1,d2			; MJ: load red
	lsr.b	#4,d1		      	; MJ: get only green
	andi.b	#$E,d2		       	; MJ: get only red
	move.w	(a0),d3 		; MJ: load current colour in buffer
	cmp.b	d5,d4			; MJ: is it time for blue to fade?
	bhi.s	FCI_NoBlue		; MJ: if not, branch
	addi.w	#$200,d3     		; MJ: increase blue

FCI_NoBlue:
	cmp.b	d1,d4			; MJ: is it time for green to fade?
	bhi.s	FCI_NoGreen		; MJ: if not, branch
	addi.b	#$20,d3 		; MJ: increase green

FCI_NoGreen:
	cmp.b	d2,d4			; MJ: is it time for red to fade?
	bhi.s	FCI_NoRed		; MJ: if not, branch
	addq.b	#2,d3		      	; MJ: increase red

FCI_NoRed:
	move.w	d3,(a0)+		; MJ: save colour
	rts				; MJ: return
; ---------------------------------------------------------------------------

Pal_FadeFrom:
	move.w	#$3F,(word_FFF626).w
	move.w	#$14,d4

loc_19DC:
	move.b	#$12,(VintRoutine).w
	vsync
	bsr.s	Pal_FadeOut
	bsr.w	ProcessPLC
	dbf d4,loc_19DC
	rts
; ---------------------------------------------------------------------------

Pal_FadeOut:
	moveq	#0,d0
	lea (Palette).w,a0
	move.b	(word_FFF626).w,d0
	adda.w	d0,a0
	move.b	(word_FFF626+1).w,d0

loc_1A02:
	bsr.s	sub_1A0A
	dbf d0,loc_1A02
	rts
; ---------------------------------------------------------------------------

sub_1A0A:
	move.w	(a0),d5 		; MJ: load colour
	move.w	d5,d1			; MJ: copy to d1
	move.b	d1,d2			; MJ: load green and red
	move.b	d1,d3			; MJ: load red
	andi.w	#$E00,d1	       	; MJ: get only blue
	beq.s	FCO_NoBlue		; MJ: if blue is finished, branch
	subi.w	#$200,d5	       	; MJ: decrease blue

FCO_NoBlue:
	andi.w	#$E0,d2 	      	; MJ: get only green (needs to be word)
	beq.s	FCO_NoGreen		; MJ: if green is finished, branch
	subi.b	#$20,d5 		; MJ: decrease green

FCO_NoGreen:
	andi.b	#$E,d3		       	; MJ: get only red
	beq.s	FCO_NoRed		; MJ: if red is finished, branch
	subq.b	#2,d5		      	; MJ: decrease red

FCO_NoRed:
	move.w	d5,(a0)+		; MJ: save new colour
	rts					; MJ: return
; ---------------------------------------------------------------------------

sub_1A3A:
	subq.w	#1,(PalCycWait).w
	bpl.s	locret_1A68
	move.w	#3,(PalCycWait).w
	move.w	(PalCycOffset).w,d0
	bmi.s	locret_1A68
	subq.w	#2,(PalCycOffset).w
	lea (word_1A6A).l,a0
	lea ((Palette+4)).w,a1
	adda.w	d0,a0
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.w	(a0)+,(a1)+

locret_1A68:
	rts
; ---------------------------------------------------------------------------
word_1A6A:  incbin "unknown/01A6A.pal"
	even
; ---------------------------------------------------------------------------

palLoadFade:
	lea (PaletteLoadTable).l,a1
	lsl.w	#3,d0
	adda.w	d0,a1
	movea.l (a1)+,a2
	movea.w (a1)+,a3
	adda.w	#$80,a3
	move.w	(a1)+,d7

loc_1ABC:
	move.l	(a2)+,(a3)+
	dbf d7,loc_1ABC
	rts
; ---------------------------------------------------------------------------

PalLoadNormal:
	lea (PaletteLoadTable).l,a1
	lsl.w	#3,d0
	adda.w	d0,a1
	movea.l (a1)+,a2
	movea.w (a1)+,a3
	move.w	(a1)+,d7

loc_1AD4:
	move.l	(a2)+,(a3)+
	dbf d7,loc_1AD4
	rts
; ---------------------------------------------------------------------------

PaletteLoadTable:
	dc.l	palSega
	dc.w	$FB00,	$1F
	dc.l	palTitle
	dc.w	$FB00,	$1F
	dc.l	palLevelSel
	dc.w	$FB00,	$1F
	dc.l	palSonic
	dc.w	$FB00,	7
	dc.l	palGHZ
	dc.w	$FB20,	$17
	dc.l	palLZ
	dc.w	$FB20,	$17
	dc.l	palMZ
	dc.w	$FB20,	$17
	dc.l	palSLZ
	dc.w	$FB20,	$17
	dc.l	palSYZ
	dc.w	$FB20,	$17
	dc.l	palSBZ
	dc.w	$FB20,	$17
	dc.l	palSpecial
	dc.w	$FB00,	$1F
	dc.l	palSplash
	dc.w	$FB00,	$1F
	even
palSega:  	incbin "screens/sega/Main.pal"
	even
palTitle:	incbin "screens/title/Main.pal"
	even
palLevelSel:	incbin "screens/title/Level Select.pal"
	even
palSonic:	incbin "levels/shared/Sonic/Sonic.pal"
	even
palGHZ:	incbin "levels/GHZ/Main.pal"
	even
palLZ:	incbin "levels/LZ/Main.pal"
	even
palMZ:	incbin "levels/MZ/Main.pal"
	even
palSLZ:	incbin "levels/SLZ/Main.pal"
	even
palSYZ:	incbin "levels/SYZ/Main.pal"
	even
palSBZ:	incbin "levels/SBZ/Main.pal"
	even
palSpecial:
palSplash:	incbin "Splash/SPLASHPAL.bin"
	even
; ---------------------------------------------------------------------------

RandomNumber:
	move.l	(RandomSeed).w,d1
	bne.s	.noreset
	move.l	#$2A6D365A,d1

.noreset:
	move.l	d1,d0
	asl.l	#2,d1
	add.l	d0,d1
	asl.l	#3,d1
	add.l	d0,d1
	move.w	d1,d0
	swap	d1
	add.w	d1,d0
	move.w	d0,d1
	swap	d1
	move.l	d1,(RandomSeed).w
	rts
; ---------------------------------------------------------------------------

GetSine:
	andi.w	#$FF,d0
	add.w	d0,d0
	addi.w	#$80,d0
	move.w	SineTable(pc,d0.w),d1
	subi.w	#$80,d0
	move.w	SineTable(pc,d0.w),d0
	rts
; ---------------------------------------------------------------------------
SineTable:	incbin "unsorted/sinetable.dat"
	even
; ---------------------------------------------------------------------------
GetSqrt:
		movem.l	d1-d2,-(sp)
		move.w	d0,d1
		swap	d1
		moveq	#0,d0
		move.w	d0,d1
		moveq	#7,d2

loc_22F4:
		rol.l	#2,d1
		add.w	d0,d0
		addq.w	#1,d0
		sub.w	d0,d1
		bcc.s	loc_230E
		add.w	d0,d1
		subq.w	#1,d0
		dbf	d2,loc_22F4
		lsr.w	#1,d0
		movem.l	(sp)+,d1-d2
		rts
; ---------------------------------------------------------------------------

loc_230E:
		addq.w	#1,d0
		dbf	d2,loc_22F4
		lsr.w	#1,d0
		movem.l	(sp)+,d1-d2
		rts
; ---------------------------------------------------------------------------

GetAngle:
	movem.l d3-d4,-(sp)
	moveq	#0,d3
	moveq	#0,d4
	move.w	d1,d3
	move.w	d2,d4
	or.w	d3,d4
	beq.s	loc_2378
	move.w	d2,d4
	tst.w	d3
	bpl.w	loc_2336
	neg.w	d3

loc_2336:
	tst.w	d4
	bpl.w	loc_233E
	neg.w	d4

loc_233E:
	cmp.w	d3,d4
	bcc.w	loc_2350
	lsl.l	#8,d4
	divu.w	d3,d4
	moveq	#0,d0
	move.b	AngleTable(pc,d4.w),d0
	bra.s	loc_235A
; ---------------------------------------------------------------------------

loc_2350:
	lsl.l	#8,d3
	divu.w	d4,d3
	moveq	#$40,d0
	sub.b	AngleTable(pc,d3.w),d0

loc_235A:
	tst.w	d1
	bpl.w	loc_2366
	neg.w	d0
	addi.w	#$80,d0

loc_2366:
	tst.w	d2
	bpl.w	loc_2372
	neg.w	d0
	addi.w	#$100,d0

loc_2372:
	movem.l (sp)+,d3-d4
	rts
; ---------------------------------------------------------------------------

loc_2378:
	move.w	#$40,d0
	movem.l (sp)+,d3-d4
	rts
; ---------------------------------------------------------------------------
AngleTable:	incbin "unsorted/angletable.dat"
	even
; ---------------------------------------------------------------------------

sSega:
	command mus_FadeOut
	bsr.w	ClearPLC
	bsr.w	Pal_FadeFrom
	clr.b	(DontIntMus).w

	clrRAM	Chunks
	clrRAM	Layout
	clrRAM	Blocks
	clrRAM	ObjectsList

	lea (VdpCtrl).l,a6
	move.w	#$8004,(a6)
	move.w	#$8230,(a6)
	move.w	#$8407,(a6)
	move.w	#$8700,(a6)
	move.w	#$8B00,(a6)
	move.w	#$8100|%10000001,(a6)
	move.w	(ModeReg2).w,d0
	andi.b	#$BF,d0
	move.w	d0,(VdpCtrl).l
	bsr.w	ClearScreen
	lea (ArtSega).l,a0
	move.w	#0,d0
	jsr TwimDec
	lea ((Chunks)&$FFFFFF).l,a1
	lea (MapSega).l,a0
	move.w	#0,d0
	bsr.w	EnigmaDec
	copyTilemap64 (Chunks)&$FFFFFF,$C61C,$B,3,0
	move.w	#$28,(PalCycOffset).w
	move.w	#5*60,(GlobalTimer).w
	move.w	(ModeReg2).w,d0
	ori.b	#$40,d0
	move.w	d0,(VdpCtrl).l
	moveq	#0,d0
	bsr.w	PalLoadFade
	bsr.w	Pal_FadeTo
	music	mus_SEGA, 0

loc_2528:
	move.b	#2,(VintRoutine).w
	vsync
	bsr.w	sub_1A3A
	tst.w	(GlobalTimer).w
	beq.s	loc_2544
	andi.b	#J_S,(padPress1).w
	beq.s	loc_2528

loc_2544:

; ---------------------------------------------------------------------------
; ============================================================================================
; Splash Screen example
; This version is for splash screens that load AFTER the SEGA screen
; For a version that replaces the SEGA screen, read the guide this code came from!
; 2014, Hitaxas
; Ported to Sonic 1 Hivebrain 2005 Thanks to ProjectFM
; ============================================================================================
SplashScreen:
	bsr.w	Pal_FadeFrom				; fade palette out
	bsr.w	ClearScreen				; clear the plane mappings

	; initalize VDP
	lea (VdpCtrl).l,a6
	move.w	#$8004,(a6)
	btst	#6,(ConsoleRegion).w			; is this a PAL machine?
	beq.s	.noextendedres				; if not, continue
	move.w	#$8100|%01111100,(a6)
.noextendedres:
	move.w	#$8230,(a6)
	move.w	#$8407,(a6)
	move.w	#$8700,(a6)
	move.w	#$8B00,(a6)
	move.w	#$8C00|%10000001,(a6)

	; load art, mappings and the palette
	lea	((Chunks)&$FFFFFF).l,a1			; load dump location
	lea	MapSplash.l,a0				; load compressed mappings address
	move.w	#$140,d0				; prepare pattern index value to patch to mappings
	bsr.w	EniDec					; decompress and dump
	copyTilemap64 (Chunks)&$FFFFFF,$C000,$27,$1E,0	; flush mappings to VRAM
	move.l	#$68000000,($C00004).l			; set vdp loc
	lea	ArtSplash.l,a0				; load background art
	jsr	NemesisDec				; run NemDec to decompress art for display
	move.b	#$B,d0
	bsr.w	PalLoadFade
	bsr.w 	Pal_FadeTo				; fade palette in
	move.w	#5*60,(GlobalTimer).w			; set delay time (5 seconds on a 60hz system)

Splash_MainLoop:
	move.b	#2,(VintRoutine).w			; set V-blank routine to run
	vsync						; wait for V-blank (decreases "Demo_Time_left")
	tst.b	(padPress1).w				; has player 1 pressed the start button?
	bmi.s	Splash_GotoTitle			; if so, branch
	tst.w	(GlobalTimer).w				; has the delay time finished?
	bne.s	Splash_MainLoop				; if not, branch

Splash_GotoTitle:
	move.b	#4,(GameMode).w				; set the screen mode to Title Screen
	rts						; return
; ---------------------------------------------------------------------------

sTitle:
	command mus_FadeOut
	bsr.w	ClearPLC
	bsr.w	Pal_FadeFrom
	clr.b	(DontIntMus).w
	lea (VdpCtrl).l,a6
	move.w	#$8004,(a6)
	move.w	#$8230,(a6)
	move.w	#$8407,(a6)
	move.w	#$9001,(a6)
	move.w	#$9200,(a6)
	move.w	#$8B03,(a6)
	move.w	#$8720,(a6)
	move.w	#$8C00|%10000001,(a6)
	move.w	(ModeReg2).w,d0
	andi.b	#$BF,d0
	move.w	d0,(VdpCtrl).l
	bsr.w	ClearScreen

	clrRAM	Chunks
	clrRAM	Blocks
	clrRAM	Layout
	clrRAM	ScrollBuffer
	clrRAM	ObjectsList
	clrRAM	NemBuffer

	lea (ArtTitleMain).l,a0
	move.w	#$4000,d0
	jsr	TwimDec
	lea (ArtTitleSonic).l,a0
	move.w	#$6000,d0
	jsr	TwimDec

	lea	((Chunks)&$FFFFFF).l,a1
	lea	MapTitle.l,a0
	moveq	#0,d0
	bsr.w	EniDec

	copyTilemap64	(Chunks)&$FFFFFF,$C208,$21,$15,0

	clr.w	(DebugRoutine).w
	clr.w	(DemoMode).w
	clr.w	(curzone).w
	bsr.w	LoadLevelBounds
	bsr.w	LevelScroll
	lea	(TilesTS).l,a0
	move.w	#0,d0
	jsr	TwimDec
	lea	(BlocksTS).l,a0
	lea	(Blocks).w,a1
	jsr	TwizDec
	lea	(ChunksTS).l,a0
	lea	((Chunks)&$FFFFFF).l,a1
	jsr	TwizDec
	bsr.w	LoadLayout
	lea	(VdpCtrl).l,a5
	lea	(VdpData).l,a6
	lea	(unk_FFF708).w,a3
	lea	((Layout+$40)).w,a4
	move.w	#$6000,d2
	bsr.w	sub_47B0
	moveq	#1,d0
	bsr.w	palLoadFade
	move.b	#2,(VintRoutine).w
	vsync
	music	mus_Title, 0
	clr.b	(EditModeFlag).w
	move.w	#$178,(GlobalTimer).w
	move.b	#$E,(byte_FFD040).w
	move.b	#$F,(byte_FFD080).w
	move.b	#$F,(byte_FFD0C0).w
	move.b	#2,(byte_FFD0C0+frame).w
	moveq	#0,d0
	bsr.w	plcReplace
	move.w	(ModeReg2).w,d0
	ori.b	#$40,d0
	move.w	d0,(VdpCtrl).l
	bsr.w	Pal_FadeTo

loc_26AE:
	move.b	#4,(VintRoutine).w
	vsync
	bsr.w	RunObjects
	bsr.w	LevelScroll
	bsr.w	ProcessMaps
	bsr.w	PalCycTitle
	bsr.w	ProcessPLC
	move.w	(ObjectsList+xpos).w,d0
	addq.w	#2,d0
	move.w	d0,(ObjectsList+xpos).w
	cmpi.w	#$1B00,d0
	blt.s	loc_26E4
	clr.b	(GameMode).w
	rts
; ---------------------------------------------------------------------------

loc_26E4:
	tst.w	(GlobalTimer).w
	beq.w	loc_27F8
	andi.b	#J_S,(padPress1).w
	beq.s	loc_26AE
	if DEBUG_BUILD=0
	btst	#JbA,(padHeld1).w
	beq.w	loc_27AA
	endif
	sfx	sfx_Woosh
	bsr.w	Pal_FadeFrom
	bsr.w	ClearScreen
	move.l	d0,(dword_FFF616).w

	lea (VdpData).l,a6
	move.l	#$50000003,4(a6)
	lea (ArtLSText).l,a5
	move.w	#$28F,d1

loc_25D8:
	move.w	(a5)+,(a6)
	dbf	d1,loc_25D8

	bsr.w	sub_292C
	moveq	#2,d0
	bsr.w	palLoadFade
	music	mus_Options, 1
	bsr.w	Pal_FadeTo

LevelSelect:
	move.b	#2,(VintRoutine).w
	vsync
	bsr.w	sub_28A6
	bsr.w	ProcessPLC
	tst.l	(plcList).w
	bne.s	LevelSelect
	move.w	(LevSelOption).w,d0
	cmpi.w	#$13,d0
	bne.s	LevSelLevCheckStart
	btst	#JbS,(padPress1).w 		; is Start pressed?
	bne.s	LevSelStartPress    		; if true, branch
	btst  	#JbC,(padPress1).w 		; is C pressed?
	bne.s	LevSelBCPress			; if not, branch
	btst  	#JbB,(padPress1).w 		; is B pressed?
	bne.s	LevSelBCPress			; if not, branch
	bra.s	LevelSelect
; ===========================================================================
LevSelLevCheckStart:
	andi.b	#J_S,(padPress1).w 		; is Start pressed?
	beq.s	LevelSelect    			; if not, branch
	bra.s	loc_2780
	
LevSelBCPress:
	move.w	(LevSelSound).w,d0

loc_277A:
	move.b	d0,mQueue+1.w
	bra.s	LevelSelect
	
LevSelStartPress:				; XREF: LevelSelect
	sfx 	sfx_Select
	clr.b	(GameMode).w
	rts
; ---------------------------------------------------------------------------

loc_2780:
	sfx 	sfx_Select
	add.w	d0,d0
	move.w	LevSelOrder(pc,d0.w),d0
	bmi.s	LevelSelect
	cmpi.w	#$700,d0
	bne.s	loc_2796
	move.b	#$10,(GameMode).w
	rts
; ---------------------------------------------------------------------------

loc_2796:
	andi.w	#$3FFF,d0
	if DEBUG_BUILD=1
	btst	#JbB,(padHeld1).w
	beq.s	loc_27A6
	move.w	#3,d0

loc_27A6:
	endif
	move.w	d0,(curzone).w

loc_27AA:
	move.b	#$C,(GameMode).w
	move.b	#3,(Lives).w
	moveq	#0,d0
	move.w	d0,(Rings).w
	move.l	d0,(dword_FFFE22).w
	move.l	d0,(dword_FFFE26).w
	rts
; ---------------------------------------------------------------------------

LevSelOrder:	dc.w 0,    1,	 2
	dc.w $100, $101, $102
	dc.w $200, $201, $202
	dc.w $300, $301, $302
	dc.w $400, $401, $402
	dc.w $500, $501,$502
	dc.w $8000, $8000,$8000
; ---------------------------------------------------------------------------

loc_27F8:
	move.w	#$1E,(GlobalTimer).w

loc_27FE:
	move.b	#4,(VintRoutine).w
	vsync
	bsr.w	LevelScroll
	bsr.w	PaletteCycle
	bsr.w	ProcessPLC
	move.w	(ObjectsList+xpos).w,d0
	addq.w	#2,d0
	move.w	d0,(ObjectsList+xpos).w
	cmpi.w	#$1C00,d0
	bcs.s	loc_282C
	clr.b	(GameMode).w
	rts
; ---------------------------------------------------------------------------

loc_282C:
	tst.w	(GlobalTimer).w
	bne.s	loc_27FE
	command mus_FadeOut
	move.w	(DemoNum).w,d0
	andi.w	#7,d0
	add.w	d0,d0
	move.w	DemoLevels(pc,d0.w),d0
	move.w	d0,(curzone).w
	addq.w	#1,(DemoNum).w
	cmpi.w	#6,(DemoNum).w
	bcs.s	loc_2860
	clr.w	(DemoNum).w

loc_2860:
	move.w	#1,(DemoMode).w
	move.b	#8,(GameMode).w
	cmpi.w	#$600,d0
	bne.s	loc_2878
	move.b	#$10,(GameMode).w

loc_2878:
	move.b	#3,(Lives).w
	moveq	#0,d0
	move.w	d0,(Rings).w
	move.l	d0,(dword_FFFE22).w
	move.l	d0,(dword_FFFE26).w
	rts
; ---------------------------------------------------------------------------

DemoLevels: dc.w 0, $100, $200, $300, $400, $500, $600
; ---------------------------------------------------------------------------

sub_28A6:
	move.b	(padPress1).w,d1
	andi.b	#J_U|J_D,d1
	bne.s	loc_28B6
	subq.b	#1,(word_FFF666).w
	bpl.s	loc_28F0

loc_28B6:
	move.b	#8,(word_FFF666).w
	move.b	(padHeld1).w,d1
	andi.b	#J_U|J_D,d1
	beq.s	loc_28F0
	move.w	(LevSelOption).w,d0
	btst	#JbU,d1
	beq.s	loc_28D6
	sfx	sfx_Pop
	subq.w	#1,d0
	bge.s	loc_28D6
	moveq	#$13,d0

loc_28D6:
	btst	#JbD,d1
	beq.s	loc_28E6
	sfx	sfx_Pop
	addq.w	#1,d0
	cmpi.w	#$14,d0
	blt.s	loc_28E6
	moveq	#0,d0

loc_28E6:
	move.w	d0,(LevSelOption).w
	bra.s	sub_292C
; ---------------------------------------------------------------------------

loc_28F0:
	cmpi.w	#$13,(LevSelOption).w
	bne.s	locret_292A
	move.b	(padPress1).w,d1
	andi.b	#J_L|J_R|J_A,d1
	beq.s	locret_292A
	move.w	(LevSelSound).w,d0
	btst	#JbA,d1       	; is A pressed?
	bne.s	LevSel_A    	; if not, branch
	btst	#JbL,d1
	beq.s	loc_2912
	sfx	sfx_Pop
	subq.w	#1,d0
	
LevSel_A:
	btst	#JbA,d1       	; is A button pressed?
	beq.s	loc_2912    	; if not, branch
	sfx	sfx_Pop
	addi.w	#16,d0	    	; add $10 to sound test

loc_2912:
	btst	#JbR,d1
	beq.s	loc_2922
	sfx	sfx_Pop
	addq.w	#1,d0

loc_2922:
	move.w	d0,(LevSelSound).w
	bra.s	sub_292C

locret_292A:
	rts
; ---------------------------------------------------------------------------

sub_292C:
	lea	(LevelSelectText).l,a1
	lea	(VdpData).l,a6
	move.l	#$62100003,d4
	move.w	#$E680,d3
	moveq	#$13,d1

loc_2944:
	move.l	d4,4(a6)
	bsr.w	sub_29CC
	addi.l	#$800000,d4
	dbf	d1,loc_2944
	moveq	#0,d0
	move.w	(LevSelOption).w,d0
	move.w	d0,d1
	move.l	#$62100003,d4
	lsl.w	#7,d0
	swap	d0
	add.l	d0,d4
	lea	(LevelSelectText).l,a1
	lsl.w	#3,d1
	move.w	d1,d0
	add.w	d1,d1
	add.w	d0,d1
	adda.w	d1,a1
	move.w	#$C680,d3
	move.l	d4,4(a6)
	bsr.w	sub_29CC
	move.w	#$E680,d3
	cmpi.w	#$13,(LevSelOption).w
	bne.s	loc_2996
	move.w	#$C680,d3

loc_2996:
	move.l	#$6BB00003,(VdpCtrl).l
	move.w	(LevSelSound).w,d0
	move.b	d0,d2
	lsr.b	#4,d0
	bsr.s	sub_29B8
	move.b	d2,d0
; ---------------------------------------------------------------------------

sub_29B8:
	andi.w	#$F,d0
	cmpi.b	#$A,d0
	bcs.s	loc_29C6
	addq.b	#4,d0

loc_29C6:
	add.w	d3,d0
	move.w	d0,(a6)
	rts
; ---------------------------------------------------------------------------

sub_29CC:
	moveq	#$17,d2

loc_29CE:
	moveq	#0,d0
	move.b	(a1)+,d0
	bpl.s	loc_29DE
	move.w	#0,(a6)
	dbf	d2,loc_29CE
	rts
; ---------------------------------------------------------------------------

loc_29DE:
	cmpi.w	#$40,d0		; Check for 0x40/64 (End of ASCII number area)
	blt.s	.notText	; If this is not an ASCII text character, branch
	subq.w	#3,d0		; Subtract an extra 3, to compensate for the
.notText:			; missing characters in the font
	subi.w	#$30,d0		; Subtract 0x30/48 (ASCII to S2 font)
	add.w	d3,d0	    	; combine character with VRAM setting
	move.w	d0,(a6)     	; send to VRAM
	dbf	d2,loc_29CE
	rts
; ---------------------------------------------------------------------------

LevelSelectText:
	dc.b    'GREEN HILL         ACT 1'
	dc.b    '                   ACT 2'
	dc.b    '                   ACT 3'
	dc.b    'LABYRINTH          ACT 1'
	dc.b    '                   ACT 2'
	dc.b    '                   ACT 3'
	dc.b    'MARBLE             ACT 1'
	dc.b    '                   ACT 2'
	dc.b    '                   ACT 3'
	dc.b    'STAR LIGHT         ACT 1'
	dc.b    '                   ACT 2'
	dc.b    '                   ACT 3'
	dc.b    'SPARKLING          ACT 1'
	dc.b    '                   ACT 2'
	dc.b    '                   ACT 3'
	dc.b    'SCRAP BRAIN        ACT 1'
	dc.b    '                   ACT 2'
	dc.b    '                   ACT 3'
	dc.b    'SPECIAL STAGE          X'
	dc.b    'SOUND SELECT            '
	even

MusicList:  dc.b mus_GHZ, mus_LZ, mus_MZ, mus_SLZ, mus_SYZ, mus_SBZ
	even
; ---------------------------------------------------------------------------

sLevel:
	tst.b	(DontIntMus).w
	bne.s	.notset
	clr.b	(DontIntMus).w
	command mus_FadeOut
	bsr.w	ClearPLC
.notset
	bsr.w	Pal_FadeFrom
	move.l	#$70000002,($C00004).l
	lea ArtTitleCards,a0
	move.l	#((ArtTitleCards_End-ArtTitleCards)/32)-1,d0
	jsr LoadUncArt
	bsr.w	ClearScreen
	moveq	#0,d0
	move.b	(curzone).w,d0
	lsl.w	#4,d0
	lea (LevelDataArray).l,a2
	lea (a2,d0.w),a2
	moveq	#0,d0
	move.b	(a2),d0
	beq.s	loc_2C0A
	bsr.w	plcReplace

loc_2C0A:
	moveq	#1,d0
	bsr.w	plcAdd
	lea (VdpCtrl).l,a6
	move.w	#$8B03,(a6)
	move.w	#$8230,(a6)
	move.w	#$8407,(a6)
	move.w	#$857C,(a6)
	clr.w	(word_FFFFE8).w
	move.w	#$8AAF,(word_FFF624).w
	move.w	#$8004,(a6)
	move.w	#$8720,(a6)
	;btst	 #6,(ConsoleRegion).w	 ; is this a PAL machine?
	;beq.s	 .cont		 ; if not, continue
	;move.w  #$8100|%01111100,(a6)
;.cont
	clrRAM	ObjectsList
	lea (CameraX).w,a1
	moveq	#0,d0
	move.w	#$3F,d1

loc_2C5C:
	move.l	d0,(a1)+
	dbf d1,loc_2C5C

	lea ((oscValues+2)).w,a1
	moveq	#0,d0
	move.w	#$27,d1

loc_2C6C:
	move.l	d0,(a1)+
	dbf d1,loc_2C6C

	moveq	#3,d0
	bsr.w	PalLoadNormal
	tst.b	(DontIntMus).w 		; DW: has the RAM been set?
	bne.s	MusicLoop	 	; DW: if yes, branch and skip the music loading code below
	moveq	#0,d0
	move.b	(curzone).w,d0
	lea (MusicList).l,a1
	move.b	(a1,d0.w),d0
	move.b	d0,SavedSong.w
	waitmsu
	addi.w	#MSUc_PLAYLOOP,d0
	move.w	d0,MCD_CMD ; send cmd: play track, loop
	addq.b	#1,MCD_CMD_CK ; Increment command clock
MusicLoop:
	clr.b	(DontIntMus).w
	move.b	#$34,(byte_FFD080).w

loc_2C92:
	move.b	#$C,(VintRoutine).w
	vsync
	bsr.w	RunObjects
	bsr.w	ProcessMaps
	bsr.w	ProcessPLC
	move.w	(byte_FFD100+8).w,d0
	cmp.w	(byte_FFD100+$30).w,d0
	bne.s	loc_2C92
	tst.l	(plcList).w
	bne.s	loc_2C92
	jsr sub_117C6
	moveq	#3,d0
	bsr.w	palLoadFade
	bsr.w	LoadLevelBounds
	bsr.w	LevelScroll
	bsr.w	LoadLevelData
	bsr.w	mapLevelLoadFull
	bsr.w	ColIndexLoad
	move.b	#1,(ObjectsList).w
	move.b	#$21,(byte_FFD040).w
	btst	#JbA,(padHeld1).w
	beq.s	loc_2D54
	move.b	#1,(EditModeFlag).w

loc_2D54:
	clr.w	(padHeldPlayer).w
	clr.w	(padHeld1).w
	bsr.w	LoadObjects
	bsr.w	RunObjects
	bsr.w	ProcessMaps
	moveq	#0,d0
	move.w	d0,(Rings).w
	move.b	d0,(byte_FFFE1B).w
	move.l	d0,(dword_FFFE22).w
	move.b	d0,(byte_FFFE2C).w
	move.b	d0,(byte_FFFE2D).w
	move.b	d0,(byte_FFFE2E).w
	move.b	d0,(byte_FFFE2F).w
	move.w	d0,(DebugRoutine).w
	move.b	d0,(LevelRestart).w
	move.w	d0,(LevelFrames).w
	bsr.w	oscInit
	st.b	(byte_FFFE1F).w
	move.b	#1,(ExtraLifeFlags).w
	move.b	#1,(byte_FFFE1E).w
	clr.w	(unk_FFF790).w
	lea	(off_3100).l,a1
	moveq	#0,d0
	move.b	(curzone).w,d0
	lsl.w	#2,d0
	movea.l (a1,d0.w),a1
	move.w	#$708,(GlobalTimer).w
	move.b	#8,(VintRoutine).w
	vsync
	move.w	#$202F,(word_FFF626).w
	bsr.w	Pal_FadeTo2
	addq.b	#2,(byte_FFD080+$24).w
	addq.b	#4,(byte_FFD0C0+$24).w
	addq.b	#4,(byte_FFD100+$24).w
	addq.b	#4,(byte_FFD140+$24).w

sLevelLoop:
	bsr.w	PauseGame
	move.b	#8,(VintRoutine).w
	vsync
	addq.w	#1,(LevelFrames).w
	bsr.w	sub_3048
	bsr.w	DemoPlayback
	move.w	(padHeld1).w,(padHeldPlayer).w
	bsr.w	RunObjects
	tst.b	(LevelRestart).w
	bne.w	sLevel
	bsr.w	LevelScroll
	bsr.w	ProcessMaps
	bsr.w	LoadObjects
	bsr.w	PaletteCycle
	bsr.w	ProcessPLC
	bsr.w	oscUpdate
	bsr.w	UpdateTimers
	bsr.w	LoadSignpostPLC
	cmpi.b	#8,(GameMode).w
	beq.s	loc_2E66
	cmpi.b	#$C,(GameMode).w
	beq.s	sLevelLoop
	rts
; ---------------------------------------------------------------------------

loc_2E66:
	tst.b	(LevelRestart).w
	bne.s	loc_2E84
	tst.w	(GlobalTimer).w
	beq.s	loc_2E84
	cmpi.b	#8,(GameMode).w
	beq.s	sLevelLoop
	clr.b	(GameMode).w
	rts
; ---------------------------------------------------------------------------

loc_2E84:
	cmpi.b	#8,(GameMode).w
	bne.s	loc_2E92
	clr.b	(GameMode).w

loc_2E92:
	move.w	#$3C,(GlobalTimer).w
	move.w	#$3F,(word_FFF626).w

loc_2E9E:
	move.b	#8,(VintRoutine).w
	vsync
	bsr.w	DemoPlayback
	bsr.w	RunObjects
	bsr.w	ProcessMaps
	bsr.w	LoadObjects
	subq.w	#1,(unk_FFF794).w
	bpl.s	loc_2EC8
	move.w	#2,(unk_FFF794).w
	bsr.w	Pal_FadeOut

loc_2EC8:
	tst.w	(GlobalTimer).w
	bne.s	loc_2E9E
	rts
	
; ---------------------------------------------------------------------------

sub_3048:
	btst	#JbU,(padHeld1).w
	beq.s	loc_305E
	addq.w	#1,(unk_FFF71C).w
	tst.b	(word_FFF624+1).w
	beq.s	loc_305E
	subq.b	#1,(word_FFF624+1).w

loc_305E:
	btst	#JbD,(padHeld1).w
	beq.s	locret_3076
	subq.w	#1,(unk_FFF71C).w
	cmpi.b	#$DF,(word_FFF624+1).w
	beq.s	locret_3076
	addq.b	#1,(word_FFF624+1).w

locret_3076:
	rts
; ---------------------------------------------------------------------------

DemoPlayback:
	if DEMO_RECORD=0
		tst.w	(DemoMode).w
		bne.s	loc_30B8
		rts
; ---------------------------------------------------------------------------

DemoRecord:
	endif
		move.b	#1,($A130F1).l
		lea	($200000).l,a1
		move.w	(unk_FFF790).w,d0
		adda.w	d0,a1
		move.b	(padHeld1).w,d0
		cmp.b	(a1),d0
		bne.s	loc_30A2
		addq.b	#1,1(a1)
		cmpi.b	#$FF,1(a1)
		beq.s	loc_30A2
		rts
; ---------------------------------------------------------------------------

loc_30A2:
		move.b	d0,2(a1)
		move.b	#0,3(a1)
		addq.w	#2,(unk_FFF790).w
		andi.w	#$3FF,(unk_FFF790).w
		move.b	#0,($A130F1).l
		rts
; ---------------------------------------------------------------------------

loc_30B8:
		tst.b	(padHeld1).w
		bpl.s	loc_30C4
		move.b	#4,(GameMode).w

loc_30C4:
		lea	(off_3100).l,a1
		moveq	#0,d0
		move.b	(curzone).w,d0
		lsl.w	#2,d0
		movea.l	(a1,d0.w),a1
		move.w	(unk_FFF790).w,d0
		adda.w	d0,a1
		move.b	(a1),d0
		lea	(padHeld1).w,a0
		move.b	d0,d1
		move.b	(a0),d2
		eor.b	d2,d0
		move.b	d1,(a0)+
		and.b	d1,d0
		move.b	d0,(a0)+
		subq.b	#1,(unk_FFF792).w
		bcc.s	locret_30FE
		move.b	3(a1),(unk_FFF792).w
		addq.w	#2,(unk_FFF790).w

locret_30FE:
		rts
; ---------------------------------------------------------------------------

off_3100:   dc.l demoin_GHZ, demoin_LZ, demoin_MZ, demoin_SLZ, demoin_MZ
	dc.l demoin_GHZ, demoin_SS
; ---------------------------------------------------------------------------

oscInit:
	lea (oscValues).w,a1
	lea (oscInitTable).l,a2
	moveq	#$20,d1

loc_336C:
	move.w	(a2)+,(a1)+
	dbf d1,loc_336C
	rts
; ---------------------------------------------------------------------------

oscInitTable:	dc.w $7C, $80, 0, $80, 0, $80, 0, $80, 0, $80, 0, $80
	dc.w 0, $80, 0, $80, 0, $80, 0, $50F0, $11E, $2080, $B4
	dc.w $3080, $10E, $5080, $1C2, $7080, $276, $80, 0, $80
	dc.w 0
; ---------------------------------------------------------------------------

oscUpdate:
	cmpi.b #6,(ObjectsList+act).w
	bcc.s	locret_340C
	lea (oscValues).w,a1
	lea (oscUpdateTable).l,a2
	move.w	(a1)+,d3
	moveq	#$F,d1

loc_33CC:
	move.w	(a2)+,d2
	move.w	(a2)+,d4
	btst	d1,d3
	bne.s	loc_33EC
	move.w	2(a1),d0
	add.w	d2,d0
	move.w	d0,2(a1)
	add.w	d0,id(a1)
	cmp.b	id(a1),d4
	bhi.s	loc_3402
	bset	d1,d3
	bra.s	loc_3402
; ---------------------------------------------------------------------------

loc_33EC:
	move.w	2(a1),d0
	sub.w	d2,d0
	move.w	d0,2(a1)
	add.w	d0,id(a1)
	cmp.b	id(a1),d4
	bls.s	loc_3402
	bclr	d1,d3

loc_3402:
	addq.w	#4,a1
	dbf d1,loc_33CC
	move.w	d3,(oscValues).w

locret_340C:
	rts
; ---------------------------------------------------------------------------

oscUpdateTable: dc.w 2, $10
	dc.w 2, $18
	dc.w 2, $20
	dc.w 2, $30
	dc.w 4, $20
	dc.w 8, 8
	dc.w 8, $40
	dc.w 4, $40
	dc.w 2, $50
	dc.w 2, $50
	dc.w 2, $20
	dc.w 3, $30
	dc.w 5, $50
	dc.w 7, $70
	dc.w 2, $10
	dc.w 2, $10
; ---------------------------------------------------------------------------

UpdateTimers:
	subq.b	#1,(GHZSpikeTimer).w
	bpl.s	loc_3464
	move.b	#$B,(GHZSpikeTimer).w
	subq.b	#1,(GHZSpikeFrame).w
	andi.b	#7,(GHZSpikeFrame).w

loc_3464:
	subq.b	#1,(RingTimer).w
	bpl.s	loc_347A
	move.b	#7,(RingTimer).w
	addq.b	#1,(RingFrame).w
	andi.b	#3,(RingFrame).w

loc_347A:
	subq.b	#1,(UnkTimer).w
	bpl.s	loc_3498
	move.b	#7,(UnkTimer).w
	addq.b	#1,(UnkFrame).w
	cmpi.b	#6,(UnkFrame).w
	bcs.s	loc_3498
	clr.b	(UnkFrame).w

loc_3498:
	tst.b	(RingLossTimer).w
	beq.s	locret_34BA
	moveq	#0,d0
	move.b	(RingLossTimer).w,d0
	add.w	(RingLossAccumulator).w,d0
	move.w	d0,(RingLossAccumulator).w
	rol.w	#7,d0
	andi.w	#3,d0
	move.b	d0,(RingLossFrame).w
	subq.b	#1,(RingLossTimer).w

locret_34BA:
	rts
; ---------------------------------------------------------------------------

LoadSignpostPLC:
	tst.w	(DebugRoutine).w
	bne.s	locret_34FA
	cmpi.w	#$202,(curzone).w
	beq.s	loc_34D4
	cmpi.b	#2,(curact).w
	beq.s	locret_34FA

loc_34D4:
	move.w	(CameraX).w,d0
	move.w	(unk_FFF72A).w,d1
	subi.w	#$100,d1
	cmp.w	d1,d0
	blt.s	locret_34FA
	tst.b	(byte_FFFE1E).w
	beq.s	locret_34FA
	cmp.w	(unk_FFF728).w,d1
	beq.s	locret_34FA
	move.w	d1,(unk_FFF728).w
	moveq	#$12,d0
	bra.w	plcReplace
; ---------------------------------------------------------------------------

locret_34FA:
	rts
; ---------------------------------------------------------------------------

sSpecial:
	command mus_FadeOut
	bsr.w	ClearPLC
	bsr.w	Pal_FadeFrom
	clr.b	(DontIntMus).w
	Console.Run 	sSpecial_MSG
	rts

sSpecial_MSG:
	Console.SetXY		#2,#11
	Console.WriteLine   	"Hate to break it to you, but"
	Console.WriteLine   	"there's no special stages."
	Console.BreakLine
	Console.WriteLine	"I don't know if I'll add one."
	Console.WriteLine	"Press %<pal3>START%<pal0> to reset."
	Console.WriteLine	"Thank you for your understanding."
	Console.WriteLine	"~ RepellantMold, as of June 2021"
	rts
; ---------------------------------------------------------------------------

LoadLevelBounds:
	moveq	#0,d0
	move.b	d0,(unk_FFF740).w
	move.b	d0,(unk_FFF741).w
	move.b	d0,(unk_FFF746).w
	move.b	d0,(unk_FFF748).w
	move.b	d0,(EventsRoutine).w
	move.w	(curzone).w,d0
	lsl.b	#6,d0
	lsr.w	#4,d0
	move.w	d0,d1
	add.w	d0,d0
	add.w	d1,d0
	lea LevelBoundArray(pc,d0.w),a0
	move.w	(a0)+,d0
	move.w	d0,(unk_FFF730).w
	move.l	(a0)+,d0
	move.l	d0,(unk_FFF728).w
	move.l	d0,(unk_FFF720).w
	cmp.w	(unk_FFF728).w,d0
	bne.s	loc_3AF2
	move.b	#1,(unk_FFF740).w

loc_3AF2:
	move.l	(a0)+,d0
	move.l	d0,(unk_FFF72C).w
	move.l	d0,(unk_FFF724).w
	cmp.w	(unk_FFF72C).w,d0
	bne.s	loc_3B08
	move.b	#1,(unk_FFF741).w

loc_3B08:
	move.w	(unk_FFF728).w,d0
	addi.w	#$240,d0
	move.w	d0,(unk_FFF732).w
	move.w	(a0)+,d0
	move.w	d0,(unk_FFF73E).w
	bra.w	loc_3C6E
; ---------------------------------------------------------------------------

LevelBoundArray:
	dc.w 4, 0, $24BF, 0, $300, $60
	dc.w 4, 0, $1EBF, 0, $300, $60
	dc.w 4, 0, $2960, 0, $300, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $17BF, 0, $720, $60
	dc.w 4, 0, $EBF, 0, $720, $60
	dc.w 4, 0, $1EBF, 0, $720, $60
	dc.w 4, 0, $1EBF, 0, $720, $60
	dc.w 4, 0, $17BF, 0, $1D0, $60
	dc.w 4, 0, $1BBF, 0, $520, $60
	dc.w 4, 0, $163F, 0, $720, $60
	dc.w 4, 0, $16BF, 0, $720, $60
	dc.w 4, 0, $1EBF, 0, $640, $60
	dc.w 4, 0, $20BF, 0, $640, $60
	dc.w 4, 0, $1EBF, 0, $6C0, $60
	dc.w 4, 0, $3EC0, 0, $720, $60
	dc.w 4, 0, $22C0, 0, $420, $60
	dc.w 4, 0, $28C0, 0, $520, $60
	dc.w 4, 0, $2EC0, 0, $620, $60
	dc.w 4, 0, $29C0, 0, $620, $60
	dc.w 4, 0, $3EC0, 0, $720, $60
	dc.w 4, 0, $3EC0, 0, $720, $60
	dc.w 4, 0, $3EC0, 0, $720, $60
	dc.w 4, 0, $3EC0, 0, $720, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
	dc.w 4, 0, $2FFF, 0, $320, $60
; ---------------------------------------------------------------------------

loc_3C6E:
	move.w	(curzone).w,d0
	cmpi.b	#3,d0
	bne.s	loc_3C7C
	subq.b	#1,(curact).w

loc_3C7C:
	lsl.b	#6,d0
	lsr.w	#4,d0
	lea StartPosArray(pc,d0.w),a1
	moveq	#0,d1
	move.w	(a1)+,d1
	move.w	d1,(ObjectsList+xpos).w
	subi.w	#$A0,d1
	bcc.s	loc_3C94
	moveq	#0,d1

loc_3C94:
	move.w	d1,(CameraX).w
	moveq	#0,d0
	move.w	(a1),d0
	move.w	d0,(ObjectsList+ypos).w
	subi.w	#$60,d0
	bcc.s	loc_3CA8
	moveq	#0,d0

loc_3CA8:
	cmp.w	(unk_FFF72E).w,d0
	blt.s	loc_3CB2
	move.w	(unk_FFF72E).w,d0

loc_3CB2:
	move.w	d0,(CameraY).w
	bsr.w	initLevelBG
	moveq	#0,d0
	move.b	(curzone).w,d0
	lsl.b	#2,d0
	move.l	SpecialChunkArray(pc,d0.w),(unk_FFF7AC).w
	bra.w	LoadLevelUnk
; ---------------------------------------------------------------------------
StartPosArray:	incbin "levels/GHZ/Start 1.dat"
	incbin "levels/GHZ/Start 2.dat"
	incbin "levels/GHZ/Start 3.dat"
	incbin "levels/GHZ/Start 4.dat"
	incbin "levels/LZ/Start 1.dat"
	incbin "levels/LZ/Start 2.dat"
	incbin "levels/LZ/Start 3.dat"
	incbin "levels/LZ/Start 4.dat"
	incbin "levels/MZ/Start 1.dat"
	incbin "levels/MZ/Start 2.dat"
	incbin "levels/MZ/Start 3.dat"
	incbin "levels/MZ/Start 4.dat"
	incbin "levels/SLZ/Start 1.dat"
	incbin "levels/SLZ/Start 2.dat"
	incbin "levels/SLZ/Start 3.dat"
	incbin "levels/SLZ/Start 4.dat"
	incbin "levels/SYZ/Start 1.dat"
	incbin "levels/SYZ/Start 2.dat"
	incbin "levels/SYZ/Start 3.dat"
	incbin "levels/SYZ/Start 4.dat"
	incbin "levels/SBZ/Start 1.dat"
	incbin "levels/SBZ/Start 2.dat"
	incbin "levels/SBZ/Start 3.dat"
	incbin "levels/SBZ/Start 4.dat"
	even

SpecialChunkArray:
	dc.b $B5, $7F, $1F, $20     ; loop, loop, S-tunnel, S-tunnel (set to $7F if you don't have such)
	dc.b $7F, $7F, $7F, $7F
	dc.b $7F, $7F, $7F, $7F
	dc.b $B5, $A8, $7F, $7F
	dc.b $7F, $7F, $7F, $7F
	dc.b $7F, $7F, $7F, $7F
; ---------------------------------------------------------------------------

LoadLevelUnk:
	moveq	#0,d0
	move.b	(curzone).w,d0
	lsl.w	#3,d0
	lea dword_3D6A(pc,d0.w),a1
	lea (unk_FFF7F0).w,a2
	move.l	(a1)+,(a2)+
	move.l	(a1)+,(a2)+
	rts
; ---------------------------------------------------------------------------

dword_3D6A: dc.l $700100, $1000100
	dc.l $8000100, $1000000
	dc.l $8000100, $1000000
	dc.l $8000100, $1000000
	dc.l $8000100, $1000000
	dc.l $8000100, $1000000
; ---------------------------------------------------------------------------

initLevelBG:
	move.w	d0,(unk_FFF70C).w
	move.w	d0,(unk_FFF714).w
	swap	d1
	move.l	d1,(unk_FFF708).w
	move.l	d1,(unk_FFF710).w
	move.l	d1,(unk_FFF718).w
	moveq	#0,d2
	move.b	(curzone).w,d2
	add.w	d2,d2
	move.w	off_3DC0(pc,d2.w),d2
	jmp off_3DC0(pc,d2.w)
; ---------------------------------------------------------------------------

off_3DC0:   dc.w InitBGHZ-off_3DC0, initLevelLZ-off_3DC0, initLevelMZ-off_3DC0, initLevelSLZ-off_3DC0
	dc.w initLevelSYZ-off_3DC0, initLevelSBZ-off_3DC0, InitBGHZ-off_3DC0
; ---------------------------------------------------------------------------

InitBGHZ:
	bra.w	HScrollGHZ
; ---------------------------------------------------------------------------

initLevelLZ:
	rts
; ---------------------------------------------------------------------------

initLevelMZ:
	rts
; ---------------------------------------------------------------------------

initLevelSLZ:
	asr.l	#1,d0
	addi.w	#$C0,d0
	move.w	d0,(unk_FFF70C).w
	rts
; ---------------------------------------------------------------------------

initLevelSYZ:
	asl.l	#4,d0
	move.l	d0,d2
	asl.l	#1,d0
	add.l	d2,d0
	asr.l	#8,d0
	move.w	d0,(unk_FFF70C).w
	move.w	d0,(unk_FFF714).w
	rts
; ---------------------------------------------------------------------------

initLevelSBZ:
	rts
; ---------------------------------------------------------------------------

LevelScroll:
	tst.b	(unk_FFF744).w
	bne.s	loc_3E18
	tst.b	(unk_FFF740).w
	bne.w	loc_4258
	bsr.w	camMoveHoriz

loc_3E08:
	tst.b	(unk_FFF741).w
	bne.w	loc_4276
	bsr.w	camMoveVerti

loc_3E14:
	bsr.w	LevelEvents

loc_3E18:
	move.w	(CameraX).w,(dword_FFF61A).w
	move.w	(CameraY).w,(dword_FFF616).w
	move.w	(unk_FFF708).w,(dword_FFF61A+2).w
	move.w	(unk_FFF70C).w,(dword_FFF616+2).w
	move.w	(unk_FFF718).w,(word_FFF620).w
	move.w	(unk_FFF71C).w,(word_FFF61E).w
	moveq	#0,d0
	move.b	(curzone).w,d0
	add.w	d0,d0
	move.w	.scroll(pc,d0.w),d0
	jmp .scroll(pc,d0.w)
; ---------------------------------------------------------------------------

.scroll:    dc.w HScrollGHZ-.scroll, HScrollLZ-.scroll, HScrollMZ-.scroll, HScrollSLZ-.scroll
	dc.w HScrollSYZ-.scroll, HScrollSBZ-.scroll, HScrollGHZ-.scroll
; ---------------------------------------------------------------------------

HScrollGHZ:
	move.w	(unk_FFF73A).w,d4
	ext.l	d4
	asl.l	#5,d4
	move.l	d4,d1
	asl.l	#1,d4
	add.l	d1,d4
	moveq	#0,d5
	bsr.w	sub_4298
	bsr.w	sub_4374
	lea (ScrollTable).w,a1
	move.w	(CameraY).w,d0
	andi.w	#$7FF,d0
	lsr.w	#5,d0
	neg.w	d0
	addi.w	#$26,d0
	move.w	d0,(unk_FFF714).w
	move.w	d0,d4
	bsr.w	sub_4344
	move.w	(unk_FFF70C).w,(dword_FFF616+2).w
	move.w	#$6F,d1
	sub.w	d4,d1
	move.w	(CameraX).w,d0
	cmpi.b	#4,(GameMode).w ; is the screen mode the title screen?
	bne.s	loc_3EA8    ; if not, branch
	moveq	#0,d0	    ; prevent the emblem from moving

loc_3EA8:
	neg.w	d0
	swap	d0
	move.w	(unk_FFF708).w,d0
	neg.w	d0

loc_3EB2:
	move.l	d0,(a1)+
	dbf d1,loc_3EB2
	move.w	#$27,d1
	move.w	(unk_FFF710).w,d0
	neg.w	d0

loc_3EC2:
	move.l	d0,(a1)+
	dbf d1,loc_3EC2
	move.w	(unk_FFF710).w,d0
	addi.w	#0,d0
	move.w	(CameraX).w,d2
	addi.w	#-$200,d2
	sub.w	d0,d2
	ext.l	d2
	asl.l	#8,d2
	divs.w	#$68,d2
	ext.l	d2
	asl.l	#8,d2
	moveq	#0,d3
	move.w	d0,d3
	move.w	#$47,d1
	add.w	d4,d1

loc_3EF0:
	move.w	d3,d0
	neg.w	d0
	move.l	d0,(a1)+
	swap	d3
	add.l	d2,d3
	swap	d3
	dbf d1,loc_3EF0
	rts
; ---------------------------------------------------------------------------

HScrollLZ:
	lea (ScrollTable).w,a1
	move.w	#$DF,d1
	move.w	(CameraX).w,d0
	neg.w	d0
	swap	d0
	move.w	(unk_FFF708).w,d0
	move.w	#0,d0
	neg.w	d0

loc_3F1C:
	move.l	d0,(a1)+
	dbf d1,loc_3F1C
	rts
; ---------------------------------------------------------------------------

HScrollMZ:
	move.w	(unk_FFF73A).w,d4
	ext.l	d4
	asl.l	#6,d4
	move.l	d4,d1
	asl.l	#1,d4
	add.l	d1,d4
	moveq	#0,d5
	bsr.w	sub_4298
	move.w	#$200,d0
	move.w	(CameraY).w,d1
	subi.w	#$1C8,d1
	bcs.s	loc_3F50
	move.w	d1,d2
	add.w	d1,d1
	add.w	d2,d1
	asr.w	#2,d1
	add.w	d1,d0

loc_3F50:
	move.w	d0,(unk_FFF714).w
	bsr.w	sub_4344
	move.w	(unk_FFF70C).w,(dword_FFF616+2).w
	lea (ScrollTable).w,a1
	move.w	#$DF,d1
	move.w	(CameraX).w,d0
	neg.w	d0
	swap	d0
	move.w	(unk_FFF708).w,d0
	neg.w	d0

loc_3F74:
	move.l	d0,(a1)+
	dbf d1,loc_3F74
	rts
; ---------------------------------------------------------------------------

HScrollSLZ:
	move.w	(unk_FFF73A).w,d4
	ext.l	d4
	asl.l	#7,d4
	move.w	(unk_FFF73C).w,d5
	ext.l	d5
	asl.l	#7,d5
	bsr.w	sub_4302
	move.w	(unk_FFF70C).w,(dword_FFF616+2).w
	bsr.w	sub_3FF6
	lea (ScrollBuffer).w,a2
	move.w	(unk_FFF70C).w,d0
	move.w	d0,d2
	subi.w	#$C0,d0
	andi.w	#$3F0,d0
	lsr.w	#3,d0
	lea (a2,d0.w),a2
	lea (ScrollTable).w,a1
	move.w	#$E,d1
	move.w	(CameraX).w,d0
	neg.w	d0
	swap	d0
	andi.w	#$F,d2
	add.w	d2,d2
	move.w	(a2)+,d0
	jmp loc_3FD0(pc,d2.w)
; ---------------------------------------------------------------------------

loc_3FCE:
	move.w	(a2)+,d0

loc_3FD0:
	rept 16
	move.l	d0,(a1)+
	endr
	dbf d1,loc_3FCE
	rts
; ---------------------------------------------------------------------------

sub_3FF6:
	lea (ScrollBuffer).w,a1
	move.w	(CameraX).w,d2
	neg.w	d2
	move.w	d2,d0
	asr.w	#3,d0
	sub.w	d2,d0
	ext.l	d0
	asl.l	#4,d0
	divs.w	#$1C,d0
	ext.l	d0
	asl.l	#4,d0
	asl.l	#8,d0
	moveq	#0,d3
	move.w	d2,d3
	move.w	#$1B,d1

loc_401C:
	move.w	d3,(a1)+
	swap	d3
	add.l	d0,d3
	swap	d3
	dbf d1,loc_401C
	move.w	d2,d0
	asr.w	#3,d0
	move.w	#4,d1

loc_4030:
	move.w	d0,(a1)+
	dbf d1,loc_4030
	move.w	d2,d0
	asr.w	#2,d0
	move.w	#4,d1

loc_403E:
	move.w	d0,(a1)+
	dbf d1,loc_403E
	move.w	d2,d0
	asr.w	#1,d0
	move.w	#$1D,d1

loc_404C:
	move.w	d0,(a1)+
	dbf d1,loc_404C
	rts
; ---------------------------------------------------------------------------

HScrollSYZ:
	move.w	(unk_FFF73A).w,d4
	ext.l	d4
	asl.l	#6,d4
	move.w	(unk_FFF73C).w,d5
	ext.l	d5
	asl.l	#4,d5
	move.l	d5,d1
	asl.l	#1,d5
	add.l	d1,d5
	bsr.w	sub_4298
	move.w	(unk_FFF70C).w,(dword_FFF616+2).w
	lea (ScrollTable).w,a1
	move.w	#$DF,d1
	move.w	(CameraX).w,d0
	neg.w	d0
	swap	d0
	move.w	(unk_FFF708).w,d0
	neg.w	d0

loc_408A:
	move.l	d0,(a1)+
	dbf d1,loc_408A
	rts
; ---------------------------------------------------------------------------

HScrollSBZ:
	lea (ScrollTable).w,a1
	move.w	#$DF,d1
	move.w	(CameraX).w,d0
	neg.w	d0
	swap	d0
	move.w	(unk_FFF708).w,d0
	move.w	#0,d0
	neg.w	d0

loc_40AC:
	move.l	d0,(a1)+
	dbf d1,loc_40AC
	rts 
	
; ---------------------------------------------------------------------------

camMoveHoriz:
	move.w	(CameraX).w,d4
	bsr.s	sub_40E8
	move.w	(CameraX).w,d0
	andi.w	#$10,d0
	move.b	(unk_FFF74A).w,d1
	eor.b	d1,d0
	bne.s	locret_40E6
	eori.b	#$10,(unk_FFF74A).w
	move.w	(CameraX).w,d0
	sub.w	d4,d0
	bpl.s	loc_40E0
	bset	#2,(unk_FFF754).w
	rts
; ---------------------------------------------------------------------------

loc_40E0:
	bset	#3,(unk_FFF754).w

locret_40E6:
	rts
; ---------------------------------------------------------------------------

sub_40E8:
	move.w	(ObjectsList+xpos).w,d0
	sub.w	(CameraX).w,d0
	subi.w	#$90,d0
	bmi.s	loc_412C
	subi.w	#$10,d0
	bpl.s	loc_4102
	clr.w	(unk_FFF73A).w
	rts
; ---------------------------------------------------------------------------

loc_4102:
	cmpi.w	#$10,d0
	bcs.s	loc_410C
	move.w	#$10,d0

loc_410C:
	add.w	(CameraX).w,d0
	cmp.w	(unk_FFF72A).w,d0
	blt.s	loc_411A
	move.w	(unk_FFF72A).w,d0

loc_411A:
	move.w	d0,d1
	sub.w	(CameraX).w,d1
	asl.w	#8,d1
	move.w	d0,(CameraX).w
	move.w	d1,(unk_FFF73A).w
	rts
; ---------------------------------------------------------------------------

loc_412C:
	cmpi.w	#$FFF0,d0		; has the screen moved more than 10 pixels left?
	bcc.s	Left_NoMax		; if not, branch
	move.w	#$FFF0,d0		; set the maximum move distance to 10 pixels left

Left_NoMax:
	add.w	(CameraX).w,d0
	cmp.w	(unk_FFF728).w,d0
	bgt.s	loc_411A
	move.w	(unk_FFF728).w,d0
	bra.s	loc_411A
; ---------------------------------------------------------------------------

loc_4146:
	move.w	#2,d0
	bra.s	loc_4102
; ---------------------------------------------------------------------------

camMoveVerti:
	moveq	#0,d1
	move.w	(ObjectsList+ypos).w,d0
	sub.w	(CameraY).w,d0
	btst	#2,(ObjectsList+status).w
	beq.s	loc_4160
	subq.w	#5,d0

loc_4160:
	btst	#1,(ObjectsList+status).w
	beq.s	loc_4180
	addi.w	#$20,d0
	sub.w	(unk_FFF73E).w,d0
	bcs.s	loc_41BE
	subi.w	#$40,d0
	bcc.s	loc_41BE
	tst.b	(unk_FFF75C).w
	bne.s	loc_41D0
	bra.s	loc_418C
; ---------------------------------------------------------------------------

loc_4180:
	sub.w	(unk_FFF73E).w,d0
	bne.s	loc_4192
	tst.b	(unk_FFF75C).w
	bne.s	loc_41D0

loc_418C:
	clr.w	(unk_FFF73C).w
	rts
; ---------------------------------------------------------------------------

loc_4192:
	cmpi.w	#$60,(unk_FFF73E).w
	bne.s	loc_41AC
	move.w	#$600,d1
	cmpi.w	#6,d0
	bgt.s	loc_4200
	cmpi.w	#$FFFA,d0
	blt.s	loc_41E8
	bra.s	loc_41D6
; ---------------------------------------------------------------------------

loc_41AC:
	move.w	#$200,d1
	cmpi.w	#2,d0
	bgt.s	loc_4200
	cmpi.w	#$FFFE,d0
	blt.s	loc_41E8
	bra.s	loc_41D6
; ---------------------------------------------------------------------------

loc_41BE:
	move.w	#$1000,d1
	cmpi.w	#$10,d0
	bgt.s	loc_4200
	cmpi.w	#$FFF0,d0
	blt.s	loc_41E8
	bra.s	loc_41D6
; ---------------------------------------------------------------------------

loc_41D0:
	moveq	#0,d0
	move.b	d0,(unk_FFF75C).w

loc_41D6:
	moveq	#0,d1
	move.w	d0,d1
	add.w	(CameraY).w,d1
	tst.w	d0
	bpl.w	loc_420A
	bra.w	loc_41F4
; ---------------------------------------------------------------------------

loc_41E8:
	neg.w	d1
	ext.l	d1
	asl.l	#8,d1
	add.l	(CameraY).w,d1
	swap	d1

loc_41F4:
	cmp.w	(unk_FFF72C).w,d1
	bgt.s	loc_4214
	move.w	(unk_FFF72C).w,d1
	bra.s	loc_4214
; ---------------------------------------------------------------------------

loc_4200:
	ext.l	d1
	asl.l	#8,d1
	add.l	(CameraY).w,d1
	swap	d1

loc_420A:
	cmp.w	(unk_FFF72E).w,d1
	blt.s	loc_4214
	move.w	(unk_FFF72E).w,d1

loc_4214:
	move.w	(CameraY).w,d4
	swap	d1
	move.l	d1,d3
	sub.l	(CameraY).w,d3
	ror.l	#8,d3
	move.w	d3,(unk_FFF73C).w
	move.l	d1,(CameraY).w
	move.w	(CameraY).w,d0
	andi.w	#$10,d0
	move.b	(unk_FFF74B).w,d1
	eor.b	d1,d0
	bne.s	locret_4256
	eori.b	#$10,(unk_FFF74B).w
	move.w	(CameraY).w,d0
	sub.w	d4,d0
	bpl.s	loc_4250
	bset	#0,(unk_FFF754).w
	rts
; ---------------------------------------------------------------------------

loc_4250:
	bset	#1,(unk_FFF754).w

locret_4256:
	rts
; ---------------------------------------------------------------------------

loc_4258:
	move.w	(unk_FFF728).w,d0
	moveq	#1,d1
	sub.w	(CameraX).w,d0
	beq.s	loc_426E
	bpl.s	loc_4268
	moveq	#-1,d1

loc_4268:
	add.w	d1,(CameraX).w
	move.w	d1,d0

loc_426E:
	move.w	d0,(unk_FFF73A).w
	bra.w	loc_3E08
; ---------------------------------------------------------------------------

loc_4276:
	move.w	(unk_FFF72C).w,d0
	addi.w	#$40,d0
	moveq	#1,d1
	sub.w	(CameraY).w,d0
	beq.s	loc_4290
	bpl.s	loc_428A
	moveq	#-1,d1

loc_428A:
	add.w	d1,(CameraY).w
	move.w	d1,d0

loc_4290:
	move.w	d0,(unk_FFF73C).w
	bra.w	loc_3E14
; ---------------------------------------------------------------------------

sub_4298:
	move.l	(unk_FFF708).w,d2
	move.l	d2,d0
	add.l	d4,d0
	move.l	d0,(unk_FFF708).w
	move.l	d0,d1
	swap	d1
	andi.w	#$10,d1
	move.b	(unk_FFF74C).w,d3
	eor.b	d3,d1
	bne.s	loc_42CC
	eori.b	#$10,(unk_FFF74C).w
	sub.l	d2,d0
	bpl.s	loc_42C6
	bset	#2,(unk_FFF756).w
	bra.s	loc_42CC
; ---------------------------------------------------------------------------

loc_42C6:
	bset	#3,(unk_FFF756).w

loc_42CC:
	move.l	(unk_FFF70C).w,d3
	move.l	d3,d0
	add.l	d5,d0
	move.l	d0,(unk_FFF70C).w
	move.l	d0,d1
	swap	d1
	andi.w	#$10,d1
	move.b	(unk_FFF74D).w,d2
	eor.b	d2,d1
	bne.s	locret_4300
	eori.b	#$10,(unk_FFF74D).w
	sub.l	d3,d0
	bpl.s	loc_42FA
	bset	#0,(unk_FFF756).w
	rts
; ---------------------------------------------------------------------------

loc_42FA:
	bset	#1,(unk_FFF756).w

locret_4300:
	rts
; ---------------------------------------------------------------------------

sub_4302:
	move.l	(unk_FFF708).w,d2
	move.l	d2,d0
	add.l	d4,d0
	move.l	d0,(unk_FFF708).w
	move.l	(unk_FFF70C).w,d3
	move.l	d3,d0
	add.l	d5,d0
	move.l	d0,(unk_FFF70C).w
	move.l	d0,d1
	swap	d1
	andi.w	#$10,d1
	move.b	(unk_FFF74D).w,d2
	eor.b	d2,d1
	bne.s	locret_4342
	eori.b	#$10,(unk_FFF74D).w
	sub.l	d3,d0
	bpl.s	loc_433C
	bset	#0,(unk_FFF756).w
	rts
; ---------------------------------------------------------------------------

loc_433C:
	bset	#1,(unk_FFF756).w

locret_4342:
	rts
; ---------------------------------------------------------------------------

sub_4344:
	move.w	(unk_FFF70C).w,d3
	move.w	d0,(unk_FFF70C).w
	move.w	d0,d1
	andi.w	#$10,d1
	move.b	(unk_FFF74D).w,d2
	eor.b	d2,d1
	bne.s	locret_4372
	eori.b	#$10,(unk_FFF74D).w
	sub.w	d3,d0
	bpl.s	loc_436C
	bset	#0,(unk_FFF756).w
	rts
; ---------------------------------------------------------------------------

loc_436C:
	bset	#1,(unk_FFF756).w

locret_4372:
	rts
; ---------------------------------------------------------------------------

sub_4374:
	move.w	(unk_FFF710).w,d2
	move.w	(unk_FFF714).w,d3
	move.w	(unk_FFF73A).w,d0
	ext.l	d0
	asl.l	#7,d0
	add.l	d0,(unk_FFF710).w
	move.w	(unk_FFF710).w,d0
	andi.w	#$10,d0
	move.b	(unk_FFF74E).w,d1
	eor.b	d1,d0
	bne.s	locret_43B4
	eori.b	#$10,(unk_FFF74E).w
	move.w	(unk_FFF710).w,d0
	sub.w	d2,d0
	bpl.s	loc_43AE
	bset	#2,(unk_FFF758).w
	bra.s	locret_43B4
; ---------------------------------------------------------------------------

loc_43AE:
	bset	#3,(unk_FFF758).w

locret_43B4:
	rts
; ---------------------------------------------------------------------------

sub_43B6:
	lea (VdpCtrl).l,a5
	lea (VdpData).l,a6
	lea (unk_FFF756).w,a2
	lea (unk_FFF708).w,a3
	lea ((Layout+$40)).w,a4
	move.w	#$6000,d2
	bsr.w	sub_4484
	lea (unk_FFF758).w,a2
	lea (unk_FFF710).w,a3
	bra.w	sub_4524
; ---------------------------------------------------------------------------

mapLevelLoad:
	lea (VdpCtrl).l,a5
	lea (VdpData).l,a6
	lea (unk_FFF756).w,a2
	lea (unk_FFF708).w,a3
	lea ((Layout+$40)).w,a4
	move.w	#$6000,d2
	bsr.w	sub_4484
	lea (unk_FFF758).w,a2
	lea (unk_FFF710).w,a3
	bsr.w	sub_4524
	lea (unk_FFF754).w,a2
	lea (CameraX).w,a3
	lea (Layout).w,a4
	move.w	#$4000,d2
	tst.b	(a2)
	beq.s	locret_4482
	bclr	#0,(a2)
	beq.s	loc_4438
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4608

loc_4438:
	bclr	#1,(a2)
	beq.s	loc_4452
	move.w	#$E0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	move.w	#$E0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4608

loc_4452:
	bclr	#2,(a2)
	beq.s	loc_4468
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4634

loc_4468:
	bclr	#3,(a2)
	beq.s	locret_4482
	moveq	#$FFFFFFF0,d4
	move.w	#$140,d5
	bsr.w	sub_4752
	moveq	#$FFFFFFF0,d4
	move.w	#$140,d5
	bsr.w	sub_4634

locret_4482:
	rts
; ---------------------------------------------------------------------------

sub_4484:
	tst.b	(a2)
	beq.w	locret_4522
	bclr	#0,(a2)
	beq.s	loc_44A2
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	moveq	#$1F,d6
	bsr.w	sub_460A

loc_44A2:
	bclr	#1,(a2)
	beq.s	loc_44BE
	move.w	#$E0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	move.w	#$E0,d4
	moveq	#$FFFFFFF0,d5
	moveq	#$1F,d6
	bsr.w	sub_460A

loc_44BE:
	bclr	#2,(a2)
	beq.s	loc_44EE
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	moveq	#$FFFFFFF0,d4
	moveq	#$FFFFFFF0,d5
	move.w	(unk_FFF7F0).w,d6
	move.w	4(a3),d1
	andi.w	#$FFF0,d1
	sub.w	d1,d6
	blt.s	loc_44EE
	lsr.w	#4,d6
	cmpi.w	#$F,d6
	bcs.s	loc_44EA
	moveq	#$F,d6

loc_44EA:
	bsr.w	sub_4636

loc_44EE:
	bclr	#3,(a2)
	beq.s	locret_4522
	moveq	#$FFFFFFF0,d4
	move.w	#$140,d5
	bsr.w	sub_4752
	moveq	#$FFFFFFF0,d4
	move.w	#$140,d5
	move.w	(unk_FFF7F0).w,d6
	move.w	4(a3),d1
	andi.w	#$FFF0,d1
	sub.w	d1,d6
	blt.s	locret_4522
	lsr.w	#4,d6
	cmpi.w	#$F,d6
	bcs.s	loc_451E
	moveq	#$F,d6

loc_451E:
	bsr.w	sub_4636

locret_4522:
	rts
; ---------------------------------------------------------------------------

sub_4524:
	tst.b	(a2)
	beq.w	locret_45B0
	bclr	#2,(a2)
	beq.s	loc_456E
	cmpi.w	#$10,(a3)
	bcs.s	loc_456E
	move.w	(unk_FFF7F0).w,d4
	move.w	4(a3),d1
	andi.w	#$FFF0,d1
	sub.w	d1,d4
	move.w	d4,-(sp)
	moveq	#$FFFFFFF0,d5
	bsr.w	sub_4752
	move.w	(sp)+,d4
	moveq	#$FFFFFFF0,d5
	move.w	(unk_FFF7F0).w,d6
	move.w	4(a3),d1
	andi.w	#$FFF0,d1
	sub.w	d1,d6
	blt.s	loc_456E
	lsr.w	#4,d6
	subi.w	#$E,d6
	bcc.s	loc_456E
	neg.w	d6
	bsr.w	sub_4636

loc_456E:
	bclr	#3,(a2)
	beq.s	locret_45B0
	move.w	(unk_FFF7F0).w,d4
	move.w	4(a3),d1
	andi.w	#$FFF0,d1
	sub.w	d1,d4
	move.w	d4,-(sp)
	move.w	#$140,d5
	bsr.w	sub_4752
	move.w	(sp)+,d4
	move.w	#$140,d5
	move.w	(unk_FFF7F0).w,d6
	move.w	4(a3),d1
	andi.w	#$FFF0,d1
	sub.w	d1,d6
	blt.s	locret_45B0
	lsr.w	#4,d6
	subi.w	#$E,d6
	bcc.s	locret_45B0
	neg.w	d6
	bsr.w	sub_4636

locret_45B0:
	rts
; ---------------------------------------------------------------------------

sub_4608:
	moveq	#$15,d6
; ---------------------------------------------------------------------------

sub_460A:
	move.l	#$800000,d7
	move.l	d0,d1

loc_4612:
	movem.l d4-d5,-(sp)
	bsr.w	sub_4706
	move.l	d1,d0
	bsr.w	sub_4662
	addq.b	#4,d1
	andi.b	#$7F,d1
	movem.l (sp)+,d4-d5
	addi.w	#$10,d5
	dbf d6,loc_4612
	rts
; ---------------------------------------------------------------------------

sub_4634:
	moveq	#$F,d6
; ---------------------------------------------------------------------------

sub_4636:
	move.l	#$800000,d7
	move.l	d0,d1

loc_463E:
	movem.l d4-d5,-(sp)
	bsr.w	sub_4706
	move.l	d1,d0
	bsr.w	sub_4662
	addi.w	#$100,d1
	andi.w	#$FFF,d1
	movem.l (sp)+,d4-d5
	addi.w	#$10,d4
	dbf d6,loc_463E
	rts
; ---------------------------------------------------------------------------

sub_4662:
	or.w	d2,d0
	swap	d0
	btst	#4,(a0)
	bne.s	loc_469E
	btst	#3,(a0)
	bne.s	loc_467E
	move.l	d0,(a5)
	move.l	(a1)+,(a6)
	add.l	d7,d0
	move.l	d0,(a5)
	move.l	(a1)+,(a6)
	rts
; ---------------------------------------------------------------------------

loc_467E:
	move.l	d0,(a5)
	move.l	(a1)+,d4
	eori.l	#$8000800,d4
	swap	d4
	move.l	d4,(a6)
	add.l	d7,d0
	move.l	d0,(a5)
	move.l	(a1)+,d4
	eori.l	#$8000800,d4
	swap	d4
	move.l	d4,(a6)
	rts
; ---------------------------------------------------------------------------

loc_469E:
	btst	#3,(a0)
	bne.s	loc_46C0
	move.l	d0,(a5)
	move.l	(a1)+,d5
	move.l	(a1)+,d4
	eori.l	#$10001000,d4
	move.l	d4,(a6)
	add.l	d7,d0
	move.l	d0,(a5)
	eori.l	#$10001000,d5
	move.l	d5,(a6)
	rts
; ---------------------------------------------------------------------------

loc_46C0:
	move.l	d0,(a5)
	move.l	(a1)+,d5
	move.l	(a1)+,d4
	eori.l	#$18001800,d4
	swap	d4
	move.l	d4,(a6)
	add.l	d7,d0
	move.l	d0,(a5)
	eori.l	#$18001800,d5
	swap	d5
	move.l	d5,(a6)
	rts
; ---------------------------------------------------------------------------

sub_4706:
	lea (Blocks).w,a1
	add.w	4(a3),d4
	add.w	(a3),d5
	move.w	d4,d3
	lsr.w	#1,d3
	andi.w	#$380,d3
	lsr.w	#3,d5
	move.w	d5,d0
	lsr.w	#5,d0
	andi.w	#$7F,d0
	add.w	d3,d0
	moveq	#$FFFFFFFF,d3
	move.b	(a4,d0.w),d3
	andi.b	#$7F,d3
	beq.s	locret_4750
	subq.b	#1,d3
	ext.w	d3
	ror.w	#7,d3
	add.w	d4,d4
	andi.w	#$1E0,d4
	andi.w	#$1E,d5
	add.w	d4,d3
	add.w	d5,d3
	movea.l d3,a0
	move.w	(a0),d3
	andi.w	#$3FF,d3
	lsl.w	#3,d3
	adda.w	d3,a1

locret_4750:
	rts
; ---------------------------------------------------------------------------

sub_4752:
	add.w	4(a3),d4
	add.w	(a3),d5
	andi.w	#$F0,d4
	andi.w	#$1F0,d5
	lsl.w	#4,d4
	lsr.w	#2,d5
	add.w	d5,d4
	moveq	#3,d0
	swap	d0
	move.w	d4,d0
	rts
; ---------------------------------------------------------------------------

sub_476E:
	add.w	4(a3),d4
	add.w	(a3),d5
	andi.w	#$F0,d4
	andi.w	#$1F0,d5
	lsl.w	#4,d4
	lsr.w	#2,d5
	add.w	d5,d4
	moveq	#2,d0
	swap	d0
	move.w	d4,d0
	rts
; ---------------------------------------------------------------------------

mapLevelLoadFull:
	lea (VdpCtrl).l,a5
	lea (VdpData).l,a6
	lea (CameraX).w,a3
	lea (Layout).w,a4
	move.w	#$4000,d2
	bsr.s	sub_47B0
	lea (unk_FFF708).w,a3
	lea ((Layout+$40)).w,a4
	move.w	#$6000,d2
; ---------------------------------------------------------------------------

sub_47B0:
	moveq	#$FFFFFFF0,d4
	moveq	#$F,d6

loc_47B4:
	movem.l d4-d6,-(sp)
	moveq	#0,d5
	move.w	d4,d1
	bsr.w	sub_4752
	move.w	d1,d4
	moveq	#0,d5
	moveq	#$1F,d6
	bsr.w	sub_460A
	movem.l (sp)+,d4-d6
	addi.w	#$10,d4
	dbf d6,loc_47B4
	rts
; ---------------------------------------------------------------------------

LoadLevelData:
	moveq	#0,d0
	move.b	(curzone).w,d0
	lsl.w	#4,d0
	lea (LevelDataArray).l,a2
	lea (a2,d0.w),a2
	move.l	a2,-(sp)
	addq.l	#4,a2
	movea.l (a2)+,a0
	lea (Blocks).w,a1
	moveq	#0,d0
	bsr.w	EnigmaDec
	movea.l (a2)+,a0
	lea ((Chunks)&$FFFFFF).l,a1
	bsr.w	KosinskiPlusDec
	bsr.w	LoadLayout
	move.w	(a2)+,d0
	move.w	(a2),d0
	andi.w	#$FF,d0
	bsr.w	palLoadFade
	movea.l (sp)+,a2
	addq.w	#4,a2
	moveq	#0,d0
	move.b	(a2),d0
	beq.s	locret_485A
	bsr.w	plcAdd

locret_485A:
	rts
	
; ---------------------------------------------------------------------------
; Collision index loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


ColIndexLoad:		    ; XREF: Level
	moveq	#0,d0
	move.b	(curzone).w,d0
	lsl.w	#2,d0
	move.l	ColPointers(pc,d0.w),(Collision).w
	rts
; End of function ColIndexLoad

ColPointers:
	dc.l	colGHZ, colLZ, colMZ, colSLZ, colSYZ, colSBZ, colGHZ	    
; ---------------------------------------------------------------------------

sub_489E:
	moveq	#0,d3
	moveq	#3,d1
	sub.w	d0,d1
	bcs.s	loc_48AC

loc_48A6:
	move.l	d3,(a6)
	dbf d1,loc_48A6

loc_48AC:
	move.w	d0,d1
	subq.w	#1,d1
	bcs.s	locret_48B8

loc_48B2:
	move.l	d2,(a6)
	dbf d1,loc_48B2

locret_48B8:
	rts
; ---------------------------------------------------------------------------

LoadLayout:
	lea (Layout).w,a3
	move.w	#$1FF,d1
	moveq	#0,d0

loc_48C4:
	move.l	d0,(a3)+
	dbf d1,loc_48C4
	lea (Layout).w,a3
	moveq	#0,d1
	bsr.w	sub_48DA
	lea ((Layout+$40)).w,a3
	moveq	#2,d1
; ---------------------------------------------------------------------------

sub_48DA:
	move.w	(curzone).w,d0
	lsl.b	#6,d0
	lsr.w	#5,d0
	move.w	d0,d2
	add.w	d0,d0
	add.w	d2,d0
	add.w	d1,d0
	lea (LayoutArray).l,a1
	move.w	(a1,d0.w),d0
	lea (a1,d0.w),a1
	moveq	#0,d1
	move.w	d1,d2
	move.b	(a1)+,d1
	move.b	(a1)+,d2

loc_4900:
	move.w	d1,d0
	movea.l a3,a0

loc_4904:
	move.b	(a1)+,(a0)+
	dbf d0,loc_4904
	lea $80(a3),a3
	dbf d2,loc_4900
	rts
; ---------------------------------------------------------------------------

LevelEvents:
	moveq	#0,d0
	move.b	(curzone).w,d0
	add.w	d0,d0
	move.w	off_495E(pc,d0.w),d0
	jsr off_495E(pc,d0.w)
	tst.w	(DebugRoutine).w
	beq.s	loc_4936
	clr.w	(unk_FFF72C).w
	move.w	#$720,(unk_FFF726).w

loc_4936:
	moveq	#2,d1
	move.w	(unk_FFF726).w,d0
	sub.w	(unk_FFF72E).w,d0
	beq.s	locret_495C
	bcc.s	loc_4952
	move.w	(CameraY).w,(unk_FFF72E).w
	andi.w	#$FFFE,(unk_FFF72E).w
	neg.w	d1

loc_4952:
	add.w	d1,(unk_FFF72E).w
	st.b	(unk_FFF75C).w

locret_495C:
	rts
; ---------------------------------------------------------------------------

off_495E:   dc.w EventsGHZ-off_495E, EventsNull-off_495E, EventsMZ-off_495E, EventsNull-off_495E
	dc.w EventsNull-off_495E, EventsNull-off_495E, EventsNull-off_495E
; ---------------------------------------------------------------------------

EventsNull:
	rts
; ---------------------------------------------------------------------------

EventsGHZ:
	moveq	#0,d0
	move.b	(curact).w,d0
	add.w	d0,d0
	move.w	off_497C(pc,d0.w),d0
	jmp off_497C(pc,d0.w)
; ---------------------------------------------------------------------------

off_497C:   dc.w EventsGHZ1-off_497C, EventsGHZ2-off_497C, EventsGHZ3-off_497C, EventsGHZ3-off_497C
; ---------------------------------------------------------------------------

EventsGHZ1:
	move.w	#$300,(unk_FFF726).w
	cmpi.w	#$1780,(CameraX).w
	ble.s	locret_4996
	move.w	#$400,(unk_FFF726).w

locret_4996:
	rts
; ---------------------------------------------------------------------------

EventsGHZ2:
	move.w	#$300,(unk_FFF726).w
	cmpi.w	#$1600,(CameraX).w
	blt.s	locret_49C8
	move.w	#$400,(unk_FFF726).w
	cmpi.w	#$1D60,(CameraX).w
	bcs.s	locret_49C8
	move.w	#$300,(unk_FFF726).w

locret_49C8:
	rts
; ---------------------------------------------------------------------------

EventsGHZ3:
	moveq	#0,d0
	move.b	(EventsRoutine).w,d0
	move.w	off_49D8(pc,d0.w),d0
	jmp off_49D8(pc,d0.w)
; ---------------------------------------------------------------------------

off_49D8:   dc.w loc_49DE-off_49D8, loc_4A32-off_49D8, loc_4A78-off_49D8
; ---------------------------------------------------------------------------

loc_49DE:
	move.w	#$300,(unk_FFF726).w
	cmpi.w	#$380,(CameraX).w
	bcs.s	locret_4A24
	move.w	#$310,(unk_FFF726).w
	cmpi.w	#$960,(CameraX).w
	bcs.s	locret_4A24
	cmpi.w	#$280,(CameraY).w
	bcs.s	loc_4A26
	move.w	#$400,(unk_FFF726).w
	cmpi.w	#$1380,(CameraX).w
	bcc.s	loc_4A1C
	move.w	#$4C0,(unk_FFF726).w
	move.w	#$4C0,(unk_FFF72E).w

loc_4A1C:
	cmpi.w	#$1700,(CameraX).w
	bcc.s	loc_4A26

locret_4A24:
	rts
; ---------------------------------------------------------------------------

loc_4A26:
	move.w	#$300,(unk_FFF726).w
	addq.b	#2,(EventsRoutine).w
	rts
; ---------------------------------------------------------------------------

loc_4A32:
	cmpi.w	#$960,(CameraX).w
	bcc.s	loc_4A3E
	subq.b	#2,(EventsRoutine).w

loc_4A3E:
	cmpi.w	#$2960,(CameraX).w
	bcs.s	locret_4A76
	bsr.w	ObjectLoad
	bne.s	loc_4A5E
	move.b	#$3D,id(a1)
	move.w	#$2A60,xpos(a1)
	move.w	#$280,ypos(a1)

loc_4A5E:
	music	mus_Boss, 1
	move.b	#1,(unk_FFF7AA).w
	addq.b	#2,(EventsRoutine).w
	moveq	#$11,d0
	bra.w	plcAdd
; ---------------------------------------------------------------------------

locret_4A76:
	rts
; ---------------------------------------------------------------------------

loc_4A78:
	move.w	(CameraX).w,(unk_FFF728).w
	rts
; ---------------------------------------------------------------------------

EventsMZ:
	moveq	#0,d0
	move.b	(curact).w,d0
	add.w	d0,d0
	move.w	off_4A90(pc,d0.w),d0
	jmp off_4A90(pc,d0.w)
; ---------------------------------------------------------------------------

off_4A90:   dc.w EventsMZ1-off_4A90, EventsMZ2-off_4A90, EventsMZ3-off_4A90, EventsMZ3-off_4A90
; ---------------------------------------------------------------------------

EventsMZ1:
	moveq	#0,d0
	move.b	(EventsRoutine).w,d0
	move.w	off_4AA4(pc,d0.w),d0
	jmp off_4AA4(pc,d0.w)
; ---------------------------------------------------------------------------

off_4AA4:   dc.w loc_4AAC-off_4AA4, sub_4ADC-off_4AA4, loc_4B20-off_4AA4, loc_4B42-off_4AA4
; ---------------------------------------------------------------------------

loc_4AAC:
	move.w	#$1D0,(unk_FFF726).w
	cmpi.w	#$27E,(CameraX).w
	blt.s	locret_4ADA
	move.w	#$220,(unk_FFF726).w
	cmpi.w	#$D00,(CameraX).w
	bcs.s	locret_4ADA
	move.w	#$340,(unk_FFF726).w
	cmpi.w	#$340,(CameraY).w
	bcs.s	locret_4ADA
	addq.b	#2,(EventsRoutine).w

locret_4ADA:
	rts
; ---------------------------------------------------------------------------

sub_4ADC:
	cmpi.w	#$340,(CameraY).w
	bcc.s	loc_4AEA
	subq.b	#2,(EventsRoutine).w
	rts
; ---------------------------------------------------------------------------

loc_4AEA:
	clr.w	(unk_FFF72C).w
	cmpi.w	#$E00,(CameraX).w
	bcc.s	locret_4B1E
	move.w	#$340,(unk_FFF72C).w
	move.w	#$340,(unk_FFF726).w
	cmpi.w	#$A90,(CameraX).w
	bcc.s	locret_4B1E
	move.w	#$500,(unk_FFF726).w
	cmpi.w	#$370,(CameraY).w
	bcs.s	locret_4B1E
	addq.b	#2,(EventsRoutine).w

locret_4B1E:
	rts
; ---------------------------------------------------------------------------

loc_4B20:
	cmpi.w	#$370,(CameraY).w
	bcc.s	loc_4B2E
	subq.b	#2,(EventsRoutine).w
	rts
; ---------------------------------------------------------------------------

loc_4B2E:
	cmpi.w	#$500,(CameraY).w
	bcs.s	locret_4B40
	move.w	#$500,(unk_FFF72C).w
	addq.b	#2,(EventsRoutine).w

locret_4B40:
	rts
; ---------------------------------------------------------------------------

loc_4B42:
	cmpi.w	#$E70,(CameraX).w
	bcs.s	locret_4B50
	clr.w	(unk_FFF72C).w

locret_4B50:
	rts
; ---------------------------------------------------------------------------

EventsMZ2:
	move.w	#$520,(unk_FFF726).w
	cmpi.w	#$1500,(CameraX).w
	bcs.s	locret_4B66
	move.w	#$540,(unk_FFF726).w

locret_4B66:
	rts
; ---------------------------------------------------------------------------

EventsMZ3:
	rts
	
; ---------------------------------------------------------------------------
; Subroutine to collect the right speed setting for a character
; a0 must be character
; a1 will be the result and have the correct speed settings
; a2 is characters' speed
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

ApplySpeedSettings:
	moveq	#0,d0				; Quickly clear d0
	tst.w	(ObjectsList+speedshoes).w	; Does character have speedshoes?
	beq.s	.noshoes			; If not, branch
	addq.b	#6,d0				; Quickly add 6 to d0
.noshoes:
	lea	Speedsettings(pc,d0.w),a1	; Load correct speed settings into a1
	move.l	(a1)+,(a2)+			; Set character's new top speed and acceleration
	move.w	(a1),(a2)			; Set character's deceleration
	rts					; Finish subroutine
	
; ----------------------------------------------------------------------------
; Speed Settings Array

; This array defines what speeds the character should be set to
; ----------------------------------------------------------------------------
;		top_speed	acceleration	deceleration    ; # ; Comment
Speedsettings:
	dc.w	$600,	    	$C,		$40     	; $00   ; Normal
	dc.w	$C00,	    	$18,		$80		; $08	; Normal Speedshoes
	even
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------

Obj_SSResults:					; XREF: Obj_Index
		moveq	#0,d0
		move.b	act(a0),d0
		move.w	Obj_SSResults_Index(pc,d0.w),d1
		jmp	Obj_SSResults_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj_SSResults_Index:	dc.w Obj_SSResults_ChkPLC-Obj_SSResults_Index
		dc.w Obj_SSResults_ChkPos-Obj_SSResults_Index
		dc.w Obj_SSResults_Wait-Obj_SSResults_Index
		dc.w Obj_SSResults_RingBonus-Obj_SSResults_Index
		dc.w Obj_SSResults_Wait-Obj_SSResults_Index
		dc.w Obj_SSResults_Exit-Obj_SSResults_Index
		dc.w Obj_SSResults_Wait-Obj_SSResults_Index
		dc.w Obj_SSResults_Continue-Obj_SSResults_Index
		dc.w Obj_SSResults_Wait-Obj_SSResults_Index
		dc.w Obj_SSResults_Exit-Obj_SSResults_Index
		dc.w loc_C91A-Obj_SSResults_Index
; ---------------------------------------------------------------------------

Obj_SSResults_ChkPLC:				; XREF: Obj_SSResults_Index
		tst.l	(plcList).w	; are the pattern load cues empty?
		beq.s	Obj_SSResults_Main	; if yes, branch
		rts
; ---------------------------------------------------------------------------

Obj_SSResults_Main:
		movea.l	a0,a1
		lea	(Obj_SSResults_Config).l,a2
		moveq	#3,d1
		cmpi.w	#50,(Rings).w ; do you have	50 or more rings?
		bcs.s	Obj_SSResults_Loop	; if no, branch
		addq.w	#1,d1		; if yes, add 1	to d1 (number of sprites)

Obj_SSResults_Loop:
		move.b	#$7E,0(a1)
		move.w	(a2)+,xpos(a1)	; load start x-position
		move.w	(a2)+,$30(a1)	; load main x-position
		move.w	(a2)+,ypos(a1)	; load y-position
		move.b	(a2)+,act(a1)
		move.b	(a2)+,frame(a1)
		move.l	#Map_obj7E,map(a1)
		move.w	#$8580,tile(a1)
		move.b	#0,render(a1)
		lea	size(a1),a1
		dbf	d1,Obj_SSResults_Loop	; repeat sequence 3 or 4 times

		moveq	#7,d0
		move.b	(EmeraldAmount).w,d1
		beq.s	loc_C842
		moveq	#0,d0
		cmpi.b	#6,d1		; do you have all chaos	emeralds?
		bne.s	loc_C842	; if not, branch
		moveq	#8,d0		; load "Sonic got them all" text
		move.w	#$18,xpos(a0)
		move.w	#$118,$30(a0)	; change position of text

loc_C842:
		move.b	d0,frame(a0)

Obj_SSResults_ChkPos:				; XREF: Obj_SSResults_Index
		moveq	#$10,d1		; set horizontal speed
		move.w	$30(a0),d0
		cmp.w	xpos(a0),d0	; has item reached its target position?
		beq.s	loc_C86C	; if yes, branch
		bge.s	Obj_SSResults_Move
		neg.w	d1

Obj_SSResults_Move:
		add.w	d1,xpos(a0)	; change item's position

loc_C85A:				; XREF: loc_C86C
		move.w	xpos(a0),d0
		bmi.s	locret_C86A
		cmpi.w	#$200,d0	; has item moved beyond	$200 on	x-axis?
		bcc.s	locret_C86A	; if yes, branch
		bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

locret_C86A:
		rts	
; ---------------------------------------------------------------------------

loc_C86C:				; XREF: Obj_SSResults_ChkPos
		cmpi.b	#2,frame(a0)
		bne.s	loc_C85A
		addq.b	#2,act(a0)
		move.w	#180,anidelay(a0)	; set time delay to 3 seconds
		move.b	#$7F,(byte_FFD100).w ; load chaos	emerald	object

Obj_SSResults_Wait:				; XREF: Obj_SSResults_Index
		subq.w	#1,anidelay(a0)	; subtract 1 from time delay
		bne.s	Obj_SSResults_Display
		addq.b	#2,act(a0)

Obj_SSResults_Display:
		bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

Obj_SSResults_RingBonus:			; XREF: Obj_SSResults_Index
		bsr.w	ObjectDisplay
		st.b	(byte_FFFE58).w ; set ring bonus update flag
		tst.w	(word_FFFE54).w	; is ring bonus	- zero?
		beq.s	loc_C8C4	; if yes, branch
		subi.w	#10,(word_FFFE54).w ; subtract 10	from ring bonus
		moveq	#10,d0		; add 10 to score
		jsr	ScoreAdd
		sfx	sfx_Switch
		rts
; ---------------------------------------------------------------------------

loc_C8C4:				; XREF: Obj_SSResults_RingBonus
		sfx	sfx_Register
		addq.b	#2,act(a0)
		move.w	#180,anidelay(a0)	; set time delay to 3 seconds
		cmpi.w	#50,(Rings).w ; do you have	at least 50 rings?
		bcs.s	locret_C8EA	; if not, branch
		move.w	#60,anidelay(a0)	; set time delay to 1 second
		addq.b	#4,act(a0)	; goto "Obj_SSResults_Continue"	routine

locret_C8EA:
		rts	
; ---------------------------------------------------------------------------

Obj_SSResults_Exit:				; XREF: Obj_SSResults_Index
		st.b	(LevelRestart).w ; restart level
		bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

Obj_SSResults_Continue:				; XREF: Obj_SSResults_Index
		move.b	#4,($FFFFD6DA).w
		move.b	#$14,($FFFFD6E4).w
		sfx		sfx_Continue
		addq.b	#2,act(a0)
		move.w	#360,anidelay(a0)	; set time delay to 6 seconds
		bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_C91A:				; XREF: Obj_SSResults_Index
		move.b	(byte_FFFE0F).w,d0
		andi.b	#$F,d0
		bne.s	Obj_SSResults_Display2
		bchg	#0,frame(a0)

Obj_SSResults_Display2:
		bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
Obj_SSResults_Config:	dc.w $20, $120,	$C4	; start	x-pos, main x-pos, y-pos
		dc.b 2,	0		; rountine number, frame number
		dc.w $320, $120, $118
		dc.b 2,	1
		dc.w $360, $120, $128
		dc.b 2,	2
		dc.w $1EC, $11C, $C4
		dc.b 2,	3
		dc.w $3A0, $120, $138
		dc.b 2,	6
; ---------------------------------------------------------------------------

Obj_SSResCE:					; XREF: Obj_Index
		moveq	#0,d0
		move.b	act(a0),d0
		move.w	Obj_SSResCE_Index(pc,d0.w),d1
		jmp	Obj_SSResCE_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj_SSResCE_Index:	dc.w Obj_SSResCE_Main-Obj_SSResCE_Index
		dc.w Obj_SSResCE_Flash-Obj_SSResCE_Index

; ---------------------------------------------------------------------------
; X-axis positions for chaos emeralds
; ---------------------------------------------------------------------------
Obj_SSResCE_PosData:	dc.w $110, $128, $F8, $140, $E0, $158
; ---------------------------------------------------------------------------

Obj_SSResCE_Main:				; XREF: Obj_SSResCE_Index
		movea.l	a0,a1
		lea	(Obj_SSResCE_PosData).l,a2
		moveq	#0,d2
		moveq	#0,d1
		move.b	(EmeraldAmount).w,d1 ; d1 is number	of emeralds
		subq.b	#1,d1		; subtract 1 from d1
		bcs.w	ObjectDelete	; if you have 0	emeralds, branch

Obj_SSResCE_Loop:
		move.b	#$7F,0(a1)
		move.w	(a2)+,xpos(a1)	; set x-position
		move.w	#$F0,xpix(a1)	; set y-position
		lea	(EmeraldArray).w,a3 ; check which emeralds	you have
		move.b	(a3,d2.w),d3
		move.b	d3,frame(a1)
		move.b	d3,ani(a1)
		addq.b	#1,d2
		addq.b	#2,act(a1)
		move.l	#Map_obj7F,map(a1)
		move.w	#$8541,tile(a1)
		move.b	#0,render(a1)
		lea	$40(a1),a1	; next object
		dbf	d1,Obj_SSResCE_Loop	; loop for d1 number of	emeralds

Obj_SSResCE_Flash:				; XREF: Obj_SSResCE_Index
		move.b	frame(a0),d0
		move.b	#6,frame(a0)	; load 6th frame (blank)
		cmpi.b	#6,d0
		bne.s	Obj_SSResCE_Display
		move.b	ani(a0),frame(a0)	; load visible frame

Obj_SSResCE_Display:
		bra.w	ObjectDisplay
		
; ---------------------------------------------------------------------------
; Sprite mappings - special stage results screen
; ---------------------------------------------------------------------------
Map_obj7E:	dc.w .byte_CCAC-Map_obj7E
		dc.w .byte_CCEE-Map_obj7E
		dc.w .byte_CD0D-Map_obj7E
		dc.w byte_AA94-Map_obj7E
		dc.w .byte_CD31-Map_obj7E
		dc.w .byte_CD46-Map_obj7E
		dc.w .byte_CD5B-Map_obj7E
		dc.w .byte_CD6B-Map_obj7E
		dc.w .byte_CDA8-Map_obj7E
.byte_CCAC:	dc.b $D			; "CHAOS EMERALDS"
		dc.b $F8, 5, 0,	8, $90
		dc.b $F8, 5, 0,	$1C, $A0
		dc.b $F8, 5, 0,	0, $B0
		dc.b $F8, 5, 0,	$32, $C0
		dc.b $F8, 5, 0,	$3E, $D0
		dc.b $F8, 5, 0,	$10, $F0
		dc.b $F8, 5, 0,	$2A, 0
		dc.b $F8, 5, 0,	$10, $10
		dc.b $F8, 5, 0,	$3A, $20
		dc.b $F8, 5, 0,	0, $30
		dc.b $F8, 5, 0,	$26, $40
		dc.b $F8, 5, 0,	$C, $50
		dc.b $F8, 5, 0,	$3E, $60
.byte_CCEE:	dc.b 6			; "SCORE"
		dc.b $F8, $D, 1, $4A, $B0
		dc.b $F8, 1, 1,	$62, $D0
		dc.b $F8, 9, 1,	$64, $18
		dc.b $F8, $D, 1, $6A, $30
		dc.b $F7, 4, 0,	$6E, $CD
		dc.b $FF, 4, $18, $6E, $CD
.byte_CD0D:	dc.b 7
		dc.b $F8, $D, 1, $52, $B0
		dc.b $F8, $D, 0, $66, $D9
		dc.b $F8, 1, 1,	$4A, $F9
		dc.b $F7, 4, 0,	$6E, $F6
		dc.b $FF, 4, $18, $6E, $F6
		dc.b $F8, $D, $FF, $F8,	$28
		dc.b $F8, 1, 1,	$70, $48
.byte_CD31:	dc.b 4
		dc.b $F8, $D, $FF, $D1,	$B0
		dc.b $F8, $D, $FF, $D9,	$D0
		dc.b $F8, 1, $FF, $E1, $F0
		dc.b $F8, 6, $1F, $E3, $40
.byte_CD46:	dc.b 4
		dc.b $F8, $D, $FF, $D1,	$B0
		dc.b $F8, $D, $FF, $D9,	$D0
		dc.b $F8, 1, $FF, $E1, $F0
		dc.b $F8, 6, $1F, $E9, $40
.byte_CD5B:	dc.b 3
		dc.b $F8, $D, $FF, $D1,	$B0
		dc.b $F8, $D, $FF, $D9,	$D0
		dc.b $F8, 1, $FF, $E1, $F0
.byte_CD6B:	dc.b $C			; "SPECIAL STAGE"
		dc.b $F8, 5, 0,	$3E, $9C
		dc.b $F8, 5, 0,	$36, $AC
		dc.b $F8, 5, 0,	$10, $BC
		dc.b $F8, 5, 0,	8, $CC
		dc.b $F8, 1, 0,	$20, $DC
		dc.b $F8, 5, 0,	0, $E4
		dc.b $F8, 5, 0,	$26, $F4
		dc.b $F8, 5, 0,	$3E, $14
		dc.b $F8, 5, 0,	$42, $24
		dc.b $F8, 5, 0,	0, $34
		dc.b $F8, 5, 0,	$18, $44
		dc.b $F8, 5, 0,	$10, $54
.byte_CDA8:	dc.b $F			; "SONIC GOT THEM ALL"
		dc.b $F8, 5, 0,	$3E, $88
		dc.b $F8, 5, 0,	$32, $98
		dc.b $F8, 5, 0,	$2E, $A8
		dc.b $F8, 1, 0,	$20, $B8
		dc.b $F8, 5, 0,	8, $C0
		dc.b $F8, 5, 0,	$18, $D8
		dc.b $F8, 5, 0,	$32, $E8
		dc.b $F8, 5, 0,	$42, $F8
		dc.b $F8, 5, 0,	$42, $10
		dc.b $F8, 5, 0,	$1C, $20
		dc.b $F8, 5, 0,	$10, $30
		dc.b $F8, 5, 0,	$2A, $40
		dc.b $F8, 5, 0,	0, $58
		dc.b $F8, 5, 0,	$26, $68
		dc.b $F8, 5, 0,	$26, $78
		even
; ---------------------------------------------------------------------------
; Sprite mappings - chaos emeralds from	the special stage results screen
; ---------------------------------------------------------------------------
Map_obj7F:
		dc.w .byte_CE02-Map_obj7F
		dc.w .byte_CE08-Map_obj7F
		dc.w .byte_CE0E-Map_obj7F
		dc.w .byte_CE14-Map_obj7F
		dc.w .byte_CE1A-Map_obj7F
		dc.w .byte_CE20-Map_obj7F
		dc.w .byte_CE26-Map_obj7F
.byte_CE02:	dc.b 1
		dc.b $F8, 5, $20, 4, $F8
.byte_CE08:	dc.b 1
		dc.b $F8, 5, 0,	0, $F8
.byte_CE0E:	dc.b 1
		dc.b $F8, 5, $40, 4, $F8
.byte_CE14:	dc.b 1
		dc.b $F8, 5, $60, 4, $F8
.byte_CE1A:	dc.b 1
		dc.b $F8, 5, $20, 8, $F8
.byte_CE20:	dc.b 1
		dc.b $F8, 5, $20, $C, $F8
.byte_CE26:	dc.b 0			; Blank frame
		even
; ---------------------------------------------------------------------------

ObjBridge:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_4E64(pc,d0.w),d1
	jmp off_4E64(pc,d1.w)
; ---------------------------------------------------------------------------

off_4E64:   dc.w ObjBridge_Init-off_4E64, loc_4F32-off_4E64, loc_50B2-off_4E64, ObjBridge_Delete-off_4E64, ObjBridge_Delete-off_4E64
	dc.w ObjBridge_Display-off_4E64
; ---------------------------------------------------------------------------

ObjBridge_Init:
	addq.b	#2,act(a0)
	move.l	#MapBridge,map(a0)
	move.w	#$438E,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$80,xpix(a0)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	move.b	id(a0),d4
	lea arg(a0),a2
	moveq	#0,d1
	move.b	(a2),d1
	move.b	#0,(a2)+
	move.w	d1,d0
	lsr.w	#1,d0
	lsl.w	#4,d0
	sub.w	d0,d3
	subq.b	#2,d1
	bcs.s	loc_4F32

ObjBridge_MakeLog:
	bsr.w	ObjectLoad
	bne.s	loc_4F32
	addq.b	#1,arg(a0)
	cmp.w	xpos(a0),d3
	bne.s	loc_4EE6
	addi.w	#$10,d3
	move.w	d2,ypos(a0)
	move.w	d2,$3C(a0)
	move.w	a0,d5
	subi.w	#ObjectsList,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+
	addq.b	#1,arg(a0)

loc_4EE6:
	move.w	a1,d5
	subi.w	#ObjectsList,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+
	move.b	#$A,act(a1)
	move.b	d4,id(a1)
	move.w	d2,ypos(a1)
	move.w	d2,$3C(a1)
	move.w	d3,xpos(a1)
	move.l	#MapBridge,map(a1)
	move.w	#$438E,tile(a1)
	move.b	#4,render(a1)
	move.w	#$180,prio(a1)
	move.b	#8,xpix(a1)
	addi.w	#$10,d3
	dbf d1,ObjBridge_MakeLog

loc_4F32:
	bsr.s	PtfmBridge
	tst.b	$3E(a0)
	beq.s	loc_4F42
	subq.b	#4,$3E(a0)
	bsr.w	ObjBridge_UpdateBend

loc_4F42:
	bra.w	ObjBridge_ChkDelete
; ---------------------------------------------------------------------------

PtfmBridge:
	moveq	#0,d1
	move.b	arg(a0),d1
	lsl.w	#3,d1
	move.w	d1,d2
	addq.w	#8,d1
	add.w	d2,d2
	lea (ObjectsList).w,a1
	tst.w	yvel(a1)
	bmi.w	locret_5048
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.w	locret_5048
	cmp.w	d2,d0
	bcc.w	locret_5048
	bra.s	PtfmNormal2
; ---------------------------------------------------------------------------

PtfmNormal:
	lea (ObjectsList).w,a1
	tst.w	yvel(a1)
	bmi.w	locret_5048
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.w	locret_5048
	add.w	d1,d1
	cmp.w	d1,d0
	bcc.w	locret_5048

PtfmNormal2:
	move.w	ypos(a0),d0
	subq.w	#8,d0

PtfmNormal3:
	move.w	ypos(a1),d2
	move.b	yrad(a1),d1
	ext.w	d1
	add.w	d2,d1
	addq.w	#4,d1
	sub.w	d1,d0
	bhi.w	locret_5048
	cmpi.w	#$FFF0,d0
	bcs.w	locret_5048
	cmpi.b	#6,act(a1)
	bcc.w	locret_5048
	add.w	d0,d2
	addq.w	#3,d2
	move.w	d2,ypos(a1)
	addq.b	#2,act(a0)

loc_4FD4:
	btst	#3,status(a1)
	beq.s	loc_4FFC
	moveq	#0,d0
	move.b	platform(a1),d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a2
	cmpi.b	#4,act(a2)
	bne.s	loc_4FFC
	subq.b	#2,act(a2)
	clr.b	subact(a2)

loc_4FFC:
	move.w	a0,d0
	subi.w	#ObjectsList,d0
	lsr.w	#6,d0
	andi.w	#$7F,d0
	move.b	d0,platform(a1)
	move.b	#0,angle(a1)
	move.w	#0,yvel(a1)
	move.w	xvel(a1),d0
	asr.w	#2,d0
	sub.w	d0,xvel(a1)
	move.w	xvel(a1),inertia(a1)
	btst	#1,status(a1)
	beq.s	loc_503C
	move.l	a0,-(sp)
	movea.l a1,a0
	jsr ObjSonic_ResetOnFloor
	movea.l (sp)+,a0

loc_503C:
	bset	#3,status(a1)
	bset	#3,status(a0)

locret_5048:
	rts
; ---------------------------------------------------------------------------

PtfmSloped:
	lea (ObjectsList).w,a1
	tst.w	yvel(a1)
	bmi.w	locret_5048
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.s	locret_5048
	add.w	d1,d1
	cmp.w	d1,d0
	bcc.s	locret_5048
	btst	#0,render(a0)
	beq.s	loc_5074
	not.w	d0
	add.w	d1,d0

loc_5074:
	lsr.w	#1,d0
	moveq	#0,d3
	move.b	(a2,d0.w),d3
	move.w	ypos(a0),d0
	sub.w	d3,d0
	bra.w	PtfmNormal3
; ---------------------------------------------------------------------------

PtfmNormalHeight:
	lea (ObjectsList).w,a1
	tst.w	yvel(a1)
	bmi.w	locret_5048
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.w	locret_5048
	add.w	d1,d1
	cmp.w	d1,d0
	bcc.w	locret_5048
	move.w	ypos(a0),d0
	sub.w	d3,d0
	bra.w	PtfmNormal3
; ---------------------------------------------------------------------------

loc_50B2:
	bsr.s	ObjBridge_ChkExit
	bra.w	ObjBridge_ChkDelete
; ---------------------------------------------------------------------------

ObjBridge_ChkExit:
	moveq	#0,d1
	move.b	arg(a0),d1
	lsl.w	#3,d1
	move.w	d1,d2
	addq.w	#8,d1
	bsr.s	PtfmCheckExit2
	bcc.s	locret_50E8
	lsr.w	#4,d0
	move.b	d0,$3F(a0)
	move.b	$3E(a0),d0
	cmpi.b	#$40,d0
	beq.s	loc_50E0
	addq.b	#4,$3E(a0)

loc_50E0:
	bsr.w	ObjBridge_UpdateBend
	bra.w	ObjBridge_PlayerPos

locret_50E8:
	rts
; ---------------------------------------------------------------------------

PtfmCheckExit:
	move.w	d1,d2
; ---------------------------------------------------------------------------

PtfmCheckExit2:
	add.w	d2,d2
	lea (ObjectsList).w,a1
	btst	#1,status(a1)
	bne.s	loc_510A
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.s	loc_510A
	cmp.w	d2,d0
	bcs.s	locret_511C

loc_510A:
	bclr	#3,status(a1)
	move.b	#2,act(a0)
	bclr	#3,status(a0)

locret_511C:
	rts
; ---------------------------------------------------------------------------

ObjBridge_PlayerPos:
	moveq	#0,d0
	move.b	$3F(a0),d0
	move.b	$29(a0,d0.w),d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a2
	lea (ObjectsList).w,a1
	move.w	ypos(a2),d0
	subq.w	#8,d0
	moveq	#0,d1
	move.b	yrad(a1),d1
	sub.w	d1,d0
	move.w	d0,ypos(a1)
	rts
; ---------------------------------------------------------------------------

ObjBridge_UpdateBend:
	move.b	$3E(a0),d0
	bsr.w	GetSine
	move.w	d0,d4
	lea (byte_5306).l,a4
	moveq	#0,d0
	move.b	arg(a0),d0
	lsl.w	#4,d0
	moveq	#0,d3
	move.b	$3F(a0),d3
	move.w	d3,d2
	add.w	d0,d3
	moveq	#0,d5
	lea (byte_51F6).l,a5
	move.b	(a5,d3.w),d5
	andi.w	#$F,d3
	lsl.w	#4,d3
	lea (a4,d3.w),a3
	lea $29(a0),a2

loc_5186:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a1
	moveq	#0,d0
	move.b	(a3)+,d0
	addq.w	#1,d0
	mulu.w	d5,d0
	mulu.w	d4,d0
	swap	d0
	add.w	$3C(a1),d0
	move.w	d0,ypos(a1)
	dbf d2,loc_5186
	moveq	#0,d0
	move.b	arg(a0),d0
	moveq	#0,d3
	move.b	$3F(a0),d3
	addq.b	#1,d3
	sub.b	d0,d3
	neg.b	d3
	bmi.s	locret_51F4
	move.w	d3,d2
	lsl.w	#4,d3
	lea (a4,d3.w),a3
	adda.w	d2,a3
	subq.w	#1,d2
	bcs.s	locret_51F4

loc_51CE:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a1
	moveq	#0,d0
	move.b	-(a3),d0
	addq.w	#1,d0
	mulu.w	d5,d0
	mulu.w	d4,d0
	swap	d0
	add.w	$3C(a1),d0
	move.w	d0,ypos(a1)
	dbf d2,loc_51CE

locret_51F4:
	rts
; ---------------------------------------------------------------------------

byte_51F6:  dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 6, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 6, 6, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 6, 8, 6, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 6, 8, 8, 6, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 6, 8, $A, 8, 6, 4, 2
	dc.b 0, 0, 0, 0, 0, 0, 0, 2, 4, 6, 8, $A, $A, 8, 6, 4
	dc.b 2, 0, 0, 0, 0, 0, 0, 2, 4, 6, 8, $A, $C, $A, 8, 6
	dc.b 4, 2, 0, 0, 0, 0, 0, 2, 4, 6, 8, $A, $C, $C, $A, 8
	dc.b 6, 4, 2, 0, 0, 0, 0, 2, 4, 6, 8, $A, $C, $E, $C, $A
	dc.b 8, 6, 4, 2, 0, 0, 0, 2, 4, 6, 8, $A, $C, $E, $E, $C
	dc.b $A, 8, 6, 4, 2, 0, 0, 2, 4, 6, 8, $A, $C, $E, $10
	dc.b $E, $C, $A, 8, 6, 4, 2, 0, 2, 4, 6, 8, $A, $C, $E
	dc.b $10, $10, $E, $C, $A, 8, 6, 4, 2

byte_5306:  dc.b $FF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b $B5, $FF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b $7E, $DB, $FF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, $61, $B5, $EC, $FF, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, $4A, $93, $CD, $F3, $FF, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, $3E, $7E, $B0, $DB, $F6, $FF, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, $38, $6D, $9D, $C5, $E4, $F8
	dc.b $FF, 0, 0, 0, 0, 0, 0, 0, 0, 0, $31, $61, $8E, $B5
	dc.b $D4, $EC, $FB, $FF, 0, 0, 0, 0, 0, 0, 0, 0, $2B, $56
	dc.b $7E, $A2, $C1, $DB, $EE, $FB, $FF, 0, 0, 0, 0, 0
	dc.b 0, 0, $25, $4A, $73, $93, $B0, $CD, $E1, $F3, $FC
	dc.b $FF, 0, 0, 0, 0, 0, 0, $1F, $44, $67, $88, $A7, $BD
	dc.b $D4, $E7, $F4, $FD, $FF, 0, 0, 0, 0, 0, $1F, $3E
	dc.b $5C, $7E, $98, $B0, $C9, $DB, $EA, $F6, $FD, $FF
	dc.b 0, 0, 0, 0, $19, $38, $56, $73, $8E, $A7, $BD, $D1
	dc.b $E1, $EE, $F8, $FE, $FF, 0, 0, 0, $19, $38, $50, $6D
	dc.b $83, $9D, $B0, $C5, $D8, $E4, $F1, $F8, $FE, $FF
	dc.b 0, 0, $19, $31, $4A, $67, $7E, $93, $A7, $BD, $CD
	dc.b $DB, $E7, $F3, $F9, $FE, $FF, 0, $19, $31, $4A, $61
	dc.b $78, $8E, $A2, $B5, $C5, $D4, $E1, $EC, $F4, $FB
	dc.b $FE, $FF
; ---------------------------------------------------------------------------

ObjBridge_ChkDelete:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.s	ObjBridge_DeleteAll
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjBridge_DeleteAll:
	moveq	#0,d2
	lea arg(a0),a2
	move.b	(a2)+,d2
	subq.b	#1,d2
	bcs.s	ObjBridge_GoDelete

loc_5432:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a1
	cmp.w	a0,d0
	beq.s	loc_5448
	bsr.w	ObjectDeleteA1

loc_5448:
	dbf d2,loc_5432

ObjBridge_GoDelete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjBridge_Delete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjBridge_Display:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/GHZ/Bridge/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSwingPtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_548A(pc,d0.w),d1
	jmp off_548A(pc,d1.w)
; ---------------------------------------------------------------------------

off_548A:   dc.w ObjSwingPtfm_Init-off_548A, loc_55C8-off_548A, loc_55E4-off_548A, ObjSwingPtfm_Delete-off_548A
	dc.w ObjSwingPtfm_Delete-off_548A, j_ObjectDisplay-off_548A
; ---------------------------------------------------------------------------

ObjSwingPtfm_Init:
	addq.b	#2,act(a0)
	move.l	#MapSwingPtfm,4(a0)
	move.w	#$4380,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$18,xpix(a0)
	move.b	#8,yrad(a0)
	move.w	ypos(a0),convex(a0)
	move.w	xpos(a0),$3A(a0)
	cmpi.b	#3,(curzone).w
	bne.s	ObjSwingPtfm_NotSYZ
	move.l	#MapSwingPtfmSYZ,4(a0)
	move.w	#$43DC,tile(a0)
	move.b	#$20,xpix(a0)
	move.b	#$10,yrad(a0)
	move.b	#$99,col(a0)

ObjSwingPtfm_NotSYZ:
	move.b	id(a0),d4
	moveq	#0,d1
	lea arg(a0),a2
	move.b	(a2),d1
	move.w	d1,-(sp)
	andi.w	#$F,d1
	move.b	#0,(a2)+
	move.w	d1,d3
	lsl.w	#4,d3
	addq.b	#8,d3
	move.b	d3,$3C(a0)
	subq.b	#8,d3
	tst.b	frame(a0)
	beq.s	ObjSwingPtfm_LoadLinks
	addq.b	#8,d3
	subq.w	#1,d1

ObjSwingPtfm_LoadLinks:
	bsr.w	ObjectLoad
	bne.s	loc_5586
	addq.b	#1,arg(a0)
	move.w	a1,d5
	subi.w	#$D000,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+
	move.b	#$A,act(a1)
	move.b	d4,id(a1)
	move.l	4(a0),4(a1)
	move.w	tile(a0),tile(a1)
	bclr	#6,tile(a1)
	move.b	#4,render(a1)
	move.w	#$200,prio(a1)
	move.b	#8,xpix(a1)
	move.b	#1,frame(a1)
	move.b	d3,$3C(a1)
	subi.b	#$10,d3
	bcc.s	loc_5582
	move.b	#2,frame(a1)
	bset	#6,tile(a1)

loc_5582:
	dbf d1,ObjSwingPtfm_LoadLinks

loc_5586:
	move.w	a0,d5
	subi.w	#ObjectsList,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+
	move.w	#$4080,angle(a0)
	move.w	#$FE00,$3E(a0)
	move.w	(sp)+,d1
	btst	#4,d1
	beq.s	loc_55C8
	move.l	#MapRollingBall,4(a0)
	move.w	#$43AA,tile(a0)
	move.b	#1,frame(a0)
	move.w	#$100,prio(a0)
	move.b	#$81,col(a0)

loc_55C8:
	moveq	#0,d1
	move.b	xpix(a0),d1
	moveq	#0,d3
	move.b	yrad(a0),d3
	bsr.w	PtfmNormalHeight
	bsr.w	sub_563C
	bra.w	ObjSwingPtfm_ChkDelete
; ---------------------------------------------------------------------------

loc_55E4:
	moveq	#0,d1
	move.b	xpix(a0),d1
	bsr.w	PtfmCheckExit
	move.w	xpos(a0),-(sp)
	bsr.w	sub_563C
	move.w	(sp)+,d2
	moveq	#0,d3
	move.b	yrad(a0),d3
	addq.b	#1,d3
	bsr.w	PtfmSurfaceHeight
	bsr.w	ObjectDisplay
	bra.w	ObjSwingPtfm_ChkDelete
; ---------------------------------------------------------------------------

PtfmSurfaceHeight:
	lea (ObjectsList).w,a1
	move.w	ypos(a0),d0
	sub.w	d3,d0
	bra.s	loc_5626
; ---------------------------------------------------------------------------

ptfmSurfaceNormal:
	lea (ObjectsList).w,a1
	move.w	ypos(a0),d0
	subi.w	#9,d0

loc_5626:
	moveq	#0,d1
	move.b	yrad(a1),d1
	sub.w	d1,d0
	move.w	d0,ypos(a1)
	sub.w	xpos(a0),d2
	sub.w	d2,xpos(a1)
	rts
; ---------------------------------------------------------------------------

sub_563C:
	move.b	(oscValues+$1A).w,d0
	move.w	#$80,d1
	btst	#0,status(a0)
	beq.s	loc_5650
	neg.w	d0
	add.w	d1,d0

loc_5650:
	bra.s	loc_5692
; ---------------------------------------------------------------------------

loc_5652:
	tst.b	platform(a0)
	bne.s	loc_5674
	move.w	$3E(a0),d0
	addq.w	#8,d0
	move.w	d0,$3E(a0)
	add.w	d0,angle(a0)
	cmpi.w	#$200,d0
	bne.s	loc_568E
	move.b	#1,platform(a0)
	bra.s	loc_568E
; ---------------------------------------------------------------------------

loc_5674:
	move.w	$3E(a0),d0
	subq.w	#8,d0
	move.w	d0,$3E(a0)
	add.w	d0,angle(a0)
	cmpi.w	#$FE00,d0
	bne.s	loc_568E
	move.b	#0,platform(a0)

loc_568E:
	move.b	angle(a0),d0

loc_5692:
	bsr.w	GetSine
	move.w	convex(a0),d2
	move.w	$3A(a0),d3
	lea arg(a0),a2
	moveq	#0,d6
	move.b	(a2)+,d6

loc_56A6:
	moveq	#0,d4
	move.b	(a2)+,d4
	lsl.w	#6,d4
	addi.l	#(ObjectsList)&$FFFFFF,d4
	movea.l d4,a1
	moveq	#0,d4
	move.b	$3C(a1),d4
	move.l	d4,d5
	muls.w	d0,d4
	asr.l	#8,d4
	muls.w	d1,d5
	asr.l	#8,d5
	add.w	d2,d4
	add.w	d3,d5
	move.w	d4,ypos(a1)
	move.w	d5,xpos(a1)
	dbf d6,loc_56A6
	rts
; ---------------------------------------------------------------------------

ObjSwingPtfm_ChkDelete:
	move.w	$3A(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.s	ObjSwingPtfm_DeleteAll
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjSwingPtfm_DeleteAll:
	moveq	#0,d2
	lea arg(a0),a2
	move.b	(a2)+,d2

loc_56FE:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a1
	bsr.w	ObjectDeleteA1
	dbf d2,loc_56FE
	rts
; ---------------------------------------------------------------------------

ObjSwingPtfm_Delete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
; Attributes: thunk

j_ObjectDisplay:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/shared/SwingPtfm/Main.map"
	even
	include "levels/shared/SwingPtfm/SYZ.map"
	even
; ---------------------------------------------------------------------------

ObjSpikeLogs:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_5788(pc,d0.w),d1
	jmp off_5788(pc,d1.w)
; ---------------------------------------------------------------------------

off_5788:   dc.w loc_5792-off_5788, loc_5854-off_5788, loc_5854-off_5788, loc_58C2-off_5788, loc_58C8-off_5788
; ---------------------------------------------------------------------------

loc_5792:
	addq.b	#2,act(a0)
	move.l	#MapSpikeLogs,4(a0)
	move.w	#$4398,tile(a0)
	move.b	#7,status(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#8,xpix(a0)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	move.b	id(a0),d4
	lea arg(a0),a2
	moveq	#0,d1
	move.b	(a2),d1
	move.b	#0,(a2)+
	move.w	d1,d0
	lsr.w	#1,d0
	lsl.w	#4,d0
	sub.w	d0,d3
	subq.b	#2,d1
	bcs.s	loc_5854
	moveq	#0,d6

loc_57E2:
	bsr.w	ObjectLoad
	bne.s	loc_5854
	addq.b	#1,arg(a0)
	move.w	a1,d5
	subi.w	#$D000,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+

loc_57FA:
	move.b	#8,act(a1)
	move.b	d4,id(a1)
	move.w	d2,ypos(a1)
	move.w	d3,xpos(a1)
	move.l	4(a0),4(a1)
	move.w	#$4398,tile(a1)
	move.b	#4,render(a1)
	move.w	#$180,prio(a1)
	move.b	#8,xpix(a1)
	move.b	d6,$3E(a1)
	addq.b	#1,d6
	andi.b	#7,d6
	addi.w	#$10,d3
	cmp.w	xpos(a0),d3
	bne.s	loc_5850
	move.b	d6,$3E(a0)
	addq.b	#1,d6
	andi.b	#7,d6
	addi.w	#$10,d3
	addq.b	#1,arg(a0)

loc_5850:
	dbf d1,loc_57E2

loc_5854:
	bsr.w	sub_5860
	bra.w	loc_5880
; ---------------------------------------------------------------------------

sub_5860:
	move.b	(GHZSpikeFrame).w,d0
	move.b	#0,col(a0)
	add.b	$3E(a0),d0
	andi.b	#7,d0
	move.b	d0,frame(a0)
	bne.s	locret_587E
	move.b	#$84,col(a0)

locret_587E:
	rts
; ---------------------------------------------------------------------------

loc_5880:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	loc_58A0
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_58A0:
	moveq	#0,d2
	lea arg(a0),a2
	move.b	(a2)+,d2
	subq.b	#2,d2
	bcs.s	loc_58C2

loc_58AC:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a1
	bsr.w	ObjectDeleteA1
	dbf d2,loc_58AC

loc_58C2:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

loc_58C8:
	bsr.s	sub_5860
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/GHZ/SpikeLogs/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjPlatform:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_5918(pc,d0.w),d1
	jmp off_5918(pc,d1.w)
; ---------------------------------------------------------------------------

off_5918:   dc.w loc_5922-off_5918, loc_59AE-off_5918, loc_59D2-off_5918, loc_5BCE-off_5918, loc_59C2-off_5918
; ---------------------------------------------------------------------------

loc_5922:
	addq.b	#2,act(a0)
	move.w	#$4000,tile(a0)
	move.l	#MapPlatform1,4(a0)
	move.b	#$20,xpix(a0)
	cmpi.b	#4,(curzone).w
	bne.s	loc_5950
	move.l	#MapPlatform2,4(a0)
	move.b	#$20,xpix(a0)

loc_5950:
	cmpi.b	#3,(curzone).w
	bne.s	loc_5972
	move.l	#MapPlatform3,4(a0)
	move.b	#$20,xpix(a0)
	move.w	#$4480,tile(a0)
	move.b	#3,arg(a0)

loc_5972:
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.w	ypos(a0),$2C(a0)
	move.w	ypos(a0),$34(a0)
	move.w	xpos(a0),$32(a0)
	move.w	#$80,angle(a0)
	moveq	#0,d1
	move.b	arg(a0),d0
	cmpi.b	#$A,d0
	bne.s	loc_59AA
	addq.b	#1,d1
	move.b	#$20,xpix(a0)

loc_59AA:
	move.b	d1,frame(a0)

loc_59AE:
	tst.b	convex(a0)
	beq.s	loc_59B8
	subq.b	#4,convex(a0)

loc_59B8:
	moveq	#0,d1
	move.b	xpix(a0),d1
	bsr.w	PtfmNormal

loc_59C2:
	bsr.w	sub_5A1E
	bsr.w	sub_5A04
	bra.w	loc_5BB0
; ---------------------------------------------------------------------------

loc_59D2:
	cmpi.b	#$40,convex(a0)
	beq.s	loc_59DE
	addq.b	#4,convex(a0)

loc_59DE:
	moveq	#0,d1
	move.b	xpix(a0),d1
	bsr.w	PtfmCheckExit
	move.w	xpos(a0),-(sp)
	bsr.w	sub_5A1E
	bsr.w	sub_5A04
	move.w	(sp)+,d2
	bsr.w	ptfmSurfaceNormal
	bsr.w	ObjectDisplay
	bra.w	loc_5BB0
; ---------------------------------------------------------------------------

sub_5A04:
	move.b	convex(a0),d0
	bsr.w	GetSine
	move.w	#$400,d1
	muls.w	d1,d0
	swap	d0
	add.w	$2C(a0),d0
	move.w	d0,ypos(a0)
	rts
; ---------------------------------------------------------------------------

sub_5A1E:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#$F,d0
	add.w	d0,d0
	move.w	off_5A32(pc,d0.w),d1
	jmp off_5A32(pc,d1.w)
; ---------------------------------------------------------------------------

off_5A32:   dc.w locret_5A4C-off_5A32, loc_5A5E-off_5A32, loc_5AA4-off_5A32, loc_5ABC-off_5A32, loc_5AE4-off_5A32
	dc.w loc_5A4E-off_5A32, loc_5A94-off_5A32, loc_5B4E-off_5A32, loc_5B7A-off_5A32, locret_5A4C-off_5A32
	dc.w loc_5B92-off_5A32, loc_5A86-off_5A32, loc_5A76-off_5A32
; ---------------------------------------------------------------------------

locret_5A4C:
	rts
; ---------------------------------------------------------------------------

loc_5A4E:
	move.w	$32(a0),d0
	move.b	angle(a0),d1
	neg.b	d1
	addi.b	#$40,d1
	bra.s	loc_5A6A
; ---------------------------------------------------------------------------

loc_5A5E:
	move.w	$32(a0),d0
	move.b	angle(a0),d1
	subi.b	#$40,d1

loc_5A6A:
	ext.w	d1
	add.w	d1,d0
	move.w	d0,xpos(a0)
	bra.w	loc_5BA8
; ---------------------------------------------------------------------------

loc_5A76:
	move.w	$34(a0),d0
	move.b	(oscValues+$E).w,d1
	neg.b	d1
	addi.b	#$30,d1
	bra.s	loc_5AB0
; ---------------------------------------------------------------------------

loc_5A86:
	move.w	$34(a0),d0
	move.b	(oscValues+$E).w,d1
	subi.b	#$30,d1
	bra.s	loc_5AB0
; ---------------------------------------------------------------------------

loc_5A94:
	move.w	$34(a0),d0
	move.b	angle(a0),d1
	neg.b	d1
	addi.b	#$40,d1
	bra.s	loc_5AB0
; ---------------------------------------------------------------------------

loc_5AA4:
	move.w	$34(a0),d0
	move.b	angle(a0),d1
	subi.b	#$40,d1

loc_5AB0:
	ext.w	d1
	add.w	d1,d0
	move.w	d0,$2C(a0)
	bra.w	loc_5BA8
; ---------------------------------------------------------------------------

loc_5ABC:
	tst.w	$3A(a0)
	bne.s	loc_5AD2
	btst	#3,status(a0)
	beq.s	locret_5AD0
	move.w	#$1E,$3A(a0)

locret_5AD0:
	rts
; ---------------------------------------------------------------------------

loc_5AD2:
	subq.w	#1,$3A(a0)
	bne.s	locret_5AD0
	move.w	#$20,$3A(a0)
	addq.b	#1,arg(a0)
	rts
; ---------------------------------------------------------------------------

loc_5AE4:
	tst.w	$3A(a0)
	beq.s	loc_5B20
	subq.w	#1,$3A(a0)
	bne.s	loc_5B20
	btst	#3,status(a0)
	beq.s	loc_5B1A
	bset	#1,status(a1)
	bclr	#3,status(a1)
	move.b	#2,act(a1)
	bclr	#3,status(a0)
	clr.b	subact(a0)
	move.w	yvel(a0),yvel(a1)

loc_5B1A:
	move.b	#8,act(a0)

loc_5B20:
	move.l	$2C(a0),d3
	move.w	yvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	add.l	d0,d3
	move.l	d3,$2C(a0)
	addi.w	#$38,yvel(a0)
	move.w	(unk_FFF72E).w,d0
	addi.w	#$E0,d0
	cmp.w	$2C(a0),d0
	bcc.s	locret_5B4C
	move.b	#6,act(a0)

locret_5B4C:
	rts
; ---------------------------------------------------------------------------

loc_5B4E:
	tst.w	$3A(a0)
	bne.s	loc_5B6E
	lea (unk_FFF7E0).w,a2
	moveq	#0,d0
	move.b	arg(a0),d0
	lsr.w	#4,d0
	tst.b	(a2,d0.w)
	beq.s	locret_5B6C
	move.w	#$3C,$3A(a0)

locret_5B6C:
	rts
; ---------------------------------------------------------------------------

loc_5B6E:
	subq.w	#1,$3A(a0)
	bne.s	locret_5B6C
	addq.b	#1,arg(a0)
	rts
; ---------------------------------------------------------------------------

loc_5B7A:
	subq.w	#2,$2C(a0)
	move.w	$34(a0),d0
	subi.w	#$200,d0
	cmp.w	$2C(a0),d0
	bne.s	locret_5B90
	clr.b	arg(a0)

locret_5B90:
	rts
; ---------------------------------------------------------------------------

loc_5B92:
	move.w	$34(a0),d0
	move.b	angle(a0),d1
	subi.b	#$40,d1
	ext.w	d1
	asr.w	#1,d1
	add.w	d1,d0
	move.w	d0,$2C(a0)

loc_5BA8:
	move.b	(oscValues+$1A).w,angle(a0)
	rts
; ---------------------------------------------------------------------------

loc_5BB0:
	move.w	$32(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.s	loc_5BCE
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_5BCE:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "unknown/05BD2.map"
	include "levels/shared/Platform/1.map"
	include "levels/shared/Platform/2.map"
	include "levels/shared/Platform/3.map"
	even
; ---------------------------------------------------------------------------

ObjRollingBall:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_5C8E(pc,d0.w),d1
	jmp off_5C8E(pc,d1.w)
; ---------------------------------------------------------------------------

off_5C8E:   dc.w loc_5C98-off_5C8E, loc_5D2C-off_5C8E, loc_5D86-off_5C8E, loc_5E4A-off_5C8E, loc_5CEE-off_5C8E
; ---------------------------------------------------------------------------

loc_5C98:
	move.b	#$18,yrad(a0)
	move.b	#$C,xrad(a0)
	bsr.w	ObjectFall
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	locret_5CEC
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	move.b	#8,act(a0)
	move.l	#MapRollingBall,4(a0)
	move.w	#$43AA,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$18,xpix(a0)
	move.b	#1,storedframe(a0)
	bsr.w	sub_5DC8

locret_5CEC:
	rts
; ---------------------------------------------------------------------------

loc_5CEE:
	move.w	#$23,d1
	move.w	#$18,d2
	move.w	#$18,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	btst	#5,status(a0)
	bne.s	loc_5D14
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcs.s	loc_5D20

loc_5D14:
	move.b	#2,act(a0)
	move.w	#$80,inertia(a0)

loc_5D20:
	bsr.w	sub_5DC8
	bra.w	loc_5E2A
; ---------------------------------------------------------------------------

loc_5D2C:
	btst	#1,status(a0)
	bne.w	loc_5D86
	bsr.w	sub_5DC8
	bsr.w	sub_5E50
	bsr.w	ObjectMove
	move.w	#$23,d1
	move.w	#$18,d2
	move.w	#$18,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	jsr ObjSonic_AnglePosition
	cmpi.w	#$20,xpos(a0)
	bcc.s	loc_5D70
	move.w	#$20,xpos(a0)
	move.w	#$400,inertia(a0)

loc_5D70:
	btst	#1,status(a0)
	beq.s	loc_5D7E
	move.w	#$FC00,yvel(a0)

loc_5D7E:
	bsr.w	ObjectDisplay
	bra.w	loc_5E2A
; ---------------------------------------------------------------------------

loc_5D86:
	bsr.w	sub_5DC8
	bsr.w	ObjectMove
	move.w	#$23,d1
	move.w	#$18,d2
	move.w	#$18,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	jsr ObjSonic_Floor
	btst	#1,status(a0)
	beq.s	loc_5DBE
	move.w	yvel(a0),d0
	addi.w	#$28,d0
	move.w	d0,yvel(a0)
	;bra.s	loc_5DC0
; ---------------------------------------------------------------------------

loc_5DBE:

loc_5DC0:
	bra.w	loc_5E2A
; ---------------------------------------------------------------------------

sub_5DC8:
	tst.b	frame(a0)
	beq.s	loc_5DD6
	move.b	#0,frame(a0)
	rts
; ---------------------------------------------------------------------------

loc_5DD6:
	move.b	inertia(a0),d0
	beq.s	loc_5E02
	bmi.s	loc_5E0A
	subq.b	#1,anidelay(a0)
	bpl.s	loc_5E02
	neg.b	d0
	addq.b	#8,d0
	bcs.s	loc_5DEC
	moveq	#0,d0

loc_5DEC:
	move.b	d0,anidelay(a0)
	move.b	storedframe(a0),d0
	addq.b	#1,d0
	cmpi.b	#4,d0
	bne.s	loc_5DFE
	moveq	#1,d0

loc_5DFE:
	move.b	d0,storedframe(a0)

loc_5E02:
	move.b	storedframe(a0),frame(a0)
	rts
; ---------------------------------------------------------------------------

loc_5E0A:
	subq.b	#1,anidelay(a0)
	bpl.s	loc_5E02
	addq.b	#8,d0
	bcs.s	loc_5E16
	moveq	#0,d0

loc_5E16:
	move.b	d0,anidelay(a0)
	move.b	storedframe(a0),d0
	subq.b	#1,d0
	bne.s	loc_5E24
	moveq	#3,d0

loc_5E24:
	move.b	d0,storedframe(a0)
	bra.s	loc_5E02
; ---------------------------------------------------------------------------

loc_5E2A:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_5E4A:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

sub_5E50:
	move.b	angle(a0),d0
	bsr.w	GetSine
	move.w	d0,d2
	muls.w	#$38,d2
	asr.l	#8,d2
	add.w	d2,inertia(a0)
	muls.w	inertia(a0),d1
	asr.l	#8,d1
	move.w	d1,xvel(a0)
	muls.w	inertia(a0),d0
	asr.l	#8,d0
	move.w	d0,yvel(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/GHZ/RollingBall/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjCollapsePtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_5EEE(pc,d0.w),d1
	jmp off_5EEE(pc,d1.w)
; ---------------------------------------------------------------------------

off_5EEE:   dc.w loc_5EFA-off_5EEE, loc_5F2A-off_5EEE, loc_5F4E-off_5EEE, loc_5F7E-off_5EEE, loc_5FDE-off_5EEE
	dc.w sub_5F60-off_5EEE
; ---------------------------------------------------------------------------

loc_5EFA:
	addq.b	#2,act(a0)
	move.l	#MapCollapsePtfm,4(a0)
	move.w	#$4000,tile(a0)
	ori.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#7,convex(a0)
	move.b	#$64,xpix(a0)
	move.b	arg(a0),frame(a0)

loc_5F2A:
	tst.b	$3A(a0)
	beq.s	loc_5F3C
	tst.b	convex(a0)
	beq.w	loc_612A
	subq.b	#1,convex(a0)

loc_5F3C:
	move.w	#$30,d1
	lea (ObjCollapsePtfm_Slope).l,a2
	bsr.w	PtfmSloped
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

loc_5F4E:
	tst.b	convex(a0)
	beq.w	loc_6130
	move.b	#1,$3A(a0)
	subq.b	#1,convex(a0)
; ---------------------------------------------------------------------------

sub_5F60:
	move.w	#$30,d1
	bsr.w	PtfmCheckExit
	move.w	#$30,d1
	lea (ObjCollapsePtfm_Slope).l,a2
	move.w	xpos(a0),d2
	bsr.w	sub_61E0
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

loc_5F7E:
	tst.b	convex(a0)
	beq.s	loc_5FCE
	tst.b	$3A(a0)
	bne.w	loc_5F94
	subq.b	#1,convex(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_5F94:
	subq.b	#1,convex(a0)
	bsr.w	sub_5F60
	lea (ObjectsList).w,a1
	btst	#3,status(a1)
	beq.s	loc_5FC0
	tst.b	convex(a0)
	bne.s	locret_5FCC
	bclr	#3,status(a1)
	bclr	#5,status(a1)
	move.b	#1,anilast(a1)

loc_5FC0:
	move.b	#0,$3A(a0)
	move.b	#6,act(a0)

locret_5FCC:
	rts
; ---------------------------------------------------------------------------

loc_5FCE:
	tst.b	render(a0)
	bpl.s	loc_5FDE
	bsr.w	ObjectFall
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_5FDE:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjCollapseFloor:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_5FF2(pc,d0.w),d1
	jmp off_5FF2(pc,d1.w)
; ---------------------------------------------------------------------------

off_5FF2:   dc.w loc_5FFE-off_5FF2, loc_603A-off_5FF2, loc_607C-off_5FF2, loc_60A2-off_5FF2, loc_6102-off_5FF2
	dc.w sub_608E-off_5FF2
; ---------------------------------------------------------------------------

loc_5FFE:
	addq.b	#2,act(a0)
	move.l	#MapCollapseFloor,4(a0)
	move.w	#$42B8,tile(a0)
	cmpi.b	#3,(curzone).w
	bne.s	loc_6022
	move.w	#$44E0,tile(a0)
	addq.b	#2,frame(a0)

loc_6022:
	ori.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#7,convex(a0)
	move.b	#$44,xpix(a0)

loc_603A:
	tst.b	$3A(a0)
	beq.s	loc_604C
	tst.b	convex(a0)
	beq.w	loc_6108
	subq.b	#1,convex(a0)

loc_604C:
	move.w	#$20,d1
	bsr.w	PtfmNormal
	tst.b	arg(a0)
	bpl.s	loc_6078
	btst	#3,status(a1)
	beq.s	loc_6078
	bclr	#0,render(a0)
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	bcc.s	loc_6078
	bset	#0,render(a0)

loc_6078:
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

loc_607C:
	tst.b	convex(a0)
	beq.w	loc_610E
	move.b	#1,$3A(a0)
	subq.b	#1,convex(a0)
; ---------------------------------------------------------------------------

sub_608E:
	move.w	#$20,d1
	bsr.w	PtfmCheckExit
	move.w	xpos(a0),d2
	bsr.w	ptfmSurfaceNormal
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

loc_60A2:
	tst.b	convex(a0)
	beq.s	loc_60F2
	tst.b	$3A(a0)
	bne.w	loc_60B8
	subq.b	#1,convex(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_60B8:
	subq.b	#1,convex(a0)
	bsr.w	sub_608E
	lea (ObjectsList).w,a1
	btst	#3,status(a1)
	beq.s	loc_60E4
	tst.b	convex(a0)
	bne.s	locret_60F0
	bclr	#3,status(a1)
	bclr	#5,status(a1)
	move.b	#1,anilast(a1)

loc_60E4:
	move.b	#0,$3A(a0)
	move.b	#6,act(a0)

locret_60F0:
	rts
; ---------------------------------------------------------------------------

loc_60F2:
	tst.b	render(a0)
	bpl.s	loc_6102
	bsr.w	ObjectFall
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_6102:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

loc_6108:
	move.b	#0,$3A(a0)

loc_610E:
	lea (ObjCollapseFloor_Delay2).l,a4
	btst	#0,arg(a0)
	beq.s	loc_6122
	lea (ObjCollapseFloor_Delay3).l,a4

loc_6122:
	moveq	#7,d1
	addq.b	#1,frame(a0)
	bra.s	loc_613C
; ---------------------------------------------------------------------------

loc_612A:
	move.b	#0,$3A(a0)

loc_6130:
	lea (ObjCollapseFloor_Delay1).l,a4
	moveq	#$18,d1
	addq.b	#2,frame(a0)

loc_613C:
	moveq	#0,d0
	move.b	frame(a0),d0
	add.w	d0,d0
	movea.l 4(a0),a3
	adda.w	(a3,d0.w),a3
	addq.w	#1,a3
	bset	#5,render(a0)
	move.b	id(a0),d4
	move.b	render(a0),d5
	movea.l a0,a1
	bra.s	loc_6168
; ---------------------------------------------------------------------------

loc_6160:
	bsr.w	ObjectLoad
	bne.s	loc_61A8
	addq.w	#5,a3

loc_6168:
	move.b	#6,act(a1)
	move.b	d4,id(a1)
	move.l	a3,4(a1)
	move.b	d5,render(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.w	tile(a0),tile(a1)
	move.w	prio(a0),prio(a1)
	move.b	xpix(a0),xpix(a1)
	move.b	(a4)+,convex(a1)
	cmpa.l	a0,a1
	bcc.s	loc_61A4
	bsr.w	ObjectDisplayA1

loc_61A4:
	dbf d1,loc_6160

loc_61A8:
	sfx	sfx_Collapse
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjCollapseFloor_Delay1:dc.b $1C, $18, $14, $10, $1A, $16, $12, $E, $A, 6, $18
	dc.b $14, $10, $C, 8, 4, $16, $12, $E, $A, 6, 2, $14, $10
	dc.b $C, 0

ObjCollapseFloor_Delay2:dc.b $1E, $16, $E, 6, $1A, $12, $A, 2

ObjCollapseFloor_Delay3:dc.b $16, $1E, $1A, $12, 6, $E, $A, 2
; ---------------------------------------------------------------------------

sub_61E0:
	lea (ObjectsList).w,a1
	btst	#3,status(a1)
	beq.s	locret_6224
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	lsr.w	#1,d0
	btst	#0,render(a0)
	beq.s	loc_6204
	not.w	d0
	add.w	d1,d0

loc_6204:
	moveq	#0,d1
	move.b	(a2,d0.w),d1
	move.w	ypos(a0),d0
	sub.w	d1,d0
	moveq	#0,d1
	move.b	yrad(a1),d1
	sub.w	d1,d0
	move.w	d0,ypos(a1)
	sub.w	xpos(a0),d2
	sub.w	d2,xpos(a1)

locret_6224:
	rts
; ---------------------------------------------------------------------------

ObjCollapsePtfm_Slope:dc.b $20, $20, $20, $20, $20, $20, $20, $20, $21, $21
	dc.b $22, $22, $23, $23, $24, $24, $25, $25, $26, $26
	dc.b $27, $27, $28, $28, $29, $29, $2A, $2A, $2B, $2B
	dc.b $2C, $2C, $2D, $2D, $2E, $2E, $2F, $2F, $30, $30
	dc.b $30, $30, $30, $30, $30, $30, $30, $30
	include "unknown/06526.map"
	include "levels/GHZ/CollapsePtfm/Sprite.map"
	include "levels/GHZ/CollapseFloor/Sprite.map"
	even
; ---------------------------------------------------------------------------

Obj1B:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_6634(pc,d0.w),d1
	jmp off_6634(pc,d1.w)
; ---------------------------------------------------------------------------

off_6634:   dc.w loc_663E-off_6634, loc_6676-off_6634, loc_668A-off_6634, loc_66CE-off_6634, loc_66D6-off_6634
; ---------------------------------------------------------------------------

loc_663E:
	addq.b	#2,act(a0)
	move.l	#Map1B,map(a0)
	move.w	#$4000,tile(a0)
	move.b	#4,render(a0)
	move.b	#$20,xpix(a0)
	move.w	#$280,prio(a0)
	tst.b	arg(a0)
	bne.s	loc_6676
	move.w	#$80,prio(a0)
	move.b	#6,act(a0)
	rts
; ---------------------------------------------------------------------------

loc_6676:
	move.w	#$20,d1
	move.w	#-$14,d3
	bsr.w	PtfmNormalHeight
	bra.s	loc_66A8
; ---------------------------------------------------------------------------

loc_668A:
	move.w	#$20,d1
	bsr.w	PtfmCheckExit
	move.w	xpos(a0),d2
	move.w	#-$14,d3
	bsr.w	PtfmSurfaceHeight
; ---------------------------------------------------------------------------

loc_66A8:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	loc_66C8
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_66C8:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

loc_66CE:
	bra.s	loc_66A8
; ---------------------------------------------------------------------------

loc_66D6:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

Map1B:	    dc.w byte_66E0-Map1B, byte_66F5-Map1B

byte_66E0:  dc.b 4
	dc.b $F0, $A, 0, $89, $E0
	dc.b $F0, $A, 8, $89, 8
	dc.b $F8, 5, 0, $92, $F8
	dc.b 8, $C, 0, $96, $F0

byte_66F5:  dc.b 4
	dc.b $E8, $F, 0, $9A, $E0
	dc.b $E8, $F, 8, $9A, 0
	dc.b 8, $D, 0, $AA, $E0
	dc.b 8, $D, 8, $AA, 0
; ---------------------------------------------------------------------------

ObjScenery:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_6718(pc,d0.w),d1
	jmp off_6718(pc,d1.w)
; ---------------------------------------------------------------------------

off_6718:   dc.w ObjScenery_Init-off_6718, ObjScenery_Normal-off_6718, ObjScenery_Delete-off_6718, ObjScenery_Delete-off_6718
; ---------------------------------------------------------------------------

ObjScenery_Init:
	addq.b	#2,act(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	mulu.w	#10,d0
	lea ObjScenery_Types(pc,d0.w),a1
	move.l	(a1)+,map(a0)
	move.w	(a1)+,tile(a0)
	ori.b	#4,render(a0)
	move.b	(a1)+,frame(a0)
	move.b	(a1)+,xpix(a0)
	move.b	(a1)+,prio(a0)
	move.b	(a1)+,col(a0)

ObjScenery_Normal:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjScenery_Delete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjScenery_Delete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjScenery_Types:dc.l MapScenery
	dc.w $398
	dc.b 0, $10, 4, $82
	dc.l MapScenery
	dc.w $398
	dc.b 1, $14, 4, $83
	dc.l MapScenery
	dc.w $4000
	dc.b 0, $20, 1, 0
	dc.l MapBridge
	dc.w $438E
	dc.b 1, $10, 1, 0
	include "levels/shared/Scenery/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjUnkSwitch:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_67C8(pc,d0.w),d1
	jmp off_67C8(pc,d1.w)
; ---------------------------------------------------------------------------

off_67C8:   dc.w loc_67CE-off_67C8, loc_67F8-off_67C8, loc_6836-off_67C8
; ---------------------------------------------------------------------------

loc_67CE:
	addq.b	#2,act(a0)
	move.l	#MapUnkSwitch,map(a0)
	move.w	#$4000,tile(a0)
	move.b	#4,render(a0)
	move.w	ypos(a0),$30(a0)
	move.b	#$10,xpix(a0)
	move.w	#$280,prio(a0)

loc_67F8:
	move.w	$30(a0),ypos(a0)
	move.w	#$10,d1
	bsr.w	sub_683C
	beq.s	loc_6812
	addq.w	#2,ypos(a0)
	moveq	#1,d0
	move.w	d0,(unk_FFF7E0).w

loc_6812:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	loc_6836
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_6836:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

sub_683C:
	lea (ObjectsList).w,a1
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.s	loc_6874
	add.w	d1,d1
	cmp.w	d1,d0
	bcc.s	loc_6874
	move.w	ypos(a1),d2
	move.b	yrad(a1),d1
	ext.w	d1
	add.w	d2,d1
	move.w	ypos(a0),d0
	subi.w	#$10,d0
	sub.w	d1,d0
	bhi.s	loc_6874
	cmpi.w	#$FFF0,d0
	bcs.s	loc_6874
	moveq	#-1,d0
	rts
; ---------------------------------------------------------------------------

loc_6874:
	moveq	#0,d0
	rts
; ---------------------------------------------------------------------------
	include "unsorted/Uknown Switch.map"
	even
; ---------------------------------------------------------------------------

Obj2A:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_689E(pc,d0.w),d1
	jmp off_689E(pc,d1.w)
; ---------------------------------------------------------------------------

off_689E:   dc.w loc_68A4-off_689E, loc_68F0-off_689E, loc_6912-off_689E
; ---------------------------------------------------------------------------

loc_68A4:
	addq.b	#2,act(a0)
	move.l	#Map2A,map(a0)
	move.w	#0,tile(a0)
	move.b	#4,render(a0)
	move.w	ypos(a0),d0
	subi.w	#$20,d0
	move.w	d0,$30(a0)
	move.b	#$B,xpix(a0)
	move.w	#$280,prio(a0)
	tst.b	arg(a0)
	beq.s	loc_68F0
	move.b	#1,frame(a0)
	move.w	#$4000,tile(a0)
	move.w	#$200,prio(a0)
	addq.b	#2,act(a0)

loc_68F0:
	tst.w	(unk_FFF7E0).w
	beq.s	loc_6906
	subq.w	#1,ypos(a0)
	move.w	$30(a0),d0
	cmp.w	ypos(a0),d0
	beq.w	ObjectDelete

loc_6906:
	move.w	#$16,d1
	move.w	#$10,d2
	bsr.w	sub_6936

loc_6912:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_6936:
	tst.w	(DebugRoutine).w
	bne.w	locret_69A6
	cmpi.b 	#6,(ObjectsList+act).w
	bcc.s  	locret_69A6
	bsr.w	sub_69CE
	beq.s	loc_698C
	bmi.w	loc_69A8
	tst.w	d0
	beq.w	loc_6976
	bmi.s	loc_6960
	tst.w	xvel(a1)
	bmi.s	loc_6976
	bra.s	loc_6966
; ---------------------------------------------------------------------------

loc_6960:
	tst.w	xvel(a1)
	bpl.s	loc_6976

loc_6966:
	sub.w	d0,xpos(a1)
	clr.w  	inertia(a1)
	clr.w  	xvel(a1)

loc_6976:
	btst	#1,status(a1)
	bne.s	loc_699A
	bset	#5,status(a1)
	bset	#5,status(a0)
	rts
; ---------------------------------------------------------------------------

loc_698C:
	btst	#5,status(a0)
	beq.s	locret_69A6
	move.w	#1,ani(a1)

loc_699A:
	bclr	#5,status(a0)
	bclr	#5,status(a1)

locret_69A6:
	rts
; ---------------------------------------------------------------------------

loc_69A8:
	tst.w	yvel(a1)
	beq.s	loc_69C0
	bpl.s	locret_69BE
	tst.w	d3
	bpl.s	locret_69BE
	sub.w	d3,ypos(a1)
	move.w	#0,yvel(a1)

locret_69BE:
	rts
; ---------------------------------------------------------------------------

loc_69C0:
	move.l	a0,-(sp)
	movea.l a1,a0
	jsr loc_FD78
	movea.l (sp)+,a0
	rts
; ---------------------------------------------------------------------------

sub_69CE:
	lea (ObjectsList).w,a1
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.s	loc_6A28
	move.w	d1,d3
	add.w	d3,d3
	cmp.w	d3,d0
	bhi.s	loc_6A28
	move.b	yrad(a1),d3
	ext.w	d3
	add.w	d3,d2
	move.w	ypos(a1),d3
	sub.w	ypos(a0),d3
	add.w	d2,d3
	bmi.s	loc_6A28
	move.w	d2,d4
	add.w	d4,d4
	cmp.w	d4,d3
	bcc.s	loc_6A28
	move.w	d0,d5
	cmp.w	d0,d1
	bcc.s	loc_6A10
	add.w	d1,d1
	sub.w	d1,d0
	move.w	d0,d5
	neg.w	d5

loc_6A10:
	move.w	d3,d1
	cmp.w	d3,d2
	bcc.s	loc_6A1C
	sub.w	d4,d3
	move.w	d3,d1
	neg.w	d1

loc_6A1C:
	cmp.w	d1,d5
	bhi.s	loc_6A24
	moveq	#1,d4
	rts
; ---------------------------------------------------------------------------

loc_6A24:
	moveq	#-1,d4
	rts
; ---------------------------------------------------------------------------

loc_6A28:
	moveq	#0,d4
	rts
; ---------------------------------------------------------------------------
	include "unknown/Map2A.map"
	even
; ---------------------------------------------------------------------------

ObjTitleSonic:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_6A64(pc,d0.w),d1
	jmp off_6A64(pc,d1.w)
; ---------------------------------------------------------------------------

off_6A64:   dc.w loc_6A6C-off_6A64, loc_6AA0-off_6A64, loc_6AB0-off_6A64, loc_6AC6-off_6A64
; ---------------------------------------------------------------------------

loc_6A6C:
	addq.b	#2,act(a0)
	move.w	#$F8,xpos(a0)
	move.w	#$DE,xpix(a0)
	move.l	#MapTitleSonic,map(a0)
	move.w	#$2300,tile(a0)
	move.w	#$80,prio(a0)
	move.b	#$1D,storedframe(a0)
	lea (AniTitleSonic).l,a1
	bsr.w	ObjectAnimate

loc_6AA0:
	subq.b	#1,storedframe(a0)
	bpl.s	locret_6AAE
	addq.b	#2,act(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

locret_6AAE:
	rts
; ---------------------------------------------------------------------------

loc_6AB0:
	subq.w	#8,xpix(a0)
	cmpi.w	#$96,xpix(a0)
	bne.s	loc_6AC0
	addq.b	#2,act(a0)

loc_6AC0:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_6AC6:
	lea (AniTitleSonic).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

OibjTitleText:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_6AE8(pc,d0.w),d1
	jsr off_6AE8(pc,d1.w)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_6AE8:   dc.w loc_6AEE-off_6AE8, loc_6B1A-off_6AE8, locret_6B18-off_6AE8
; ---------------------------------------------------------------------------

loc_6AEE:
	addq.b	#2,act(a0)
	move.w	#$D8,xpos(a0)
	move.w	#$130,xpix(a0)
	move.l	#MapTitleText,map(a0)
	move.w	#$200,tile(a0)
	cmpi.b	#2,frame(a0)
	bne.s	loc_6B1A
	addq.b	#2,act(a0)

locret_6B18:
	rts
; ---------------------------------------------------------------------------

loc_6B1A:
	lea (AniTitleText).l,a1
	bra.s	ObjectAnimate
; ---------------------------------------------------------------------------
	include "screens/title/TitleSonic/Sprite.ani"
	include "screens/title/TitleText/Sprite.ani"
	even
; ---------------------------------------------------------------------------

ObjectAnimate:
	moveq	#0,d0
	move.b	ani(a0),d0
	cmp.b	anilast(a0),d0
	beq.s	loc_6B54
	move.b	d0,anilast(a0)
	clr.b	anipos(a0)
	clr.b	anidelay(a0)

loc_6B54:
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	subq.b	#1,anidelay(a0)
	bpl.s	locret_6B94
	move.b	(a1),anidelay(a0)
	moveq	#0,d1
	move.b	anipos(a0),d1
	move.b	render(a1,d1.w),d0
	cmp.b	#$FA,d0
	bhs.s	loc_6B96

loc_6B70:
	move.b	d0,d1
	andi.b	#$1F,d0
	move.b	d0,frame(a0)
	move.b	status(a0),d0
	andi.b	#3,d0
	andi.b	#$FC,render(a0)
	lsr.b	#5,d1
	eor.b	d0,d1
	or.b	d1,render(a0)
	addq.b	#1,anipos(a0)

locret_6B94:
	rts
; ---------------------------------------------------------------------------

loc_6B96:
	addq.b	#1,d0
	bne.s	loc_6BA6
	clr.b	anipos(a0)
	move.b	render(a1),d0
	bra.s	loc_6B70
; ---------------------------------------------------------------------------

loc_6BA6:
	addq.b	#1,d0
	bne.s	loc_6BBA
	move.b	tile(a1,d1.w),d0
	sub.b	d0,anipos(a0)
	sub.b	d0,d1
	move.b	render(a1,d1.w),d0
	bra.s	loc_6B70
; ---------------------------------------------------------------------------

loc_6BBA:
	addq.b	#1,d0
	bne.s	loc_6BC4
	move.b	tile(a1,d1.w),ani(a0)

loc_6BC4:
	addq.b	#1,d0
	bne.s	loc_6BCC
	addq.b	#2,act(a0)

loc_6BCC:
	addq.b	#1,d0
	bne.s	locret_6BDA
	clr.b	anipos(a0)
	clr.b	subact(a0)

locret_6BDA:
	rts
; ---------------------------------------------------------------------------
	include "screens/title/TitleText/Sprite.map"
	include "screens/title/TitleSonic/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjBallhog:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_6F3E(pc,d0.w),d1
	jmp off_6F3E(pc,d1.w)
; ---------------------------------------------------------------------------

off_6F3E:   dc.w loc_6F46-off_6F3E, loc_6F96-off_6F3E, loc_7056-off_6F3E, loc_705C-off_6F3E
; ---------------------------------------------------------------------------

loc_6F46:
	move.b	#$13,yrad(a0)
	move.b	#8,xrad(a0)
	move.l	#MapBallhog,4(a0)
	move.w	#$2400,tile(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#5,col(a0)
	move.b	#$C,xpix(a0)
	bsr.w	ObjectFall
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	locret_6F94
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,act(a0)

locret_6F94:
	rts
; ---------------------------------------------------------------------------

loc_6F96:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_6FB2(pc,d0.w),d1
	jsr off_6FB2(pc,d1.w)
	lea (AniBallhog).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_6FB2:   dc.w loc_6FB6-off_6FB2, loc_701C-off_6FB2
; ---------------------------------------------------------------------------

loc_6FB6:
	subq.w	#1,$30(a0)
	bpl.s	loc_6FE6
	addq.b	#2,subact(a0)
	move.w	#$FF,$30(a0)
	move.w	#$40,xvel(a0)
	move.b	#1,ani(a0)
	bchg	#0,status(a0)
	bne.s	loc_6FDE
	neg.w	xvel(a0)

loc_6FDE:
	move.b	#0,$32(a0)
	rts
; ---------------------------------------------------------------------------

loc_6FE6:
	tst.b	$32(a0)
	bne.s	locret_6FF4
	cmpi.b	#2,frame(a0)
	beq.s	loc_6FF6

locret_6FF4:
	rts
; ---------------------------------------------------------------------------

loc_6FF6:
	move.b	#1,$32(a0)
	bsr.w	ObjectLoad
	bne.s	locret_701A
	move.b	#$20,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	addi.w	#$10,ypos(a1)

locret_701A:
	rts
; ---------------------------------------------------------------------------

loc_701C:
	subq.w	#1,$30(a0)
	bmi.s	loc_7032
	bsr.w	ObjectMove
	jsr ObjectHitFloor
	add.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_7032:
	subq.b	#2,subact(a0)
	move.w	#$3B,$30(a0)
	move.w	#0,xvel(a0)
	move.b	#0,ani(a0)
	tst.b	render(a0)
	bpl.s	locret_7054
	move.b	#2,ani(a0)

locret_7054:
	rts
; ---------------------------------------------------------------------------

loc_7056:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_705C:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjCannonball:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7070(pc,d0.w),d1
	jmp off_7070(pc,d1.w)
; ---------------------------------------------------------------------------

off_7070:   dc.w ObjCannonball_Init-off_7070, ObjCannonball_Act-off_7070, ObjCannonball_Delete-off_7070
; ---------------------------------------------------------------------------

ObjCannonball_Init:
	addq.b	#2,act(a0)
	move.l	#MapCannonball,map(a0)
	move.w	#$2418,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$87,col(a0)
	move.b	#8,xpix(a0)
	move.w	#$18,$30(a0)

ObjCannonball_Act:
	btst	#7,status(a0)
	bne.s	loc_70C2
	tst.w	$30(a0)
	bne.s	loc_70D2
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	loc_70D6
	add.w	d1,ypos(a0)

loc_70C2:
	move.b	#$24,id(a0)
	move.b	#0,act(a0)
	bra.w	ObjCannonballExplode
; ---------------------------------------------------------------------------

loc_70D2:
	subq.w	#1,$30(a0)

loc_70D6:
	bsr.w	ObjectFall
	bsr.w	ObjectDisplay
	move.w	(unk_FFF72E).w,d0
	addi.w	#224,d0
	cmp.w	ypos(a0),d0
	bcs.s	ObjCannonball_Delete
	rts
; ---------------------------------------------------------------------------

ObjCannonball_Delete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjCannonballExplode:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7102(pc,d0.w),d1
	jmp off_7102(pc,d1.w)
; ---------------------------------------------------------------------------

off_7102:   dc.w ObjCannonballExplode_Init-off_7102, ObjCannonballExplode_Act-off_7102
; ---------------------------------------------------------------------------

ObjCannonballExplode_Init:
	addq.b	#2,act(a0)
	move.l	#MapCannonballExplode,map(a0)
	move.w	#$41C,tile(a0)
	move.b	#4,render(a0)
	move.w	#$100,prio(a0)
	move.b	#0,col(a0)
	move.b	#$C,xpix(a0)
	move.b	#9,anidelay(a0)
	move.b	#0,frame(a0)
	sfx	sfx_UnkA2

ObjCannonballExplode_Act:
	subq.b	#1,anidelay(a0)
	bpl.s	.disp
	move.b	#9,anidelay(a0)
	addq.b	#1,frame(a0)
	cmpi.b	#4,frame(a0)
	beq.w	ObjectDelete

.disp:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjExplode:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7172(pc,d0.w),d1
	jmp off_7172(pc,d1.w)
; ---------------------------------------------------------------------------

off_7172:   dc.w ObjExplode_Load-off_7172, ObjExplode_Init-off_7172, ObjExplode_Act-off_7172
; ---------------------------------------------------------------------------

ObjExplode_Load:
	addq.b	#2,act(a0)
	bsr.w	ObjectLoad
	bne.s	ObjExplode_Init
	move.b	#$28,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)

ObjExplode_Init:
	addq.b	#2,act(a0)
	move.l	#MapExplode,map(a0)
	move.w	#$5A0,tile(a0)
	move.b	#4,render(a0)
	move.w	#$100,prio(a0)
	move.b	#0,col(a0)
	move.b	#12,xpix(a0)
	move.b	#7,anidelay(a0)
	move.b	#0,frame(a0)
	sfx	sfx_Break

ObjExplode_Act:
	subq.b	#1,anidelay(a0)
	bpl.s	.display
	move.b	#7,anidelay(a0)
	addq.b	#1,frame(a0)
	cmpi.b	#5,frame(a0)
	beq.w	ObjectDelete

.display:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjBombExplode:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7200(pc,d0.w),d1
	jmp off_7200(pc,d1.w)
; ---------------------------------------------------------------------------

off_7200:   dc.w ObjBomb_Init-off_7200, ObjExplode_Act-off_7200
; ---------------------------------------------------------------------------

ObjBomb_Init:
	addq.b	#2,act(a0)
	move.l	#MapBombExplode,map(a0)
	move.w	#$5A0,tile(a0)
	move.b	#4,render(a0)
	move.w	#$100,prio(a0)
	move.b	#0,col(a0)
	move.b	#$C,xpix(a0)
	move.b	#7,anidelay(a0)
	move.b	#0,frame(a0)
	sfx	sfx_BuzzExplode
	rts
; ---------------------------------------------------------------------------
	include "levels/GHZ/BallHog/Sprite.ani"
	include "levels/GHZ/BallHog/Sprite.map"
	include "levels/GHZ/BallHog/Cannonball.map"
	include "levels/GHZ/BallHog/CannonballExplode.map"
	include "levels/shared/Explosion/Sprite.map"
	include "levels/shared/Explosion/Bomb.map"
	even
; ---------------------------------------------------------------------------

ObjAnimals:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_732C(pc,d0.w),d1
	jmp off_732C(pc,d1.w)
; ---------------------------------------------------------------------------

off_732C:   dc.w loc_7382-off_732C, loc_7418-off_732C, loc_7472-off_732C, loc_74A8-off_732C, loc_7472-off_732C
	dc.w loc_7472-off_732C, loc_7472-off_732C, loc_74A8-off_732C, loc_7472-off_732C

byte_733E:  dc.b 0, 1, 2, 3, 4, 5, 6, 3, 4, 1, 0, 5

word_734A:  dc.w $FE00, $FC00
	dc.l MapAnimals1
	dc.w $FE00, $FD00
	dc.l MapAnimals2
	dc.w $FEC0, $FE00
	dc.l MapAnimals1
	dc.w $FF00, $FE80
	dc.l MapAnimals2
	dc.w $FE80, $FD00
	dc.l MapAnimals3
	dc.w $FD00, $FC00
	dc.l MapAnimals2
	dc.w $FD80, $FC80
	dc.l MapAnimals3
; ---------------------------------------------------------------------------

loc_7382:
	addq.b	#2,act(a0)
	bsr.w	RandomNumber
	andi.w	#1,d0
	moveq	#0,d1
	move.b	(curzone).w,d1
	add.w	d1,d1
	add.w	d0,d1
	move.b	byte_733E(pc,d1.w),d0
	move.b	d0,$30(a0)
	lsl.w	#3,d0
	lea word_734A(pc,d0.w),a1
	move.w	(a1)+,$32(a0)
	move.w	(a1)+,$34(a0)
	move.l	(a1)+,map(a0)
	move.w	#$580,tile(a0)
	btst	#0,$30(a0)
	beq.s	loc_73C6
	move.w	#$592,tile(a0)

loc_73C6:
	move.b	#$C,yrad(a0)
	move.b	#4,render(a0)
	bset	#0,render(a0)
	move.w	#$300,prio(a0)
	move.b	#8,xpix(a0)
	move.b	#7,anidelay(a0)
	move.b	#2,frame(a0)
	move.w	#-$400,yvel(a0)
	tst.b	(unk_FFF7A7).w
	bne.s	loc_7438
	bsr.w	ObjectLoad
	bne.s	loc_7414
	move.b	#$29,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)

loc_7414:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_7418:
	tst.b	render(a0)
	bpl.w	ObjectDelete
	bsr.w	ObjectFall
	tst.w	yvel(a0)
	bmi.s	loc_746E
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	loc_746E
	add.w	d1,ypos(a0)

loc_7438:
	move.w	$32(a0),xvel(a0)
	move.w	$34(a0),yvel(a0)
	move.b	#1,frame(a0)
	move.b	$30(a0),d0
	add.b	d0,d0
	addq.b	#4,d0
	move.b	d0,act(a0)
	tst.b	(unk_FFF7A7).w
	beq.s	loc_746E
	btst	#4,(byte_FFFE0F).w
	beq.s	loc_746E
	neg.w	xvel(a0)
	bchg	#0,render(a0)

loc_746E:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_7472:
	bsr.w	ObjectFall
	move.b	#1,frame(a0)
	tst.w	yvel(a0)
	bmi.s	loc_749C
	move.b	#0,frame(a0)
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	loc_749C
	add.w	d1,ypos(a0)
	move.w	$34(a0),yvel(a0)

loc_749C:
	tst.b	render(a0)
	bpl.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_74A8:
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	tst.w	yvel(a0)
	bmi.s	loc_74CC
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	loc_74CC
	add.w	d1,ypos(a0)
	move.w	$34(a0),yvel(a0)

loc_74CC:
	subq.b	#1,anidelay(a0)
	bpl.s	loc_74E2
	move.b	#1,anidelay(a0)
	addq.b	#1,frame(a0)
	andi.b	#1,frame(a0)

loc_74E2:
	tst.b	render(a0)
	bpl.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjPoints:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7500(pc,d0.w),d1
	jsr off_7500(pc,d1.w)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_7500:   dc.w ObjPoints_Init-off_7500, ObjPoints_Act-off_7500
; ---------------------------------------------------------------------------

ObjPoints_Init:
	addq.b	#2,act(a0)
	move.l	#MapPoints,map(a0)
	move.w	#$2797,tile(a0)
	move.b	#4,render(a0)
	move.w	#$80,prio(a0)
	move.b	#8,xpix(a0)
	move.w	#-$300,yvel(a0)

ObjPoints_Act:
	tst.w	yvel(a0)
	bpl.w	ObjectDelete
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Animals/1.map"
	include "levels/shared/Animals/2.map"
	include "levels/shared/Animals/3.map"
	include "levels/shared/Points/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjCrabmeat:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_75B8(pc,d0.w),d1
	jmp off_75B8(pc,d1.w)
; ---------------------------------------------------------------------------

off_75B8:   dc.w loc_75C2-off_75B8, loc_7616-off_75B8, loc_7772-off_75B8, loc_7778-off_75B8, loc_77AE-off_75B8
; ---------------------------------------------------------------------------

loc_75C2:
	move.b	#$10,yrad(a0)
	move.b	#8,xrad(a0)
	move.l	#MapCrabmeat,4(a0)
	move.w	#$400,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#6,col(a0)
	move.b	#$15,xpix(a0)
	bsr.w	ObjectFall
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	locret_7614
	add.w	d1,ypos(a0)
	move.b	d3,angle(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,act(a0)

locret_7614:
	rts
; ---------------------------------------------------------------------------

loc_7616:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_7632(pc,d0.w),d1
	jsr off_7632(pc,d1.w)
	lea (AniCrabmeat).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_7632:   dc.w loc_7636-off_7632, loc_76D4-off_7632
; ---------------------------------------------------------------------------

loc_7636:
	subq.w	#1,$30(a0)
	bpl.s	locret_7670
	tst.b	render(a0)
	bpl.s	loc_764A
	bchg	#1,$32(a0)
	bne.s	loc_7672

loc_764A:
	addq.b	#2,subact(a0)
	move.w	#$7F,$30(a0)
	move.w	#$80,xvel(a0)
	bsr.w	sub_7742
	addq.b	#3,d0
	move.b	d0,ani(a0)
	bchg	#0,status(a0)
	bne.s	locret_7670
	neg.w	xvel(a0)

locret_7670:
	rts
; ---------------------------------------------------------------------------

loc_7672:
	move.w	#$3B,$30(a0)
	move.b	#6,ani(a0)
	bsr.w	ObjectLoad
	bne.s	loc_76A8
	move.b	#$1F,id(a1)
	move.b	#6,act(a1)
	move.w	xpos(a0),xpos(a1)
	subi.w	#$10,xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.w	#$FF00,xvel(a1)

loc_76A8:
	bsr.w	ObjectLoad
	bne.s	locret_76D2
	move.b	#$1F,id(a1)
	move.b	#6,act(a1)
	move.w	xpos(a0),xpos(a1)
	addi.w	#$10,xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.w	#$100,xvel(a1)

locret_76D2:
	rts
; ---------------------------------------------------------------------------

loc_76D4:
	subq.w	#1,$30(a0)
	bmi.s	loc_7728
	bsr.w	ObjectMove
	bchg	#0,$32(a0)
	bne.s	loc_770E
	move.w	xpos(a0),d3
	addi.w	#$10,d3
	btst	#0,status(a0)
	beq.s	loc_76FA
	subi.w	#$20,d3

loc_76FA:
	jsr ObjectHitFloor2
	cmpi.w	#$FFF8,d1
	blt.s	loc_7728
	cmpi.w	#$C,d1
	bge.s	loc_7728
	rts
; ---------------------------------------------------------------------------

loc_770E:
	jsr ObjectHitFloor
	add.w	d1,ypos(a0)
	move.b	d3,angle(a0)
	bsr.w	sub_7742
	addq.b	#3,d0
	move.b	d0,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_7728:
	subq.b	#2,subact(a0)
	move.w	#$3B,$30(a0)

loc_7732:
	move.w	#0,xvel(a0)
	bsr.w	sub_7742
	move.b	d0,ani(a0)
	rts
; ---------------------------------------------------------------------------

sub_7742:
	moveq	#0,d0
	move.b	angle(a0),d3
	bmi.s	loc_775E
	cmpi.b	#6,d3
	bcs.s	locret_775C
	moveq	#1,d0
	btst	#0,status(a0)
	bne.s	locret_775C
	moveq	#2,d0

locret_775C:
	rts
; ---------------------------------------------------------------------------

loc_775E:
	cmpi.b	#$FA,d3
	bhi.s	locret_7770
	moveq	#2,d0
	btst	#0,status(a0)
	bne.s	locret_7770
	moveq	#1,d0

locret_7770:
	rts
; ---------------------------------------------------------------------------

loc_7772:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

loc_7778:
	addq.b	#2,act(a0)
	move.l	#MapCrabmeat,4(a0)
	move.w	#$400,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$87,col(a0)
	move.b	#8,xpix(a0)
	move.w	#$FC00,yvel(a0)
	move.b	#7,ani(a0)

loc_77AE:
	lea (AniCrabmeat).l,a1
	bsr.w	ObjectAnimate
	bsr.w	ObjectFall
	bsr.w	ObjectDisplay
	move.w	(unk_FFF72E).w,d0
	addi.w	#$E0,d0
	cmp.w	ypos(a0),d0
	bcs.s	loc_77D0
	rts
; ---------------------------------------------------------------------------

loc_77D0:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/GHZ/Crabmeat/Sprite.ani"
	include "levels/GHZ/Crabmeat/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjBuzzbomber:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_78A6(pc,d0.w),d1
	jmp off_78A6(pc,d1.w)
; ---------------------------------------------------------------------------

off_78A6:   dc.w loc_78AC-off_78A6, loc_78D6-off_78A6, loc_79E6-off_78A6
; ---------------------------------------------------------------------------

loc_78AC:
	addq.b	#2,act(a0)
	move.l	#MapBuzzbomber,4(a0)
	move.w	#$444,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#8,col(a0)
	move.b	#$18,xpix(a0)

loc_78D6:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	loc_78F2(pc,d0.w),d1
	jsr loc_78F2(pc,d1.w)
	lea (AniBuzzbomber).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

loc_78F2:
	ori.b	#$9A,d4
	subq.w	#1,$32(a0)
	bpl.s	locret_7926
	btst	#1,$34(a0)
	bne.s	loc_7928
	addq.b	#2,subact(a0)
	move.w	#$7F,$32(a0)
	move.w	#$400,xvel(a0)
	move.b	#1,ani(a0)
	btst	#0,status(a0)
	bne.s	locret_7926
	neg.w	xvel(a0)

locret_7926:
	rts
; ---------------------------------------------------------------------------

loc_7928:
	bsr.w	ObjectLoad
	bne.s	locret_798A
	move.b	#$23,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	addi.w	#$1C,ypos(a1)
	move.w	#$200,yvel(a1)
	move.w	#$200,xvel(a1)
	move.w	#$18,d0
	btst	#0,status(a0)
	bne.s	loc_7964
	neg.w	d0
	neg.w	xvel(a1)

loc_7964:
	add.w	d0,xpos(a1)
	move.b	status(a0),status(a1)
	move.w	#$E,$32(a1)
	move.l	a0,$3C(a1)
	move.b	#1,$34(a0)
	move.w	#$3B,$32(a0)
	move.b	#2,ani(a0)

locret_798A:
	subq.w	#1,$32(a0)
	bmi.s	loc_79C2
	bsr.w	ObjectMove
	tst.b	$34(a0)
	bne.s	locret_79E4
	move.w	(ObjectsList+xpos).w,d0
	sub.w	xpos(a0),d0
	bpl.s	loc_79A8
	neg.w	d0

loc_79A8:
	cmpi.w	#$60,d0
	bcc.s	locret_79E4
	tst.b	render(a0)
	bpl.s	locret_79E4
	move.b	#2,$34(a0)
	move.w	#$1D,$32(a0)
	bra.s	loc_79D4
; ---------------------------------------------------------------------------

loc_79C2:
	move.b	#0,$34(a0)
	bchg	#0,status(a0)
	move.w	#$3B,$32(a0)

loc_79D4:
	subq.b	#2,subact(a0)
	move.w	#0,xvel(a0)
	move.b	#0,ani(a0)

locret_79E4:
	rts
; ---------------------------------------------------------------------------

loc_79E6:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjBuzzMissile:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_79FA(pc,d0.w),d1
	jmp off_79FA(pc,d1.w)
; ---------------------------------------------------------------------------

off_79FA:   dc.w loc_7A04-off_79FA, loc_7A4E-off_79FA, loc_7A6C-off_79FA, loc_7AB2-off_79FA, loc_7AB8-off_79FA
; ---------------------------------------------------------------------------

loc_7A04:
	subq.w	#1,$32(a0)
	bpl.s	sub_7A5E
	addq.b	#2,act(a0)
	move.l	#MapBuzzMissile,4(a0)
	move.w	#$2444,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#8,xpix(a0)
	andi.b	#3,status(a0)
	tst.b	arg(a0)
	beq.s	loc_7A4E
	move.b	#8,act(a0)
	move.b	#$87,col(a0)
	move.b	#1,ani(a0)
	bra.s	loc_7AC2
; ---------------------------------------------------------------------------

loc_7A4E:
	bsr.s	sub_7A5E
	lea (AniBuzzMissile).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_7A5E:
	movea.l $3C(a0),a1
	cmpi.b	#$27,id(a1)
	beq.s	loc_7AB2
	rts
; ---------------------------------------------------------------------------

loc_7A6C:
	btst	#7,status(a0)
	bne.s	loc_7AA2
	move.b	#$87,col(a0)
	move.b	#1,ani(a0)
	bsr.w	ObjectMove
	lea (AniBuzzMissile).l,a1
	bsr.w	ObjectAnimate
	bsr.w	ObjectDisplay
	move.w	(unk_FFF72E).w,d0
	addi.w	#$E0,d0
	cmp.w	ypos(a0),d0
	bcs.s	loc_7AB2
	rts
; ---------------------------------------------------------------------------

loc_7AA2:
	move.b	#$24,id(a0)
	move.b	#0,act(a0)
	bra.w	ObjCannonballExplode
; ---------------------------------------------------------------------------

loc_7AB2:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

loc_7AB8:
	tst.b	render(a0)
	bpl.s	loc_7AB2
	bsr.w	ObjectMove

loc_7AC2:
	lea (AniBuzzMissile).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/GHZ/Buzzbomber/Sprite.ani"
	include "levels/GHZ/Buzzbomber/Missile.ani"
	include "levels/GHZ/Buzzbomber/Sprite.map"
	include "levels/GHZ/Buzzbomber/Missile.map"
	even
; ---------------------------------------------------------------------------

ObjRings:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7BEE(pc,d0.w),d1
	jmp off_7BEE(pc,d1.w)
; ---------------------------------------------------------------------------

off_7BEE:   dc.w loc_7C18-off_7BEE, loc_7CD0-off_7BEE, loc_7CF8-off_7BEE, loc_7D1E-off_7BEE, loc_7D2C-off_7BEE

byte_7BF8:  dc.b $10, 0
	dc.b $18, 0
	dc.b $20, 0
	dc.b 0, $10
	dc.b 0, $18
	dc.b 0, $20
	dc.b $10, $10
	dc.b $18, $18
	dc.b $20, $20
	dc.b $F0, $10
	dc.b $E8, $18
	dc.b $E0, $20
	dc.b $10, 8
	dc.b $18, $10
	dc.b $F0, 8
	dc.b $E8, $10
; ---------------------------------------------------------------------------

loc_7C18:
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	lea tile(a2,d0.w),a2
	move.b	(a2),d4
	move.b	arg(a0),d1
	move.b	d1,d0
	andi.w	#7,d1
	cmpi.w	#7,d1
	bne.s	loc_7C3A
	moveq	#6,d1

loc_7C3A:
	swap	d1
	move.w	#0,d1
	lsr.b	#4,d0
	add.w	d0,d0
	move.b	byte_7BF8(pc,d0.w),d5
	ext.w	d5
	move.b	byte_7BF8+1(pc,d0.w),d6
	ext.w	d6
	movea.l a0,a1
	move.w	xpos(a0),d2
	move.w	ypos(a0),d3
	lsr.b	#1,d4
	bcs.s	loc_7CBC
	bclr	#7,(a2)
	bra.s	loc_7C74
; ---------------------------------------------------------------------------

loc_7C64:
	swap	d1
	lsr.b	#1,d4
	bcs.s	loc_7CBC
	bclr	#7,(a2)
	bsr.w	ObjectLoad
	bne.s	loc_7CC8

loc_7C74:
	move.b	#$25,id(a1)
	addq.b	#2,act(a1)
	move.w	d2,xpos(a1)
	move.w	xpos(a0),$32(a1)
	move.w	d3,ypos(a1)
	move.l	#MapRing,map(a1)
	move.w	#$27B2,tile(a1)
	move.b	#4,render(a1)
	move.w	#$100,prio(a1)
	move.b	#$47,col(a1)
	move.b	#8,xpix(a1)
	move.b	respawn(a0),respawn(a1)
	move.b	d1,$34(a1)

loc_7CBC:
	addq.w	#1,d1
	add.w	d5,d2
	add.w	d6,d3
	swap	d1
	dbf d1,loc_7C64

loc_7CC8:
	btst	#0,(a2)
	bne.w	ObjectDelete

loc_7CD0:
	move.b	(RingFrame).w,frame(a0)
	move.w	$32(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.s	loc_7D2C
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_7CF8:
	addq.b	#2,act(a0)
	move.b	#0,col(a0)
	move.w	#$80,prio(a0)
	bsr.w	CollectRing
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	move.b	$34(a0),d1
	bset	d1,2(a2,d0.w)

loc_7D1E:
	lea (AniRing).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_7D2C:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

CollectRing:
	addq.w	#1,(Rings).w
	ori.b	#1,(ExtraLifeFlags).w
	moveq	#sfx_RingRight,d0
	cmpi.w	#50,(Rings).w
	bcs.s	loc_7D6A
	bset	#0,(byte_FFFE1B).w
	beq.s	loc_7D5E
	cmpi.w	#100,(Rings).w
	bcs.s	loc_7D6A
	bset	#1,(byte_FFFE1B).w
	bne.s	loc_7D6A

loc_7D5E:
	addq.b	#1,(Lives).w
	addq.b	#1,(byte_FFFE1C).w
	sfx	sfx_Register
	rts

loc_7D6A:
	move.b	d0,mQueue+2.w
	rts
; ---------------------------------------------------------------------------

ObjRingLoss:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7D7E(pc,d0.w),d1
	jmp off_7D7E(pc,d1.w)
; ---------------------------------------------------------------------------

off_7D7E:   dc.w loc_7D88-off_7D7E, loc_7E48-off_7D7E
	dc.w loc_7E9A-off_7D7E, loc_7EAE-off_7D7E
	dc.w loc_7EBC-off_7D7E
; ---------------------------------------------------------------------------

loc_7D88:
	movea.l a0,a1
	moveq	#0,d5
	move.w	(Rings).w,d5
	moveq	#32,d0
	cmp.w	d0,d5
	bcs.s	loc_7D98
	move.w	d0,d5

loc_7D98:
	subq.w	#1,d5
	lea	SpillingRingData,a3 ; load the address of the array in a3
	bra.s	loc_7DA8
; ---------------------------------------------------------------------------

loc_7DA0:
	bsr.w	ObjectLoad
	bne.w	loc_7E2C

loc_7DA8:
	move.b	#$37,id(a1)
	addq.b	#2,act(a1)
	move.b	#8,yrad(a1)
	move.b	#8,xrad(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.l	#MapRing,map(a1)

loc_7DD2:
	move.w	#$27B2,tile(a1)
	move.b	#4,render(a1)
	move.w	#$100,prio(a1)
	move.b	#$47,col(a1)
	move.b	#8,xpix(a1)
	move.l	(a3)+,xvel(a1) ; move the data contained in the array to the x/y velocity and increment the address in a3
	dbf	d5,loc_7DA0

loc_7E2C:
	clr.w	(Rings).w
	move.b	#$80,(ExtraLifeFlags).w
	clr.b	(byte_FFFE1B).w
	moveq	#-1,d0					; Move #-1 to d0
	move.b	d0,$1F(a0)				; Move d0 to new timer
	move.b	d0,(RingLossTimer).w	; Move d0 to old timer (for animated purposes)
	sfx	sfx_RingLoss

loc_7E48:
	move.b	(RingLossFrame).w,frame(a0)
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	bmi.s	loc_7E82
	move.b	(byte_FFFE0F).w,d0
	add.b	d7,d0
	andi.b	#3,d0
	bne.s	loc_7E82
	jsr ObjectHitFloor
	tst.w	d1
	bpl.s	loc_7E82
	add.w	d1,ypos(a0)
	move.w	yvel(a0),d0
	asr.w	#2,d0
	sub.w	d0,yvel(a0)
	neg.w	yvel(a0)

loc_7E82:
	subq.b	#1,$1F(a0)		; Subtract 1
	beq.w	ObjectDelete		; If 0, delete
	move.w	(unk_FFF72E).w,d0
	addi.w	#224,d0
	cmp.w	ypos(a0),d0
	bcs.s	loc_7EBC
	btst	#0,$1F(a0)		; Test the first bit of the timer, so rings flash every other frame.
	beq.w	ObjectDisplay		; If the bit is 0, the ring will appear.
	cmpi.b	#80,$1F(a0)		; Rings will flash during last 80 steps of their life.
	bhi.w	ObjectDisplay		; If the timer is higher than 80, obviously the rings will STAY visible.
	rts
; ---------------------------------------------------------------------------

loc_7E9A:
	addq.b	#2,act(a0)
	move.b	#0,col(a0)
	move.w	#$80,prio(a0)
	bsr.w	CollectRing

loc_7EAE:
	lea (AniRing).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_7EBC:
	bra.w	ObjectDelete
	
; ---------------------------------------------------------------------------
; Ring Spawn Array
; ---------------------------------------------------------------------------



SpillingRingData:
	dc.w    $FF3C,$FC14,$00C4,$FC14,$FDC8,$FCB0,$0238,$FCB0
	dc.w	$FCB0,$FDC8,$0350,$FDC8,$FC14,$FF3C,$03EC,$FF3C
	dc.w	$FC14,$00C4,$03EC,$00C4,$FCB0,$0238,$0350,$0238
	dc.w	$FDC8,$0350,$0238,$0350,$FF3C,$03EC,$00C4,$03EC
	dc.w	$FF9E,$FE0A,$0062,$FE0A,$FEE4,$FE58,$011C,$FE58
	dc.w	$FE58,$FEE4,$01A8,$FEE4,$FE0A,$FF9E,$01F6,$FF9E
	dc.w	$FE0A,$0062,$01F6,$0062,$FE58,$011C,$01A8,$011C
	dc.w	$FEE4,$01A8,$011C,$01A8,$FF9E,$01F6,$0062,$01F6
	even
; ---------------------------------------------------------------------------

Obj4B:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_7ECE(pc,d0.w),d1
	jmp off_7ECE(pc,d1.w)
; ---------------------------------------------------------------------------

off_7ECE:   dc.w loc_7ED6-off_7ECE, loc_7F12-off_7ECE, loc_7F3C-off_7ECE, loc_7F4C-off_7ECE
; ---------------------------------------------------------------------------

loc_7ED6:
	lea	(byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	lea	tile(a2,d0.w),a2
	bclr	#7,(a2)
	addq.b	#2,act(a0)
	move.l	#Map4B,map(a0)
	move.w	#$24EC,tile(a0)
	move.b	#4,render(a0)
	move.w	#$100,prio(a0)
	move.b	#$52,col(a0)
	move.b	#$C,xpix(a0)

loc_7F12:
	move.b	(RingFrame).w,frame(a0)
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_7F3C:
	addq.b	#2,act(a0)
	move.b	#0,col(a0)
	move.w	#$80,prio(a0)

loc_7F4C:
	move.b	#$4A,(byte_FFD1C0).w
	moveq	#$13,d0
	jsr   	plcAdd
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/shared/Rings/Sprite.ani"
	include "levels/shared/Rings/Sprite.map"
	include "unknown/Map4B.map"
	even
; ---------------------------------------------------------------------------

ObjMonitor:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_8054(pc,d0.w),d1
	jmp off_8054(pc,d1.w)
; ---------------------------------------------------------------------------

off_8054:   dc.w loc_805E-off_8054, loc_80C0-off_8054
	dc.w sub_81D2-off_8054, loc_81A4-off_8054
	dc.w loc_81AE-off_8054
; ---------------------------------------------------------------------------

loc_805E:
	addq.b	#2,act(a0)
	move.b	#$E,yrad(a0)
	move.b	#$E,xrad(a0)
	move.l	#MapMonitor,map(a0)
	move.w	#$680,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$F,xpix(a0)
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	bclr	#7,tile(a2,d0.w)
	btst	#0,tile(a2,d0.w)
	beq.s	loc_80B4
	move.b	#8,act(a0)
	move.b	#$B,frame(a0)
	rts
; ---------------------------------------------------------------------------

loc_80B4:
	move.b	#$46,col(a0)
	move.b	arg(a0),ani(a0)

loc_80C0:
	move.b	subact(a0),d0
	beq.s	loc_811A
	subq.b	#2,d0
	bne.s	loc_80FA
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	bsr.w	PtfmCheckExit
	btst	#3,status(a1)
	bne.w	loc_80EA
	clr.b	subact(a0)
	bra.w	loc_81A4
; ---------------------------------------------------------------------------

loc_80EA:
	move.w	#$10,d3
	move.w	xpos(a0),d2
	bsr.w	PtfmSurfaceHeight
	bra.w	loc_81A4
; ---------------------------------------------------------------------------

loc_80FA:
	bsr.w	ObjectFall
	jsr ObjectHitFloor
	tst.w	d1
	bpl.w	loc_81A4
	add.w	d1,ypos(a0)
	clr.w	yvel(a0)
	clr.b	subact(a0)
	bra.w	loc_81A4
; ---------------------------------------------------------------------------

loc_811A:
	move.w	#$1A,d1
	move.w	#$F,d2
	bsr.w	sub_83B4
	beq.w	loc_818A
	tst.w	yvel(a1)
	bmi.s	loc_8138
	cmpi.b	#2,ani(a1)
	beq.s	loc_818A
	cmpi.b	#9,ani(a1)
	beq.s	loc_818A

loc_8138:
	tst.w	d1
	bpl.s	loc_814E
	sub.w	d3,ypos(a1)
	bsr.w	loc_4FD4
	move.b	#2,subact(a0)
	bra.w	loc_81A4
; ---------------------------------------------------------------------------

loc_814E:
	tst.w	d0
	beq.w	loc_8174
	bmi.s	loc_815E
	tst.w	xvel(a1)
	bmi.s	loc_8174
	bra.s	loc_8164
; ---------------------------------------------------------------------------

loc_815E:
	tst.w	xvel(a1)
	bpl.s	loc_8174

loc_8164:
	sub.w	d0,xpos(a1)
	move.w	#0,inertia(a1)
	move.w	#0,xvel(a1)

loc_8174:
	btst	#1,status(a1)
	bne.s	loc_8198
	bset	#5,status(a1)
	bset	#5,status(a0)
	bra.s	loc_81A4
; ---------------------------------------------------------------------------

loc_818A:
	btst	#5,status(a0)
	beq.s	loc_81A4
	move.w	#1,ani(a1)

loc_8198:
	bclr	#5,status(a0)
	bclr	#5,status(a1)

loc_81A4:
	lea (AniMonitor).l,a1
	bsr.w	ObjectAnimate

loc_81AE:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_81D2:
	addq.b	#2,act(a0)
	move.b	#0,col(a0)
	bsr.w	ObjectLoad
	bne.s	loc_81FA
	move.b	#$2E,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	ani(a0),ani(a1)

loc_81FA:
	bsr.w	ObjectLoad
	bne.s	loc_8216
	move.b	#$27,id(a1)
	addq.b	#2,act(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)

loc_8216:
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	bset	#0,tile(a2,d0.w)
	move.b	#9,ani(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjMonitorItem:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_8242(pc,d0.w),d1
	jsr off_8242(pc,d1.w)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_8242:   dc.w loc_8248-off_8242, loc_8288-off_8242
	dc.w loc_83AA-off_8242
; ---------------------------------------------------------------------------

loc_8248:
	addq.b	#2,act(a0)
	move.w	#$680,tile(a0)
	move.b	#$24,render(a0)
	move.w	#$180,prio(a0)
	move.b	#8,xpix(a0)
	move.w	#-$300,yvel(a0)
	moveq	#0,d0
	move.b	ani(a0),d0
	addq.b	#2,d0
	move.b	d0,frame(a0)
	movea.l #MapMonitor,a1
	add.b	d0,d0
	adda.w	(a1,d0.w),a1
	addq.w	#1,a1
	move.l	a1,map(a0)

loc_8288:
	tst.w	yvel(a0)
	bpl.w	loc_829C
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_829C:
	addq.b	#2,act(a0)
	move.w	#$1D,anidelay(a0)
	move.b	ani(a0),d0
	cmpi.b	#1,d0
	bne.s	loc_82B2
	rts
; ---------------------------------------------------------------------------

loc_82B2:
	cmpi.b	#2,d0
	bne.s	loc_82CA

loc_82B8:
	addq.b	#1,(Lives).w
	addq.b	#1,(byte_FFFE1C).w
	sfx	sfx_Register
	rts
; ---------------------------------------------------------------------------

loc_82CA:
	cmpi.b	#3,d0
	bne.s	loc_82F8
	st.b	(byte_FFFE2E).w
	move.w	#$4B0,(ObjectsList+speedshoes).w
	lea	(PlayerTopSpeed).w,a2	; Load PlayerTopSpeed into a2
	bsr.w	ApplySpeedSettings  ; Fetch Speed settings
	command mus_ShoesOn
	rts
; ---------------------------------------------------------------------------

loc_82F8:
	cmpi.b	#4,d0
	bne.s	loc_8314
	st.b	(byte_FFFE2C).w
	move.b	#$38,(byte_FFD180).w
	sfx	sfx_Shield
	rts
; ---------------------------------------------------------------------------

loc_8314:
	cmpi.b	#5,d0
	bne.s	loc_8360
	st.b	(byte_FFFE2D).w
	move.w	#$4B0,(ObjectsList+invincible).w
	move.b	#$38,(byte_FFD200).w
	move.b	#1,(byte_FFD200+ani).w
	move.b	#$38,(byte_FFD240).w
	move.b	#2,(byte_FFD240+ani).w
	move.b	#$38,(byte_FFD280).w
	move.b	#3,(byte_FFD280+ani).w
	move.b	#$38,(byte_FFD2C0).w
	move.b	#4,(byte_FFD2C0+ani).w
	music	mus_Invincibility, 1
	rts
; ---------------------------------------------------------------------------

loc_8360:
	cmpi.b	#6,d0
	bne.s	loc_83A0
	addi.w	#10,(Rings).w
	ori.b	#1,(ExtraLifeFlags).w
	cmpi.w	#50,(Rings).w
	bcs.s	loc_8396
	bset	#0,(byte_FFFE1B).w
	beq.w	loc_82B8
	cmpi.w	#100,(Rings).w
	bcs.s	loc_8396
	bset	#1,(byte_FFFE1B).w
	beq.w	loc_82B8

loc_8396:
	sfx	sfx_RingRight
	rts
; ---------------------------------------------------------------------------

loc_83A0:
	cmpi.b	#7,d0
	bne.w	locret_83A8
	move.b	#1,(byte_FFFE2D).w
	move.w	#$4B0,(ObjectsList+invincible).w
	move.b	#$38,(byte_FFD200).w
	move.b	#1,(byte_FFD200+ani).w
	move.b	#$38,(byte_FFD240).w
	move.b	#2,(byte_FFD240+ani).w
	move.b	#$38,(byte_FFD280).w
	move.b	#3,(byte_FFD280+ani).w
	move.b	#$38,(byte_FFD2C0).w
	move.b	#4,(byte_FFD2C0+ani).w
	music	mus_Invincibility, 1
	move.b	#1,(byte_FFFE2C).w
	move.b	#$38,(byte_FFD180).w
	sfx	sfx_Shield
	move.b	#1,(byte_FFFE2E).w
	move.w	#$4B0,(ObjectsList+speedshoes).w
	lea	(PlayerTopSpeed).w,a2	; Load PlayerTopSpeed into a2
	bsr.w	ApplySpeedSettings  ; Fetch Speed settings
locret_83A8:
	rts
; ---------------------------------------------------------------------------

loc_83AA:
	subq.w	#1,anidelay(a0)
	bmi.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------

sub_83B4:
	tst.w	(DebugRoutine).w
	bne.w	loc_8400
	lea (ObjectsList).w,a1
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.s	loc_8400
	move.w	d1,d3
	add.w	d3,d3
	cmp.w	d3,d0
	bhi.s	loc_8400
	move.b	yrad(a1),d3
	ext.w	d3
	add.w	d3,d2
	move.w	ypos(a1),d3
	sub.w	ypos(a0),d3
	add.w	d2,d3
	bmi.s	loc_8400
	add.w	d2,d2
	cmp.w	d2,d3
	bcc.s	loc_8400
	cmp.w	d0,d1
	bcc.s	loc_83F6
	add.w	d1,d1
	sub.w	d1,d0

loc_83F6:
	cmpi.w	#$10,d3
	bcs.s	loc_8404

loc_83FC:
	moveq	#1,d1
	rts
; ---------------------------------------------------------------------------

loc_8400:
	moveq	#0,d1
	rts
; ---------------------------------------------------------------------------

loc_8404:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addq.w	#4,d1
	move.w	d1,d2
	add.w	d2,d2
	add.w	xpos(a1),d1
	sub.w	xpos(a0),d1
	bmi.s	loc_83FC
	cmp.w	d2,d1
	bcc.s	loc_83FC
	moveq	#-1,d1
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Monitors/Sprite.ani"
	include "levels/shared/Monitors/Sprite.map"
	even
; ---------------------------------------------------------------------------

RunObjects:
	lea (ObjectsList).w,a0
	moveq	#$7F,d7
	moveq	#0,d0
	cmpi.b 	#6,(ObjectsList+act).w
	bcc.s  	loc_8560
; ---------------------------------------------------------------------------

sub_8546:
	move.b	(a0),d0
	beq.s	loc_8556
	add.w	d0,d0
	add.w	d0,d0
	movea.l loc_857A+2(pc,d0.w),a1
	jsr (a1)
	moveq	#0,d0

loc_8556:
	lea size(a0),a0
	dbf d7,sub_8546
	rts
; ---------------------------------------------------------------------------

loc_8560:
	moveq	#$1F,d7
	bsr.s	sub_8546
	moveq	#$5F,d7

loc_8566:
	moveq	#0,d0
	move.b	(a0),d0
	beq.s	loc_8576
	tst.b	render(a0)
	bpl.s	loc_8576
	bsr.w	ObjectDisplay

loc_8576:
	lea size(a0),a0

loc_857A:
	dbf d7,loc_8566
	rts
; ---------------------------------------------------------------------------

AllObjects: dc.l ObjSonic, Obj_SSResults, Obj_SSResCE, ObjectFall, ObjectFall, ObjectFall, ObjectFall
	dc.l ObjectFall, ObjectFall, ObjectFall, ObjectFall
	dc.l ObjectFall, ObjSignpost, ObjTitleSonic, OibjTitleText
	dc.l ObjCredits, ObjBridge, ObjSceneryLamp, ObjLavaMaker
	dc.l ObjLavaball, ObjSwingPtfm, ObjectFall, ObjSpikeLogs
	dc.l ObjPlatform, ObjRollingBall, ObjCollapsePtfm, Obj1B
	dc.l ObjScenery, ObjUnkSwitch, ObjBallhog, ObjCrabmeat
	dc.l ObjCannonball, ObjHUD, ObjBuzzbomber, ObjBuzzMissile
	dc.l ObjCannonballExplode, ObjRings, ObjMonitor, ObjExplode
	dc.l ObjAnimals, ObjPoints, Obj2A, ObjChopper, ObjJaws
	dc.l ObjBurrobot, ObjMonitorItem, ObjMZPlatforms, ObjGlassBlock
	dc.l ObjChainPtfm, ObjSwitch, ObjPushBlock, ObjTitleCard
	dc.l ObjFloorLavaball, ObjSpikes, ObjRingLoss, ObjShield
	dc.l ObjGameOver, ObjLevelResults, ObjPurpleRock, ObjSmashWall
	dc.l ObjGHZBoss, ObjCapsule, ObjBombExplode, ObjMotobug
	dc.l ObjSpring, ObjNewtron, ObjRoller, ObjWall, Obj45
	dc.l ObjMZBlocks, ObjBumper, ObjGHZBossBall, ObjWaterfallSnd
	dc.l ObjEntryRingBeta, Obj4B, ObjLavafallMalker, ObjLavafall
	dc.l ObjLavaChase, Obj4F, ObjYadrin, ObjSmashBlock, ObjMovingPtfm
	dc.l ObjCollapseFloor, ObjLavaHurt, ObjBasaran, ObjMovingBlocks
	dc.l ObjSpikedBalls, ObjGiantSpikedBalls, ObjSLZMovingPtfm
	dc.l ObjCirclePtfm, ObjStaircasePtfm, ObjSLZGirder, ObjFan
	dc.l ObjSeeSaw
; ---------------------------------------------------------------------------

ObjectFall:
	move.w	x_vel(a0),d0	; load horizontal speed
	ext.l	d0
	asl.l	#8,d0		; convert to 16.16 fixed point
	add.l	d0,x_pos(a0)	; add to x-position
	move.w	y_vel(a0),d0	; load vertical speed
	addi.w	#$38,y_vel(a0)	; increase vertical speed (apply gravity)
	ext.l	d0
	asl.l	#8,d0		; convert to 16.16 fixed point
	add.l	d0,y_pos(a0)	; add to y-position
	rts
; ---------------------------------------------------------------------------

ObjectMove:
	move.w	x_vel(a0),d0	; load horizontal speed
	ext.l	d0
	asl.l	#8,d0		; convert to 16.16 fixed point
	add.l	d0,x_pos(a0)	; add to x-position
	move.w	y_vel(a0),d0	; load vertical speed
	ext.l	d0
	asl.l	#8,d0		; convert to 16.16 fixed point
	add.l	d0,y_pos(a0)	; add to y-position
	rts
; ---------------------------------------------------------------------------

ObjectDisplay:
	lea	(DisplayLists).w,a1
	adda.w	priority(a0),a1
	cmpi.w	#$7E,(a1)
	bcc.s	return_16510
	addq.w	#2,(a1)
	adda.w	(a1),a1
	move.w	a0,(a1)

return_16510:
	rts
; ---------------------------------------------------------------------------

ObjectDisplayA1:
	lea	(DisplayLists).w,a2
	adda.w	priority(a1),a2
	cmpi.w	#$7E,(a2)
	bcc.s	return_1652E
	addq.w	#2,(a2)
	adda.w	(a2),a2
	move.w	a1,(a2)

return_1652E:
	rts
; ---------------------------------------------------------------------------

ObjectDelete:
	movea.l a0,a1

ObjectDeleteA1:
	moveq	#0,d1
	moveq	#$F,d0

.clear:
	move.l	d1,(a1)+
	dbf d0,.clear
	rts
; ---------------------------------------------------------------------------

off_8796:   dc.l 0, (CameraX)&$FFFFFF, (unk_FFF708)&$FFFFFF, (unk_FFF718)&$FFFFFF
; ---------------------------------------------------------------------------

ProcessMaps:
	lea (SprTableBuff).w,a2
	moveq	#0,d5
	lea (DisplayLists).w,a4
	moveq	#7,d7

loc_87B2:
	tst.w	(a4)
	beq.w	loc_8876
	moveq	#2,d6

loc_87BA:
	movea.w (a4,d6.w),a0
	tst.b	id(a0)
	beq.w	loc_886E
	tst.l	4(a0)
	beq.w	loc_886E
	bclr	#7,render(a0)
	move.b	render(a0),d0
	move.b	d0,d4
	andi.w	#$C,d0
	beq.s	loc_8826
	movea.l off_8796(pc,d0.w),a1
	moveq	#0,d0
	move.b	xpix(a0),d0
	move.w	xpos(a0),d3
	sub.w	(a1),d3
	move.w	d3,d1
	add.w	d0,d1
	bmi.w	loc_886E
	move.w	d3,d1
	sub.w	d0,d1
	cmpi.w	#320,d1
	bge.s	loc_886E
	addi.w	#$80,d3
	btst	#4,d4
	beq.s	loc_8830
	moveq	#0,d0
	move.b	yrad(a0),d0
	move.w	ypos(a0),d2
	sub.w	4(a1),d2
	move.w	d2,d1
	add.w	d0,d1
	bmi.s	loc_886E
	move.w	d2,d1
	sub.w	d0,d1
	cmpi.w	#224,d1
	bge.s	loc_886E
	addi.w	#$80,d2
	bra.s	loc_8848
; ---------------------------------------------------------------------------

loc_8826:
	move.w	xpix(a0),d2
	move.w	xpos(a0),d3
	bra.s	loc_8848
; ---------------------------------------------------------------------------

loc_8830:
	move.w	ypos(a0),d2
	sub.w	4(a1),d2
	addi.w	#$80,d2
	cmpi.w	#96,d2
	bcs.s	loc_886E
	cmpi.w	#384,d2
	bcc.s	loc_886E

loc_8848:
	movea.l map(a0),a1
	moveq	#0,d1
	btst	#5,d4
	bne.s	loc_8864
	move.b	frame(a0),d1
	add.w	d1,d1
	adda.w	(a1,d1.w),a1
	moveq	#$00,d1 		; MJ: clear d1 (because of our byte to word change)
	move.b	(a1)+,d1
	subq.b	#1,d1
	bmi.s	loc_8868

loc_8864:
	bsr.w	sub_8898

loc_8868:
	bset	#7,render(a0)

loc_886E:
	addq.w	#2,d6
	subq.w	#2,(a4)
	bne.w	loc_87BA

loc_8876:
	lea $80(a4),a4
	dbf d7,loc_87B2
	move.b	d5,(byte_FFF62C).w
	cmpi.b	#80,d5
	beq.s	loc_8890
	move.l	#0,(a2)
	rts
; ---------------------------------------------------------------------------

loc_8890:
	move.b	#0,-5(a2)
	rts
; ---------------------------------------------------------------------------

sub_8898:
	movea.w tile(a0),a3
	btst	#0,d4
	bne.s	loc_88DE
	btst	#1,d4
	bne.w	loc_892C
; ---------------------------------------------------------------------------

sub_88AA:
	cmpi.b	#80,d5
	beq.s	locret_88DC
	move.b	(a1)+,d0
	ext.w	d0
	add.w	d2,d0
	move.w	d0,(a2)+
	move.b	(a1)+,(a2)+
	addq.b	#1,d5
	move.b	d5,(a2)+
	move.b	(a1)+,d0
	lsl.w	#8,d0
	move.b	(a1)+,d0
	add.w	a3,d0
	move.w	d0,(a2)+
	move.b	(a1)+,d0
	ext.w	d0
	add.w	d3,d0
	andi.w	#$1FF,d0
	bne.s	loc_88D6
	addq.w	#1,d0

loc_88D6:
	move.w	d0,(a2)+
	dbf d1,sub_88AA

locret_88DC:
	rts
; ---------------------------------------------------------------------------

loc_88DE:
	btst	#1,d4
	bne.w	loc_8972

loc_88E6:
	cmpi.b	#80,d5
	beq.s	locret_892A
	move.b	(a1)+,d0
	ext.w	d0
	add.w	d2,d0
	move.w	d0,(a2)+
	move.b	(a1)+,d4
	move.b	d4,(a2)+
	addq.b	#1,d5
	move.b	d5,(a2)+
	move.b	(a1)+,d0
	lsl.w	#8,d0
	move.b	(a1)+,d0
	add.w	a3,d0
	eori.w	#$800,d0
	move.w	d0,(a2)+
	move.b	(a1)+,d0
	ext.w	d0
	neg.w	d0
	add.b	d4,d4
	andi.w	#$18,d4
	addq.w	#8,d4
	sub.w	d4,d0
	add.w	d3,d0
	andi.w	#$1FF,d0
	bne.s	loc_8924
	addq.w	#1,d0

loc_8924:
	move.w	d0,(a2)+
	dbf d1,loc_88E6

locret_892A:
	rts
; ---------------------------------------------------------------------------

loc_892C:
	cmpi.b	#80,d5
	beq.s	locret_8970
	move.b	(a1)+,d0
	move.b	(a1),d4
	ext.w	d0
	neg.w	d0
	lsl.b	#3,d4
	andi.w	#$18,d4
	addq.w	#8,d4
	sub.w	d4,d0
	add.w	d2,d0
	move.w	d0,(a2)+
	move.b	(a1)+,(a2)+
	addq.b	#1,d5
	move.b	d5,(a2)+
	move.b	(a1)+,d0
	lsl.w	#8,d0
	move.b	(a1)+,d0
	add.w	a3,d0
	eori.w	#$1000,d0
	move.w	d0,(a2)+
	move.b	(a1)+,d0
	ext.w	d0
	add.w	d3,d0
	andi.w	#$1FF,d0
	bne.s	loc_896A
	addq.w	#1,d0

loc_896A:
	move.w	d0,(a2)+
	dbf d1,loc_892C

locret_8970:
	rts
; ---------------------------------------------------------------------------

loc_8972:
	cmpi.b	#80,d5
	beq.s	locret_89C4
	move.b	(a1)+,d0
	move.b	(a1),d4
	ext.w	d0
	neg.w	d0
	lsl.b	#3,d4
	andi.w	#$18,d4
	addq.w	#8,d4
	sub.w	d4,d0
	add.w	d2,d0
	move.w	d0,(a2)+
	move.b	(a1)+,d4
	move.b	d4,(a2)+
	addq.b	#1,d5
	move.b	d5,(a2)+
	move.b	(a1)+,d0
	lsl.w	#8,d0
	move.b	(a1)+,d0
	add.w	a3,d0
	eori.w	#$1800,d0
	move.w	d0,(a2)+
	move.b	(a1)+,d0
	ext.w	d0
	neg.w	d0
	add.b	d4,d4
	andi.w	#$18,d4
	addq.w	#8,d4
	sub.w	d4,d0
	add.w	d3,d0
	andi.w	#$1FF,d0
	bne.s	loc_89BE
	addq.w	#1,d0

loc_89BE:
	move.w	d0,(a2)+
	dbf d1,loc_8972

locret_89C4:
	rts
; ---------------------------------------------------------------------------

ObjectChkOffscreen:
	move.w	xpos(a0),d0
	sub.w	(CameraX).w,d0
	bmi.s	.offscreen
	cmpi.w	#320,d0
	bge.s	.offscreen
	move.w	ypos(a0),d1
	sub.w	(CameraY).w,d1
	bmi.s	.offscreen
	cmpi.w	#224,d1
	bge.s	.offscreen
	moveq	#0,d0
	rts
; ---------------------------------------------------------------------------

.offscreen:
	moveq	#1,d0
	rts
; ---------------------------------------------------------------------------

LoadObjects:
	moveq	#0,d0
	move.b	(unk_FFF76C).w,d0
	move.w	off_89FC(pc,d0.w),d0
	jmp off_89FC(pc,d0.w)
; ---------------------------------------------------------------------------

off_89FC:   dc.w loc_8A00-off_89FC, loc_8A44-off_89FC
; ---------------------------------------------------------------------------

loc_8A00:
	addq.b	#2,(unk_FFF76C).w
	move.w	(curzone).w,d0
	lsl.b	#6,d0
	lsr.w	#4,d0
	lea (ObjectListArray).l,a0
	movea.l a0,a1
	adda.w	(a0,d0.w),a0
	move.l	a0,(unk_FFF770).w
	move.l	a0,(unk_FFF774).w
	adda.w	tile(a1,d0.w),a1
	move.l	a1,(unk_FFF778).w
	move.l	a1,(unk_FFF77C).w
	lea (byte_FFFC00).w,a2
	move.w	#$101,(a2)+
	move.w	#$5E,d0

loc_8A38:
	clr.l	(a2)+
	dbf d0,loc_8A38
	move.w	#$FFFF,(unk_FFF76E).w

loc_8A44:
	move.w	(CameraX).w,d1
	subi.w	#$80,d1
	andi.w	#$FF80,d1
	move.w	d1,(CameraXCoarse).w
	lea (byte_FFFC00).w,a2
	moveq	#0,d2
	move.w	(CameraX).w,d6
	andi.w	#$FF80,d6
	cmp.w	(unk_FFF76E).w,d6
	beq.w	locret_8B20
	bge.s	loc_8ABA
	move.w	d6,(unk_FFF76E).w
	movea.l (unk_FFF774).w,a0
	subi.w	#$80,d6
	bcs.s	loc_8A96

loc_8A6A:
	cmp.w	-6(a0),d6
	bge.s	loc_8A96
	subq.w	#6,a0
	tst.b	4(a0)
	bpl.s	loc_8A80
	subq.b	#1,render(a2)
	move.b	render(a2),d2

loc_8A80:
	bsr.w	sub_8B22
	bne.s	loc_8A8A
	subq.w	#6,a0
	bra.s	loc_8A6A
; ---------------------------------------------------------------------------

loc_8A8A:
	tst.b	4(a0)
	bpl.s	loc_8A94
	addq.b	#1,render(a2)

loc_8A94:
	addq.w	#6,a0

loc_8A96:
	move.l	a0,(unk_FFF774).w
	movea.l (unk_FFF770).w,a0
	addi.w	#$300,d6

loc_8AA2:
	cmp.w	-6(a0),d6
	bgt.s	loc_8AB4
	tst.b	-2(a0)
	bpl.s	loc_8AB0
	subq.b	#1,(a2)

loc_8AB0:
	subq.w	#6,a0
	bra.s	loc_8AA2
; ---------------------------------------------------------------------------

loc_8AB4:
	move.l	a0,(unk_FFF770).w
	rts
; ---------------------------------------------------------------------------

loc_8ABA:
	move.w	d6,(unk_FFF76E).w
	movea.l (unk_FFF770).w,a0
	addi.w	#$280,d6

loc_8AC6:
	cmp.w	(a0),d6
	bls.s	loc_8ADA
	tst.b	4(a0)
	bpl.s	loc_8AD4
	move.b	(a2),d2
	addq.b	#1,(a2)

loc_8AD4:
	bsr.w	sub_8B22
	beq.s	loc_8AC6

loc_8ADA:
	move.l	a0,(unk_FFF770).w
	movea.l (unk_FFF774).w,a0
	subi.w	#$300,d6
	bcs.s	loc_8AFA

loc_8AE8:
	cmp.w	(a0),d6
	bls.s	loc_8AFA
	tst.b	4(a0)
	bpl.s	loc_8AF6
	addq.b	#1,render(a2)

loc_8AF6:
	addq.w	#6,a0
	bra.s	loc_8AE8
; ---------------------------------------------------------------------------

loc_8AFA:
	move.l	a0,(unk_FFF774).w
	rts
; ---------------------------------------------------------------------------

loc_8B00:
	movea.l (unk_FFF778).w,a0
	move.w	(unk_FFF718).w,d0
	addi.w	#$200,d0
	andi.w	#$FF80,d0
	cmp.w	(a0),d0
	bcs.s	locret_8B20
	bsr.w	sub_8B22
	move.l	a0,(unk_FFF778).w
	bra.w	loc_8B00
; ---------------------------------------------------------------------------

locret_8B20:
	rts
; ---------------------------------------------------------------------------

sub_8B22:
	tst.b	4(a0)
	bpl.s	loc_8B36
	bset	#7,tile(a2,d2.w)
	beq.s	loc_8B36
	addq.w	#6,a0
	moveq	#0,d0
	rts
; ---------------------------------------------------------------------------

loc_8B36:
	bsr.s	ObjectLoad
	bne.s	locret_8B70
	move.w	(a0)+,xpos(a1)
	move.w	(a0)+,d0
	move.w	d0,d1
	andi.w	#$FFF,d0
	move.w	d0,ypos(a1)
	rol.w	#2,d1
	andi.b	#3,d1
	move.b	d1,render(a1)
	move.b	d1,status(a1)
	move.b	(a0)+,d0
	bpl.s	loc_8B66
	andi.b	#$7F,d0
	move.b	d2,respawn(a1)

loc_8B66:
	move.b	d0,id(a1)
	move.b	(a0)+,arg(a1)
	moveq	#0,d0

locret_8B70:
	rts
; ---------------------------------------------------------------------------

ObjectLoad:
	lea (LevelObjectsList).w,a1
	move.w	#$5F,d0

loc_8B7A:
	tst.b	(a1)
	beq.s	locret_8B86
	lea size(a1),a1
	dbf d0,loc_8B7A

locret_8B86:
	rts
; ---------------------------------------------------------------------------

LoadNextObject:
	movea.l a0,a1
	move.w	#$F000,d0
	sub.w	a0,d0
	lsr.w	#6,d0
	subq.w	#1,d0
	bcs.s	locret_8BA2

loc_8B96:
	tst.b	(a1)
	beq.s	locret_8BA2
	lea size(a1),a1
	dbf d0,loc_8B96

locret_8BA2:
	rts
; ---------------------------------------------------------------------------

ObjChopper:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_8BB6(pc,d0.w),d1
	jsr off_8BB6(pc,d1.w)
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_8BB6:   dc.w loc_8BBA-off_8BB6, loc_8BF0-off_8BB6
; ---------------------------------------------------------------------------

loc_8BBA:
	addq.b	#2,act(a0)
	move.l	#MapChopper,4(a0)
	move.w	#$47B,tile(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#9,col(a0)
	move.b	#$10,xpix(a0)
	move.w	#$F900,yvel(a0)
	move.w	ypos(a0),$30(a0)

loc_8BF0:
	lea (AniChopper).l,a1
	bsr.w	ObjectAnimate
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	move.w	$30(a0),d0
	cmp.w	ypos(a0),d0
	bcc.s	loc_8C18
	move.w	d0,ypos(a0)
	move.w	#$F900,yvel(a0)

loc_8C18:
	move.b	#1,ani(a0)
	subi.w	#$C0,d0
	cmp.w	ypos(a0),d0
	bcc.s	locret_8C3A
	move.b	#0,ani(a0)
	tst.w	yvel(a0)
	bmi.s	locret_8C3A
	move.b	#2,ani(a0)

locret_8C3A:
	rts
; ---------------------------------------------------------------------------
	include "levels/GHZ/Chopper/Sprite.ani"
	even
	include "levels/GHZ/Chopper/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjJaws:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_8C70(pc,d0.w),d1
	jsr off_8C70(pc,d1.w)
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_8C70:   dc.w loc_8C74-off_8C70, loc_8CA4-off_8C70
; ---------------------------------------------------------------------------

loc_8C74:
	addq.b	#2,act(a0)
	move.l	#MapJaws,4(a0)
	move.w	#$47B,tile(a0)
	move.b	#4,render(a0)
	move.b	#$A,col(a0)
	move.w	#$200,prio(a0)
	move.b	#$10,xpix(a0)
	move.w	#$FFC0,xvel(a0)

loc_8CA4:
	lea (AniJaws).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectMove
; ---------------------------------------------------------------------------
	include "levels/LZ/Jaws/Sprite.ani"
	include "levels/LZ/Jaws/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjBurrobot:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_8CFC(pc,d0.w),d1
	jmp off_8CFC(pc,d1.w)
; ---------------------------------------------------------------------------

off_8CFC:   dc.w loc_8D02-off_8CFC, loc_8D56-off_8CFC, loc_8E46-off_8CFC
; ---------------------------------------------------------------------------

loc_8D02:
	move.b	#$13,yrad(a0)
	move.b	#8,xrad(a0)
	move.l	#MapBurrobot,4(a0)
	move.w	#$239C,tile(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#5,col(a0)
	move.b	#$C,xpix(a0)
	bset	#0,status(a0)
	bsr.w	ObjectFall
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_8D54
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,act(a0)

locret_8D54:
	rts
; ---------------------------------------------------------------------------

loc_8D56:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_8D72(pc,d0.w),d1
	jsr off_8D72(pc,d1.w)
	lea (AniBurrobot).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_8D72:   dc.w loc_8D78-off_8D72, loc_8DA2-off_8D72, loc_8E10-off_8D72
; ---------------------------------------------------------------------------

loc_8D78:
	subq.w	#1,$30(a0)
	bpl.s	locret_8DA0
	addq.b	#2,subact(a0)
	move.w	#$FF,$30(a0)
	move.w	#$80,xvel(a0)
	move.b	#1,ani(a0)
	bchg	#0,status(a0)
	beq.s	locret_8DA0
	neg.w	xvel(a0)

locret_8DA0:
	rts
; ---------------------------------------------------------------------------

loc_8DA2:
	subq.w	#1,$30(a0)
	bmi.s	loc_8DDE
	bsr.w	ObjectMove
	bchg	#0,$32(a0)
	bne.s	loc_8DD4
	move.w	xpos(a0),d3
	addi.w	#$C,d3
	btst	#0,status(a0)
	bne.s	loc_8DC8
	subi.w	#$18,d3

loc_8DC8:
	bsr.w	ObjectHitFloor2
	cmpi.w	#$C,d1
	bge.s	loc_8DDE
	rts
; ---------------------------------------------------------------------------

loc_8DD4:
	bsr.w	ObjectHitFloor
	add.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_8DDE:
	btst	#2,(byte_FFFE0F).w
	beq.s	loc_8DFE
	subq.b	#2,subact(a0)
	move.w	#$3B,$30(a0)
	move.w	#0,xvel(a0)
	move.b	#0,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_8DFE:
	addq.b	#2,subact(a0)
	move.w	#$FC00,yvel(a0)
	move.b	#2,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_8E10:
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	bmi.s	locret_8E44
	move.b	#3,ani(a0)
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_8E44
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	move.b	#1,ani(a0)
	move.w	#$FF,$30(a0)
	subq.b	#2,subact(a0)

locret_8E44:
	rts
; ---------------------------------------------------------------------------

loc_8E46:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/LZ/Burrobot/Sprite.ani"
	even
	include "levels/LZ/Burrobot/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjMZPlatforms:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_8ECE(pc,d0.w),d1
	jmp off_8ECE(pc,d1.w)
; ---------------------------------------------------------------------------

off_8ECE:   dc.w loc_8EDE-off_8ECE, loc_8F3C-off_8ECE

off_8ED2:   dc.w ObjMZPlatforms_Slope1-off_8ED2
	dc.b 0, $40
	dc.w ObjMZPlatforms_Slope3-off_8ED2
	dc.b 1, $40
	dc.w ObjMZPlatforms_Slope2-off_8ED2
	dc.b 2, $20
; ---------------------------------------------------------------------------

loc_8EDE:
	addq.b	#2,act(a0)
	move.l	#MapMZPlatforms,4(a0)
	move.w	#$C000,tile(a0)
	move.b	#4,render(a0)
	move.w	#$280,prio(a0)
	move.w	ypos(a0),$2C(a0)
	move.w	xpos(a0),$2A(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	lsr.w	#2,d0

loc_8F10:
	andi.w	#$1C,d0
	lea off_8ED2(pc,d0.w),a1
	move.w	(a1)+,d0
	lea off_8ED2(pc,d0.w),a2
	move.l	a2,$30(a0)
	move.b	(a1)+,frame(a0)
	move.b	(a1),xpix(a0)
	andi.b	#$F,arg(a0)
	move.b	#$40,yrad(a0)
	bset	#4,render(a0)

loc_8F3C:
	bsr.w	sub_8FA6
	tst.b	subact(a0)
	beq.s	loc_8F7C
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	bsr.w	PtfmCheckExit
	btst	#3,status(a1)
	bne.w	loc_8F64
	clr.b	subact(a0)
	bra.s	loc_8F9E
; ---------------------------------------------------------------------------

loc_8F64:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	movea.l $30(a0),a2
	move.w	xpos(a0),d2
	bsr.w	sub_61E0
	bra.s	loc_8F9E
; ---------------------------------------------------------------------------

loc_8F7C:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	move.w	#$20,d2
	cmpi.b	#2,frame(a0)
	bne.s	loc_8F96
	move.w	#$30,d2

loc_8F96:
	movea.l $30(a0),a2
	bsr.w	loc_A30C

loc_8F9E:
	bra.w	loc_90C2
; ---------------------------------------------------------------------------

sub_8FA6:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#7,d0
	add.w	d0,d0
	move.w	off_8FBA(pc,d0.w),d1
	jmp off_8FBA(pc,d1.w)
; ---------------------------------------------------------------------------

off_8FBA:   dc.w locret_8FC6-off_8FBA, loc_8FC8-off_8FBA, loc_8FD2-off_8FBA, loc_8FDC-off_8FBA, loc_8FE6-off_8FBA
	dc.w loc_9006-off_8FBA
; ---------------------------------------------------------------------------

locret_8FC6:
	rts
; ---------------------------------------------------------------------------

loc_8FC8:
	move.b	(oscValues+2).w,d0
	move.w	#$20,d1
	bra.s	loc_8FEE
; ---------------------------------------------------------------------------

loc_8FD2:
	move.b	(oscValues+6).w,d0
	move.w	#$30,d1
	bra.s	loc_8FEE
; ---------------------------------------------------------------------------

loc_8FDC:
	move.b	(oscValues+$A).w,d0
	move.w	#$40,d1
	bra.s	loc_8FEE
; ---------------------------------------------------------------------------

loc_8FE6:
	move.b	(oscValues+$E).w,d0
	move.w	#$60,d1

loc_8FEE:
	btst	#3,arg(a0)
	beq.s	loc_8FFA
	neg.w	d0
	add.w	d1,d0

loc_8FFA:
	move.w	$2C(a0),d1
	sub.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_9006:
	move.b	$34(a0),d0
	tst.b	subact(a0)
	bne.s	loc_9018
	subq.b	#2,d0
	bcc.s	loc_9024
	moveq	#0,d0
	bra.s	loc_9024
; ---------------------------------------------------------------------------

loc_9018:
	addq.b	#4,d0
	cmpi.b	#$40,d0
	bcs.s	loc_9024
	move.b	#$40,d0

loc_9024:
	move.b	d0,$34(a0)
	jsr (GetSine).l
	lsr.w	#4,d0
	move.w	d0,d1
	add.w	$2C(a0),d0
	move.w	d0,ypos(a0)
	cmpi.b	#$20,$34(a0)
	bne.s	loc_9082
	tst.b	$35(a0)
	bne.s	loc_9082
	move.b	#1,$35(a0)
	bsr.w	LoadNextObject
	bne.s	loc_9082
	move.b	#$35,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	$2C(a0),$2C(a1)
	addq.w	#8,$2C(a1)
	subq.w	#3,$2C(a1)
	subi.w	#$40,xpos(a1)
	move.l	$30(a0),$30(a1)
	move.l	a0,convex(a1)
	movea.l a0,a2
	bsr.s	sub_90A4

loc_9082:
	moveq	#0,d2
	lea sensorfront(a0),a2
	move.b	(a2)+,d2
	subq.b	#1,d2
	bcs.s	locret_90A2

loc_908E:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.w	#-$3000,d0
	movea.w d0,a1
	move.w	d1,$3C(a1)
	dbf d2,loc_908E

locret_90A2:
	rts
; ---------------------------------------------------------------------------

sub_90A4:
	lea sensorfront(a2),a2
	moveq	#0,d0
	move.b	(a2),d0
	addq.b	#1,(a2)
	lea render(a2,d0.w),a2
	move.w	a1,d0
	subi.w	#$D000,d0
	lsr.w	#6,d0
	andi.w	#$7F,d0
	move.b	d0,(a2)
	rts
; ---------------------------------------------------------------------------

loc_90C2:
	tst.b	$35(a0)
	beq.s	loc_90CE
	tst.b	render(a0)
	bpl.s	loc_90EE

loc_90CE:
	move.w	$2A(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_90EE:
	moveq	#0,d2

loc_90F0:
	lea sensorfront(a0),a2
	move.b	(a2),d2
	clr.b	(a2)+
	subq.b	#1,d2
	bcs.s	locret_911E

loc_90FC:
	moveq	#0,d0
	move.b	(a2),d0
	clr.b	(a2)+
	lsl.w	#6,d0
	addi.w	#-$3000,d0
	movea.w d0,a1
	bsr.w	ObjectDeleteA1
	dbf d2,loc_90FC
	move.b	#0,$35(a0)

loc_9118:
	move.b	#0,$34(a0)

locret_911E:
	rts
; ---------------------------------------------------------------------------

ObjMZPlatforms_Slope1:dc.b $20, $20, $20, $20, $20
	dc.b $20, $20, $20, $20, $20
	dc.b $20, $20, $20, $20, $21
	dc.b $22, $23, $24, $25, $26
	dc.b $27, $28, $29, $2A, $2B
	dc.b $2C, $2D, $2E, $2F, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $2F, $2E, $2D
	dc.b $2C, $2B, $2A, $29, $28
	dc.b $27, $26, $25, $24, $23
	dc.b $22, $21, $20, $20, $20
	dc.b $20, $20, $20, $20, $20
	dc.b $20, $20, $20, $20, $20
	dc.b $20

ObjMZPlatforms_Slope2:dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30, $30
	dc.b $30, $30, $30, $30

ObjMZPlatforms_Slope3:dc.b $20, $20, $20, $20, $20
	dc.b $20, $21, $22, $23, $24
	dc.b $25, $26, $27, $28, $29
	dc.b $2A, $2B, $2C, $2D, $2E
	dc.b $2F, $30, $31, $32, $33
	dc.b $34, $35, $36, $37, $38
	dc.b $39, $3A, $3B, $3C, $3D
	dc.b $3E, $3F, $40, $40, $40
	dc.b $40, $40, $40, $40, $40
	dc.b $40, $40, $40, $40, $40
	dc.b $40, $40, $40, $40, $40
	dc.b $3F, $3E, $3D, $3C, $3B
	dc.b $3A, $39, $38, $37, $36
	dc.b $35, $34, $33, $32, $31
	dc.b $30, $30, $30, $30, $30
	dc.b $30
; ---------------------------------------------------------------------------

ObjFloorLavaball:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_91F2(pc,d0.w),d1
	jmp off_91F2(pc,d1.w)
; ---------------------------------------------------------------------------

off_91F2:   dc.w loc_91F8-off_91F2, loc_9240-off_91F2, loc_92BA-off_91F2
; ---------------------------------------------------------------------------

loc_91F8:
	addq.b	#2,act(a0)
	move.l	#MapLavaball,4(a0)
	move.w	#$345,2(a0)
	move.w	xpos(a0),$2A(a0)
	move.b	#4,render(a0)
	move.w	#$80,prio(a0)
	move.b	#$8B,col(a0)
	move.b	#8,xpix(a0)
	sfx	sfx_Lava
	tst.b	arg(a0)
	beq.s	loc_9240
	addq.b	#2,act(a0)
	bra.w	loc_92BA
; ---------------------------------------------------------------------------

loc_9240:
	movea.l $30(a0),a1
	move.w	xpos(a0),d1
	sub.w	$2A(a0),d1
	addi.w	#$C,d1
	move.w	d1,d0
	lsr.w	#1,d0
	move.b	(a1,d0.w),d0
	neg.w	d0
	add.w	$2C(a0),d0
	move.w	d0,d2
	add.w	$3C(a0),d0
	move.w	d0,ypos(a0)
	cmpi.w	#$84,d1
	bcc.s	loc_92B8
	addi.l	#$10000,xpos(a0)
	cmpi.w	#$80,d1
	bcc.s	loc_92B8
	move.l	xpos(a0),d0
	addi.l	#$80000,d0
	andi.l	#$FFFFF,d0
	bne.s	loc_92B8
	bsr.w	LoadNextObject
	bne.s	loc_92B8
	move.b	#$35,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	d2,$2C(a1)
	move.w	$3C(a0),$3C(a1)
	move.b	#1,arg(a1)
	movea.l convex(a0),a2
	bsr.w	sub_90A4

loc_92B8:
	bra.s	loc_92C6
; ---------------------------------------------------------------------------

loc_92BA:
	move.w	$2C(a0),d0
	add.w	$3C(a0),d0
	move.w	d0,ypos(a0)

loc_92C6:
	lea (AniFloorLavaball).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/MZ/FloorLavaball/Sprite.ani"
	include "levels/MZ/Platform/Sprite.map"
	include "levels/MZ/FloorLavaball/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjGlassBlock:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_93DE(pc,d0.w),d1
	jsr off_93DE(pc,d1.w)
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	loc_93D8
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_93D8:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

off_93DE:   dc.w loc_93FA-off_93DE, loc_9498-off_93DE, loc_94B0-off_93DE, loc_94CA-off_93DE, loc_94D8-off_93DE
	dc.w loc_9500-off_93DE

byte_93EA:  dc.b 2, 4, 0
	dc.b 4, $48, 1
	dc.b 6, 4, 2
	even

byte_93F4:  dc.b 8, 0, 3
	dc.b $A, 0, 2
; ---------------------------------------------------------------------------

loc_93FA:
	lea (byte_93EA).l,a2
	moveq	#2,d1
	cmpi.b	#3,arg(a0)
	bcs.s	loc_9412
	lea (byte_93F4).l,a2
	moveq	#1,d1

loc_9412:
	movea.l a0,a1
	bra.s	loc_941C
; ---------------------------------------------------------------------------

loc_9416:
	bsr.w	LoadNextObject
	bne.s	loc_9486

loc_941C:
	move.b	(a2)+,act(a1)
	move.b	#$30,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.b	(a2)+,d0
	ext.w	d0
	add.w	ypos(a0),d0
	move.w	d0,ypos(a1)
	move.l	#MapGlassBlock,4(a1)
	move.w	#$C38E,2(a1)
	move.b	#4,render(a1)
	move.w	ypos(a1),$30(a1)
	move.b	arg(a0),arg(a1)
	move.b	#$20,xpix(a1)
	move.w	#$200,prio(a1)
	move.b	(a2)+,frame(a1)
	move.l	a0,$3C(a1)
	dbf d1,loc_9416
	move.b	#$10,xpix(a1)
	move.w	#$180,prio(a1)
	addq.b	#8,arg(a1)
	andi.b	#$F,arg(a1)

loc_9486:
	move.w	#$90,$32(a0)
	move.b	#$38,yrad(a0)
	bset	#4,render(a0)

loc_9498:
	bsr.w	sub_9514
	move.w	#$2B,d1
	move.w	#$24,d2
	move.w	#$24,d3
	move.w	xpos(a0),d4
	bra.w	sub_A2BC
; ---------------------------------------------------------------------------

loc_94B0:
	movea.l $3C(a0),a1
	move.w	$32(a1),$32(a0)
	bsr.w	sub_9514
	move.w	#$2B,d1
	move.w	#$24,d2
	bra.w	sub_6936
; ---------------------------------------------------------------------------

loc_94CA:
	movea.l $3C(a0),a1
	move.w	$32(a1),$32(a0)
	bra.w	sub_9514
; ---------------------------------------------------------------------------

loc_94D8:
	bsr.w	sub_9514
	move.w	#$2B,d1
	move.w	#$38,d2
	move.w	#$38,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	cmpi.b	#8,act(a0)
	beq.s	locret_94FE
	move.b	#8,act(a0)

locret_94FE:
	rts
; ---------------------------------------------------------------------------

loc_9500:
	movea.l $3C(a0),a1
	move.w	$32(a1),$32(a0)
	move.w	ypos(a1),$30(a0)
	bra.w	*+4
; ---------------------------------------------------------------------------

sub_9514:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#7,d0
	add.w	d0,d0
	move.w	off_9528(pc,d0.w),d1
	jmp off_9528(pc,d1.w)
; ---------------------------------------------------------------------------

off_9528:   dc.w locret_9532-off_9528, loc_9534-off_9528, loc_9540-off_9528
	dc.w loc_9550-off_9528, loc_95D6-off_9528
; ---------------------------------------------------------------------------

locret_9532:
	rts
; ---------------------------------------------------------------------------

loc_9534:
	move.b	(oscValues+$12).w,d0
	move.w	#$40,d1
	bra.w	loc_9616
; ---------------------------------------------------------------------------

loc_9540:
	move.b	(oscValues+$12).w,d0
	move.w	#$40,d1
	neg.w	d0
	add.w	d1,d0
	bra.w	loc_9616
; ---------------------------------------------------------------------------

loc_9550:
	btst	#3,arg(a0)
	beq.s	loc_9564
	move.b	(oscValues+$12).w,d0
	subi.w	#$10,d0
	bra.w	loc_9624
; ---------------------------------------------------------------------------

loc_9564:
	btst	#3,status(a0)
	bne.s	loc_9574
	bclr	#0,$34(a0)
	bra.s	loc_95A8
; ---------------------------------------------------------------------------

loc_9574:
	tst.b	$34(a0)
	bne.s	loc_95A8
	move.b	#1,$34(a0)
	bset	#0,$35(a0)
	beq.s	loc_95A8
	bset	#7,$34(a0)
	move.w	#$10,sensorfront(a0)
	move.b	#$A,convex(a0)
	cmpi.w	#$40,$32(a0)
	bne.s	loc_95A8
	move.w	#$40,sensorfront(a0)

loc_95A8:
	tst.b	$34(a0)
	bpl.s	loc_95D0
	tst.b	convex(a0)
	beq.s	loc_95BA
	subq.b	#1,convex(a0)
	bne.s	loc_95D0

loc_95BA:
	tst.w	$32(a0)
	beq.s	loc_95CA
	subq.w	#1,$32(a0)
	subq.w	#1,sensorfront(a0)
	bne.s	loc_95D0

loc_95CA:
	bclr	#7,$34(a0)

loc_95D0:
	move.w	$32(a0),d0
	bra.s	loc_9624
; ---------------------------------------------------------------------------

loc_95D6:
	btst	#3,arg(a0)
	beq.s	loc_95E8
	move.b	(oscValues+$12).w,d0
	subi.w	#$10,d0
	bra.s	loc_9624
; ---------------------------------------------------------------------------

loc_95E8:
	tst.b	$34(a0)
	bne.s	loc_9606
	lea (unk_FFF7E0).w,a2
	moveq	#0,d0
	move.b	arg(a0),d0
	lsr.w	#4,d0
	tst.b	(a2,d0.w)
	beq.s	loc_9610
	move.b	#1,$34(a0)

loc_9606:
	tst.w	$32(a0)
	beq.s	loc_9610
	subq.w	#2,$32(a0)

loc_9610:
	move.w	$32(a0),d0
	bra.s	loc_9624
; ---------------------------------------------------------------------------

loc_9616:
	btst	#3,arg(a0)
	beq.s	loc_9624
	neg.w	d0
	add.w	d1,d0
	lsr.b	#1,d0

loc_9624:
	move.w	$30(a0),d1
	sub.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/MZ/GlassBlock/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjChainPtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_96C2(pc,d0.w),d1
	jmp off_96C2(pc,d1.w)
; ---------------------------------------------------------------------------

off_96C2:   dc.w loc_96EA-off_96C2, loc_97D0-off_96C2, loc_9834-off_96C2, loc_9846-off_96C2, loc_9818-off_96C2

byte_96CC:  dc.b 0, 0
	dc.b 1, 0

byte_96D0:  dc.b 2, 0, 0
	dc.b 4, $1C, 1
	dc.b 8, $CC, 3
	dc.b 6, $F0, 2

word_96DC:  dc.w $7000, $A000
	dc.w $5000, $7800
	dc.w $3800, $5800
	dc.w $B800
; ---------------------------------------------------------------------------

loc_96EA:
	moveq	#0,d0
	move.b	arg(a0),d0
	bpl.s	loc_9706
	andi.w	#$7F,d0
	add.w	d0,d0
	lea byte_96CC(pc,d0.w),a2
	move.b	(a2)+,$3A(a0)
	move.b	(a2)+,d0
	move.b	d0,arg(a0)

loc_9706:
	andi.b	#$F,d0
	add.w	d0,d0
	move.w	word_96DC(pc,d0.w),d2
	tst.w	d0
	bne.s	loc_9718
	move.w	d2,$32(a0)

loc_9718:
	lea (byte_96D0).l,a2
	movea.l a0,a1
	moveq	#3,d1
	bra.s	loc_972C
; ---------------------------------------------------------------------------

loc_9724:
	bsr.w	LoadNextObject
	bne.w	loc_97B0

loc_972C:
	move.b	(a2)+,act(a1)
	move.b	#$31,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.b	(a2)+,d0
	ext.w	d0
	add.w	ypos(a0),d0
	move.w	d0,ypos(a1)
	move.l	#MapChainPtfm,4(a1)
	move.w	#$300,2(a1)
	move.b	#4,render(a1)
	move.w	ypos(a1),$30(a1)
	move.b	arg(a0),arg(a1)
	move.b	#$10,xpix(a1)
	move.w	d2,$34(a1)
	move.w	#$200,prio(a1)
	move.b	(a2)+,frame(a1)
	cmpi.b	#1,frame(a1)
	bne.s	loc_97A2
	subq.w	#1,d1
	move.b	arg(a0),d0
	andi.w	#$F0,d0
	cmpi.w	#$20,d0
	beq.s	loc_972C
	move.b	#$38,xpix(a1)
	move.b	#$90,col(a1)
	addq.w	#1,d1

loc_97A2:
	move.l	a0,$3C(a1)
	dbf d1,loc_9724
	move.w	#$180,prio(a1)

loc_97B0:
	moveq	#0,d0
	move.b	arg(a0),d0
	lsr.w	#3,d0
	andi.b	#$E,d0
	lea byte_97CA(pc,d0.w),a2
	move.b	(a2)+,xpix(a0)
	move.b	(a2)+,frame(a0)
	bra.s	loc_97D0
; ---------------------------------------------------------------------------

byte_97CA:  dc.b $38, 0
	dc.b $30, 9
	dc.b $10, $A
; ---------------------------------------------------------------------------

loc_97D0:
	bsr.w	sub_986A
	move.w	ypos(a0),(unk_FFF7A4).w
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	move.w	#$C,d2
	move.w	#$D,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	btst	#3,status(a0)
	beq.s	loc_9810
	cmpi.b	#$10,$32(a0)
	bcc.s	loc_9810
	movea.l a0,a2
	lea (ObjectsList).w,a0
	bsr.w	loc_FD78
	movea.l a2,a0

loc_9810:
	bra.w	loc_984A
; ---------------------------------------------------------------------------

loc_9818:
	move.b	#$80,yrad(a0)
	bset	#4,render(a0)
	movea.l $3C(a0),a1
	move.b	$32(a1),d0
	lsr.b	#5,d0
	addq.b	#3,d0
	move.b	d0,frame(a0)

loc_9834:
	movea.l $3C(a0),a1
	moveq	#0,d0
	move.b	$32(a1),d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)

loc_9846:
loc_984A:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_986A:
	move.b	arg(a0),d0
	andi.w	#$F,d0
	add.w	d0,d0
	move.w	off_987C(pc,d0.w),d1
	jmp off_987C(pc,d1.w)
; ---------------------------------------------------------------------------

off_987C:   dc.w loc_988A-off_987C, loc_9926-off_987C, loc_9926-off_987C, loc_99B6-off_987C, loc_9926-off_987C
	dc.w loc_99B6-off_987C, loc_9926-off_987C
; ---------------------------------------------------------------------------

loc_988A:
	lea (unk_FFF7E0).w,a2
	moveq	#0,d0
	move.b	$3A(a0),d0
	tst.b	(a2,d0.w)
	beq.s	loc_98DE
	tst.w	(unk_FFF7A4).w
	bpl.s	loc_98A8
	cmpi.b	#$10,$32(a0)
	beq.s	loc_98D6

loc_98A8:
	tst.w	$32(a0)
	beq.s	loc_98D6
	move.b	(byte_FFFE0F).w,d0
	andi.b	#$F,d0
	bne.s	loc_98C8
	tst.b	render(a0)
	bpl.s	loc_98C8
	sfx	sfx_Chain

loc_98C8:
	subi.w	#$80,$32(a0)
	bcc.s	loc_9916
	move.w	#0,$32(a0)

loc_98D6:
	move.w	#0,yvel(a0)
	bra.s	loc_9916
; ---------------------------------------------------------------------------

loc_98DE:
	move.w	$34(a0),d1
	cmp.w	$32(a0),d1
	beq.s	loc_9916
	move.w	yvel(a0),d0
	addi.w	#$70,yvel(a0)
	add.w	d0,$32(a0)
	cmp.w	$32(a0),d1
	bhi.s	loc_9916
	move.w	d1,$32(a0)
	move.w	#0,yvel(a0)
	tst.b	render(a0)
	bpl.s	loc_9916
	sfx	sfx_Stomp

loc_9916:
	moveq	#0,d0
	move.b	$32(a0),d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_9926:
	tst.w	sensorfront(a0)
	beq.s	loc_996E
	tst.w	convex(a0)
	beq.s	loc_9938
	subq.w	#1,convex(a0)
	bra.s	loc_99B2
; ---------------------------------------------------------------------------

loc_9938:
	move.b	(byte_FFFE0F).w,d0
	andi.b	#$F,d0
	bne.s	loc_9952
	tst.b	render(a0)
	bpl.s	loc_9952
	sfx	sfx_Chain

loc_9952:
	subi.w	#$80,$32(a0)
	bcc.s	loc_99B2
	move.w	#0,$32(a0)
	move.w	#0,yvel(a0)
	move.w	#0,sensorfront(a0)
	bra.s	loc_99B2
; ---------------------------------------------------------------------------

loc_996E:
	move.w	$34(a0),d1
	cmp.w	$32(a0),d1
	beq.s	loc_99B2
	move.w	yvel(a0),d0
	addi.w	#$70,yvel(a0)
	add.w	d0,$32(a0)
	cmp.w	$32(a0),d1
	bhi.s	loc_99B2
	move.w	d1,$32(a0)
	move.w	#0,yvel(a0)
	move.w	#1,sensorfront(a0)
	move.w	#$3C,convex(a0)
	tst.b	render(a0)
	bpl.s	loc_99B2
	sfx	sfx_Stomp

loc_99B2:
	bra.w	loc_9916
; ---------------------------------------------------------------------------

loc_99B6:
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_99C2
	neg.w	d0

loc_99C2:
	cmpi.w	#$90,d0
	bcc.s	loc_99CC
	addq.b	#1,arg(a0)

loc_99CC:
	bra.w	loc_9916
; ---------------------------------------------------------------------------

Obj45:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_99DE(pc,d0.w),d1
	jmp off_99DE(pc,d1.w)
; ---------------------------------------------------------------------------

off_99DE:   dc.w loc_99FA-off_99DE, loc_9A8E-off_99DE, loc_9AC4-off_99DE, loc_9AD8-off_99DE, loc_9AB0-off_99DE

byte_99E8:  dc.b 2, 4, 0
	dc.b 4, $E4, 1
	dc.b 8, $34, 3
	dc.b 6, $28, 2

word_99F4:  dc.w $3800, $A000, $5000
; ---------------------------------------------------------------------------

loc_99FA:
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	word_99F4(pc,d0.w),d2
	lea (byte_99E8).l,a2
	movea.l a0,a1
	moveq	#3,d1
	bra.s	loc_9A18
; ---------------------------------------------------------------------------

loc_9A12:
	bsr.w	LoadNextObject
	bne.s	loc_9A88

loc_9A18:
	move.b	(a2)+,act(a1)
	move.b	#$45,id(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	(a2)+,d0
	ext.w	d0
	add.w	xpos(a0),d0
	move.w	d0,xpos(a1)
	move.l	#Map45,map(a1)
	move.w	#$300,tile(a1)
	move.b	#map,render(a1)
	move.w	xpos(a1),$30(a1)
	move.w	xpos(a0),$3A(a1)
	move.b	arg(a0),arg(a1)
	move.b	#$20,xpix(a1)
	move.w	d2,$34(a1)
	move.w	#$200,prio(a1)
	cmpi.b	#1,(a2)
	bne.s	loc_9A76
	move.b	#$91,col(a1)

loc_9A76:
	move.b	(a2)+,frame(a1)
	move.l	a0,$3C(a1)
	dbf d1,loc_9A12
	move.w	#$180,prio(a1)

loc_9A88:
	move.b	#$10,xpix(a0)

loc_9A8E:
	move.w	xpos(a0),-(sp)
	bsr.w	sub_9AFC
	move.w	#$17,d1
	move.w	#$20,d2
	move.w	#$20,d3
	move.w	(sp)+,d4
	bsr.w	sub_A2BC
	bra.w	loc_9ADC
; ---------------------------------------------------------------------------

loc_9AB0:
	movea.l $3C(a0),a1
	move.b	$32(a1),d0
	addi.b	#$10,d0
	lsr.b	#5,d0
	addq.b	#3,d0
	move.b	d0,frame(a0)

loc_9AC4:
	movea.l $3C(a0),a1
	moveq	#0,d0
	move.b	$32(a1),d0
	neg.w	d0
	add.w	$30(a0),d0
	move.w	d0,xpos(a0)

loc_9AD8:
loc_9ADC:
	move.w	$3A(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_9AFC:
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	off_9B0C(pc,d0.w),d1
	jmp off_9B0C(pc,d1.w)
; ---------------------------------------------------------------------------

off_9B0C:   dc.w loc_9B10-off_9B0C, loc_9B10-off_9B0C
; ---------------------------------------------------------------------------

loc_9B10:
	tst.w	sensorfront(a0)
	beq.s	loc_9B3E
	tst.w	convex(a0)
	beq.s	loc_9B22
	subq.w	#1,convex(a0)
	bra.s	loc_9B72
; ---------------------------------------------------------------------------

loc_9B22:
	subi.w	#$80,$32(a0)
	bcc.s	loc_9B72
	move.w	#0,$32(a0)
	move.w	#0,xvel(a0)
	move.w	#0,sensorfront(a0)
	bra.s	loc_9B72
; ---------------------------------------------------------------------------

loc_9B3E:
	move.w	$34(a0),d1
	cmp.w	$32(a0),d1
	beq.s	loc_9B72
	move.w	xvel(a0),d0
	addi.w	#$70,xvel(a0)
	add.w	d0,$32(a0)
	cmp.w	$32(a0),d1
	bhi.s	loc_9B72
	move.w	d1,$32(a0)
	move.w	#0,xvel(a0)
	move.w	#1,sensorfront(a0)
	move.w	#$3C,convex(a0)

loc_9B72:
	moveq	#0,d0
	move.b	$32(a0),d0
	neg.w	d0
	add.w	$30(a0),d0
	move.w	d0,xpos(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/MZ/ChainPtfm/Sprite.map"
	even
	include "unknown/Map45.map"
	even
; ---------------------------------------------------------------------------

ObjSwitch:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_9D72(pc,d0.w),d1
	jmp off_9D72(pc,d1.w)
; ---------------------------------------------------------------------------

off_9D72:   dc.w loc_9D76-off_9D72, loc_9DAC-off_9D72
; ---------------------------------------------------------------------------

loc_9D76:
	addq.b	#2,act(a0)
	move.l	#MapSwitch,4(a0)
	move.w	#$4513,2(a0)
	cmpi.b	#2,(curzone).w
	beq.s	loc_9D96
	move.w	#$513,2(a0)

loc_9D96:
	move.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$200,prio(a0)
	addq.w	#3,ypos(a0)

loc_9DAC:
	tst.b	render(a0)
	bpl.s	loc_9E2E
	move.w	#$1B,d1
	move.w	#5,d2
	move.w	#5,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	bclr	#0,frame(a0)
	move.b	arg(a0),d0
	andi.w	#$F,d0
	lea (unk_FFF7E0).w,a3
	lea (a3,d0.w),a3
	tst.b	arg(a0)
	bpl.s	loc_9DE8
	bsr.w	sub_9E58
	bne.s	loc_9DFE

loc_9DE8:
	moveq	#0,d3
	btst	#6,arg(a0)
	beq.s	loc_9DF4
	moveq	#7,d3

loc_9DF4:
	tst.b	subact(a0)
	bne.s	loc_9DFE
	bclr	d3,(a3)
	bra.s	loc_9E14
; ---------------------------------------------------------------------------

loc_9DFE:
	tst.b	(a3)
	bne.s	loc_9E0C
	sfx	sfx_Switch

loc_9E0C:
	bset	#0,frame(a0)
	bset	d3,(a3)

loc_9E14:
	btst	#5,arg(a0)
	beq.s	loc_9E2E
	subq.b	#1,anidelay(a0)
	bpl.s	loc_9E2E
	move.b	#7,anidelay(a0)
	bchg	#1,frame(a0)

loc_9E2E:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	loc_9E52
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_9E52:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

sub_9E58:
	move.w	xpos(a0),d2
	move.w	ypos(a0),d3
	subi.w	#$10,d2
	subq.w	#8,d3
	move.w	#$20,d4
	move.w	#$10,d5
	lea (LevelObjectsList).w,a1
	move.w	#$5F,d6

loc_9E76:
	tst.b	render(a1)
	bpl.s	loc_9E82
	cmpi.b	#$33,(a1)
	beq.s	loc_9E90

loc_9E82:
	lea size(a1),a1
	dbf d6,loc_9E76
	moveq	#0,d0

locret_9E8C:
	rts
; ---------------------------------------------------------------------------
	dc.b $10, $10
; ---------------------------------------------------------------------------

loc_9E90:
	moveq	#1,d0
	andi.w	#$3F,d0
	add.w	d0,d0
	lea locret_9E8C(pc,d0.w),a2
	move.b	(a2)+,d1
	ext.w	d1
	move.w	xpos(a1),d0
	sub.w	d1,d0
	sub.w	d2,d0
	bcc.s	loc_9EB2
	add.w	d1,d1
	add.w	d1,d0
	bcs.s	loc_9EB6
	bra.s	loc_9E82
; ---------------------------------------------------------------------------

loc_9EB2:
	cmp.w	d4,d0
	bhi.s	loc_9E82

loc_9EB6:
	move.b	(a2)+,d1
	ext.w	d1
	move.w	ypos(a1),d0
	sub.w	d1,d0
	sub.w	d3,d0
	bcc.s	loc_9ECC
	add.w	d1,d1
	add.w	d1,d0
	bcs.s	loc_9ED0
	bra.s	loc_9E82
; ---------------------------------------------------------------------------

loc_9ECC:
	cmp.w	d5,d0
	bhi.s	loc_9E82

loc_9ED0:
	moveq	#1,d0
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Switch/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjPushBlock:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_9F10(pc,d0.w),d1
	jmp off_9F10(pc,d1.w)
; ---------------------------------------------------------------------------

off_9F10:   dc.w loc_9F1A-off_9F10, loc_9F84-off_9F10, loc_A00C-off_9F10

byte_9F16:  dc.b $10, 0
	dc.b $40, 1
; ---------------------------------------------------------------------------

loc_9F1A:
	addq.b	#2,act(a0)
	move.b	#$F,yrad(a0)
	move.b	#$F,xrad(a0)
	move.l	#MapPushBlock,4(a0)
	move.w	#$42B8,2(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	andi.w	#$E,d0
	lea byte_9F16(pc,d0.w),a2
	move.b	(a2)+,xpix(a0)
	move.b	(a2)+,frame(a0)
	tst.b	arg(a0)
	beq.s	loc_9F68
	move.w	#$C2B8,2(a0)

loc_9F68:
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	beq.s	loc_9F84
	bclr	#7,2(a2,d0.w)
	btst	#0,2(a2,d0.w)
	bne.w	ObjectDelete

loc_9F84:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	move.w	#$10,d2
	move.w	#$11,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A14E
	cmpi.w	#$200,(curzone).w
	bne.s	loc_9FD4
	bclr	#7,arg(a0)
	move.w	xpos(a0),d0
	cmpi.w	#$A20,d0
	bcs.s	loc_9FD4
	cmpi.w	#$AA1,d0
	bcc.s	loc_9FD4
	move.w	(unk_FFF7A4).w,d0
	subi.w	#$1C,d0
	move.w	d0,ypos(a0)
	bset	#7,(unk_FFF7A4).w
	bset	#7,arg(a0)

loc_9FD4:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.s	loc_9FF6
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_9FF6:
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	beq.s	loc_A008
	bclr	#0,2(a2,d0.w)

loc_A008:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

loc_A00C:
	move.w	xpos(a0),-(sp)
	cmpi.b	#4,subact(a0)
	bcc.s	loc_A01C
	bsr.w	ObjectMove

loc_A01C:
	btst	#1,status(a0)
	beq.s	loc_A05E
	addi.w	#$18,yvel(a0)
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.w	loc_A05C
	add.w	d1,ypos(a0)
	clr.w	yvel(a0)
	bclr	#1,status(a0)
	move.w	(a1),d0
	andi.w	#$3FF,d0
	cmpi.w	#$2D2,d0
	bcs.s	loc_A05C
	move.w	$30(a0),d0
	asr.w	#3,d0
	move.w	d0,xvel(a0)
	clr.w	ypix(a0)

loc_A05C:
	bra.s	loc_A0A0
; ---------------------------------------------------------------------------

loc_A05E:
	tst.w	xvel(a0)
	beq.w	loc_A090
	bmi.s	loc_A078
	moveq	#0,d3
	move.b	xpix(a0),d3
	bsr.w	ObjectHitWallRight
	tst.w	d1
	bmi.s	loc_A08A
	bra.s	loc_A0A0
; ---------------------------------------------------------------------------

loc_A078:
	moveq	#0,d3
	move.b	xpix(a0),d3
	not.w	d3
	bsr.w	ObjectHitWallLeft
	tst.w	d1
	bmi.s	loc_A08A
	bra.s	loc_A0A0
; ---------------------------------------------------------------------------

loc_A08A:
	clr.w	xvel(a0)
	bra.s	loc_A0A0
; ---------------------------------------------------------------------------

loc_A090:
	addi.l	#$2001,ypos(a0)
	cmpi.b	#$A0,$F(a0)
	bcc.s	loc_A0CC

loc_A0A0:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	move.w	#$10,d2
	move.w	#$11,d3
	move.w	(sp)+,d4
	bsr.w	sub_A14E
	cmpi.b	#4,act(a0)
	beq.s	loc_A0C6
	move.b	#4,act(a0)

loc_A0C6:
	bsr.s	sub_A0E2
	bra.w	loc_9FD4
; ---------------------------------------------------------------------------

loc_A0CC:
	move.w	(sp)+,d4
	lea (ObjectsList).w,a1
	bclr	#3,status(a1)
	bclr	#3,status(a0)
	bra.w	loc_9FF6
; ---------------------------------------------------------------------------

sub_A0E2:
	cmpi.w	#$201,(curzone).w
	bne.s	loc_A108
	move.w	#$FFE0,d2
	cmpi.w	#$DD0,xpos(a0)
	beq.s	loc_A126
	cmpi.w	#$CC0,xpos(a0)
	beq.s	loc_A126
	cmpi.w	#$BA0,xpos(a0)
	beq.s	loc_A126
	rts
; ---------------------------------------------------------------------------

loc_A108:
	cmpi.w	#$202,(curzone).w
	bne.s	locret_A124
	move.w	#$20,d2
	cmpi.w	#$560,xpos(a0)
	beq.s	loc_A126
	cmpi.w	#$5C0,xpos(a0)
	beq.s	loc_A126

locret_A124:
	rts
; ---------------------------------------------------------------------------

loc_A126:
	bsr.w	ObjectLoad
	bne.s	locret_A14C
	move.b	#$4C,id(a1)
	move.w	xpos(a0),xpos(a1)
	add.w	d2,xpos(a1)
	move.w	ypos(a0),ypos(a1)
	addi.w	#$10,ypos(a1)
	move.l	a0,$3C(a1)

locret_A14C:
	rts
; ---------------------------------------------------------------------------

sub_A14E:
	move.b	subact(a0),d0
	beq.w	loc_A1DE
	subq.b	#2,d0
	bne.s	loc_A172
	bsr.w	PtfmCheckExit
	btst	#3,status(a1)
	bne.s	loc_A16C
	clr.b	subact(a0)
	rts
; ---------------------------------------------------------------------------

loc_A16C:
	move.w	d4,d2
	bra.w	PtfmSurfaceHeight
; ---------------------------------------------------------------------------

loc_A172:
	subq.b	#2,d0
	bne.s	loc_A1B8
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.w	locret_A1B6
	add.w	d1,ypos(a0)
	clr.w	yvel(a0)
	clr.b	subact(a0)
	move.w	(a1),d0
	andi.w	#$3FF,d0
	cmpi.w	#$2D2,d0
	bcs.s	locret_A1B6
	move.w	$30(a0),d0
	asr.w	#3,d0
	move.w	d0,xvel(a0)
	move.b	#4,act(a0)
	clr.w	ypix(a0)

locret_A1B6:
	rts
; ---------------------------------------------------------------------------

loc_A1B8:
	bsr.w	ObjectMove
	move.w	xpos(a0),d0
	andi.w	#$C,d0
	bne.w	locret_A29A
	andi.w	#$FFF0,xpos(a0)
	move.w	xvel(a0),$30(a0)
	clr.w	xvel(a0)
	subq.b	#2,subact(a0)
	rts
; ---------------------------------------------------------------------------

loc_A1DE:
	bsr.w	loc_A37C
	tst.w	d4
	beq.w	locret_A29A
	bmi.w	locret_A29A
	tst.w	d0
	beq.w	locret_A29A
	bmi.s	loc_A222
	btst	#0,status(a1)
	bne.w	locret_A29A
	move.w	d0,-(sp)
	moveq	#0,d3
	move.b	xpix(a0),d3
	bsr.w	ObjectHitWallRight
	move.w	(sp)+,d0
	tst.w	d1
	bmi.w	locret_A29A
	addi.l	#loc_10000,xpos(a0)
	moveq	#1,d0
	move.w	#$40,d1
	bra.s	loc_A24C
; ---------------------------------------------------------------------------

loc_A222:
	btst	#0,status(a1)
	beq.s	locret_A29A
	move.w	d0,-(sp)
	moveq	#0,d3
	move.b	xpix(a0),d3
	not.w	d3
	bsr.w	ObjectHitWallLeft
	move.w	(sp)+,d0
	tst.w	d1
	bmi.s	locret_A29A
	subi.l	#loc_10000,xpos(a0)
	moveq	#$FFFFFFFF,d0
	move.w	#$FFC0,d1

loc_A24C:
	lea (ObjectsList).w,a1
	add.w	d0,xpos(a1)
	move.w	d1,inertia(a1)
	move.w	#0,xvel(a1)
	sfx	sfx_PushBlock
	tst.b	arg(a0)
	bmi.s	locret_A29A
	move.w	d0,-(sp)
	bsr.w	ObjectHitFloor
	move.w	(sp)+,d0
	cmpi.w	#4,d1
	ble.s	loc_A296
	move.w	#$400,xvel(a0)
	tst.w	d0
	bpl.s	loc_A28E
	neg.w	xvel(a0)

loc_A28E:
	move.b	#6,subact(a0)
	bra.s	locret_A29A
; ---------------------------------------------------------------------------

loc_A296:
	add.w	d1,ypos(a0)

locret_A29A:
	rts
; ---------------------------------------------------------------------------
	include "levels/MZ/PushBlock/Sprite.map"
	even
; ---------------------------------------------------------------------------

sub_A2BC:
	cmpi.b	#6,(ObjectsList+$24).w
	bcc.w	loc_A2FE
	tst.b	subact(a0)
	beq.w	loc_A37C
	move.w	d1,d2
	add.w	d2,d2
	lea (ObjectsList).w,a1
	btst	#1,status(a1)
	bne.s	loc_A2EE
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.s	loc_A2EE
	cmp.w	d2,d0
	bcs.s	loc_A302

loc_A2EE:
	bclr	#3,status(a1)
	bclr	#3,status(a0)
	clr.b	subact(a0)

loc_A2FE:
	moveq	#0,d4
	rts
; ---------------------------------------------------------------------------

loc_A302:
	move.w	d4,d2
	bsr.w	PtfmSurfaceHeight
	moveq	#0,d4
	rts
; ---------------------------------------------------------------------------

loc_A30C:
	tst.w	(DebugRoutine).w
	bne.w	loc_A448
	tst.b	render(a0)
	bpl.w	loc_A42E
	lea (ObjectsList).w,a1
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.w	loc_A42E
	move.w	d1,d3
	add.w	d3,d3
	cmp.w	d3,d0
	bhi.w	loc_A42E
	move.w	d0,d5
	btst	#0,render(a0)
	beq.s	loc_A346
	not.w	d5
	add.w	d3,d5

loc_A346:
	lsr.w	#1,d5
	moveq	#0,d3
	move.b	(a2,d5.w),d3
	sub.b	(a2),d3
	move.w	ypos(a0),d5
	sub.w	d3,d5
	move.b	yrad(a1),d3
	ext.w	d3
	add.w	d3,d2
	move.w	ypos(a1),d3
	sub.w	d5,d3
	addq.w	#4,d3
	add.w	d2,d3
	bmi.w	loc_A42E
	subq.w	#4,d3
	move.w	d2,d4
	add.w	d4,d4
	cmp.w	d4,d3
	bcc.w	loc_A42E
	bra.w	loc_A3CC
; ---------------------------------------------------------------------------

loc_A37C:
	tst.w	(DebugRoutine).w
	bne.w	loc_A448
	tst.b	render(a0)
	bpl.w	loc_A42E
	lea (ObjectsList).w,a1
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	add.w	d1,d0
	bmi.w	loc_A42E
	move.w	d1,d3
	add.w	d3,d3
	cmp.w	d3,d0
	bhi.w	loc_A42E
	move.b	yrad(a1),d3
	ext.w	d3
	add.w	d3,d2
	move.w	ypos(a1),d3
	sub.w	ypos(a0),d3
	addq.w	#4,d3
	add.w	d2,d3
	bmi.w	loc_A42E
	subq.w	#4,d3
	move.w	d2,d4
	add.w	d4,d4
	cmp.w	d4,d3
	bcc.w	loc_A42E

loc_A3CC:
	move.w	d0,d5
	cmp.w	d0,d1
	bcc.s	loc_A3DA
	add.w	d1,d1
	sub.w	d1,d0
	move.w	d0,d5
	neg.w	d5

loc_A3DA:
	move.w	d3,d1
	cmp.w	d3,d2
	bcc.s	loc_A3E6
	sub.w	d4,d3
	move.w	d3,d1
	neg.w	d1

loc_A3E6:
	cmp.w	d1,d5
	bhi.w	loc_A44C
	tst.w	d0
	beq.s	loc_A40C
	bmi.s	loc_A3FA
	tst.w	xvel(a1)
	bmi.s	loc_A40C
	bra.s	loc_A400
; ---------------------------------------------------------------------------

loc_A3FA:
	tst.w	xvel(a1)
	bpl.s	loc_A40C

loc_A400:
	move.w	#0,inertia(a1)
	move.w	#0,xvel(a1)

loc_A40C:
	sub.w	d0,xpos(a1)
	btst	#1,status(a1)
	bne.s	loc_A428
	bset	#5,status(a1)
	bset	#5,status(a0)
	moveq	#1,d4
	rts
; ---------------------------------------------------------------------------

loc_A428:
	bsr.s	sub_A43C
	moveq	#1,d4
	rts
; ---------------------------------------------------------------------------

loc_A42E:
	btst	#5,status(a0)
	beq.s	loc_A448
	move.w	#1,ani(a1)
; ---------------------------------------------------------------------------

sub_A43C:
	bclr	#5,status(a0)
	bclr	#5,status(a1)

loc_A448:
	moveq	#0,d4
	rts
; ---------------------------------------------------------------------------

loc_A44C:
	tst.w	d3
	bmi.s	loc_A458

loc_A450:
	cmpi.w	#$10,d3
	bcs.s	loc_A488
	bra.s	loc_A42E
; ---------------------------------------------------------------------------

loc_A458:
	tst.w	yvel(a1)
	beq.s	loc_A472
	bpl.s	loc_A46E
	tst.w	d3
	bpl.s	loc_A46E
	sub.w	d3,ypos(a1)
	move.w	#0,yvel(a1)

loc_A46E:
	moveq	#-1,d4
	rts
; ---------------------------------------------------------------------------

loc_A472:
	btst	#1,status(a1)
	bne.s	loc_A46E
	move.l	a0,-(sp)
	movea.l a1,a0
	bsr.w	loc_FD78
	movea.l (sp)+,a0
	moveq	#-1,d4
	rts
; ---------------------------------------------------------------------------

loc_A488:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addq.w	#4,d1
	move.w	d1,d2
	add.w	d2,d2
	add.w	xpos(a1),d1
	sub.w	xpos(a0),d1
	bmi.s	loc_A4C4
	cmp.w	d2,d1
	bcc.s	loc_A4C4
	tst.w	yvel(a1)
	bmi.s	loc_A4C4
	sub.w	d3,ypos(a1)
	subq.w	#1,ypos(a1)
	bsr.w	loc_4FD4
	move.b	#2,subact(a0)
	bset	#3,status(a0)
	moveq	#-1,d4
	rts
; ---------------------------------------------------------------------------

loc_A4C4:
	moveq	#0,d4
	rts
; ---------------------------------------------------------------------------

ObjTitleCard:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_A4D6(pc,d0.w),d1
	jmp off_A4D6(pc,d1.w)
; ---------------------------------------------------------------------------

off_A4D6:   dc.w loc_A4DE-off_A4D6, loc_A556-off_A4D6, loc_A57C-off_A4D6, loc_A57C-off_A4D6
; ---------------------------------------------------------------------------

loc_A4DE:
	movea.l a0,a1
	moveq	#0,d0
	move.b	(curzone).w,d0
	lea (word_A5E4).l,a3
	lsl.w	#4,d0
	adda.w	d0,a3
	lea (word_A5D4).l,a2
	moveq	#3,d1

loc_A4F8:
	move.b	#$34,id(a1)
	move.w	(a3),xpos(a1)
	move.w	(a3)+,$32(a1)
	move.w	(a3)+,$30(a1)
	move.w	(a2)+,xpix(a1)
	move.b	(a2)+,act(a1)
	move.b	(a2)+,d0
	bne.s	loc_A51A
	move.b	(curzone).w,d0

loc_A51A:
	cmpi.b	#7,d0
	bne.s	loc_A524
	add.b	(curact).w,d0

loc_A524:
	move.b	d0,frame(a1)
	move.l	#MapTitleCard,map(a1)
	move.w	#$8580,tile(a1)
	move.b	#$78,xpix(a1)
	move.b	#0,render(a1)
	move.w	#0,prio(a1)
	move.w	#$3C,anidelay(a1)
	lea size(a1),a1
	dbf d1,loc_A4F8

loc_A556:
	moveq	#$10,d1
	move.w	$30(a0),d0
	cmp.w	xpos(a0),d0
	beq.s	loc_A56A
	bge.s	loc_A566
	neg.w	d1

loc_A566:
	add.w	d1,xpos(a0)

loc_A56A:
	move.w	xpos(a0),d0
	bmi.s	locret_A57A
	cmpi.w	#$200,d0
	bcc.s	locret_A57A
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

locret_A57A:
	rts
; ---------------------------------------------------------------------------

loc_A57C:
	tst.w	anidelay(a0)
	beq.s	loc_A58A
	subq.w	#1,anidelay(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_A58A:
	moveq	#$20,d1
	move.w	$32(a0),d0
	cmp.w	xpos(a0),d0
	beq.s	loc_A5B0
	bge.s	loc_A59A
	neg.w	d1

loc_A59A:
	add.w	d1,xpos(a0)
	move.w	xpos(a0),d0
	bmi.s	locret_A5AE
	cmpi.w	#$200,d0
	bcc.s	locret_A5AE
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

locret_A5AE:
	rts
; ---------------------------------------------------------------------------

loc_A5B0:
	cmpi.b	#4,act(a0)
	bne.s	loc_A5D0
	moveq	#2,d0
	jsr (plcAdd).l
	moveq	#0,d0
	move.b	(curzone).w,d0
	addi.w	#$15,d0
	jsr (plcAdd).l

loc_A5D0:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

word_A5D4:  dc.w $D0
	dc.b 2, 0
	dc.w $E4
	dc.b 2, 6
	dc.w $EA
	dc.b 2, 7
	dc.w $E0
	dc.b 2, $A

word_A5E4:  dc.w 0, $120, $FEFC, $13C, $414, $154, $214, $154
	dc.w 0, $120, $FEF4, $134, $40C, $14C, $20C, $14C
	dc.w 0, $120, $FEE0, $120, $3F8, $138, $1F8, $138
	dc.w 0, $120, $FEFC, $13C, $414, $154, $214, $154
	dc.w 0, $120, $FEF4, $134, $40C, $14C, $20C, $14C
	dc.w 0, $120, $FF00, $140, $418, $158, $218, $158
; ---------------------------------------------------------------------------

ObjGameOver:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_A652(pc,d0.w),d1
	jmp off_A652(pc,d1.w)
; ---------------------------------------------------------------------------

off_A652:   dc.w loc_A658-off_A652, loc_A696-off_A652, loc_A6B8-off_A652
; ---------------------------------------------------------------------------

loc_A658:
	tst.l	(plcList).w
	beq.s	loc_A660
	rts
; ---------------------------------------------------------------------------

loc_A660:
	addq.b	#2,act(a0)
	move.w	#$50,xpos(a0)
	tst.b	frame(a0)
	beq.s	loc_A676
	move.w	#$1F0,xpos(a0)

loc_A676:
	move.w	#$F0,xpix(a0)
	move.l	#MapGameOver,map(a0)
	move.w	#$8580,tile(a0)
	move.b	#0,render(a0)
	move.w	#0,prio(a0)

loc_A696:
	moveq	#$10,d1
	cmpi.w	#$120,xpos(a0)
	beq.s	loc_A6AC
	bcs.s	loc_A6A4
	neg.w	d1

loc_A6A4:
	add.w	d1,xpos(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_A6AC:
	move.w	#$258,anidelay(a0)
	addq.b	#2,act(a0)
	rts
; ---------------------------------------------------------------------------

loc_A6B8:
	move.b	(padPressPlayer).w,d0
	andi.b	#J_B|J_C|J_A,d0
	bne.s	loc_A6D6
	tst.b	frame(a0)
	bne.s	loc_A6DC
	tst.w	anidelay(a0)
	beq.s	loc_A6D6
	subq.w	#1,anidelay(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_A6D6:
	move.b	#0,(GameMode).w

loc_A6DC:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjLevelResults:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_A6EE(pc,d0.w),d1
	jmp off_A6EE(pc,d1.w)
; ---------------------------------------------------------------------------

off_A6EE:   dc.w loc_A6FA-off_A6EE, loc_A74E-off_A6EE, loc_A786-off_A6EE, loc_A794-off_A6EE, loc_A786-off_A6EE
	dc.w loc_A7F2-off_A6EE
; ---------------------------------------------------------------------------

loc_A6FA:
	tst.l	(plcList).w
	beq.s	loc_A702
	rts
; ---------------------------------------------------------------------------

loc_A702:
	movea.l a0,a1
	lea (word_A856).l,a2
	moveq	#6,d1

loc_A70C:
	move.b	#$3A,id(a1)
	move.w	(a2)+,xpos(a1)
	move.w	(a2)+,$30(a1)
	move.w	(a2)+,xpix(a1)
	move.b	(a2)+,act(a1)
	move.b	(a2)+,d0
	cmpi.b	#6,d0
	bne.s	loc_A72E
	add.b	(curact).w,d0

loc_A72E:
	move.b	d0,frame(a1)
	move.l	#MapLevelResults,map(a1)
	move.w	#$8580,tile(a1)
	move.b	#0,render(a1)
	lea size(a1),a1
	dbf d1,loc_A70C

loc_A74E:
	moveq	#$10,d1
	move.w	$30(a0),d0
	cmp.w	xpos(a0),d0
	beq.s	loc_A774
	bge.s	loc_A75E
	neg.w	d1

loc_A75E:
	add.w	d1,xpos(a0)

loc_A762:
	move.w	xpos(a0),d0
	bmi.s	locret_A772
	cmpi.w	#$200,d0
	bcc.s	locret_A772
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

locret_A772:
	rts
; ---------------------------------------------------------------------------

loc_A774:
	cmpi.b	#4,frame(a0)
	bne.s	loc_A762
	addq.b	#2,act(a0)
	move.w	#$B4,anidelay(a0)

loc_A786:
	subq.w	#1,anidelay(a0)
	bne.s	loc_A790
	addq.b	#2,act(a0)

loc_A790:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_A794:
	bsr.w	ObjectDisplay
	st.b	(byte_FFFE58).w
	moveq	#0,d0
	tst.w	(word_FFFE54).w
	beq.s	loc_A7B0
	addi.w	#10,d0
	subi.w	#10,(word_FFFE54).w

loc_A7B0:
	tst.w	(word_FFFE56).w
	beq.s	loc_A7C0
	addi.w	#10,d0
	subi.w	#10,(word_FFFE56).w

loc_A7C0:
	tst.w	d0
	bne.s	loc_A7DA
	sfx	sfx_Register
	addq.b	#2,act(a0)
	move.w	#$B4,anidelay(a0)

locret_A7D8:
	rts
; ---------------------------------------------------------------------------

loc_A7DA:
	bsr.w	ScoreAdd
	sfx	sfx_Switch
	rts
; ---------------------------------------------------------------------------

loc_A7F2:
	move.b	(curzone).w,d0
	andi.w	#7,d0
	lsl.w	#3,d0
	move.b	(curact).w,d1
	andi.w	#3,d1
	add.w	d1,d1
	add.w	d1,d0
	move.w	word_A826(pc,d0.w),d0
	move.w	d0,(curzone).w
	tst.w	d0
	bne.s	loc_A81C
	clr.b	(GameMode).w
	bra.s	loc_A822
; ---------------------------------------------------------------------------

loc_A81C:
	move.b	#1,(LevelRestart).w

loc_A822:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	
word_A826:  dc.w 1,    2, $200,    0
	dc.w $101, $102, $200,	  0
	dc.w $201, $202, $400,	  0
	dc.w 0, $302, $200,    0
	dc.w $300, $402, $500,	  0
	dc.w $501, $502,    0,	  0

word_A856:    ; routine number, frame	 number (changes)
	; x-start, x-main, y-main
	dc.w 4,    $124, $BC ; SONIC HAS
	dc.b 2,    0
	dc.w $FEE0, $120, $D0 ; PASSED
	dc.b 2,    1
	dc.w $40C, $14C, $D6 ; act number
	dc.b 2,    6
	dc.w $520,    $120,    $122 ; score
	dc.b 2,    2
	dc.w $540,    $120,    $F2 ; time bonus
	dc.b 2,    3
	dc.w $560,    $120,    $102 ; ring bonus
	dc.b 2,    4
	dc.w $20C, $14C, $CC ; The blue bit of the card
	dc.b 2,    5
	include "levels/shared/TitleCard/Sprite.map"
	even
	include "levels/shared/GameOver/Sprite.map"
	include "levels/shared/LevelResults/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSpikes:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_AB0A(pc,d0.w),d1
	jmp off_AB0A(pc,d1.w)
; ---------------------------------------------------------------------------

off_AB0A:   dc.w loc_AB1A-off_AB0A, loc_AB64-off_AB0A

byte_AB0E:  dc.b 0, $14
	dc.b 1, $10
	dc.b 2, 4
	dc.b 3, $1C
	dc.b 4, $40
	dc.b 5, $10
; ---------------------------------------------------------------------------

loc_AB1A:
	addq.b	#tile,act(a0)
	move.l	#MapSpikes,map(a0)
	move.w	#$51B,tile(a0)
	ori.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	arg(a0),d0
	andi.b	#$F,arg(a0)
	andi.w	#$F0,d0
	lea (byte_AB0E).l,a1
	lsr.w	#3,d0
	adda.w	d0,a1
	move.b	(a1)+,frame(a0)
	move.b	(a1)+,xpix(a0)
	move.w	xpos(a0),$30(a0)
	move.w	ypos(a0),$32(a0)

loc_AB64:
	bsr.w	sub_AC02
	move.w	#4,d2
	cmpi.b	#5,frame(a0)
	beq.s	loc_AB80
	cmpi.b	#1,frame(a0)
	bne.s	loc_AB9E
	move.w	#$14,d2

loc_AB80:
	move.w	#$1B,d1
	move.w	d2,d3
	subq.w	#2,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	tst.b	subact(a0)
	bne.s	loc_ABDE
	cmpi.w	#1,d4
	beq.s	loc_ABBE
	bra.s	loc_ABDE
; ---------------------------------------------------------------------------

loc_AB9E:
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	move.w	#$10,d2
	bsr.w	sub_6936
	tst.w	d4
	bpl.s	loc_ABDE
	tst.w	yvel(a1)
	beq.s	loc_ABDE
	tst.w	d3
	bmi.s	loc_ABDE

loc_ABBE:

	move.l	a0,-(sp)
	movea.l a0,a2
	lea (ObjectsList).w,a0
	move.l	ypos(a0),d3
	move.w	yvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	sub.l	d0,d3
	move.l	d3,ypos(a0)
	bsr.w	loc_FCF4
	movea.l (sp)+,a0

loc_ABDE:
	move.w	$30(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_AC02:
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	off_AC12(pc,d0.w),d1
	jmp off_AC12(pc,d1.w)
; ---------------------------------------------------------------------------

off_AC12:   dc.w locret_AC18-off_AC12, loc_AC1A-off_AC12
	dc.w loc_AC2E-off_AC12
; ---------------------------------------------------------------------------

locret_AC18:
	rts
; ---------------------------------------------------------------------------

loc_AC1A:
	bsr.w	sub_AC42
	moveq	#0,d0
	move.b	$34(a0),d0
	add.w	$32(a0),d0
	move.w	d0,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_AC2E:
	bsr.w	sub_AC42
	moveq	#0,d0
	move.b	$34(a0),d0
	add.w	$30(a0),d0
	move.w	d0,xpos(a0)
	rts
; ---------------------------------------------------------------------------

sub_AC42:
	tst.w	convex(a0)
	beq.s	loc_AC60
	subq.w	#1,convex(a0)
	bne.s	locret_ACA2
	tst.b	render(a0)
	bpl.s	locret_ACA2
	sfx	sfx_SpikeMove
	bra.s	locret_ACA2
; ---------------------------------------------------------------------------

loc_AC60:
	tst.w	sensorfront(a0)
	beq.s	loc_AC82
	subi.w	#$800,$34(a0)
	bcc.s	locret_ACA2
	move.w	#0,$34(a0)
	move.w	#0,sensorfront(a0)
	move.w	#$3C,convex(a0)
	bra.s	locret_ACA2
; ---------------------------------------------------------------------------

loc_AC82:
	addi.w	#$800,$34(a0)
	cmpi.w	#$2000,$34(a0)
	bcs.s	locret_ACA2
	move.w	#$2000,$34(a0)
	move.w	#1,sensorfront(a0)
	move.w	#$3C,convex(a0)

locret_ACA2:
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Spikes/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjPurpleRock:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_AD1A(pc,d0.w),d1
	jmp off_AD1A(pc,d1.w)
; ---------------------------------------------------------------------------

off_AD1A:   dc.w loc_AD1E-off_AD1A, loc_AD42-off_AD1A
; ---------------------------------------------------------------------------

loc_AD1E:
	addq.b	#2,act(a0)
	move.l	#MapPurpleRock,map(a0)
	move.w	#$63D0,tile(a0)
	move.b	#4,render(a0)
	move.b	#$13,xpix(a0)
	move.w	#$200,prio(a0)

loc_AD42:
	move.w	#$1B,d1
	move.w	#$10,d2
	move.w	#$10,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjWaterfallSnd:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	.act(pc,d0.w),d1
	jmp .act(pc,d1.w)
; ---------------------------------------------------------------------------

.act:	    dc.w ObjWaterfallSnd_Init-.act, ObjWaterfallSnd_Act-.act
; ---------------------------------------------------------------------------

ObjWaterfallSnd_Init:
	addq.b	#2,act(a0)
	move.b	#4,render(a0)

ObjWaterfallSnd_Act:
	; this is to avoid overwriting any other sfx
	tst.b	mQueue+2.w	; check if any sound was queued
	bne.s	.nosound	; if was, skip
	move.b	#sfx_Waterfall,mQueue+2.w; else, play this again

.nosound:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------
	include "levels/GHZ/PurpleRock/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSmashWall:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_ADEA(pc,d0.w),d1
	jsr off_ADEA(pc,d1.w)
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_ADEA:   dc.w loc_ADF0-off_ADEA, loc_AE1A-off_ADEA, loc_AE92-off_ADEA
; ---------------------------------------------------------------------------

loc_ADF0:
	addq.b	#2,act(a0)
	move.l	#MapSmashWall,4(a0)
	move.w	#$450F,2(a0)
	move.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$200,prio(a0)
	move.b	arg(a0),frame(a0)

loc_AE1A:
	move.w	(ObjectsList+$10).w,$30(a0)
	move.w	#$1B,d1
	move.w	#$20,d2
	move.w	#$20,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	btst	#5,status(a0)
	bne.s	loc_AE3E

locret_AE3C:
	rts
; ---------------------------------------------------------------------------

loc_AE3E:
	cmpi.b	#2,ani(a1)
	bne.s	locret_AE3C
	move.w	$30(a0),d0
	bpl.s	loc_AE4E
	neg.w	d0

loc_AE4E:
	cmpi.w	#$480,d0
	bcs.s	locret_AE3C
	move.w	$30(a0),xvel(a1)
	addq.w	#4,xpos(a1)
	lea (ObjSmashWall_FragRight).l,a4
	move.w	xpos(a0),d0
	cmp.w	xpos(a1),d0
	bcs.s	loc_AE78
	subq.w	#8,xpos(a1)
	lea (ObjSmashWall_FragLeft).l,a4

loc_AE78:
	move.w	xvel(a1),inertia(a1)
	bclr	#5,status(a0)
	bclr	#5,status(a1)
	moveq	#7,d1
	move.w	#$70,d2
	bsr.s	ObjectFragment

loc_AE92:
	bsr.w	ObjectMove
	addi.w	#$70,yvel(a0)
	tst.b	render(a0)
	bpl.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjectFragment:
	moveq	#0,d0
	move.b	frame(a0),d0
	add.w	d0,d0
	movea.l map(a0),a3
	adda.w	(a3,d0.w),a3
	addq.w	#1,a3
	bset	#5,render(a0)
	move.b	id(a0),d4
	move.b	render(a0),d5
	movea.l a0,a1
	bra.s	loc_AED6
; ---------------------------------------------------------------------------

loc_AECE:
	bsr.w	LoadNextObject
	bne.s	loc_AF28
	addq.w	#5,a3

loc_AED6:
	move.b	#4,act(a1)
	move.b	d4,id(a1)
	move.l	a3,map(a1)
	move.b	d5,render(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.w	tile(a0),tile(a1)
	move.w	prio(a0),prio(a1)
	move.b	xpix(a0),xpix(a1)
	move.w	(a4)+,xvel(a1)
	move.w	(a4)+,yvel(a1)
	dbf d1,loc_AECE

loc_AF28:
	sfx	sfx_Smash
	rts
; ---------------------------------------------------------------------------

ObjSmashWall_FragRight:dc.w $400, $FB00
	dc.w $600, $FF00
	dc.w $600, $100
	dc.w $400, $500
	dc.w $600, $FA00
	dc.w $800, $FE00
	dc.w $800, $200
	dc.w $600, $600

ObjSmashWall_FragLeft:dc.w $FA00, $FA00
	dc.w $F800, $FE00
	dc.w $F800, $200
	dc.w $FA00, $600
	dc.w $FC00, $FB00
	dc.w $FA00, $FF00
	dc.w $FA00, $100
	dc.w $FC00, $500
	include "levels/GHZ/SmashWall/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjGHZBoss:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_B002(pc,d0.w),d1
	jmp off_B002(pc,d1.w)
; ---------------------------------------------------------------------------

off_B002:   dc.w loc_B010-off_B002, loc_B07C-off_B002, loc_B2AE-off_B002, loc_B2D6-off_B002

byte_B00A:  dc.b 2, 0
	dc.b 4, 1
	dc.b 6, 7
; ---------------------------------------------------------------------------

loc_B010:
	lea (byte_B00A).l,a2
	movea.l a0,a1
	moveq	#2,d1
	bra.s	loc_B022
; ---------------------------------------------------------------------------

loc_B01C:
	bsr.w	LoadNextObject
	bne.s	loc_B064

loc_B022:
	move.b	(a2)+,act(a1)
	move.b	#$3D,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.l	#MapGHZBoss,map(a1)
	move.w	#$400,tile(a1)
	move.b	#4,render(a1)
	move.b	#$20,xpix(a1)
	move.b	#$80,prio+1(a1)
	move.b	(a2)+,ani(a1)
	move.l	a0,$34(a1)
	dbf d1,loc_B01C

loc_B064:
	move.w	xpos(a0),$30(a0)
	move.w	ypos(a0),convex(a0)
	move.b	#$F,col(a0)
	move.b	#8,colprop(a0)

loc_B07C:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_B0AA(pc,d0.w),d1
	jsr off_B0AA(pc,d1.w)
	lea (AniGHZBoss).l,a1
	bsr.w	ObjectAnimate
	move.b	status(a0),d0
	andi.b	#3,d0

loc_B09C:
	andi.b	#$FC,render(a0)
	or.b	d0,render(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_B0AA:   dc.w loc_B0B6-off_B0AA, loc_B1AE-off_B0AA
	dc.w loc_B1FC-off_B0AA, loc_B236-off_B0AA
	dc.w loc_B25C-off_B0AA, loc_B290-off_B0AA
; ---------------------------------------------------------------------------

loc_B0B6:
	move.w	#$100,yvel(a0)
	bsr.w	BossMove
	cmpi.w	#$338,convex(a0)
	bne.s	loc_B0D2
	move.w	#0,yvel(a0)
	addq.b	#2,subact(a0)

loc_B0D2:
	move.b	$3F(a0),d0
	jsr (GetSine).l
	asr.w	#6,d0
	add.w	convex(a0),d0
	move.w	d0,ypos(a0)
	move.w	$30(a0),xpos(a0)
	addq.b	#2,$3F(a0)
	cmpi.b	#8,subact(a0)
	bcc.s	locret_B136
	tst.b	status(a0)
	bmi.s	loc_B138
	tst.b	col(a0)
	bne.s	locret_B136
	tst.b	$3E(a0)
	bne.s	loc_B11A
	move.b	#$20,$3E(a0)
	sfx	sfx_BossHit

loc_B11A:
	lea ((Palette+$22)).w,a1
	moveq	#0,d0
	tst.w	(a1)
	bne.s	loc_B128
	move.w	#$EEE,d0

loc_B128:
	move.w	d0,(a1)
	subq.b	#1,$3E(a0)
	bne.s	locret_B136
	move.b	#$F,col(a0)

locret_B136:
	rts
; ---------------------------------------------------------------------------

loc_B138:
	move.b	#8,subact(a0)
	move.w	#$B3,$3C(a0)
	rts
; ---------------------------------------------------------------------------

sub_B146:
	move.b	(byte_FFFE0F).w,d0
	andi.b	#7,d0
	bne.s	locret_B186
	bsr.w	ObjectLoad
	bne.s	locret_B186
	move.b	#$3F,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	jsr (RandomNumber).l
	move.w	d0,d1
	moveq	#0,d1
	move.b	d0,d1
	lsr.b	#2,d1
	subi.w	#$20,d1
	add.w	d1,xpos(a1)
	lsr.w	#8,d0
	lsr.b	#3,d0
	add.w	d0,ypos(a1)

locret_B186:
	rts
; ---------------------------------------------------------------------------

BossMove:
	move.l	$30(a0),d2
	move.l	convex(a0),d3
	move.w	xvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	add.l	d0,d2
	move.w	yvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	add.l	d0,d3
	move.l	d2,$30(a0)
	move.l	d3,convex(a0)
	rts
; ---------------------------------------------------------------------------

loc_B1AE:
	move.w	#$FF00,xvel(a0)
	move.w	#$FFC0,yvel(a0)
	bsr.w	BossMove
	cmpi.w	#$2A00,$30(a0)
	bne.s	loc_B1F8
	move.w	#0,xvel(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,subact(a0)
	bsr.w	LoadNextObject
	bne.s	loc_B1F2
	move.b	#$48,id(a1)
	move.w	$30(a0),xpos(a1)
	move.w	convex(a0),ypos(a1)
	move.l	a0,$34(a1)

loc_B1F2:
	move.w	#$77,$3C(a0)

loc_B1F8:
	bra.w	loc_B0D2
; ---------------------------------------------------------------------------

loc_B1FC:
	subq.w	#1,$3C(a0)
	bpl.s	loc_B226
	addq.b	#2,subact(a0)
	move.w	#$3F,$3C(a0)
	move.w	#$100,xvel(a0)
	cmpi.w	#$2A00,$30(a0)
	bne.s	loc_B226
	move.w	#$7F,$3C(a0)
	move.w	#$40,xvel(a0)

loc_B226:
	btst	#0,status(a0)
	bne.s	loc_B232
	neg.w	xvel(a0)

loc_B232:
	bra.w	loc_B0D2
; ---------------------------------------------------------------------------

loc_B236:
	subq.w	#1,$3C(a0)
	bmi.s	loc_B242
	bsr.w	BossMove
	bra.s	loc_B258
; ---------------------------------------------------------------------------

loc_B242:
	bchg	#0,status(a0)
	move.w	#$3F,$3C(a0)
	subq.b	#2,subact(a0)
	move.w	#0,xvel(a0)

loc_B258:
	bra.w	loc_B0D2
; ---------------------------------------------------------------------------

loc_B25C:
	subq.w	#1,$3C(a0)
	bmi.s	loc_B266
	bra.w	sub_B146
; ---------------------------------------------------------------------------

loc_B266:
	bset	#0,status(a0)
	bclr	#7,status(a0)
	move.w	#$400,xvel(a0)
	move.w	#$FFC0,yvel(a0)
	addq.b	#2,subact(a0)
	tst.b	(unk_FFF7A7).w
	bne.s	locret_B28E
	move.b	#1,(unk_FFF7A7).w

locret_B28E:
	rts
; ---------------------------------------------------------------------------

loc_B290:
	cmpi.w	#$2AC0,(unk_FFF72A).w
	beq.s	loc_B29E
	addq.w	#2,(unk_FFF72A).w
	bra.s	loc_B2A6
; ---------------------------------------------------------------------------

loc_B29E:
	tst.b	render(a0)
	bpl.w	ObjectDelete

loc_B2A6:
	bsr.w	BossMove
	bra.w	loc_B0D2
; ---------------------------------------------------------------------------

loc_B2AE:
	movea.l $34(a0),a1
	cmpi.b	#$A,subact(a1)
	bne.s	loc_B2C2
	tst.b	render(a0)
	bpl.w	ObjectDelete

loc_B2C2:
	move.b	#1,ani(a0)
	tst.b	col(a1)
	bne.s	loc_B2D4
	move.b	#5,ani(a0)

loc_B2D4:
	bra.s	loc_B2FC
; ---------------------------------------------------------------------------

loc_B2D6:
	movea.l $34(a0),a1
	cmpi.b	#$A,subact(a1)
	bne.s	loc_B2EA
	tst.b	render(a0)
	bpl.w	ObjectDelete

loc_B2EA:
	move.b	#7,ani(a0)
	move.w	xvel(a1),d0
	beq.s	loc_B2FC
	move.b	#8,ani(a0)

loc_B2FC:
	movea.l $34(a0),a1
	move.w	xpos(a1),xpos(a0)
	move.w	ypos(a1),ypos(a0)
	move.b	status(a1),status(a0)
	lea (AniGHZBoss).l,a1
	bsr.w	ObjectAnimate
	move.b	status(a0),d0
	andi.b	#3,d0
	andi.b	#$FC,render(a0)
	or.b	d0,render(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjGHZBossBall:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_B340(pc,d0.w),d1
	jmp off_B340(pc,d1.w)
; ---------------------------------------------------------------------------

off_B340:   dc.w loc_B34A-off_B340, loc_B404-off_B340, loc_B462-off_B340, loc_B49E-off_B340, loc_B4B8-off_B340
; ---------------------------------------------------------------------------

loc_B34A:
	addq.b	#2,act(a0)
	move.w	#$4080,angle(a0)
	move.w	#$FE00,$3E(a0)
	move.l	#MapGHZBossBall,4(a0)
	move.w	#$46C,2(a0)
	lea arg(a0),a2
	move.b	#0,(a2)+
	moveq	#5,d1
	movea.l a0,a1
	bra.s	loc_B3AC
; ---------------------------------------------------------------------------

loc_B376:
	bsr.w	LoadNextObject
	bne.s	loc_B3D6
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	#$48,id(a1)
	move.b	#6,act(a1)
	move.l	#MapSwingPtfm,4(a1)
	move.w	#$380,2(a1)
	move.b	#1,frame(a1)
	addq.b	#1,arg(a0)

loc_B3AC:
	move.w	a1,d5
	subi.w	#$D000,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+
	move.b	#4,render(a1)
	move.b	#8,xpix(a1)
	move.w	#$300,prio(a1)
	move.l	$34(a0),$34(a1)
	dbf d1,loc_B376

loc_B3D6:
	move.b	#8,act(a1)
	move.l	#$5E7A,4(a1)
	move.w	#$43AA,2(a1)
	move.b	#1,frame(a1)
	move.w	#$280,prio(a1)
	move.b	#$81,col(a1)
	rts
; ---------------------------------------------------------------------------

byte_B3FE:  dc.b 0, $10, $20, $30, $40, $60
; ---------------------------------------------------------------------------

loc_B404:
	lea (byte_B3FE).l,a3
	lea arg(a0),a2
	moveq	#0,d6
	move.b	(a2)+,d6

loc_B412:
	moveq	#0,d4
	move.b	(a2)+,d4
	lsl.w	#6,d4
	addi.l	#(ObjectsList)&$FFFFFF,d4
	movea.l d4,a1
	move.b	(a3)+,d0
	cmp.b	$3C(a1),d0
	beq.s	loc_B42C
	addq.b	#1,$3C(a1)

loc_B42C:
	dbf d6,loc_B412
	cmp.b	$3C(a1),d0
	bne.s	loc_B446
	movea.l $34(a0),a1
	cmpi.b	#6,subact(a1)
	bne.s	loc_B446
	addq.b	#2,act(a0)

loc_B446:
	cmpi.w	#$20,$32(a0)
	beq.s	loc_B452
	addq.w	#1,$32(a0)

loc_B452:
	bsr.w	sub_B46E
	move.b	angle(a0),d0
	bsr.w	loc_5692
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_B462:
	bsr.w	sub_B46E
	bsr.w	loc_5652
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_B46E:
	movea.l $34(a0),a1
	move.w	xpos(a1),$3A(a0)
	move.w	ypos(a1),d0
	add.w	$32(a0),d0
	move.w	d0,convex(a0)
	move.b	status(a1),status(a0)
	tst.b	status(a1)
	bpl.s	locret_B49C
	move.b	#$3F,id(a0)
	move.b	#0,act(a0)

locret_B49C:
	rts
; ---------------------------------------------------------------------------

loc_B49E:
	movea.l $34(a0),a1
	tst.b	status(a1)
	bpl.s	loc_B4B4
	move.b	#$3F,id(a0)
	move.b	#0,act(a0)

loc_B4B4:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_B4B8:
	moveq	#0,d0
	tst.b	frame(a0)
	bne.s	loc_B4C2
	addq.b	#1,d0

loc_B4C2:
	move.b	d0,frame(a0)
	movea.l $34(a0),a1
	tst.b	status(a1)
	bpl.w	ObjectDisplay
	move.b	#0,col(a0)
	bsr.w	sub_B146
	subq.b	#1,$3C(a0)
	bpl.s	loc_B4EE
	move.b	#$3F,id(a0)
	move.b	#0,act(a0)

loc_B4EE:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/GHZ/Boss/Sprite.ani"
	include "levels/GHZ/Boss/Sprite.map"
	even
	include "levels/GHZ/Boss/Ball.map"
	even
; ---------------------------------------------------------------------------

ObjCapsule:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_B66C(pc,d0.w),d1
	jsr off_B66C(pc,d1.w)
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_B66C:   dc.w loc_B68C-off_B66C, loc_B6D6-off_B66C
	dc.w loc_B710-off_B66C, loc_B760-off_B66C
	dc.w loc_B760-off_B66C, loc_B760-off_B66C
	dc.w loc_B7C6-off_B66C, loc_B7FA-off_B66C

byte_B67C:  dc.b 2, $20, 4, 0
	dc.b 4, $C, 5, 1
	dc.b 6, $10, 4, 3
	dc.b 8, $10, 3, 5
; ---------------------------------------------------------------------------

loc_B68C:
	move.l	#MapCapsule,map(a0)
	move.w	#$49D,tile(a0)
	move.b	#4,render(a0)
	move.w	ypos(a0),$30(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	lsl.w	#2,d0
	lea byte_B67C(pc,d0.w),a1
	move.b	(a1)+,act(a0)
	move.b	(a1)+,xpix(a0)
	move.w	#$180,prio(a0)
	move.b	(a1)+,frame(a0)
	cmpi.w	#8,d0
	bne.s	locret_B6D4
	move.b	#6,col(a0)
	move.b	#8,colprop(a0)

locret_B6D4:
	rts
; ---------------------------------------------------------------------------

loc_B6D6:
	cmpi.b	#2,(unk_FFF7A7).w
	beq.s	loc_B6F2
	move.w	#$2B,d1
	move.w	#$18,d2
	move.w	#$18,d3
	move.w	xpos(a0),d4
	bra.w	sub_A2BC
; ---------------------------------------------------------------------------

loc_B6F2:
	tst.b	subact(a0)
	beq.s	loc_B708
	clr.b	subact(a0)
	bclr	#3,(ObjectsList+$22).w
	bset	#1,(ObjectsList+$22).w

loc_B708:
	move.b	#2,frame(a0)
	rts
; ---------------------------------------------------------------------------

loc_B710:
	move.w	#$17,d1
	move.w	#8,d2
	move.w	#8,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	lea (AniCapsule).l,a1
	bsr.w	ObjectAnimate
	move.w	$30(a0),ypos(a0)
	tst.b	subact(a0)
	beq.s	locret_B75E
	addq.w	#8,ypos(a0)
	move.b	#$A,act(a0)
	move.w	#$3C,anidelay(a0)
	clr.b	(byte_FFFE1E).w
	clr.b	subact(a0)
	bclr	#3,(ObjectsList+$22).w
	bset	#1,(ObjectsList+$22).w

locret_B75E:
	rts
; ---------------------------------------------------------------------------

loc_B760:
	move.b	(byte_FFFE0F).w,d0
	andi.b	#7,d0
	bne.s	loc_B7A0
	bsr.w	ObjectLoad
	bne.s	loc_B7A0
	move.b	#$3F,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	jsr (RandomNumber).l
	move.w	d0,d1
	moveq	#0,d1
	move.b	d0,d1
	lsr.b	#2,d1
	subi.w	#$20,d1
	add.w	d1,xpos(a1)
	lsr.w	#8,d0
	lsr.b	#3,d0
	add.w	d0,ypos(a1)

loc_B7A0:
	subq.w	#1,anidelay(a0)
	bne.s	locret_B7C4
	move.b	#2,(unk_FFF7A7).w
	move.b	#$C,act(a0)
	move.b	#9,frame(a0)
	move.w	#$B4,anidelay(a0)
	addi.w	#$20,ypos(a0)

locret_B7C4:
	rts
; ---------------------------------------------------------------------------

loc_B7C6:
	move.b	(byte_FFFE0F).w,d0
	andi.b	#6,d0
	bne.s	loc_B7E8
	bsr.w	ObjectLoad
	bne.s	loc_B7E8
	move.b	#$28,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)

loc_B7E8:
	subq.w	#1,anidelay(a0)
	bne.s	locret_B7F8
	addq.b	#2,act(a0)
	move.w	#$3C,anidelay(a0)

locret_B7F8:
	rts
; ---------------------------------------------------------------------------

loc_B7FA:
	subq.w	#1,anidelay(a0)
	bne.s	locret_B808
	bsr.w	sub_C81C
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

locret_B808:
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Capsule/Sprite.ani"
	include "levels/shared/Capsule/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjMotobug:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_B890(pc,d0.w),d1
	jmp off_B890(pc,d1.w)
; ---------------------------------------------------------------------------

off_B890:   dc.w loc_B898-off_B890, loc_B8FA-off_B890, loc_B9D8-off_B890, loc_B9E6-off_B890
; ---------------------------------------------------------------------------

loc_B898:
	move.l	#MapMotobug,4(a0)
	move.w	#$4F0,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$14,xpix(a0)
	tst.b	ani(a0)
	bne.s	loc_B8F2
	move.b	#$E,yrad(a0)
	move.b	#8,xrad(a0)
	move.b	#$C,col(a0)
	bsr.w	ObjectFall
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_B8F0
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,act(a0)
	bchg	#0,status(a0)

locret_B8F0:
	rts
; ---------------------------------------------------------------------------

loc_B8F2:
	addq.b	#4,act(a0)
	bra.w	loc_B9D8
; ---------------------------------------------------------------------------

loc_B8FA:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_B94E(pc,d0.w),d1
	jsr off_B94E(pc,d1.w)
	lea (AniMotobug).l,a1
	bsr.w	ObjectAnimate

ObjectChkDespawn:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	bmi.w	loc_B938
	cmpi.w	#$280,d0
	bhi.w	loc_B938
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_B938:
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	beq.s	loc_B94A
	bclr	#7,2(a2,d0.w)

loc_B94A:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

off_B94E:   dc.w loc_B952-off_B94E, loc_B976-off_B94E
; ---------------------------------------------------------------------------

loc_B952:
	subq.w	#1,$30(a0)
	bpl.s	locret_B974
	addq.b	#2,subact(a0)
	move.w	#$FF00,xvel(a0)
	move.b	#1,ani(a0)
	bchg	#0,status(a0)
	bne.s	locret_B974
	neg.w	xvel(a0)

locret_B974:
	rts
; ---------------------------------------------------------------------------

loc_B976:
	bsr.w	ObjectMove
	bsr.w	ObjectHitFloor
	cmpi.w	#$FFF8,d1
	blt.s	loc_B9C0
	cmpi.w	#$C,d1
	bge.s	loc_B9C0
	add.w	d1,ypos(a0)
	subq.b	#1,$33(a0)
	bpl.s	locret_B9BE
	move.b	#$F,$33(a0)
	bsr.w	ObjectLoad
	bne.s	locret_B9BE
	move.b	#$40,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	status(a0),status(a1)
	move.b	#2,ani(a1)

locret_B9BE:
	rts
; ---------------------------------------------------------------------------

loc_B9C0:
	subq.b	#2,subact(a0)
	move.w	#$3B,$30(a0)
	move.w	#0,xvel(a0)
	move.b	#0,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_B9D8:
	lea (AniMotobug).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_B9E6:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/GHZ/Motobug/Sprite.ani"
	include "levels/GHZ/Motobug/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSpring:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_BAA0(pc,d0.w),d1
	jsr off_BAA0(pc,d1.w)
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_BAA0:   dc.w loc_BAB8-off_BAA0, sub_BB2E-off_BAA0, loc_BB84-off_BAA0, sub_BB8E-off_BAA0, sub_BB9A-off_BAA0
	dc.w loc_BC1C-off_BAA0, sub_BC26-off_BAA0, loc_BC32-off_BAA0, loc_BC98-off_BAA0, loc_BCA2-off_BAA0

word_BAB4:  dc.w -$1000, -$A00
; ---------------------------------------------------------------------------

loc_BAB8:
	addq.b	#2,act(a0)
	move.l	#MapSpring,4(a0)
	move.w	#$523,2(a0)
	ori.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$200,prio(a0)
	move.b	arg(a0),d0
	btst	#4,d0
	beq.s	loc_BB04
	move.b	#8,act(a0)
	move.b	#1,ani(a0)
	move.b	#3,frame(a0)
	move.w	#$533,2(a0)
	move.b	#8,xpix(a0)

loc_BB04:
	btst	#5,d0
	beq.s	loc_BB16
	move.b	#$E,act(a0)
	bset	#1,status(a0)

loc_BB16:
	btst	#1,d0
	beq.s	loc_BB22
	bset	#5,2(a0)

loc_BB22:
	andi.w	#$F,d0
	move.w	word_BAB4(pc,d0.w),$30(a0)
	rts
; ---------------------------------------------------------------------------

sub_BB2E:
	move.w	#$1B,d1
	move.w	#8,d2
	move.w	#$10,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	tst.b	subact(a0)
	bne.s	loc_BB4A
	rts
; ---------------------------------------------------------------------------

loc_BB4A:
	addq.b	#2,act(a0)
	addq.w	#8,ypos(a1)
	move.w	$30(a0),yvel(a1)
	bset	#1,status(a1)
	bclr	#3,status(a1)
	move.b	#$10,ani(a1)
	move.b	#2,act(a1)
	bclr	#3,status(a0)
	clr.b	subact(a0)
	sfx	sfx_Spring

loc_BB84:
	lea (AniSpring).l,a1
	bra.w	ObjectAnimate
; ---------------------------------------------------------------------------

sub_BB8E:
	move.b	#1,anilast(a0)
	subq.b	#4,act(a0)
	rts
; ---------------------------------------------------------------------------

sub_BB9A:
	move.w	#$13,d1
	move.w	#$E,d2
	move.w	#$F,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	cmpi.b	#2,act(a0)
	bne.s	loc_BBBC
	move.b	#8,act(a0)

loc_BBBC:
	btst	#5,status(a0)
	bne.s	loc_BBC6
	rts
; ---------------------------------------------------------------------------

loc_BBC6:
	addq.b	#2,act(a0)
	move.w	$30(a0),xvel(a1)
	addq.w	#8,xpos(a1)
	btst	#0,status(a0)
	bne.s	loc_BBE6
	subi.w	#$10,xpos(a1)
	neg.w	xvel(a1)

loc_BBE6:
	move.w	#$F,$3E(a1)
	move.w	xvel(a1),inertia(a1)
	bchg	#0,status(a1)
	btst	#2,status(a1)
	bne.s	loc_BC06
	move.b	#0,ani(a1)

loc_BC06:
	bclr	#5,status(a0)
	bclr	#5,status(a1)
	sfx	sfx_Spring

loc_BC1C:
	lea (AniSpring).l,a1
	bra.w	ObjectAnimate
; ---------------------------------------------------------------------------

sub_BC26:
	move.b	#2,anilast(a0)
	subq.b	#4,act(a0)
	rts
; ---------------------------------------------------------------------------

loc_BC32:
	move.w	#$1B,d1
	move.w	#8,d2
	move.w	#$10,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	cmpi.b	#2,act(a0)
	bne.s	loc_BC54
	move.b	#$E,act(a0)

loc_BC54:
	tst.b	subact(a0)
	bne.s	locret_BC5E
	tst.w	d4
	bmi.s	loc_BC60

locret_BC5E:
	rts
; ---------------------------------------------------------------------------

loc_BC60:
	addq.b	#2,act(a0)
	subq.w	#8,ypos(a1)
	move.w	$30(a0),yvel(a1)
	neg.w	yvel(a1)
	bset	#1,status(a1)
	bclr	#3,status(a1)
	move.b	#2,act(a1)
	bclr	#3,status(a0)
	clr.b	subact(a0)
	sfx	sfx_Spring

loc_BC98:
	lea (AniSpring).l,a1
	bra.w	ObjectAnimate
; ---------------------------------------------------------------------------

loc_BCA2:
	move.b	#1,anilast(a0)
	subq.b	#4,act(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Spring/Sprite.ani"
	include "levels/shared/Spring/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjNewtron:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_BD26(pc,d0.w),d1
	jmp off_BD26(pc,d1.w)
; ---------------------------------------------------------------------------

off_BD26:   dc.w loc_BD2C-off_BD26, loc_BD5C-off_BD26, loc_BEC6-off_BD26
; ---------------------------------------------------------------------------

loc_BD2C:
	addq.b	#2,act(a0)
	move.l	#MapNewtron,4(a0)
	move.w	#$249B,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$14,xpix(a0)
	move.b	#$10,yrad(a0)
	move.b	#8,xrad(a0)

loc_BD5C:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_BD78(pc,d0.w),d1
	jsr off_BD78(pc,d1.w)
	lea (AniNewtron).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_BD78:   dc.w loc_BD82-off_BD78, loc_BDC4-off_BD78, loc_BE38-off_BD78, loc_BE58-off_BD78, loc_BE5E-off_BD78
; ---------------------------------------------------------------------------

loc_BD82:
	bset	#0,status(a0)
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_BD9A
	neg.w	d0
	bclr	#0,status(a0)

loc_BD9A:
	cmpi.w	#$80,d0
	bcc.s	locret_BDC2
	addq.b	#2,subact(a0)
	move.b	#1,ani(a0)
	tst.b	arg(a0)
	beq.s	locret_BDC2
	move.w	#$49B,2(a0)
	move.b	#8,subact(a0)
	move.b	#4,ani(a0)

locret_BDC2:
	rts
; ---------------------------------------------------------------------------

loc_BDC4:
	cmpi.b	#4,frame(a0)
	bcc.s	loc_BDE4
	bset	#0,status(a0)
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	locret_BDE2
	bclr	#0,status(a0)

locret_BDE2:
	rts
; ---------------------------------------------------------------------------

loc_BDE4:
	cmpi.b	#1,frame(a0)
	bne.s	loc_BDF2
	move.b	#$C,col(a0)

loc_BDF2:
	bsr.w	ObjectFall
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_BE36
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,subact(a0)
	move.b	#2,ani(a0)
	btst	#5,2(a0)
	beq.s	loc_BE1E
	addq.b	#1,ani(a0)

loc_BE1E:
	move.b	#$D,col(a0)
	move.w	#$200,xvel(a0)
	btst	#0,status(a0)
	bne.s	locret_BE36
	neg.w	xvel(a0)

locret_BE36:
	rts
; ---------------------------------------------------------------------------

loc_BE38:
	bsr.w	ObjectMove

loc_BE3C:
	bsr.w	ObjectHitFloor
	cmpi.w	#$FFF8,d1
	blt.s	loc_BE52
	cmpi.w	#$C,d1
	bge.s	loc_BE52
	add.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_BE52:
	addq.b	#2,subact(a0)
	rts
; ---------------------------------------------------------------------------

loc_BE58:
	bsr.w	ObjectMove
	rts
; ---------------------------------------------------------------------------

loc_BE5E:
	cmpi.b	#1,frame(a0)
	bne.s	loc_BE6C
	move.b	#$C,col(a0)

loc_BE6C:
	cmpi.b	#2,frame(a0)
	bne.s	locret_BEC4
	tst.b	$32(a0)
	bne.s	locret_BEC4
	move.b	#1,$32(a0)
	bsr.w	ObjectLoad
	bne.s	locret_BEC4
	move.b	#$23,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	subq.w	#8,ypos(a1)
	move.w	#$200,xvel(a1)
	move.w	#$14,d0
	btst	#0,status(a0)
	bne.s	loc_BEB4
	neg.w	d0
	neg.w	xvel(a1)

loc_BEB4:
	add.w	d0,xpos(a1)
	move.b	status(a0),status(a1)
	move.b	#1,arg(a1)

locret_BEC4:
	rts
; ---------------------------------------------------------------------------

loc_BEC6:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/GHZ/Newtron/Sprite.ani"
	include "levels/GHZ/Newtron/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjRoller:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_BFB8(pc,d0.w),d1
	jmp off_BFB8(pc,d1.w)
; ---------------------------------------------------------------------------

off_BFB8:   dc.w loc_BFBE-off_BFB8, loc_C00C-off_BFB8, loc_C0B0-off_BFB8
; ---------------------------------------------------------------------------

loc_BFBE:
	move.b	#$E,yrad(a0)
	move.b	#8,xrad(a0)
	bsr.w	ObjectFall
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_C00A
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,act(a0)
	move.l	#MapRoller,4(a0)
	move.w	#$24B8,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$10,xpix(a0)
	move.b	#$8E,col(a0)

locret_C00A:
	rts
; ---------------------------------------------------------------------------

loc_C00C:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_C028(pc,d0.w),d1
	jsr off_C028(pc,d1.w)
	lea (AniRoller).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_C028:   dc.w loc_C030-off_C028, loc_C052-off_C028, loc_C060-off_C028, loc_C08E-off_C028
; ---------------------------------------------------------------------------

loc_C030:
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcs.s	locret_C050
	cmpi.w	#$20,d0
	bcc.s	locret_C050
	addq.b	#2,subact(a0)
	move.b	#1,ani(a0)
	move.w	#$400,xvel(a0)

locret_C050:
	rts
; ---------------------------------------------------------------------------

loc_C052:
	cmpi.b	#2,ani(a0)
	bne.s	locret_C05E
	addq.b	#2,subact(a0)

locret_C05E:
	rts
; ---------------------------------------------------------------------------

loc_C060:
	bsr.w	ObjectMove
	bsr.w	ObjectHitFloor
	cmpi.w	#$FFF8,d1
	blt.s	loc_C07A
	cmpi.w	#$C,d1
	bge.s	loc_C07A
	add.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_C07A:
	addq.b	#2,subact(a0)
	bset	#0,$32(a0)
	beq.s	locret_C08C
	move.w	#$FA00,yvel(a0)

locret_C08C:
	rts
; ---------------------------------------------------------------------------

loc_C08E:
	bsr.w	ObjectFall
	tst.w	yvel(a0)
	bmi.s	locret_C0AE
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_C0AE
	add.w	d1,ypos(a0)
	subq.b	#2,subact(a0)

loc_C0A8:
	move.w	#0,yvel(a0)

locret_C0AE:
	rts
; ---------------------------------------------------------------------------

loc_C0B0:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/shared/Roller/Sprite.ani"
	even
	include "levels/shared/Roller/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjWall:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C10A(pc,d0.w),d1
	jmp off_C10A(pc,d1.w)
; ---------------------------------------------------------------------------

off_C10A:   dc.w loc_C110-off_C10A, loc_C148-off_C10A, loc_C154-off_C10A
; ---------------------------------------------------------------------------

loc_C110:
	addq.b	#2,act(a0)
	move.l	#MapWall,map(a0)
	move.w	#$434C,tile(a0)
	ori.b	#4,render(a0)
	move.b	#8,xpix(a0)
	move.w	#$300,prio(a0)
	move.b	arg(a0),frame(a0)
	bclr	#4,frame(a0)
	beq.s	loc_C148
	addq.b	#2,act(a0)
	bra.s	loc_C154
; ---------------------------------------------------------------------------

loc_C148:
	move.w	#$13,d1
	move.w	#$28,d2
	bsr.w	sub_6936

loc_C154:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/GHZ/Wall/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjLavaMaker:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C1D0(pc,d0.w),d1
	jsr off_C1D0(pc,d1.w)
	bra.w	loc_C2E6
; ---------------------------------------------------------------------------

off_C1D0:   dc.w loc_C1DA-off_C1D0, loc_C1FA-off_C1D0

byte_C1D4:  dc.b $1E, $3C, $5A, $78, $96, $B4
; ---------------------------------------------------------------------------

loc_C1DA:
	addq.b	#2,act(a0)
	move.b	arg(a0),d0
	lsr.w	#4,d0
	andi.w	#$F,d0
	move.b	byte_C1D4(pc,d0.w),storedframe(a0)
	move.b	storedframe(a0),anidelay(a0)
	andi.b	#$F,arg(a0)

loc_C1FA:
	subq.b	#1,anidelay(a0)
	bne.s	locret_C22A
	move.b	storedframe(a0),anidelay(a0)
	bsr.w	ObjectChkOffscreen
	bne.s	locret_C22A
	bsr.w	ObjectLoad
	bne.s	locret_C22A
	move.b	#$14,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	arg(a0),arg(a1)

locret_C22A:
	rts
; ---------------------------------------------------------------------------

ObjLavaball:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C23E(pc,d0.w),d1
	jsr off_C23E(pc,d1.w)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_C23E:   dc.w loc_C254-off_C23E, loc_C2C8-off_C23E, j_ObjectDelete-off_C23E

word_C244:  dc.w $FC00, $FB00, $FA00, $F900, $FE00, $200, $FE00, $200
; ---------------------------------------------------------------------------

loc_C254:
	addq.b	#2,act(a0)
	move.b	#8,yrad(a0)
	move.b	#8,xrad(a0)
	move.l	#MapLavaball,map(a0)
	move.w	#$345,tile(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$8B,col(a0)
	move.w	ypos(a0),$30(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	word_C244(pc,d0.w),yvel(a0)
	move.b	#8,xpix(a0)
	cmpi.b	#6,arg(a0)
	bcs.s	loc_C2BE
	move.b	#$10,xpix(a0)
	move.b	#2,ani(a0)
	move.w	yvel(a0),xvel(a0)
	move.w	#0,yvel(a0)

loc_C2BE:
	sfx	sfx_LavaBall
	
loc_C2C8:
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	off_C306(pc,d0.w),d1
	jsr off_C306(pc,d1.w)
	bsr.w	ObjectMove
	lea (AniLavaball).l,a1
	bsr.w	ObjectAnimate

loc_C2E6:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#640,d0
	bhi.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------

off_C306:   dc.w loc_C318-off_C306, loc_C318-off_C306, loc_C318-off_C306, loc_C318-off_C306, loc_C340-off_C306
	dc.w loc_C362-off_C306, loc_C384-off_C306, loc_C3A8-off_C306, locret_C3CC-off_C306
; ---------------------------------------------------------------------------

loc_C318:
	addi.w	#$18,yvel(a0)
	move.w	$30(a0),d0
	cmp.w	ypos(a0),d0
	bcc.s	loc_C32C
	addq.b	#2,act(a0)

loc_C32C:
	bclr	#1,status(a0)
	tst.w	yvel(a0)
	bpl.s	locret_C33E
	bset	#1,status(a0)

locret_C33E:
	rts
; ---------------------------------------------------------------------------

loc_C340:
	bset	#1,status(a0)
	bsr.w	ObjectHitCeiling
	tst.w	d1
	bpl.s	locret_C360
	move.b	#8,arg(a0)
	move.b	#1,ani(a0)
	move.w	#0,yvel(a0)

locret_C360:
	rts
; ---------------------------------------------------------------------------

loc_C362:
	bclr	#1,status(a0)
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_C382
	move.b	#8,arg(a0)
	move.b	#1,ani(a0)
	move.w	#0,yvel(a0)

locret_C382:
	rts
; ---------------------------------------------------------------------------

loc_C384:
	bset	#0,status(a0)
	moveq	#-8,d3
	bsr.w	ObjectHitWallLeft
	tst.w	d1
	bpl.s	locret_C3A6
	move.b	#8,arg(a0)
	move.b	#3,ani(a0)
	move.w	#0,xvel(a0)

locret_C3A6:
	rts
; ---------------------------------------------------------------------------

loc_C3A8:
	bclr	#0,status(a0)
	moveq	#8,d3
	bsr.w	ObjectHitWallRight
	tst.w	d1
	bpl.s	locret_C3CA
	move.b	#8,arg(a0)
	move.b	#3,ani(a0)
	move.w	#0,xvel(a0)
; ---------------------------------------------------------------------------

locret_C3CA:
locret_C3CC:
	rts
; ---------------------------------------------------------------------------
; Attributes: thunk

j_ObjectDelete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------
	include "levels/MZ/LavaBall/Sprite.ani"
	even
; ---------------------------------------------------------------------------

ObjMZBlocks:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C3FC(pc,d0.w),d1
	jmp off_C3FC(pc,d1.w)
; ---------------------------------------------------------------------------

off_C3FC:   dc.w loc_C400-off_C3FC, loc_C43C-off_C3FC
; ---------------------------------------------------------------------------

loc_C400:
	addq.b	#2,act(a0)
	move.b	#$F,yrad(a0)
	move.b	#$F,xrad(a0)
	move.l	#MapMZBlocks,4(a0)
	move.w	#$4000,2(a0)
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	move.b	#$10,xpix(a0)
	move.w	ypos(a0),$30(a0)
	move.w	#$5C0,$32(a0)

loc_C43C:
	tst.b	render(a0)
	bpl.s	loc_C46A
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#7,d0
	add.w	d0,d0
	move.w	off_C48E(pc,d0.w),d1
	jsr off_C48E(pc,d1.w)
	move.w	#$1B,d1
	move.w	#$10,d2
	move.w	#$11,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC

loc_C46A:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_C48E:   dc.w locret_C498-off_C48E, loc_C4B2-off_C48E, loc_C49A-off_C48E, loc_C4D2-off_C48E
	dc.w loc_C50E-off_C48E
; ---------------------------------------------------------------------------

locret_C498:
	rts
; ---------------------------------------------------------------------------

loc_C49A:
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_C4A6
	neg.w	d0

loc_C4A6:
	cmpi.w	#$90,d0
	bcc.s	loc_C4B2
	move.b	#3,arg(a0)

loc_C4B2:
	moveq	#0,d0
	move.b	(oscValues+$16).w,d0
	btst	#3,arg(a0)
	beq.s	loc_C4C6
	neg.w	d0
	addi.w	#$10,d0

loc_C4C6:
	move.w	$30(a0),d1
	sub.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_C4D2:
	bsr.w	ObjectMove
	addi.w	#$18*2,yvel(a0)
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.w	locret_C50C
	add.w	d1,ypos(a0)
	clr.w	yvel(a0)
	move.w	ypos(a0),$30(a0)
	move.b	#4,arg(a0)
	move.w	(a1),d0
	andi.w	#$3FF,d0
	cmpi.w	#$2E8,d0
	bcc.s	locret_C50C
	move.b	#0,arg(a0)

locret_C50C:
	rts
; ---------------------------------------------------------------------------

loc_C50E:
	moveq	#0,d0

loc_C510:
	move.b	(oscValues+$12).w,d0
	lsr.w	#3,d0
	move.w	$30(a0),d1
	sub.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/MZ/Blocks/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSceneryLamp:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C538(pc,d0.w),d1
	jmp off_C538(pc,d1.w)
; ---------------------------------------------------------------------------

off_C538:   dc.w loc_C53C-off_C538, loc_C560-off_C538
; ---------------------------------------------------------------------------

loc_C53C:
	addq.b	#2,act(a0)
	move.l	#MapSceneryLamp,4(a0)
	move.w	#0,2(a0)
	move.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$300,prio(a0)

loc_C560:
	subq.b	#1,anidelay(a0)
	bpl.s	loc_C57E
	move.b	#7,anidelay(a0)
	addq.b	#1,frame(a0)
	cmpi.b	#6,frame(a0)
	bcs.s	loc_C57E
	move.b	#0,frame(a0)

loc_C57E:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/SYZ/SceneryLamp/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjBumper:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C5FE(pc,d0.w),d1
	jmp off_C5FE(pc,d1.w)
; ---------------------------------------------------------------------------

off_C5FE:   dc.w loc_C602-off_C5FE, loc_C62C-off_C5FE
; ---------------------------------------------------------------------------

loc_C602:
	addq.b	#2,act(a0)
	move.l	#MapBumper,4(a0)
	move.w	#$380,2(a0)
	move.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$80,prio(a0)
	move.b	#$D7,col(a0)

loc_C62C:
	tst.b	colprop(a0)
	beq.s	loc_C684
	clr.b	colprop(a0)
	lea (ObjectsList).w,a1
	move.w	xpos(a0),d1
	move.w	ypos(a0),d2
	sub.w	xpos(a1),d1
	sub.w	ypos(a1),d2
	jsr (GetAngle).l
	jsr (GetSine).l
	muls.w	#$F900,d1
	asr.l	#8,d1
	move.w	d1,xvel(a1)
	muls.w	#$F900,d0
	asr.l	#8,d0
	move.w	d0,yvel(a1)
	bset	#1,status(a1)
	clr.b	$3C(a1)
	move.b	#1,ani(a0)
	sfx	sfx_Bumper

loc_C684:
	lea (AniBumper).l,a1
	bsr.w	ObjectAnimate
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0

loc_C6A8:
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/SYZ/Bumper/Sprite.ani"
	even
	include "levels/SYZ/Bumper/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSignpost:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C726(pc,d0.w),d1
	jsr off_C726(pc,d1.w)
	lea (AniSignpost).l,a1
	bsr.w	ObjectAnimate
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_C726:   dc.w loc_C72E-off_C726, loc_C752-off_C726, loc_C77C-off_C726, loc_C814-off_C726
; ---------------------------------------------------------------------------

loc_C72E:
	addq.b	#2,act(a0)
	move.l	#MapSignpost,4(a0)
	move.w	#$680,2(a0)
	move.b	#4,render(a0)
	move.b	#$18,xpix(a0)
	move.w	#$200,prio(a0)

loc_C752:
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcs.s	locret_C77A
	cmpi.w	#$20,d0
	bcc.s	locret_C77A
	sfx	sfx_Signpost
	clr.b	(byte_FFFE1E).w
	move.w	(unk_FFF72A).w,(unk_FFF728).w
	addq.b	#2,act(a0)

locret_C77A:
	rts
; ---------------------------------------------------------------------------

loc_C77C:
	subq.w	#1,$30(a0)
	bpl.s	loc_C798
	move.w	#$3C,$30(a0)
	addq.b	#1,ani(a0)
	cmpi.b	#3,ani(a0)
	bne.s	loc_C798
	addq.b	#2,act(a0)

loc_C798:
	subq.w	#1,$32(a0)
	bpl.s	locret_C802
	move.w	#$B,$32(a0)
	moveq	#0,d0
	move.b	$34(a0),d0
	addq.b	#2,$34(a0)
	andi.b	#$E,$34(a0)
	lea byte_C804(pc,d0.w),a2
	bsr.w	ObjectLoad
	bne.s	locret_C802
	move.b	#$25,id(a1)
	move.b	#6,act(a1)
	move.b	(a2)+,d0
	ext.w	d0
	add.w	xpos(a0),d0
	move.w	d0,xpos(a1)
	move.b	(a2)+,d0
	ext.w	d0
	add.w	ypos(a0),d0
	move.w	d0,ypos(a1)
	move.l	#MapRing,4(a1)
	move.w	#$27B2,2(a1)
	move.b	#4,render(a1)
	move.w	#$100,prio(a1)
	move.b	#8,xpix(a1)

locret_C802:
	rts
; ---------------------------------------------------------------------------

byte_C804:  dc.b $E8, $F0
	dc.b 8, 8
	dc.b $F0, 0
	dc.b $18, $F8
	dc.b 0, $F8
	dc.b $10, 0
	dc.b $E8, 8
	dc.b $18, $10
; ---------------------------------------------------------------------------

loc_C814:
	tst.w	(DebugRoutine).w
	bne.w	locret_C880
; ---------------------------------------------------------------------------

sub_C81C:
	tst.b	(byte_FFD600).w
	bne.w	locret_C880
	move.w	(unk_FFF72A).w,(unk_FFF728).w
	clr.b	(byte_FFFE2D).w
	clr.b	(byte_FFFE2C).w
	clr.b	(byte_FFFE1E).w
	move.b	#$3A,(byte_FFD600).w
	move.l	a0,-(sp)
	move.l	#$70000002,($C00004).l
	lea ArtTitleCards,a0
	move.l	#((ArtTitleCards_End-ArtTitleCards)/32)-1,d0
	jsr LoadUncArt
	move.l	(sp)+,a0
	st.b	(byte_FFFE58).w
	moveq	#0,d0
	move.b	(dword_FFFE22+1).w,d0
	mulu.w	#$3C,d0
	moveq	#0,d1
	move.b	(dword_FFFE22+2).w,d1
	add.w	d1,d0
	divu.w	#$F,d0
	moveq	#$14,d1
	cmp.w	d1,d0
	bcs.s	loc_C862
	move.w	d1,d0

loc_C862:
	add.w	d0,d0
	move.w	word_C882(pc,d0.w),(word_FFFE54).w
	move.w	(Rings).w,d0
	mulu.w	#$A,d0
	move.w	d0,(word_FFFE56).w
	music	mus_GotThroughAct, 0

locret_C880:
	rts
; ---------------------------------------------------------------------------

word_C882:  dc.w $1388, $3E8, $1F4, $190, $12C, $12C, $C8, $C8, $64
	dc.w $64, $64, $64, $32, $32, $32, $32, $A, $A, $A, $A
	dc.w 0
	include "levels/shared/Signpost/Sprite.ani"
	include "levels/shared/Signpost/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjLavafallMalker:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_C926(pc,d0.w),d1
	jsr off_C926(pc,d1.w)
	bra.w	loc_CB28
; ---------------------------------------------------------------------------

off_C926:   dc.w loc_C932-off_C926, loc_C95C-off_C926, loc_C9CE-off_C926, loc_C982-off_C926, loc_C9DA-off_C926
	dc.w loc_C9EA-off_C926
; ---------------------------------------------------------------------------

loc_C932:
	addq.b	#2,act(a0)
	move.l	#MapLavafall,4(a0)
	move.w	#$E3A8,2(a0)
	move.b	#4,render(a0)
	move.w	#$80,prio(a0)
	move.b	#$38,xpix(a0)
	move.w	#$78,$34(a0)

loc_C95C:
	subq.w	#1,$32(a0)
	bpl.s	locret_C980
	move.w	$34(a0),$32(a0)
	move.w	(ObjectsList+$C).w,d0
	move.w	ypos(a0),d1
	cmp.w	d1,d0
	bcc.s	locret_C980
	subi.w	#$170,d1
	cmp.w	d1,d0
	bcs.s	locret_C980
	addq.b	#2,act(a0)

locret_C980:
	rts
; ---------------------------------------------------------------------------

loc_C982:
	addq.b	#2,act(a0)
	bsr.w	LoadNextObject
	bne.s	loc_C9A8
	move.b	#$4D,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	arg(a0),arg(a1)
	move.l	a0,$3C(a1)

loc_C9A8:
	move.b	#1,ani(a0)
	tst.b	arg(a0)
	beq.s	loc_C9BC
	move.b	#4,ani(a0)
	bra.s	loc_C9DA
; ---------------------------------------------------------------------------

loc_C9BC:
	movea.l $3C(a0),a1
	bset	#1,status(a1)
	move.w	#$FA80,yvel(a1)
	bra.s	loc_C9DA
; ---------------------------------------------------------------------------

loc_C9CE:
	tst.b	arg(a0)
	beq.s	loc_C9DA
	addq.b	#2,act(a0)
	rts
; ---------------------------------------------------------------------------

loc_C9DA:
	lea (AniLavaFallMaker).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_C9EA:
	move.b	#0,ani(a0)
	move.b	#2,act(a0)
	tst.b	arg(a0)
	beq.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------

ObjLavafall:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_CA12(pc,d0.w),d1
	jsr off_CA12(pc,d1.w)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_CA12:   dc.w loc_CA1E-off_CA12, loc_CB0A-off_CA12, sub_CB8C-off_CA12, loc_CBEA-off_CA12

word_CA1A:  dc.w $FB00, 0
; ---------------------------------------------------------------------------

loc_CA1E:
	addq.b	#2,act(a0)
	move.w	ypos(a0),$30(a0)
	tst.b	arg(a0)
	beq.s	loc_CA34
	subi.w	#$250,ypos(a0)

loc_CA34:
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	word_CA1A(pc,d0.w),yvel(a0)
	movea.l a0,a1
	moveq	#1,d1
	bsr.s	sub_CA50
	bra.s	loc_CAA0
; ---------------------------------------------------------------------------

sub_CA4A:
	bsr.w	LoadNextObject
	bne.s	loc_CA9A
; ---------------------------------------------------------------------------

sub_CA50:
	move.b	#$4D,id(a1)
	move.l	#MapLavafall,4(a1)
	move.w	#$63A8,2(a1)
	move.b	#4,render(a1)
	move.b	#$20,xpix(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	arg(a0),arg(a1)
	move.w	#$80,prio(a1)
	move.b	#5,ani(a1)
	tst.b	arg(a0)
	beq.s	loc_CA9A
	move.b	#2,ani(a1)

loc_CA9A:
	dbf d1,sub_CA4A
	rts
; ---------------------------------------------------------------------------

loc_CAA0:
	addi.w	#$60,ypos(a1)
	move.w	$30(a0),$30(a1)
	addi.w	#$60,$30(a1)
	move.b	#$93,col(a1)
	move.b	#$80,yrad(a1)
	bset	#4,render(a1)
	addq.b	#4,act(a1)
	move.l	a0,$3C(a1)
	tst.b	arg(a0)
	beq.s	loc_CB00
	moveq	#0,d1
	bsr.w	sub_CA4A
	addq.b	#2,act(a1)
	bset	#4,2(a1)
	addi.w	#$100,ypos(a1)
	move.w	#0,prio(a1)
	move.w	$30(a0),$30(a1)
	move.l	$3C(a0),$3C(a1)
	move.b	#0,arg(a0)

loc_CB00:
	sfx	sfx_Lava

loc_CB0A:
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	move.w	off_CB48(pc,d0.w),d1
	jsr off_CB48(pc,d1.w)
	bsr.w	ObjectMove
	lea (AniLavaFallMaker).l,a1
	bsr.w	ObjectAnimate

loc_CB28:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------

off_CB48:   dc.w loc_CB4C-off_CB48, loc_CB6C-off_CB48
; ---------------------------------------------------------------------------

loc_CB4C:
	addi.w	#$18,yvel(a0)
	move.w	$30(a0),d0
	cmp.w	ypos(a0),d0
	bcc.s	locret_CB6A
	addq.b	#4,act(a0)
	movea.l $3C(a0),a1
	move.b	#3,ani(a1)

locret_CB6A:
	rts
; ---------------------------------------------------------------------------

loc_CB6C:
	addi.w	#$18,yvel(a0)
	move.w	$30(a0),d0
	cmp.w	ypos(a0),d0
	bcc.s	locret_CB8A
	addq.b	#4,act(a0)
	movea.l $3C(a0),a1
	move.b	#1,ani(a1)

locret_CB8A:
	rts
; ---------------------------------------------------------------------------

sub_CB8C:
	movea.l $3C(a0),a1
	cmpi.b	#6,act(a1)
	beq.w	loc_CBEA
	move.w	ypos(a1),d0
	addi.w	#$60,d0
	move.w	d0,ypos(a0)
	sub.w	$30(a0),d0
	neg.w	d0
	moveq	#8,d1
	cmpi.w	#$40,d0
	bge.s	loc_CBB6
	moveq	#$B,d1

loc_CBB6:
	cmpi.w	#$80,d0
	ble.s	loc_CBBE
	moveq	#$E,d1

loc_CBBE:
	subq.b	#1,anidelay(a0)
	bpl.s	loc_CBDC
	move.b	#7,anidelay(a0)
	addq.b	#1,anipos(a0)
	cmpi.b	#2,anipos(a0)
	bcs.s	loc_CBDC
	move.b	#0,anipos(a0)

loc_CBDC:
	move.b	anipos(a0),d0
	add.b	d1,d0
	move.b	d0,frame(a0)
	bra.w	loc_CB28
; ---------------------------------------------------------------------------

loc_CBEA:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjLavaChase:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_CBFC(pc,d0.w),d1
	jmp off_CBFC(pc,d1.w)
; ---------------------------------------------------------------------------

off_CBFC:   dc.w loc_CC06-off_CBFC, loc_CC66-off_CBFC, loc_CCA2-off_CBFC, loc_CD00-off_CBFC, loc_CD1C-off_CBFC
; ---------------------------------------------------------------------------

loc_CC06:
	addq.b	#2,act(a0)
	movea.l a0,a1
	moveq	#1,d1
	bra.s	loc_CC16
; ---------------------------------------------------------------------------

loc_CC10:
	bsr.w	LoadNextObject
	bne.s	loc_CC58

loc_CC16:
	move.b	#$4E,id(a1)
	move.l	#MapLavaChase,4(a1)
	move.w	#$63A8,2(a1)
	move.b	#4,render(a1)
	move.b	#$50,xpix(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.w	#$80,prio(a1)
	move.b	#0,ani(a1)
	move.b	#$94,col(a1)
	move.l	a0,$3C(a1)

loc_CC58:
	dbf d1,loc_CC10
	addq.b	#6,act(a1)
	move.b	#4,frame(a1)

loc_CC66:
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_CC72
	neg.w	d0

loc_CC72:
	cmpi.w	#$E0,d0
	bcc.s	loc_CC92
	move.w	(ObjectsList+$C).w,d0
	sub.w	ypos(a0),d0
	bcc.s	loc_CC84
	neg.w	d0

loc_CC84:
	cmpi.w	#$60,d0
	bcc.s	loc_CC92
	move.b	#1,sensorfront(a0)
	bra.s	loc_CCA2
; ---------------------------------------------------------------------------

loc_CC92:
	tst.b	sensorfront(a0)
	beq.s	loc_CCA2
	move.w	#$100,xvel(a0)
	addq.b	#2,act(a0)

loc_CCA2:
	cmpi.w	#$6A0,xpos(a0)
	bne.s	loc_CCB2
	clr.w	xvel(a0)
	clr.b	sensorfront(a0)

loc_CCB2:
	lea (AniLavaChase).l,a1
	bsr.w	ObjectAnimate
	bsr.w	ObjectMove
	tst.b	sensorfront(a0)
	bne.s	locret_CCE6
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.s	loc_CCE8
	bra.w	ObjectDisplay

locret_CCE6:
	rts
; ---------------------------------------------------------------------------

loc_CCE8:
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	bclr	#7,2(a2,d0.w)
	move.b	#8,act(a0)
	rts
; ---------------------------------------------------------------------------

loc_CD00:
	movea.l $3C(a0),a1
	cmpi.b	#8,act(a1)
	beq.s	loc_CD1C
	move.w	xpos(a1),xpos(a0)
	subi.w	#$80,xpos(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

loc_CD1C:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjLavaHurt:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_CD2E(pc,d0.w),d1
	jmp off_CD2E(pc,d1.w)
; ---------------------------------------------------------------------------

off_CD2E:   dc.w loc_CD36-off_CD2E, loc_CD6C-off_CD2E

byte_CD32:  dc.b $96, $94, $95, 0
; ---------------------------------------------------------------------------

loc_CD36:
	addq.b	#2,act(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	move.b	byte_CD32(pc,d0.w),col(a0)
	move.l	#MapLavaHurt,4(a0)
	move.w	#$8680,2(a0)
	move.b	#4,render(a0)
	move.b	#$80,xpix(a0)
	move.w	#$200,prio(a0)
	move.b	arg(a0),frame(a0)

loc_CD6C:
	tst.w	(DebugRoutine).w
	beq.s	loc_CD76
	bsr.w	ObjectDisplay

loc_CD76:
	cmpi.b	#6,(ObjectsList+$24).w
	bcc.s	loc_CD84
	bset	#7,render(a0)

loc_CD84:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	bmi.w	ObjectDelete
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------
	include "levels/MZ/LavaHurt/Sprite.map"
	include "levels/MZ/LavaFall/Maker.ani"
	include "levels/MZ/LavaChase/Sprite.ani"
	include "levels/MZ/LavaFall/Sprite.map"
	include "levels/MZ/LavaChase/Sprite.map"
	even
; ---------------------------------------------------------------------------

Obj4F:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_D202(pc,d0.w),d1
	jmp off_D202(pc,d1.w)
; ---------------------------------------------------------------------------

off_D202:   dc.w loc_D20A-off_D202, loc_D246-off_D202, loc_D274-off_D202, loc_D2C8-off_D202
; ---------------------------------------------------------------------------

loc_D20A:
	addq.b	#2,act(a0)
	move.l	#Map4F,map(a0)
	move.w	#$24E4,tile(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$C,xpix(a0)
	move.b	#$14,yrad(a0)
	move.b	#2,col(a0)
	tst.b	arg(a0)
	beq.s	loc_D246
	move.w	#$300,d2
	bra.s	loc_D24A
; ---------------------------------------------------------------------------

loc_D246:
	move.w	#$E0,d2

loc_D24A:
	move.w	#$100,d1
	bset	#0,render(a0)
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_D268
	neg.w	d0
	neg.w	d1
	bclr	#0,render(a0)

loc_D268:
	cmp.w	d2,d0
	bcc.s	loc_D274
	move.w	d1,xvel(a0)
	addq.b	#2,act(a0)

loc_D274:
	bsr.w	ObjectFall
	move.b	#1,frame(a0)
	tst.w	yvel(a0)
	bmi.s	loc_D2AE
	move.b	#0,frame(a0)
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	loc_D2AE
	move.w	(a1),d0
	andi.w	#$3FF,d0
	cmpi.w	#$2D2,d0
	bcs.s	loc_D2A4
	addq.b	#2,act(a0)
	bra.s	loc_D2AE
; ---------------------------------------------------------------------------

loc_D2A4:
	add.w	d1,ypos(a0)
	move.w	#-$400,yvel(a0)
	sfx	sfx_UnkB8

loc_D2AE:
	bsr.w	sub_D2DA
	beq.s	loc_D2C4
	neg.w	xvel(a0)
	bchg	#0,render(a0)
	bchg	#0,status(a0)

loc_D2C4:
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

loc_D2C8:
	bsr.w	ObjectFall
	tst.b	render(a0)
	bpl.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

sub_D2DA:
	move.w	(LevelFrames).w,d0
	add.w	d7,d0
	andi.w	#3,d0
	bne.s	loc_D308
	moveq	#0,d3
	move.b	xpix(a0),d3
	tst.w	xvel(a0)
	bmi.s	loc_D2FE
	bsr.w	ObjectHitWallRight
	tst.w	d1
	bpl.s	loc_D308

loc_D2FA:
	moveq	#1,d0
	rts
; ---------------------------------------------------------------------------

loc_D2FE:
	not.w	d3
	bsr.w	ObjectHitWallLeft
	tst.w	d1
	bmi.s	loc_D2FA

loc_D308:
	moveq	#0,d0
	rts
; ---------------------------------------------------------------------------
	include "unknown/Map4F.map"
	even
; ---------------------------------------------------------------------------

ObjYadrin:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_D334(pc,d0.w),d1
	jmp off_D334(pc,d1.w)
; ---------------------------------------------------------------------------

off_D334:   dc.w loc_D338-off_D334, loc_D38C-off_D334
; ---------------------------------------------------------------------------

loc_D338:
	move.l	#MapYadrin,4(a0)
	move.w	#$247B,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$14,xpix(a0)
	move.b	#$11,yrad(a0)
	move.b	#8,xrad(a0)
	move.b	#$CC,col(a0)
	bsr.w	ObjectFall
	bsr.w	ObjectHitFloor
	tst.w	d1
	bpl.s	locret_D38A
	add.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	addq.b	#2,act(a0)
	bchg	#0,status(a0)

locret_D38A:
	rts
; ---------------------------------------------------------------------------

loc_D38C:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	off_D3A8(pc,d0.w),d1
	jsr off_D3A8(pc,d1.w)
	lea (AniYardin).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_D3A8:   dc.w loc_D3AC-off_D3A8, loc_D3D0-off_D3A8
; ---------------------------------------------------------------------------

loc_D3AC:
	subq.w	#1,$30(a0)
	bpl.s	locret_D3CE
	addq.b	#2,subact(a0)
	move.w	#$FF00,xvel(a0)
	move.b	#1,ani(a0)
	bchg	#0,status(a0)
	bne.s	locret_D3CE
	neg.w	xvel(a0)

locret_D3CE:
	rts
; ---------------------------------------------------------------------------

loc_D3D0:
	bsr.w	ObjectMove
	bsr.w	ObjectHitFloor
	cmpi.w	#$FFF8,d1
	blt.s	loc_D3F0
	cmpi.w	#$C,d1
	bge.s	loc_D3F0
	add.w	d1,ypos(a0)
	bsr.w	sub_D2DA
	bne.s	loc_D3F0
	rts
; ---------------------------------------------------------------------------

loc_D3F0:
	subq.b	#2,subact(a0)
	move.w	#$3B,$30(a0)
	move.w	#0,xvel(a0)
	move.b	#0,ani(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Yadrin/Sprite.ani"
	include "levels/shared/Yadrin/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSmashBlock:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_D4D4(pc,d0.w),d1
	jsr off_D4D4(pc,d1.w)
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_D4D4:   dc.w loc_D4DA-off_D4D4, loc_D504-off_D4D4, loc_D580-off_D4D4
; ---------------------------------------------------------------------------

loc_D4DA:
	addq.b	#2,act(a0)
	move.l	#MapSmashBlock,4(a0)
	move.w	#$42B8,2(a0)
	move.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$200,prio(a0)
	move.b	arg(a0),frame(a0)

loc_D504:
	move.b	(ObjectsList+$1C).w,$32(a0)
	move.w	#$1B,d1
	move.w	#$10,d2
	move.w	#$11,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	btst	#3,status(a0)
	bne.s	loc_D528

locret_D526:
	rts
; ---------------------------------------------------------------------------

loc_D528:
	cmpi.b	#2,$32(a0)
	bne.s	locret_D526
	bset	#2,status(a1)
	move.b	#$E,yrad(a1)
	move.b	#7,xrad(a1)
	move.b	#2,ani(a1)
	move.w	#$FD00,yvel(a1)
	bset	#1,status(a1)
	bclr	#3,status(a1)
	move.b	#2,act(a1)
	bclr	#3,status(a0)
	clr.b	subact(a0)
	move.b	#1,frame(a0)
	lea (ObjSmashBlock_Frag).l,a4
	moveq	#3,d1
	move.w	#$38,d2
	bsr.w	ObjectFragment

loc_D580:
	bsr.w	ObjectMove
	addi.w	#$38,yvel(a0)
	tst.b	render(a0)
	bpl.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjSmashBlock_Frag:dc.w $FE00, $FE00, $FF00, $FF00, $200, $FE00, $100, $FF00
	include "levels/GHZ/SmashBlock/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjMovingPtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_D5FC(pc,d0.w),d1
	jsr off_D5FC(pc,d1.w)
	move.w	$32(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_D5FC:   dc.w loc_D606-off_D5FC, loc_D648-off_D5FC, loc_D658-off_D5FC

byte_D602:  dc.b $10, 0
	dc.b $20, 1
; ---------------------------------------------------------------------------

loc_D606:
	addq.b	#2,act(a0)
	move.l	#MapMovingPtfm,4(a0)
	move.w	#$42B8,2(a0)
	move.b	#4,render(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	lsr.w	#3,d0
	andi.w	#$1E,d0
	lea byte_D602(pc,d0.w),a2
	move.b	(a2)+,xpix(a0)
	move.b	(a2)+,frame(a0)
	move.w	#$200,prio(a0)
	move.w	xpos(a0),$32(a0)
	move.w	ypos(a0),$30(a0)

loc_D648:
	moveq	#0,d1
	move.b	xpix(a0),d1
	jsr (PtfmNormal).l
	bra.w	sub_D674
; ---------------------------------------------------------------------------

loc_D658:
	moveq	#0,d1
	move.b	xpix(a0),d1
	jsr (PtfmCheckExit).l
	move.w	xpos(a0),-(sp)
	bsr.w	sub_D674
	move.w	(sp)+,d2
	jmp (ptfmSurfaceNormal).l
; ---------------------------------------------------------------------------

sub_D674:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#$F,d0
	add.w	d0,d0
	move.w	off_D688(pc,d0.w),d1
	jmp off_D688(pc,d1.w)
; ---------------------------------------------------------------------------

off_D688:   dc.w locret_D690-off_D688, loc_D692-off_D688, loc_D6B2-off_D688, loc_D6C0-off_D688
; ---------------------------------------------------------------------------

locret_D690:
	rts
; ---------------------------------------------------------------------------

loc_D692:
	move.b	(oscValues+$E).w,d0
	subi.b	#$60,d1
	btst	#0,status(a0)
	beq.s	loc_D6A6
	neg.w	d0
	add.w	d1,d0

loc_D6A6:
	move.w	$32(a0),d1
	sub.w	d0,d1
	move.w	d1,xpos(a0)
	rts
; ---------------------------------------------------------------------------

loc_D6B2:
	cmpi.b	#4,act(a0)
	bne.s	locret_D6BE
	addq.b	#1,arg(a0)

locret_D6BE:
	rts
; ---------------------------------------------------------------------------

loc_D6C0:
	moveq	#0,d3
	move.b	xpix(a0),d3
	bsr.w	ObjectHitWallRight
	tst.w	d1
	bmi.s	loc_D6DA
	addq.w	#1,xpos(a0)
	move.w	xpos(a0),$32(a0)
	rts
; ---------------------------------------------------------------------------

loc_D6DA:
	clr.b	arg(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/GHZ/MovingPtfm/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjBasaran:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjBasaran_Index(pc,d0.w),d1
	jmp ObjBasaran_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjBasaran_Index:dc.w ObjBasaran_Init-ObjBasaran_Index, ObjBasaran_Action-ObjBasaran_Index
; ---------------------------------------------------------------------------

ObjBasaran_Init:
	addq.b	#2,act(a0)
	move.l	#MapBasaran,4(a0)
	move.w	#$84B8,2(a0)
	move.b	#4,render(a0)
	move.b	#$C,yrad(a0)
	move.w	#$100,prio(a0)
	move.b	#$B,col(a0)
	move.b	#$10,xpix(a0)

ObjBasaran_Action:
	moveq	#0,d0
	move.b	subact(a0),d0
	move.w	ObjBasaran_Index2(pc,d0.w),d1
	jsr ObjBasaran_Index2(pc,d1.w)
	lea (AniBasaran).l,a1
	bsr.w	ObjectAnimate
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

ObjBasaran_Index2:dc.w ObjBasaran_ChkDrop-ObjBasaran_Index2, ObjBasaran_DropFly-ObjBasaran_Index2, ObjBasaran_PlaySound-ObjBasaran_Index2
	dc.w ObjBasaran_FlyUp-ObjBasaran_Index2
; ---------------------------------------------------------------------------

ObjBasaran_ChkDrop:
	move.w	#$80,d2
	bsr.w	ObjBasaran_CheckPlayer
	bcc.s	ObjBasaran_NotDropped
	move.w	(ObjectsList+$C).w,d0
	move.w	d0,sensorfront(a0)
	sub.w	ypos(a0),d0
	bcs.s	ObjBasaran_NotDropped
	cmpi.w	#$80,d0
	bcc.s	ObjBasaran_NotDropped
	tst.w	(DebugRoutine).w
	bne.s	ObjBasaran_NotDropped
	move.b	(byte_FFFE0F).w,d0
	add.b	d7,d0
	andi.b	#7,d0
	bne.s	ObjBasaran_NotDropped
	move.b	#1,ani(a0)
	addq.b	#2,subact(a0)

ObjBasaran_NotDropped:
	rts
; ---------------------------------------------------------------------------

ObjBasaran_DropFly:
	bsr.w	ObjectMove
	addi.w	#$18,yvel(a0)
	move.w	#$80,d2
	bsr.w	ObjBasaran_CheckPlayer
	move.w	sensorfront(a0),d0
	sub.w	ypos(a0),d0
	bcs.s	ObjBasaran_Delete
	cmpi.w	#$10,d0
	bcc.s	locret_D7CE
	move.w	d1,xvel(a0)
	move.w	#0,yvel(a0)
	move.b	#2,ani(a0)
	addq.b	#2,subact(a0)

locret_D7CE:
	rts
; ---------------------------------------------------------------------------

ObjBasaran_Delete:
	tst.b	render(a0)
	bpl.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------

ObjBasaran_PlaySound:
	sfx	sfx_Basaran

loc_D7EE:
	bsr.w	ObjectMove
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_D7FE
	neg.w	d0

loc_D7FE:
	cmpi.w	#$80,d0
	bcs.s	locret_D814
	move.b	(byte_FFFE0F).w,d0
	add.b	d7,d0
	andi.b	#7,d0
	bne.s	locret_D814
	addq.b	#2,subact(a0)

locret_D814:
	rts
; ---------------------------------------------------------------------------

ObjBasaran_FlyUp:
	bsr.w	ObjectMove
	subi.w	#$18,yvel(a0)
	bsr.w	ObjectHitCeiling
	tst.w	d1
	bpl.s	locret_D842
	sub.w	d1,ypos(a0)
	andi.w	#$FFF8,xpos(a0)
	clr.w	xvel(a0)
	clr.w	yvel(a0)
	clr.b	ani(a0)
	clr.b	subact(a0)

locret_D842:
	rts
; ---------------------------------------------------------------------------

ObjBasaran_CheckPlayer:
	move.w	#$100,d1
	bset	#0,status(a0)
	move.w	(ObjectsList+8).w,d0
	sub.w	xpos(a0),d0
	bcc.s	loc_D862
	neg.w	d0
	neg.w	d1
	bclr	#0,status(a0)

loc_D862:
	cmp.w	d2,d0
	rts
; ---------------------------------------------------------------------------
	include "levels/MZ/Basaran/Sprite.ani"
	include "levels/MZ/Basaran/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjMovingBlocks:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjMovingBlocks_Index(pc,d0.w),d1
	jmp ObjMovingBlocks_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjMovingBlocks_Index:dc.w ObjMovingBlocks_Init-ObjMovingBlocks_Index, ObjMovingBlocks_Action-ObjMovingBlocks_Index

ObjMovingBlocks_Variables:dc.b $10, $10
	dc.b $20, $20
	dc.b $10, $20
	dc.b $20, $1A
	dc.b $10, $27
	dc.b $10, $10
; ---------------------------------------------------------------------------

ObjMovingBlocks_Init:
	addq.b	#2,act(a0)
	move.l	#MapMovingBlocks,4(a0)
	move.w	#$4000,2(a0)
	cmpi.b	#3,(curzone).w
	bne.s	loc_D912
	move.w	#$4480,2(a0)

loc_D912:
	move.b	#4,render(a0)
	move.w	#$180,prio(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	lsr.w	#3,d0
	andi.w	#$E,d0
	lea ObjMovingBlocks_Variables(pc,d0.w),a2
	move.b	(a2)+,xpix(a0)
	move.b	(a2),yrad(a0)
	lsr.w	#1,d0
	move.b	d0,frame(a0)
	move.w	xpos(a0),$34(a0)
	move.w	ypos(a0),$30(a0)
	moveq	#0,d0
	move.b	(a2),d0
	add.w	d0,d0
	move.w	d0,$3A(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#$F,d0
	subq.w	#8,d0
	bcs.s	ObjMovingBlocks_IsGone
	lsl.w	#2,d0
	lea ((oscValues+$2C)).w,a2
	lea (a2,d0.w),a2
	tst.w	(a2)
	bpl.s	ObjMovingBlocks_IsGone
	bchg	#0,status(a0)

ObjMovingBlocks_IsGone:
	move.b	arg(a0),d0
	bpl.s	ObjMovingBlocks_Action
	andi.b	#$F,d0
	move.b	d0,$3C(a0)
	move.b	#5,arg(a0)
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	beq.s	ObjMovingBlocks_Action
	bclr	#7,2(a2,d0.w)
	btst	#0,2(a2,d0.w)
	beq.s	ObjMovingBlocks_Action
	move.b	#6,arg(a0)
	clr.w	$3A(a0)

ObjMovingBlocks_Action:
	move.w	xpos(a0),-(sp)
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#$F,d0
	add.w	d0,d0
	move.w	ObjBasaran_TypeIndex(pc,d0.w),d1
	jsr ObjBasaran_TypeIndex(pc,d1.w)
	move.w	(sp)+,d4
	tst.b	render(a0)
	bpl.s	ObjMovingBlocks_ChkDelete
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	moveq	#0,d2
	move.b	yrad(a0),d2
	move.w	d2,d3
	addq.w	#1,d3
	bsr.w	sub_A2BC

ObjMovingBlocks_ChkDelete:
	move.w	$34(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjBasaran_TypeIndex:dc.w ObjBasaran_Type00-ObjBasaran_TypeIndex, ObjBasaran_Type01-ObjBasaran_TypeIndex, ObjBasaran_Type02-ObjBasaran_TypeIndex
	dc.w ObjBasaran_Type03-ObjBasaran_TypeIndex, ObjBasaran_Type04-ObjBasaran_TypeIndex, ObjBasaran_Type05-ObjBasaran_TypeIndex
	dc.w ObjBasaran_Type06-ObjBasaran_TypeIndex, ObjBasaran_Type07-ObjBasaran_TypeIndex, ObjBasaran_Type08-ObjBasaran_TypeIndex
	dc.w ObjBasaran_Type09-ObjBasaran_TypeIndex, ObjBasaran_Type0A-ObjBasaran_TypeIndex, ObjBasaran_Type0B-ObjBasaran_TypeIndex
; ---------------------------------------------------------------------------

ObjBasaran_Type00:
	rts
; ---------------------------------------------------------------------------

ObjBasaran_Type01:
	move.w	#$40,d1
	moveq	#0,d0
	move.b	(oscValues+$A).w,d0
	bra.s	loc_DA38
; ---------------------------------------------------------------------------

ObjBasaran_Type02:
	move.w	#$80,d1
	moveq	#0,d0
	move.b	(oscValues+$1E).w,d0

loc_DA38:
	btst	#0,status(a0)
	beq.s	loc_DA44
	neg.w	d0
	add.w	d1,d0

loc_DA44:
	move.w	$34(a0),d1
	sub.w	d0,d1
	move.w	d1,xpos(a0)
	rts
; ---------------------------------------------------------------------------

ObjBasaran_Type03:
	move.w	#$40,d1
	moveq	#0,d0
	move.b	(oscValues+$A).w,d0
	bra.s	loc_DA62
; ---------------------------------------------------------------------------

ObjBasaran_Type04:
	moveq	#0,d0
	move.b	(oscValues+$1E).w,d0

loc_DA62:
	btst	#0,status(a0)
	beq.s	loc_DA70
	neg.w	d0
	addi.w	#$80,d0

loc_DA70:
	move.w	$30(a0),d1
	sub.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

ObjBasaran_Type05:
	tst.b	convex(a0)
	bne.s	loc_DA9A
	lea (unk_FFF7E0).w,a2
	moveq	#0,d0
	move.b	$3C(a0),d0
	btst	#0,(a2,d0.w)
	beq.s	loc_DAA4
	move.b	#1,convex(a0)

loc_DA9A:
	tst.w	$3A(a0)
	beq.s	loc_DAB4
	subq.w	#2,$3A(a0)

loc_DAA4:
	move.w	$3A(a0),d0
	move.w	$30(a0),d1
	add.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_DAB4:
	addq.b	#1,arg(a0)
	clr.b	convex(a0)
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	beq.s	loc_DAA4
	bset	#0,2(a2,d0.w)
	bra.s	loc_DAA4
; ---------------------------------------------------------------------------

ObjBasaran_Type06:
	tst.b	convex(a0)
	bne.s	loc_DAEC
	lea (unk_FFF7E0).w,a2
	moveq	#0,d0
	move.b	$3C(a0),d0
	tst.b	(a2,d0.w)
	bpl.s	loc_DAFE
	move.b	#1,convex(a0)

loc_DAEC:
	moveq	#0,d0
	move.b	yrad(a0),d0
	add.w	d0,d0
	cmp.w	$3A(a0),d0
	beq.s	loc_DB0E
	addq.w	#2,$3A(a0)

loc_DAFE:
	move.w	$3A(a0),d0
	move.w	$30(a0),d1
	add.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_DB0E:
	subq.b	#1,arg(a0)
	clr.b	convex(a0)
	lea (byte_FFFC00).w,a2
	moveq	#0,d0
	move.b	respawn(a0),d0
	beq.s	loc_DAFE
	bclr	#0,2(a2,d0.w)
	bra.s	loc_DAFE
; ---------------------------------------------------------------------------

ObjBasaran_Type07:
	tst.b	convex(a0)
	bne.s	loc_DB40
	tst.b	(unk_FFF7EF).w
	beq.s	locret_DB5A
	move.b	#1,convex(a0)
	clr.w	$3A(a0)

loc_DB40:
	addq.w	#1,xpos(a0)
	move.w	xpos(a0),$34(a0)
	addq.w	#1,$3A(a0)
	cmpi.w	#$380,$3A(a0)
	bne.s	locret_DB5A
	clr.b	arg(a0)

locret_DB5A:
	rts
; ---------------------------------------------------------------------------

ObjBasaran_Type08:
	move.w	#$10,d1
	moveq	#0,d0
	move.b	(oscValues+$2A).w,d0
	lsr.w	#1,d0
	move.w	(oscValues+$2C).w,d3
	bra.s	ObjBasaran_MoveSquare
; ---------------------------------------------------------------------------

ObjBasaran_Type09:
	move.w	#$30,d1
	moveq	#0,d0
	move.b	(oscValues+$2E).w,d0
	move.w	(oscValues+$30).w,d3
	bra.s	ObjBasaran_MoveSquare
; ---------------------------------------------------------------------------

ObjBasaran_Type0A:
	move.w	#$50,d1
	moveq	#0,d0
	move.b	(oscValues+$32).w,d0
	move.w	(oscValues+$34).w,d3
	bra.s	ObjBasaran_MoveSquare
; ---------------------------------------------------------------------------

ObjBasaran_Type0B:
	move.w	#$70,d1
	moveq	#0,d0
	move.b	(oscValues+$36).w,d0
	move.w	(oscValues+$38).w,d3

ObjBasaran_MoveSquare:
	tst.w	d3
	bne.s	loc_DBAA
	addq.b	#1,status(a0)
	andi.b	#3,status(a0)

loc_DBAA:
	move.b	status(a0),d2
	andi.b	#3,d2
	bne.s	loc_DBCA
	sub.w	d1,d0
	add.w	$34(a0),d0
	move.w	d0,xpos(a0)
	neg.w	d1
	add.w	$30(a0),d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_DBCA:
	subq.b	#1,d2
	bne.s	loc_DBE8
	subq.w	#1,d1
	sub.w	d1,d0
	neg.w	d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	addq.w	#1,d1
	add.w	$34(a0),d1
	move.w	d1,xpos(a0)
	rts
; ---------------------------------------------------------------------------

loc_DBE8:
	subq.b	#1,d2
	bne.s	loc_DC06
	subq.w	#1,d1
	sub.w	d1,d0
	neg.w	d0
	add.w	$34(a0),d0
	move.w	d0,xpos(a0)
	addq.w	#1,d1
	add.w	$30(a0),d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_DC06:
	sub.w	d1,d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	neg.w	d1
	add.w	$34(a0),d1
	move.w	d1,xpos(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/MovingBlocks/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSpikedBalls:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjSpikedBalls_Index(pc,d0.w),d1
	jmp ObjSpikedBalls_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjSpikedBalls_Index:dc.w ObjSpikedBalls_Init-ObjSpikedBalls_Index, ObjSpikedBalls_Move-ObjSpikedBalls_Index, ObjSpikedBalls_Display-ObjSpikedBalls_Index
; ---------------------------------------------------------------------------

ObjSpikedBalls_Init:
	addq.b	#2,act(a0)
	move.l	#MapSpikedBalls,4(a0)
	move.w	#$3BA,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#8,xpix(a0)
	move.w	xpos(a0),$3A(a0)
	move.w	ypos(a0),convex(a0)
	move.b	#$98,col(a0)
	move.b	arg(a0),d1
	andi.b	#$F0,d1
	ext.w	d1
	asl.w	#3,d1
	move.w	d1,$3E(a0)
	move.b	status(a0),d0
	ror.b	#2,d0
	andi.b	#$C0,d0
	move.b	d0,angle(a0)
	lea $29(a0),a2
	move.b	arg(a0),d1
	andi.w	#7,d1
	move.b	#0,(a2)+
	move.w	d1,d3
	lsl.w	#4,d3
	move.b	d3,$3C(a0)
	subq.w	#1,d1
	bcs.s	loc_DD5E
	btst	#3,arg(a0)
	beq.s	ObjSpikedBalls_MakeChain
	subq.w	#1,d1
	bcs.s	loc_DD5E

ObjSpikedBalls_MakeChain:
	bsr.w	ObjectLoad
	bne.s	loc_DD5E
	addq.b	#1,$29(a0)
	move.w	a1,d5
	subi.w	#$D000,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+
	move.b	#4,act(a1)
	move.b	id(a0),id(a1)
	move.l	4(a0),4(a1)
	move.w	2(a0),2(a1)
	move.b	render(a0),render(a1)
	move.w	prio(a0),prio(a1)
	move.b	xpix(a0),xpix(a1)
	move.b	col(a0),col(a1)
	subi.b	#$10,d3
	move.b	d3,$3C(a1)
	dbf d1,ObjSpikedBalls_MakeChain

loc_DD5E:
	move.w	a0,d5
	subi.w	#$D000,d5
	lsr.w	#6,d5
	andi.w	#$7F,d5
	move.b	d5,(a2)+

ObjSpikedBalls_Move:
	bsr.w	ObjSpikedBalls_MoveStub
	bra.w	ObjSpikedBalls_ChkDelete
; ---------------------------------------------------------------------------

ObjSpikedBalls_MoveStub:
	move.w	$3E(a0),d0
	add.w	d0,angle(a0)
	move.b	angle(a0),d0
	jsr (GetSine).l
	move.w	convex(a0),d2
	move.w	$3A(a0),d3
	lea $29(a0),a2
	moveq	#0,d6
	move.b	(a2)+,d6

ObjSpikedBalls_MoveLoop:
	moveq	#0,d4
	move.b	(a2)+,d4
	lsl.w	#6,d4
	addi.l	#(ObjectsList)&$FFFFFF,d4
	movea.l d4,a1
	moveq	#0,d4
	move.b	$3C(a1),d4
	move.l	d4,d5
	muls.w	d0,d4
	asr.l	#8,d4
	muls.w	d1,d5
	asr.l	#8,d5
	add.w	d2,d4
	add.w	d3,d5
	move.w	d4,ypos(a1)
	move.w	d5,xpos(a1)
	dbf d6,ObjSpikedBalls_MoveLoop
	rts
; ---------------------------------------------------------------------------

ObjSpikedBalls_ChkDelete:
	move.w	$3A(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjSpikedBalls_Delete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjSpikedBalls_Delete:
	moveq	#0,d2
	lea $29(a0),a2
	move.b	(a2)+,d2

ObjSpikedBalls_DeleteLoop:
	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#6,d0
	addi.l	#(ObjectsList)&$FFFFFF,d0
	movea.l d0,a1
	bsr.w	ObjectDeleteA1
	dbf d2,ObjSpikedBalls_DeleteLoop
	rts
; ---------------------------------------------------------------------------

ObjSpikedBalls_Display:
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "unsorted/MapSpikedBalls.map"
	even
; ---------------------------------------------------------------------------

ObjGiantSpikedBalls:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjGiantBalls_Index(pc,d0.w),d1
	jmp ObjGiantBalls_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjGiantBalls_Index:dc.w ObjGiantBalls_Init-ObjGiantBalls_Index, ObjGiantBalls_Move-ObjGiantBalls_Index
; ---------------------------------------------------------------------------

ObjGiantBalls_Init:
	addq.b	#2,act(a0)
	move.l	#MapGiantSpikedBalls,4(a0)
	move.w	#$396,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$18,xpix(a0)
	move.w	xpos(a0),$3A(a0)
	move.w	ypos(a0),convex(a0)
	move.b	#$86,col(a0)
	move.b	arg(a0),d1
	andi.b	#$F0,d1
	ext.w	d1
	asl.w	#3,d1
	move.w	d1,$3E(a0)
	move.b	status(a0),d0
	ror.b	#2,d0
	andi.b	#$C0,d0
	move.b	d0,angle(a0)
	move.b	#$50,$3C(a0)

ObjGiantBalls_Move:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#7,d0
	add.w	d0,d0
	move.w	ObjGiantBalls_TypeIndex(pc,d0.w),d1
	jsr ObjGiantBalls_TypeIndex(pc,d1.w)
	move.w	$3A(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjGiantBalls_TypeIndex:dc.w ObjGiantBalls_Type00-ObjGiantBalls_TypeIndex, ObjGiantBalls_Type01-ObjGiantBalls_TypeIndex, ObjGiantBalls_Type02-ObjGiantBalls_TypeIndex, ObjGiantBalls_Type03-ObjGiantBalls_TypeIndex
; ---------------------------------------------------------------------------

ObjGiantBalls_Type00:
	rts
; ---------------------------------------------------------------------------

ObjGiantBalls_Type01:
	move.w	#$60,d1
	moveq	#0,d0
	move.b	(oscValues+$E).w,d0
	btst	#0,status(a0)
	beq.s	loc_DED6
	neg.w	d0
	add.w	d1,d0

loc_DED6:
	move.w	$3A(a0),d1
	sub.w	d0,d1
	move.w	d1,xpos(a0)
	rts
; ---------------------------------------------------------------------------

ObjGiantBalls_Type02:
	move.w	#$60,d1
	moveq	#0,d0
	move.b	(oscValues+$E).w,d0
	btst	#0,status(a0)
	beq.s	loc_DEFA
	neg.w	d0
	addi.w	#$80,d0

loc_DEFA:
	move.w	convex(a0),d1
	sub.w	d0,d1
	move.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

ObjGiantBalls_Type03:
	move.w	$3E(a0),d0
	add.w	d0,angle(a0)
	move.b	angle(a0),d0
	jsr (GetSine).l
	move.w	convex(a0),d2
	move.w	$3A(a0),d3
	moveq	#0,d4
	move.b	$3C(a0),d4
	move.l	d4,d5
	muls.w	d0,d4
	asr.l	#8,d4
	muls.w	d1,d5
	asr.l	#8,d5
	add.w	d2,d4
	add.w	d3,d5
	move.w	d4,ypos(a0)
	move.w	d5,xpos(a0)
	rts
; ---------------------------------------------------------------------------
	include "unsorted/MapGiantSpikedBalls.map"
	even
; ---------------------------------------------------------------------------

ObjSLZMovingPtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_DF9A(pc,d0.w),d1
	jsr off_DF9A(pc,d1.w)
	move.w	$32(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_DF9A:   dc.w loc_DFC2-off_DF9A, loc_E03A-off_DF9A, loc_E04A-off_DF9A, loc_E194-off_DF9A

byte_DFA2:  dc.b $28, 0
	dc.b $10, 1
	dc.b $20, 1
	dc.b $34, 1
	dc.b $10, 3
	dc.b $20, 3
	dc.b $34, 3
	dc.b $14, 1
	dc.b $24, 1
	dc.b $2C, 1
	dc.b $14, 3
	dc.b $24, 3
	dc.b $2C, 3
	dc.b $20, 5
	dc.b $20, 7
	dc.b $30, 9
; ---------------------------------------------------------------------------

loc_DFC2:
	addq.b	#2,act(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	bpl.s	loc_DFE6
	addq.b	#4,act(a0)
	andi.w	#$7F,d0
	mulu.w	#6,d0
	move.w	d0,$3C(a0)
	move.w	d0,$3E(a0)
	addq.l	#4,sp
	rts
; ---------------------------------------------------------------------------

loc_DFE6:
	lsr.w	#3,d0
	andi.w	#$1E,d0
	lea byte_DFA2(pc,d0.w),a2
	move.b	(a2)+,xpix(a0)
	move.b	(a2)+,frame(a0)
	moveq	#0,d0
	move.b	arg(a0),d0
	add.w	d0,d0
	andi.w	#$1E,d0
	lea byte_DFA2+2(pc,d0.w),a2
	move.b	(a2)+,d0
	lsl.w	#2,d0
	move.w	d0,$3C(a0)
	move.b	(a2)+,arg(a0)
	move.l	#MapSLZMovingPtfm,4(a0)
	move.w	#$4480,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.w	xpos(a0),$32(a0)
	move.w	ypos(a0),$30(a0)

loc_E03A:
	moveq	#0,d1
	move.b	xpix(a0),d1
	jsr (PtfmNormal).l
	bra.w	sub_E06E
; ---------------------------------------------------------------------------

loc_E04A:
	moveq	#0,d1
	move.b	xpix(a0),d1
	jsr (PtfmCheckExit).l
	move.w	xpos(a0),-(sp)
	bsr.w	sub_E06E
	move.w	(sp)+,d2
	tst.b	id(a0)
	beq.s	locret_E06C
	jmp (ptfmSurfaceNormal).l
; ---------------------------------------------------------------------------

locret_E06C:
	rts
; ---------------------------------------------------------------------------

sub_E06E:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#$F,d0
	add.w	d0,d0
	move.w	off_E082(pc,d0.w),d1
	jmp off_E082(pc,d1.w)
; ---------------------------------------------------------------------------

off_E082:   dc.w locret_E096-off_E082, loc_E098-off_E082, loc_E0A6-off_E082, loc_E098-off_E082
	dc.w loc_E0BA-off_E082, loc_E098-off_E082, loc_E0CC-off_E082, loc_E098-off_E082, loc_E0EE-off_E082
	dc.w loc_E110-off_E082
; ---------------------------------------------------------------------------

locret_E096:
	rts
; ---------------------------------------------------------------------------

loc_E098:
	cmpi.b	#4,act(a0)
	bne.s	locret_E0A4
	addq.b	#1,arg(a0)

locret_E0A4:
	rts
; ---------------------------------------------------------------------------

loc_E0A6:
	bsr.w	sub_E14A
	move.w	$34(a0),d0
	neg.w	d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_E0BA:
	bsr.w	sub_E14A
	move.w	$34(a0),d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_E0CC:
	bsr.w	sub_E14A
	move.w	$34(a0),d0
	asr.w	#1,d0
	neg.w	d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	move.w	$34(a0),d0
	add.w	$32(a0),d0
	move.w	d0,xpos(a0)
	rts
; ---------------------------------------------------------------------------

loc_E0EE:
	bsr.w	sub_E14A
	move.w	$34(a0),d0
	asr.w	#1,d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	move.w	$34(a0),d0
	neg.w	d0
	add.w	$32(a0),d0
	move.w	d0,xpos(a0)
	rts
; ---------------------------------------------------------------------------

loc_E110:
	bsr.w	sub_E14A
	move.w	$34(a0),d0
	neg.w	d0
	add.w	$30(a0),d0
	move.w	d0,ypos(a0)
	tst.b	arg(a0)
	beq.w	loc_E12C
	rts
; ---------------------------------------------------------------------------

loc_E12C:
	btst	#3,status(a0)
	beq.s	loc_E146
	bset	#1,status(a1)
	bclr	#3,status(a1)
	move.b	#2,act(a1)

loc_E146:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

sub_E14A:
	move.w	convex(a0),d0
	tst.b	$3A(a0)
	bne.s	loc_E160
	cmpi.w	#$800,d0
	bcc.s	loc_E168
	addi.w	#$10,d0
	bra.s	loc_E168
; ---------------------------------------------------------------------------

loc_E160:
	tst.w	d0
	beq.s	loc_E168
	subi.w	#$10,d0

loc_E168:
	move.w	d0,convex(a0)
	ext.l	d0
	asl.l	#8,d0
	add.l	$34(a0),d0
	move.l	d0,$34(a0)
	swap	d0
	move.w	$3C(a0),d2
	cmp.w	d2,d0
	bls.s	loc_E188
	move.b	#1,$3A(a0)

loc_E188:
	add.w	d2,d2
	cmp.w	d2,d0
	bne.s	locret_E192
	clr.b	arg(a0)

locret_E192:
	rts
; ---------------------------------------------------------------------------

loc_E194:
	subq.w	#1,$3C(a0)
	bne.s	loc_E1BE
	move.w	$3E(a0),$3C(a0)
	bsr.w	ObjectLoad
	bne.s	loc_E1BE
	move.b	#$59,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	#$E,arg(a1)

loc_E1BE:
	addq.l	#4,sp
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	rts
; ---------------------------------------------------------------------------
	include "levels/SLZ/MovingPtfm/Srite.map"
	even
; ---------------------------------------------------------------------------

ObjCirclePtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_E222(pc,d0.w),d1
	jsr off_E222(pc,d1.w)
	move.w	$32(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_E222:   dc.w loc_E228-off_E222, loc_E258-off_E222, loc_E268-off_E222
; ---------------------------------------------------------------------------

loc_E228:
	addq.b	#2,act(a0)
	move.l	#MapCirclePtfm,4(a0)
	move.w	#$4480,2(a0)
	move.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$18,xpix(a0)
	move.w	xpos(a0),$32(a0)
	move.w	ypos(a0),$30(a0)

loc_E258:
	moveq	#0,d1
	move.b	xpix(a0),d1
	jsr (PtfmNormal).l
	bra.w	sub_E284
; ---------------------------------------------------------------------------

loc_E268:
	moveq	#0,d1
	move.b	xpix(a0),d1
	jsr (PtfmCheckExit).l
	move.w	xpos(a0),-(sp)
	bsr.w	sub_E284
	move.w	(sp)+,d2
	jmp (ptfmSurfaceNormal).l
; ---------------------------------------------------------------------------

sub_E284:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#$C,d0
	lsr.w	#1,d0
	move.w	off_E298(pc,d0.w),d1
	jmp off_E298(pc,d1.w)
; ---------------------------------------------------------------------------

off_E298:   dc.w loc_E29C-off_E298, loc_E2DA-off_E298
; ---------------------------------------------------------------------------

loc_E29C:
	move.b	(oscValues+$22).w,d1
	subi.b	#$50,d1
	ext.w	d1
	move.b	(oscValues+$26).w,d2
	subi.b	#$50,d2
	ext.w	d2
	btst	#0,arg(a0)
	beq.s	loc_E2BC
	neg.w	d1
	neg.w	d2

loc_E2BC:
	btst	#1,arg(a0)
	beq.s	loc_E2C8
	neg.w	d1
	exg d1,d2

loc_E2C8:
	add.w	$32(a0),d1
	move.w	d1,xpos(a0)
	add.w	$30(a0),d2
	move.w	d2,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_E2DA:
	move.b	(oscValues+$22).w,d1
	subi.b	#$50,d1
	ext.w	d1
	move.b	(oscValues+$26).w,d2
	subi.b	#$50,d2
	ext.w	d2
	btst	#0,arg(a0)
	beq.s	loc_E2FA
	neg.w	d1
	neg.w	d2

loc_E2FA:
	btst	#1,arg(a0)
	beq.s	loc_E306
	neg.w	d1
	exg d1,d2

loc_E306:
	neg.w	d1
	add.w	$32(a0),d1
	move.w	d1,xpos(a0)
	add.w	$30(a0),d2
	move.w	d2,ypos(a0)
	rts
; ---------------------------------------------------------------------------
	include "levels/SLZ/CirclePtfm/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjStaircasePtfm:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_E358(pc,d0.w),d1
	jsr off_E358(pc,d1.w)
	move.w	$30(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

off_E358:   dc.w loc_E35E-off_E358, loc_E3DE-off_E358, loc_E3F2-off_E358
; ---------------------------------------------------------------------------

loc_E35E:
	addq.b	#2,act(a0)
	moveq	#$38,d3
	moveq	#1,d4
	btst	#0,status(a0)
	beq.s	loc_E372
	moveq	#$3B,d3
	moveq	#$FFFFFFFF,d4

loc_E372:
	move.w	xpos(a0),d2
	movea.l a0,a1
	moveq	#3,d1
	bra.s	loc_E38A
; ---------------------------------------------------------------------------

loc_E37C:
	bsr.w	LoadNextObject
	bne.w	loc_E3DE
	move.b	#4,act(a1)

loc_E38A:
	move.b	#$5B,id(a1)
	move.l	#MapStaircasePtfm,4(a1)
	move.w	#$4480,2(a1)
	move.b	#4,render(a1)
	move.w	#$180,prio(a1)
	move.b	#$10,xpix(a1)
	move.b	arg(a0),arg(a1)
	move.w	d2,xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.w	xpos(a0),$30(a1)
	move.w	ypos(a1),$32(a1)
	addi.w	#$20,d2
	move.b	d3,sensorback(a1)
	move.l	a0,$3C(a1)
	add.b	d4,d3
	dbf d1,loc_E37C

loc_E3DE:
	moveq	#0,d0
	move.b	arg(a0),d0
	andi.w	#7,d0
	add.w	d0,d0
	move.w	off_E43A(pc,d0.w),d1
	jsr off_E43A(pc,d1.w)

loc_E3F2:
	movea.l $3C(a0),a2
	moveq	#0,d0
	move.b	sensorback(a0),d0
	move.b	(a2,d0.w),d0
	add.w	$32(a0),d0
	move.w	d0,ypos(a0)
	moveq	#0,d1
	move.b	xpix(a0),d1
	addi.w	#$B,d1
	move.w	#$10,d2
	move.w	#$11,d3
	move.w	xpos(a0),d4
	bsr.w	sub_A2BC
	tst.b	d4
	bpl.s	loc_E42A
	move.b	d4,sensorfront(a2)

loc_E42A:
	btst	#3,status(a0)
	beq.s	locret_E438
	move.b	#1,sensorfront(a2)

locret_E438:
	rts
; ---------------------------------------------------------------------------

off_E43A:   dc.w loc_E442-off_E43A, loc_E4A8-off_E43A, loc_E464-off_E43A, loc_E4A8-off_E43A
; ---------------------------------------------------------------------------

loc_E442:
	tst.w	$34(a0)
	bne.s	loc_E458
	cmpi.b	#1,sensorfront(a0)
	bne.s	locret_E456
	move.w	#$1E,$34(a0)

locret_E456:
	rts
; ---------------------------------------------------------------------------

loc_E458:
	subq.w	#1,$34(a0)
	bne.s	locret_E456
	addq.b	#1,arg(a0)
	rts
; ---------------------------------------------------------------------------

loc_E464:
	tst.w	$34(a0)
	bne.s	loc_E478
	tst.b	sensorfront(a0)
	bpl.s	locret_E476
	move.w	#$3C,$34(a0)

locret_E476:
	rts
; ---------------------------------------------------------------------------

loc_E478:
	subq.w	#1,$34(a0)
	bne.s	loc_E484
	addq.b	#1,arg(a0)
	rts
; ---------------------------------------------------------------------------

loc_E484:
	lea convex(a0),a1
	move.w	$34(a0),d0
	lsr.b	#2,d0
	andi.b	#1,d0
	move.b	d0,(a1)+
	eori.b	#1,d0
	move.b	d0,(a1)+
	eori.b	#1,d0
	move.b	d0,(a1)+
	eori.b	#1,d0
	move.b	d0,(a1)+
	rts
; ---------------------------------------------------------------------------

loc_E4A8:
	lea convex(a0),a1
	cmpi.b	#$80,(a1)
	beq.s	locret_E4D0
	addq.b	#1,(a1)
	moveq	#0,d1
	move.b	(a1)+,d1
	swap	d1
	lsr.l	#1,d1
	move.l	d1,d2
	lsr.l	#1,d1
	move.l	d1,d3
	add.l	d2,d3
	swap	d1
	swap	d2
	swap	d3
	move.b	d3,(a1)+
	move.b	d2,(a1)+
	move.b	d1,(a1)+

locret_E4D0:
	rts
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------
	include "levels/SLZ/StaircasePtfm/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSLZGirder:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_E4EA(pc,d0.w),d1
	jmp off_E4EA(pc,d1.w)
; ---------------------------------------------------------------------------

off_E4EA:   dc.w loc_E4EE-off_E4EA, loc_E506-off_E4EA
; ---------------------------------------------------------------------------

loc_E4EE:
	addq.b	#2,act(a0)
	move.l	#MapSLZGirder,4(a0)
	move.w	#$83CC,2(a0)
	move.b	#$10,xpix(a0)

loc_E506:
	move.l	(CameraX).w,d1
	add.l	d1,d1
	swap	d1
	neg.w	d1
	move.w	d1,xpos(a0)
	move.l	(CameraY).w,d1
	add.l	d1,d1
	swap	d1
	andi.w	#$3F,d1
	neg.w	d1
	addi.w	#$100,d1
	move.w	d1,xpix(a0)
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/SLZ/Girder/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjFan:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_E56C(pc,d0.w),d1
	jmp off_E56C(pc,d1.w)
; ---------------------------------------------------------------------------

off_E56C:   dc.w loc_E570-off_E56C, loc_E594-off_E56C
; ---------------------------------------------------------------------------

loc_E570:
	addq.b	#2,act(a0)
	move.l	#MapFan,4(a0)
	move.w	#$43A0,2(a0)
	move.b	#4,render(a0)
	move.b	#$10,xpix(a0)
	move.w	#$200,prio(a0)

loc_E594:
	btst	#1,arg(a0)
	bne.s	loc_E5B6
	subq.w	#1,$30(a0)
	bpl.s	loc_E5B6
	move.w	#$78,$30(a0)
	bchg	#0,$32(a0)
	beq.s	loc_E5B6
	move.w	#$B4,$30(a0)

loc_E5B6:
	tst.b	$32(a0)
	bne.w	loc_E64E
	lea (ObjectsList).w,a1
	move.w	xpos(a1),d0
	sub.w	xpos(a0),d0
	btst	#0,status(a0)
	bne.s	loc_E5D4
	neg.w	d0

loc_E5D4:
	addi.w	#$50,d0
	cmpi.w	#$F0,d0
	bcc.s	loc_E61C
	move.w	ypos(a1),d1
	addi.w	#$60,d1
	sub.w	ypos(a0),d1
	bcs.s	loc_E61C
	cmpi.w	#$70,d1
	bcc.s	loc_E61C
	subi.w	#$50,d0
	bcc.s	loc_E5FC
	not.w	d0
	add.w	d0,d0

loc_E5FC:
	addi.w	#$60,d0
	btst	#0,status(a0)
	bne.s	loc_E60A
	neg.w	d0

loc_E60A:
	neg.b	d0
	asr.w	#4,d0
	btst	#0,arg(a0)
	beq.s	loc_E618
	neg.w	d0

loc_E618:
	add.w	d0,xpos(a1)

loc_E61C:
	subq.b	#1,anidelay(a0)
	bpl.s	loc_E64E
	move.b	#0,anidelay(a0)
	addq.b	#1,anipos(a0)
	cmpi.b	#3,anipos(a0)
	bcs.s	loc_E63A
	move.b	#0,anipos(a0)

loc_E63A:
	moveq	#0,d0
	btst	#0,arg(a0)
	beq.s	loc_E646
	moveq	#2,d0

loc_E646:
	add.b	anipos(a0),d0
	move.b	d0,frame(a0)

loc_E64E:
	move.w	xpos(a0),d0
	andi.w	#$FF80,d0
	sub.w	(CameraXCoarse).w,d0
	cmpi.w	#$280,d0
	bhi.w	ObjectDelete
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/SLZ/Fan/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSeeSaw:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_E6B0(pc,d0.w),d1
	jsr off_E6B0(pc,d1.w)
	bra.w	ObjectChkDespawn
; ---------------------------------------------------------------------------

off_E6B0:   dc.w loc_E6B6-off_E6B0, loc_E6DA-off_E6B0, loc_E706-off_E6B0
; ---------------------------------------------------------------------------

loc_E6B6:
	addq.b	#2,act(a0)
	move.l	#MapSeesaw,4(a0)
	move.w	#$374,2(a0)
	ori.b	#4,render(a0)
	move.w	#$200,prio(a0)
	move.b	#$30,xpix(a0)

loc_E6DA:
	lea (ObjSeeSaw_SlopeTilt).l,a2
	btst	#0,frame(a0)
	beq.s	loc_E6EE
	lea (ObjSeeSaw_SlopeLine).l,a2

loc_E6EE:
	lea (ObjectsList).w,a1
	move.w	#$30,d1
	jsr (PtfmSloped).l
	btst	#3,(a0)
	beq.s	locret_E704
	nop

locret_E704:
	rts
; ---------------------------------------------------------------------------

loc_E706:
	bsr.w	sub_E738
	lea (ObjSeeSaw_SlopeTilt).l,a2
	btst	#0,frame(a0)
	beq.s	loc_E71E
	lea (ObjSeeSaw_SlopeLine).l,a2

loc_E71E:
	move.w	#$30,d1
	jsr (PtfmCheckExit).l
	move.w	#$30,d1
	move.w	xpos(a0),d2
	jsr (sub_61E0).l
	rts
; ---------------------------------------------------------------------------

sub_E738:
	moveq	#2,d1
	lea (ObjectsList).w,a1
	move.w	xpos(a0),d0
	sub.w	xpos(a1),d0
	bcc.s	loc_E74C
	neg.w	d0
	moveq	#0,d1

loc_E74C:
	cmpi.w	#8,d0
	bcc.s	loc_E754
	moveq	#1,d1

loc_E754:
	move.b	d1,frame(a0)
	bclr	#0,render(a0)
	btst	#1,frame(a0)
	beq.s	locret_E76C
	bset	#0,render(a0)

locret_E76C:
	rts
; ---------------------------------------------------------------------------

ObjSeeSaw_SlopeTilt:dc.b $24, $24, $26, $28, $2A, $2C, $2A, $28, $26, $24
	dc.b $23, $22, $21, $20, $1F, $1E, $1D, $1C, $1B, $1A
	dc.b $19, $18, $17, $16, $15, $14, $13, $12, $11, $10
	dc.b $F, $E, $D, $C, $B, $A, 9, 8, 7, 6, 5, 4, 3, 2, 2
	dc.b 2, 2, 2

ObjSeeSaw_SlopeLine:dc.b $15, $15, $15, $15, $15, $15, $15, $15, $15, $15
	dc.b $15, $15, $15, $15, $15, $15, $15, $15, $15, $15
	dc.b $15, $15, $15, $15, $15, $15, $15, $15, $15, $15
	dc.b $15, $15, $15, $15, $15, $15, $15, $15, $15, $15
	dc.b $15, $15, $15, $15, $15, $15, $15, $15
	include "levels/SLZ/Seesaw/Sprite.map"
	even
; ---------------------------------------------------------------------------

ObjSonic:
	tst.w	(DebugRoutine).w
	bne.w	Edit
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	off_E826(pc,d0.w),d1
	jmp off_E826(pc,d1.w)
; ---------------------------------------------------------------------------

off_E826:   dc.w loc_E830-off_E826, loc_E872-off_E826, ObjSonic_Hurt-off_E826, ObjSonic_Death-off_E826
	dc.w ObjSonic_ResetLevel-off_E826
; ---------------------------------------------------------------------------

loc_E830:
	addq.b	#2,act(a0)
	move.b	#$13,yrad(a0)
	move.b	#9,xrad(a0)
	move.l	#MapSonic,map(a0)
	move.w	#$780,tile(a0)
	move.w	#$100,prio(a0)
	move.b	#$18,xpix(a0)
	move.b	#4,render(a0)
	lea	(PlayerTopSpeed).w,a2	; Load PlayerTopSpeed into a2
	jsr	ApplySpeedSettings  ; Fetch Speed settings

loc_E872:
	andi.w	#$7FF,ypos(a0)
	andi.w	#$7FF,(CameraY).w
	tst.w	(EditModeFlag).w
	beq.s	loc_E892
	btst	#JbB,(padPressPlayer).w
	beq.s	loc_E892
	move.w	#1,(DebugRoutine).w

loc_E892:
	moveq	#0,d0
	move.b	status(a0),d0
	andi.w	#6,d0
	move.w	off_E8C8(pc,d0.w),d1
	jsr off_E8C8(pc,d1.w)
	bsr.s	sub_E8D6
	bsr.w	sub_E952
	move.b	(unk_FFF768).w,sensorfront(a0)
	move.b	(unk_FFF76A).w,sensorback(a0)
	bsr.w	ObjSonic_Animate
	bsr.w	TouchObjects
	bsr.w	ObjSonic_SpecialChunk
	bra.w	ObjSonic_DynTiles
; ---------------------------------------------------------------------------

off_E8C8:   dc.w sub_E96C-off_E8C8, sub_E98E-off_E8C8, loc_E9A8-off_E8C8, loc_E9C6-off_E8C8
; ---------------------------------------------------------------------------

sub_E8D6:
	move.b	invulnerable(a0),d0
	beq.s	loc_E8E4
	subq.b	#1,invulnerable(a0)
	lsr.w	#3,d0
	bcc.s	loc_E8E8

loc_E8E4:
	bsr.w	ObjectDisplay

loc_E8E8:
	tst.b	(byte_FFFE2D).w
	beq.s	loc_E91C
	tst.w	invincible(a0)
	beq.s	loc_E91C
	subq.w	#1,invincible(a0)
	bne.s	loc_E91C
	tst.b	(unk_FFF7AA).w
	bne.s	loc_E916
	move.b	SavedSong.w,d0
	addi.w	#MSUc_PLAYLOOP,d0
	waitmsu
	move.w	d0,MCD_CMD ; send cmd: play track, loop
	addq.b	#1,MCD_CMD_CK ; Increment command clock

loc_E916:
	clr.b	(byte_FFFE2D).w
	subq.b	#2,act(a0)
	move.b	#$78,invulnerable(a0)

loc_E91C:
	tst.b	(byte_FFFE2E).w
	beq.s	locret_E950
	tst.w	speedshoes(a0)
	beq.s	locret_E950
	subq.w	#1,speedshoes(a0)
	bne.s	locret_E950
	lea	(PlayerTopSpeed).w,a2	; Load PlayerTopSpeed into a2
	jsr	ApplySpeedSettings	; Fetch Speed settings
	clr.b	(byte_FFFE2E).w
	move.w	(SavedSong).w,d0
	addi.w	#MSUc_PLAYLOOP,d0
	waitmsu
	move.w	d0,MCD_CMD
	addq.b	#1,MCD_CMD_CK
; ---------------------------------------------------------------------------

locret_E950:
	rts
; ---------------------------------------------------------------------------

sub_E952:
	move.w	(unk_FFF7A8).w,d0
	lea (SonicPosTable).w,a1
	lea (a1,d0.w),a1
	move.w	xpos(a0),(a1)+
	move.w	ypos(a0),(a1)+
	addq.b	#4,(unk_FFF7A9).w
	rts
; ---------------------------------------------------------------------------

sub_E96C:
	bsr.w	ObjSonic_SpinDash
	bsr.w	ObjSonic_Jump
	bsr.w	ObjSonic_SlopeResist
	bsr.w	ObjSonic_Move
	bsr.w	ObjSonic_Roll
	bsr.w	ObjSonic_LevelBound
	bsr.w	ObjectMove
	bsr.w	ObjSonic_AnglePosition
	bra.w	ObjSonic_SlopeRepel
; ---------------------------------------------------------------------------

sub_E98E:
	bsr.w	ObjSonic_JumpHeight
	bsr.w	ObjSonic_ChgJumpDirection
	bsr.w	ObjSonic_LevelBound
	bsr.w	ObjectFall
	bsr.w	ObjSonic_JumpAngle
	bra.w	ObjSonic_Floor
; ---------------------------------------------------------------------------

loc_E9A8:
	bsr.w	ObjSonic_Jump
	bsr.w	ObjSonic_RollRepel
	bsr.w	ObjSonic_RollSpeed
	bsr.w	ObjSonic_LevelBound
	bsr.w	ObjectMove
	bsr.w	ObjSonic_AnglePosition
	bra.w	ObjSonic_SlopeRepel
; ---------------------------------------------------------------------------

loc_E9C6:
	bsr.w	ObjSonic_JumpHeight
	bsr.w	ObjSonic_ChgJumpDirection
	bsr.w	ObjSonic_LevelBound
	bsr.w	ObjectFall
	bsr.w	ObjSonic_JumpAngle
	bra.w	ObjSonic_Floor
; ---------------------------------------------------------------------------

ObjSonic_Move:
	move.w	(PlayerTopSpeed).w,d6
	move.w	(PlayerAccel).w,d5
	move.w	(PlayerDecel).w,d4
	tst.w	lock(a0)
	bne.w	ObjSonic_LookUp
	btst	#JbL,(padHeldPlayer).w
	beq.s	ObjSonic_NoLeft
	bsr.w	ObjSonic_MoveLeft

ObjSonic_NoLeft:
	btst	#JbR,(padHeldPlayer).w
	beq.s	ObjSonic_NoRight
	bsr.w	ObjSonic_MoveRight

ObjSonic_NoRight:
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	bne.w	ObjSonic_ResetScroll
	tst.w	inertia(a0)
	bne.w	ObjSonic_ResetScroll
	bclr	#5,status(a0)
	move.b	#5,ani(a0)
	btst	#3,status(a0)
	beq.s	ObjSonic_Balance
	moveq	#0,d0
	move.b	platform(a0),d0
	lsl.w	#6,d0
	lea (ObjectsList).w,a1
	lea (a1,d0.w),a1
	tst.b	status(a1)
	bmi.s	ObjSonic_LookUp
	moveq	#0,d1
	move.b	xpix(a1),d1
	move.w	d1,d2
	add.w	d2,d2
	subq.w	#4,d2
	add.w	xpos(a0),d1
	sub.w	xpos(a1),d1
	cmpi.w	#4,d1
	blt.s	loc_EA92
	cmp.w	d2,d1
	bge.s	loc_EA82
	bra.s	ObjSonic_LookUp
; ---------------------------------------------------------------------------

ObjSonic_Balance:
	jsr ObjectHitFloor
	cmpi.w	#$C,d1
	blt.s	ObjSonic_LookUp
	cmpi.b	#3,sensorfront(a0)
	bne.s	loc_EA8A

loc_EA82:
	bclr	#0,status(a0)
	bra.s	loc_EA98
; ---------------------------------------------------------------------------

loc_EA8A:
	cmpi.b	#3,sensorback(a0)
	bne.s	ObjSonic_LookUp

loc_EA92:
	bset	#0,status(a0)

loc_EA98:
	move.b	#6,ani(a0)
	bra.s	ObjSonic_ResetScroll
; ---------------------------------------------------------------------------

ObjSonic_LookUp:
	btst	#JbU,(padHeldPlayer).w
	beq.s	ObjSonic_Duck
	move.b	#7,ani(a0)
	move.w	(CameraY).w,d0	; get camera top coordinate
	sub.w	(unk_FFF72C).w,d0	; subtract zone's top bound from it
	add.w	(unk_FFF73E).w,d0	; add default offset
	cmpi.w	#$C8,d0			; is offset <= $C8?
	ble.s	.notC8			; if so, branch
	move.w	#$C8,d0			; set offset to $C8
		
.notC8:
	cmp.w	(unk_FFF73E).w,d0
	ble.s	loc_EAEA
	addq.w	#2,(unk_FFF73E).w
	bra.s	loc_EAEA
; ---------------------------------------------------------------------------

ObjSonic_Duck:
	btst	#1,(padHeldPlayer).w
	beq.s	ObjSonic_ResetScroll
	move.b	#8,ani(a0)
	move.w	(CameraY).w,d0	; get camera top coordinate
	sub.w	(unk_FFF72E).w,d0	; subtract zone's bottom bound from it (creating a negative number)
	add.w	(unk_FFF73E).w,d0	; add default offset
	cmpi.w	#8,d0			; is offset < 8?
	blt.s	.set			; if so, branch
	bgt.s	.not8			; if greater than 8, branch
		
.set:
	move.w	#8,d0	; set offset to 8
		
.not8:
	cmp.w	(unk_FFF73E).w,d0
	bge.s	loc_EAEA
	subq.w	#2,(unk_FFF73E).w
	bra.s	loc_EAEA
; ---------------------------------------------------------------------------

ObjSonic_ResetScroll:
	cmpi.w	#$60,(unk_FFF73E).w
	beq.s	loc_EAEA
	bhs.s	loc_EAE6
	addq.w	#4,(unk_FFF73E).w

loc_EAE6:
	subq.w	#2,(unk_FFF73E).w

loc_EAEA:
	move.b	(padHeldPlayer).w,d0
	andi.b	#$C,d0
	bne.s	loc_EB16
	move.w	inertia(a0),d0
	beq.s	loc_EB16
	bmi.s	loc_EB0A
	sub.w	d5,d0
	bcc.s	loc_EB04
	move.w	#0,d0

loc_EB04:
	move.w	d0,inertia(a0)
	bra.s	loc_EB16
; ---------------------------------------------------------------------------

loc_EB0A:
	add.w	d5,d0
	bcc.s	loc_EB12
	move.w	#0,d0

loc_EB12:
	move.w	d0,inertia(a0)

loc_EB16:
	move.b	angle(a0),d0
	jsr (GetSine).l
	muls.w	inertia(a0),d1
	asr.l	#8,d1
	move.w	d1,xvel(a0)
	muls.w	inertia(a0),d0
	asr.l	#8,d0
	move.w	d0,yvel(a0)

loc_EB34:
	move.b	#$40,d1
	tst.w	inertia(a0)
	beq.s	locret_EB8E
	bmi.s	loc_EB42
	neg.w	d1

loc_EB42:
	move.b	angle(a0),d0
	add.b	d1,d0
	move.w	d0,-(sp)
	bsr.w	ObjSonic_WalkSpeed
	move.w	(sp)+,d0
	tst.w	d1
	bpl.s	locret_EB8E
	move.w	#0,inertia(a0)
	bset	#5,status(a0)
	asl.w	#8,d1
	addi.b	#$20,d0
	andi.b	#$C0,d0
	beq.s	loc_EB8A
	cmpi.b	#$40,d0
	beq.s	loc_EB84
	cmpi.b	#$80,d0
	beq.s	loc_EB7E
	add.w	d1,xvel(a0)
locret_EB8E:
	rts
; ---------------------------------------------------------------------------

loc_EB7E:
	sub.w	d1,yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_EB84:
	sub.w	d1,xvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_EB8A:
	add.w	d1,yvel(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_MoveLeft:
	move.w	inertia(a0),d0
	beq.s	loc_EB98
	bpl.s	loc_EBC4

loc_EB98:
	bset	#0,status(a0)
	bne.s	loc_EBAC
	bclr	#5,status(a0)
	move.b	#1,anilast(a0)

loc_EBAC:
	sub.w	d5,d0
	move.w	d6,d1
	neg.w	d1
	cmp.w	d1,d0
	bgt.s	loc_EBB8
	add.w	d5,d0
	cmp.w	d1,d0
	ble.s	loc_EBB8
	move.w	d1,d0

loc_EBB8:
	move.w	d0,inertia(a0)
	move.b	#0,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_EBC4:
	sub.w	d4,d0
	bcc.s	loc_EBCC
	move.w	#$FF80,d0

loc_EBCC:
	move.w	d0,inertia(a0)
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	bne.s	locret_EBFA
	cmpi.w	#$400,d0
	blt.s	locret_EBFA
	move.b	#$D,ani(a0)
	sfx	sfx_Skid
	bclr	#0,status(a0)

locret_EBFA:
	rts
; ---------------------------------------------------------------------------

ObjSonic_MoveRight:
	move.w	inertia(a0),d0
	bmi.s	loc_EC2A
	bclr	#0,status(a0)
	beq.s	loc_EC16
	bclr	#5,status(a0)
	move.b	#1,anilast(a0)

loc_EC16:
	add.w	d5,d0
	cmp.w	d6,d0
	blt.s	loc_EC1E
	sub.w	d5,d0
	cmp.w	d6,d0
	bge.s	loc_EC1E
	move.w	d6,d0

loc_EC1E:
	move.w	d0,inertia(a0)
	move.b	#0,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_EC2A:
	add.w	d4,d0
	bcc.s	loc_EC32
	move.w	#$80,d0

loc_EC32:
	move.w	d0,inertia(a0)
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	bne.s	locret_EC60
	cmpi.w	#$FC00,d0
	bgt.s	locret_EC60
	move.b	#$D,ani(a0)
	sfx	sfx_Skid
	bset	#0,status(a0)

locret_EC60:
	rts
; ---------------------------------------------------------------------------

ObjSonic_RollSpeed:
	move.w	(PlayerTopSpeed).w,d6
	asl.w	#1,d6
	moveq	#6,d5
	move.w	(PlayerDecel).w,d4
	asr.w	#2,d4
	tst.w	lock(a0)
	bne.s	loc_EC92
	btst	#JbL,(padHeldPlayer).w
	beq.s	loc_EC86
	bsr.w	ObjSonic_RollLeft

loc_EC86:
	btst	#JbR,(padHeldPlayer).w
	beq.s	loc_EC92
	bsr.w	ObjSonic_RollRight

loc_EC92:
	move.w	inertia(a0),d0
	beq.s	loc_ECB4
	bmi.s	loc_ECA8
	sub.w	d5,d0
	bcc.s	loc_ECA2
	move.w	#0,d0

loc_ECA2:
	move.w	d0,inertia(a0)
	bra.s	loc_ECB4
; ---------------------------------------------------------------------------

loc_ECA8:
	add.w	d5,d0
	bcc.s	loc_ECB0
	move.w	#0,d0

loc_ECB0:
	move.w	d0,inertia(a0)

loc_ECB4:
	tst.w	inertia(a0)
	bne.s	loc_ECD6
	bclr	#2,status(a0)
	move.b	#$13,yrad(a0)
	move.b	#9,xrad(a0)
	move.b	#5,ani(a0)
	subq.w	#5,ypos(a0)

loc_ECD6:
	move.b	angle(a0),d0
	jsr (GetSine).l
	muls.w	inertia(a0),d1
	asr.l	#8,d1
	move.w	d1,xvel(a0)
	muls.w	inertia(a0),d0
	asr.l	#8,d0
	move.w	d0,yvel(a0)
	bra.w	loc_EB34
; ---------------------------------------------------------------------------

ObjSonic_RollLeft:
	move.w	inertia(a0),d0
	beq.s	loc_ED00
	bpl.s	loc_ED0E

loc_ED00:
	bset	#0,status(a0)
	move.b	#2,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_ED0E:
	sub.w	d4,d0
	bcc.s	loc_ED16
	move.w	#$FF80,d0

loc_ED16:
	move.w	d0,inertia(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_RollRight:
	move.w	inertia(a0),d0
	bmi.s	loc_ED30
	bclr	#0,status(a0)
	move.b	#2,ani(a0)
	rts
; ---------------------------------------------------------------------------

loc_ED30:
	add.w	d4,d0
	bcc.s	loc_ED38
	move.w	#$80,d0

loc_ED38:
	move.w	d0,inertia(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_ChgJumpDirection:
	move.w	(PlayerTopSpeed).w,d6
	move.w	(PlayerAccel).w,d5
	asl.w	#1,d5
	move.w	xvel(a0),d0
	btst	#JbL,(padHeld1).w
	beq.s	loc_ED6E
	bset	#0,status(a0)
	sub.w	d5,d0
	move.w	d6,d1
	neg.w	d1
	cmp.w	d1,d0
	bgt.s	loc_ED6E
	add.w	d5,d0	    		; +++ remove this frame's acceleration change
	cmp.w	d1,d0	    		; +++ compare speed with top speed
	ble.s	loc_ED6E    		; +++ if speed was already greater than the maximum, branch
	move.w	d1,d0

loc_ED6E:
	btst	#JbR,(padHeld1).w
	beq.s	ObjSonic_JumpMove
	bclr	#0,status(a0)
	add.w	d5,d0
	cmp.w	d6,d0
	blt.s	ObjSonic_JumpMove
	sub.w	d5,d0	    		; +++ remove this frame's acceleration change
	cmp.w	d6,d0	    		; +++ compare speed with top speed
	bge.s	ObjSonic_JumpMove   	; +++ if speed was already greater than the maximum, branch
	move.w	d6,d0

ObjSonic_JumpMove:
	move.w	d0,xvel(a0)

ObjSonic_ResetScroll2:
	cmpi.w	#$60,(unk_FFF73E).w
	beq.s	loc_ED9A
	bcc.s	loc_ED96
	addq.w	#4,(unk_FFF73E).w

loc_ED96:
	subq.w	#2,(unk_FFF73E).w

loc_ED9A:
	cmpi.w	#$FC00,yvel(a0)
	bcs.s	locret_EDC8
	move.w	xvel(a0),d0
	move.w	d0,d1
	asr.w	#5,d1
	beq.s	locret_EDC8
	bmi.s	loc_EDBC
	sub.w	d1,d0
	bcc.s	loc_EDB6
	move.w	#0,d0

loc_EDB6:
	move.w	d0,xvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_EDBC:
	sub.w	d1,d0
	bcs.s	loc_EDC4
	move.w	#0,d0

loc_EDC4:
	move.w	d0,xvel(a0)

locret_EDC8:
	rts
; ---------------------------------------------------------------------------

ObjSonic_Squish:
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	bne.s	locret_EDF8
	bsr.w	ObjSonic_NoRunningOnWalls
	tst.w	d1
	bpl.s	locret_EDF8
	clr.w	inertia(a0)
	clr.w	xvel(a0)
	clr.w	yvel(a0)
	move.b	#$B,ani(a0)

locret_EDF8:
	rts
; ---------------------------------------------------------------------------

ObjSonic_LevelBound:
	move.l	xpos(a0),d1
	move.w	xvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	add.l	d0,d1
	swap	d1
	move.w	(unk_FFF728).w,d0
	addi.w	#$10,d0
	cmp.w	d1,d0
	bhi.s	ObjSonic_BoundSides
	move.w	(unk_FFF72A).w,d0
	addi.w	#$128,d0
	cmp.w	d1,d0
	bls.s	ObjSonic_BoundSides
	move.w	(unk_FFF72E).w,d0
	addi.w	#$E0,d0
	cmp.w	ypos(a0),d0
	bcs.w	loc_FD78
	rts
; ---------------------------------------------------------------------------

ObjSonic_BoundSides:
	move.w	d0,xpos(a0)
	clr.w	xpix(a0)
	clr.w	xvel(a0)
	clr.w	inertia(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_Roll:
	move.w	inertia(a0),d0
	bpl.s	loc_EE54
	neg.w	d0

loc_EE54:
	cmpi.w	#$80,d0
	bcs.s	locret_EE6C
	move.b	(padHeldPlayer).w,d0
	andi.b	#$C,d0
	bne.s	locret_EE6C
	btst	#JbD,(padHeldPlayer).w
	bne.s	ObjSonic_CheckRoll

locret_EE6C:
	rts
; ---------------------------------------------------------------------------

ObjSonic_CheckRoll:
	btst	#2,status(a0)
	beq.s	ObjSonic_DoRoll
	rts
; ---------------------------------------------------------------------------

ObjSonic_DoRoll:
	bset	#2,status(a0)
	move.b	#$E,yrad(a0)
	move.b	#7,xrad(a0)
	move.b	#2,ani(a0)
	addq.w	#5,ypos(a0)
	sfx	sfx_Roll
	tst.w	inertia(a0)
	bne.s	locret_EEAA
	move.w	#$200,inertia(a0)

locret_EEAA:
	rts
; ---------------------------------------------------------------------------

ObjSonic_Jump:
	move.b	(padPressPlayer).w,d0
	andi.b	#J_B|J_C|J_A,d0
	beq.w	locret_EF46
	moveq	#0,d0
	move.b	angle(a0),d0
	addi.b	#-$80,d0
	bsr.w	sub_10520
	cmpi.w	#6,d1
	blt.w	locret_EF46
	moveq	#0,d0
	move.b	angle(a0),d0
	subi.b	#$40,d0
	jsr (GetSine).l
	muls.w	#$680,d1
	asr.l	#8,d1
	add.w	d1,xvel(a0)
	muls.w	#$680,d0
	asr.l	#8,d0
	add.w	d0,yvel(a0)
	bset	#1,status(a0)
	bclr	#5,status(a0)
	addq.l	#4,sp
	st.b	jumping(a0)
	sfx	sfx_Jump
	move.b	#$13,yrad(a0)
	move.b	#9,xrad(a0)
	tst.b	(byte_FFD600).w
	bne.s	loc_EF48
	move.b	#$E,yrad(a0)
	move.b	#7,xrad(a0)
	move.b	#2,ani(a0)
	bset	#2,status(a0)
	addq.w	#5,ypos(a0)

locret_EF46:
	rts
; ---------------------------------------------------------------------------

loc_EF48:
	move.b	#$13,ani(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_JumpHeight:
	tst.b	jumping(a0)
	beq.s	loc_EF78
	cmpi.w	#$FC00,yvel(a0)
	bge.s	locret_EF76
	move.b	(padHeldPlayer).w,d0
	andi.b	#J_B|J_C|J_A,d0
	bne.s	locret_EF76
	move.w	#$FC00,yvel(a0)

locret_EF76:
	rts
; ---------------------------------------------------------------------------

loc_EF78:
	cmpi.w	#$F040,yvel(a0)
	bge.s	locret_EF86
	move.w	#$F040,yvel(a0)

locret_EF86:
	rts
; ---------------------------------------------------------------------------
; Subroutine to make Sonic perform a spindash
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


ObjSonic_SpinDash:
	tst.b	spindashflag(a0)
	bne.s	loc_1AC8E
	cmpi.b	#8,ani(a0)
	bne.s	locret_1AC8C
	move.b	(padHeldPlayer).w,d0
	andi.b	#J_B|J_C|J_A,d0
	beq.s	locret_1AC8C
	move.b	#2,ani(a0)
	sfx	sfx_Spindash
	addq.l	#4,sp
	move.b	#1,spindashflag(a0)
	move.w	#0,spindashtimer(a0)
	cmpi.b	#ypos,arg(a0)
	bcs.s	loc_1AC84
	move.b	#2,($FFFFD100+ani).w

loc_1AC84:
	bsr.w	ObjSonic_LevelBound
	bra.w	ObjSonic_AnglePosition

locret_1AC8C:
	rts 
; ---------------------------------------------------------------------------

loc_1AC8E:
	move.b	(padHeldPlayer).w,d0
	btst	#1,d0
	bne.w	loc_1AD30
	move.b	#$E,yrad(a0)
	move.b	#7,xrad(a0)
	move.b	#2,ani(a0)
	addq.w	#5,ypos(a0)
	move.b	#0,spindashflag(a0)
	moveq	#0,d0
	move.b	spindashtimer(a0),d0
	add.w	d0,d0
	move.w	Dash_Speeds(pc,d0.w),inertia(a0)
	move.w	inertia(a0),d0
	subi.w	#$800,d0
	add.w	d0,d0
	andi.w	#$1F00,d0
	neg.w	d0
	addi.w	#$2000,d0
	move.w	d0,($FFFFEED0).w
	btst	#0,status(a0)
	beq.s	loc_1ACF4
	neg.w	inertia(a0)

loc_1ACF4:
	bset	#2,status(a0)
	move.b	#0,($FFFFD100+ani).w
	sfx	sfx_Dash
	move.b	angle(a0),d0
	jsr (GetSine).l
	muls.w	inertia(a0),d1
	asr.l	#8,d1
	move.w	d1,xvel(a0)
	muls.w	inertia(a0),d0
	asr.l	#8,d0
	move.w	d0,yvel(a0)
	bra.s	loc_1AD78
; ===========================================================================
Dash_Speeds:	dc.w  $800	; 0
	dc.w  $880	; 1
	dc.w  $900	; 2
	dc.w  $980	; 3
	dc.w  $A00	; 4
	dc.w  $A80	; 5
	dc.w  $B00	; 6
	dc.w  $B80	; 7
	dc.w  $C00	; 8
; ===========================================================================

loc_1AD30:		; If still charging the dash...
	tst.w	spindashtimer(a0)
	beq.s	loc_1AD48
	move.w	spindashtimer(a0),d0
	lsr.w	#5,d0
	sub.w	d0,spindashtimer(a0)
	bcc.s	loc_1AD48
	move.w	#0,spindashtimer(a0)

loc_1AD48:
	move.b	(padPressPlayer).w,d0
	andi.b	#J_B|J_C|J_A,d0 ; 'p'
	beq.w	loc_1AD78
	sfx	sfx_Spindash
	addi.w	#$200,spindashtimer(a0)
	cmpi.w	#$800,spindashtimer(a0)
	bcs.s	loc_1AD78
	move.w	#$800,spindashtimer(a0)

loc_1AD78:
	addq.l	#4,sp
	cmpi.w	#$60,($FFFFEED8).w
	beq.s	loc_1AD8C
	bcc.s	loc_1AD88
	addq.w	#4,($FFFFEED8).w

loc_1AD88:
	subq.w	#2,($FFFFEED8).w

loc_1AD8C:
	bsr.w	ObjSonic_LevelBound
	bsr.w	ObjSonic_AnglePosition
	move.w	#$60,(unk_FFF73E).w ; reset looking up/down
	rts
; End of subroutine ObjSonic_SpinDash
; ---------------------------------------------------------------------------

ObjSonic_SlopeResist:
	move.b	angle(a0),d0
	addi.b	#$60,d0
	cmpi.b	#$C0,d0
	bcc.s	locret_EFBC
	move.b	angle(a0),d0
	jsr (GetSine).l
	muls.w	#$20,d0
	asr.l	#8,d0
	tst.w	inertia(a0)
	beq.s	locret_EFBC
	bmi.s	loc_EFB8
	tst.w	d0
	beq.s	locret_EFB6
	add.w	d0,inertia(a0)

locret_EFB6:
locret_EFBC:
	rts
; ---------------------------------------------------------------------------

loc_EFB8:
	add.w	d0,inertia(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_RollRepel:
	move.b	angle(a0),d0
	addi.b	#$60,d0
	cmpi.b	#$C0,d0
	bcc.s	locret_EFF8
	move.b	angle(a0),d0
	jsr (GetSine).l
	muls.w	#$50,d0
	asr.l	#8,d0
	tst.w	inertia(a0)
	bmi.s	loc_EFEE
	tst.w	d0
	bpl.s	loc_EFE8
	asr.l	#2,d0

loc_EFE8:
	add.w	d0,inertia(a0)
	rts
; ---------------------------------------------------------------------------

loc_EFEE:
	tst.w	d0
	bmi.s	loc_EFF4
	asr.l	#2,d0

loc_EFF4:
	add.w	d0,inertia(a0)

locret_EFF8:
	rts
; ---------------------------------------------------------------------------

ObjSonic_SlopeRepel:
	tst.w	lock(a0)
	bne.s	loc_F02C
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	beq.s	locret_F02A
	move.w	inertia(a0),d0
	bpl.s	loc_F018
	neg.w	d0

loc_F018:
	cmpi.w	#$280,d0
	bcc.s	locret_F02A
	bset	#1,status(a0)
	move.w	#$1E,lock(a0)

locret_F02A:
	rts
; ---------------------------------------------------------------------------

loc_F02C:
	subq.w	#1,lock(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_JumpAngle:
	move.b	angle(a0),d0
	beq.s	locret_F04C
	bpl.s	loc_F042
	addq.b	#2,d0
	bcc.s	loc_F048
	moveq	#0,d0
	bra.s	loc_F048
; ---------------------------------------------------------------------------

loc_F042:
	subq.b	#2,d0
	bcc.s	loc_F048
	moveq	#0,d0

loc_F048:
	move.b	d0,angle(a0)

locret_F04C:
	rts
; ---------------------------------------------------------------------------

ObjSonic_Floor:
	move.w	xvel(a0),d1
	move.w	yvel(a0),d2
	jsr (GetAngle).l
	subi.b	#$20,d0
	andi.b	#$C0,d0
	cmpi.b	#$40,d0
	beq.w	loc_F104
	cmpi.b	#$80,d0
	beq.w	loc_F160
	cmpi.b	#$C0,d0
	beq.w	loc_F1BC

loc_F07C:
	bsr.w	ObjSonic_HitWall
	tst.w	d1
	bpl.s	loc_F08E
	sub.w	d1,xpos(a0)
	clr.w	xvel(a0)

loc_F08E:
	bsr.w	sub_1068C
	tst.w	d1
	bpl.s	loc_F0A0
	add.w	d1,xpos(a0)
	clr.w	xvel(a0)

loc_F0A0:
	bsr.w	ObjSonic_HitFloor
	tst.w	d1
	bpl.s	locret_F102
	move.b	yvel(a0),d0
	addq.b	#8,d0
	neg.b	d0
	cmp.b	d0,d1
	blt.s	locret_F102
	add.w	d1,ypos(a0)
	move.b	d3,angle(a0)
	bsr.w	ObjSonic_ResetOnFloor
	move.b	#0,ani(a0)
	move.b	d3,d0
	addi.b	#$20,d0
	andi.b	#$40,d0
	bne.s	loc_F0E0
	move.w	#0,yvel(a0)
	move.w	xvel(a0),inertia(a0)
	rts
; ---------------------------------------------------------------------------

loc_F0E0:
	move.w	#0,xvel(a0)
	cmpi.w	#$FC0,yvel(a0)
	ble.s	loc_F0F4
	move.w	#$FC0,yvel(a0)

loc_F0F4:
	move.w	yvel(a0),inertia(a0)
	tst.b	d3
	bpl.s	locret_F102
	neg.w	inertia(a0)

locret_F102:
	rts
; ---------------------------------------------------------------------------

loc_F104:
	bsr.w	ObjSonic_HitWall
	tst.w	d1
	bpl.s	loc_F11E
	sub.w	d1,xpos(a0)
	move.w	#0,xvel(a0)
	move.w	yvel(a0),inertia(a0)
	rts
; ---------------------------------------------------------------------------

loc_F11E:
	bsr.w	ObjSonic_NoRunningOnWalls
	tst.w	d1
	bpl.s	loc_F132
	sub.w	d1,ypos(a0)
	move.w	#0,yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_F132:
	tst.w	yvel(a0)
	bmi.s	locret_F15E
	bsr.w	ObjSonic_HitFloor
	tst.w	d1
	bpl.s	locret_F15E
	add.w	d1,ypos(a0)
	move.b	d3,angle(a0)
	bsr.w	ObjSonic_ResetOnFloor
	move.b	#0,ani(a0)
	clr.w	yvel(a0)
	move.w	xvel(a0),inertia(a0)

locret_F15E:
	rts
; ---------------------------------------------------------------------------

loc_F160:
	bsr.w	ObjSonic_HitWall
	tst.w	d1
	bpl.s	loc_F172
	sub.w	d1,xpos(a0)
	move.w	#0,xvel(a0)

loc_F172:
	bsr.w	sub_1068C
	tst.w	d1
	bpl.s	loc_F184
	add.w	d1,xpos(a0)
	move.w	#0,xvel(a0)

loc_F184:
	bsr.w	ObjSonic_NoRunningOnWalls
	tst.w	d1
	bpl.s	locret_F1BA
	sub.w	d1,ypos(a0)
	move.b	d3,d0
	addi.b	#$20,d0
	andi.b	#$40,d0
	bne.s	loc_F1A4
	clr.w	yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_F1A4:
	move.b	d3,angle(a0)
	bsr.w	ObjSonic_ResetOnFloor
	move.w	yvel(a0),inertia(a0)
	tst.b	d3
	bpl.s	locret_F1BA
	neg.w	inertia(a0)

locret_F1BA:
	rts
; ---------------------------------------------------------------------------

loc_F1BC:
	bsr.w	sub_1068C
	tst.w	d1
	bpl.s	loc_F1D6
	add.w	d1,xpos(a0)
	clr.w	xvel(a0)
	move.w	yvel(a0),inertia(a0)
	rts
; ---------------------------------------------------------------------------

loc_F1D6:
	bsr.w	ObjSonic_NoRunningOnWalls
	tst.w	d1
	bpl.s	loc_F1EA
	sub.w	d1,ypos(a0)
	clr.w	yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_F1EA:
	tst.w	yvel(a0)
	bmi.s	locret_F216
	bsr.w	ObjSonic_HitFloor
	tst.w	d1
	bpl.s	locret_F216
	add.w	d1,ypos(a0)
	move.b	d3,angle(a0)
	bsr.w	ObjSonic_ResetOnFloor
	clr.b	ani(a0)
	clr.w	yvel(a0)
	move.w	xvel(a0),inertia(a0)

locret_F216:
	rts
; ---------------------------------------------------------------------------

ObjSonic_ResetOnFloor:
	bclr	#5,status(a0)
	bclr	#1,status(a0)
	btst	#2,status(a0)
	beq.s	loc_F25C
	bclr	#2,status(a0)
	move.b	#$13,yrad(a0)
	move.b	#9,xrad(a0)
	move.b	#0,ani(a0)
	subq.w	#5,ypos(a0)

loc_F25C:
	move.w	#0,lock(a0)
	move.b	#0,$3C(a0)
	rts
; ---------------------------------------------------------------------------

sub_F290:
	swap	d0
	rol.l	#4,d0
	andi.b	#$F,d0
	move.b	d0,frame(a1)
	rol.l	#4,d0
	andi.b	#$F,d0
	move.b	d0,$5A(a1)
	rol.l	#4,d0
	andi.b	#$F,d0
	move.b	d0,$9A(a1)
	rol.l	#4,d0
	andi.b	#$F,d0
	move.b	d0,$DA(a1)
	rts
; ---------------------------------------------------------------------------

ObjSonic_Hurt:
	bsr.w	ObjSonic_HurtStop
	bsr.w	ObjectMove
	addi.w	#$30,yvel(a0)
	bsr.w	ObjSonic_LevelBound
	bsr.w	sub_E952
	bsr.w	ObjSonic_Animate
	bsr.w	ObjSonic_DynTiles
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjSonic_HurtStop:
	move.w	(unk_FFF72E).w,d0
	addi.w	#$E0,d0
	cmp.w	ypos(a0),d0
	blo.w	loc_FD78
	bsr.w	loc_F07C
	btst	#1,status(a0)
	bne.s	locret_F318
	moveq	#0,d0
	move.w	d0,yvel(a0)
	move.w	d0,xvel(a0)
	move.w	d0,inertia(a0)
	move.b	#0,ani(a0)
	subq.b	#2,act(a0)
	move.b	#$78,invulnerable(a0)

locret_F318:
	rts
; ---------------------------------------------------------------------------

ObjSonic_Death:
	bsr.w	ObjSonic_GameOver
	bsr.w	ObjectFall
	bsr.w	sub_E952
	bsr.w	ObjSonic_Animate
	bsr.w	ObjSonic_DynTiles
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjSonic_GameOver:
	move.w	(CameraY).w,d0
	addi.w	#$100,d0
	cmp.w	ypos(a0),d0
	bpl.w	locret_F3AE
	move.w	#$FFC8,yvel(a0)
	addq.b	#2,act(a0)
	addq.b	#1,(byte_FFFE1C).w
	subq.b	#1,(Lives).w
	bne.s	loc_F380
	move.b	#0,$3A(a0)
	move.b	#$39,(byte_FFD080).w
	move.b	#$39,(byte_FFD0C0).w
	move.b	#1,(byte_FFD0C0+$1A).w
	music	mus_GameOver, 0
	moveq	#3,d0
	jmp (plcAdd).l
; ---------------------------------------------------------------------------

loc_F380:
	move.b	#$3C,$3A(a0)
; ---------------------------------------------------------------------------
	move.b	(padPressPlayer).w,d0
	andi.b	#J_B|J_C|J_A,d0
	beq.s	locret_F3AE
	andi.b	#$40,d0
	bne.s	loc_F3B0
	move.b	#0,ani(a0)
	subq.b	#4,act(a0)
	move.w	convex(a0),ypos(a0)
	move.b	#$78,invulnerable(a0)

locret_F3AE:
	rts
; ---------------------------------------------------------------------------

loc_F3B0:
	st.b	(LevelRestart).w
	rts
; ---------------------------------------------------------------------------

ObjSonic_ResetLevel:
	tst.b	$3A(a0)
	beq.s	locret_F3CA
	subq.b	#1,$3A(a0)
	bne.s	locret_F3CA
	st.b	(LevelRestart).w

locret_F3CA:
	rts
; ---------------------------------------------------------------------------
	dc.b $12, 9, $A, $12, 9, $A, $12, 9, $A, $12, 9, $A, $12
	dc.b 9, $A, $12, 9, $12, $E, 7, $A, $E, 7, $A
; ---------------------------------------------------------------------------

ObjSonic_SpecialChunk:
	cmpi.b	#3,(curzone).w
	beq.s	loc_F3F4
	tst.b	(curzone).w
	bne.w	locret_F490

loc_F3F4:
	move.w	ypos(a0),d0
	lsr.w	#1,d0
	andi.w	#$380,d0
	move.w	xpos(a0),d1
	move.w	d1,d2
	lsr.w	#8,d1
	andi.w	#$7F,d1
	add.w	d1,d0
	lea (Layout).w,a1
	move.b	(a1,d0.w),d1
	cmp.b	(unk_FFF7AE).w,d1
	beq.w	ObjSonic_CheckRoll
	cmp.b	(unk_FFF7AF).w,d1
	beq.w	ObjSonic_CheckRoll
	cmp.b	(unk_FFF7AC).w,d1
	beq.s	loc_F448
	cmp.b	(unk_FFF7AD).w,d1
	beq.s	loc_F438
	bclr	#6,render(a0)
	rts
; ---------------------------------------------------------------------------

loc_F438:
	btst	#1,status(a0)
	beq.s	loc_F448
	bclr	#6,render(a0)
	rts
; ---------------------------------------------------------------------------

loc_F448:
	cmpi.b	#$2C,d2
	bcc.s	loc_F456
	bclr	#6,render(a0)
	rts
; ---------------------------------------------------------------------------

loc_F456:
	cmpi.b	#$E0,d2
	bcs.s	loc_F464
	bset	#6,render(a0)
	rts
; ---------------------------------------------------------------------------

loc_F464:
	btst	#6,render(a0)
	bne.s	loc_F480
	move.b	angle(a0),d1
	beq.s	locret_F490
	cmpi.b	#$80,d1
	bhi.s	locret_F490
	bset	#6,render(a0)
	rts
; ---------------------------------------------------------------------------

loc_F480:
	move.b	angle(a0),d1
	cmpi.b	#$80,d1
	bls.s	locret_F490
	bclr	#6,render(a0)

locret_F490:
	rts
; ---------------------------------------------------------------------------

ObjSonic_Animate:
	lea (AniSonic).l,a1
	moveq	#0,d0
	move.b	ani(a0),d0
	cmp.b	anilast(a0),d0
	beq.s	ObjSonic_AnimDo
	move.b	d0,anilast(a0)
	clr.b	anipos(a0)
	clr.b	anidelay(a0)

ObjSonic_AnimDo:
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	move.b	(a1),d0
	bmi.s	ObjSonic_AnimateCmd
	move.b	status(a0),d1
	andi.b	#1,d1
	andi.b	#$FC,render(a0)
	or.b	d1,render(a0)
	subq.b	#1,anidelay(a0)
	bpl.s	ObjSonic_AnimDelay
	move.b	d0,anidelay(a0)
; ---------------------------------------------------------------------------

ObjSonic_AnimDo2:
	moveq	#0,d1
	move.b	anipos(a0),d1
	move.b	render(a1,d1.w),d0
	cmp.b	#$FD,d0
	bhs.s	ObjSonic_AnimEndFF

ObjSonic_AnimNext:
	move.b	d0,frame(a0)
	addq.b	#1,anipos(a0)

ObjSonic_AnimDelay:
	rts
; ---------------------------------------------------------------------------

ObjSonic_AnimEndFF:
	addq.b	#1,d0
	bne.s	ObjSonic_AnimFE
	move.b	#0,anipos(a0)
	move.b	render(a1),d0
	bra.s	ObjSonic_AnimNext
; ---------------------------------------------------------------------------

ObjSonic_AnimFE:
	addq.b	#1,d0
	bne.s	ObjSonic_AnimFD
	move.b	2(a1,d1.w),d0
	sub.b	d0,anipos(a0)
	sub.b	d0,d1
	move.b	render(a1,d1.w),d0
	bra.s	ObjSonic_AnimNext
; ---------------------------------------------------------------------------

ObjSonic_AnimFD:
	addq.b	#1,d0
	bne.s	ObjSonic_AnimEnd
	move.b	2(a1,d1.w),ani(a0)

ObjSonic_AnimEnd:
	rts
; ---------------------------------------------------------------------------

ObjSonic_AnimateCmd:
	subq.b	#1,anidelay(a0)
	bpl.s	ObjSonic_AnimDelay
	addq.b	#1,d0
	bne.w	ObjSonic_AnimRollJump
	moveq	#0,d1
	move.b	angle(a0),d0
	move.b	status(a0),d2
	andi.b	#1,d2
	bne.s	loc_F53E
	not.b	d0

loc_F53E:
	addi.b	#$10,d0
	bpl.s	loc_F546
	moveq	#3,d1

loc_F546:
	andi.b	#$FC,render(a0)
	eor.b	d1,d2
	or.b	d2,render(a0)
	btst	#5,status(a0)
	bne.w	ObjSonic_AnimPush
	lsr.b	#4,d0
	andi.b	#6,d0
	move.w	inertia(a0),d2
	bpl.s	loc_F56A
	neg.w	d2

loc_F56A:
	lea (byte_F654).l,a1
	cmpi.w	#$600,d2
	bcc.s	loc_F582
	lea (byte_F64C).l,a1
	move.b	d0,d1
	lsr.b	#1,d1
	add.b	d1,d0

loc_F582:
	add.b	d0,d0
	move.b	d0,d3
	neg.w	d2
	addi.w	#$800,d2
	bpl.s	loc_F590
	moveq	#0,d2

loc_F590:
	lsr.w	#8,d2
	move.b	d2,anidelay(a0)
	bsr.w	ObjSonic_AnimDo2
	add.b	d3,frame(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_AnimRollJump:
	addq.b	#1,d0
	bne.s	ObjSonic_AnimPush
	move.w	inertia(a0),d2
	bpl.s	loc_F5AC
	neg.w	d2

loc_F5AC:
	lea (byte_F664).l,a1
	cmpi.w	#$600,d2
	bcc.s	loc_F5BE
	lea (byte_F65C).l,a1

loc_F5BE:
	neg.w	d2
	addi.w	#$400,d2
	bpl.s	loc_F5C8
	moveq	#0,d2

loc_F5C8:
	lsr.w	#8,d2
	move.b	d2,anidelay(a0)
	move.b	status(a0),d1
	andi.b	#1,d1
	andi.b	#$FC,render(a0)
	or.b	d1,render(a0)
	bra.w	ObjSonic_AnimDo2
; ---------------------------------------------------------------------------

ObjSonic_AnimPush:
	move.w	inertia(a0),d2
	bmi.s	loc_F5EC
	neg.w	d2

loc_F5EC:
	addi.w	#$800,d2
	bpl.s	loc_F5F4
	moveq	#0,d2

loc_F5F4:
	lsr.w	#6,d2
	move.b	d2,anidelay(a0)

loc_F5FA:
	lea (byte_F66C).l,a1
	move.b	status(a0),d1
	andi.b	#1,d1
	andi.b	#$FC,render(a0)
	or.b	d1,render(a0)
	bra.w	ObjSonic_AnimDo2
; ---------------------------------------------------------------------------
	include "levels/shared/Sonic/Srite.ani"
	even
; ---------------------------------------------------------------------------

ObjSonic_DynTiles:	    ; XREF: Obj01_Control; et al
	moveq	#0,d0
	move.b	frame(a0),d0	; load frame number
	cmp.b  	(SonicLastDPLCID).w,d0
	beq.s	locret_13C96
	move.b	d0,(SonicLastDPLCID).w
	lea (DynMapSonic).l,a2
	add.w	d0,d0
	adda.w	(a2,d0.w),a2
	moveq	#0,d5
	move.b	(a2)+,d5
	subq.w	#1,d5
	bmi.s	locret_13C96
	move.w	#$F000,d4
	move.l	#ArtSonic,d6

ObjSonic_DynReadEntry:
	moveq	#0,d1
	move.b	(a2)+,d1
	lsl.w	#8,d1
	move.b	(a2)+,d1
	move.w	d1,d3
	lsr.w	#8,d3
	andi.w	#$F0,d3
	addi.w	#$10,d3
	andi.w	#$FFF,d1
	lsl.l	#5,d1
	add.l	d6,d1
	lsr.l 	#1,d1
	move.w	d4,d2
	add.w	d3,d4
	add.w	d3,d4
	jsr (QueueDMATransfer).l
	dbf d5,ObjSonic_DynReadEntry	; repeat for number of entries

locret_13C96:
	rts 
; End of function LoadSonicDynPLC
; ---------------------------------------------------------------------------

ObjShield:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjShield_Index(pc,d0.w),d1
	jmp ObjShield_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjShield_Index:dc.w ObjShield_Init-ObjShield_Index, ObjShield_Shield-ObjShield_Index, ObjShield_Stars-ObjShield_Index
; ---------------------------------------------------------------------------

ObjShield_Init:
	addq.b	#2,act(a0)
	move.l	#MapShield,map(a0)
	move.b	#4,render(a0)
	move.w	#$80,prio(a0)
	move.b	#$10,xpix(a0)
	tst.b	ani(a0)
	bne.s	loc_F786
	move.w	#$541,tile(a0)
	rts
; ---------------------------------------------------------------------------

loc_F786:
	addq.b	#2,act(a0)
	move.w	#$55C,tile(a0)
	rts
; ---------------------------------------------------------------------------

ObjShield_Shield:
	tst.b	(byte_FFFE2D).w
	bne.s	locret_F7C0
	tst.b	(byte_FFFE2C).w
	beq.s	ObjShield_Delete
	move.w	(ObjectsList+xpos).w,xpos(a0)
	move.w	(ObjectsList+ypos).w,ypos(a0)
	move.b	(ObjectsList+status).w,status(a0)
	lea (AniShield).l,a1
	jsr (ObjectAnimate).l
	bra.w	ObjectDisplay

locret_F7C0:
	rts
; ---------------------------------------------------------------------------

ObjShield_Delete:
	bra.w	ObjectDelete
; ---------------------------------------------------------------------------

ObjShield_Stars:
	tst.b	(byte_FFFE2D).w
	beq.w	ObjectDelete
	move.w	(unk_FFF7A8).w,d0
	move.b	ani(a0),d1
	subq.b	#1,d1

ObjShield_StarTrail:
	lsl.b	#3,d1
	move.b	d1,d2
	add.b	d1,d1
	add.b	d2,d1
	addq.b	#4,d1
	sub.b	d1,d0
	move.b	$30(a0),d1
	sub.b	d1,d0
	addq.b	#4,d1
	cmpi.b	#$18,d1
	bcs.s	ObjShield_StarTrail2
	moveq	#0,d1

ObjShield_StarTrail2:
	move.b	d1,$30(a0)

ObjShield_StarTrail2a:
	lea (SonicPosTable).w,a1
	lea (a1,d0.w),a1
	move.w	(a1)+,xpos(a0)
	move.w	(a1)+,ypos(a0)
	move.b	(ObjectsList+status).w,status(a0)
	lea (AniShield).l,a1
	jsr (ObjectAnimate).l
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjEntryRingBeta:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjEntryRingBeta_Index(pc,d0.w),d1
	jmp ObjEntryRingBeta_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjEntryRingBeta_Index:dc.w ObjEntryRingBeta_Init-ObjEntryRingBeta_Index, ObjEntryRingBeta_RmvSonic-ObjEntryRingBeta_Index
	dc.w ObjEntryRingBeta_LoadSonic-ObjEntryRingBeta_Index
; ---------------------------------------------------------------------------

ObjEntryRingBeta_Init:
	tst.l	(plcList).w
	beq.s	ObjEntryRingBeta_Init2
	rts
; ---------------------------------------------------------------------------

ObjEntryRingBeta_Init2:
	addq.b	#2,act(a0)
	move.l	#MapEntryRingBeta,map(a0)
	move.b	#4,render(a0)
	move.w	#$80,prio(a0)
	move.b	#$38,xpix(a0)
	move.w	#$541,tile(a0)
	move.b	#$78,$30(a0)

ObjEntryRingBeta_RmvSonic:
	move.w	(ObjectsList+xpos).w,xpos(a0)
	move.w	(ObjectsList+ypos).w,ypos(a0)
	move.b	(ObjectsList+status).w,status(a0)
	lea (AniEntryRingBeta).l,a1
	jsr (ObjectAnimate).l
	cmpi.b	#2,frame(a0)
	bne.w	ObjectDisplay
	tst.b	(ObjectsList).w
	beq.w	ObjectDisplay
	clr.b	(ObjectsList).w
	sfx	sfx_BigRing
	bra.w	ObjectDisplay
; ---------------------------------------------------------------------------

ObjEntryRingBeta_LoadSonic:
	subq.b	#1,$30(a0)
	bne.s	ObjEntryRingBeta_Wait
	move.b	#$10,(GameMode).w
; ---------------------------------------------------------------------------

ObjEntryRingBeta_Wait:
	rts
; ---------------------------------------------------------------------------
	include "levels/shared/Shield/Shield.ani"
	include "levels/shared/Shield/Shield.map"
	even
	include "levels/shared/SpecialRing/Sprite.ani"
	include "levels/shared/SpecialRing/Sprite.map"
	even
; ---------------------------------------------------------------------------

TouchObjects:
	moveq	#0,d5
	move.b	yrad(a0),d5
	subq.b	#3,d5
	move.w	xpos(a0),d2
	move.w	ypos(a0),d3
	subq.w	#8,d2
	sub.w	d5,d3
	move.w	#$10,d4
	add.w	d5,d5
	lea (LevelObjectsList).w,a1
	move.w	#$5F,d6

loc_FB6E:
	tst.b	render(a1)
	bpl.s	loc_FB7A
	move.b	col(a1),d0
	bne.s	loc_FBB8

loc_FB7A:
	lea size(a1),a1
	dbf d6,loc_FB6E
	moveq	#0,d0

locret_FB84:
	rts
	dc.b $14, $14
	dc.b $C, $14
	dc.b $14, $C
	dc.b 4, $10
	dc.b $C, $12
	dc.b $10, $10
	dc.b 6, 6
	dc.b $18, $C
	dc.b $C, $10
	dc.b $10, $C
	dc.b 8, 8
	dc.b $14, $10
	dc.b $14, 8
	dc.b $E, $E
	dc.b $18, $18
	dc.b $28, $10
	dc.b $10, $18
	dc.b $C, $20
	dc.b $20, $70
	dc.b $40, $20
	dc.b $80, $20
	dc.b $20, $20
	dc.b 8, 8
	dc.b 4, 4
	dc.b $20, 8
; ---------------------------------------------------------------------------

loc_FBB8:
	andi.w	#$3F,d0
	add.w	d0,d0
	lea locret_FB84(pc,d0.w),a2
	moveq	#0,d1
	move.b	(a2)+,d1
	move.w	xpos(a1),d0
	sub.w	d1,d0
	sub.w	d2,d0
	bcc.s	loc_FBD8
	add.w	d1,d1
	add.w	d1,d0
	bcs.s	loc_FBDC
	bra.s	loc_FB7A
; ---------------------------------------------------------------------------

loc_FBD8:
	cmp.w	d4,d0
	bhi.s	loc_FB7A

loc_FBDC:
	moveq	#0,d1
	move.b	(a2)+,d1
	move.w	ypos(a1),d0
	sub.w	d1,d0
	sub.w	d3,d0
	bcc.s	loc_FBF2
	add.w	d1,d1
	add.w	d0,d1
	bcs.s	loc_FBF6
	bra.s	loc_FB7A
; ---------------------------------------------------------------------------

loc_FBF2:
	cmp.w	d5,d0
	bhi.s	loc_FB7A

loc_FBF6:
	move.b	col(a1),d1
	andi.b	#$C0,d1
	beq.w	loc_FC6A
	cmpi.b	#$C0,d1
	beq.w	loc_FDC4
	tst.b	d1
	bmi.w	loc_FCE0
	move.b	col(a1),d0
	andi.b	#$3F,d0
	cmpi.b	#6,d0
	beq.s	loc_FC2E
	cmpi.w	#$5A,$30(a0)
	bcc.w	locret_FC2C
	addq.b	#2,act(a1)

locret_FC2C:
	rts
; ---------------------------------------------------------------------------

loc_FC2E:
	tst.w	yvel(a0)
	bpl.s	loc_FC58
	move.w	ypos(a0),d0
	subi.w	#$10,d0
	cmp.w	ypos(a1),d0
	bcs.s	locret_FC68
	neg.w	yvel(a0)
	move.w	#$FE80,yvel(a1)
	tst.b	subact(a1)
	bne.s	locret_FC68
	addq.b	#4,subact(a1)
	rts
; ---------------------------------------------------------------------------

loc_FC58:
	cmpi.b	#2,ani(a0)
	bne.s	locret_FC68
	neg.w	yvel(a0)
	addq.b	#2,act(a1)

locret_FC68:
	rts
; ---------------------------------------------------------------------------

loc_FC6A:
	tst.b	(byte_FFFE2D).w
	bne.s	loc_FC78
	cmpi.b	#9,ani(a0)
	beq.s	loc_FC78
	cmpi.b	#2,ani(a0)
	bne.s	loc_FCE0

loc_FC78:
	tst.b	colprop(a1)
	beq.s	loc_FCA2
	neg.w	xvel(a0)
	neg.w	yvel(a0)
	asr xvel(a0)
	asr yvel(a0)
	move.b	#0,col(a1)
	subq.b	#1,colprop(a1)
	bne.s	locret_FCA0
	bset	#7,status(a1)

locret_FCA0:
	rts
; ---------------------------------------------------------------------------

loc_FCA2:
	bset	#7,status(a1)
	moveq	#$A,d0
	bsr.w	ScoreAdd
	move.b	#$27,id(a1)
	move.b	#0,act(a1)
	tst.w	yvel(a0)
	bmi.s	loc_FCD0
	move.w	ypos(a0),d0
	cmp.w	ypos(a1),d0
	bcc.s	loc_FCD8
	neg.w	yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_FCD0:
	addi.w	#$100,yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_FCD8:
	subi.w	#$100,yvel(a0)
	rts
; ---------------------------------------------------------------------------

loc_FCE0:
	tst.b	(byte_FFFE2D).w
	beq.s	loc_FCEA

loc_FCE6:
	moveq	#-1,d0
	rts
; ---------------------------------------------------------------------------

loc_FCEA:
	tst.b	invulnerable(a0)
	bne.s	loc_FCE6
	movea.l a1,a2

loc_FCF4:
	tst.b	(byte_FFFE2C).w
	bne.s	loc_FD18
	tst.w	(Rings).w
	beq.s	loc_FD72
	bsr.w	ObjectLoad
	bne.s	loc_FD18
	move.b	#$37,id(a1)
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)

loc_FD18:
	clr.b	(byte_FFFE2C).w
	move.b	#4,act(a0)
	bsr.w	ObjSonic_ResetOnFloor
	bset	#1,status(a0)
	move.w	#$FC00,yvel(a0)
	move.w	#$FE00,xvel(a0)
	move.w	xpos(a0),d0
	cmp.w	xpos(a2),d0
	bcs.s	loc_FD48
	neg.w	xvel(a0)

loc_FD48:
	clr.w	inertia(a0)
	move.b	#$1A,ani(a0)
	move.b	#-1,invulnerable(a0)
	moveq	#sfx_Death,d0
	cmpi.b	#$36,(a2)
	bne.s	loc_FD68
	moveq	#sfx_SpikeHit,d0

loc_FD68:
	move.b	d0,mQueue+2.w		
	moveq	#-1,d0	
	rts
; ---------------------------------------------------------------------------

loc_FD72:
	tst.w	(EditModeFlag).w
	bne.s	loc_FD18

loc_FD78:
	tst.w	(DebugRoutine).w
	bne.s	loc_FDC0
	move.w	(unk_FFF726).w,d0
	move.w	(unk_FFF72E).w,d1
	cmp.w	d0,d1
	blt.s	loc_FDC0
	move.b	#6,act(a0)
	bsr.w	ObjSonic_ResetOnFloor
	clr.w	(byte_FFFE2C).w
	bset	#1,status(a0)
	move.w	#$F900,yvel(a0)
	clr.w	xvel(a0)
	clr.w	inertia(a0)
	move.w	ypos(a0),convex(a0)
	move.b	#$18,ani(a0)
	moveq	#sfx_Death,d0
	cmpi.b	#$36,(a2)
	bne.s	loc_FDBA
	moveq	#sfx_SpikeHit,d0

loc_FDBA:
	move.b	d0,mQueue+2.w
	tst.b	(unk_FFF7AA).w	  ; is boss mode on?
	bne.s	loc_FDC0    ; if yes, branch 
	st.b  	(DontIntMus).w

loc_FDC0:
	moveq	#-1,d0
	rts
; ---------------------------------------------------------------------------

loc_FDC4:
	move.b	col(a1),d1
	andi.b	#$3F,d1
	cmpi.b	#$C,d1
	beq.s	loc_FDDA
	cmpi.b	#$17,d1
	beq.s	loc_FE0C
	rts
; ---------------------------------------------------------------------------

loc_FDDA:
	sub.w	d0,d5
	cmpi.w	#8,d5
	bcc.s	loc_FE08
	move.w	xpos(a1),d0
	subq.w	#4,d0
	btst	#0,status(a1)
	beq.s	loc_FDF4
	subi.w	#$10,d0

loc_FDF4:
	sub.w	d2,d0
	bcc.s	loc_FE00
	addi.w	#$18,d0
	bcs.s	loc_FE04
	bra.s	loc_FE08
; ---------------------------------------------------------------------------

loc_FE00:
	cmp.w	d4,d0
	bhi.s	loc_FE08

loc_FE04:
	bra.w	loc_FCE0
; ---------------------------------------------------------------------------

loc_FE08:
	bra.w	loc_FC6A
; ---------------------------------------------------------------------------

loc_FE0C:
	addq.b	#1,colprop(a1)
	rts
; ---------------------------------------------------------------------------

ObjSonic_AnglePosition:
	btst	#3,status(a0)
	beq.s	loc_FE26
	moveq	#0,d0
	move.b	d0,(unk_FFF768).w
	move.b	d0,(unk_FFF76A).w
	rts
; ---------------------------------------------------------------------------

loc_FE26:
	moveq	#3,d0
	move.b	d0,(unk_FFF768).w
	move.b	d0,(unk_FFF76A).w
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	cmpi.b	#$40,d0
	beq.w	ObjSonic_WalkVertL
	cmpi.b	#$80,d0
	beq.w	ObjSonic_WalkCeiling
	cmpi.b	#$C0,d0
	beq.w	ObjSonic_WalkVertR
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF768).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	xrad(a0),d0
	ext.w	d0
	neg.w	d0
	add.w	d0,d3
	lea (unk_FFF76A).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.w	(sp)+,d0
	bsr.w	ObjSonic_Angle
	tst.w	d1
	beq.s	locret_FEC6
	bpl.s	loc_FEC8
	cmpi.w	#$FFF2,d1
	blt.s	locret_FEE8
	add.w	d1,ypos(a0)

locret_FEC6:
locret_FEE8:
locret_FF0C:
	rts
; ---------------------------------------------------------------------------

loc_FEC8:
	cmpi.w	#$E,d1
	bgt.s	loc_FED4
	add.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_FED4:
	bset	#1,status(a0)
	bclr	#5,status(a0)
	move.b	#1,anilast(a0)
	rts
; ---------------------------------------------------------------------------

sub_FF2C:
	move.l	xpos(a0),d2
	move.l	ypos(a0),d3
	move.w	xvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	sub.l	d0,d2

loc_FF3E:
	move.w	yvel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	sub.l	d0,d3
	move.l	d2,xpos(a0)
	move.l	d3,ypos(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_Angle:
	move.b	(unk_FFF76A).w,d2
	cmp.w	d0,d1
	ble.s	loc_FF60
	move.b	(unk_FFF768).w,d2
	move.w	d0,d1

loc_FF60:
	btst	#0,d2

loc_FF64:
	bne.s	loc_FF6C
	move.b	d2,angle(a0)
	rts
; ---------------------------------------------------------------------------

loc_FF6C:
	move.b	angle(a0),d2
	addi.b	#$20,d2
	andi.b	#$C0,d2
	move.b	d2,angle(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_WalkVertR:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0

loc_FF88:
	move.b	xrad(a0),d0
	ext.w	d0
	neg.w	d0
	add.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF768).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5
	bsr.w	FindFloor
	move.w	d1,-(sp)

loc_FFAE:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF76A).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5

loc_FFD6:
	bsr.w	FindFloor
	move.w	(sp)+,d0
	bsr.w	ObjSonic_Angle
	tst.w	d1
	beq.s	locret_FFF2
	bpl.s	loc_FFF4
	cmpi.w	#$FFF2,d1
	blt.w	locret_FF0C
	add.w	d1,xpos(a0)

locret_FFF2:
	rts
; ---------------------------------------------------------------------------

loc_FFF4:
	cmpi.w	#$E,d1
	bgt.s	loc_10000
	add.w	d1,xpos(a0)

locret_FFFE:
	rts
; ---------------------------------------------------------------------------

loc_10000:
	bset	#1,status(a0)
	bclr	#5,status(a0)
	move.b	#1,anilast(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_WalkCeiling:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	eori.w	#$F,d2
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$1000,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	eori.w	#$F,d2
	move.b	xrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	lea (unk_FFF76A).w,a4
	movea.w #$FFF0,a3
	move.w	#$1000,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.w	(sp)+,d0
	bsr.w	ObjSonic_Angle
	tst.w	d1
	beq.s	locret_1008E
	bpl.s	loc_10090
	cmpi.w	#$FFF2,d1
	blt.w	locret_FEE8
	sub.w	d1,ypos(a0)

locret_1008E:
	rts
; ---------------------------------------------------------------------------

loc_10090:
	cmpi.w	#$E,d1
	bgt.s	loc_1009C
	sub.w	d1,ypos(a0)
	rts
; ---------------------------------------------------------------------------

loc_1009C:
	bset	#1,status(a0)
	bclr	#5,status(a0)
	move.b	#1,anilast(a0)
	rts
; ---------------------------------------------------------------------------

ObjSonic_WalkVertL:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	eori.w	#$F,d3
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$800,d6
	moveq	#$D,d5
	bsr.w	FindFloor
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	eori.w	#$F,d3
	lea (unk_FFF76A).w,a4
	movea.w #$FFF0,a3
	move.w	#$800,d6
	moveq	#$D,d5
	bsr.w	FindFloor
	move.w	(sp)+,d0
	bsr.w	ObjSonic_Angle
	tst.w	d1
	beq.s	locret_1012A
	bpl.s	loc_1012C
	cmpi.w	#$FFF2,d1
	blt.w	locret_FF0C
	sub.w	d1,xpos(a0)

locret_1012A:
	rts
; ---------------------------------------------------------------------------

loc_1012C:
	cmpi.w	#$E,d1
	bgt.s	loc_10138
	sub.w	d1,xpos(a0)
	rts
; ---------------------------------------------------------------------------

loc_10138:
	bset	#1,status(a0)
	bclr	#5,status(a0)
	move.b	#1,anilast(a0)
	rts
; ---------------------------------------------------------------------------

Floor_ChkTile:
	move.w	d2,d0
	lsr.w	#1,d0
	andi.w	#$380,d0
	move.w	d3,d1
	lsr.w	#8,d1
	andi.w	#$7F,d1
	add.w	d1,d0
	moveq	#$FFFFFFFF,d1
	lea (Layout).w,a1
	move.b	(a1,d0.w),d1
	beq.s	loc_10186
	bmi.s	loc_1018A
	subq.b	#1,d1
	ext.w	d1
	ror.w	#7,d1
	move.w	d2,d0
	add.w	d0,d0
	andi.w	#$1E0,d0
	add.w	d0,d1
	move.w	d3,d0
	lsr.w	#3,d0
	andi.w	#$1E,d0
	add.w	d0,d1

loc_10186:
	movea.l d1,a1
	rts
; ---------------------------------------------------------------------------

loc_1018A:
	andi.w	#$7F,d1
	btst	#6,render(a0)
	beq.s	loc_101A2
	addq.w	#1,d1
	cmpi.w	#$29,d1
	bne.s	loc_101A2
	move.w	#$51,d1

loc_101A2:
	subq.b	#1,d1
	ror.w	#7,d1
	move.w	d2,d0
	add.w	d0,d0
	andi.w	#$1E0,d0
	add.w	d0,d1
	move.w	d3,d0
	lsr.w	#3,d0
	andi.w	#$1E,d0
	add.w	d0,d1
	movea.l d1,a1
	rts
; ---------------------------------------------------------------------------

sub_101BE:
	bsr.s	Floor_ChkTile
	move.w	(a1),d0
	move.w	d0,d4
	andi.w	#$7FF,d0
	beq.s	loc_101CE
	btst	d5,d4
	bne.s	loc_101DC

loc_101CE:
	add.w	a3,d2
	bsr.w	sub_10264
	sub.w	a3,d2
	addi.w	#$10,d1
	rts
; ---------------------------------------------------------------------------

loc_101DC:
	movea.l (Collision).w,a2
	move.b	(a2,d0.w),d0
	andi.w	#$FF,d0
	beq.s	loc_101CE
	lea (colAngles).l,a2
	move.b	(a2,d0.w),(a4)
	lsl.w	#4,d0
	move.w	d3,d1
	btst	#$B,d4
	beq.s	loc_10202
	not.w	d1
	neg.b	(a4)

loc_10202:
	btst	#$C,d4
	beq.s	loc_10212
	addi.b	#$40,(a4)
	neg.b	(a4)
	subi.b	#$40,(a4)

loc_10212:
	andi.w	#$F,d1
	add.w	d0,d1
	lea (colWidth).l,a2
	move.b	(a2,d1.w),d0
	ext.w	d0
	eor.w	d6,d4
	btst	#$C,d4
	beq.s	loc_1022E
	neg.w	d0

loc_1022E:
	tst.w	d0
	beq.s	loc_101CE
	bmi.s	loc_1024A
	cmpi.b	#$10,d0
	beq.s	loc_10256
	move.w	d2,d1
	andi.w	#$F,d1
	add.w	d1,d0
	move.w	#$F,d1
	sub.w	d0,d1
	rts
; ---------------------------------------------------------------------------

loc_1024A:
	move.w	d2,d1
	andi.w	#$F,d1
	add.w	d1,d0
	bpl.w	loc_101CE

loc_10256:
	sub.w	a3,d2
	bsr.w	sub_10264
	add.w	a3,d2
	subi.w	#$10,d1
	rts
; ---------------------------------------------------------------------------

sub_10264:
	bsr.w	Floor_ChkTile
	move.w	(a1),d0
	move.w	d0,d4
	andi.w	#$7FF,d0
	beq.s	loc_10276
	btst	d5,d4
	bne.s	loc_10284

loc_10276:
	move.w	#$F,d1
	move.w	d2,d0
	andi.w	#$F,d0
	sub.w	d0,d1
	rts
; ---------------------------------------------------------------------------

loc_10284:
	movea.l (Collision).w,a2
	move.b	(a2,d0.w),d0
	andi.w	#$FF,d0
	beq.s	loc_10276
	lea (colAngles).l,a2
	move.b	(a2,d0.w),(a4)
	lsl.w	#4,d0
	move.w	d3,d1
	btst	#$B,d4
	beq.s	loc_102AA
	not.w	d1
	neg.b	(a4)

loc_102AA:
	btst	#$C,d4
	beq.s	loc_102BA
	addi.b	#$40,(a4)
	neg.b	(a4)
	subi.b	#$40,(a4)

loc_102BA:
	andi.w	#$F,d1
	add.w	d0,d1
	lea (colWidth).l,a2
	move.b	(a2,d1.w),d0
	ext.w	d0
	eor.w	d6,d4
	btst	#$C,d4
	beq.s	loc_102D6
	neg.w	d0

loc_102D6:
	tst.w	d0
	beq.s	loc_10276
	bmi.s	loc_102EC
	move.w	d2,d1
	andi.w	#$F,d1
	add.w	d1,d0
	move.w	#$F,d1
	sub.w	d0,d1
	rts
; ---------------------------------------------------------------------------

loc_102EC:
	move.w	d2,d1
	andi.w	#$F,d1
	add.w	d1,d0
	bpl.w	loc_10276
	not.w	d1
	rts
; ---------------------------------------------------------------------------

FindFloor:
	bsr.w	Floor_ChkTile
	move.w	(a1),d0
	move.w	d0,d4
	andi.w	#$7FF,d0
	beq.s	loc_1030E
	btst	d5,d4
	bne.s	loc_1031C

loc_1030E:
	add.w	a3,d3
	bsr.w	FindFloor2
	sub.w	a3,d3
	addi.w	#$10,d1
	rts
; ---------------------------------------------------------------------------

loc_1031C:
	movea.l (Collision).w,a2
	move.b	(a2,d0.w),d0
	andi.w	#$FF,d0
	beq.s	loc_1030E
	lea (colAngles).l,a2
	move.b	(a2,d0.w),(a4)
	lsl.w	#4,d0
	move.w	d2,d1
	btst	#$C,d4
	beq.s	loc_1034A
	not.w	d1
	addi.b	#$40,(a4)
	neg.b	(a4)
	subi.b	#$40,(a4)

loc_1034A:
	btst	#$B,d4
	beq.s	loc_10352
	neg.b	(a4)

loc_10352:
	andi.w	#$F,d1
	add.w	d0,d1
	lea (colHeight).l,a2
	move.b	(a2,d1.w),d0
	ext.w	d0
	eor.w	d6,d4
	btst	#$B,d4
	beq.s	loc_1036E
	neg.w	d0

loc_1036E:
	tst.w	d0
	beq.s	loc_1030E
	bmi.s	loc_1038A
	cmpi.b	#$10,d0
	beq.s	loc_10396
	move.w	d3,d1
	andi.w	#$F,d1
	add.w	d1,d0
	move.w	#$F,d1
	sub.w	d0,d1
	rts
; ---------------------------------------------------------------------------

loc_1038A:
	move.w	d3,d1
	andi.w	#$F,d1
	add.w	d1,d0
	bpl.w	loc_1030E

loc_10396:
	sub.w	a3,d3
	bsr.w	FindFloor2
	add.w	a3,d3
	subi.w	#$10,d1
	rts
; ---------------------------------------------------------------------------

FindFloor2:
	bsr.w	Floor_ChkTile
	move.w	(a1),d0
	move.w	d0,d4
	andi.w	#$7FF,d0
	beq.s	loc_103B6
	btst	d5,d4
	bne.s	loc_103C4

loc_103B6:
	move.w	#$F,d1
	move.w	d3,d0
	andi.w	#$F,d0
	sub.w	d0,d1
	rts
; ---------------------------------------------------------------------------

loc_103C4:
	movea.l (Collision).w,a2
	move.b	(a2,d0.w),d0
	andi.w	#$FF,d0
	beq.s	loc_103B6
	lea (colAngles).l,a2
	move.b	(a2,d0.w),(a4)
	lsl.w	#4,d0
	move.w	d2,d1
	btst	#$C,d4
	beq.s	loc_103F2
	not.w	d1
	addi.b	#$40,(a4)
	neg.b	(a4)
	subi.b	#$40,(a4)

loc_103F2:
	btst	#$B,d4
	beq.s	loc_103FA
	neg.b	(a4)

loc_103FA:
	andi.w	#$F,d1
	add.w	d0,d1
	lea (colHeight).l,a2
	move.b	(a2,d1.w),d0
	ext.w	d0
	eor.w	d6,d4
	btst	#$B,d4
	beq.s	loc_10416
	neg.w	d0

loc_10416:
	tst.w	d0
	beq.s	loc_103B6
	bmi.s	loc_1042C
	move.w	d3,d1
	andi.w	#$F,d1
	add.w	d1,d0
	move.w	#$F,d1
	sub.w	d0,d1
	rts
; ---------------------------------------------------------------------------

loc_1042C:
	move.w	d3,d1
	andi.w	#$F,d1
	add.w	d1,d0
	bpl.w	loc_103B6
	not.w	d1
	rts
; ---------------------------------------------------------------------------

ObjSonic_WalkSpeed:
	move.l	xpos(a0),d3
	move.l	ypos(a0),d2
	move.w	xvel(a0),d1
	ext.l	d1
	asl.l	#8,d1
	add.l	d1,d3
	move.w	yvel(a0),d1
	ext.l	d1
	asl.l	#8,d1
	add.l	d1,d2
	swap	d2
	swap	d3
	move.b	d0,(unk_FFF768).w
	move.b	d0,(unk_FFF76A).w
	move.b	d0,d1
	addi.b	#$20,d0
	andi.b	#$C0,d0
	beq.w	loc_105C8
	cmpi.b	#$80,d0
	beq.w	loc_10754
	andi.b	#$38,d1
	bne.s	loc_10514
	addq.w	#8,d2

loc_10514:
	cmpi.b	#$40,d0
	beq.w	loc_10822
	bra.w	loc_10694
; ---------------------------------------------------------------------------

sub_10520:
	move.b	d0,(unk_FFF768).w
	move.b	d0,(unk_FFF76A).w
	addi.b	#$20,d0
	andi.b	#$C0,d0
	cmpi.b	#$40,d0
	beq.w	loc_107AE
	cmpi.b	#$80,d0
	beq.w	ObjSonic_NoRunningOnWalls
	cmpi.b	#$C0,d0
	beq.w	loc_10628

ObjSonic_HitFloor:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF768).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	xrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	lea (unk_FFF76A).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.w	(sp)+,d0
	move.b	#0,d2

loc_105A8:
	move.b	(unk_FFF76A).w,d3
	cmp.w	d0,d1
	ble.s	loc_105B6
	move.b	(unk_FFF768).w,d3
	move.w	d0,d1

loc_105B6:
	btst	#0,d3
	beq.s	locret_105BE
	move.b	d2,d3

locret_105BE:
	rts
; ---------------------------------------------------------------------------

loc_105C8:
	addi.w	#$A,d2
	lea (unk_FFF768).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$E,d5
	bsr.w	sub_101BE
	move.b	#0,d2

loc_105E2:
	move.b	(unk_FFF768).w,d3
	btst	#0,d3
	beq.s	locret_105EE
	move.b	d2,d3

locret_105EE:
	rts
; ---------------------------------------------------------------------------

ObjectHitFloor:
	move.w	xpos(a0),d3

ObjectHitFloor2:
	move.w	ypos(a0),d2
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	lea (unk_FFF768).w,a4
	move.b	#0,(a4)
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$D,d5
	bsr.w	sub_101BE
	move.b	(unk_FFF768).w,d3
	btst	#0,d3
	beq.s	locret_10626
	move.b	#0,d3

locret_10626:
	rts
; ---------------------------------------------------------------------------

loc_10628:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF768).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF76A).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.w	(sp)+,d0
	move.b	#$C0,d2
	bra.w	loc_105A8
; ---------------------------------------------------------------------------

sub_1068C:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3

loc_10694:
	addi.w	#$A,d3
	lea (unk_FFF768).w,a4
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.b	#$C0,d2
	bra.w	loc_105E2
; ---------------------------------------------------------------------------

ObjectHitWallRight:
	add.w	xpos(a0),d3
	move.w	ypos(a0),d2
	lea (unk_FFF768).w,a4
	move.b	#0,(a4)
	movea.w #$10,a3
	move.w	#0,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.b	(unk_FFF768).w,d3
	btst	#0,d3
	beq.s	locret_106DE
	move.b	#$C0,d3

locret_106DE:
	rts
; ---------------------------------------------------------------------------

ObjSonic_NoRunningOnWalls:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	eori.w	#$F,d2
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d3
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$1000,d6
	moveq	#$E,d5
	bsr.w	sub_101BE
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	eori.w	#$F,d2
	move.b	xrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	lea (unk_FFF76A).w,a4
	movea.w #$FFF0,a3
	move.w	#$1000,d6
	moveq	#$E,d5
	bsr.w	sub_101BE
	move.w	(sp)+,d0
	move.b	#$80,d2
	bra.w	loc_105A8
; ---------------------------------------------------------------------------

loc_10754:
	subi.w	#$A,d2
	eori.w	#$F,d2
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$1000,d6
	moveq	#$E,d5
	bsr.w	sub_101BE
	move.b	#$80,d2
	bra.w	loc_105E2
; ---------------------------------------------------------------------------

ObjectHitCeiling:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	eori.w	#$F,d2
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$1000,d6
	moveq	#$E,d5
	bsr.w	sub_101BE
	move.b	(unk_FFF768).w,d3
	btst	#0,d3
	beq.s	locret_107AC
	move.b	#$80,d3

locret_107AC:
	rts
; ---------------------------------------------------------------------------

loc_107AE:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	sub.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	eori.w	#$F,d3
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$800,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.w	d1,-(sp)
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3
	moveq	#0,d0
	move.b	xrad(a0),d0
	ext.w	d0
	add.w	d0,d2
	move.b	yrad(a0),d0
	ext.w	d0
	sub.w	d0,d3
	eori.w	#$F,d3
	lea (unk_FFF76A).w,a4
	movea.w #$FFF0,a3
	move.w	#$800,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.w	(sp)+,d0
	move.b	#$40,d2
	bra.w	loc_105A8
; ---------------------------------------------------------------------------

ObjSonic_HitWall:
	move.w	ypos(a0),d2
	move.w	xpos(a0),d3

loc_10822:
	subi.w	#$A,d3
	eori.w	#$F,d3
	lea (unk_FFF768).w,a4
	movea.w #$FFF0,a3
	move.w	#$800,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.b	#$40,d2
	bra.w	loc_105E2
; ---------------------------------------------------------------------------

ObjectHitWallLeft:
	add.w	xpos(a0),d3
	move.w	ypos(a0),d2
	lea (unk_FFF768).w,a4
	move.b	#0,(a4)
	movea.w #$FFF0,a3
	move.w	#$800,d6
	moveq	#$E,d5
	bsr.w	FindFloor
	move.b	(unk_FFF768).w,d3
	btst	#0,d3
	beq.s	locret_10870
	move.b	#$40,d3

locret_10870:
	rts
; ---------------------------------------------------------------------------

ObjCredits:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjCredits_Index(pc,d0.w),d1
	jmp	ObjCredits_Index(pc,d1.w)
; ===========================================================================
ObjCredits_Index:    dc.w ObjCredits_Main-ObjCredits_Index
	dc.w ObjCredits_Display-ObjCredits_Index
; ===========================================================================

ObjCredits_Main:	     ; XREF: ObjCredits_Index
	addq.b	#2,act(a0)
	move.w	#$120,xpos(a0)
	move.w	#$F0,xpix(a0)
	move.l	#Map_Credits,map(a0)
	move.w	#$5A0,tile(a0)
	move.w	(CreditsIndex).w,d0  ; load  credits index number
	move.b	d0,frame(a0)		; display appropriate sprite
	move.b	#0,render(a0)
	move.b	#16,xpix(a0)
	move.w	#0,prio(a0)
	cmpi.b	#4,(GameMode).w ; is the scene	number 04 (title screen)?
	jne	ObjectDisplay	    ; if not, branch
	move.w	#$A6,tile(a0)
	move.b	#$A,frame(a0)		; display "SONIC TEAM PRESENTS"
; ===========================================================================

ObjCredits_Display:		 ; XREF: ObjCredits_Index
	jmp	ObjectDisplay
; ===========================================================================
; ---------------------------------------------------------------------------
; Sprite mappings - "SONIC TEAM PRESENTS" and credits
; ---------------------------------------------------------------------------
Map_Credits:
	include "screens\credits\CreditsText\Sprite.map"
	even
; ---------------------------------------------------------------------------

ZoneAnimTiles:
	tst.b	(PauseFlag).w
	bmi.s	locret_112A8
	lea (VdpData).l,a6
	moveq	#0,d0
	move.b	(curzone).w,d0
	add.w	d0,d0
	move.w	off_112AA(pc,d0.w),d0
	jmp off_112AA(pc,d0.w)
; ---------------------------------------------------------------------------

locret_112A8:
	rts
; ---------------------------------------------------------------------------

off_112AA:  dc.w loc_112B8-off_112AA, locret_11482-off_112AA, loc_11376-off_112AA, locret_11482-off_112AA
	dc.w locret_11482-off_112AA, locret_11482-off_112AA, locret_11482-off_112AA
; ---------------------------------------------------------------------------

loc_112B8:
	subq.b	#1,(unk_FFF7B1).w
	bpl.s	loc_112EE
	move.b	#5,(unk_FFF7B1).w
	lea (byte_6B018).l,a1
	move.b	(unk_FFF7B0).w,d0
	addq.b	#1,(unk_FFF7B0).w
	andi.w	#1,d0
	beq.s	loc_112DC
	lea $100(a1),a1

loc_112DC:
	move.l	#$6F000001,(VdpCtrl).l
	move.w	#7,d1
	bra.w	LoadAnimTiles
; ---------------------------------------------------------------------------

loc_112EE:
	subq.b	#1,(unk_FFF7B3).w
	bpl.s	loc_11324
	move.b	#$F,(unk_FFF7B3).w
	lea (byte_6B218).l,a1
	move.b	(unk_FFF7B2).w,d0
	addq.b	#1,(unk_FFF7B2).w
	andi.w	#1,d0
	beq.s	loc_11312
	lea $200(a1),a1

loc_11312:
	move.l	#$6B800001,(VdpCtrl).l
	move.w	#$F,d1
	bra.w	LoadAnimTiles
; ---------------------------------------------------------------------------

loc_11324:
	subq.b	#1,(unk_FFF7B5).w
	bpl.s	locret_11370
	move.b	#7,(unk_FFF7B5).w
	move.b	(unk_FFF7B4).w,d0
	addq.b	#1,(unk_FFF7B4).w
	andi.w	#3,d0
	move.b	byte_11372(pc,d0.w),d0
	btst	#0,d0
	bne.s	loc_1134C
	move.b	#$7F,(unk_FFF7B5).w

loc_1134C:
	lsl.w	#7,d0
	move.w	d0,d1
	add.w	d0,d0
	add.w	d1,d0
	move.l	#$6D800001,(VdpCtrl).l
	lea (byte_6B618).l,a1
	lea (a1,d0.w),a1
	move.w	#$B,d1
	bsr.w	LoadAnimTiles

locret_11370:
	rts
; ---------------------------------------------------------------------------

byte_11372: dc.b 0, 1, 2, 1
; ---------------------------------------------------------------------------

loc_11376:
	subq.b	#1,(unk_FFF7B1).w
	bpl.s	loc_113B4
	move.b	#$13,(unk_FFF7B1).w
	lea (byte_6BA98).l,a1
	moveq	#0,d0
	move.b	(unk_FFF7B0).w,d0
	addq.b	#1,d0
	cmpi.b	#3,d0
	bne.s	loc_11398
	moveq	#0,d0

loc_11398:
	move.b	d0,(unk_FFF7B0).w
	mulu.w	#$100,d0
	adda.w	d0,a1
	move.l	#$5C400001,(VdpCtrl).l
	move.w	#7,d1
	bsr.w	LoadAnimTiles

loc_113B4:
	subq.b	#1,(unk_FFF7B3).w
	bpl.s	loc_11412
	move.b	#1,(unk_FFF7B3).w
	moveq	#0,d0
	move.b	(unk_FFF7B0).w,d0
	lea (byte_6BD98).l,a4
	ror.w	#7,d0
	adda.w	d0,a4
	move.l	#$5A400001,(VdpCtrl).l
	moveq	#0,d3
	move.b	(unk_FFF7B2).w,d3
	addq.b	#1,(unk_FFF7B2).w
	move.b	(oscValues+$A).w,d3
	move.w	#3,d2

loc_113EC:
	move.w	d3,d0
	add.w	d0,d0
	andi.w	#$1E,d0
	lea (off_1149A).l,a3
	move.w	(a3,d0.w),d0
	lea (a3,d0.w),a3
	movea.l a4,a1
	move.w	#$1F,d1
	jsr (a3)
	addq.w	#4,d3
	dbf d2,loc_113EC
	rts
; ---------------------------------------------------------------------------

loc_11412:
	subq.b	#1,(unk_FFF7B5).w
	bpl.s	locret_11480
	move.b	#7,(unk_FFF7B5).w
	lea (byte_6C398).l,a1
	moveq	#0,d0
	move.b	(unk_FFF7B4).w,d0
	addq.b	#1,d0
	cmpi.b	#6,d0
	bne.s	loc_11436
	moveq	#0,d0

loc_11436:
	move.b	d0,(unk_FFF7B4).w
	mulu.w	#$100,d0
	adda.w	d0,a1
	move.l	#$5D400001,(VdpCtrl).l
	move.w	#7,d1
	bsr.s	LoadAnimTiles
	lea (byte_6C998).l,a1
	moveq	#0,d0
	move.b	(unk_FFF7B6).w,d0
	addq.b	#1,(unk_FFF7B6).w
	andi.b	#3,(unk_FFF7B6).w
	mulu.w	#$C0,d0
	adda.w	d0,a1
	move.l	#$5E400001,(VdpCtrl).l
	move.w	#5,d1
	bra.s	LoadAnimTiles
; ---------------------------------------------------------------------------

locret_11480:
locret_11482:
	rts
; ---------------------------------------------------------------------------

LoadAnimTiles:
	rept 8
	move.l	(a1)+,(a6)
	endr
	dbf d1,LoadAnimTiles
	rts
; ---------------------------------------------------------------------------

off_1149A:  dc.w loc_114BA-off_1149A, loc_114C6-off_1149A, loc_114DC-off_1149A, loc_114EA-off_1149A
	dc.w loc_11500-off_1149A, loc_1150E-off_1149A, loc_11524-off_1149A, loc_11532-off_1149A
	dc.w loc_11548-off_1149A, loc_11556-off_1149A, loc_1156C-off_1149A, loc_1157A-off_1149A
	dc.w loc_11590-off_1149A, loc_1159E-off_1149A, loc_115B4-off_1149A, loc_115C6-off_1149A
; ---------------------------------------------------------------------------

loc_114BA:
	move.l	(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_114BA
	rts
; ---------------------------------------------------------------------------

loc_114C6:
	move.l	2(a1),d0
	move.b	render(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_114C6
	rts
; ---------------------------------------------------------------------------

loc_114DC:
	move.l	2(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_114DC
	rts
; ---------------------------------------------------------------------------

loc_114EA:
	move.l	4(a1),d0
	move.b	3(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_114EA
	rts
; ---------------------------------------------------------------------------

loc_11500:
	move.l	4(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_11500
	rts
; ---------------------------------------------------------------------------

loc_1150E:
	move.l	6(a1),d0
	move.b	5(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_1150E
	rts
; ---------------------------------------------------------------------------

loc_11524:
	move.l	6(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_11524
	rts
; ---------------------------------------------------------------------------

loc_11532:
	move.l	xpos(a1),d0
	move.b	7(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_11532
	rts
; ---------------------------------------------------------------------------

loc_11548:
	move.l	xpos(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_11548
	rts
; ---------------------------------------------------------------------------

loc_11556:
	move.l	xpix(a1),d0
	move.b	9(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_11556
	rts
; ---------------------------------------------------------------------------

loc_1156C:
	move.l	xpix(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_1156C
	rts
; ---------------------------------------------------------------------------

loc_1157A:
	move.l	ypos(a1),d0
	move.b	$B(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_1157A
	rts
; ---------------------------------------------------------------------------

loc_11590:
	move.l	ypos(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_11590
	rts
; ---------------------------------------------------------------------------

loc_1159E:
	move.l	ypos(a1),d0
	rol.l	#8,d0
	move.b	id(a1),d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_1159E
	rts
; ---------------------------------------------------------------------------

loc_115B4:
	move.w	ypix(a1),(a6)
	move.w	id(a1),(a6)
	lea xvel(a1),a1
	dbf d1,loc_115B4
	rts
; ---------------------------------------------------------------------------

loc_115C6:
	move.l	id(a1),d0
	move.b	$F(a1),d0
	ror.l	#8,d0
	move.l	d0,(a6)
	lea xvel(a1),a1
	dbf d1,loc_115C6
	rts

; ---------------------------------------------------------------------------

ObjHUD:
	moveq	#0,d0
	move.b	act(a0),d0
	move.w	ObjHUD_Index(pc,d0.w),d1
	jmp ObjHUD_Index(pc,d1.w)
; ---------------------------------------------------------------------------

ObjHUD_Index:	dc.w ObjHUD_Init-ObjHUD_Index, ObjHUD_Display-ObjHUD_Index
; ---------------------------------------------------------------------------

ObjHUD_Init:
	addq.b	#2,act(a0)
	move.w	#$90,xpos(a0)
	move.w	#$108,xpix(a0)
	move.l	#MapHUD,map(a0)
	move.w	#$6CA,tile(a0)
	move.b	#0,render(a0)
	move.w	#0,prio(a0)

ObjHUD_Display:
	jmp ObjectDisplay
; ---------------------------------------------------------------------------
	include "levels/shared/HUD/Sprite.map"
	even
; ---------------------------------------------------------------------------

ScoreAdd:
	st.b	(byte_FFFE1F).w
	lea (unk_FFFE50).w,a2
	lea (dword_FFFE26).w,a3
	add.l	d0,(a3)
	move.l	#999999,d1
	cmp.l	(a3),d1
	bhi.w	loc_1166E
	move.l	d1,(a3)
	move.l	d1,(a2)

loc_1166E:
	move.l	(a3),d0
	cmp.l	(a2),d0
	bcs.w	locret_11678
	move.l	d0,(a2)

locret_11678:
	rts
; ---------------------------------------------------------------------------

UpdateHUD:
	tst.w	(EditModeFlag).w
	bne.w	loc_11746
	tst.b	(byte_FFFE1F).w
	beq.s	loc_1169A
	clr.b	(byte_FFFE1F).w
	move.l	#$5C800003,d0
	move.l	(dword_FFFE26).w,d1
	bsr.w	sub_1187E

loc_1169A:
	tst.b	(ExtraLifeFlags).w
	beq.s	loc_116BA
	bpl.s	loc_116A6
	bsr.w	sub_117B2

loc_116A6:
	clr.b	(ExtraLifeFlags).w
	move.l	#$5F400003,d0
	moveq	#0,d1
	move.w	(Rings).w,d1
	bsr.w	sub_11874

loc_116BA:
	tst.b	(byte_FFFE1E).w
	beq.s	loc_1170E
	tst.b	(PauseFlag).w
	bmi.s	loc_1170E
	lea (dword_FFFE26).w,a1
	btst	#6,(ConsoleRegion).w
	beq.s	HUD_NotPAL
	bsr.w 	HUDCountPAL
	bra.s  	loc_116EE

HUD_NotPAL:
	bsr.w 	HUDCountNTSC
loc_116EE:
	move.l	#$5E400003,d0
	moveq	#0,d1
	move.b	(dword_FFFE22+1).w,d1
	bsr.w	sub_118F4
	move.l	#$5EC00003,d0
	moveq	#0,d1
	move.b	(dword_FFFE22+2).w,d1
	bsr.w	sub_118FE

loc_1170E:
	tst.b	(byte_FFFE1C).w
	beq.s	loc_1171C
	clr.b	(byte_FFFE1C).w
	bsr.w	sub_119BA

loc_1171C:
	tst.b	(byte_FFFE58).w
	beq.s	locret_11744
	clr.b	(byte_FFFE58).w
	move.l	#$6E000002,(VdpCtrl).l
	moveq	#0,d1
	move.w	(word_FFFE54).w,d1
	bsr.w	sub_11958
	moveq	#0,d1
	move.w	(word_FFFE56).w,d1
	bsr.w	sub_11958

locret_11744:
	rts

HUDCountNTSC:
	addq.b	#1,-(a1)
	cmpi.b	#60,(a1)
	bcs.w	loc_1170E
	move.b	#0,(a1)
	addq.b	#1,-(a1)
	cmpi.b	#60,(a1)
	bcs.w	loc_116EE
	move.b	#0,(a1)
	addq.b	#1,-(a1)
	cmpi.b	#9,(a1)
	bcs.w	loc_116EE
	move.b	#9,(a1)
	rts

HUDCountPAL:
	addq.b	#1,-(a1)
	cmpi.b	#50,(a1)
	bcs.w	loc_1170E
	move.b	#0,(a1)
	addq.b	#1,-(a1)
	cmpi.b	#50,(a1)
	bcs.w	loc_116EE
	move.b	#0,(a1)
	addq.b	#1,-(a1)
	cmpi.b	#9,(a1)
	bcs.w	loc_116EE
	move.b	#9,(a1)
	rts
; ---------------------------------------------------------------------------

loc_11746:
	bsr.w	sub_1181E
	tst.b	(ExtraLifeFlags).w
	beq.s	loc_1176A
	bpl.s	loc_11756
	bsr.w	sub_117B2

loc_11756:
	clr.b	(ExtraLifeFlags).w
	move.l	#$5F400003,d0
	moveq	#0,d1
	move.w	(Rings).w,d1
	bsr.w	sub_11874

loc_1176A:
	move.l	#$5EC00003,d0
	moveq	#0,d1
	move.b	(byte_FFF62C).w,d1
	bsr.w	sub_118FE
	tst.b	(byte_FFFE1C).w
	beq.s	loc_11788
	clr.b	(byte_FFFE1C).w
	bsr.w	sub_119BA

loc_11788:
	tst.b	(byte_FFFE58).w
	beq.s	locret_117B0
	clr.b	(byte_FFFE58).w
	move.l	#$6E000002,(VdpCtrl).l
	moveq	#0,d1
	move.w	(word_FFFE54).w,d1
	bsr.w	sub_11958
	moveq	#0,d1
	move.w	(word_FFFE56).w,d1
	bsr.w	sub_11958

locret_117B0:
	rts
; ---------------------------------------------------------------------------

sub_117B2:
	move.l	#$5F400003,(VdpCtrl).l
	lea byte_1181A(pc),a2
	move.w	#2,d2
	bra.s	loc_117E2
; ---------------------------------------------------------------------------

sub_117C6:
	lea (VdpData).l,a6
	bsr.w	sub_119BA
	move.l	#$5C400003,(VdpCtrl).l
	lea byte_1180E(pc),a2
	move.w	#$E,d2

loc_117E2:
	lea byte_11A26(pc),a1

loc_117E6:
	move.w	#$F,d1
	move.b	(a2)+,d0
	bmi.s	loc_11802
	ext.w	d0
	lsl.w	#5,d0
	lea (a1,d0.w),a3

loc_117F6:
	move.l	(a3)+,(a6)
	dbf d1,loc_117F6

loc_117FC:
	dbf d2,loc_117E6
	rts
; ---------------------------------------------------------------------------

loc_11802:
	move.l	#0,(a6)
	dbf d1,loc_11802
	bra.s	loc_117FC
; ---------------------------------------------------------------------------

byte_1180E: dc.b $16, $FF, $FF, $FF, $FF, $FF, $FF, 0, 0, $14, 0, 0

byte_1181A: dc.b $FF, $FF, 0, 0
; ---------------------------------------------------------------------------

sub_1181E:
	move.l	#$5C400003,(VdpCtrl).l
	move.w	(CameraX).w,d1
	swap	d1
	move.w	(ObjectsList+8).w,d1
	bsr.s	sub_1183E
	move.w	(CameraY).w,d1
	swap	d1
	move.w	(ObjectsList+$C).w,d1
; ---------------------------------------------------------------------------

sub_1183E:
	moveq	#7,d6
	lea (ArtText).l,a1

loc_11846:
	rol.w	#4,d1
	move.w	d1,d2
	andi.w	#$F,d2
	cmpi.w	#$A,d2
	bcs.s	loc_11856
	addq.w	#7,d2

loc_11856:
	lsl.w	#5,d2
	lea (a1,d2.w),a3
	rept 8
	move.l	(a3)+,(a6)
	endr
	swap	d1
	dbf d6,loc_11846
	rts
; ---------------------------------------------------------------------------

sub_11874:
	lea (dword_118E8).l,a2
	moveq	#2,d6
	bra.s	loc_11886
; ---------------------------------------------------------------------------

sub_1187E:
	lea (dword_118DC).l,a2
	moveq	#5,d6

loc_11886:
	moveq	#0,d4
	lea byte_11A26(pc),a1

loc_1188C:
	moveq	#0,d2
	move.l	(a2)+,d3

loc_11890:
	sub.l	d3,d1
	bcs.s	loc_11898
	addq.w	#1,d2
	bra.s	loc_11890
; ---------------------------------------------------------------------------

loc_11898:
	add.l	d3,d1
	tst.w	d2
	beq.s	loc_118A2
	move.w	#1,d4

loc_118A2:
	tst.w	d4
	beq.s	loc_118D0
	lsl.w	#6,d2
	move.l	d0,4(a6)
	lea (a1,d2.w),a3
	rept 16
	move.l	(a3)+,(a6)
	endr

loc_118D0:
	addi.l	#$400000,d0
	dbf d6,loc_1188C
	rts
; ---------------------------------------------------------------------------

dword_118DC:	dc.l 100000
				dc.l 10000
dword_118E4:	dc.l 1000
dword_118E8:	dc.l 100
dword_118EC:	dc.l 10
dword_118F0:	dc.l 1
; ---------------------------------------------------------------------------

sub_118F4:
	lea (dword_118F0).l,a2
	moveq	#0,d6
	bra.s	loc_11906
; ---------------------------------------------------------------------------

sub_118FE:
	lea (dword_118EC).l,a2
	moveq	#1,d6

loc_11906:
	moveq	#0,d4
	lea byte_11A26(pc),a1

loc_1190C:
	moveq	#0,d2
	move.l	(a2)+,d3

loc_11910:
	sub.l	d3,d1
	bcs.s	loc_11918
	addq.w	#1,d2
	bra.s	loc_11910
; ---------------------------------------------------------------------------

loc_11918:
	add.l	d3,d1
	tst.w	d2
	beq.s	loc_11922
	move.w	#1,d4

loc_11922:
	lsl.w	#6,d2
	move.l	d0,4(a6)
	lea (a1,d2.w),a3
	rept 16
	move.l	(a3)+,(a6)
	endr
	addi.l	#$400000,d0
	dbf d6,loc_1190C
	rts
; ---------------------------------------------------------------------------

sub_11958:
	lea (dword_118E4).l,a2
	moveq	#3,d6
	moveq	#0,d4
	lea byte_11A26(pc),a1

loc_11966:
	moveq	#0,d2
	move.l	(a2)+,d3

loc_1196A:
	sub.l	d3,d1
	bcs.s	loc_11972
	addq.w	#1,d2
	bra.s	loc_1196A
; ---------------------------------------------------------------------------

loc_11972:
	add.l	d3,d1
	tst.w	d2
	beq.s	loc_1197C
	move.w	#1,d4

loc_1197C:
	tst.w	d4
	beq.s	loc_119AC
	lsl.w	#6,d2
	lea (a1,d2.w),a3
	rept 16
	move.l	(a3)+,(a6)
	endr

loc_119A6:
	dbf d6,loc_11966
	rts
; ---------------------------------------------------------------------------

loc_119AC:
	moveq	#$F,d5

loc_119AE:
	move.l	#0,(a6)
	dbf d5,loc_119AE
	bra.s	loc_119A6
; ---------------------------------------------------------------------------

sub_119BA:
	move.l	#$7BA00003,d0
	moveq	#0,d1
	move.b	(Lives).w,d1
	lea (dword_118EC).l,a2
	moveq	#1,d6
	moveq	#0,d4
	lea byte_11D26(pc),a1

loc_119D4:
	move.l	d0,4(a6)
	moveq	#0,d2
	move.l	(a2)+,d3

loc_119DC:
	sub.l	d3,d1
	bcs.s	loc_119E4
	addq.w	#1,d2
	bra.s	loc_119DC
; ---------------------------------------------------------------------------

loc_119E4:
	add.l	d3,d1
	tst.w	d2
	beq.s	loc_119EE
	move.w	#1,d4

loc_119EE:
	tst.w	d4
	beq.s	loc_11A14

loc_119F2:
	lsl.w	#5,d2
	lea (a1,d2.w),a3
	rept 8
	move.l	(a3)+,(a6)
	endr

loc_11A08:
	addi.l	#$400000,d0
	dbf d6,loc_119D4
	rts
; ---------------------------------------------------------------------------

loc_11A14:
	tst.w	d6
	beq.s	loc_119F2
	moveq	#7,d5

loc_11A1A:
	move.l	#0,(a6)
	dbf d5,loc_11A1A
	bra.s	loc_11A08
; ---------------------------------------------------------------------------

byte_11A26: dc.b 0, 0, 0, 0, 0, $66, $66, $10, 6, $66, $66, $61, 6
	dc.b $61, $16, $61, 6, $61, 6, $61, 6, $61, 6, $61, 6
	dc.b $61, 6, $61, 6, $61, 6, $61, 6, $61, 6, $61, 6, $66
	dc.b $66, $61, 0, $66, $66, $10, 0, $11, $11, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 6, $61, 0, 0, $66, $61, 0, 0, 6, $61, 0, 0
	dc.b 6, $61, 0, 0, 6, $61, 0, 0, 6, $61, 0, 0, 6, $61
	dc.b 0, 0, 6, $61, 0, 0, 6, $61, 0, 0, 6, $61, 0, 0, 1
	dc.b $11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, $66, $66, $10, 6, $66, $66, $61
	dc.b 6, $61, $16, $61, 1, $11, $66, $61, 0, 6, $66, $10
	dc.b 0, $66, $61, 0, 0, $66, $10, 0, 6, $66, $10, 0, 6
	dc.b $66, $66, $61, 6, $66, $66, $61, 1, $11, $11, $11
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, $66, $66, $10, 6, $66, $66, $61, 6, $61
	dc.b $16, $61, 1, $11, 6, $61, 0, 6, $66, $10, 0, 6, $66
	dc.b $10, 0, 1, $16, $61, 6, $61, 6, $61, 6, $66, $66
	dc.b $61, 0, $66, $66, $10, 0, $11, $11, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, $66, $10, 0, 6, $66, $10, 0, 6, $66, $10, 0, $66
	dc.b $66, $10, 0, $61, $66, $10, 6, $61, $66, $10, 6, $66
	dc.b $66, $61, 6, $66, $66, $61, 1, $11, $66, $11, 0, 0
	dc.b $66, $10, 0, 0, $11, $10, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, $66, $66, $61
	dc.b 6, $66, $66, $61, 6, $61, $11, $11, 6, $61, 0, 0
	dc.b 6, $66, $66, $10, 6, $66, $66, $61, 1, $11, $16, $61
	dc.b 6, $61, 6, $61, 6, $66, $66, $61, 1, $66, $66, $10
	dc.b 0, $11, $11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, $66, $66, $10, 6, $66
	dc.b $66, $61, 6, $61, $16, $61, 6, $61, 1, $11, 6, $66
	dc.b $66, $10, 6, $66, $66, $61, 6, $61, $16, $61, 6, $61
	dc.b 6, $61, 6, $66, $66, $61, 0, $66, $66, $10, 0, $11
	dc.b $11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 6, $66, $66, $61, 6, $66, $66, $61
	dc.b 1, $11, $16, $61, 0, 0, $66, $10, 0, 0, $66, $10
	dc.b 0, 0, $66, $10, 0, 6, $61, 0, 0, 6, $61, 0, 0, 6
	dc.b $61, 0, 0, 6, $61, 0, 0, 1, $11, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $66
	dc.b $66, $10, 6, $66, $66, $61, 6, $61, $16, $61, 6, $61
	dc.b 6, $61, 0, $66, $66, $10, 0, $66, $66, $10, 6, $61
	dc.b $16, $61, 6, $61, 6, $61, 6, $66, $66, $61, 0, $66
	dc.b $66, $10, 0, $11, $11, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $66, $66, $10
	dc.b 6, $66, $66, $61, 6, $61, $16, $61, 6, $61, 6, $61
	dc.b 6, $66, $66, $61, 0, $66, $66, $61, 0, $11, $16, $61
	dc.b 6, $61, 6, $61, 6, $66, $66, $61, 0, $66, $66, $10
	dc.b 0, $11, $11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 6, $61, 0, 0, 6, $61, 0, 0, 1, $11, 0, 0, 0, 0, 0
	dc.b 0, 6, $61, 0, 0, 6, $61, 0, 0, 1, $11, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0, 0, 0, 0, 0, $F, $FF, $FF, $F1, $F, $FF
	dc.b $FF, $F1, $F, $F1, $11, $11, $F, $F1, 0, 0, $F, $FF
	dc.b $FF, $10, $F, $FF, $FF, $10, $F, $F1, $11, $10, $F
	dc.b $F1, 0, 0, $F, $FF, $FF, $F1, $F, $FF, $FF, $F1, 1
	dc.b $11, $11, $11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 0, 0, 0, 0

byte_11D26: dc.b 0, 0, 0, 0, 0, $66, $66, $10, 6, $61, $16, $61, 6
	dc.b $61, 6, $61, 6, $61, 6, $61, 6, $61, 6, $61, 0, $66
	dc.b $66, $10, 0, $11, $11, 0, 0, 0, 0, 0, 0, 6, $61, 0
	dc.b 0, $66, $61, 0, 0, $16, $61, 0, 0, 6, $61, 0, 0, 6
	dc.b $61, 0, 0, 6, $61, 0, 0, 1, $11, 0, 0, 0, 0, 0, 0
	dc.b $66, $66, $10, 0, $11, $16, $61, 0, 0, $66, $11, 0
	dc.b 6, $61, $10, 0, $66, $11, $10, 6, $66, $66, $61, 1
	dc.b $11, $11, $11, 0, 0, 0, 0, 0, $66, $66, $10, 0, $11
	dc.b $16, $61, 0, 6, $66, $10, 0, 1, $16, $61, 6, $61
	dc.b 6, $61, 0, $66, $66, $10, 0, $11, $11, 0, 0, 0, 0
	dc.b 0, 0, 0, $66, $10, 0, 6, $66, $10, 0, $61, $66, $10
	dc.b 6, $61, $66, $10, 6, $66, $66, $61, 1, $11, $66, $11
	dc.b 0, 0, $11, $10, 0, 0, 0, 0, 6, $66, $66, $61, 6, $61
	dc.b $11, $11, 6, $66, $66, $10, 1, $11, $16, $61, 6, $61
	dc.b 6, $61, 0, $66, $66, $10, 0, $11, $11, 0, 0, 0, 0
	dc.b 0, 0, $66, $66, $10, 6, $61, $11, $10, 6, $66, $66
	dc.b $10, 6, $61, $16, $61, 6, $61, 6, $61, 0, $66, $66
	dc.b $10, 0, $11, $11, 0, 0, 0, 0, 0, 6, $66, $66, $61
	dc.b 1, $11, $16, $61, 0, 0, $66, $10, 0, 6, $61, 0, 0
	dc.b $66, $10, 0, 0, $66, $10, 0, 0, $11, $10, 0, 0, 0
	dc.b 0, 0, 0, $66, $66, $10, 6, $61, $16, $61, 0, $66
	dc.b $66, $10, 6, $61, $16, $61, 6, $61, 6, $61, 0, $66
	dc.b $66, $10, 0, $11, $11, 0, 0, 0, 0, 0, 0, $66, $66
	dc.b $10, 6, $61, $16, $61, 6, $61, 6, $61, 0, $66, $66
	dc.b $61, 0, $11, $16, $61, 0, $66, $66, $10, 0, $11, $11
	dc.b 0
; ---------------------------------------------------------------------------

Edit:
	moveq	#0,d0
	move.b	(DebugRoutine).w,d0
	move.w	off_11E74(pc,d0.w),d1
	jmp off_11E74(pc,d1.w)
; ---------------------------------------------------------------------------

off_11E74:  dc.w loc_11E78-off_11E74, loc_11EB8-off_11E74
; ---------------------------------------------------------------------------

loc_11E78:
	clr.w	(ObjectsList+inertia).w ; Clear Inertia
	clr.w	(ObjectsList+yvel).w ; Clear X/Y Speed
	clr.w	(ObjectsList+xvel).w ; Clear X/Y Speed
	addq.b	#2,(DebugRoutine).w
	clr.b	frame(a0)
	clr.b	ani(a0)
	moveq	#0,d0
	move.b	(curzone).w,d0
	lea (DebugLists).l,a2
	add.w	d0,d0
	adda.w	(a2,d0.w),a2
	move.w	(a2)+,d6
	cmp.b	(byte_FFFE06).w,d6
	bhi.s	loc_11EA8
	clr.b	(byte_FFFE06).w

loc_11EA8:
	bsr.w	sub_11FCE
	move.b	#$C,(DebugTimer).w
	move.b	#1,(DebugSpeed).w

loc_11EB8:
	moveq	#0,d0
	move.b	(curzone).w,d0
	lea (DebugLists).l,a2
	add.w	d0,d0
	adda.w	(a2,d0.w),a2
	move.w	(a2)+,d6
	bsr.w	sub_11ED6
	jmp ObjectDisplay
; ---------------------------------------------------------------------------

sub_11ED6:
	moveq	#0,d4
	move.w	#1,d1
	move.b	(padPress1).w,d4
	bne.s	loc_11F0E
	tst.b	(padHeld1).w
	bne.s	loc_11EF6
	move.b	#$C,(DebugTimer).w
	move.b	#$F,(DebugSpeed).w
	rts
; ---------------------------------------------------------------------------

loc_11EF6:
	subq.b	#1,(DebugTimer).w
	bne.s	loc_11F12
	move.b	#1,(DebugTimer).w
	addq.b	#1,(DebugSpeed).w
	bne.s	loc_11F0E
	st.b	(DebugSpeed).w

loc_11F0E:
	move.b	(padHeld1).w,d4

loc_11F12:
	moveq	#0,d1
	move.b	(DebugSpeed).w,d1
	addq.w	#1,d1
	swap	d1
	asr.l	#4,d1
	move.l	ypos(a0),d2
	move.l	xpos(a0),d3
	btst	#JbU,d4
	beq.s	loc_11F32
	sub.l	d1,d2
	bcc.s	loc_11F32
	moveq	#0,d2

loc_11F32:
	btst	#JbD,d4
	beq.s	loc_11F48
	add.l	d1,d2
	cmpi.l	#$7FF0000,d2
	bcs.s	loc_11F48
	move.l	#$7FF0000,d2

loc_11F48:
	btst	#JbL,d4
	beq.s	loc_11F54
	sub.l	d1,d3
	bcc.s	loc_11F54
	moveq	#0,d3

loc_11F54:
	btst	#JbR,d4
	beq.s	loc_11F5C
	add.l	d1,d3

loc_11F5C:
	move.l	d2,ypos(a0)
	move.l	d3,xpos(a0)
	btst	#JbA,(padPressPlayer).w
	beq.s	loc_11F80
	addq.b	#1,(byte_FFFE06).w
	cmp.b	(byte_FFFE06).w,d6
	bhi.s	loc_11F7C
	clr.b	(byte_FFFE06).w

loc_11F7C:
	bra.w	sub_11FCE
; ---------------------------------------------------------------------------

loc_11F80:
	btst	#JbC,(padPressPlayer).w
	beq.s	loc_11FA4
	jsr ObjectLoad
	bne.s	loc_11FA4
	move.w	xpos(a0),xpos(a1)
	move.w	ypos(a0),ypos(a1)
	move.b	map(a0),id(a1)
	rts
; ---------------------------------------------------------------------------

loc_11FA4:
	btst	#JbB,(padPressPlayer).w
	beq.s	locret_11FCC
	moveq	#0,d0
	move.w	d0,(DebugRoutine).w
	move.l	#MapSonic,(ObjectsList+4).w
	move.w	#$780,(ObjectsList+2).w
	move.b	d0,(ObjectsList+$1C).w
	move.w	d0,xpix(a0)
	move.w	d0,ypix(a0)

locret_11FCC:
	rts
; ---------------------------------------------------------------------------

sub_11FCE:
	moveq	#0,d0
	move.b	(byte_FFFE06).w,d0
	lsl.w	#3,d0
	move.l	(a2,d0.w),map(a0)
	move.w	6(a2,d0.w),tile(a0)
	move.b	5(a2,d0.w),frame(a0)
	rts
; ---------------------------------------------------------------------------

DebugLists: dc.w DebugList_GHZ-DebugLists, DebugList_LZ-DebugLists, DebugList_MZ-DebugLists, DebugList_SLZ-DebugLists
	dc.w DebugList_SYZ-DebugLists, DebugList_SBZ-DebugLists, DebugList_Ending-DebugLists

DebugList_GHZ:	dc.w $D
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($1F<<24)|MapCrabmeat
	dc.b 0, 0, 4, 0
	dc.l ($22<<24)|MapBuzzbomber
	dc.b 0, 0, 4, $44
	dc.l ($2B<<24)|MapChopper
	dc.b 0, 0, 4, $7B
	dc.l ($36<<24)|MapSpikes
	dc.b 0, 0, 5, $1B
	dc.l ($18<<24)|MapPlatform1
	dc.b 0, 0, $40, 0
	dc.l ($3B<<24)|MapPurpleRock
	dc.b 0, 0, $63, $D0
	dc.l ($40<<24)|MapMotobug
	dc.b 0, 0, 4, $F0
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23
	dc.l ($42<<24)|MapNewtron
	dc.b 0, 0, $24, $9B
	dc.l ($44<<24)|MapWall
	dc.b 0, 0, $43, $4C
	dc.l ($19<<24)|MapRollingBall
	dc.b 0, 0, $43, $AA
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23

DebugList_LZ:	dc.w 5
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($2C<<24)|MapJaws
	dc.b 0, 0, $2C, 0
	dc.l ($2D<<24)|MapBurrobot
	dc.b 0, 0, $2D, 0
	dc.l ($1B<<24)|Map1B
	dc.b 0, 0, $1B, 0
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23

DebugList_MZ:	dc.w $11
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($22<<24)|MapBuzzbomber
	dc.b 0, 0, 4, $44
	dc.l ($36<<24)|MapSpikes
	dc.b 0, 0, 5, $1B
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23
	dc.l ($13<<24)|MapLavaball
	dc.b 0, 0, 3, $45
	dc.l ($46<<24)|MapMZBlocks
	dc.b 0, 0, $40, 0
	dc.l ($4C<<24)|MapLavafall
	dc.b 0, 0, $63, $A8
	dc.l ($4E<<24)|MapLavaChase
	dc.b 0, 0, $63, $A8
	dc.l ($33<<24)|MapPushBlock
	dc.b 0, 0, $42, $B8
	dc.l ($4F<<24)|Map4F
	dc.b 0, 0, 4, $E4
	dc.l ($50<<24)|MapYadrin
	dc.b 0, 0, 4, $7B
	dc.l ($51<<24)|MapSmashBlock
	dc.b 0, 0, $42, $B8
	dc.l ($52<<24)|MapMovingPtfm
	dc.b 0, 0, 2, $B8
	dc.l ($53<<24)|MapCollapseFloor
	dc.b 0, 0, $62, $B8
	dc.l ($54<<24)|MapLavaHurt
	dc.b 0, 0, $86, $80
	dc.l ($55<<24)|MapBasaran
	dc.b 0, 0, $24, $B8

DebugList_SLZ:	dc.w $D
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($59<<24)|MapSLZMovingPtfm
	dc.b 0, 0, $44, $80
	dc.l ($53<<24)|MapCollapseFloor
	dc.b 0, 2, $44, $E0
	dc.l ($18<<24)|MapPlatform3
	dc.b 0, 0, $44, $80
	dc.l ($5A<<24)|MapCirclePtfm
	dc.b 0, 0, $44, $80
	dc.l ($5B<<24)|MapStaircasePtfm
	dc.b 0, 0, $44, $80
	dc.l ($5D<<24)|MapFan
	dc.b 0, 0, $43, $A0
	dc.l ($5E<<24)|MapSeesaw
	dc.b 0, 0, 3, $74
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23
	dc.l ($13<<24)|MapLavaball
	dc.b 0, 0, 3, $45
	dc.l ($1F<<24)|MapCrabmeat
	dc.b 0, 0, 4, 0
	dc.l ($22<<24)|MapBuzzbomber
	dc.b 0, 0, 4, $44

DebugList_SYZ:	dc.w $D
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($36<<24)|MapSpikes
	dc.b 0, 0, 5, $1B
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23
	dc.l ($43<<24)|MapRoller
	dc.b 0, 0, $24, $B8
	dc.l ($12<<24)|MapSceneryLamp
	dc.b 0, 0, 0, 0
	dc.l ($47<<24)|MapBumper
	dc.b 0, 0, 3, $80
	dc.l ($1F<<24)|MapCrabmeat
	dc.b 0, 0, 4, 0
	dc.l ($22<<24)|MapBuzzbomber
	dc.b 0, 0, 4, $44
	dc.l ($50<<24)|MapYadrin
	dc.b 0, 0, 4, $7B
	dc.l ($18<<24)|MapPlatform2
	dc.b 0, 0, $40, 0
	dc.l ($56<<24)|MapMovingBlocks
	dc.b 0, 0, $40, 0
	dc.l ($32<<24)|MapSwitch
	dc.b 0, 0, 5, $13

DebugList_SBZ:	dc.w 6
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($1E<<24)|MapBallhog
	dc.b 0, 0, $24, 0
	dc.l ($41<<24)|MapSpring
	dc.b 0, 0, 5, $23
	
DebugList_Ending:   dc.w $D
	dc.l ($25<<24)|MapRing
	dc.b 0, 0, $27, $B2
	dc.l ($26<<24)|MapMonitor
	dc.b 0, 0, 6, $80
	dc.l ($10<<24)|MapRing
	dc.b 0, 0, $10, $B2
	dc.l ($1B<<24)|Map1B
	dc.b 0, 0, $1B, $B2

LevelDataArray: dc.l ($4<<24)|TilesGHZ, ($5<<24)|BlocksGHZ, ChunksGHZ
	dc.b 0, $81, 4, 4
	dc.l ($6<<24)|TilesLZ, ($7<<24)|BlocksLZ, ChunksLZ
	dc.b 0, $82, 5, 5
	dc.l ($8<<24)|TilesMZ, ($9<<24)|BlocksMZ, ChunksMZ
	dc.b 0, $83, 6, 6
	dc.l ($A<<24)|TilesSLZ, ($B<<24)|BlocksSLZ, ChunksSLZ
	dc.b 0, $84, 7, 7
	dc.l ($C<<24)|TilesSYZ, ($D<<24)|BlocksSYZ, ChunksSYZ
	dc.b 0, $85, 8, 8
	dc.l ($E<<24)|TilesSBZ, ($F<<24)|BlocksSBZ, ChunksSBZ
	dc.b 0, $86, 9, 9
	dc.l ($4<<24)|TilesGHZ, ($5<<24)|BlocksGHZ, ChunksGHZ
	dc.b 0, $81, 4, 4

plcArray:   dc.w plcMain-plcArray, plcMain2-plcArray, plcExplosion-plcArray, plcGameOver-plcArray
	dc.w plcGHZ1-plcArray, plzGHZ2-plcArray, plcLZ1-plcArray, plcLZ2-plcArray, plcMZ1-plcArray
	dc.w plcMZ2-plcArray, plcSLZ1-plcArray, plcSLZ2-plcArray, plcSYZ1-plcArray, plcSYZ2-plcArray
	dc.w plcSBZ1-plcArray, plcSBZ2-plcArray, plcTitleCards-plcArray, word_12484-plcArray
	dc.w plcSignPosts-plcArray, plcFlash-plcArray, plcSpecialStage-plcArray, plcGHZAnimals-plcArray
	dc.w plcLZAnimals-plcArray, plcMZAnimals-plcArray, plcSLZAnimals-plcArray, plcSYZAnimals-plcArray
	dc.w plcSBZAnimals-plcArray, plcGHZAnimals-plcArray

plcMain:    dc.w (((plcMain2-plcMain-2)/6)-1)
	dc.l ArtSmoke
	dc.w $F400
	dc.l ArtHUD
	dc.w $D940
	dc.l ArtLives
	dc.w $FA80
	dc.l ArtRings
	dc.w $F640
	dc.l byte_2E6C8
	dc.w $F2E0

plcMain2:   dc.w (((plcExplosion-plcMain2-2)/6)-1)
	dc.l ArtMonitors
	dc.w $D000
	dc.l ArtShield
	dc.w $A820
	dc.l ArtInvinStars
	dc.w $AB80

plcExplosion:	dc.w (((plcGameOver-plcExplosion-2)/6)-1)
	dc.l ArtExplosions
	dc.w $B400

plcGameOver:	dc.w (((plcGHZ1-plcGameOver-2)/6)-1)
	dc.l ArtGameOver
	dc.w $B000

plcGHZ1:    dc.w (((plzGHZ2-plcGHZ1-2)/6)-1)
	dc.l TilesGHZ
	dc.w 0
	dc.l byte_27400
	dc.w $6B00
	dc.l ArtPurpleRock
	dc.w $7A00
	dc.l ArtCrabmeat
	dc.w $8000
	dc.l ArtBuzzbomber
	dc.w $8880
	dc.l ArtChopper
	dc.w $8F60
	dc.l ArtNewtron
	dc.w $9360
	dc.l ArtMotobug
	dc.w $9E00
	dc.l ArtSpikes
	dc.w $A360
	dc.l ArtSpringHoriz
	dc.w $A460
	dc.l ArtSpringVerti
	dc.w $A660

plzGHZ2:    dc.w (((plcLZ1-plzGHZ2-2)/6)-1)
	dc.l byte_2744A
	dc.w $7000
	dc.l ArtBridge
	dc.w $71C0
	dc.l ArtSpikeLogs
	dc.w $7300
	dc.l byte_27698
	dc.w $7540
	dc.l ArtSmashWall
	dc.w $A1E0
	dc.l ArtWall
	dc.w $6980

plcLZ1:     dc.w (((plcLZ2-plcLZ1-2)/6)-1)
	dc.l TilesLZ
	dc.w 0
	dc.l ArtSpikes
	dc.w $A360
	dc.l ArtSpringHoriz
	dc.w $A460
	dc.l ArtSpringVerti
	dc.w $A660

plcLZ2:     dc.w (((plcMZ1-plcLZ2-2)/6)-1)
	dc.l ArtJaws
	dc.w $99C0

plcMZ1:     dc.w (((plcMZ2-plcMZ1-2)/6)-1)
	dc.l TilesMZ
	dc.w 0
	dc.l ArtChainPtfm
	dc.w $6000
	dc.l byte_2827A
	dc.w $68A0
	dc.l byte_2744A
	dc.w $7000
	dc.l byte_2816E
	dc.w $71C0
	dc.l byte_28558
	dc.w $7500
	dc.l ArtBuzzbomber
	dc.w $8880
	dc.l ArtYardin
	dc.w $8F60
	dc.l ArtBasaran
	dc.w $9700
	dc.l ArtSplats
	dc.w $9C80

plcMZ2:     dc.w (((plcSLZ1-plcMZ2-2)/6)-1)
	dc.l ArtButtonMZ
	dc.w $A260
	dc.l ArtSpikes
	dc.w $A360
	dc.l ArtSpringHoriz
	dc.w $A460
	dc.l ArtSpringVerti
	dc.w $A660
	dc.l byte_28E6E
	dc.w $5700

plcSLZ1:    dc.w (((plcSLZ2-plcSLZ1-2)/6)-1)
	dc.l TilesSLZ
	dc.w 0
	dc.l byte_2827A
	dc.w $68A0
	dc.l ArtCrabmeat
	dc.w $8000
	dc.l ArtBuzzbomber
	dc.w $8880
	dc.l byte_297B6
	dc.w $9000
	dc.l byte_29D4A
	dc.w $9C00
	dc.l ArtMotobug
	dc.w $9E00
	dc.l byte_294DA
	dc.w $A260
	dc.l ArtSpikes
	dc.w $A360
	dc.l ArtSpringHoriz
	dc.w $A460
	dc.l ArtSpringVerti
	dc.w $A660

plcSLZ2:    dc.w (((plcSYZ1-plcSLZ2-2)/6)-1)
	dc.l ArtSeesaw
	dc.w $6E80
	dc.l ArtFan
	dc.w $7400
	dc.l byte_2953C
	dc.w $7980
	dc.l byte_2961E
	dc.w $7B80

plcSYZ1:    dc.w (((plcSYZ2-plcSYZ1-2)/6)-1)
	dc.l TilesSYZ
	dc.w 0
	dc.l ArtCrabmeat
	dc.w $8000
	dc.l ArtBuzzbomber
	dc.w $8880
	dc.l ArtYardin
	dc.w $8F60
	dc.l ArtMotobug
	dc.w $9E00
	dc.l byte_2BC04
	dc.w $9700

plcSYZ2:    dc.w (((plcSBZ1-plcSYZ2-2)/6)-1)
	dc.l ArtBumper
	dc.w $7000
	dc.l byte_2A104
	dc.w $72C0
	dc.l byte_29FC0
	dc.w $7740
	dc.l ArtButton
	dc.w $A1E0
	dc.l ArtSpikes
	dc.w $A360
	dc.l ArtSpringHoriz
	dc.w $A460
	dc.l ArtSpringVerti
	dc.w $A660

plcSBZ1:    dc.w (((plcSBZ2-plcSBZ1-2)/6)-1)
	dc.l TilesSBZ
	dc.w 0

plcSBZ2:    dc.w (((plcTitleCards-plcSBZ2-2)/6)-1)
	dc.l ArtSpikes
	dc.w $A360

plcTitleCards:	dc.w (((word_12484-plcTitleCards-2)/6)-1)
	dc.l ArtTitleCards
	dc.w $B000

word_12484: dc.w (((plcSignPosts-word_12484-2)/6)-1)
	dc.l byte_60000
	dc.w $8000
	dc.l byte_60864
	dc.w $8D80
	dc.l byte_60BB0
	dc.w $93A0

plcSignPosts:	dc.w (((plcFlash-plcSignPosts-2)/6)-1)
	dc.l ArtSignPost
	dc.w $D000
	dc.l ArtSpecialRing
	dc.w $9D80
	dc.l ArtFlash
	dc.w $A820

plcFlash:   dc.w (((plcSpecialStage-plcFlash-2)/6)-1)
	dc.l ArtFlash
	dc.w $A820

plcSpecialStage:dc.w (((plcGHZAnimals-plcSpecialStage-2)/6)-1)

plcGHZAnimals:	dc.w (((plcLZAnimals-plcGHZAnimals-2)/6)-1)
	dc.l ArtAnimalPocky
	dc.w $B000
	dc.l ArtAnimalCucky
	dc.w $B240

plcLZAnimals:	dc.w (((plcMZAnimals-plcLZAnimals-2)/6)-1)
	dc.l ArtAnimalPecky
	dc.w $B000
	dc.l ArtAnimalRocky
	dc.w $B240

plcMZAnimals:	dc.w (((plcSLZAnimals-plcMZAnimals-2)/6)-1)
	dc.l ArtAnimalPicky
	dc.w $B000
	dc.l ArtAnimalFlicky
	dc.w $B240

plcSLZAnimals:	dc.w (((plcSYZAnimals-plcSLZAnimals-2)/6)-1)
	dc.l ArtAnimalRicky
	dc.w $B000
	dc.l ArtAnimalRocky
	dc.w $B240

plcSYZAnimals:	dc.w (((plcSBZAnimals-plcSYZAnimals-2)/6)-1)
	dc.l ArtAnimalPicky
	dc.w $B000
	dc.l ArtAnimalCucky
	dc.w $B240

plcSBZAnimals:	dc.w (((plcEnd-plcSBZAnimals-2)/6)-1)
	dc.l ArtAnimalPocky
	dc.w $B000
	dc.l ArtAnimalFlicky
	dc.w $B240
plcEnd:

ArtCred:    incbin "screens/credits/CreditsText/Sprite.nem"
	even
ArtSega:    incbin "screens/sega/Main.twim"
	even
MapSega:    incbin "unknown/18A56.eni"
	even
ArtSplash:  incbin "Splash/SPLASHART.bin"
	even
MapSplash:  incbin "Splash/SPLASHMAP.bin"
	even
MapTitle: 	incbin "unknown/18A62.eni"
	even
ArtTitleMain:	incbin "screens/title/Main.twim"
	even
ArtTitleSonic:	incbin "screens/title/Sonic.twim"
	even
	include "levels/shared/Sonic/sprite.map"
	include "levels/shared/Sonic/dynamic.map"
	align $8000,0
ArtSonic:   incbin "levels/shared/Sonic/Art.unc"
	even

byte_1C8EF:
ArtSmoke:   incbin "unsorted/smoke.nem"
	even
ArtShield:  incbin "levels/shared/Shield/Shield.nem"
	even
ArtInvinStars:	incbin "levels/shared/Shield/Stars.nem"
	even
ArtFlash:   incbin "unsorted/flash.nem"
	even
ArtSpecialRing:	incbin "levels/shared/Big ring/Sprite.nem"
	even
byte_27400: incbin "unsorted/ghz flower stalk.nem"
	even
byte_2744A: incbin "unsorted/ghz swing.nem"
	even
ArtBridge:  incbin "levels/GHZ/Bridge/Art.nem"
	even
byte_27698: incbin "unsorted/ghz checkered ball.nem"
	even
ArtSpikes:  incbin "levels/shared/Spikes/Art.nem"
	even
ArtSpikeLogs:	incbin "levels/GHZ/SpikeLogs/Art.nem"
	even
ArtPurpleRock:	incbin "levels/GHZ/PurpleRock/Art.nem"
	even
ArtSmashWall:	incbin "levels/GHZ/SmashWall/Art.nem"
	even
ArtWall:	incbin "levels/GHZ/Wall/Art.nem"
	even
ArtChainPtfm:	incbin "levels/MZ/ChainPtfm/Art.nem"
	even
ArtButtonMZ:	incbin "levels/shared/Switch/Art MZ.nem"
	even
byte_2816E: incbin "unsorted/mz piston.nem"
	even
byte_2827A: incbin "unsorted/mz fire ball.nem"
	even
byte_28558: incbin "unsorted/mz lava.nem"
	even
byte_28E6E: incbin "levels/MZ/PushBlock/Art.nem"
	even
ArtSeesaw:  incbin "levels/SLZ/Seesaw/Art.nem"
	even
ArtFan:     incbin "levels/SLZ/Fan/Art.nem"
	even
byte_294DA: incbin "unsorted/slz platform.nem"
	even
byte_2953C: incbin "unsorted/slz girders.nem"
	even
byte_2961E: incbin "unsorted/slz spiked platforms.nem"
	even
byte_297B6: incbin "unsorted/slz misc platforms.nem"
	even
byte_29D4A: incbin "unsorted/slz metal block.nem"
	even
ArtBumper:  incbin "levels/SYZ/Bumper/Art.nem"
	even
byte_29FC0: incbin "unsorted/syz small spiked ball.nem"
	even
ArtButton:  incbin "levels/shared/Switch/Art.nem"
	even
byte_2A104: incbin "unsorted/swinging spiked ball.nem"
	even
ArtCrabmeat:	incbin "levels/GHZ/Crabmeat/Art.nem"
	even
ArtBuzzbomber:	incbin "levels/GHZ/Buzzbomber/Art.nem"
	even
ArtChopper: incbin "levels/GHZ/Chopper/Art.nem"
	even
ArtJaws:    incbin "levels/LZ/Jaws/Art.nem"
	even
byte_2BC04: incbin "unsorted/roller.nem"
	even
ArtMotobug: incbin "levels/GHZ/Motobug/Art.nem"
	even
ArtNewtron: incbin "levels/GHZ/Newtron/Art.nem"
	even
ArtYardin:  incbin "levels/shared/Yadrin/Art.nem"
	even
ArtBasaran: incbin "levels/MZ/Basaran/Art.nem"
	even
ArtSplats:  incbin "levels/shared/Splats/Art.nem"
	even
ArtTitleCards:	incbin "levels/shared/Title Cards/Art.unc"
ArtTitleCards_End:	  even
ArtHUD:     incbin "levels/shared/HUD/Main.nem"
	even
ArtLives:   incbin "levels/shared/HUD/Lives.nem"
	even
ArtRings:   incbin "levels/shared/Rings/Art.nem"
	even
ArtMonitors:	incbin "levels/shared/Monitors/Art.nem"
	even
ArtExplosions:	incbin "levels/shared/Explosions/Art.nem"
	even
byte_2E6C8: incbin "unsorted/score points.nem"
	even
ArtGameOver:	incbin "levels/shared/GameOver/Art.nem"
	even
ArtSpringHoriz: incbin "levels/shared/Spring/Art Horizontal.nem"
	even
ArtSpringVerti: incbin "levels/shared/Spring/Art Vertical.nem"
	even
ArtSignPost:	incbin "levels/shared/Signpost/Art.nem"
	even
ArtAnimalPocky: incbin "levels/shared/Animals/Pocky.nem"
	even
ArtAnimalCucky: incbin "levels/shared/Animals/Cucky.nem"
	even
ArtAnimalPecky: incbin "levels/shared/Animals/Pecky.nem"
	even
ArtAnimalRocky: incbin "levels/shared/Animals/Rocky.nem"
	even
ArtAnimalPicky: incbin "levels/shared/Animals/Picky.nem"
	even
ArtAnimalFlicky:incbin "levels/shared/Animals/Flicky.nem"
	even
ArtAnimalRicky: incbin "levels/shared/Animals/Ricky.nem"
	even
byte_60000: incbin "unknown/60000.dat"
	even
byte_60864: incbin "unknown/60864.dat"
	even
byte_60BB0: incbin "unknown/60BB0.dat"
	even
byte_6B018: incbin "unknown/6B018.dat"
	even
byte_6B218: incbin "unknown/6B218.dat"
	even
byte_6B618: incbin "unknown/6B618.dat"
	even
byte_6BA98: incbin "unknown/6BA98.dat"
	even
byte_6BD98: incbin "unknown/6BD98.dat"
	even
byte_6C398: incbin "unknown/6C398.dat"
	even
byte_6C998: incbin "unknown/6C998.dat"
	even

BlocksGHZ:  incbin "levels/GHZ/Blocks.eni"
	even
TilesGHZ:   incbin "levels/GHZ/Tiles.nem"
	even
ChunksGHZ:  incbin "levels/GHZ/Chunks.kosp"
	even
BlocksLZ:   incbin "levels/LZ/Blocks.eni"
	even
TilesLZ:    incbin "levels/LZ/Tiles.nem"
	even
ChunksLZ:   incbin "levels/LZ/Chunks.kosp"
	even
BlocksMZ:   incbin "levels/MZ/Blocks.eni"
	even
TilesMZ:    incbin "levels/MZ/Tiles.nem"
	even
ChunksMZ:   incbin "levels/MZ/Chunks.kosp"
	even
BlocksSLZ:  incbin "levels/SLZ/Blocks.eni"
	even
TilesSLZ:   incbin "levels/SLZ/Tiles.nem"
	even
ChunksSLZ:  incbin "levels/SLZ/Chunks.kosp"
	even
BlocksSYZ:  incbin "levels/SYZ/Blocks.eni"
	even
TilesSYZ:   incbin "levels/SYZ/Tiles.nem"
	even
ChunksSYZ:  incbin "levels/SYZ/Chunks.kosp"
	even
BlocksSBZ:  incbin "levels/SBZ/Blocks.eni"
	even
TilesSBZ:   incbin "levels/SBZ/Tiles.nem"
	even
ChunksSBZ:  incbin "levels/SBZ/Chunks.kosp"
	even
BlocksTS:   incbin "levels/TS/Blocks.twiz"
	even
TilesTS:    incbin "levels/TS/Tiles.twim"
	even
ChunksTS:   incbin "levels/TS/Chunks.twiz"
	even

colAngles:  incbin "levels/shared/Collision Angles.dat"
	even
colWidth:   incbin "levels/shared/Collision Widths.dat"
	even
colHeight:  incbin "levels/shared/Collision Heights.dat"
	even
colGHZ:     incbin "levels/GHZ/Collision.dat"
	even
colLZ:	    incbin "levels/LZ/Collision.dat"
	even
colMZ:	    incbin "levels/MZ/Collision.dat"
	even
colSLZ:     incbin "levels/SLZ/Collision.dat"
	even
colSYZ:     incbin "levels/SYZ/Collision.dat"
	even
colSBZ:     incbin "levels/SBZ/Collision.dat"
	even

LayoutArray:
	dc.w LayoutGHZ1FG-LayoutArray, LayoutGHZ1BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutGHZ2FG-LayoutArray, LayoutGHZ2BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutGHZ3FG-LayoutArray, LayoutGHZ3BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutGHZ3FG-LayoutArray, LayoutGHZ3BG-LayoutArray, LayoutEnding1BG-LayoutArray
	dc.w LayoutLZ1FG-LayoutArray, LayoutLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutLZ2FG-LayoutArray, LayoutLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutLZ3FG-LayoutArray, LayoutLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutLZ3FG-LayoutArray, LayoutLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutMZ1FG-LayoutArray, LayoutMZ1BG-LayoutArray, LayoutMZ1FG-LayoutArray
	dc.w LayoutMZ2FG-LayoutArray, LayoutMZ2BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutMZ3FG-LayoutArray, LayoutMZ3BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutMZ3FG-LayoutArray, LayoutMZ3BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSLZ1FG-LayoutArray, LayoutSLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSLZ2FG-LayoutArray, LayoutSLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSLZ3FG-LayoutArray, LayoutSLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSLZ3FG-LayoutArray, LayoutSLZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSYZ1FG-LayoutArray, LayoutSYZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSYZ2FG-LayoutArray, LayoutSYZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSYZ3FG-LayoutArray, LayoutSYZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSYZ3FG-LayoutArray, LayoutSYZBG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSBZ1FG-LayoutArray, LayoutSBZ2FG-LayoutArray, LayoutSBZ2FG-LayoutArray
	dc.w LayoutSBZ2FG-LayoutArray, LayoutSBZ2BG-LayoutArray, LayoutSBZ2BG-LayoutArray
	dc.w LayoutSBZ2FG-LayoutArray, LayoutSBZ2BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutSBZ2FG-LayoutArray, LayoutSBZ2BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutEnding1FG-LayoutArray, LayoutEnding1BG-LayoutArray, LayoutEnding1BG-LayoutArray
	dc.w LayoutEnding1FG-LayoutArray, LayoutEnding1BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutEnding1FG-LayoutArray, LayoutEnding1BG-LayoutArray, byte_6E3D6-LayoutArray
	dc.w LayoutEnding1FG-LayoutArray, LayoutEnding1BG-LayoutArray, byte_6E3D6-LayoutArray
LayoutGHZ1FG:	incbin "levels/GHZ/Foreground 1.unc"
	even
LayoutGHZ1BG:	incbin "levels/GHZ/Background 1.unc"
	even
LayoutGHZ2FG:	incbin "levels/GHZ/Foreground 2.unc"
	even
LayoutGHZ2BG:	incbin "levels/GHZ/Background 2.unc"
	even
LayoutGHZ3FG:	incbin "levels/GHZ/Foreground 3.unc"
	even
LayoutGHZ3BG:	incbin "levels/GHZ/Background 3.unc"
	even
LayoutLZ1FG:	incbin "levels/LZ/Foreground 1.unc"
	even
LayoutLZBG: 	incbin "levels/LZ/Background.unc"
	even
LayoutLZ2FG:	incbin "levels/LZ/Foreground 2.unc"
	even
LayoutLZ3FG:	incbin "levels/LZ/Foreground 3.unc"
	even
LayoutMZ1FG:	incbin "levels/MZ/Foreground 1.unc"
	even
LayoutMZ1BG:	incbin "levels/MZ/Background 1.unc"
	even
LayoutMZ2FG:	incbin "levels/MZ/Foreground 2.unc"
	even
LayoutMZ2BG:	incbin "levels/MZ/Background 2.unc"
	even
LayoutMZ3FG:	incbin "levels/MZ/Foreground 3.unc"
	even
LayoutMZ3BG:	incbin "levels/MZ/Background 3.unc"
	even
LayoutSLZ1FG:	incbin "levels/SLZ/Foreground 1.unc"
	even
LayoutSLZBG:	incbin "levels/SLZ/Background.unc"
	even
LayoutSLZ2FG:	incbin "levels/SLZ/Foreground 2.unc"
	even
LayoutSLZ3FG:	incbin "levels/SLZ/Foreground 3.unc"
	even
LayoutSYZ1FG:	incbin "levels/SYZ/Foreground 1.unc"
	even
LayoutSYZBG:	incbin "levels/SYZ/Background.unc"
	even
LayoutSYZ2FG:	incbin "levels/SYZ/Foreground 2.unc"
	even
LayoutSYZ3FG:	incbin "levels/SYZ/Foreground 3.unc"
	even
LayoutSBZ1FG:	incbin "levels/SBZ/Foreground 1.unc"
	even
LayoutSBZ2FG:	incbin "levels/SBZ/Foreground 2.unc"
	even
LayoutSBZ2BG:	incbin "levels/SBZ/Background 2.unc"
	even
LayoutEnding1FG:
LayoutEnding1BG:

byte_6E3D6: dc.b 0, 0, 0, 0

ObjectListArray:dc.w ObjListGHZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListGHZ2-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListGHZ3-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListGHZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListLZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListLZ2-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListLZ3-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListLZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListMZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListMZ2-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListMZ3-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListMZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSLZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSLZ2-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSLZ3-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSLZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSYZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSYZ2-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSYZ3-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSYZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSBZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSBZ2-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSBZ3-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListSBZ1-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListNull-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListNull-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListNull-ObjectListArray, ObjListNull-ObjectListArray
	dc.w ObjListNull-ObjectListArray, ObjListNull-ObjectListArray
ObjListGHZ1:	incbin "levels/GHZ/Objects 1.unc"
	even
ObjListGHZ2:	incbin "levels/GHZ/Objects 2.unc"
	even
ObjListGHZ3:	incbin "levels/GHZ/Objects 3.unc"
	even
ObjListLZ1: 	incbin "levels/LZ/Objects 1.unc"
	even
ObjListLZ2: 	incbin "levels/LZ/Objects 2.unc"
	even
ObjListLZ3: 	incbin "levels/LZ/Objects 3.unc"
	even
ObjListMZ1: 	incbin "levels/MZ/Objects 1.unc"
	even
ObjListMZ2: 	incbin "levels/MZ/Objects 2.unc"
	even
ObjListMZ3: 	incbin "levels/MZ/Objects 3.unc"
	even
ObjListSLZ1:	incbin "levels/SLZ/Objects 1.unc"
	even
ObjListSLZ2:	incbin "levels/SLZ/Objects 2.unc"
	even
ObjListSLZ3:	incbin "levels/SLZ/Objects 3.unc"
	even
ObjListSYZ1:	incbin "levels/SYZ/Objects 1.unc"
	even
ObjListSYZ2:	incbin "levels/SYZ/Objects 2.unc"
	even
ObjListSYZ3:	incbin "levels/SYZ/Objects 3.unc"
	even
ObjListSBZ1:	incbin "levels/SBZ/Objects 1.unc"
	even
ObjListSBZ2:	incbin "levels/SBZ/Objects 2.unc"
	even
ObjListSBZ3:	incbin "levels/SBZ/Objects 3.unc"
	even

ObjListNull:	dc.w $FFFF, 0, 0
	even

demoin_GHZ:
		;incbin	"demos/GHZ1.bin"
		even
demoin_LZ:
		even
demoin_MZ:
		even
demoin_SLZ:
		even
demoin_SYZ:
		even
demoin_SBZ:
		even
demoin_SS:
		even

MSUMD_DRV:	incbin	"msu\msu-drv.bin"
	even

msuLockout:	incbin	"msu\msuLockout.bin"
	even
	
; end of 'ROM'
	include	"AMPS/code/smps2asm.asm"
	include	"AMPS/code/68k.asm"

DualPCM:
	PUSHS							; store section information for Main
Z80Code	SECTION	org(0),	file("AMPS/.z80")			; create a new section for Dual PCM
	z80prog	0						; init z80 program
	include	"AMPS/code/z80.asm"				; code for Dual PCM
DualPCM_sz:	z80prog						; end z80 program
	POPS							; go back to Main section

	PUSHS							; store section information for Main
mergecode	SECTION file("AMPS/.z80.dat"),	org(0)		; create settings file for storing info about how to merge things
	dc.l	offset(DualPCM),	Z80_Space		; store info about location of file and size available

	if zchkoffs
	rept zfuturec
		popp	zoff		; grab the location of the patch
		popp	zbyte		; grab the correct byte
		dc.w	zoff		; write the address
		dc.b	zbyte,	'>'	; write the byte and separator
	endr
	endif
	POPS				; go back to Main section

	ds.b	Z80_Space		; reserve space for the Z80 driver
	even
	opt ae+
	include	"error/ErrorHandler.asm"
; ===========================================================================
EndOfROM:	end
