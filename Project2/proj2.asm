; proj2.asm
; Links with C standard library by default to use C input/output functions. Therefore, it will link with it's own startup
; code from the library, then call our main() function below. The standard startup code will set up the stack for us
; and take care of cleanup when done.
;
; Assemble: nasm -f elf32 -l proj2.lst proj2.asm
; Link: gcc -m32 proj2 proj2.o
;
; C standard library should be linked in by default by gcc linker
;

	extern printf   ; C printf() function from std C library
	extern fscanf   ; C fscanf() function from std C library
	extern fopen    ; C fopen() function from std C library
	extern fclose   ; C fclose() function from std C library

	section .data


	section .bss       ; Uninitialized data -- will be cleared to zero by C startup code which then calls main

FilePtr:    resb 4     ; File pointer
RunTotal:   resb 4     ; Running total of integers read
NumValues: 	resb 4     ; Integer variable (2 bytes only needed - max 1000) to store number of values in array
IntValues: 	resb 4000  ; Reserve 4000 bytes -- enough for 1000 integer (4 byte) values
                       ; Array not needed but directions explicitly state to read into an array

	section .text

FileModeStr:   db "r",0                                                  ; String for fopen() file mode (read only)
ScanFmtStr:    db "%d",0                                                 ; Format string for fscanf()
SumFmtStr:     db "Integers read = %d. Sum of integers read = %d",10,0   ; Sum output string for printf()
FileErrStr:    db "Unable to open file!",10,0                            ; File opening and file reading error statements
TooManyStr:    db "Too many values in file!  Max = 1000",10,0
NoFileNameStr: db "No file name given!",10,0
ArgErrStr:     db "No file name given!",10,0
ReadErrStr:    db "Error reading file!",10,0
TooManyErrStr: db "Too many values in file!",10,0
TooFewErrStr:  db "Warning! Unable to read all values!",10, 0

	global main	

; C equivalent for main -- int main( int argc, int *argv[] )
; argc contains the count of arguments that were on the command line, including the command itself
; argv is a pointer to an array of string pointers, one for each argument. For this program,
; argv[0] will be "prog2"
; argv[1] will be the string name of the integer data file

; On entry, the stack will have arguments pushed to it and the esp (stack pointer) register will
; be set to the return address for main.  
; The offsets are:
; argv                      [esp + 8]   - array point
; argc                      [esp + 4]   - number of arguments
; function return address   [esp]       - return address upon completion of main()

main: 
    mov     eax, [esp + 4]       ; Get argc -- number of command line arguments
    cmp     eax, 2               ; Must have at least 2 arguments (command name and file name)
    jge     GetArgV              ; Jump to next step if greater than or equal to 2
	mov     eax, ArgErrStr       
	call    PrintErr             ; Print error
    jmp     ProgEnd	
GetArgV:
    mov     esi, [esp + 8]       ; Get argv pointer (array of string pointers)
    mov     eax, [esi + 4]       ; Get argv[1] -- each pointer is 4 bytes, so index 1 is 4 bytes into array       
    call    OpenFile
	cmp     eax, 0               ; If Open file was NULL, then failure
	jne     ReadNumberCount
	mov     eax, FileErrStr 
	call    PrintErr             ; Print file error string
	jmp     ProgEnd
ReadNumberCount:
    mov     [FilePtr], eax       ; Store file pointer
                                 ; eax still contains file pointer
    mov     ebx, NumValues       ; address of NumValues variable
	call    ReadValue
	cmp     eax, -1              ; Check for end of file
	jne     CheckValues
	mov     eax, ReadErrStr
	call    PrintErr             ; Print read error string
	jmp     CloseFile
CheckValues:
    cmp     dword [NumValues], 1000  ; Compare number of file values to 1000
	jle     ReadLoopSetup
	mov     eax, TooManyErrStr
	call    PrintErr             ; Print error for too many values
	jmp     CloseFile
ReadLoopSetup:
    mov     ecx, 0               ; ecx will be our array index 
	                             ; Clear all 32 bits (ecx) even though we'll only use lower 16 bits of cx	
ReadLoop:
    mov     eax, [FilePtr]
	mov     ebx, ecx             ; Get current index
	shl     ebx, 2               ; Multiply by 4 - stame as left shift by 2 (each integer is 4 bytes)
	add     ebx, IntValues       ; address is IntValues address plus 4 * index 
	call    ReadValue
	cmp     eax, -1      
	je      PrintFinal           ; If -1 assume we're finished
Add2Sum: 
    mov     eax, dword [ebx]  
    add     dword [RunTotal], eax  ; ebx still contains address of this element
Index:
    add     ecx, 1                 ; Add one to index
    cmp     ecx, [NumValues]       ; Compare with number of values to be read
    jl      ReadLoop	           ; Jump back to read loop if less than
CheckRead:
    cmp     ecx, [NumValues]       ; Check to see how many values we actually read 
	je      PrintFinal             ; If equal, we finished successfully
	push    dword TooFewErrStr     ; We were unable to read all values
	call    printf                 ; Print notification 
	add     esp, 4
PrintFinal:
    push    dword [RunTotal]      ; Push sum argument onto stack
    push    ecx                   ; Push total number of values read onto stack (printf expects 32-bit integer even though we only used 16-bit cx)
    push    SumFmtStr	          ; Push format string onto stack
	call    printf                ; Print final sum
	add     esp, 12               ; Fixing up stack pointer
CloseFile:
    push    dword [FilePtr]
	call    fclose               ; Closing file opened
	add     esp, 4               ; Fixing up stack pointer
ProgEnd:
	ret				; main() is technically a function called from the C standard library startup code
					; so we must return from it when finished.  The startup code that called main will
					; clean up and exit
	
; OpenFile -- open the file. 
; eax must contain the pointer to the file name on entry
; eax will contain the file pointer upon exit returning
OpenFile:
    push dword FileModeStr     ; Push file mode ("r") string pointer on stack
    push eax                   ; Push file name string pointer on stack
    call fopen                 ; Call C-library fopen() function -- eax will contain 
                               ; result NULL (0) for failure, pointer to FILE if success	
	add  esp,8                 ; Fix up stack from pushed arguments
    ret                          	

; ReadValue -- read a single integer value from file
; On entry -- eax = file pointer, ebx = address to store value read
; Returns 0 in eax if successful, -1 in eax if end of file
ReadValue:
    push ecx                   ; Save ECX register
	push ebx                   ; Also save EBX register
    push ebx                   ; Push address to store result on stack
    push dword ScanFmtStr      ; Push address of fscanf() format string
    push eax                   ; Push file pointer
    call fscanf                ; Call C-library fscanf( FILE,Fmt,&storage) 
                               ; Result of fscanf() will be in eax (0 or -1)
	add  esp,12                ; Fix up stack after fscanf() argument push
	pop  ebx                   ; Restore EBX register
	pop  ecx                   ; Restore ECX register						     
    ret							   

; PrintError
; Input is pointer to error string in eax
PrintErr:
    push ecx                   ; Save ecx register so it doesn't get altered
    push eax                   ; Push string pointer on stack for printf()
	call printf                ; Call printf
	add  esp,4                 ; Fix stack from eax push
	pop  ecx                   ; Restore ecx register
	ret


             


 	

