 processor       16f628a
        __config        0feeh           ; Internal Osc, WDT Enabled, not code protected
        include "p16f628a.inc"
#define RAMSTART 07h
 
        radix   dec
 
#define trig    RA,1          ; trigger input from host
#define pulse   RA,0          ; timing pulse output to host
#define echo    RA,7          ; echo signals from comparitor          ; Unused - do not connect.
#define tx2     RA,2          ; Tx phase 2
#define tx1     RA,3          ; Tx phase 1
 
#define _C      STATUS,C
 
;/////////////////////////////////////////////////////////////////////////////
 
        org     RAMSTART
 
loop            res     1       ; loop counter
dlyctr          res     1       ; delay counter
tone_cnt        res     1       ; count echo cycles
period          res     1       ; received burst cycle period from tmr0
 
;/////////////////////////////////////////////////////////////////////////////
 
        org     0               ;start address 0
 
        movwf   OSCCAL          ; use microchip's calibration value
 
        movlw   89h
        option                  ;assign 1:2 prescaler to watchdog
 
        movlw   0dh
        tris    RA            ;GPIO 1, 4 & 5 are outputs
        movwf   0
 
        bcf     pulse
 
;////////////////////////////////////////////////////////////////////////////
;
; The main loop controls the range finder. In response to a low going trigger
; input, its calls "burst" to send out 8 cycles of 40khz. It then raises the
; pulse line so the host can begin timing.
; There is a choice of two tone detect routines, the simplest is currently set.
; It then clears the output pulse so the host can complete timing, and loops
; around to wait for the next cycle.
; If an echo is not detected then the watchdog timer will reset the PIC after
; about 30mS, and the pulse line will be cleared. Therefore a very long pulse
; should be interpreted as "nothing detected"
 
main:   clrwdt
        btfss   trig            ; wait for trigger signal from user to go high
        goto    main            ; from previous measurement.
 
m2:     clrwdt
        btfsc   trig            ; wait for trigger signal from user
        goto    m2
end
 
        call    burst           ; send the ultra-sonic burst
        bsf     pulse           ; start the output timing pulse
        
; OK, here's the cheap-n-easy way to detect the echo, just wait for a transition
; on the echo line. Though not really detecting a tone, it is very effective.
; The transducers provide the selectivity.
 
m1:     btfsc   echo
        goto    m1              ; wait for low
        bcf     pulse           ; end the output timing pulse
 
; And here is the "proper" tone detecter. It detects 3 cycles of 40khz to
; give a valid output. It works but is still experimental. It is not as effective
; as just detecting the first edge, particually in the first few cm.
;
;       call tone               ; validate 3 cycles of 40khz
;       bcf     pulse           ; end the output timing pulse
;
 
        goto    main
 
;////////////////////////////////////////////////////////////////////////////
;
; The burst routine generates an acurately times 40khz burst of 8 cycles.
; Since a 4Mhz PIC (1uS instruction rate) cannot gerenate timings of less
; than 1uS, the high half cycle is 12uS and the low half cycle 13uS.
; That's good enough.
 
burst:  clrf    loop
        movlw   8               ; number of cycles in burst
        movwf   loop
 
burst1: movlw   0x10            ; 1st half cycle
        movwf   GPIO
 
        movlw   3               ; (3 * 3inst * 1uS) -1uS = 8uS 
        movwf   dlyctr          ; 8uS + (4*1uS) = 12uS
burst2: decfsz  dlyctr,f
        goto    burst2
 
        movlw   0x20
        movwf   GPIO
        movlw   2               ; (2 * 3inst * 1uS) -1uS = 5uS 
        movwf   dlyctr          ; 5uS + (8*1uS) = 13uS
burst3: decfsz  dlyctr,f
        goto    burst3
        nop
        decfsz  loop,f
        goto    burst1
 
        movlw   0x00            ; set both drives low
        movwf   GPIO
 
        retlw   0
 
;////////////////////////////////////////////////////////////////////////////
;
; The timing for this routine is critical. Our little PIC is only chugging
; along at 4Mhz, or 1uS per instruction. The longest path though this code
; is 19uS, out of the 25uS available - thats tight and why I only wait for a
; low on the echo line and not a high as well.
 
tone:   clrf    TMR0
 
t1:     btfsc   echo
        goto    t1              ; wait for low
 
        movfw   TMR0
        clrf    TMR0
        movwf   period          ; store timer0 value
 
        movlw   21              ; if(period>22 && period<30) 
        subwf   period,w
        btfss   _C
        goto    t2
        movlw   30
        subwf   period,f
        btfsc   _C
        goto    t2
 
        decfsz  tone_cnt,f      ; 25uS period OK, so 
        goto    t1              ; if not yet 3 of them, keep looking
        retlw   0               ; else - success - return
        
t2:     movlw   3               ; failed to detect 25uS period, so reset tone detect
        movwf   tone_cnt        ; to 3 and keep looking
        goto    t1

END
