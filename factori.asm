; The Assembly Intel OSX implementation. This demonstrates the speed of
; assembly in comparisson to the C and Python variants.
;
; Note that system call numbers are different in OSX. Also you need to
; explicitly exit with exit code 0 to declare success.
;
; Build the OSX executable using the following commands:
; 
; $ nasm -fmacho64 -g -O0 factori.asm -o factori.o
; $ ld -macosx_version_min 10.8.0 -o factori factori.o -lSystem
;
; Debug and show symbols using the following commands:
;
; $ dsymutil -dump-debug-map factori
; $ otool -t factori
;
; $ lldb commands (start with sudo lldb factori)
; (gdb) b interate   	// sets breakpoint at iterate
; (gdb) r				// runs until breakpoint
; (gdb) register read 	// reads all registers
; (gdb) si				// single step through asm code
; (gdb) memory read --size 4 --format x --count 40 0x0000000000001f95 // dump mem
; (gdb) memory read --size 1 --format c --count 17 0x0000000000002003 // print string
; (gdb) image dump symtab factori // show all symbols in factori
; (gdb) settings set target.x86-disassembly-flavor intel // intel style
; (gdb) quit			// leave gdb

global _main					;our program starts at _main

section .data
newline_char:	db 10
hex_prefix:		db '0x'
hex_codes:		db '0123456789abcdef'
dec_codes:		db '0123456789'
cnum:			dq 428987894557991123	;05f412371d60b871h / this is the big number
									 	;the number that we would like to split in
									 	;factors
x:				dq 0					;the product anum * bnum, temp interim result
jump:			dq 2					;jump to be subtracted from anum in each iter.

remainder: 		dq 0					; remainder of cnum - x
anum:			dd 0					; one of the factors that we found
anumext: 		dd 0
bnum: 			dd 0					; the other factor, when remainder is 0

half: 			dq 0.5					; just a fixed value 0.5, needed for floor func

cnumstr:		db 'cnum      = ', 0
.len			equ $-cnumstr

anumstr:		db 'anum      = ', 0
.len			equ $-anumstr

bnumstr:		db 'bnum      = ', 0
.len			equ $-bnumstr

xstr:			db 'x         = ', 0
.len			equ $-xstr

remainderstr:	db 'remainder = ', 0
.len			equ $-remainderstr

section .text

; Function to print newline character
print_newline:
	mov		rax, 0x02000004		;system call number 1, write
	mov		rdi, 1				;where to write, 1 = stdout
	mov 	rsi, newline_char 	;newline char
	mov		rdx, 1				;how many bytes to write
	syscall 					;invoke system call with the above
	ret

; Function to print hex prefix 0x
print_hexprefix:
	mov		rax, 0x02000004		;system call number 1, write
	mov		rdi, 1				;where to write, 1 = stdout
	mov 	rsi, hex_prefix		;hex prefix chars
	mov		rdx, 2				;how many bytes to write
	syscall 					;invoke system call with the above
	ret

; Function to print string
print_string:
	mov 	rax, 0x02000004		;system call number 1, write
	mov		rdi, 1				;where to write, 1 = stdout
	syscall 					; invoke system call with the above
	ret

; Funcion to print number in haxadecimal notation
print_hex:
	mov 	rax, rdi			;read parameter (value) in rax
	mov 	rcx, 64				;how far are we shifting
.iterate:
	push 	rax					;save initial rax
	sub 	rcx, 4				;select first number of bits to shift (4)
	sar 	rax, cl				;shift to 60, 56, 52, ..., 4, 0
								;the cl register is the smallest part
								;of rcx
	and 	rax, 0fh			;clear all bits but the lowest 4
	mov 	rdx, hex_codes
	lea 	rsi, [rdx + rax]	;select hex sign that matches the 4 bits
	mov		rax, 0x02000004		;system call number 1, write
	mov 	rdi, 1				;where to write, 1 = stdout
	mov 	rdx, 1				;how many bytes to write
	push 	rcx					;syscall will break rcx
	syscall 					;invoke system call with the above
	pop 	rcx					;recover rcx value
	pop 	rax					;recover rax value
	test 	rcx, rcx			;rcx==0 when all digits processed
	jnz 	.iterate			;repeat until done (rcx==0)
	ret 						;return to caller

