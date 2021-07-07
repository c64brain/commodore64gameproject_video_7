-++++++++++++*+++++++++++++++++++++++++++++++++++++++++++++++++++;===============================================================================
; PLAYER SETUP
;===============================================================================
;2w The Player Sprite here can move around the screen on top of the tiles
; and when the edge is reached, the screen scrolls in that direction.
;===============================================================================

#region "Player Setup"
PlayerInit

        ;------------------------------------------------------------------------------
        ; PLAYER has a strange setup as it's ALWAYS going to be using sprites 0 and 1
        ; As well as always being 'active' (used)
        ;------------------------------------------------------------------------------

        lda #COLOR_BLACK
        sta VIC_BACKGROUND_COLOR

        lda #%00000011                          ; Turn on multicolor for sprites 0 and 1
        sta VIC_SPRITE_MULTICOLOR               ; also turn all others to single color

        lda #COLOR_BLACK
        sta VIC_SPRITE_MULTICOLOR_1             ; Set sprite shared multicolor 1 to brown
        lda #COLOR_LTRED
        sta VIC_SPRITE_MULTICOLOR_2             ; set sprite shared multicolor 2 to 'pink'

        lda #COLOR_YELLOW
        sta VIC_SPRITE_COLOR                    ; set sprite 0 color to yellow
        lda #COLOR_BLUE
        sta VIC_SPRITE_COLOR + 1                ; set sprite 1 color to orange (bkground sprite)

        ;------------------------------------------------------------------------------
        ; We now use a system that tracks the sprite position in character coords on
        ; the screen, so to avoid costly calculations every frame, we set the sprite
        ; to a character border intially and track all movement from there. That way
        ; we need only do this set of calculations once in the lifetime of the Player.
        ;
        ; To initally place the sprite, we use 'SpriteToCharPos'
        ;------------------------------------------------------------------------------
; Sprite X position
        lda #19
        sta PARAM1

; Sprite Y0 Head
        ldx #0
        lda #9
        sta PARAM2
        jsr SpriteToCharPos

; Sprite Y1 Legs
        lda #19
        sta PARAM1

        ldx #1
        lda #11
        sta PARAM2
        jsr SpriteToCharPos

        ;---------------------------------------------------------------------------
        ; Set sprite images.  The sprites from the MLP Spelunker demo used 2 sprites
        ; overlapped so they could use an extra color.  So our main player sprite
        ; uses 2 sprites (0 and 1).  The first walking frame image 1, and it's
        ; background sprite is image 8.  We use the SetSpriteImage subroutine as it
        ; will update the pointers for both Screen1 and Screen2 for us.
        ;---------------------------------------------------------------------------

        lda #PLAYER_STATE_IDLE          ; Set initial state (idle)
        jsr ChangePlayerState

        lda #1
        sta SPRITE_IS_ACTIVE            ; Set sprite 0 to active
        sta SPRITE_IS_ACTIVE + 1        ; Set sprite 1 to active
        rts

#endregion

;===================================================================================================
;                                                                                  UPDATE PLAYER 
;---------------------------------------------------------------------------------------------------
; Update the player. Joystick controls are updated via interrupt so we read the values from JOY_X
; and JOY_Y
;---------------------------------------------------------------------------------------------------

#region "Update Player"

PLAYER_RIGHT_CAP = $1c                      ; Sprite movement caps - at this point we don't
PLAYER_LEFT_CAP = $09                       ; Move the sprite, we scroll the screen
PLAYER_UP_CAP = $04                          
PLAYER_DOWN_CAP = 13

UpdatePlayer                                ; Only update the player if it's active
        lda SPRITE_IS_ACTIVE                ; check against sprite #0 - is it active?
        bne @update 
        rts
@update    
        ldx #0
        jsr AnimateSprite
        jsr UpdatePlayerState               ;jump (PLAYER_STATE_JUMPTABLE)
        rts

#endregion

;===============================================================================
; JOYSTICK TESTING
; MOVING: Direction the character is moving in
; SCROLL: Check if the screen has stopped scrolling

; JoystickReady = 0 - the screen has stopped scrolling
; JoystickReady = 1 - the screen is now scrolling
;===============================================================================

#region "JoystickReady"
JoystickReady
        lda SCROLL_MOVING               ; if moving is 'stopped' we can test joystick
        beq @joyready
 
; Screen is still scrolling           ; if it's moving but direction is stopped, we're 'fixing'
        lda SCROLL_DIRECTION          ; > 0 then stop the character direction movement
        bne @joyready


