;		MDS I/O DRIVERS FOR CP/M
;		VERSION 1.3 OCTOBER, 1976
		BIAS	EQU 800H		;FOR RELOCATION
;
;		COPYRIGHT (C) 1976
;		DIGITAL RESEARCH
;		BOX 579, PACIFIC GROVE CA.
;
;
		VERS	EQU 13			;CPM VERSION NUMBER
		PATCH	EQU 1500H+BIAS
;
		ORG		PATCH
		CPMB	EQU 800H+BIAS	;BASE OF CPM CONSOLE PROCESSOR
		BDOS	EQU 906H+BIAS	;BASIC DOS (RESIDENT PORTION)
		CPML	EQU $-CPMB		;LENGTH (IN BYTES) OF CPM SYSTEM
		NSECTS	EQU CPML/128	;NUMBER OF SECTORS TO LOAD
		LBIAS	EQU 980H-CPMB	;LOADER BIAS VALUE USED IN SYSGEN
		OFFSET	EQU 2			;NUMBER OF DISK TRACKS USED BY CP/M
		DISKA	EQU 84H			;ADDRESS OF LAST LOGGED DISK ON WARM START
		BUFF	EQU 80H			;DEFAULT BUFFER ADDRESS
		RETRY	EQU 10			;MAX RETRIES ON DISK I/O BEFORE ERROR
