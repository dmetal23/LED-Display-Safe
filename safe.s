@Daniel Rojas
@MoWe 2:00PM

.equ SWI_SETSEG8, 0x200 @display on 8 Segment
.equ SWI_SETLED, 0x201 @LEDs on/off
.equ SWI_CheckBlack, 0x202 @check Black button
.equ SWI_CheckBlue, 0x203 @check press Blue button
.equ SWI_DRAW_STRING, 0x204 @display a string on LCD
.equ SWI_DRAW_INT, 0x205 @display an int on LCD
.equ SWI_CLEAR_DISPLAY,0x206 @clear LCD
.equ SWI_DRAW_CHAR, 0x207 @display a char on LCD
.equ SWI_CLEAR_LINE, 0x208 @clear a line on LCD
.equ SWI_Exit, 0x11 @terminate program
.equ SWI_GetTicks, 0x6d @get current time

.equ LEFT_LED, 0x02 @bit patterns for LED lights
.equ RIGHT_LED, 0x01
.equ LEFT_BLACK_BUTTON,0x02 @bit patterns for black buttons
.equ RIGHT_BLACK_BUTTON,0x01 @and for blue buttons

.equ SEG_A,0x80
.equ SEG_B,0x40
.equ SEG_C,0x20
.equ SEG_D,0x08
.equ SEG_E,0x04
.equ SEG_F,0x02
.equ SEG_G,0x01
.equ SEG_P,0x10

@ Variables
.equ MA_LOCKSTATE,0x00002040		@ 0x00 unlocked, 0x01 locked
.equ MA_PINHIT,0x00002044			@ If reaches the PIN length, the safe will be unlocked

@ Arrays
.equ MA_PIN,0x00002048				@ Memory handled dynamically starting at this address. Make sure it is after the variables!

@message to LCD
mov r0,#0 @ column number
mov r1,#0 @ row number
ldr r2,=Welcome @ pointer to string
swi SWI_DRAW_STRING @ draw to the LCD screen
mov r0,#0
mov r1,#1
ldr r2,=Limit
swi SWI_DRAW_STRING
mov r0,#0
mov r1,#2
ldr r2,=Limit2
swi SWI_DRAW_STRING
mov r0,#2
mov r1,#3
ldr r2,=Min
swi SWI_DRAW_STRING

@ starts unlocked
mov r0,#0x00
bl set_unlocked

@ Reset pin hit counter
mov r0,#0x00
ldr r1,=MA_PINHIT
str r0,[r1]

@ start without pincode, set PIN length to zero.
mov r0,#0x00
ldr r1,=MA_PIN
str r0,[r1]


@ MENU ========================================================================
menu:

menu_blackbuttons:
	@ Black buttons
	swi SWI_CheckBlack
	
menu_blackbuttons_left:
	@ Left Black Button check	
	cmp r0,#LEFT_BLACK_BUTTON
	bne menu_blackbuttons_left_end
		bl get_lockstate
		cmp r1,#0x00
		bne unlocksafe
		bl pinhit_reset		@ Reset PIN HIT counter
		beq locksafe
menu_blackbuttons_left_end:

menu_blackbuttons_right:
	@ Right Black Button check
	cmp r0,#RIGHT_BLACK_BUTTON
	bne menu_blackbuttons_end
		bl pinhit_reset		@ Reset PIN HIT counter
		@ If no PIN stored, Learn, otherwise, Forget 
		bl get_pin_length
		cmp r1,#0x00
		beq learn
		bne forget
menu_blackbuttons_end:

menu_bluebuttons:
	bl get_lockstate
	cmp r1,#0x01
	beq solve

menu_end:	
	@ Infinite loop menu
	b menu
	
	
@ ROUTINES 
@ Functions jumping back to MENU.

@ SOLVE
solve:
	@ Check blue buttons
	swi SWI_CheckBlue
	mov r9,#0x00
	
solve_skipswi:
	cmp r0,#0x00
	beq solve_end
	add r9,r9,#0x01	
	mov r8,r0	@ Store the input code for later use
	
	@ Checking the PIN code on the fly
	@ Get hit counter to r2
	ldr r1,=MA_PINHIT
	ldr r2,[r1]
	@ Get PIN length to r3
	ldr r1,=MA_PIN
	ldr r3,[r1]
	
	@ Check overflow
	cmp r2,r3
	bge solve_fail
	
	@ Get PIN code from the array to r4
	mov r4, r2,LSL #2	@ multiply r2 by 4 to get the offset
	add r4,r4,#0x04		@ Seek through the length part too
	add r1,r1,r4		@ offset address
	ldr r4,[r1]			@ Load PIN code from memory
	
	@ Comparison
	cmp r8,r4
	bne solve_fail
	
	@ If matches, increment hit counter
	add r2,r2,#0x01
	ldr r1,=MA_PINHIT
	str r2,[r1]
	
	@ If there is a full PIN match, the Left black button eill unlock the safe	
	b solve_end
	