; The screen has stopped scrolling
        lda #1                          ; Send code for joystick NOT ready for input
        rts                             

; The screen is now scrolling
@joyready
        lda #SCROLL_STOP                ; reset scroll direction - if it needs to scroll
        sta SCROLL_DIRECTION            ; it will be updated

        lda #0                          ; send code for joystick ready
        rts

#endregion

;===============================================================================
; PLAYER WALKS TO THE RIGHT
;===============================================================================

#region "MovePlayerRight"
MovePlayerRight
        lda #0
        sta SCROLL_FIX_SKIP
        ;------------------------------------------ CHECK RIGHT MOVEMENT CAP
        clc                             ; clear carry flag because I'm paranoid
        lda SPRITE_CHAR_POS_X           ; load the sprite char X position
        cmp #PLAYER_RIGHT_CAP           ; check against the right edge of the screen
        bcc @rightMove                  ; if X char pos < cap - move the sprite, else scroll

                                        ; Check against map edge
        lda MAP_X_POS                   ; load the current MAP X Position          
        cmp #100                         ; the map is 64 tiles wide, the screen is 10 tiles wide
        bne @scrollRight
        lda MAP_X_DELTA                 ; each tile is 4 characters wide (0-3)
        cmp #0                          ; if we hit this limit we don't scroll (or move)
        bne @scrollRight
                                        ;at this point we will revert to move 
        lda #1
        sta SCROLL_FIX_SKIP
        jmp @rightMove
        rts
        ;------------------------------------------ SCROLL RIGHT
                                        ; Pre-scroll check
@scrollRight
        ldx #0
        jsr CheckMoveRight              ; Collision check against characters
        beq @scroll                     ; TODO - return the collision code here
        rts
                                        ; Setup for the scroll
@scroll
        lda #SCROLL_RIGHT               ; Set the direction for scroll and post scroll checks
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; load 'clear code'
        rts                             ; TODO - ensure collision code is returned

        ;----------------------------------------- MOVE SPRITE RIGHT                                
@rightMove
        ldx #0
        jsr CheckMoveRight              ; Check ahead for character collision
        bne @rightDone

@moveRight
        ldx #0
        jsr MoveSpriteRight             ; Move sprites one pixel right
        ldx #1
        jsr MoveSpriteRight

        lda #0                          ; move code 'clear'
@rightDone
        rts

#endregion

;===============================================================================
; PLAYER WALKS TO THE LEFT
;===============================================================================

#region "Move Player Left"
MovePlayerLeft
        lda #0                          ; Make sure scroll 'fix' is on
        sta SCROLL_FIX_SKIP
        ;---------------------------------------- CHECK MOVEMENT CAP ($07)
        lda SPRITE_CHAR_POS_X           ; Check for left side movement cap
        cmp #PLAYER_LEFT_CAP
        bcs @leftMove                   ; if below cap, we move the sprite
                                        ; Otherwise we prepare to scroll

                                        ; Check for edge of map for scrolling
        lda MAP_X_POS                   ; Check for map pos X = 0
        bne @scrollLeft                 
        lda MAP_X_DELTA                 ; check for map delta = 0
        bne @scrollLeft
                                        ; We're at the maps left edge
                                        ; So we revert to sprite movement once more
        lda #1
        sta SCROLL_FIX_SKIP
        lda SPRITE_POS_X,x              ; Check for sprite pos > 0 (not sprite char pos)
        bpl @leftMove                   ; so we could walk to the edge of screen
        rts

@scrollLeft
        ;--------------------------------------- SCROLL SCREEN FOR LEFT MOVE
        ldx #0
        jsr CheckMoveLeft               ; check for character collision to the left
        beq @scroll
        rts                             ; TODO - return collision code

@scroll
        lda #SCROLL_LEFT
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; return 'clear code'
        rts
        ;---------------------------------------- MOVE THE PLAYER LEFT ONE PIXEL
@leftMove
        ldx #0
        jsr CheckMoveLeft               ; check for collisions with characters
        bne @leftDone                   ; TODO return collision code
   
@moveLeft 
        ldx #0
        jsr MoveSpriteLeft
        ldx #1
        jsr MoveSpriteLeft

        lda #0                          ; move code 'clear'
@leftDone
        rts

#endregion

;===============================================================================
; PLAYER MOVES DOWN THE SCREEN
;===============================================================================

