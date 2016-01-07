# LED-Display-Safe
Assignment Program the control unit for an electronic safe.

The 8-Segment display and LEDs will show status of the safe:

U: indicates safe is unlocked
L: indicates safe is locked
P: indicates safe is programming a code
C: indicates safe is confirming a new code
F: indicates safe is forgetting an old code
A: indicates a programming request was successful
'E': indicates a programming fault.
The safe starts unlocked, cannot be locked and there are no valid codes.

To lock the safe (this should work at ANY time):

press the left black button.
To unlock the safe (This should work ONLY when the safe is locked):

Enter a valid code sequence
Press the left black button.
To learn a new code (codes must be 4 buttons or more):

Press the right button once
8-segment should show 'P'
enter a new code sequence
press the right button again.
8-segment should show 'C'
enter the same code sequence
press the right button a third time.
If the code was correct 8-segment displays 'A'
if the code was incorrect 8-segment display 'E'
To forget an old code:

Press the right black button
8-segment should show 'P'
enter an old code sequence
press the right button again.
8-segment should show 'F'
enter the same code sequence
press the right button a third time
If the codes matched 8-segment displays 'A'
if the codes did not matched 8-segment displays 'E'
