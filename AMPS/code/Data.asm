; ===========================================================================
; ---------------------------------------------------------------------------
; Flags section. None of this is required, but I added it here to
; make it easier to debug built ROMS! If you would like easier
; assistance from Natsumi, please keep this section intact!
; ---------------------------------------------------------------------------
	;dc.b "AMPS-v2.1"		; ident str

	;if safe
	;	dc.b "s"		; safe mode enabled

	;else
	;	dc.b " "		; safe mode disabled
	;endif

	;if FEATURE_FM6
	;	dc.b "F6"		; FM6 enabled
	;endif

	;if FEATURE_SFX_MASTERVOL
	;	dc.b "SM"		; sfx ignore master volume
	;endif

	;if FEATURE_UNDERWATER
	;	dc.b "UW"		; underwater mode enabled
	;endif

	;if FEATURE_MODULATION
	;	dc.b "MO"		; modulation enabled
	;endif

	;if FEATURE_DACFMVOLENV
	;	dc.b "VE"		; FM & DAC volume envelope enabled
	;endif

	;if FEATURE_MODENV
	;	dc.b "ME"		; modulation envelope enabled
	;endif

	;if FEATURE_PORTAMENTO
	;	dc.b "PM"		; portamento enabled
	;endif

	;if FEATURE_BACKUP
	;	dc.b "BA"		; backup enabled
	;endif

	;if FEATURE_SOUNDTEST
	;	dc.b "ST"		; soundtest enabled
	;endif
; ===========================================================================
; ---------------------------------------------------------------------------
; Define music and SFX
; ---------------------------------------------------------------------------

	opt oz-				; disable zero-offset optimization
	if safe=0
		nolist			; if in safe mode, list data section.
	endif

__mus =		MusOff

MusicIndex:
	ptrMusic GHZ, $07, LZ, $72, MZ, $73, SLZ, $26, SYZ, $15, SBZ, $08, FZ, $18
	ptrMusic Boss, $12, SS, $00, Invincibility, $FF, Title, $00, GotThroughAct, $00, ExtraLife, $05
	ptrMusic GameOver, $00, Continue, $00, Options, $00, Splash, $00, SEGA, $00

MusCount =	__mus-MusOff		; number of installed music tracks
SFXoff =	__mus			; first SFX ID
__sfx =		SFXoff
; ---------------------------------------------------------------------------

SoundIndex:
	ptrSFX	$01, RingRight
	ptrSFX	0, RingLeft, RingLoss, Break, Jump, Roll
	ptrSFX	0, Bubble, Drown, SpikeHit, Death
	ptrSFX	0, Register, Bonus, Shield, Dash, BossHit
	ptrSFX	0, Signpost, Lamppost, BigRing, Bumper, Spring
	ptrSFX	0, Collapse, Smash, BuzzExplode, Explode
	ptrSFX	0, Electricity, Flame, LavaBall, SpikeMove, Rumble, AirDing
	ptrSFX	0, Door, Stomp, EnterSS, Goal, ActionBlock, Diamonds, Continue, Spindash

; SFX with special features
	ptrSFX	$80, PushBlock, Waterfall, Skid, Basaran, Chain, Saw, Lava, Metal, Pounding, Alarm, Switch

; unused SFX
	ptrSFX	0, UnkA2, UnkAB, UnkB8, Buzzer

	ptrSFX 	0, Select, Pop, Woosh

SFXcount =	__sfx-SFXoff		; number of intalled sound effects
SFXlast =	__sfx
; ===========================================================================
; ---------------------------------------------------------------------------
; Define samples
; ---------------------------------------------------------------------------

