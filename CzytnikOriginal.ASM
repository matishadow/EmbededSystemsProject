;TITLE	'CZYTNIK KART MAGNETYCZNYCH'
;**************************************
;Program czyta dane z karty magnetycznej
;Dane traktowane są jako 5 bitowe - 4 bity znaku + bit parzystości
;maxymalna ilość danych - 40 znaków
;Takie parametry zapisu są typowe dla drugiej ścieżki kart magnetycznych
;Program nie sprawdza poprawności odczytu - parzystości ani sumy kontrolnej
;Program wypisuje na wyświetlaczu odczytane dane do momentu napotkania danej
;oznaczającej koniec danych 1111B (na wyświetlaczu jako ?).
;Na czas odczytu danych włączany jest BUZZER

;**************************************
;Pamięć wewnętrzna
DATA	EQU	30H

BUZ	EQU	P1.5

;**************************************
;Ustawienie układu 8255
;PORT A - WEJŚCIE MOD 0 - nieużywane
;PORT B - WEJŚCIE MOD 0
;B0 <- -CARD PRESENT
;B1 <- -STROBE
;B2 <- -DATA
;PORT C - WEJŚCIE - nieużywane

SET_8255	EQU	10011011B

;**************************************
	LJMP	START

;**************************************
	ORG	100H
START:

	MOV	R0,#CS55D	;ustaw układ 8255 jako wejście
	MOV	A,#SET_8255
	MOVX	@R0,A
	MOV	R0,#CS55B	;dalej tylko odczyt portu B

	LCALL	LCD_CLR		;wypisanie tekstu oczekiwania na kartę
	MOV	DPTR,#TEXT1
	LCALL	WRITE_TEXT

;**************************************
;odczyt karty magnetycznej
LOOP:
;zerowanie obszaru danych
	MOV	R1,#DATA	;adres początku danych
	CLR	A
CLEAR:
	MOV	@R1,A
	INC	R1
	CJNE	R1,#DATA+40,CLEAR	;adres końca danych

WAIT_CARD:			;oczekiwanie na włożenie karty
	MOVX	A,@R0		;tj. na sygnał CARD PRESENT
	JB	ACC.0,WAIT_CARD

;**************************************
;wykryto obecność karty
;oczekiwanie na sygnał CLOCK i piewszy bit danych
	CLR	BUZ		;włączenie BUZZERa na czas odczytu karty

	MOV	R1,#DATA	;ustawienie wskaźnika na dane
	MOV	R3,#40		;licznik - odczyt max 40 znaków
	MOV	R2,#5		;licznik - ilość bitów w znaku

WAIT_CLOCK_MIN:			;oczekiwanie na ujemną połówkę CLOCKa
	MOVX	A,@R0
	JB	ACC.0,END_READ		;koniec odczytu jeśli brak sygnału
					;obecności karty -CARD PRESENT
	JB	ACC.1,WAIT_CLOCK_MIN
					;odczyt bitów na ujemnym zboczu CLOCKa
	JNB	ACC.2,FIRST_BIT		;sprawdzenie, czy jest pierwszy bit
					;- pierwszy bit = 0

WAIT_CLOCK_PLUS:		;ujemna połówka CLOCKa - czekaj na dodatnią
	MOVX	A,@R0
	JNB	ACC.1,WAIT_CLOCK_PLUS

	SJMP	WAIT_CLOCK_MIN	;powrót do oczekiwania na pierwszy bit

;**************************************
;wykryto pierwszy bit - odczyt wszystkich danych z karty
FIRST_BIT:
NEXT_BIT:
	MOV	C,ACC.2		;zapisanie bitu do danej
	CPL	C		;bity na karcie są zanegowane
	MOV	A,@R1		;więc przed zapisem trzeba je negować
	RRC	A		;bity są czytane od najmłodszego
	MOV	@R1,A		;-wsuwane są od lewej do prawej

	DJNZ	R2,NEXT_CLOCK_PLUS	;czy zapisano już 5 bitów danej

	RR	A			;tak - dosuń daną do prawej
	RR	A
	RR	A
	MOV	@R1,A
	INC	R1			;ustaw adres na następną daną
	MOV	R2,#5			;ustaw licznik bitów

	DJNZ	R3,NEXT_CLOCK_PLUS	;czy odczytano już wszystkie dane
	SJMP	END_READ		;tak - koniec odczytu karty

NEXT_CLOCK_PLUS:			;oczekiwanie na kolejny CLOCK dodatni
	MOVX	A,@R0
	JNB	ACC.1,NEXT_CLOCK_PLUS

NEXT_CLOCK_MIN:				;oczekiwanie na kolejny CLOCK ujemny
	MOVX	A,@R0
	JB	ACC.0,END_READ		;koniec odczytu jeśli brak sygnału
					;obecności karty -CARD PRESENT
	JB	ACC.1,NEXT_CLOCK_MIN
	SJMP	NEXT_BIT		;jest ujemne zbocze CLOCKa
					;-odczyt kolejnego bitu

;**************************************
;odczyt zakończony - wypisanie danych na wyświetlacz LCD
END_READ:
	SETB	BUZ		;koniec odczytu - wyłączenie BUZZERa
	LCALL	LCD_CLR		;zerowanie wyświetlacza

	MOV	A,#40		;obliczenie ilości odczytanych danych
	CLR	C
	SUBB	A,R3
	MOV	R3,A
	JZ	WRITE_END	;nie odczytano żadnych znaków

	MOV	R1,#DATA	;adres na pierwszą daną

;**************************************
;zapis danych na wyświetlacz
WRITE:
	MOV	A,@R1		;odczyt danej z pamięci
	ANL	A,#0FH		;zerowanie bitu parzystości
	ADD	A,#30H		;wypisanie na wyświetlaczu LCD
	LCALL	WRITE_DATA

	MOV	A,@R1
	ANL	A,#0FH
	CJNE	A,#0FH,NO_END	;czy znacznik końca
	SJMP	WRITE_END

NO_END:
	INC	R1
	DJNZ	R3,WRITE

;**************************************
;koniec danych
WRITE_END:			;oczekiwanie na koniec sygnału -CARD PRESENT
	MOVX	A,@R0
	JNB	ACC.0,WRITE_END

	LJMP	LOOP		;oczekiwanie na następną kartę

;**************************************
TEXT1:
	DB	'WAIT FOR CARD  ',0

;**************************************
;END