print_dec:
	mov 	rax, rdi			;read parameter (value) in rax
	xor 	r8, r8				;clear r8 (r8 is to remmber how much items on stack)
	cmp 	rax, 10				;if rax is smaller than ten, then just print rax
	jge 	.div10 				;if greater or equal continue finding 0's
	push 	rax 				;save rax, prepare for printing
	inc 	r8 					;tell that there is just one digit
	jmp 	.print_digit 		;jump straight to printing rax
.div10:
	xor 	rdx, rdx			;clear rdx register
	mov 	rbx, 10				;set divider to 10
	div 	rbx					;divide rax by 10
	push 	rdx					;save rax on stack
	inc 	r8					;increase number of elements on the stack
	cmp 	rax, 10				;if less than 10 left in rax, stop look
	jge 	.div10 				;if greater continue
	push 	rax					;last digit is in rax
	inc 	r8					;increase number of elements on the stack
.print_digit:
	pop 	rax					;pop rax from stack, ready to print
	mov 	rdx, dec_codes 		;lookup right digit
	lea 	rsi, [rdx + rax]	;select dec digit that matches the 4 bits
	mov		rax, 0x02000004		;system call number 1, write
	mov 	rdi, 1				;where to write, 1 = stdout
	mov 	rdx, 1				;how many bytes to write
	syscall 					;invoke system call with the above
	dec 	r8					;update number of stack waiting to be processed
	test 	r8, r8				;test r8 for 0
	jnz 	.print_digit 		;as long not 0 there are elements on the stack
	ret 						;return to caller

_main:
	mov 	rdx, cnum 
	fild 	qword[rdx]			;push integer as double float in st(0)
	fsqrt 						;calculate the square root
	mov 	rdx, half			;prepare load of 0.5 as double float
	fsub 	qword[rdx]			;substract 0.5 from the sqrt result
	frndint 					;then round to nearest integer
	mov 	rdx, anum 			;prepare to store integer value in anum
	fistp 	qword[rdx]			;store and pop st(0) from the stack in anum
	mov 	rdi, qword[rdx]		;move result in rdi
	shr 	rdi, 1 				;shift 1 to right
	jc 		odd 				;if carry flag set, least significant bit was 1, odd
	shl 	rdi, 1				;rotate 1 bit back to the left
	dec 	rdi					;subtract 1 when number was even
	mov 	rdx, anum 			;load address of anum in rdx
	mov 	[rdx], rdi 			;copy rdi in anum
	jmp 	print_anum 			;goto print numbers
odd:
	shl 	rdi, 1 				;rotate 1 bit back to the left when number was odd
print_anum:
	mov 	rdx, bnum 			;load address of bnum in rdx
	mov 	[rdx], rdi 			;copy rdi in bnum, should be the same as anum
	fild 	dword[rdx]			;load bnum as a double integer
	mov 	rdx, anum 			;prepare anum for loading
	fild 	dword[rdx] 			;load anum as a double integer
	mov 	rdx, x 				;prepare the result, x = anum * bnum
	fmul 						;perform anum * bnum
	fistp 	qword[rdx]			;store the result as a 64bit integer in x
	mov 	rdx, cnum 			;prepare cnum for loading
	fild 	qword[rdx] 			;load cnum and an 64bit integer (qword)
	mov 	rdx, x 				;prepare x (anum * bnum) for loading
	fild 	qword[rdx] 			;load x as a 64bit integer
	fsub 						;perform floating point subtraction [ToDo could be integer]
	mov 	rdx, remainder 		;prepare to store result in remainder (memory)
	fistp 	qword[rdx]			;store remainder in memory

