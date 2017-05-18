; TITLE	'CZYTNIK KART MAGNETYCZNYCH'
;**************************************
; Program czyta dane z karty magnetycznej
; Dane traktowane są jako 5 bitowe - 4 bity znaku + bit parzystości
; maxymalna ilość danych - 40 znaków
; Takie parametry zapisu są typowe dla drugiej ścieżki kart magnetycznych
; Program nie sprawdza poprawności odczytu - parzystości ani sumy kontrolnej
; Program wypisuje na wyświetlaczu odczytane dane do momentu napotkania danej
; oznaczającej koniec danych 1111B (na wyświetlaczu jako ?).
; Na czas odczytu danych włączany jest BUZZER

;**************************************
; Pamięć wewnętrzna
DATA	EQU	30H
LED	EQU	P1.7
BUZ	EQU	P1.5

;**************************************
; Ustawienie układu 8255
; PORT A - WEJŚCIE MOD 0 - nieużywane
; PORT B - WEJŚCIE MOD 0
; B0 <- -CARD PRESENT
; B1 <- -STROBE
; B2 <- -DATA
; PORT C - WEJŚCIE - nieużywane

SET_8255	EQU	10011011B

;**************************************
	LJMP	START

;**************************************
	ORG	100H
START:

	MOV	R0,#CS55D	; ustaw układ 8255 jako wejście
	MOV	A,#SET_8255
	MOVX	@R0,A
	MOV	R0,#CS55B	; dalej tylko odczyt portu B

	LCALL	LCD_CLR		; wypisanie tekstu oczekiwania na kartę
	MOV	DPTR,#TEXT1
	LCALL	WRITE_TEXT

;**************************************
; odczyt karty magnetycznej
LOOP:
; zerowanie obszaru danych
	MOV	R1,#DATA	; adres początku danych
	CLR	A
CLEAR:
	MOV	@R1,A
	INC	R1
	CJNE	R1,#DATA+40,CLEAR	; adres końca danych (30H)

WAIT_CARD:			; oczekiwanie na włożenie karty
	MOVX	A,@R0		; tj. na sygnał CARD PRESENT
	JB	ACC.0,WAIT_CARD

;**************************************
; wykryto obecność karty
; oczekiwanie na sygnał CLOCK i piewszy bit danych
	; CLR	BUZ		; włączenie BUZZERa na czas odczytu karty

	MOV	R1,#DATA	; ustawienie wskaźnika na dane
	MOV	R3,#40		; licznik - odczyt max 40 znaków
	MOV	R2,#5		; licznik - ilość bitów w znaku

WAIT_CLOCK_MIN:			; oczekiwanie na ujemną połówkę CLOCKa
	MOVX	A,@R0
	JB	ACC.0,END_READ		; koniec odczytu jeśli brak sygnału
					; obecności karty -CARD PRESENT
	JB	ACC.1,WAIT_CLOCK_MIN
					; odczyt bitów na ujemnym zboczu CLOCKa
	JNB	ACC.2,FIRST_BIT		; sprawdzenie, czy jest pierwszy bit
					; - pierwszy bit = 0

WAIT_CLOCK_PLUS:		; ujemna połówka CLOCKa - czekaj na dodatnią
	MOVX	A,@R0
	JNB	ACC.1,WAIT_CLOCK_PLUS

	SJMP	WAIT_CLOCK_MIN	; powrót do oczekiwania na pierwszy bit

;**************************************
; wykryto pierwszy bit - odczyt wszystkich danych z karty
FIRST_BIT:
NEXT_BIT:
	MOV	C,ACC.2		; zapisanie bitu do danej
	CPL	C		; bity na karcie są zanegowane
	MOV	A,@R1		; więc przed zapisem trzeba je negować
	RRC	A		; bity są czytane od najmłodszego
	MOV	@R1,A		; -wsuwane są od lewej do prawej

	DJNZ	R2,NEXT_CLOCK_PLUS	; czy zapisano już 5 bitów danej

	RR	A			; tak - dosuń daną do prawej
	RR	A
	RR	A
	MOV	@R1,A
	INC	R1			; ustaw adres na następną daną
	MOV	R2,#5			; ustaw licznik bitów

	DJNZ	R3,NEXT_CLOCK_PLUS	; czy odczytano już wszystkie dane
	SJMP	END_READ		; tak - koniec odczytu karty

NEXT_CLOCK_PLUS:			; oczekiwanie na kolejny CLOCK dodatni
	MOVX	A,@R0
	JNB	ACC.1,NEXT_CLOCK_PLUS

NEXT_CLOCK_MIN:				; oczekiwanie na kolejny CLOCK ujemny
	MOVX	A,@R0
	JB	ACC.0,END_READ		; koniec odczytu jeśli brak sygnału
					; obecności karty -CARD PRESENT
	JB	ACC.1,NEXT_CLOCK_MIN
	SJMP	NEXT_BIT		; jest ujemne zbocze CLOCKa
					; -odczyt kolejnego bitu