solve_fail:
	@ Reset hit counter
	bl pinhit_reset
	
	@ Do one more iteration with the same input
	cmp r9,#0x02
	bge solve_end
	mov r0, r8
	b solve_skipswi	
	
solve_end:
	b menu

@ LOCK
locksafe:
	@ check PIN length
	bl get_pin_length
	cmp r1,#0x00
	beq locksafefailed	@ no PIN code stored, safe cannot be locked
	
	@ lock safe if there is a stored PIN
	bl set_locked
	b menu
	
locksafefailed:
	bl seg8_status
	b menu
	
@ UNLOCKSAFE
unlocksafe:
	@ Get PIN length to r3
	bl get_pin_length
	mov r3,r1
	@ Get hit count to r2
	ldr r1,=MA_PINHIT
	ldr r2,[r1]
	
	@ Unlock the safe if PIN matches
	cmp r2,r3
	bne unlocksafe_end
	
	@ Unlock the safe
	bl set_unlocked

unlocksafe_end:
	@ Reset hit counter
	ldr r1,=MA_PINHIT
	mov r2,#0x00
	str r2,[r1]
	b menu

	
@ LEARN
@ Run only, if unlocked AND old code forgot
learn:
	@ If locked, do nothing
	bl get_lockstate
	cmp r1,#0x00
	bne menu
	
	@ Display 'L'
	ldr r0,=SEG_A|SEG_B|SEG_G|SEG_F|SEG_E
	swi SWI_SETSEG8
	
	@ Read PIN
	ldr r1,=MA_PIN		@ read pin to here
	bl readpin
	
	@ Minimum length check
	cmp r3,#4
	bmi learnfail	
	
	@ Display 'C'
	ldr r0,=SEG_A|SEG_G|SEG_E|SEG_D
	swi SWI_SETSEG8
	
	@ Confirm PIN
	mov r7,#0x00
	bl checkpin
	cmp r2,#0x01
	beq learnsuccess	@ correct
	
learnfail:
	@ Incorrect, delete PIN
	ldr r1,=MA_PIN
	mov r2,#0x00
	str r2,[r1]
	
	@ Display 'E'
	ldr r0,=SEG_A|SEG_D|SEG_E|SEG_F|SEG_G
	swi SWI_SETSEG8	
	b menu
	
learnsuccess:
	@ Display 'A'
	ldr r0,=SEG_A|SEG_B|SEG_C|SEG_E|SEG_F|SEG_G
	swi SWI_SETSEG8
	b menu


@ FORGET
@ Run only if unlocked AND a code stored
forget:
	@ If locked, do nothing
	bl get_lockstate
	cmp r1,#0x00
	bne menu
	
	@ Display 'P'
	ldr r0,=SEG_A|SEG_B|SEG_G|SEG_F|SEG_E
	swi SWI_SETSEG8
	
	@ Verify old code
	ldr r1,=MA_PIN
	mov r7,#0x01
	bl checkpin
	cmp r2,#0x00
	beq forgetfail		@ fail check
	
	@ Display 'F'
	ldr r0,=SEG_A|SEG_G|SEG_F|SEG_E
	swi SWI_SETSEG8
	
	@ Verify old code again
	ldr r1,=MA_PIN
	mov r7,#0x01
	bl checkpin
	cmp r2,#0x00
	beq forgetfail		@ fail check
	
	@ Delete PIN code
	ldr r1,=MA_PIN
	mov r2,#0x00
	str r2,[r1]
	
	@ Display 'A'
	ldr r0,=SEG_A|SEG_B|SEG_C|SEG_E|SEG_F|SEG_G
	swi SWI_SETSEG8
	b forgetend

forgetfail:
	@ Display 'E'
	ldr r0,=SEG_A|SEG_D|SEG_G|SEG_F|SEG_E
	swi SWI_SETSEG8
	
forgetend:
	b menu



@ SUBROUTINES 
@ These are returning functions.

@ PINHIT_RESET	
pinhit_reset:
	@ Reset hit counter
	ldr r1,=MA_PINHIT
	mov r2,#0x00
	str r2,[r1]
	mov pc,lr
	

@ GET_LOCKSTATE
@ Gets the pincode length. 
@ OUTPUT PARAMETERS
@	r1: contains the status code
get_lockstate:
	ldr r2,=MA_LOCKSTATE
	ldr r1,[r2]	
	mov pc,lr		@ return
	

@ GET_PIN_LENGTH
@ Gets the pincode length. 
@ OUTPUT PARAMETERS
@	r1: contains the PIN length
get_pin_length:
	ldr r2,=MA_PIN
	ldr r1,[r2]	
	mov pc,lr		@ return


@ SEG8_SET_STATUS
seg8_status:
	ldr r2,=MA_LOCKSTATE
	ldr r1,[r2]
	cmp r1,#0x00
	beq seg8_update_status_unlocked	
	ldr r0,=SEG_G|SEG_E|SEG_D
	b seg8_update_status_end	
