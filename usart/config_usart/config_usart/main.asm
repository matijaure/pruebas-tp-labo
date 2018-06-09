;r16 tiene datos importantes que van a cambiar
;r17 tiene datos locales

.include "m328pdef.inc"
.dseg
.org SRAM_START
	; variables
.cseg
.org 0x00
	rjmp main
.org INT_VECTORS_SIZE

main:
	ldi r16, low(RAMEND)
	out spl,r16
	ldi r16, high(RAMEND)
	out sph,r16

	call USART_init
;	ldi r16, '1'
	call USART_Transmit
	call ADC_init
;	ldi r16,'2'
	call USART_Transmit

rutina:	
	call delay_1s
	call Read_ADC
	call USART_Transmit
	mov r16,r24
	call USART_Transmit
	mov r16,r25
	call USART_Transmit

	jmp rutina


ADC_init:
	ldi r16, 0
	out ddrC, r16 ; make Port C an input for ADC
	ldi r16, 0x87 ; enable ADC and select ck/128
	sts ADCSRA, r16	
	ldi r16, 0x80 ; 5V Vref, ADC0 single ended, eligo el puerto ADC0
	sts ADMUX, r16 ; input, right-justified data
	ret

Read_ADC:
	lds r17, ADCSRA
	ori r17, (1<<ADSC)
	sts ADCSRA, r17  ;star conversion
Keep_poling:		  ; wait for end of conversion	
	lds r17,ADCSRA
	sbrs r17, ADIF ; is it end of conversion yet?
	rjmp Keep_poling  ; keep polling en of conversion
	lds r17, ADCSRA
	ori r17, (1<<ADIF)
	sts ADCSRA, r17 ;write 1 to clear ADIF flag 
	lds r24, ADCL
	lds r25, ADCH
	;rjmp Read_ADC
	ret

USART_init:
	ldi r16,low(0x67)
	ldi r17, high(0x67)
	sts UBRR0L, r16
	sts UBRR0H, r17
	ldi r16, (1<<RXEN0)|(1<<TXEN0)
	sts UCSR0B,r16
; Set frame format: 8data, 1stop bit
	ldi r16, (3<<UCSZ00)
	sts UCSR0C,r16
	ret

USART_Transmit:
	lds r17, UCSR0A
	sbrs r17, UDRE0
	rjmp USART_Transmit
	sts UDR0,r16
	ret

USART_Receive:
; Wait for data to be received
	lds r17, UCSR0A
	sbrs r17, RXC0
	rjmp USART_Receive
; Get and return received data from buffer
	lds r16, UDR0
	ret



delay_1s:
	ldi r18, 50
delay2:
	ldi r19, 200
delay1:
	ldi r20, 199
delay0:
	nop
	dec r20
	brne delay0
	nop
	dec r19
	brne delay1
	dec r18
	brne delay2
	ret
