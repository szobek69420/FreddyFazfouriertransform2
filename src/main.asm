[BITS 32]

section .rodata use32
	test_text db "sus amogus",10,0
	
	test_sample_vector:
	dd 16, 16, 4, test_samples
	test_samples dd 0.000, 0.049, 0.098, 0.147, 0.195, 0.243, 0.290, 0.337, 0.383, 0.428, 0.471, 0.514, 0.556, 0.596, 0.634, 0.672

section .text use32
	
	import ExitProcess kernel32.dll
	extern ExitProcess
	
	extern my_printf
	
	extern vector_init
	extern vector_for_each
	extern dft_simple
	extern dft_fft
	extern complex_print
	
	..start:
		push ebp
		mov ebp, esp
	
		finit
		
		sub esp, 16			;coeff vector		16
		
		lea eax, [ebp-16]
		push 8
		push eax
		call vector_init
		
		lea ecx, [ebp-16]
		push test_sample_vector
		push ecx
		call dft_fft
		
		lea ecx, [ebp-16]
		push 0
		push main_printCoeff_helper
		push ecx
		call vector_for_each
		jmp main_printCoeff_done
		main_printCoeff_helper:
			mov eax, dword[esp+4]
			push 69
			push eax
			call complex_print
			add esp, 8
			ret
		main_printCoeff_done:
		
		mov esp, ebp
		pop ebp
		
		push 0
		call [ExitProcess]