__samp =	$80
SampleList:
	sample $0000, Stop, Stop					; 80 - Stop sample (DO NOT EDIT)
	sample $0100, Kick, Stop					; 81 - Kick
	sample $0100, Snare, Stop					; 82 - Snare
	sample $0100, Timpani, Stop, HiTimpani		; 83 - Hi Timpani
	sample $00E6, Timpani, Stop, MidTimpani		; 84 - Timpani
	sample $00C2, Timpani, Stop, LowTimpani		; 85 - Low Timpani
	sample $00B6, Timpani, Stop, FloorTimpani	; 86 - Floor Timpani
	sample $0100, Tom, Stop, HiTom				; 87 - Hi Tom
	sample $00E6, Tom, Stop, MidTom				; 88 - Mid Tom
	sample $00C2, Tom, Stop, LowTom				; 89 - Low Tom
	sample $00B6, Tom, Stop, FloorTom			; 8A - Floor Tom
	sample $0100, Sega, Stop					; 8B - SEGA screen
	sample $0100, SonicClear, Stop				; 8C - Sonic (act results)
	sample $0100, SonicHurt, Stop				; 8D - Sonic (when he gets hurt)
	sample $0100, SonicDeath, Stop				; 8E - Sonic (when he dies)
	sample $0100, SonicLife, Stop				; 8F - Sonic (extra life)
	sample $0100, Lava, Lava					; 90 - Lava (loop)
	sample $0100, Guitar1, Stop					; 91 - Power guitar chord 1
	sample $0100, Guitar2, Stop					; 92 - Power guitar chord 2
	sample $0100, Guitar3, Stop					; 93 - Power guitar chord 3
	sample $0100, CrashCymbal, Stop				; 94 - Crash Cymbal
	sample $0100, DGSel, Stop					; 95 - "Select" (DGamer)
	sample $0100, DGPop, Stop					; 96 - "Pop" (DGamer)
	sample $0100, DGWoosh, Stop					; 97 - "Whoosh" (DGamer)
	sample $0100, Congrats, Stop				; 98 - "Congratulations!" (MASATOG 2008 (DS))
	even
; ===========================================================================
; ---------------------------------------------------------------------------
; Define volume envelopes and their data
; ---------------------------------------------------------------------------

vNone =		$00
__venv =	$01

VolEnvs:
	volenv 01, 02, 03, 04, 05, 06, 07, 08
	volenv 09, 0A, 0B, 0C, 0D
VolEnvs_End:
; ---------------------------------------------------------------------------

vd01:		dc.b $00, $00, $00, $08, $08, $08, $10, $10
		dc.b $10, $18, $18, $18, $20, $20, $20, $28
		dc.b $28, $28, $30, $30, $30, $38, eHold

vd02:		dc.b $00, $10, $20, $30, $40, $7F, eStop

vd03:		dc.b $00, $00, $08, $08, $10, $10, $18, $18
		dc.b $20, $20, $28, $28, $30, $30, $38, $38
		dc.b eHold

vd04:		dc.b $00, $00, $10, $18, $20, $20, $28, $28
		dc.b $28, $30, eHold

vd05:		dc.b $00, $00, $00, $00, $00, $00, $00, $00
		dc.b $00, $00, $08, $08, $08, $08, $08, $08
		dc.b $08, $08, $08, $08, $08, $08, $08, $08
		dc.b $10, $10, $10, $10, $10, $10, $10, $10
		dc.b $18, $18, $18, $18, $18, $18, $18, $18
		dc.b $20, eHold

vd06:		dc.b $18, $18, $18, $10, $10, $10, $10, $08
		dc.b $08, $08, $00, $00, $00, $00, eHold

vd07:		dc.b $00, $00, $00, $00, $00, $00, $08, $08
		dc.b $08, $08, $08, $10, $10, $10, $10, $10
		dc.b $18, $18, $18, $20, $20, $20, $28, $28
		dc.b $28, $30, $38, eHold

vd08:		dc.b $00, $00, $00, $00, $00, $08, $08, $08
		dc.b $08, $08, $10, $10, $10, $10, $10, $10
		dc.b $18, $18, $18, $18, $18, $20, $20, $20
		dc.b $20, $20, $28, $28, $28, $28, $28, $30
		dc.b $30, $30, $30, $30, $38, $38, $38, eHold

vd09:		dc.b $00, $08, $10, $18, $20, $28, $30, $38
		dc.b $40, $48, $50, $58, $60, $68, $70, $78
		dc.b eStop
		
vd0A:		dc.b $00, $00, $00, $00, $00, $00, $00, $00
		dc.b $00, $00, $08, $08, $08, $08, $08, $08
		dc.b $08, $08, $08, $08, $08, $08, $08, $08
		dc.b $08, $08, $08, $08, $08, $08, $08, $08
		dc.b $08, $08, $08, $08, $08, $08, $08, $08
		dc.b $10, $10, $10, $10, $10, $10, $10, $10
		dc.b $10, $10, $18, $18, $18, $18, $18, $18
		dc.b $18, $18, $18, $18, $20, eHold

vd0B:		dc.b $20, $20, $20, $18, $18, $18, $10, $10
		dc.b $10, $08, $08, $08, $08, $08, $08, $08
		dc.b $10, $10, $10, $10, $10, $18, $18, $18
		dc.b $18, $18, $20, eReset

vd0C:		dc.b $20, $20, $18, $18, $10, $10, $08, $08
		dc.b $08, $08, $08, $08, $08, $08, $08, $08
		dc.b $08, $08, $08, $08, $08, $08, $08, $08
		dc.b $08, $08, $10, $10, $10, $10, $10, $10
		dc.b $10, $10, $10, $10, $10, $10, $10, $10
		dc.b $10, $10, $10, $10, $10, $10, $18, $18
		dc.b $18, $18, $18, $18, $18, $18, $18, $18
		dc.b $18, $18, $18, $18, $18, $18, $18, $18
		dc.b $18, $18, $20, $20, $20, $20, $20, $20
		dc.b $20, $20, $20, $20, $20, $20, $20, $20
		dc.b $20, $20, $20, $20, $20, $20, $28, $28
		dc.b $28, $28, $28, $28, $28, $28, $28, $28
		dc.b $28, $28, $28, $28, $28, $28, $28, $28
		dc.b $28, $28, $30, $30, $30, $30, $30, $30
		dc.b $30, $30, $30, $30, $30, $30, $30, $30
		dc.b $30, $30, $30, $30, $30, $30, $38, eHold

vd0D:		dc.b $70, $68, $60, $58, $50, $48, $40, $38
		dc.b $30, $28, $20, $18, $10, $08, $00, eHold
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Define volume envelopes and their data
; ---------------------------------------------------------------------------

mNone =		$00
__menv =	$01

ModEnvs:
	modenv
ModEnvs_End:
; ---------------------------------------------------------------------------

	if FEATURE_MODENV

	endif

; ===========================================================================
; ---------------------------------------------------------------------------
; Include music, sound effects and voice bank
; ---------------------------------------------------------------------------

	include "AMPS/Voices.s2a"	; include universal voice bank
	opt ae-				; disable automatic evens
; ---------------------------------------------------------------------------

sfxaddr	incSFX				; include all sfx
musaddr	incMus				; include all music
musend
; ===========================================================================
; ---------------------------------------------------------------------------
; Include samples and filters
; ---------------------------------------------------------------------------

		align	$8000		; must be aligned to bank. By the way, these are also used in Z80.asm. Be sure to check it out
fLog:		incbin "AMPS/filters/Logarithmic.dat"	; logarithmic filter (no filter)
;fLinear:	incbin "AMPS/filters/Linear.dat"	; linear filter (no filter)

dacaddr		dcb.b Z80E_Read*(MaxPitch/$100),$00
SWF_Stop:	dcb.b $8000-(2*Z80E_Read*(MaxPitch/$100)),$80
SWFR_Stop:	dcb.b Z80E_Read*(MaxPitch/$100),$00
; ---------------------------------------------------------------------------

	incSWF	Kick, Timpani, Snare, SonicClear, SonicDeath, SonicHurt, SonicLife
	incSWF	Tom, Lava, Sega, CrashCymbal
	incSWF	Guitar1, Guitar2, Guitar3
	incSWF 	Congrats, DGSel, DGPop, DGWoosh
	even
	opt ae+				; enable automatic evens
	list				; continue source listing
; ---------------------------------------------------------------------------
