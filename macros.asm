

align		macro pos,num
	if narg=1
		dcb.b ((\pos)-(offset(*)%(\pos)))%(\pos),$FF
	else
		dcb.b ((\pos)-(offset(*)%(\pos)))%(\pos),num
	endif
	endm
	
; Macro for playing a command
command		macro id
	move.b #id,mQueue.w
    endm

; Macro for playing music
music		macro id
	move.b #id,mQueue+1.w
    endm

; Macro for playing sound effect
sfx		macro id
	move.b #id,mQueue+2.w
    endm
		
; ---------------------------------------------------------------------------
; self-explanatory
; ---------------------------------------------------------------------------

disable_ints:	macro
		move	#$2700,sr
		endm

enable_ints:	macro
		move	#$2300,sr
		endm
		
vsync:			macro
		enable_ints
@wait\@:	tst.b	(VintRoutine).w
		bne.s	@wait\@
		endm
; ---------------------------------------------------------------------------

; enum object, width 64 bytes
id		equ 0
render		equ 1
tile		equ 2
map		equ 4
xpos		equ 8
xpix		equ $A
ypos		equ $C
ypix		equ $E
xvel		equ $10
yvel		equ $12
yrad		equ $16
xrad		equ $17
prio		equ $18
frame		equ $1A
anipos		equ $1B
ani		equ $1C
anilast		equ $1D
anidelay	equ $1E
col		equ $20
colprop		equ $21
status		equ $22
respawn		equ $23
act		equ $24
subact		equ $25
angle		equ $26
arg		equ $28
size		equ $40

; ---------------------------------------------------------------------------

; enum player, width 64 bytes
inertia		equ $14
air		equ $20
invulnerable	equ $30
invincible	equ $32
speedshoes	equ $34
sensorfront	equ $36
sensorback	equ $37
convex		equ $38
spindashflag equ $39
spindashtimer equ $3A
jumping		equ $3C
platform	equ $3D
lock		equ $3E

; ---------------------------------------------------------------------------

; sonic 2 naming convention
x_pos	equ	xpos
y_pos	equ	ypos
x_sub	equ	xpix
y_sub	equ	ypix
x_vel	equ	xvel
y_vel	equ	yvel
x_radius	equ	xrad
y_radius	equ	yrad
routine	equ	act
routine_secondary	equ	subact
priority	equ	prio
move_lock	equ	lock
stick_to_convex	equ	convex
subtype	equ	arg
anim_frame_duration	equ	anilast
collision_flags	equ	col
collision_property	equ	colprop
anim_frame	equ	anipos
anim	equ	ani
art_tile	equ	tile
render_flags	equ	render
mappings	equ	map
mapping_frame	equ	frame
invulnerable_time	equ	invulnerable
invincibility_time	equ	invincible
speedshoes_time	equ	speedshoes
next_tilt	equ	sensorfront
tilt	equ	sensorback
spindash_flag	equ	spindashflag
spindash_counter	equ	spindashtimer
interact	equ	platform

; ---------------------------------------------------------------------------
; long conditional jumps
; ---------------------------------------------------------------------------

jhi:		macro loc
		bls.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jcc:		macro loc
		bcs.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jhs:		macro loc
		jcc	loc
		endm

jls:		macro loc
		bhi.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jcs:		macro loc
		bcc.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jlo:		macro loc
		jcs	loc
		endm

jeq:		macro loc
		bne.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jne:		macro loc
		beq.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jgt:		macro loc
		ble.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jge:		macro loc
		blt.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jle:		macro loc
		bgt.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jlt:		macro loc
		bge.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jpl:		macro loc
		bmi.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

jmi:		macro loc
		bpl.s	.nojump\@
		jmp	loc
	.nojump\@:
		endm

SetGfxMode macro mode
    move.w  #VDPREG_MODE4|(mode), (VdpCtrl)
    endm
	
VDPREG_MODE1:     equ $8000  ; Mode register #1
VDPREG_MODE2:     equ $8100  ; Mode register #2
VDPREG_MODE3:     equ $8B00  ; Mode register #3
VDPREG_MODE4:     equ $8C00  ; Mode register #4

VDPREG_PLANEA:    equ $8200  ; Plane A table address
VDPREG_PLANEB:    equ $8400  ; Plane B table address
VDPREG_SPRITE:    equ $8500  ; Sprite table address
VDPREG_WINDOW:    equ $8300  ; Window table address
VDPREG_HSCROLL:   equ $8D00  ; HScroll table address

VDPREG_SIZE:      equ $9000  ; Plane A and B size
VDPREG_WINX:      equ $9100  ; Window X split position
VDPREG_WINY:      equ $9200  ; Window Y split position
VDPREG_INCR:      equ $8F00  ; Autoincrement
VDPREG_BGCOL:     equ $8700  ; Background color
VDPREG_HRATE:     equ $8A00  ; HBlank interrupt rate

VDPREG_DMALEN_L:  equ $9300  ; DMA length (low)
VDPREG_DMALEN_H:  equ $9400  ; DMA length (high)
VDPREG_DMASRC_L:  equ $9500  ; DMA source (low)
VDPREG_DMASRC_M:  equ $9600  ; DMA source (mid)
VDPREG_DMASRC_H:  equ $9700  ; DMA source (high)

VdpCtrl:    equ $C00004  ; VDP control port
VdpData:    equ $C00000  ; VDP data port
HvCounter:  equ $C00008  ; H/V counter

GFXMODE_256x224:      equ %00000000
GFXMODE_320x224:      equ %10000001
GFXMODE_256x448:      equ %00000110
GFXMODE_320x448:      equ %10000111
GFXMODE_256x224_SH:   equ %00001000
GFXMODE_320x224_SH:   equ %10001001
GFXMODE_256x448_SH:   equ %00001110
GFXMODE_320x448_SH:   equ %10001111

VRAM_ADDR_CMD:  equ $40000000
CRAM_ADDR_CMD:  equ $C0000000
VSRAM_ADDR_CMD: equ $40000010

VRAM_DMA_CMD:   equ $40000080
CRAM_DMA_CMD:   equ $C0000080
VSRAM_DMA_CMD:  equ $40000090