;
;		PERFORM FOLLOWING FUNCTIONS
;		BOOT     COLD START
;		WBOOT    WARM START (SAVE I/O BYTE)
;		(BOOT AND WBOOT ARE THE SAME FOR MDS)
;		CONST    CONSOLE STATUS
;		REG-A    =   00 IF NO CHARACTER READY
;		REG-A    =   FF IF CHARACTER READY
;		CONIN    CONSOLE CHARACTER IN (RESULT IN REG-A)
;		CONOUT   CONSOLE CHARACTER OUT (CHAR IN REG-C)
;		LIST     LIST OUT (CHAR IN REG-C)
;		PUNCH    PUNCH OUT (CHAR IN REG-C)
;		READER   PAPER TAPE READER IN (RESULT TO REG-A)
;		HOME     MOVE TO TRACK 00
;
;		(THE FOLLOWING CALLS SET-UP THE IO PARAMETER BLOCK FOR THE
;		MDS, WHICH IS USED TO PERFORM SUBSEQUENT READS AND WRITES)
;		SELDSK   SELECT DISK GIVEN BY REG-C (0,1,2...)
;		SETTRK   SET TRACK ADDRESS (6,...76) FOR SUBSEQUENT READ/WRITE
;		SETSEC   SET SECTOR ADDRESS (1,...,26) FOR SUBSEQUENT READ/WRITE
;		SETDMA   SET SUBSEQUENT DMA ADDRESS (INITIALLY 80H)
;
;		(READ AND WRITE ASSUME PREVIOUS CALLS TO SET UP THE IO PARAMETER
;		READ     READ TRACK/SECTOR TO PRESET DMA ADDRESS
;		WRITE    WRITE TRACK/SECTOR FROM PRESET DMA ADDRESS
;
;		JUMP VECTOR FOR INDIVIDUAL ROUTINES
		JMP		BOOT
WBOOTE:
		JMP		WBOOT
		JMP		CONST
		JMP		CONIN
		JMP		CONOUT
		JMP		LIST
		JMP		PUNCH
		JMP		READER
		JMP		HOME
		JMP		SELDSK
		JMP		SETTRK
		JMP		SETSEC
		JMP		SETDMA
		JMP		READ
		JMP		WRITE
;
;
;		END OF CONTROLLER - INDEPENDENT CODE, THE REMAINING SUBROUTINES
;		ARE TAILORED TO THE PARTICULAR OPERATING ENVIRNOMENT, AND ML
;		BE ALTERED FOR ANY SYSTEM WHICH DIFFERS FROM THE INTEL MDS
;
;		THE   FOLLOWING CODE ASSUMES THE MDS MONITOR EXISTS AT 0FB80H
;		AND   USES THE I/O SUBROUTINES WITHIN THE MONITOR
;
;		WE ALSO ASSUME THE MDS SYSTEM HAS TWO DISK DRIVES AVAILABLE
		NDISKS	EQU 2			;NUMBER OF DRIVES AVAILABLE
		REVRT	EQU OFDH		; INTERRUPT REVERT PORT
		INTC	EQU 0FCH		; INTERRUPT MASK PORT
		ICON	EQU 0F3H		;INTERRUPT  CONTROL PORT
		INTE	EQU 0111$1110B	;ENABLE RST 0(WARM BOOT), RST 7 (MON
;
;		MDS MONITOR EQUATES
		MON80	EQU BF300H		;MDS MONITOR
		RMONB0	EQU BFF0FH		;RESTART MONB0 (DISK SELECT ERROR)
		CI		EQU BF803H		;CONSOLE CHARACTER TO REG-A
		RI		EQU BF806H		;READER IN TO REG-A
		CO		EQU BF809H		;CONSOLE CHAR FROM C TO CONSOLE OUT
		PO		EQU BF86CH		;PUNCH CHAR FROM C TO PUNCH DEVICE
		LO		EQU BF80FH		;LIST FROM C TO LIST DEVICE
		CSTS	EQU BF812H		;CONSOLE STATUS OO/FF TO REGISTER A
;
;		DISK PORTS AND COMMANDS
		BASE	EQU 73H			;BASE OF DISK COMMAND IO PORTS
		DSTAT	EQU BASE		;DISK STATUS (INPUT)
		RTYPE	EQU BASE+1		;RESULT TYPE (INPUT)
		RBYTE	EQU BASE+3		;RESULT BYTE (INPUT)
;
		LOW		EQU BASE+1		;IOPB LOW ADDRESS (OUTPUT)
		HIGH	EQU BASE+2		;IOPB HIGH ADDRESS (OUTPUT)
;
		READF	EQU 4H			;READ FUNCTION
		WRITF	EQU 6H			;WRITE FUNCTION
		RECAL	EQU 3H			;RECALIBRATE DRIVE
		IORDY	EQU 4H			;I/O FINISHED MASK
		CR		EQU BDH			;CARRIAGE RETURN
		LF		EQU BAH			;LINE FEED
;
SIGNON:							;SIGNON MESSAGE, XXK CP/M     VERS Y.Y
		DB		CR, LF, LF
		DB		'00K CP/M VERS '
		DB		VERS/10+'0', ', ', VERS MOD 10+'0'
		DB		CR, LF, 0

BOOT:							;PRINT SIGNON MESSAGE AND GO TO DOS
		LXI		SP, BUFF+80H
		LXI		H, SIGNON
		CALL	PRMSG			;PRINT MESSAGE
		XRA		A				;CLEAR ACCUMULATOR
		STA		DISKA			;SET INITIALLY TO DISK A
		JMP		GOCPM			;GO TO CP/M
;
;
WBOOT:							;LOADER ON TRACK 0, SECTOR 1, WHICH WILL BE SKIPPED FOR WARM
								;READ CP/M FROM DISK - ASSUMING THERE IS A 128 BYTE COLD START
								;START
;
		LXI		SP, BUFF		;USING DMA - THUS 80 THRU FF AVAILABLE FOR STACK
;
		MVI		C, RETRY		;MAX RETRIES
		PUSH	B
WBOOT0:							;ENTER HERE ON ERROR RETRIES
		LXI		B, CPMB			;SET DMA ADDRESS TO START OF DISK SYSTEM
		CALL	SETDMA
		MVI		C, 2			;START READING SECTOR 2
		CALL	SETSEC
		MVI		C, 0			;START READING TRACK 0
		CALL	SETTRK
		MVI		C, 0			;START WITH DISK 0
		CALL	SELDSK			;CHANGES DISKN TO 0
;
								;READ SECTORS, COUNT NSECTS TO ZERO
		POP		B				;IO-ERROR COUNT
		MVI		B, NSECTS
RDSEC:							;READ NEXT SECTOR
		PUSH	B				;SAVE SECTOR COUNT
		CALL	READ
		JNZ		BOOTERR			;RETRY IF ERRORS OCCUR
		LHLD	IOD				;INCREMENT DMA ADDRESS
		LXI		D, 128			;SECTOR SIZE
		DAD		D				;INCREMENTED DMA ADDRESS IN HL
		MOV		B, H
		MOV		C, L			;READY FOR CALL TO SET DMA
		CALL	SETDMA
		LDA		IOS				;SECTOR NUMBER JUST READ
		CPI		26				;READ LAST SECTOR?
		JC		RD1
								;MUST BE SECTOR 26, ZERO AND GO TO NEXT TRACK
		LDA		IOT				;GET TRACK TO REGISTER A
		INR		A
		MOV		C, A			;READY FOR CALL
		CALL	SETTRK
		XRA		A				;CLEAR SECTOR NUMBER
RD1:	INR		A				;TO NEXT SECTOR
		MOV		C, A			;READY FOR CALL
		CALL	SETSEC
		POP		B				;RECALL SECTOR COUNT
		DCR		B				;DONE?
		JNZ		RDSEC
								;DONE WITH THE LOAD, RESET DEFAULT BUFFER ADDRESS
GOCPM:							;(ENTER HERE FROM COLD START BOOT)
								;ENABLE RST0 AND RST 7
		DI
		MVI		A, 12H			;INITIALIZE COMMAND
		OUT		REVRT
		XRA		A
		OUT		INTC			;CLEARED
		MVI		A, INTE			;RST0 AND RST7 BITS ON
		OUT		INTC
		XRA		A
		OUT		ICON			;INTERRUPT CONTROL
;
								;SET DEFAULT BUFFER ADDRESS TO 8OH
		LXI		B, BUFF
		CALL	SETDMA
;
								;RESET MONITOR ENTRY POINTS
		MVI		A, JMP
		STA		0
		LXI		H, WBOOTE
		SHLD	1				;JMP WBOOT AT LOCATION 00
		STA		5
		LXI		H, BDOS
		SHLD	6				;JMP BDOS AT LOCATION 5
		STA		7*8				;JMP TO MON60 (MAY HAVE BEEN CHANGED BY DDT)
		LXI		H, MON80
		SHLD	7*8+1
								;LEAVE IOBYTE SET
								;PREVIOUSLY SELECTED DISK WAS B, SEND PARAMETER TO CPM
		LXI		H, DISKA
		MOV		C, M			;LOOKS LIKE A SINGLE PARAMETER TO CPM
		EI
		JMP		CPMB
;
								;ERROR CONDITION OCCURRED, PRINT MESSAGE AND RETRY
BOOTERR:
		POP		B				;RECALL COUNTS
		DCR		C
		JZ		BOOTER0
								;TRY AGAIN
		PUSH	B
		JMP		WBOOT0
;
BOOTER0:
								;OTHERWISE TOO MANY RETRIES
		LXI		H, BOOTMSG
		CALL	ERROR
		JMP		WBOOT			;FOR ANOTHER TRY
;
BOOTMSG:
		DB		'CANNOT BOOT', 0
;
;
CONST:							;CONSOLE STATUS TO REG-A
								;(EXACTLY THE SAME AS MDS CALL)
		JMP		CSTS
;
CONIN:							;CONSOLE CHARACTER TO REG-A
		CALL	CI
		ANI		7FH				;REMOVE PARITY BIT
		RET
;
CONOUT:							;CONSOLE CHARACTER FROM C TO CONSOLE OUT
								;SAME AS MDS CALL, BUT WAIT FOR SLOW CONSOLES ON LINE FEED
		MOV		A, C			;GET CHARACTER TO ACCUM
		CPI		LF				;END OF LINE?
		PUSH	PSW				;SAVE CONDITION FOR LATER
		CALL	CO				;SEND THE CHARACTER (MAY BE LINE FEED)
		POP		PSW
		RNZ						;RETURN IF IT WASN'T A LINE FEED
								;
								;WAIT 13 CHARACTER TIMES (AT 2400 BAUD) FOR LINE FEED TO HAPPEN
								;(THIS WORKS OUT TO ABOUT 50 MILLISECS)
		MVI		B, 50			;NUMBER OF MILLISECS TO WAIT
T1:
		MVI		C, 182			;COUNTER TO CONTROL 1 MILLISEC LOOP
T2:
		DCR		C				;1 CYCLE = .5 USEC
		JNZ		T2				;10 CYCLES= 5.5 USEC
;                            -----------
;                             =    5.5 USEC PER LOOP* 182 = 1001 USEC
		DCR		B
		JNZ		T1				;FOR ANOTHER LOOP
		RET
;
LIST:							;LIST DEVICE OUT
								;(EXACTLY THE SAME AS MDS CALL)
		JMP		LO
;
PUNCH:							;PUNCH DEVICE OUT
								;(EXACTLY THE SAME AS MDS CALL)
		JMP		PO
;
READER:							;READER CHARACTER IN TO REG-A
								;(EXACTLY THE SAME AS MDS CALL)
		JMP		RI
;
HOME:							;MOVE TO HOME POSITION
								;TREAT AS TRACK 00 SEEK
		MVI		C, 0
		JMP		SETTRK
;
SELDSK:							;SELECT DISK GIVEN BY REGISTER C
								;CP/M HAS CHECKED FOR DISK SELECT 0 ON 1, BUT WE MAY HAVE
								;A SINGLE DRIVE MDS SYSTEM, SO CHECK AGAIN AND GIVE ERROR
								;BY CALLING MON80
		MOV		A, C
		CPI		NDISKS			;TOO LARGE?
		CNC		RMON80			;GIVES $ADDR MESSAGE AT CONSOLE
;
		RAL
		RAL
		RAL
		RAL
		ANI		10000B			;UNIT NUMBER IN POSITION
		MOV		C, A			;SAVE IT
		LXI		H, IOF			;IO FUNCTION
		MOV		A, M
		ANI		11001111B		;MASK OUT DISK NUMBER
		ORA		C				;MASK IN NEW DISK NUMBER
		MOV		M, A			; SAVE IT IN IOPB
		RET
;
;
SETTRK:							;SET TRACK ADDRESS GIVEN BY C
		LXI		H, IOT
		MOV		H, C
		RET
;
SETSEC:							;SET SECTOR NUMBER GIVEN BY C
		LXI		H, IOS
		MOV		M, C
		RET
;
SETDMA:							;SET DMA ADDRESS GIVEN BY REGS B,C
		MOV		L, C
		MOV		H, B
		SHLD	IOD
		RET
;
READ:							;READ NEXT DISK RECORD (ASSUMING DISK/TRK/SEC/DMA SET)
		MVI		C, READF		;SET TO READ FUNCTION
		CALL	SETFUNC
		CALL	WAITIO			;PERFORM READ FUNCTION
		RET						;MAY HAVE ERROR SET IN REG-A
;
;
WRITE:							;DISK WRITE FUNCTION
		MVI		C, WRITF
		CALL	SETFUNC			;SET TO WRITE FUNCTION
		CALL	WAITIO
		RET						;MAY HAVE ERROR SET
;
;
;		UTILITY SUBROUTINES
PRMSG:							;PRINT MESSAGE AT H,L TO 0
		MOV		A, M
		ORA		A				;ZERO?
		RZ
								;MORE TO PRINT
		PUSH	H
		MOV		C, A
		CALL	CONOUT
		POP		H
		INX		H
		JMP		PRMSG
;
ERROR:							;ERROR MESSAGE ADDRESSES BY H,L
		CALL	PRMSG
								;ERROR MESSAGE WRITTEN, WAIT FOR RESPONSE FROM CONSOLE
		CALL	CONIN
		MVI		C, CR			;CARRIAGE RETURN
		CALL	CONOUT
		MVI		C, LF			;LINE FEED
		CALL	CONOUT
		RET						;MAY BE RETURNING FOR ANOTHER RETRY
;
SETFUNC:
								;SET FUNCTION FOR NEXT I/O (COMMAND IN REG-C)
		LXI		N, IOF			;IO FUNCTION ADDRESS
		MOV		A, M			;GET IT TO ACCUMULATOR FOR MASKING
		ANI		11111000B		;REMOVE PREVIOUS COMMAND
		ORA		C				;SET TO NEW COMMAND
		MOV		M, A			;REPLACED IN IOPB
		RET
;
WAITIO:
		MVI		C, RETRY		;MAX RETRIES BEFORE PERM ERROR
REWAIT:
								;START THE I/O FUNCTION AND WAIT FOR COMPLETION
		IN		RTYPE
		IN		RBYTE			;CLEARS THE CONTROLLER
;
		MVI		A, IOPB AND 0FFH;LOW ADDRESS FOR IOPB
		OUT		LOW				;TO THE CONTROLLER
		MVI		A, IOPB SHR 8	;HIGH ADDRESS FOR IOPB
		OUT		HIGH			;TO THE CONTROLLER, STARTS OPERATION
;
WAIT0:
		IN		DSTAT			;WAIT FOR COMPLETION
		ANI		IOPDY			;READY?
		JZ		WAIT0
;
								;CHECK IO COMPLETION OK
		IN		RTYPE			; MUST BE I/O COMPLETE (00) UNLINKED
								;00 UNLINKED I/O COMPLETE,        01 LINKED I/O COMPLETE (NOT USED)
								;10 DISK STATUS CHANGED           11 (NOT USED)
		CPI		10B				;READY STATUS CHANGE?
		JZ		WREADY
;
								;MUST BE BO IN THE ACCUMULATOR
		ORA		A
		JNZ		WERROR			;SOME OTHER CONDITION, RETRY
;
								;CHECK I/O ERROR BITS
		IN		RBYTE
		RAL
		JC		WREADY			;UNIT NOT READY
		RAR
		ANI		11111110B		;ANY OTHER ERRORS? (DELETED DATA 0K)
		JHZ		WERROR
;
								;READ OR WRITE IS OK, ACCUMULATOR CONTAINS ZERO
		RET
;
WREADY:							;NOT READY, TREAT AS ERROR FOR NOW
		IN		RBYTE			;CLEAR RESULT BYTE
		JMP		TRYC0UNT
;
WERROR:	;RETURN HARDWARE MALFUNCTION (CRC, TRACK, SEEK, ETC.)
								;THE MDS CONTROLLER HAS RETURNED A BIT IN EACH POSITION
;		OF THE ACCUMULATOR, CORRESPONDING TO THE CONDITIONS,
;		0        - DELETED DATA (ACCEPTED AS OK ABOVE)
;		1        - CRC ERROR
;		2        - SEEK ERROR
;		3        - ADDRESS ERROR (HARDWARE MALFUNCTION)
;		4        - DATA OVER/UNDER FLOW (HARDWARE MALFUNCTION)
;		5        - WRITE PROTECT (TREATED AS NOT READY)
;		6        - WRITE ERROR (HARDWARE MALFUNCTION)
;		7        - NOT READY
;		(ACCUMULATOR BITS ARE NUMBERED 7 6 5 4 3 2 1 0)
;
;		IT MAY BE USEFUL TO FILTER OUT THE VARIOUS CONDITIONS,
;		BUT WE WILL GET A PERMANENT ERROR MESSAGE IF IT IS NOT
;		RECOVERABLE. IN ANY CASE, THE NOT READY CONDITION IS
;		TREATED AS A SEPARATE CONDITION FOR LATER IMPROVEMENT
TRYCOUNT:
;		REGISTER C CONTAINS RETRY COUNT, DECREMENT 'TIL ZERO
		DCR		C
		JNZ		REWAIT			;FOR ANOTHER TRY
;
;		CANNOT RECOVER FROM ERROR
		MVI		A, I			;ERROR CODE
		RET
;
;
;		DATA AREAS (MUST BE IN RAM)
IOPB:							;IO PARAMETER BLOCK
		DB		B0H				;NORMAL I/O OPERATION
IOF:	DB		READF			;IO FUNCTION. INITIAL READ
ION:	DB		1				;NUMBER OF SECTORS TO READ
IOT:	DB		OFFSET			;TRACK NUMBER
IOS:	DB		1				;SECTOR NUMBER
IOD:	DW		BUFF			;IO ADDRESS
;
;
		END