#region "Move Player Down"
MovePlayerDown
        clc
        lda SPRITE_CHAR_POS_Y
        cmp #PLAYER_DOWN_CAP
        bcc @downMove

        lda MAP_Y_POS
        cmp #49
        bne @downScroll
        lda MAP_Y_DELTA
        cmp #02
        bcc @downScroll
        rts

@downScroll
        ldx #1                          ; Check Sprite #0
        jsr CheckMoveDown               ; returns: 0 = can move : 1 = blocked
        beq @scroll                     ; We are not blocked = 0
        rts                             ; return with contents of collison routine

@scroll
        lda #SCROLL_DOWN
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; return a clear collision code
        rts

@downMove
        ldx #0                          ; Check Sprite #0
        jsr CheckMoveDown               ; returns: 0 = can move : 1 = blocked
        bne @downDone                   ; retun with contents of collision code
        ldx #0
        jsr MoveSpriteDown              ; = 0 so we can move the Sprite Down
        ldx #1
        jsr MoveSpriteDown
        lda #0                          ; return with clear code
@downDone
        rts

#endregion

;===============================================================================
; PLAYER MOVES UP THE SCREEN
;===============================================================================

#region "MovePlayerUp"
MovePlayerUp
        sec
        lda SPRITE_CHAR_POS_Y
        cmp #PLAYER_UP_CAP
        bcs @upMove

        lda MAP_Y_POS
        bne @upScroll
        clc
        lda MAP_Y_DELTA
        cmp #1
        bcs @upScroll
        rts

@upScroll
        ldx #0
        jsr CheckMoveUp
        beq @scroll
        rts

@scroll
        lda #SCROLL_UP
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        rts

@upMove
        ldx #0                                  ; Check Sprite 0 (head/body)
        jsr CheckMoveUp
        bne @upDone
                
        jsr MoveSpriteUp
        ldx #1
        jsr MoveSpriteUp
@upDone
        rts

#endregion

;===================================================================================================
;                                                                                  PLAYER STATES
;===================================================================================================
; Player states are incremented by 2 as they are indexes to look up the address of the state
; code on the PLAYER_STATE_JUMPTABLE.  An address is 2 bytes (1 word) egro the index must increase
; by 2 bytes.
;---------------------------------------------------------------------------------------------------
PLAYER_STATE_IDLE               = 0     ; standing still - awaiting input
PLAYER_STATE_WALK_RIGHT         = 2     ; Walking right
PLAYER_STATE_WALK_LEFT          = 4     ; Walking left
PLAYER_STATE_PUNCH_RIGHT        = 6    ; punch right
PLAYER_STATE_PUNCH_LEFT         = 8    ; punch left
PLAYER_STATE_KICK_RIGHT         = 10    ; kick right
PLAYER_STATE_KICK_LEFT          = 12    ; kick left
PLAYER_STATE_POLE               = 14    ; Climbing pole
PLAYER_STATE_FLOATING           = 16    ; floating

PLAYER_SUBSTATE_ENTER   = 0     ; we have just entered this state
PLAYER_SUBSTATE_RUNNING = 1     ; This state is running normally

;---------------------------------------------------------------------------------------------------
;                                                                       PLAYER STATE JUMPTABLE
;---------------------------------------------------------------------------------------------------
PLAYER_STATE_JUMPTABLE
        word PlayerStateIdle
        word PlayerStateWalkRight
        word PlayerStateWalkLeft
        word PlayerStatePunchRight
        word PlayerStatePunchLeft
        word PlayerStateKickRight
        word PlayerStateKickLeft
        word PlayerStatePole
        word PlayerStateFloating
;---------------------------------------------------------------------------------------------------
;===================================================================================================
;                                                                            CHANGE PLAYER STATE
;---------------------------------------------------------------------------------------------------
; Change a players state
;
; A = state to change to
;
; Modifies A,X,ZEROPAGE_POINTER_1

;C64 Brain Notes: Player states recorded (animation, idle, running, etc.). Data is saved to PLAYER_SUBSTATE
;---------------------------------------------------------------------------------------------------
#region "PlayerChangeState"
ChangePlayerState
        tax                                             ; transfer A to X
        stx PLAYER_STATE                                ; store the new player state                            
        lda #PLAYER_SUBSTATE_ENTER                      ; Set substate to ENTER
        sta PLAYER_SUBSTATE

        lda #1
        sta SPRITE_ANIM_PLAY

        lda PLAYER_STATE_JUMPTABLE,x                    ; lookup state to change to
        sta ZEROPAGE_POINTER_1                          ; and store it in ZEROPAGE_POINTER_1

        lda PLAYER_STATE_JUMPTABLE + 1,x
        sta ZEROPAGE_POINTER_1 + 1

        jmp (ZEROPAGE_POINTER_1)                        ; jump to state (to setup)
                                                        ; NOTE: This is NOT a jsr.
                                                        ; The state will act as an extension of
                                                        ; this routine then return.
        rts
#endregion
;===================================================================================================
;                                                                            UPDATE PLAYER STATE
;---------------------------------------------------------------------------------------------------
; Update the player based on their state
;---------------------------------------------------------------------------------------------------
#region "UpdatePlayerState"
UpdatePlayerState
        ldx PLAYER_STATE                        ; Load player state
        lda PLAYER_STATE_JUMPTABLE,x            ; fetch the state address from the jump table
        sta ZEROPAGE_POINTER_1                  ; store it in ZEROPAGE_POINTER_1
        lda PLAYER_STATE_JUMPTABLE +1,x
        sta ZEROPAGE_POINTER_1 + 1
        jmp (ZEROPAGE_POINTER_1)                ; jump to the right state (note - NOT a jsr)
        rts
#endregion

;===================================================================================================
;                                                                                  APPLY GRAVITY
;===================================================================================================
; Apply Gravity to the player - this system will be totally rewritten at some point to apply
; a proper gravity to a player or any other sprite.. but for now it's just super basic
;
; A returns 0 if we moved down and a collision code if we didn't
;---------------------------------------------------------------------------------------------------

#region "Apply Gravity"

ApplyGravity
;===============================================================================
; CHECK IF SPRITE IS AT THE BOTTOM OF THE SCREEN
;===============================================================================
        lda SPRITE_CHAR_POS_Y
        cmp #PLAYER_DOWN_CAP + 1
        bcc @spriteFalling

;===============================================================================
; CHECK THE MAP/DELTAS - USED TO MANAGE PROPER SCROLLING
;===============================================================================
        lda MAP_Y_POS                   ; How far have we scrolled?
        cmp #$1B
        bne @scroll

        lda MAP_Y_DELTA
        cmp #3
        bcc @scroll
        rts                           ; retun with contents of collison routine

;===============================================================================
; BEGIN SCROLLING THE SCREEN DOWN ONE PIXEL - ON EACH EXECUTION
;===============================================================================
@scroll
        lda #SCROLL_DOWN
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING

;===============================================================================
; CHECK LEFT/RIGHT MOVEMENT WHEN FALLING
;===============================================================================
        lda JOY_X
        bmi @leftFallMove
        bne @rightFallMove
        rts

;===============================================================================
; PLAYER CAN MOVE RIGHT WHILE FREEFALLING
;===============================================================================
@rightFallMove
        ldx #0
        jsr MovePlayerRight             ; = 0 so we can move the Sprite Right
        ldx #1
        jsr MovePlayerRight
        rts

;===============================================================================
; PLAYER CAN MOVE LEFT WHILE FREEFALLING
;===============================================================================
@leftFallMove
        ldx #0
        jsr MovePlayerLeft              ; = 0 so we can move the Sprite Left
        ldx #1
        jsr MovePlayerLeft
        rts

;===============================================================================
; OTHERWISE SPRITE JUST FALLS DOWN THE SCREEN
;===============================================================================
@spriteFalling
        ldx #0
        jsr MoveSpriteDown              ; = 0 so we can move the Sprite Down
        ldx #1
        jsr MoveSpriteDown
        rts

#endregion

;===============================================================================
; PLAYER STATE IDLE
;===============================================================================
#region "Player State Idle"
PlayerStateIdle
;===============================================================================
; SET IDLE SPRITE
;===============================================================================
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

        ldx #0                                  ; load sprite number (0) in X
        lda #<ANIM_PLAYER_IDLE                  ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  ; byte %00000111
        lda #>ANIM_PLAYER_IDLE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts 
 
;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady                       ; lda SCROLL_MOVING, lda SCROLL_DIRECTION
        beq @input                              ; The screen has stopped scrolling
        rts                                     ; The screen is now scrolling (reads UpdateScroll)
                                                               
;===============================================================================
; CHECK IF SPRITE HAS LANDED ON THE FLOOR
;=============================================================================== 
; Note: ldx #0 - checks the sprite Head area (Sprite 0)
;       ldx #1 = checks the sprite Legs area (Sprite 1)

;===============================================================================
; SPRITE IS CLIMBING A POLE OR SITTING IDLE ON IT
;===============================================================================

