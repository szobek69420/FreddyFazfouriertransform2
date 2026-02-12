[BITS 32]

section .rodata use32
	ONE dd 1.0
	PI2 dd 6.28318530718
	
	print_int_nl db "%d",10,0
	
	test_text db "sussy baka",10,0
	
	SIZE_OF_COMPLEX equ 8		;size of complex is assumed to be 8 regardless, this define is only for code readability

section .text use32

	global dft_simple		;void dft_simple(vector<Complex>* outCoeffs, vector<float>* samples)
	global dft_fft			;void dft_fft(vector<Complex*> outCoeffs, vector<float*> samples)
	
	extern my_printf
	extern my_malloc
	extern my_free
	
	extern complex_createExp
	extern complex_createGeo
	extern complex_add
	extern complex_sub
	extern complex_mul
	extern complex_mulScalar
	extern complex_copy
	extern complex_print
	
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
	
	sub esp, 4			;coeff array			4
	sub esp, 4			;log2(signal length)+1	8
	
	;check if the number is a zweierpotenz
	mov dword[ebp-8], 0
	
	mov eax, dword[ebp+24]
	mov ebx, dword[eax]
	test ebx, ebx
	jz dft_fft_check_power_loop_end
	dft_fft_check_power_loop_start:
		inc dword[ebp-8]
		sar ebx, 1
		jnc dft_fft_check_power_loop_continue
			test ebx, 0xffffffff
			jnz dft_fft_invalid_sample_count
		dft_fft_check_power_loop_continue:
		test ebx, ebx
		jnz dft_fft_check_power_loop_start
		
	dft_fft_check_power_loop_end:
	
	;alloc the coeff array
	mov eax, dword[ebp+24]
	mov eax, dword[eax]
	imul eax, dword[ebp-8]
	imul eax, SIZE_OF_COMPLEX
	push eax
	call my_malloc
	mov dword[ebp-4], eax
	
	;do the dft
	mov eax, dword[ebp+24]
	push dword[eax]
	push 1
	push dword[eax+12]
	mov ecx, dword[ebp+24]
	mov ecx, dword[ecx]
	imul ecx, dword[ebp-8]
	push ecx
	push dword[ebp-4]
	call dft_fft_calculateFft_internal
	
	;move the coeffs into the outBuffer
	push dword[ebp+20]
	call vector_clear
	
	mov eax, dword[ebp+24]
	mov ebx, dword[eax]			;loop end in ebx
	mov esi, dword[ebp-4]
	xor edi, edi				;index in esi
	cmp ebx, 0
	jle dft_fft_move_loop_end
	dft_fft_move_loop_start:
		lea eax, [esi+SIZE_OF_COMPLEX*edi]
		push eax
		push dword[ebp+20]
		call vector_push_back_buffer
		add esp, 8
		
		inc edi
		cmp edi, ebx
		jl dft_fft_move_loop_start
	dft_fft_move_loop_end:
		
	;dealloc the coeff array
	push dword[ebp-4]
	call my_free
	
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
	xor dword[esp], 0x80000000
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
;void dft_fft_calculateFft_internal(
;	Complex* outCoeffs,					//the space for the coefficient of this and the following smaller dfts
;	int outCoeffsLength,				//should be (log2(samplesJumpCount)+1)
;	float* samples,						//first sample should always be a considered one
;	int samplesJump,					//the difference of indices of two subsequent considered samples
;	int samplesJumpCount				//the number of considered samples in the subsignal
;)
dft_fft_calculateFft_internal:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;even coeff start				4
	sub esp, 4			;odd coeff start				8
	sub esp, 4			;coeff lengths in elements		12
	
	sub esp, 8			;delta phase					20
	sub esp, 8			;current phase					28
	
	;check if the sample count is 0 or 1
	cmp dword[ebp+36], 0
	jle dft_fft_calculateFft_internal_end
	cmp dword[ebp+36], 1
	jne dft_fft_calculateFft_internal_multiple_samples
		mov eax, dword[ebp+28]
		push 0
		push dword[eax]
		push dword[ebp+20]
		call complex_createGeo
		jmp dft_fft_calculateFft_internal_end
		
	dft_fft_calculateFft_internal_multiple_samples:
	
	
	;calculate the offsets of the subsignal dft coeffs
	;basically just halving the space in outCoeffs that is not used for this level's coefficients
	;even start: sizeof(complex)*sampleJumpCount
	;odd start: sizeof(complex)*(sampleJumpCount+(outCoeffLength-sampleJumpCount)/2)
	mov eax, dword[ebp+36]
	mov ecx, dword[ebp+24]
	sub ecx, eax
	shr ecx, 1
	mov dword[ebp-12], ecx
	add ecx, eax
	imul eax, SIZE_OF_COMPLEX
	imul ecx, SIZE_OF_COMPLEX
	add eax, dword[ebp+20]
	add ecx, dword[ebp+20]
	mov dword[ebp-4], eax
	mov dword[ebp-8], ecx
	
	;calculate the even dft
	mov eax, dword[ebp+36]
	shr eax, 1
	push eax
	mov ecx, dword[ebp+32]
	shl ecx, 1
	push ecx
	push dword[ebp+28]
	push dword[ebp-12]
	push dword[ebp-4]
	call dft_fft_calculateFft_internal
	
	;calculate the odd dft
	mov eax, dword[ebp+36]
	shr eax, 1
	push eax
	mov ecx, dword[ebp+32]
	shl ecx, 1
	push ecx
	mov eax, dword[ebp+28]
	mov ecx, dword[ebp+32]
	lea eax, [eax+4*ecx]
	push eax
	push dword[ebp-12]
	push dword[ebp-8]
	call dft_fft_calculateFft_internal
	
	
	;calculate the coefficients for this dft
	movss xmm0, dword[PI2]
	mov eax, dword[ebp+36]
	cvtsi2ss xmm1, eax
	rcpss xmm1, xmm1
	mulss xmm0, xmm1
	sub esp, 4
	movss dword[esp], xmm0
	xor dword[esp], 0x80000000
	push dword[ONE]
	lea ecx, [ebp-20]
	push ecx
	call complex_createExp
	
	lea edx, [ebp-28]
	push 0
	push 0x3f800000
	push edx
	call complex_createGeo
	
	mov esi, dword[ebp+36]
	shr esi, 1
	dec esi					;subsignal index mask in esi ([0:sampleJumpCount-1]->[0:sampleJumpCount/2-1])
	xor ebx, ebx			;index in ebx
	dft_fft_calculateFft_internal_loop_start:
		mov edi, dword[ebp+20]
		lea edi, [edi+SIZE_OF_COMPLEX*ebx]
		
		;calculate the ebx. coeff
		mov eax, ebx
		and eax, esi
		lea eax, [SIZE_OF_COMPLEX*eax]
		add eax, dword[ebp-8]
		lea ecx, [ebp-28]
		push eax
		push ecx
		push edi
		call complex_mul
		add esp, 12
		
		mov eax, ebx
		and eax, esi
		lea eax, [SIZE_OF_COMPLEX*eax]
		add eax, dword[ebp-4]
		push eax
		push edi
		push edi
		call complex_add
		add esp, 12
		
		;update the phase shifter
		lea eax, [ebp-20]
		lea ecx, [ebp-28]
		push eax
		push ecx
		push ecx
		call complex_mul
		add esp, 12
		
		inc ebx
		cmp ebx, dword[ebp+36]
		jl dft_fft_calculateFft_internal_loop_start
	
	dft_fft_calculateFft_internal_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret