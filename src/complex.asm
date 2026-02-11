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
	
	print_int_nl db "%d",10,0
	print_float_nl db "%f",10,0

section .text use32

	global complex_createGeo		;void complex_createGeo(Complex*, float realPart, float imgPart)
	global complex_createExp		;void complex_createExp(Complex*, float abs, float arg)
	
	global complex_add				;void complex_add(Complex* result, Complex* a, Complex* b);
	global complex_sub				;void complex_sub(Complex* result, Complex* a, Complex* b);
	global complex_mul				;void complex_mul(Complex* result, Complex* a, Complex* b);
	global complex_div				;void complex_div(Complex* result, Complex* a, Complex* b);
	global complex_mulScalar		;void complex_mulScalar(Complex* result, Complex* a, float s)
	
	global complex_real				;float* complex_real(Complex*)
	global complex_img				;float* complex_img(Complex*)
	
	global complex_abs				;void complex_abs(Complex*, float* outAbs)
	global complex_arg				;void complex_arg(Complex*, float* outArg)
	
	global complex_copy				;void complex_copy(Complex* dst, Complex* src)
	
	global complex_print			;void complex_print(Complex*, int expForm)
	
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
	
	movq xmm2, xmm0
	mulps xmm2, xmm1
	hsubps xmm2, xmm2
	movss dword[edx], xmm2
	
	movq xmm3, xmm0
	shufps xmm3, xmm3, 0b00000001
	mulps xmm3, xmm1
	haddps xmm3, xmm3
	movss dword[edx+4], xmm3
	
	ret
	
	
complex_div:
	mov eax, dword[esp+8]
	mov ecx, dword[esp+12]
	mov edx, dword[esp+4]
	
	movq xmm0, qword[eax]
	movq xmm1, qword[ecx]
	
	movq xmm2, xmm0
	mulps xmm2, xmm1
	haddps xmm2, xmm2
	
	movq xmm3, xmm0
	shufps xmm3, xmm3, 0b00000001
	mulps xmm3, xmm1
	hsubps xmm3, xmm3
	
	mulps xmm1, xmm1
	haddps xmm1, xmm1
	rcpss xmm1, xmm1
	
	mulss xmm2, xmm1
	mulss xmm3, xmm1
	movss dword[edx], xmm2
	movss dword[edx+4], xmm3
	
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
	
	
complex_real:
	mov eax, dword[esp+4]
	ret
	
	
complex_img:
	mov eax, dword[esp+4]
	add eax, 4
	ret
	
	
complex_abs:
	mov eax, dword[esp+4]
	movq xmm0, qword[eax]
	mulps xmm0, xmm0
	haddps xmm0, xmm0
	sqrtss xmm0, xmm0
	mov ecx, dword[esp+8]
	movss dword[ecx], xmm0
	ret
	
	
complex_arg:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;result		4
	
	mov eax, dword[ebp+8]
	lea ecx, [ebp-4]
	
	fld dword[eax+4]
	fld dword[eax]
	fpatan
	fstp dword[ecx]
	mov edx, dword[eax+4]
	xor edx, dword[ecx]
	test edx, 0x80000000
	jz complex_arg_end
		test dword[eax+4], 0x80000000
		jnz complex_arg_add
			movss xmm0, dword[ecx]
			subss xmm0, dword[PI]
			movss dword[ecx], xmm0
			jmp complex_arg_end
			
		complex_arg_add:
			movss xmm0, dword[ecx]
			addss xmm0, dword[PI]
			movss dword[ecx], xmm0
			jmp complex_arg_end
	
	complex_arg_end:
	mov eax, dword[ebp-4]
	mov ecx, dword[ebp+12]
	mov dword[ecx], eax
	
	mov esp, ebp
	pop ebp
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
	
	test dword[ebp+12], 0xffffffff
	jnz complex_print_exp
	complex_print_geo:
		mov eax, dword[ebp+8]
		push dword[eax+4]
		push dword[eax]
		push complex_print_format_geo
		call my_printf
		jmp complex_print_end
	
	complex_print_exp:
		sub esp, 4
		mov eax, esp
		push eax
		push dword[ebp+8]
		call complex_arg
		add esp, 4
		mov eax, esp
		push eax
		push dword[ebp+8]
		call complex_abs
		add esp, 8
		push complex_print_format_exp
		call my_printf
		jmp complex_print_end
	
	complex_print_end:
	mov esp, ebp
	pop ebp
	ret
	complex_print_format_geo db "%f + %fj",10,0
	complex_print_format_exp db "%f * e^%fj",10,0
	
	
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