; Screen has stopped scrolling
@input
        ldx #1                            
        jsr CheckBlockUnder 
        lda COLLIDER_ATTR
        cmp #COLL_POLE                          ; Check for pole under player 
        beq @goPoleClimb

;===============================================================================
; CHECK IF SPRITE IS PUNCHING RIGHT
;===============================================================================
@checkdiagonals
        lda checkupright
        bit JOY_2                               ; punch right
        beq @pressUpRight

;===============================================================================
; CHECK IF SPRITE IS PUNCHING LEFT
;===============================================================================
        lda checkupleft                          ; Mask for bit 0
        bit JOY_2                               ; check zero = jumping (button pressed)
        beq @pressUpLeft                        ; punch left   

;===============================================================================
; SPRITE HAS NOT YET LANDED ON THE FLOOR
;===============================================================================
        ldx #1                            
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                         ; Does floor exist under us?
        bne @stillFalling                       ; No, player keeps falling

;===============================================================================
; CHECK IF SPRITE IS A LITTLE BELOW THE FLOOR
;===============================================================================
        lda SPRITE_CHAR_POS_Y
        cmp #14              ; = 13: - 1 = 12
        bcc @moveSpriteUp
        jmp @horizCheck

;===============================================================================
; SPRITE LANDED ON A FLOOR, SO MOVE SPRITE UP (FIXES BELOW FLOOR BUG)
;===============================================================================
@moveSpriteUp
        ldx #0
        jsr MovePlayerUp
        ldx #1
        jsr MovePlayerUp
