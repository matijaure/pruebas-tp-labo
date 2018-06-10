/*
 * config_modulos.asm
 *
 * Configuracion del ADC, USART y SPI
 */ 
;r16 tiene datos importantes que van a cambiar
;r17 tiene datos locales

.include "m328pdef.inc"

.equ MOSI = 5
.equ SCK = 7
.equ SS = 4
.dseg
.org SRAM_START
	; variables
.cseg
.org 0x00
	rjmp main
.org INT0addr ; direccion de la interrupcion externa INT0
	jmp EX_INT0_ISR ; direccion de la rutina de servicio de INT0
.org INT_VECTORS_SIZE

main:
	ldi r16, low(RAMEND)
	out spl,r16
	ldi r16, high(RAMEND)
	out sph,r16
	; Agrego habilitacion de INT0
	ldi r20, 1<<ISC01 ; activar INT0 por flanco descendente
	sts EICRA, r20
	sbi PORTD,2 ; activar Rpull_up para el pulsador
	ldi r20, 1<<INT0 ; habilitar INT0
	out EIMSK, r20
	sei ; habilitar interrupciones globales
	; despues de la interrupcion, vuelve acá
;aca:
	;rjmp aca ; para probar la interrupción

	call USART_init
;	ldi r16, '1'
	call USART_Transmit
	call ADC_init
	call SPI_init
;	ldi r16,'2'
	call USART_Transmit

rutina:	
	call delay_1s ; revisar frecuencia utilizada en el delay
	call Read_ADC
	call USART_Transmit
	mov r16,r24
	;call USART_Transmit ; transmitiendo por puerto serie ADCL
	; agrego prueba spi
	call SPI_Transmit ; transmitiendo por SPI ADCL

	mov r16,r25
	;call USART_Transmit ; transmitiendo por puerto serie ADCH
	call SPI_Transmit ; transmitiendo por SPI ADCH
	jmp rutina


; rutinas de configuracion

ADC_init:
	ldi r16, 0
	out ddrC, r16 ; pone el puerto C (ADC) como entrada
	ldi r16, 0x87
	sts ADCSRA, r16	; habilita el ADC y elige prescaler de 128 (maxima precision) (f_clk = f_osc/128)
	ldi r16, 0x80 ; 5V Vref, ADC0 una sola entrada, elijo el puerto ADC0
	sts ADMUX, r16 ; el resultado de la conversion queda a la derecha
	ret

Read_ADC:
	lds r17, ADCSRA
	ori r17, (1<<ADSC)
	sts ADCSRA, r17  ; empezar la conversión
Keep_polling:		  ; esperar que termine la conversión
	lds r17,ADCSRA
	sbrs r17, ADIF ; terminó la conversión?
	rjmp Keep_polling  ; si no terminó, seguir preguntando
	lds r17, ADCSRA
	ori r17, (1<<ADIF) ; limpiar el flag ADIF con un 1
	sts ADCSRA, r17 
	lds r24, ADCL ; lee el resultado de la conversion, parte baja
	lds r25, ADCH ; y parte alta
	;rjmp Read_ADC
	ret

USART_init:
	ldi r16,low(0x67) ; cargar baudrate de 9600 con f_osc = 16 MHz
	ldi r17, high(0x67)
	sts UBRR0L, r16
	sts UBRR0H, r17
	ldi r16, (1<<RXEN0)|(1<<TXEN0) ; habilitar recepcion y transmision
	sts UCSR0B,r16
	ldi r16, (3<<UCSZ00) ; configurar framing: 8 bits de datos, 1 bit de start, 1 bit de stop
	sts UCSR0C,r16
	ret

USART_Transmit:
	lds r17, UCSR0A
	sbrs r17, UDRE0 ; si el buffer está vacío, salta una instrucción
	rjmp USART_Transmit
	sts UDR0,r16 ; transmite el dato (r16) de forma serial
	ret

USART_Receive:
; Wait for data to be received
	lds r17, UCSR0A
	sbrs r17, RXC0
	rjmp USART_Receive
; Get and return received data from buffer
	lds r16, UDR0
	ret



delay_1s: ;				 CM
	ldi r18, 50			;1
delay2:
	ldi r19, 200		;1
delay1:
	ldi r20, 199		;1
delay0:
	nop					;1
	dec r20				;1
	brne delay0			;2/1 hasta acá, delay0
	nop					;1
	dec r19				;1
	brne delay1			;2/1 hasta acá, delay1
	dec r18				;1
	brne delay2			;2/1 hasta acá, delay2
	ret					;8 (4 del call y 4 del ret)
; t_delay0 = 198*4 + 3 = 795
; t_delay1 = (1+t_delay0+4)*199 + (1+t_delay0+3) = 159999
; t_delay2 = (1+t_delay1+3)*49 + (1+t_delay1+2) = 8000149
; t_delay = 1 + t_delay2 + 8 = 8000158 ciclos de maquina
; t_delay(seg) = 8000158/f_osc = 1.00001975 para f_osc = 8 MHz

; Agrego rutina de servicio de INT0
EX_INT0_ISR:
	; cuando se apreta el pulsador se debe empezar a leer
	; para probar cargo un valor a r25 como señal
	; de que se ejecutò la interrupción
	ldi r25,50
	reti ; volver de la interrupción

; Agrego inicialización de SPI
SPI_init:
	LDI R17, (1<<MOSI)|(1<<SCK)|(1<<SS)
	OUT DDRB, R17 ; MOSI, SCK y SS como salida
	LDI R17, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
	OUT SPCR, R17 ; habiltar spi, modo maestro, CLK = f_osc/16
	ret
	; ver si hay problemas por usar f_osc/16 acá y f_osc/128 en el usart

; rutina de transmisión por SPI
SPI_Transmit:
	CBI PORTB, SS ; habilitar dispositivo esclavo
	OUT SPDR, r16 ; empezar a transmitir dato (r16)
SPI_keep_polling:
	IN R20, SPSR
	SBRS R20, SPIF ; esperar que la transmision
	RJMP SPI_keep_polling ; se complete

	SBI PORTB, SS ; deshabilitar dispositivo esclavo
	ret