;**************************************
; odczyt zakończony - wypisanie danych na wyświetlacz LCD
END_READ:
	SETB	BUZ		; koniec odczytu - wyłączenie BUZZERa
	LCALL	LCD_CLR		; zerowanie wyświetlacza

	MOV	A,#40		; obliczenie ilości odczytanych danych
	CLR	C
	SUBB	A,R3
	MOV	R3,A
	JZ	WRITE_END	; nie odczytano żadnych znaków

	MOV	R1,#DATA	; adres na pierwszą daną
	
	; sprawdzam, czy na poczatku srednik
	MOV	A,@R1		; odczyt danej z pamięci
	MOV B,A         ; zapamiętanie wartości A aby potem porównać ze średnikiem
	MOV A, #0Bh     ; do A wkładamy średnik
	XRL A,B         ; sprawdzamy czy znak zapisany w B to średnik
	JZ WRITE        ; jeśli tak to skaczemy do normalnego wypisywania
	
P_WRITE2:
	CPL LED
	MOV	R1,#DATA+40
	LJMP WRITE2
	
;**************************************
WRITE:	
	MOV	A,@R1		; odczyt danej z pamięci
	MOV B,A		    ; !!!zapamietuje parity z danych
	
	ANL	A,#0FH      ; zerowanie bitu parzystości???
	JB PSW.0,PARA0
	JNB PSW.0,PARA1
PARA1:
	JB B.4,PAR_OK
	JNB B.4,WRITE_ERR_CHR
PARA0:
	JNB B.4,PAR_OK
	JB B.4,WRITE_ERR_CHR
PAR_OK:
	
;**************************************
; zapis danych na wyświetlacz

	MOV	A,@R1		; odczyt danej z pamięci
	ANL	A,#0FH		; zerowanie bitu parzystości
	ADD	A,#30H		; dodanie 48 aby zgadzało się z ascii	
	LCALL	WRITE_DATA ; wypisanie na wyświetlaczu LCD

	MOV	A,@R1
	ANL	A,#0FH
	CJNE	A,#0FH,NO_END	; czy znacznik końca
	SJMP	WRITE_END

NO_END:
	INC	R1
	DJNZ	R3,WRITE
	LJMP WRITE_END
WRITE_END:			; oczekiwanie na koniec sygnału -CARD PRESENT
	MOVX	A,@R0
	JNB	ACC.0,WRITE_END

	LCALL CHECK_SUM
	MOV R1, #DATA+40  ; !!! TU też do sprawdzenia czy ta suma z karty jest tam
	MOV B , @R1
	CJNE A, B, WRITE_ERR_SUM

	LJMP	LOOP		; oczekiwanie na następną kartę
;**************************************
WRITE2:	
	; CPL LED
	MOV	A,@R1		; odczyt danej z pamięci
	
	MOV C, ACC.7
	MOV B.0,C
	MOV C, ACC.6
	MOV B.1,C
	MOV C, ACC.5
	MOV B.2,C
	MOV C, ACC.4
	MOV B.3,C
	MOV C, ACC.3
	MOV B.4,C
	MOV A,B
	
	ANL	A,#0FH      ; zerowanie bitu parzystości???
	
	JB PSW.0,PARA0_2
	JNB PSW.0,PARA1_2
PARA1_2:
	JB B.4,PAR_OK2
	JNB B.4,WRITE_ERR_CHR
PARA0_2:
	JNB B.4,PAR_OK2
	JB B.4,WRITE_ERR_CHR
PAR_OK2:
	
;**************************************
; zapis danych na wyświetlacz
	; XOR B,B
	MOV	A,@R1		; odczyt danej z pamięci
	ANL	A,#0FH		; zerowanie bitu parzystości
	ADD	A,#30H		; wypisanie na wyświetlaczu LCD
	LCALL	WRITE_DATA

	MOV	A,@R1
	ANL	A,#0FH
	CJNE	A,#0FH,NO_END2	; czy znacznik końca
	SJMP	WRITE_END

NO_END2:
	DEC	R1
	DJNZ	R3,WRITE2


	LJMP AFTER_CHECK
; Podprocedura do liczenia xora z danych od DATA do ;
; podprocedura psuje rejestry A i B
CHECK_SUM:
	MOV B, #0        ; zerujemy B bo tam będziemy trzymac wynik xora
	MOV R1, #DATA
CHECK_LOOP:
	MOV A, @R1       ; znaki po kolei idą do A
   ;ANL	A,#0FH       ; !!! TU nie jestem pewien czy suma znajdująca się na karcie jest liczona z bitem parzystości czy nie
	XRL B, A         ; xorujemy je
	MOV A, @R1       ; znowu znak do A żeby potem sprawdzić czy jest on średnikiem
	INC R1           ; przesuwamy wskaźnik na następny znak
	CJNE	A,#0FH,CHECK_LOOP    ; Sprawdzamy czy znak jest średnikiem
	                 ; średnik też xorujemy
	MOV A, B        ; wynik zwracamy w A
	RET
AFTER_CHECK:


;**************************************
; koniec danych

WRITE_ERR_CHR:
	; CPL LED
	MOV	DPTR,#ERR_CHR
	LCALL	WRITE_TEXT	
	LJMP LOOP
WRITE_ERR_SUM:
	LCALL LCD_CLR
	MOV DPTR,#ERR_SUM
	LCALL 	WRITE_TEXT
	LJMP LOOP
	
WRITE_TEST1:
	MOV	DPTR,#TEST1
	LCALL	WRITE_TEXT	
	LJMP LOOP
;**************************************
TEXT1:
	DB	'WAIT FOR CARD  ',0
ERR_CHR:
	DB 	'BLAD PARZYSTOSCI ZNAKU',0
ERR_SUM:
	DB	'BLAD SUMY KONTROLNEJ',0

TEST1:
	DB	'test', 0
;**************************************
; END

