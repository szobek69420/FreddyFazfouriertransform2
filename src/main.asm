[BITS 32]

section .rodata use32
	test_text db "sus amogus",10,0

section .text use32
	
	import ExitProcess kernel32.dll
	extern ExitProcess
	
	extern my_printf
	
	..start:
		push ebp
		mov ebp, esp
	
		finit
		
		push test_text
		call my_printf
		
		mov esp, ebp
		pop ebp
		
		push 0
		call [ExitProcess]