; -----------------------------------------------------------------------------------
  ; SEGMENT SETUP

.segment "HEADER"
    .byte $4E, $45, $53, $1A      ; N E S EOF
    .byte $02                     ; 2 * 16KB PRG ROM
    .byte $01                     ; 1 * 8KB CHR ROM
    .byte %00000001               ; mapper and mirroring
    .byte $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00 ; filler bytes

.segment "VECTORS"
    .word NMI
    .word Reset
    ; irq (not used)

.segment "CHARS"
    .incbin "spacetry2.chr"

.segment "ZEROPAGE" ; LSB 0 - FF
  ; Variables
    Buttons: .res 1
    cmpButtons: .res 1
    ship_x: .res 1
    ship_y: .res 1

  ; Constants
    JOYPAD1 = $4016
    JOYPAD2 = $4017




; -----------------------------------------------------------------------------------
  ; INIT CODE

.segment "STARTUP"
Reset: 
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ; move all sprites off screen
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

; -----------------------------------------------------------------------------------
  ; HANDLES PALETTES

LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00

LoadPalettesLoop:
  LDA PaletteData, x    ; load palette byte
  STA $2007             ; write to PPU
  INX                   ; set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop  ; if x = $20, 32 bytes copied, all done

; -----------------------------------------------------------------------------------
  ; HANDLES SPRITES

  LDX #$00

LoadSprites:
  LDA SpriteData, X   ; start loop (address of sprites+x)
  STA $0200, X
  INX                 ; x = x+1
  CPX #$20
  BNE LoadSprites     ; Loop until x = $20

  ; Enables NMI, sprites 
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0
  STA $2000
  LDA #%00011000   ; enable sprites
  STA $2001

  ; Initial Postion for Player (UFO)
  LDA $200
  STA ship_y
  LDA $203
  STA ship_x




; -----------------------------------------------------------------------------------
  ; RESET LOOP + NMI STUFF

Forever:          ; rti doesn't work with RESET
  JMP Forever     ; jump back to Forever, infinite loop
  
NMI:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer

  JSR ReadJoypad1
  JSR MovePlayer

  LDA #0
  STA $2006
  STA $2006

  ; Enables NMI, sprites 
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0
  STA $2000
  LDA #%00011000   ; enable sprites
  STA $2001

  rti

; -----------------------------------------------------------------------------------
  ; CONTROLLERS

  ; NesHacker explains controller HW+SW: https://www.youtube.com/watch?v=nAStgQzPrAQ

  ; From nesdev: https://www.nesdev.org/wiki/Controller_reading_code
  ; At the same time that we strobe bit 0, we initialize the ring counter
  ; so we're hitting two birds with one stone here

ReadJoypad1:
    LDA #$01
    ; While the strobe bit is set, buttons will be continuously reloaded.
    ; This means that reading from JOYPAD1 will only return the state of the
    ; first button: button A.
    STA JOYPAD1
    STA Buttons
    LSR a        ; now A is 0
    ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
    ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
    STA JOYPAD1
@loop:
    LDA JOYPAD1
    LSR a        ; bit 0 -> Carry
    ROL Buttons  ; Carry -> bit 0; bit 7 -> Carry
    BCC @loop     ; Only exits when Carry Flag = 1
    RTS  

; -----------------------------------------------------------------------------------
  ; PLAYER MOVEMENT

MovePlayer:
  LDA #1
  STA cmpButtons

@CheckButtonsPressed:
  LDA Buttons
  AND cmpButtons           ; 1=Branch, 0=Don't branch
  BNE @WhichButtonsPressed 
  ROL cmpButtons           ; branch fails (==0), button is NOT pressed
  BCC @CheckButtonsPressed  ; loops until C-flag==1

@WhichButtonsPressed:
  LDA Buttons
  AND #%00000001
  BEQ @checkLeft
  INC ship_x
    
@checkLeft:
  LDA Buttons
  AND #%00000010
  BEQ @checkDown
  DEC ship_x

@checkDown: 
  LDA Buttons
  AND #%00000100
  BEQ @checkUp
  INC ship_y

@checkUp:
  LDA Buttons
  AND #%00001000
  BEQ @UpdateSprites
  DEC ship_y

@UpdateSprites:
    lda ship_y
    sta $200
    lda #1
    sta $201
    sta $202
    lda ship_x
    sta $203

    lda ship_y
    sta $204
    lda #2
    sta $205
    sta $206
    lda ship_x
    clc 
    adc #8
    sta $207

  RTS ; MovePlayer rts

; -----------------------------------------------------------------------------------
  ; SPRITE + PALETTE DATA

PaletteData:
    .byte $0f,$21,$0f,$0f,    $0f,$21,$0f,$0f,    $0f,$21,$0f,$0f,    $0f,$21,$0f,$0f ; Background palette data --> All black
    .byte $0f,$05,$1F,$35,    $0f,$05,$1F,$35,    $0f,$05,$1F,$35,    $0f,$05,$1F,$35 ; Sprite palette data     --> 0 Palette in NEXXT


SpriteData: ; y-pos, tile#, attributes, x-pos ($00 = top-LM tile of screen in-game) : tile# = $00-$FF (0-255 : 256 total tiles : 16 x 16 tiles)
    .byte $C0, $01, $00, $80
    .byte $C0, $02, $00, $81

; -----------------------------------------------------------------------------------