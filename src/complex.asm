[BITS 32]

;struct Complex{
;	float32 real, img;
;}	8 bytes

section .rodata use32
	PI			dd 3.14159265359
	PI2			dd 6.28318530718
	
	ONE_PER_2PI	dd 0.159154943091
	
	SIN_COEFFS:
	dd 1.0
	dd -0.166666666667
	dd 0.008333333333
	dd -0.000198412698
	
	COS_COEFFS:
	dd 1.0
	dd -0.5
	dd 0.041666666667
	dd -0.001388888889

section .text use32

	global complex_createGeo		;void complex_createGeo(Complex*, float realPart, float imgPart)
	global complex_createExp		;void complex_createExp(Complex*, float abs, float arg)
	
	global complex_add				;void complex_add(Complex* result, Complex* a, Complex* b);
	global complex_sub				;void complex_sub(Complex* result, Complex* a, Complex* b);
	global complex_mul				;void complex_mul(Complex* result, Complex* a, Complex* b);
	global complex_div				;void complex_div(Complex* result, Complex* a, Complex* b);
	global complex_mulScalar		;void complex_mulScalar(Complex* result, Complex* a, float s)
	
	global complex_copy				;void complex_copy(Complex* dst, Complex* src)
	
	global complex_print			;void complex_print(Complex*)
	
	extern my_printf
	
complex_createGeo:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov edx, dword[esp+12]
	mov dword[eax], ecx
	mov dword[eax+4], edx
	ret
	
	
complex_createExp:
	push ebp
	mov ebp, esp
	
	fld dword[ebp+16]
	fsincos
	mov eax, dword[ebp+8]
	fstp dword[eax]
	fstp dword[eax+4]
	movss xmm0, dword[eax]
	mulss xmm0, dword[ebp+12]
	movss dword[eax], xmm0
	movss xmm1, dword[eax+4]
	mulss xmm1, dword[ebp+12]
	movss dword[eax+4], xmm1
	
	mov esp, ebp
	pop ebp
	ret
	
	
complex_add:
	mov eax, dword[esp+8]
	mov ecx, dword[esp+12]
	mov edx, dword[esp+4]
	
	movq xmm0, qword[eax]
	movq xmm1, qword[ecx]
	addps xmm0, xmm1
	movq qword[edx], xmm0
	
	ret
	
	
complex_sub:
	mov eax, dword[esp+8]
	mov ecx, dword[esp+12]
	mov edx, dword[esp+4]
	
	movq xmm0, qword[eax]
	movq xmm1, qword[ecx]
	subps xmm0, xmm1
	movq qword[edx], xmm0
	
	ret
	
	
complex_mul:
	mov eax, dword[esp+8]
	mov ecx, dword[esp+12]
	mov edx, dword[esp+4]
	
	movq xmm0, qword[eax]
	movq xmm1, qword[ecx]
	mulps xmm0, xmm1
	hsubps xmm0, xmm2
	movss dword[edx], xmm0
	
	movss xmm3, dword[eax]
	mulss xmm3, dword[ecx+4]
	movss xmm4, dword[ecx]
	mulss xmm4, dword[eax+4]
	addss xmm3, xmm4
	movss dword[edx+4], xmm3
	
	ret
	
	
complex_div:
	mov eax, dword[esp+8]
	mov ecx, dword[esp+12]
	mov edx, dword[esp+4]
	
	movq xmm0, qword[ecx]
	
	movq xmm1, xmm0
	haddps xmm1, xmm1
	mulss xmm1, dword[eax]
	
	movss xmm2, dword[eax+4]
	mulss xmm2, dword[ecx]
	movss xmm3, dword[eax]
	mulss xmm3, dword[ecx+4]
	subss xmm2, xmm3
	
	movq xmm4, xmm0
	mulps xmm4, xmm4
	haddps xmm4, xmm4
	rcpss xmm4, xmm4
	
	mulss xmm1, xmm4
	mulss xmm2, xmm4
	
	movss dword[edx], xmm1
	movss dword[edx+4], xmm2
	
	ret
	
complex_mulScalar:
	mov eax, dword[esp+8]
	movq xmm0, qword[eax]
	movss xmm1, dword[esp+12]
	shufps xmm1, xmm1, 0
	mulps xmm0, xmm1
	mov ecx, dword[esp+4]
	movq qword[ecx], xmm0
	ret
	
	
complex_copy:
	mov eax, dword[esp+4]
	mov ecx, dword[esp+8]
	mov edx, dword[ecx]
	mov dword[eax], edx
	mov edx, dword[ecx+4]
	mov dword[eax+4], edx
	ret
	
	
complex_print:
	push ebp
	mov ebp, esp
	
	mov eax, dword[ebp+8]
	push dword[eax+4]
	push dword[eax]
	push complex_print_format
	call my_printf
	
	mov esp, ebp
	pop ebp
	ret
	complex_print_format db "%f + %fj",10,0
	
	
;void complex_calcSin(float* buffer, float num)
complex_calcSin_internal:
	sub esp, 16				;helper

	;num: (-inf, inf) -> [-pi, pi)
	movss xmm0, dword[esp+24]
	movss xmm1, xmm0
	addss xmm1, dword[PI]
	mulss xmm1, dword[ONE_PER_2PI]
	roundss xmm1, xmm1, 0b0001
	mulss xmm1, dword[PI2]
	subss xmm0, xmm1
	
	;calculate taylor series
	movss xmm1, xmm0
	movss xmm2, xmm0
	mulss xmm2, xmm2
	
	movss dword[esp], xmm1
	mulss xmm1, xmm2
	movss dword[esp+4], xmm1
	mulss xmm1, xmm2
	movss dword[esp+8], xmm1
	mulss xmm1, xmm2
	movss dword[esp+12], xmm1
	
	movups xmm1, [esp]
	mulps xmm1, [SIN_COEFFS]
	haddps xmm1, xmm1
	haddps xmm1, xmm1
	mov eax, dword[esp+20]
	movss dword[eax], xmm1
	
	ret