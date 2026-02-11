[BITS 32]

section .rodata use32
	ONE dd 1.0
	PI2 dd 6.28318530718

section .text use32

	global dft_simple		;void dft_simple(vector<Complex>* outCoeffs, vector<float>* samples)
	global dft_fft			;void dft_fft(vector<Complex*> outCoeffs, vector<float*> samples)
	
	extern my_printf
	
	extern complex_createExp
	extern complex_createGeo
	extern complex_add
	extern complex_sub
	extern complex_mul
	extern complex_mulScalar
	extern complex_copy
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back
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
		add esp, 8
		
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
	
dft_fft:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	;check if the number is a zweierpotenz
	mov eax, dword[ebp+24]
	mov ebx, dword[eax]
	dft_fft_check_power_loop_start:
		sar ebx, 1
		jnc dft_fft_check_power_loop_continue
			test ebx, 0xffffffff
			jnz dft_fft_invalid_sample_count
		dft_fft_check_power_loop_continue:
		test ebx, ebx
		jnz dft_fft_check_power_loop_start
		
	dft_fft_check_power_loop_end:
	
	push dword[ebp+24]
	push dword[ebp+20]
	call dft_calcCoeff_internal
	
	
	dft_fft_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret
	dft_fft_invalid_sample_count:
		mov eax, dword[ebp+24]
		push dword[eax]
		push dft_fft_invalid_sample_count_error_message
		call my_printf
		jmp dft_fft_end
		dft_fft_invalid_sample_count_error_message db "dft_fft: sample count needs to be a power of two (which %d is not)",10,0
	

;internal functinos -----------------------------------------------------

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
		push dword[eax]
		push ecx
		push edx
		call complex_mulScalar
		
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
	

;assumes that the sample count is a power of 2
;void dft_fft_calculateFft_internal(vector<Complex>* outCoeffs, vector<float>* samples)
dft_fft_calculateFft_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 16			;even samples		16
	sub esp, 16			;odd samples		32
	sub esp, 16			;even out coeffs	48
	sub esp, 16			;odd out coeffs		64
	sub esp, 4			;samples per 2		68
	sub esp, 8			;delta sus			76
	sub esp, 8			;current sus		84
	sub esp, 4			;mod helper			88
	
	;clear the out buffer
	push dword[ebp+20]
	call vector_clear
	
	;check if the samples count is 0 or 1
	mov eax, dword[ebp+20]
	test eax, eax
	jz dft_fft_calculateFft_internal_end
	
	cmp eax, 1
	jnz dft_fft_calculateFft_internal_multiple_samples
		push 0
		push dword[ebp+24]
		call vector_at
		mov ecx, esp
		push 0
		push dword[eax]
		push ecx
		call complex_createGeo
		add esp, 12
		push dword[ebp+24]
		call vector_push_back
		jmp dft_fft_calculateFft_internal_end
		
	dft_fft_calculateFft_internal_multiple_samples:
	
	;separate the samples
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	shl eax, 1
	mov dword[ebp-68], eax
	
	lea eax, [ebp-16]
	push 4
	push eax
	call vector_init
	
	lea ecx, [ebp-32]
	push 4
	push ecx
	call vector_init
	
	mov eax, dword[ebp+24]
	mov esi, dword[eax+12]
	xor edi, edi
	dft_fft_calculateFft_internal_separate_loop_start:
		lea eax, [ebp-16]
		push dword[esi+8*edi]
		push eax
		call vector_push_back
		lea eax, [ebp-32]
		push dword[esi+8*edi+4]
		push eax
		call vector_push_back
		add esp, 16
		
		inc edi
		cmp edi, dword[ebp-68]
		jl dft_fft_calculateFft_internal_separate_loop_start
		
	
	;calculate the smaller dfts
	lea eax, [ebp-16]
	lea ecx, [ebp-48]
	push eax
	push ecx
	call dft_fft_calculateFft_internal
	
	lea eax, [ebp-32]
	lea ecx, [ebp-64]
	push eax
	push ecx
	call dft_fft_calculateFft_internal
	
	;calculate the coefficients
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	cvtsi2ss xmm0, eax
	rcpss xmm0, xmm0
	mulss xmm0, dword[PI2]
	sub esp, 4
	movss dword[esp], xmm0
	xor dword[esp], 0x80000000
	push dword[ONE]
	lea ecx, [ebp-76]
	push ecx
	call complex_createExp
	
	lea edx, [ebp-84]
	push 0
	push 0
	push edx
	call complex_createGeo
	
	mov eax, dword[ebp-68]
	dec eax
	mov dword[ebp-88], eax		;a bitmask for faster modulo calculation
	
	mov eax, dword[ebp+24]
	mov ebx, dword[eax]
	xor esi, esi
	dft_fft_calculateFft_internal_coeff_loop_start:
		mov edi, esi
		and edi, dword[ebp-88]			;index in the smaller dfts
		
		sub esp, 8
		
		lea eax, [ebp-64]
		push edi
		push eax
		call vector_at
		add esp, 8
		
		mov edx, esp
		lea ecx, [ebp-84]
		push ecx
		push eax
		push edx
		call complex_mul
		add esp, 12
		
		lea eax, [ebp-48]
		push edi
		push eax
		call vector_at
		add esp, 8
		
		mov ecx, esp
		push eax
		push ecx
		push ecx
		call complex_add
		add esp, 12
		
		push dword[ebp+20]
		call vector_push_back		;complex is on the stack!!!!
		add esp, 12
		
		;update the sus
		lea eax, [ebp-76]
		lea ecx, [ebp-84]
		push eax
		push ecx
		push ecx
		call complex_mul
		add esp, 12
	
		inc esi
		cmp esi, ebx
		jl dft_fft_calculateFft_internal_coeff_loop_start
		
		
	;destroy the created vectors
	lea eax, [ebp-16]
	push eax
	call vector_destroy
	lea ecx, [ebp-32]
	push ecx
	call vector_destroy
	lea edx, [ebp-48]
	push edx
	call vector_destroy
	lea eax, [ebp-64]
	push eax
	call vector_destroy
	
	dft_fft_calculateFft_internal_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret