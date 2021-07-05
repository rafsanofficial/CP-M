;       SYSTEM GENERATION PROGRAM, VERSION FOR MDS
		VERS	EQU 11			;X. X
;
;        COPYRIGHT (C) DIGITAL RESEARCH
;                 1976
;
		ORG		100H			;BASE OF TRANSIENT AREA
;
		LOADP	EQU 900H		;LOAD POINT FOR SYSTEM DURING LOAD/STORE
		BDOS	EQU 5H			;DOS ENTRY POINT
		BOOT	EQU 0			;JUMP TO 'BOOT' TO REBOOT SYSTEM
		CONI	EQU 1			;CONSOLE INPUT FUNCTION
		CONO	EQU 2			;CONSOLE OUTPUT FUNCTION
		SELF	EQU 14			;SELECT DISK
		DISKA	EQU 0			;NUMBER CORRESPONDING TO A
		DISKB	EQU 1			;AND B, RESPECTIVELY
;
		MAXTRY	EQU 10			;MAXIMUM NUMBER OF RETRIES ON EACH READ/WRITE
		NTRKS	EQU 2			;NUMBER OF TRACK RESERVED FOR CP/M
		CR		EQU BDH			;CARRIAGE RETURN
		LF		EQU BAH			;LINE FEED
		STACKSIZE	EQU 10			;SIZE OF LOCAL STACK
;
		WBOOT	EQU 1			;ADDRESS OF WARM BOOT (OTHER PATCH ENTRY
								;POINTS ARE COMPUTED RELATIVE TO WBOOT)
		SELDSK	EQU 24			;WBOOT+24 FOR DISK SELECT
		SETTRK	EQU 27			;WBOOT+27 FOR SET TRACK FUNCTION
		SETSEC	EQU 30			;WBOOT+30 FOR SET SECTOR FUNCTION
		SETDMA	EQU 33			;WBOOT+33 FOR SET DMA ADDRESS
		READF	EQU 36			;WB00T+36 FOR READ FUNCTION
		WRITF	EQU 39			;WB00T+39 FOR WRITE FUNCTION
;
		LXI		SP, STACK		;SET LOCAL STACK
		JMP		START
;
;		UTILITY SUBROUTINES
GETCHAR:
;		READ CONSOLE CHARACTER TO REGISTER A
		MVI		C, CONI! CALL BDOS!
;		CONVERT TO UPPER CASE BEFORE RETURN
		ANI		5FH! RET
;
PUTCHAR:
;		WRITE CHARACTER FROM A TO CONSOLE
		MOV		E, A! MVI C, COND! CALL BDOS! RET
;
CRLF:							;SEND CARRIAGE RETURN, LINE FEED
		MVI		A, CR
		CALL	PUTCHAR
		MVI		A, LF
		CALL	PUTCHAR
		RET
;
OUTMSG:							;PRINT MESSAGE ADDRESSED BY H,L TIL ZERO
		PUSH	H! CALL CRLF! POP H	;DROP THRU TO OUTMSG0
OUTMSGA:
		MOV		A, M! ORA A! RZ
;		MESSAGE NOT YET COMPLETED
		PUSH	H! CALL PUTCHAR! POP H! INX H
		JMP		OUTMSG0
;
SEL:
;		SELECT DISK GIVEN BY REGISTER A
		MOV		C, A! LHLD WBOOT! LXI D, SELDSK! BAD D! PCHL
;
TRK:							;SET UP TRACK
		LHLD	WBOOT			;ADDRESS OF BOOT ENTRY
		LXI		D, SETTRK		;OFFSET FOR SETTRK ENTRY
		DAD		D
		PCHL					;GONE TO SETTRK
;
SEC:							;SET UP SECTOR NUMBER
		LHLD	WBOOT
		LXI		D, SETSEC
		DAD		D
		PCHL
;
DMA:							;SET DMA ADDRESS TO VALUE OF B,C
		LHLD	WBOOT
		LXI		D, SETDMA
		DAD		D
		PCHL
;
READ:							;PERFORM READ OPERATION
		LHLD	WBOOT
		LXI		D, READF
		DAD		D
		PCHL
;
WR1TE:							;PERFORM WRITE OPERATON
		LHLD	WBOOT
		LXI		D, WRITF
		DAD		D
		PCHL
