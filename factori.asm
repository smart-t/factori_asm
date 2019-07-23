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
cnum:			dq 00000000000000001h
;cnum:			dq 428987894557991123; 05f412371d60b871h	; 428987894557991123 in base-10

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
	mov		rdx, 2			;how many bytes to write
	syscall 					;invoke system call with the above
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
	mov 	rdx, cnum			;set value to convert
	mov 	rdi, [rdx]			;load big number (cnum)
	call 	print_dec
	call 	print_newline
	call 	print_hexprefix 	;print hex prefix
	mov 	rdx, cnum			;set value to convert
	mov 	rdi, [rdx]			;load big number (cnum)
	call 	print_hex 			;print value in haxadecimal notation
	call 	print_newline 		;print newline char

; This exit(0) construct is required for OSX
    mov		rax, 0x02000001		;system call for exit
    xor		rdi, rdi			;exit code 0
    syscall						;invoke system call to exit
