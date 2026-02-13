[BITS 32]

section .rodata use32
	HALF dd 0.5
	ONE dd 1.0
	PI dd 3.14159265358
	PI2 dd 6.28318530718

section .text use32

	;if the sample count is even:
		;the hann window function is assumed to be sampleCount+1 "long"
		;so that each sample is Hann(sampleIndex+0.5)
	;if the sample count is odd:
		;the hann window function is assumed to be sampleCount+2 "long"
		;so that each sample is Hann(sampleIndex+1)
	;this ensures that the sum in the case of a 50% (in this case floor(sampleCount/2)) overlap will always be one for the window
	;void filter_createHann(int sampleCount, float* sampleBuffer)
	global filter_createHann


filter_createHann:
	push ebp
	push esi
	push edi
	push ebx
	mov ebp, esp
	
	sub esp, 4			;delta sample pos		4
	sub esp, 4			;current sample pos		8
	
	;check if the sampleCount is chill
	cmp dword[ebp+20], 0
	jle filter_createHann_end
	
	;calculate the delta and start sample pos
	test dword[ebp+20], 0x00000001
	jnz filter_createHann_calcDelta_odd
	
	filter_createHann_calcDelta_even:
		movss xmm0, dword[PI2]
		mov eax, dword[ebp+20]
		inc eax
		cvtsi2ss xmm1, eax
		divss xmm0, xmm1
		movss dword[ebp-4], xmm0
		
		mulss xmm0, dword[HALF]
		movss dword[ebp-8], xmm0
		jmp filter_createHann_calcDelta_done
		
	filter_createHann_calcDelta_odd:
		movss xmm0, dword[PI2]
		mov eax, dword[ebp+20]
		add eax, 2
		cvtsi2ss xmm1, eax
		divss xmm0, xmm1
		movss dword[ebp-4], xmm0
		
		movss dword[ebp-8], xmm0
		jmp filter_createHann_calcDelta_done
	
	filter_createHann_calcDelta_done:
	
	
	;sample the hann function
	;NOTE: 0.5*(1-cos(2*pi*x/N)) = sin^2(pi*x/N)
	
	mov esi, dword[ebp+24]		;current element in buffer
	mov edi, dword[ebp+20]		;index in edi
	movss xmm0, dword[ebp-4]	;delta in xmm0
	filter_createHann_sampleSin_loop_start:
		fld dword[ebp-8]
		fsin
		fstp dword[esi]
		
		movss xmm1, dword[ebp-8]
		addss xmm1, xmm0
		movss dword[ebp-8], xmm1
		
		add esi, 4
		dec edi
		jnz filter_createHann_sampleSin_loop_start
		
	mov esi, dword[ebp+24]	;current element in buffer in esi
	mov edi, dword[ebp+20]
	shr edi, 2				;index in edi
	test edi, edi
	jz filter_createHann_sampleSquare4_loop_end
	filter_createHann_sampleSquare4_loop_start:
		movups xmm0, [esi]
		mulps xmm0, xmm0
		movups [esi], xmm0
		
		add esi, 16
		dec edi
		jnz filter_createHann_sampleSquare4_loop_start
	filter_createHann_sampleSquare4_loop_end:
	
	mov edi, dword[ebp+20]
	and edi, 0b11			;index in edi
	mov esi, dword[ebp+20]
	sub esi, edi
	shl esi, 2
	add esi, dword[ebp+24]	;current element in buffer in esi
	test edi, edi
	jz filter_createHann_sampleSquare1_loop_end
	filter_createHann_sampleSquare1_loop_start:
		movss xmm0, dword[esi]
		mulss xmm0, xmm0
		movss dword[esi], xmm0
		
		add esi, 4
		dec edi
		jnz filter_createHann_sampleSquare1_loop_start
	filter_createHann_sampleSquare1_loop_end:
	

	filter_createHann_end:
	mov esp, ebp
	pop ebx
	pop edi
	pop esi
	pop ebp
	ret