; print cnum as a decimal number
	mov 	rsi, cnumstr 		;load address of cnumstr in rsi
	mov 	rdx, cnumstr.len 	;load len of cnumstr in rdx
	call 	print_string 		;print cnumstr
	mov 	rdx, cnum 			;prepare to print cnum and a decimal
	mov 	rdi, qword[rdx]		;load the value in rdi our parameter to print_dec
	call 	print_dec 			;print cnum as a decimal value
	call 	print_newline 		;print newline char

; start of loop to find the first factor of cnum
next:
	xor 	rdx, rdx			;make sure rdx is 0
	mov 	rdx, bnum 			;prepare bnum for calculations, must be in register
	mov 	rax, qword[rdx]		;load bnum in rax
	shl 	rax, 1				;shift rax 1bit to right (multiply by 2)
	mov 	rdx, remainder 		;prepare remainder for calculation, must be in register
	add 	rax, qword[rdx] 	;add remainder to bnum * jump
	mov 	rdx, remainder 		;prepare remainder to capture result in memory
	mov 	qword[rdx], rax 	;store the result in remainder (memory)

; adjust anum by subtracting jump (=2)
	mov 	rdx, anum 			;prepare anum for adjustment with jump
	fild 	dword[rdx] 			;load anum and convert to double float
	mov 	rdx, jump 			;prepare jump for adjustment
	fild 	qword[rdx] 			;load jump and convert to double float
	fsub 						;subtract jump from anum
 	mov 	rdx, anum 			;prepare anum to store result in memory
	fistp 	qword[rdx] 			;store adjusted anum in anum memory

; simple integer division, dividing rax (remainder) by rbx (anum))
	mov 	rdx, remainder 		;prepare remainder for loading in rax
	mov 	rax, qword[rdx] 	;load remainder in rax as qword
	mov 	rdx, anum 			;prepare anum for loading in rbx
	mov 	rbx, qword[rdx] 	;load anum in rbx
	xor 	rdx, rdx  			;make sure the rdx register is 0
	idiv 	rbx 				;perform division (rax=remainder / rbx=anum)
	mov 	rbx, x 				;prepare x for storing the remainder (rdx)
	mov 	qword[rbx], rdx 	;store remainder of division in x (memory)
	test 	rdx, rdx 			;test to see if division remainder was 0
	jnz 	next 				;if not the case, jump to start of loop

; calculate bnum
	mov 	rdx, cnum 			;prepare cnum for loading in rax
	mov 	rax, qword[rdx]		;load cnum in rax
	mov 	rdx, anum 			;prepare anum for loading in rbx
	mov 	rbx, qword[rdx] 	;load anum in rbx
	xor 	rdx, rdx			;make sure the rdx register is 0
	idiv 	rbx 				;perform division (rax=cnum / rbx=anum)
	mov 	rdx, bnum 			;prepare bnum for storing the result
	mov 	qword[rdx], rax

; print anum as decimal number
	mov 	rsi, anumstr		;load address of anumstr in sdi
	mov 	rdx, anumstr.len 	;load len of anumstr in edx
	call 	print_string 		;print anumstr
	mov 	rdx, anum 			;prepare storing the anum
	mov 	rdi, qword[rdx] 	;move anum in rdi, such that we can print it
	call 	print_dec 			;print rdi in decimals
	call 	print_newline 		;print newline char

; print bnum as decimal number
	mov 	rsi, bnumstr		;load address of bnumstr in sdi
	mov 	rdx, bnumstr.len 	;load len of bnumstr in edx
	call 	print_string 		;print bnumstr
	mov 	rdx, bnum 			;prepare storing the bnum
	mov 	rdi, qword[rdx] 	;move bnum in rdi, such that we can print it
	call 	print_dec 			;print rdi in decimals
	call 	print_newline 		;print newline char

; This exit(0) construct is required for OSX
    mov		rax, 0x02000001		;system call for exit
    xor		rdi, rdi			;exit code 0
    syscall						;invoke system call to exit
