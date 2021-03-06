;		MDS LOADER MOVE PROGRAM, PLACES COLD START BOOT AT BOOTB
;
		ORG		3000H			;WE ARE LOADED HERE ON COLD START
		BOOTB	EQU 80H			;START OF COLD BOOT PROGRAM
		BOOTL	EQU 80H			;LENGTH OF BOOT
		MBIAS	EQU 900H-$		;BIAS TO ADD DURING LOAD
		BASE	EQU 078H		;'BASE' USED BY DISK CONTROLLER
		RTYPE	EQU BASE+1		;RESULT TYPE
		RBYTE	EQU BASE+3		;RESULT TYPE
;
		BSW		EQU BFFH		;BOOT SWITCH
;
								;CLEAR DISK STATUS
		IN		RTYPE
		IN		RBYTE

;
COLDSTART:
		IN		BSW
		ANI		2H				;SWITCH ON?
		JNZ		COLDSTART
;
		LXI		H, BOOTV		;VIRTUAL BASE
		MVI		B, BOOTL		;LENGTH OF BOOT
		LXI		D, BOOTB		;DESTINATION OF BOOT
MOVE:
		MOV		A, M
		STAX	D				;TRANSFERRED ONE BYTE
		INX		H
		INX		D
		DCR		B
		JNZ		MOVE
		JMP		BOOTB			;TO BOOT SYSTEM
;
BOOTV:							;BOOT LOADER PLACE HERE AT SYSTEM GENERATION
		LBIAS	EQU $-80H+MBIAS	;COLD START BOOT BEGINS AT 80H
		END

								;MBS COLD START LOADER FOR CP/M
		BIAS	EQU 800H		;BIAS FOR RELOCATION
		FALSE	EQU 0
		TRUE	EQU NOT FALSE
		TESTING	EQU FALSE		;IF TRUE, THEN GO TO MON80 ON ERRORS
;
		BDOSB	EQU BIAS		;BASE OF DOS LOAD
		BDOS	EQU 906H+BIAS	;ENTRY TO DOS FOR CALLS
		BDOSE	EQU 1700H+BIAS	;END OF DOS LOAD
		BOOT	EQU 1500H+BIAS	;COLD START ENTRY POINT
		RBOOT	EQU BOOT+3		;WARM START ENTRY POINT
;
		ORG		80H				;LOADED DOWN FROM HARDWARE BOOT AT 3000H
;
		BDOSL	EQU BDOSE-BDOSB
		NTRKS	EQU 2			;NUMBER OF TRACKS TO READ
		BDOSS	EQU BD0SL/I28	;NUMBER OF SECTORS IN DOS
		BDOS0	EQU 25			;NUMBER OF BDOS SECTORS ON TRACK 0
		BDOS1	EQU BDOSS-BDOS0	;NUMBER OF SECTORS ON TRACK 1

		MON80	EQU BF800H		;INTEL MONITOR BASE
		RMON80	EQU 0FF0FH		;RESTART LOCATION FOR MON80
		BASE	EQU 078H		;'BASE' USED BY CONTROLLER
		RTYPE	EQU BASE+1		;RESULT TYPE
		RBYTE	EQU BASE+3		;RESULT BYTE
		RESET	EQU BASE+7		;RESET CONTROLLER
;
		DSTAT	EQU BASE		;DISK STATUS PORT
		LOW		EQU BASE+1		;LOW IOPB ADDRESS
		HIGH	EQU BASE+2		;HIGH IOPB ADDRESS
		RECAL	EQU 3H			;PFCALIBRATE SELECTED DRIVE
		READF	EQU 4H			;DISK READ FUNCTION
		STACK	EQU 100H		;USE END OF BOOT FOR STACK
;
RSTART:
		LXI		SP, STACK		;IN CASE OF CALL TO MON80
								;CLEAR THE CONTROLLER
		OUT		RESET			;L0GIC CLEARED
;
;
		MVI		B, NTRKS		;NUMBER OF TRACKS TO READ
		LXI		H, IOPB0
;
START:
;
								;READ FIRST/NEXT TPACK INTO BDOSB
		MOV		A, L
		OUT		LOW
		MOV		A, H
		OUT		HIGH
WAIT0:	IN		DSTAT
		ANI		4
		JZ		WAIT0
;
								;CHECK DISK STATUS
		IN		RTYPE
		ANI     11B
		CPI		2
;
		IF		TESTING
		CNC		RMON80			;GO TO MONITOR IF 11 OR 10
		ENDIF
		IF		NOT TESTING
		JNC		RSTART			;RETRY THE LOAD
		ENDIF
;
		IN		RBYTE			;I/O COMPLETE, CHECK STATUS
								;IF NOT READY, THEN GO TO MON80
		RAL
		CC		RMON80			;NOT READY BIT SET
		RAR						;RESTORE
		ANI		11110B			;OVERRUN/ADDR ERR/SEEK/CRC/XXXX
;
		IF		TESTING
		CNZ		RMON80			;GO TO MONITOR
		ENDIF
		IF		NOT TESTING
		JNZ		RSTART			;RETRY THE LOAD
		ENDIF
;
;
		LXI		D, IOPBL		;LENGTH OF IOPB
		DAD		D				;ADDRESSING NEXT IOPB
		DCR		8				;COUNT DOWN TRACKS
		JNZ		START
;
;
								;JMP TO BOOT TO PRINT INITIAL MESSAGE, AND SET UP JMPS
		JMP		BOOT
;
;		PARAMETER BLOCKS
IOPB0:	DB		80H				;IOCW, NO UPDATE
		DB		READF			;READ FUNCTION
		DB		BDOS0			;0 SECTORS TO READ 0N TRACK 0
		DB		0				;TRACK 0
		DB		2				;START WITH SECTOR 2 ON TRACK 0
		DW		BDOSB			;START AT BASE OF BDOS
		IOPBL	EQU $-IOPB0
;
IOPB1:	DB		80H
		DB		READF
		DB		BDOS1			;SECTORS TO READ ON TRACK 1
		DB		1				;TRACK 1
		DB		1				;SECTOR 1
		DW		BDOSB+BDOS0=l28	;BASE OF SECOND READ

		END