;===============================================================================
; @horizCheck: SKIPS OVER GRAVITY CHECK SINCE SPRITE IS ON THE FLOOR
;===============================================================================
        jmp @horizCheck                       ; Player has landed on tile (can't fall)

;===============================================================================
; SPRITE HAS NOT LANDED ON A FLOOR, SO STILL FALLING
;=============================================================================== 
@stillFalling
        jsr ApplyGravity

;===============================================================================
; CHECK THE VERTICAL MOVEMENT
;===============================================================================
; Is Sprite moving to the Left?
;*******************************************************************************
@horizCheck
        lda JOY_X                               ; horizontal movement
        beq @vertCheck                          ; check zero - ho horizontal input
        bmi @left                               ; negative = left
        
;===============================================================================
; SPRITE HAS MOVED TO THE RIGHT
;===============================================================================
@right
        lda #PLAYER_STATE_WALK_RIGHT            ; go to walk state right
        jmp ChangePlayerState

;===============================================================================
; SPRITE HAS MOVED TO THE LEFT
;=============================================================================== 
@left
        lda #PLAYER_STATE_WALK_LEFT             ; go to walk state left
        jmp ChangePlayerState

;===============================================================================
; SUBROUTINE FOR: SPRITE FLOATING (IN WATER)
;===============================================================================
@goFloating
        lda #PLAYER_STATE_FLOATING
        jmp ChangePlayerState

;===============================================================================
; CHECK FOR SPRITE FLOATING IN THE WATER
;===============================================================================
@vertCheck
        ldx #1                          ; if we are on a pole, can we move down?
        jsr CheckBlockUnder             ; first check we are on a pole
        lda COLLIDER_ATTR
        cmp #COLL_WATER
        beq @goFloating 

;===============================================================================
; CHECK IF JOYSTICK IS MOVING UP OR DOWN
;===============================================================================
        lda JOY_Y                               ; check vertical joystick input
        beq @end                                ; zero means no input
        rts

;===============================================================================
; SUBROUTINE FOR: SPRITE CLIMBING A POLE
;===============================================================================
@goPoleClimb
        lda #PLAYER_STATE_POLE
        jmp ChangePlayerState

;===============================================================================
; SUBROUTINE FOR: SPRITE PUNCHING RIGHT
;===============================================================================
@pressUpRight
        lda #PLAYER_STATE_PUNCH_RIGHT            ; go to jump state
        jmp ChangePlayerState

;===============================================================================
; SUBROUTINE FOR: SPRITE PUNCHING LEFT
;===============================================================================
@pressUpLeft
        lda #PLAYER_STATE_PUNCH_LEFT            ; go to jump state
        jmp ChangePlayerState

@end
        rts

IDLE_VAR
        byte $00
#endregion

;===============================================================================
; PLAYER STATE WALK RIGHT
;===============================================================================

#region "Player State Walking Right"
PlayerStateWalkRight  
        lda PLAYER_SUBSTATE
        bne @running
        ;------------------------------------------------------- SETUP CODE GOES HERE
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_WALK_R                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_WALK_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                 

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @input                      ; The screen has stopped scrolling
        rts                             ; The screen is now scrolling

;===============================================================================
; CHECK IF SPRITE HAS LANDED ON THE FLOOR
;=============================================================================== 

; Screen has stopped scrolling

@input
        ldx #1                            
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                         ; Does floor exist under us?
        beq @joyCheck                       ; No, player keeps falling

;===============================================================================
; NO FLOOR EXISTS YET. SPRITE KEEPS FALLING
;===============================================================================
        jsr ApplyGravity                ; Apply Gravity - if we are not falling

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@joyCheck
        lda JOY_X
        bmi @idle                       ; if negative we are idling
        beq @idle

;===============================================================================
; SPRITE IS MOVING TO THE RIGHT
;===============================================================================
@right   
        ldx #0
        jsr MovePlayerRight             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerRight             ; Use twice for double speed
      
        rts
@idle
        lda #PLAYER_STATE_IDLE              
        jmp ChangePlayerState

#endregion

;===============================================================================
; PLAYER STATE WALK LEFT
;===============================================================================

#region "Player State Walking Left"
PlayerStateWalkLeft
        lda PLAYER_SUBSTATE
        bne @running
        ;------------------------------------------------------- SETUP CODE GOES HERE
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_WALK_L                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_WALK_L
        sta ZEROPAGE_POINTER_1 + 1

;===============================================================================
; IDLE ANIMATION: SPRITE RUNNING IN POSITION
;===============================================================================
        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts 

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @input                      ; Screen has stopped scrolling
        rts                             ; Screen is now scrolling (reads UpdateScroll)

;===============================================================================
; CHECK IF SPRITE HAS LANDED ON THE FLOOR
;=============================================================================== 

; Screen has stopped scrolling

@input
        ldx #1                            
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                         ; Does floor exist under us?
        beq @joyCheck                       ; No, player keeps falling

;===============================================================================
; NO FLOOR EXISTS YET. SPRITE KEEPS FALLING
;===============================================================================
        jsr ApplyGravity                ; Apply Gravity - if we are not falling

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@joyCheck
        lda JOY_X
        beq @idle

;===============================================================================
; SPRITE IS MOVING TO THE LEFT
;===============================================================================
        ldx #0
        jsr MovePlayerLeft              ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerLeft              ; Use twice for double speed
        rts
@idle
        lda #PLAYER_STATE_IDLE              
        jmp ChangePlayerState

#endregion

;===================================================================================================
; STATE PUNCH RIGHT
;---------------------------------------------------------------------------------------------------

; IMPORTANT: Checks when the Player can Move LEFT or RIGHT. No other state or subroutine does this.

; The player is standing still and waiting input.
; Possible optimizations we are doublechecking CheckBlockUnder and CheckDown, we can check once
; and store those in a temp variable and look them up if needed.
;---------------------------------------------------------------------------------------------------

#region "Player State Idle"
PlayerStatePunchRight
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; BEGIN PUNNCHING RIGHT ANIMATION
;===============================================================================
        ldx #0
        lda #<ANIM_PLAYER_PUNCH_R                  ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_PUNCH_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start

@running
        ;------------------------------------------------------------ JOYSTICK INPUT

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
        jsr JoystickReady
        beq @input
        rts    

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input                                 ; not ready for input, we return
        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bpl @idle                       ; if negative we are idling
@idle
        lda #0
        sta SPRITE_ANIM_PLAY            ; pause our animation
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

#endregion

;===============================================================================
; STATE PUNCH RIGHT
;===============================================================================

#region "Player State Idle"
PlayerStatePunchLeft
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; BEGIN PUNNCHING LEFT ANIMATION
;===============================================================================
        ldx #0
        lda #<ANIM_PLAYER_PUNCH_L                  ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_PUNCH_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start

@running
        ;---------------------------------------------------------- JOYSTICK INPUT

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
        jsr JoystickReady
        beq @input                              ; not ready for input
        rts

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input
        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling

@idle
        lda #0
        sta SPRITE_ANIM_PLAY                    ; begin our animation when set to one

        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
#endregion

;===============================================================================
;  STATE KICK RIGHT
;===============================================================================
#region "PlayerStateStairsR"
PlayerStateKickRight
        lda PLAYER_SUBSTATE                     ; test for first run
        bne @running
        ;------------------------------------------------------- SETUP CODE GOES HERE

;===============================================================================
; BEGIN KICKING RIGHT ANIMATION
;===============================================================================
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_KICK_R                         ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_KICK_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; state change goes into effect next frame

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        ;---------------------------------------------------------- JOYSTICK INPUT
        jsr JoystickReady
        beq @idle                              ; not ready for input
        rts

@idle
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
        ;--------------------------------------------------------------------------
#endregion

;===================================================================================================
;  STATE KICK LEFT
;---------------------------------------------------------------------------------------------------
;  Player state for climbing stairs
;---------------------------------------------------------------------------------------------------
#region "PlayerStateStairsR"
PlayerStateKickLeft
        lda PLAYER_SUBSTATE                     ; test for first run
        bne @running
        ;------------------------------------------------------- SETUP CODE GOES HERE
                                ; TODO - some check to change to walking right animation
                                ;        if it's currently different

;===============================================================================
; BEGIN KICKING LEFT ANIMATION
;===============================================================================
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_KICK_L                         ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_KICK_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; state change goes into effect next frame

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        ;---------------------------------------------------------- JOYSTICK INPUT
        jsr JoystickReady
        beq @idle                              ; not ready for input
        rts

@idle
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
;  PLAYER STATE POLE
;===============================================================================
#region "PlayerStatePole"
PlayerStatePole
        lda PLAYER_SUBSTATE                     ; test for first run
        bne @running

;===============================================================================
; SET CLIMBING SPRITE
;===============================================================================
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_CLIMB_POLE                   ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_CLIMB_POLE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; change takes effect next frame

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @input                              ; not ready for input
        rts

;===============================================================================
; CHECK IF SPRITE IS ON THE POLE
;=============================================================================== 
@input
        lda #1
        sta SPRITE_ANIM_PLAY            ; pause our animation

        ldx #1
        jsr CheckBlockUnder                     ; Check tile under Top sprite (Sprite)
        lda COLLIDER_ATTR
        cmp #COLL_POLE                          ; Does pole exist here?
        bne @exitPoleClimb                          ; No pole found, exit routine

;===============================================================================
; SPRITE IS ON THE POLE
;===============================================================================
; Is Sprite moving to the Left or Right?
;*******************************************************************************
        lda JOY_X
        beq @vertCheck
        bmi @left
        bpl @right  
        rts

;===============================================================================
; CALL SPRITE WALKING LEFT SUBROUTINE
;===============================================================================
@left
        ldx #1
        jsr CheckMoveLeft
        beq @goLeft                             ; Not blocked, left routine
        rts

;===============================================================================
; POLE WAS FOUND: MOVE SPRITE UP
;=============================================================================== 
@exitPoleClimb 
        ldx #0
        jsr MovePlayerUp
        ldx #1
        jsr MovePlayerUp

;===============================================================================
; SPRITE HAS FALLEN OFF THE POLE
;===============================================================================
@noPoleFound
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
; CHECK IF SPRITE CAN MOVE TO THE RIGHT
;===============================================================================
@right
        ldx #1
        jsr CheckMoveRight
        beq @goRight                            ; Not blocked, right routine
        rts

;===============================================================================
; CALL SPRITE WALKING RIGHT SUBROUTINE
;===============================================================================
@goRight
        lda #PLAYER_STATE_WALK_RIGHT
        jmp ChangePlayerState

;===============================================================================
; CALL SPRITE WALKING LEFT SUBROUTINE
;===============================================================================
@goLeft
        lda #PLAYER_STATE_WALK_LEFT
        jmp ChangePlayerState

;===============================================================================
; IF DELTA=4 PLAYER HAS PASSED THROUGH A TILE
;=============================================================================== 
@vertCheck  
        ldx #1
        lda SPRITE_POS_X_DELTA,x
        cmp #4                                  ; they pass through if delta is 4
        beq @checkJoystick                      ; We have passed completely through the tile
        bcc @deltaFinished                      ; if less than 4, shift right one pixel

        jsr MovePlayerLeft                      ; not equal, not less, must be more - shift left one
        jmp @checkJoystick

;===============================================================================
; SPRITE IS MOVING TO THE RIGHT
;===============================================================================
@deltaFinished
        ldx #0
        jsr MovePlayerRight
        ldx #1
        jsr MovePlayerRight

;===============================================================================
; CHECK IF JOYSTICK IS IDLE OR MOVing UP OR DOWN
;===============================================================================
@checkJoystick                              ; No tile was found underneath sprite, he falls
        lda JOY_Y
        beq @end
        bmi @up
        bpl @down
        rts

;===============================================================================
; SPRITE IS MOVING UP
;===============================================================================
@up
        ldx #0
        jsr MovePlayerUp
        ldx #1
        jsr MovePlayerUp
        rts

;===============================================================================
; SPRITE IS MOVING DOWN
;===============================================================================
@down
        ldx #0
        jsr MovePlayerDown              ; Otherwise, move the Sprite Down
        ldx #1
        jsr MovePlayerDown
;        bne @endClimb
        rts

;===============================================================================
; IF DELTA=4 PLAYER HAS PASSED THROUGH A TILE
;===============================================================================
@endClimb
        lda SPRITE_POS_X_DELTA          ; Check if Sprite is passing 
        cmp #4                          ; completely through the tile
        beq @end                        ; Yes, they passed through
        rts    

@end
        lda #0
        sta SPRITE_ANIM_PLAY            ; pause our animation
        rts

;===================================================================================================
;                                                                                 STATE FLOATING
;---------------------------------------------------------------------------------------------------
#region "Player State Walking Right"
PlayerStateFloating
        lda PLAYER_SUBSTATE
        bne @running

        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start
        ;-----------------------------------------------------------------------------
@running
        jsr JoystickReady
        beq @input                      ; Check creates the 'fix' pause for scroll resetting
        rts

;===============================================================================
; IN WATER: LEFT/RIGHT MOVEMENT
;===============================================================================
@input
        lda JOY_X
        bmi @leftWaterMove
        bne @rightWaterMove

;===============================================================================
; IN WATER: UP/DOWN MOVEMENT
;===============================================================================
        lda JOY_Y
        beq @checkWaterCollis
        bmi @checkWaterUp               ; joystick going up
        bpl @down                       ; joystick going down
        rts

@rightWaterMove
        ldx #0
        jsr MovePlayerRight
;        ldx #1
;        jsr MovePlayerRight
        rts

@leftWaterMove
        ldx #0
        jsr MovePlayerLeft
;        ldx #1
;        jsr MovePlayerLeft
        rts

@right
        lda #PLAYER_STATE_WALK_RIGHT            ; go to walk state right
        jmp ChangePlayerState

        ;--------------------------------------------- JOYSTICK LEFT
@left
        lda #PLAYER_STATE_WALK_LEFT             ; go to walk state right
        jmp ChangePlayerState

;===============================================================================
; IN WATER: CAN ONLY MOVE UP WHEN IN WATER
;===============================================================================
@up
        ldx #0
        jsr CheckMoveUp                     ; Check tile under Top sprite (Sprite)
        lda COLLIDER_ATTR
        cmp #COLL_POLE                          ; Does pole exist here?
        beq @goingUp  
        jmp @end

;===============================================================================
; IN WATER: CAN ONLY MOVE DOWN WHEN IN WATER
;===============================================================================
@checkWaterUp
        ldx #0
        jsr CheckMoveUp                     ; Check tile under Top sprite (Sprite)
        lda COLLIDER_ATTR
        cmp #COLL_POLE                          ; Does pole exist here?
        beq @goingUp  

        ldx #0
        jsr CheckMoveUp                     ; Check tile under Top sprite (Sprite)
        lda COLLIDER_ATTR
        cmp #COLL_WATER                          ; Does pole exist here?
        beq @goingUp                          ; No pole found, exit routine
        rts

@goingUp
        ldx #0
        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
        rts

;===============================================================================
; IN WATER: CAN ONLY MOVE DOWN WHEN IN WATER
;===============================================================================
@down
        ldx #1
        jsr CheckBlockUnder                     ; Check tile under Top sprite (Sprite)
        lda COLLIDER_ATTR
        cmp #COLL_WATER                          ; Does pole exist here?
        beq @goingDown 
        jmp @end

@goingDown
        ldx #0
        jsr MovePlayerDown             ; Move player one pixel across - A = move? 0 or 1
;        ldx #1
;        jsr MovePlayerDown
        rts

;===============================================================================
; IN WATER: SPRITE RISES TO SURFACE
;===============================================================================
@checkWaterCollis
        ldx #0
        jsr CheckBlockUnder                     ; Check tile under Top sprite (Sprite)
        lda COLLIDER_ATTR
        cmp #COLL_WATER                          ; Does pole exist here?
        bne @end 

        ldx #0
        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
;        ldx #1
;        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
        rts

@end
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

#endregion

#endregion


checkupright
        byte %0001001

checkupleft
        byte %0000101

PLAYER_STATE                            ; Current state - walking, standing, dying, climbing
        byte 0
PLAYER_SUBSTATE
        byte 0 