seg8_update_status_unlocked:
	ldr r0,=SEG_G|SEG_E|SEG_D|SEG_C|SEG_B
seg8_update_status_end:
	swi SWI_SETSEG8	
	mov pc,lr


@ SET_UNLOCKED
set_unlocked:
	@ set state 
	mov r0,#0x00
	ldr r1,=MA_LOCKSTATE
	str r0,[r1]
	@ display
	ldr r0,=SEG_G|SEG_E|SEG_D|SEG_C|SEG_B
	swi SWI_SETSEG8
   mov r0,#RIGHT_LED
   swi SWI_SETLED
	mov pc,lr		@ return

	
@ SET_LOCKED
set_locked:
	@ set state 
	mov r0,#0x01
	ldr r1,=MA_LOCKSTATE
	str r0,[r1]
	@ display
	ldr r0,=SEG_G|SEG_E|SEG_D
	swi SWI_SETSEG8
   mov r0,#LEFT_LED
   swi SWI_SETLED
	mov pc,lr		@ return

	
@ READPIN
@ This function will read a PIN code into the memory.  
@ It will use registers as output parameters, so save registers to the stack if you are using them, before jumping into this function!
@
@ INPUT PARAMETERS:
@	r1: Memory Address for the code read. The result will be stored using the first block as the length, and the followings will contains the numbers, like this: |length|code1|code2|code3|... 
@
@ OUTPUT PARAMETERS:
@	r2: Last memory offset according to PIN length. Use it if you are reading more than one addresses to calculate the next empty address you can use.
@	r3: PIN length. Note that the first block of the used memory range contains this number too.

readpin:
	@ init
	mov r2,#0x00		@ memory address offset
	mov r3,#0x00		@ counter
	
readpinloop:
	@ Black buttons
	swi SWI_CheckBlack
	@ Right Button
	cmp r0,#RIGHT_BLACK_BUTTON
	beq readpinend
	@ Left button
	cmp r0,#LEFT_BLACK_BUTTON
	beq locksafe
	
	@ read one number
	swi SWI_CheckBlue
	cmp r0,#0x00
	beq readpinloop
	
	@ store number
	add r2, r2, #4 		@ memory offset here, because I will store the length at the first block!
	str r0,[r1,r2]		@ store r0 in the memory, using address from r1 offset by r2
	add r3, r3, #1 		@ PIN counter
	b readpinloop

readpinend:	
	@ store length at the first block of used memory range
	@ The structure looks like this: |length|code1|code2|code3|... 
	str r3,[r1]		@ store r3 in the memory 
	mov pc,lr		@ return
	
	
@@@ CHECK PIN @@@
@ It will check the stored PIN in the memory. 
@ INPUT PARAMETERS:
@   r1: PIN CODE memory address
@	r7: Left Black button can abort if 0x01, or not if 0x00
@ OUTPUT PARAMETERS:
@	r2: 0x00 mismatch, 0x01 match

checkpin:
	@ initialization	
	mov r3,#0x00		@ memory address offset
	mov r4,#0x00		@ PIN counter
	mov r5,#0x00		@ temporary variable for the stored PIN code
	mov r2,#0x01		@ result: 0-mismatch, 1-match. Start with true for simple code, then set it to false on the first code mismatch or overflow.
	ldr r6,[r1]			@ PIN length
	add r1,r1,#0x04		@ Seek to PIN code values
	
checkpinloop:
	@ black buttons
	swi SWI_CheckBlack
	@ Right Button
	cmp r0,#RIGHT_BLACK_BUTTON
	beq checkpinstop
	@ Left BUtton
	cmp r7, #0x00
	beq checkpinloop_leftbuttonend
	cmp r0,#LEFT_BLACK_BUTTON
	beq locksafe
	checkpinloop_leftbuttonend:

	@ read one number
	swi SWI_CheckBlue
	cmp r0,#0x00
	beq checkpinloop
	add r4, r4, #1 		@ PIN counter
	
	@ skip comparison after overflow and let the user fool himself, wait for black button
	cmp r4,r6
	bge checkpinloop
	
	@ skip comparison after fail
	cmp r2,#0x00
	beq checkpinloop
	
	@ read PIN part from memory
	ldr r5,[r1,r3]		@ load r5 from the memory, using address from r1 offset by r3
	add r3, r3, #4 		@ memory offset
		
	@ compare PIN numbers
	cmp r0,r5
	beq checkpinloop	@ if match, jump back
	mov r2,#0x00		@ if mismatch, set to false
	
	b checkpinloop
	
checkpinstop:
	@ Check if the user entered the same length of code
	cmp r6,r4
	beq checkpinend		@ true
	mov r2,#0x00		@ false
	
checkpinend:
	mov pc,lr		@ return
	

@ EXIT
exit:
	swi SWI_Exit
   
Welcome: .asciz "* Right Black Button - PIN SETUP"
Limit: .asciz "* Left Black Button - LOCK"
Limit2: .asciz "* No lock until PIN is setup"
Min: .asciz "* 4 buttons MINIMUM"