GETPUT:
;       GET OR PUT CP/M (RW=0 FOR READ, 1 FOR WRITE)
;       DISK IS ALREADY SELECTED
;
		LXI		H, LOADP		;LOAD POINT IN RAN FOR CP/H DURING SYS(
		SHLD	DMADDR
;
;       CLEAR TRACK TO 00
		XRA		A				;CLEAR REG-A
		STA		TRACK
;
RWTRK:							;READ OR WRITE NEXT TRACK
		LXI		H, TRACK
		MOV		A, M
		CPI		NTRKS			;LOADED OR DUMPED ENTIRE SYSTEM?
		JNC		ENDRW			;END OF READ OR WRITE
;
;       OTHERWISE NOTDONE, GO TO HEXT TRACK
		INR		M
		MOV		C, A
		CALL	TRK				;TO SET TRACK
		XRA		A
		STA		SECTOR			;SECTOR INCREMENTED BEFORE READ OR WRITE
;
RWSEC:							;READ OR WRITE SECTOR
		LXI		H, SECTOR
		MOV		A, M
		CPI		26				;PAST LAST SECTOR ON THIS TRACK?
		JNC		ENDTRK
		IHR		M				;TO NEXT SECTOR
;
;		READ OR WRITE SECTOR TO OR FROM CURRENT DMA ADDR
		LHLD	DMADDR
		MOV		B, H
		MOV		C, L			;READY FOR SET DMA
		LXI		D, 00H			;INCREMENT BY 128 BYTES
		DAD		D
		SHLD	DMADDR			;READY FOR NEXT OPERATION
		CALL	DMA				;DMA ADDRESS SET FROM B, C
		XRA		A
		STA		RETRY			;SET TO ZERO RETRIES
;
TRYSEC:							;TRY TO READ OR WRITE CURRENT SECTOR
		LDA		RETRY
		CPI		MAXTRY			;TOO MANY RETRIES?
		JC		TRYOK
;
;		PAST MAXTRIES, MESSAGE AHD IGNORE
		LXI		H, ERRMSG
		CALL	OUTMSG
		CALL	GETCHAR
		CPI		CR
		JNZ		REBOOT
;
;		TYPED A CR, OK TO IGNORE
		CALL	CRLF
		JMP		RWSEC
;
TRYOK:
;		OK TO TRY READ OR WRITE
		INR		A
		STA		RETRY			;RETRY=RETRY+1
		LDA		SECTOR			;NEXT SECTOR TO READ OR WRITE
		MOV		C, A
		CALL	SEC				;SET UP SECTOR NUMBER
		LDA		RW				;READ OR WRITE?
		ORA		A
		JZ		TRYREAD
;
;		MUST BE WRITE
		CALL	WRITE
		JMP		CHKRW			;CHECK FOR ERROR RETURNS
TRYREAD:
		CALL	READ
CHKRW:
		ORA		A
		JZ		RWSEC			;ZERO FLAG IF R/W OK
;
;		ERROR, RETRY OPERATION
		JMP		TRYSEC
;
;		END OF TRACK
ENDTRK:
		JMP		RWTRK			;FOR ANOTHER TRACK
;
ENDRW:							;END OF READ OR WRITE, RETURN TO CALLER
		RET
;
;
START:
;
		LXI		H, SIGHON
		CALL	OUTMSG
		LXI		H, ASKGET		;GET SYSTEM?
		CALL	OUTMSG
		CALL	GETCHAR
		MVI		C, DISKB		;ASSUME DISK B, UNLESS SPECIFIED
		CPI		'Y'
		JZ		GETC			;GET FROM DISK B
		CPI		'B'
		JZ		GETC
		MVI		C, DISKA		;IN CASE A WAS TYPED
		CPI		'A'				;MAY BE FROM A
		JNZ		PUTSYS
;
GETC:
;		SELECT DISK GIVEN  BY REGISTER C
		MOV		A, C
		ADI		'A'
		STA		GDISK			;TO SET MESSAGE
		MOV		A, C! CALL SEL
;		GETSYS, SET RW TO READ, AND GET SYSTEM
		CALL	CRLF
		LXI		H, GETMSG
		CALL	OUTMSG
		CALL	GETCHAR
		CPI		CR
		JNZ		REBOOT
		CALL	CRLF
;
		XRA		A
		STA		RW
		CALL	GETPUT
		LXI		H, DONE
		CALL	OUTMSG
;
;		PUT SYSTEM
PUTSYS:
		CALL	CRLF
		LXI		H, ASKPUT
		CALL	OUTMSG
		CALL	GETCHAR
		MVI		C, DISKB		;ASSUME DISKB, UNLESS SPECIFIED
		CPI		'Y'
		JZ		PUTC
		CPI		'B'
		JZ		PUTC
;
;		MAY BE DISK A
		MVI		C, DISKA
		CPI		'A'
		JNZ		REBOOT
PUTC:
;         ;SET DISK FROM REGISTER C
		MOV		A, C
		ADI		'A'
		STA		PDISK			;MESSAGE SET
		MOV		A, C! CALL SEL
;		PUT SYSTEM, SET RW TO WRITE
		CALL	CRLF
		LXI		H, PUTMSG
		CALL	OUTMSG
		CALL	GETCHAR
		CPI		CR
		JNZ		REBOOT
		CALL	CRLF
;
		LXI		H, RW
		MVI		M, 1
		CALL	GETPUT			;TO PUT SYSTEM BACK ON DISKETTE
		LXI		H, DONE
		CALL	OUTMSG
;
REBOOT:
		LXI		H, BOOTING
		CALL	OUTMSG
		CALL	GETCHAR
		CPI		CR
		JNZ		REBOOT
;
;		SELECT DISK A BEFORE REBOOT
		MVI		A, DISKA! CALL SEL! CALL CRLF! JMP BOOT
;
;		DATA AREAS
;		MESSAGES
SIGNON:
		DB		'SYSGEN VERSION'
		DB		VERS/10+'0','.',VERS MOD 10+'0'
		DB		0
ASKGET:	DB		'GET SYSTEM? (Y/N)', 0
GETMSG:	DB		'SOURCE ON'
CDISK:	DB		'B'
		DB		', THEN TYPE RETURN', 0
ASKPUT:	DB		'PUT SYSTEM? (Y/N)', 0
PUTMSG:	DB		'DESTINATION ON '
PDISK:	DB		'B'
		DB		', THEN TYPE RETURN', 0
ERRMSG:	DB		'PERMANENT ERROR, TYPE RETURN TO IGNORE', 0
DONE:	DB		'FUNCTION COMPLETE', 0
BOOTING:DB		'REBOOTING, TYPE RETURN', 0
;
;		VARIABLES
SDISK:	DS		1				;SELECTED DISK FOR CURRENT OPERATION
TRACK:	DS		1				;CURRENT TRACK
SECTOR:	DS		1				;CURRENT SECTOR
RW:		DS		1				;READ IF 0, WRITE IF 1
DMADDR:	DS		2				;CURRENT DMA ADDRESS
RETRY:	DS		1				;NUMBER OF TRIES ON THIS SECTOR
		DS		STACKSIZE=2
STACK:
		END
