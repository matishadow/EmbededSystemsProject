;TITLE	'CZYTNIK KART MAGNETYCZNYCH'
;**************************************
;Program czyta dane z karty magnetycznej
;Dane traktowane s¹ jako 5 bitowe - 4 bity znaku + bit parzystoœci
;maxymalna iloœæ danych - 40 znaków
;Takie parametry zapisu s¹ typowe dla drugiej œcie¿ki kart magnetycznych
;Program nie sprawdza poprawnoœci odczytu - parzystoœci ani sumy kontrolnej
;Program wypisuje na wyœwietlaczu odczytane dane do momentu napotkania danej
;oznaczaj¹cej koniec danych 1111B (na wyœwietlaczu jako ?).
;Na czas odczytu danych w³¹czany jest BUZZER

;**************************************
;Pamiêæ wewnêtrzna
DATA	EQU	30H

BUZ	EQU	P1.5

;**************************************
;Ustawienie uk³adu 8255
;PORT A - WEJŒCIE MOD 0 - nieu¿ywane
;PORT B - WEJŒCIE MOD 0
;B0 <- -CARD PRESENT
;B1 <- -STROBE
;B2 <- -DATA
;PORT C - WEJŒCIE - nieu¿ywane

SET_8255	EQU	10011011B

;**************************************
	LJMP	START

;**************************************
	ORG	100H
START:

	MOV	R0,#CS55D	;ustaw uk³ad 8255 jako wejœcie
	MOV	A,#SET_8255
	MOVX	@R0,A
	MOV	R0,#CS55B	;dalej tylko odczyt portu B

	LCALL	LCD_CLR		;wypisanie tekstu oczekiwania na kartê
	MOV	DPTR,#TEXT1
	LCALL	WRITE_TEXT

;**************************************
;odczyt karty magnetycznej
LOOP:
;zerowanie obszaru danych
	MOV	R1,#DATA	;adres pocz¹tku danych
	CLR	A
CLEAR:
	MOV	@R1,A
	INC	R1
	CJNE	R1,#DATA+40,CLEAR	;adres koñca danych

WAIT_CARD:			;oczekiwanie na w³o¿enie karty
	MOVX	A,@R0		;tj. na sygna³ CARD PRESENT
	JB	ACC.0,WAIT_CARD

;**************************************
;wykryto obecnoœæ karty
;oczekiwanie na sygna³ CLOCK i piewszy bit danych
	CLR	BUZ		;w³¹czenie BUZZERa na czas odczytu karty

	MOV	R1,#DATA	;ustawienie wskaŸnika na dane
	MOV	R3,#40		;licznik - odczyt max 40 znaków
	MOV	R2,#5		;licznik - iloœæ bitów w znaku

WAIT_CLOCK_MIN:			;oczekiwanie na ujemn¹ po³ówkê CLOCKa
	MOVX	A,@R0
	JB	ACC.0,END_READ		;koniec odczytu jeœli brak sygna³u
					;obecnoœci karty -CARD PRESENT
	JB	ACC.1,WAIT_CLOCK_MIN
					;odczyt bitów na ujemnym zboczu CLOCKa
	JNB	ACC.2,FIRST_BIT		;sprawdzenie, czy jest pierwszy bit
					;- pierwszy bit = 0

WAIT_CLOCK_PLUS:		;ujemna po³ówka CLOCKa - czekaj na dodatni¹
	MOVX	A,@R0
	JNB	ACC.1,WAIT_CLOCK_PLUS

	SJMP	WAIT_CLOCK_MIN	;powrót do oczekiwania na pierwszy bit

;**************************************
;wykryto pierwszy bit - odczyt wszystkich danych z karty
FIRST_BIT:
NEXT_BIT:
	MOV	C,ACC.2		;zapisanie bitu do danej
	CPL	C		;bity na karcie s¹ zanegowane
	MOV	A,@R1		;wiêc przed zapisem trzeba je negowaæ
	RRC	A		;bity s¹ czytane od najm³odszego
	MOV	@R1,A		;-wsuwane s¹ od lewej do prawej

	DJNZ	R2,NEXT_CLOCK_PLUS	;czy zapisano ju¿ 5 bitów danej

	RR	A			;tak - dosuñ dan¹ do prawej
	RR	A
	RR	A
	MOV	@R1,A
	INC	R1			;ustaw adres na nastêpn¹ dan¹
	MOV	R2,#5			;ustaw licznik bitów

	DJNZ	R3,NEXT_CLOCK_PLUS	;czy odczytano ju¿ wszystkie dane
	SJMP	END_READ		;tak - koniec odczytu karty

NEXT_CLOCK_PLUS:			;oczekiwanie na kolejny CLOCK dodatni
	MOVX	A,@R0
	JNB	ACC.1,NEXT_CLOCK_PLUS

NEXT_CLOCK_MIN:				;oczekiwanie na kolejny CLOCK ujemny
	MOVX	A,@R0
	JB	ACC.0,END_READ		;koniec odczytu jeœli brak sygna³u
					;obecnoœci karty -CARD PRESENT
	JB	ACC.1,NEXT_CLOCK_MIN
	SJMP	NEXT_BIT		;jest ujemne zbocze CLOCKa
					;-odczyt kolejnego bitu

;**************************************
;odczyt zakoñczony - wypisanie danych na wyœwietlacz LCD
END_READ:
	SETB	BUZ		;koniec odczytu - wy³¹czenie BUZZERa
	LCALL	LCD_CLR		;zerowanie wyœwietlacza

	MOV	A,#40		;obliczenie iloœci odczytanych danych
	CLR	C
	SUBB	A,R3
	MOV	R3,A
	JZ	WRITE_END	;nie odczytano ¿adnych znaków

	MOV	R1,#DATA	;adres na pierwsz¹ dan¹

;**************************************
;zapis danych na wyœwietlacz
WRITE:
	MOV	A,@R1		;odczyt danej z pamiêci
	ANL	A,#0FH		;zerowanie bitu parzystoœci
	ADD	A,#30H		;wypisanie na wyœwietlaczu LCD
	LCALL	WRITE_DATA

	MOV	A,@R1
	ANL	A,#0FH
	CJNE	A,#0FH,NO_END	;czy znacznik koñca
	SJMP	WRITE_END

NO_END:
	INC	R1
	DJNZ	R3,WRITE

;**************************************
;koniec danych
WRITE_END:			;oczekiwanie na koniec sygna³u -CARD PRESENT
	MOVX	A,@R0
	JNB	ACC.0,WRITE_END

	LJMP	LOOP		;oczekiwanie na nastêpn¹ kartê

;**************************************
TEXT1:
	DB	'WAIT FOR CARD  ',0

;**************************************
;END

