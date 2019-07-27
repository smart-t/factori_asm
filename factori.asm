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
cnum:			dq 428987894557991123	; 05f412371d60b871h / this is the big number
									 	; the number that we would like to split in
									 	; factors
x:				dq 0					; the product anum * bnum, temp interim result
remainder: 		dq 0					; remainder of cnum - x
anum:			dd 0					; one of the factors that we found
bnum: 			dd 0					; the other factor, when remainder is 0

half: 			dq 0.5					; just a fixed value 0.5, needed for floor func

cnumstr:		db 'cnum      = ', 0
.len			equ $-cnumstr

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

;; print cnum as hexadecimal number
;	call 	print_hexprefix 	;print hex prefix
;	mov 	rdx, cnum			;set value to convert
;	mov 	rdi, [rdx]			;load big number (cnum)
;	call 	print_hex 			;print value in haxadecimal notation
;	call 	print_newline 		;print newline char

; print cnum as a decimal number
	mov 	rsi, cnumstr 		;load address of cnumstr in sdi
	mov 	rdx, cnumstr.len 	;load len of cnumstr in edx
	call 	print_string 		;print cnumstr
	mov 	rdx, cnum 			;prepare to print cnum and a decimal
	mov 	rdi, [rdx]			;load the value in rdi our parameter to print_dec
	call 	print_dec 			;print cnum as a decimal value
	call 	print_newline 		;print newline char

; print remainder as decimal number
	mov 	rsi, remainderstr	;load address of cnumstr in sdi
	mov 	rdx, remainderstr.len 	;load len of cnumstr in edx
	call 	print_string 		;print cnumstr
	mov 	rdx, remainder 		;prepare storing the remainder
	fistp 	qword[rdx] 			;store the remainder as a 64bit integer value
	mov 	rdi, [rdx] 			;move remainder in rdi, such that we can print it
	call 	print_dec 			;print rdi in decimals
	call 	print_newline 		;print newline char

; This exit(0) construct is required for OSX
    mov		rax, 0x02000001		;system call for exit
    xor		rdi, rdi			;exit code 0
    syscall						;invoke system call to exit
