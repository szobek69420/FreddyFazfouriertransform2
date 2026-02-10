[BITS 32]

section .rodata use32
	ONE dd 1.0
	PI2 dd 6.28318530718

section .text use32

	global dft_simple		;void dft_simple(vector<Complex>* outCoeffs, vector<float>* samples)
	
	extern complex_createExp
	extern complex_createGeo
	extern complex_add
	extern complex_sub
	extern complex_mul
	extern complex_copy
	
	extern vector_push_back_buffer
	extern vector_clear
	extern vector_at
	
dft_simple:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 8			;temp		8
	sub esp, 4			;current w	12
	
	mov dword[ebp-12], 0
	
	;clear outCoeffs
	push dword[ebp+20]
	call vector_clear
	
	mov eax, dword[ebp+24]
	mov ebx, dword[eax]			;max index in ebx
	xor esi, esi				;index in esi
	cmp ebx, 0
	jle dft_simple_loop_end
	dft_simple_loop_start:
		lea ecx, [ebp-8]
		push dword[ebp-12]
		push dword[ebp+24]
		push ecx
		call dft_calcCoeff_internal
		add esp, 12
		
		lea ecx, [ebp-8]
		push ecx
		push dword[ebp+20]
		call vector_push_back_buffer
		
		movss xmm0, dword[ebp-12]
		addss xmm0, dword[PI2]
		movss dword[ebp-12], xmm0
		
		inc esi
		cmp esi, ebx
		jl dft_simple_loop_start
		
	dft_simple_loop_end:
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	

;void dft_calcCoeff_internal(Complex* result, vector<float>* samples, float angularFreq)
dft_calcCoeff_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 8			;wave delta			8
	sub esp, 8			;current wave pos	16
	sub esp, 8			;current dot prod	24
	sub esp, 8			;temp				32
	
	;calculate the wave delta
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	cvtsi2ss xmm0, eax
	rcpss xmm0, xmm0
	mulss xmm0, dword[ebp+28]
	sub esp, 4
	movss dword[esp], xmm0
	push dword[ONE]
	lea eax, [ebp-8]
	push eax
	call complex_createExp
	
	;init values
	push 0
	push 0x3f800000
	lea eax, [ebp-16]
	push eax
	call complex_createGeo
	
	push 0
	push 0
	lea eax, [ebp-24]
	push eax
	call complex_createGeo
	
	;do the dot product
	mov eax, dword[ebp+24]
	mov ebx, dword[eax]			;index in ebx
	xor esi, esi				;current index in samples
	cmp ebx, 0
	jle dft_calcCoeff_internal_dot_loop_end
	dft_calcCoeff_internal_dot_loop_start:
		push esi
		push dword[ebp+24]
		call vector_at
		
		lea ecx, [ebp-16]
		lea edx, [ebp-32]
		push ecx
		push eax
		push edx
		call complex_mul
		
		lea eax, [ebp-32]
		lea ecx, [ebp-24]
		push eax
		push ecx
		push ecx
		call complex_add
		
		lea eax, [ebp-8]
		lea ecx, [ebp-16]
		push eax
		push ecx
		push ecx
		call complex_mul
		
		add esp, 44
		
		inc esi
		cmp esi, ebx
		jl dft_calcCoeff_internal_dot_loop_start
		
	dft_calcCoeff_internal_dot_loop_end:
	
	dft_calcCoeff_internal_end:
	lea eax, [ebp-24]
	push eax
	push dword[ebp+20]
	call complex_copy
	
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret