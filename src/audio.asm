[BITS 32]

;struct WaveHeader{
;	char chunkId[4];			;0	//should be "RIFF"
;	uint32 chunkSize;			;4	//file size - 8
;	char fileType[4];			;8	//should be "WAVE"
;	char formatChunkMarker[4];	;12	//should be "fmt "
;	uint32 formatChunkSize;		;16
;	uint16 audioFormat;			;20	//1 is PCM
;	uint16 numberOfChannels;	;22
;	uint32 sampleRate;			;24
;	uint32 byteRate;			;28
;	uint16 bytesPerSampleFrame;	;32 //(blockAlign)
;	uint16 bitsPerSample;		;34
;}	36 bytes overall

;struct WAVEFORMATEX{
;	uint16 wFormatTag;			;0
;	uint16 nChannels;			;2
;	uint32 nSamplesPerSec;		;4
;	uint32 nAvgBytesPerSec;		;8
;	uint16 nBlockAlign;			;12
;	uint16 wBitsPerSample;		;14
;	uint16 cbSize;				;16
;}	18 bytes overall

;struct WAVEHDR {
;	char* lpData;				;0
;	int dwBufferLength;			;4
;	int dwBytesRecorded;		;8
;	int* dwUser;				;12
;	int dwFlags;				;16
;	int dwLoops;				;20
;	wavehdr_tag* lpNext;		;24
;	int* reserved;				;28
;} 	32 bytes overall; only lpData, dwBufferLength, dwFlags and dwLoops are important for us

;struct Sound{
;	int dataSizeInBytes;			;0
;	char* data;						;4
;	WAVEFORMATEX* formatDescriptor;	;8
;	char* filePath;					;12
;	int id;							;16		//for internal use
;	int sampleCount;				;20		//sampleCount as in dataSizeInBytes/system_waveformatex->nBlockAlign
;	int importCount;				;24
;}	28 bytes overall

;struct Playback{
;	int id;							;0
;	Sound* sound;					;4
;	int loopsLeft;					;8
;	int currentPosition;			;12	as in nBlockAlign
;	int priority;					;16
;}	20 bytes overall

;struct PlaybackCommand{
;	enum{ PLAY=0, STOP=69, UNLOAD=420 } commandType;
;
;	union{
;		struct PlayCommand{ int soundId; int loopCount; int playbackId; int priority; } playCommand;
;		struct StopCommand{ int playbackId; } stopCommand;
;		struct UnloadCommand{ int soundId; } unloadCommand;
;	}
;}	20 bytes overall

%macro dll_import 2
	import %2 %1
	extern %2
%endmacro

section .rodata use32

	;the maximum number of prepared blocks waiting to play
	;if this is changed, the helpers for the main loop might need to be changed as well
	MAX_PREPARED_BLOCKS dd 5
	BLOCK_LENGTH dd 1000			;number of samples per prepared block
	MAX_PLAYBACK_COUNT dd 5			;max number of playbacks
	VOLUME_SCALER dd 0.2			;1/MAX_PLAYBACK_COUNT
	
	PLAYBACK_COMMAND_PLAY equ 0
	PLAYBACK_COMMAND_STOP equ 69
	PLAYBACK_COMMAND_UNLOAD equ 420
	

	MMSYSERR_NOERROR dd 0

	WAVE_MAPPER dd 0xffffffff
	
	CALLBACK_FUNCTION dd 0x00030000
	WAVE_MAPPED_DEFAULT_COMMUNICATION_DEVICE dd 0x0010
	
	WHDR_BEGINLOOP dd 0x00000004
	WHDR_ENDLOOP dd 0x00000008
	WHDR_DONE dd 0x00000001
	
	WOM_OPEN dd 0x3bb
	WOM_CLOSE dd 0x3bc
	WOM_DONE dd 0x3bd
	
	WAVE_FORMAT_PCM dw 1
	
	file_open_mode db "r",0
	
	based_chunk_id db "RIFF"
	based_file_type db "WAVE"
	based_format_marker db "fmt "
	
	data_chunk_id db "data"

	error_read_failure db "audio_readWaveHeader: couldn't read the file %s",10,0
	error_invalid_chunk_id db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid chunk ID",10,0
	error_invalid_file_type db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid file type",10,0
	error_invalid_format_chunk_marker db "audio_readWaveHeader: couldn't read wave header of %s due to missing format chunk marker",10,0
	error_device_could_not_be_created db "audio_loadSound: audio device could not be created",10,0
	error_header_could_not_be_prepared db "audio_playSound: block header couldn't be prepared",10,0
	error_data_could_not_be_written db "audio_playSound: data couldn't be written to device",10,0

	print_int_nl db "%d",10,0
	print_two_ints_nl db "%d %d",10,0
	print_four_ints_nl db "%d %d %d %d",10,0
	print_seven_ints_nl db "%d %d %d %d %d %d %d",10,0
	print_string_nl db "%s",10,0
	
	test_text db "freaky golem",10,0
	test_text2 db "cheeky golem",10,0
	
	ZERO dd 0
	ONE dd 1.0
	
	;helpers for mixin
	SCALER_8BIT dd 0.0078125
	SCALER_16BIT dd 0.000030517578125
	SCALER_24BIT dd 0.00000011920928955
	SCALER_32BIT dd 0.00000000046566128730774
	UNSCALER_8BIT dd 128.0
	UNSCALER_16BIT dd 32768.0
	UNSCALER_24BIT dd 8388608.0
	UNSCALER_32BIT dd 2147483648.0
	
	
section .text use32	

	dll_import winmm.dll, waveOutOpen				;creates an audio device
	dll_import winmm.dll, waveOutClose				;destroys an audio device
	dll_import winmm.dll, waveOutWrite				;writes (plays) a playback block into an audio device
	dll_import winmm.dll, waveOutReset				;stops the currently playing sound on the given audio device
	dll_import winmm.dll, waveOutPause				;pauses the currently playing sound on the given audio device
	dll_import winmm.dll, waveOutRestart			;resumes the currently playing sound on the given audio device
	dll_import winmm.dll, waveOutPrepareHeader		;prepares a playback block to be played
	dll_import winmm.dll, waveOutUnprepareHeader	;undoes the PrepareHeader func

	dll_import kernel32.dll, Sleep

	extern my_printf
	extern my_malloc
	extern my_free
	extern my_fopen
	extern my_fclose
	extern my_fjmp
	extern my_fread
	extern file_getId
	extern my_memcmp
	extern my_memcpy
	extern my_memset
	extern my_strcmp
	extern my_strcpy
	extern my_strlen
	
	extern vector_init
	extern vector_destroy
	extern vector_push_back_buffer
	
	
;dataStart: how long is the header in bytes
;dataLength: how much raw audio data is there in bytes
;returns zero if there were no problems
;int sigmaudio_readWaveHeader(const char* filePath, WaveHeader* headerBuffer, int* dataStart, int* dataLength)
audio_readWaveHeader:
	push ebp
	mov ebp, esp
	
	sub esp, 36			;temporary header buffer	;36
	sub esp, 4			;file						;40
	sub esp, 4			;return value				;44
	sub esp, 4			;dataStart					;48
	sub esp, 4			;dataLength					;52
	sub esp, 8			;chunk parse helper			;60
	
	mov dword[ebp-48], 0
	mov dword[ebp-52], 0
	
	mov dword[ebp-44], 0
	
	;open file
	push file_open_mode
	push dword[ebp+8]
	call my_fopen
	mov dword[ebp-40], eax
	test eax, eax
	jz sigmaudio_readWaveHeader_error_read_failure
	
	;read data
	push dword[ebp-40]
	push 1
	push 36
	lea eax, [ebp-36]
	push eax
	call my_fread
	add esp, 16
	
	;was the read successful?
	cmp eax, 1
	jne sigmaudio_readWaveHeader_error_read_failure
	
	push 0		;not from current
	push 12		;the start of the first chunk
	push dword[ebp-40]
	call my_fjmp
	add esp, 12
	
	sigmaudio_readWaveHeader_parseChunks_loop_start:
		;read in the chunk descriptor (chunk id, chunk size)
		push dword[ebp-40]
		push 1
		push 8
		lea eax, [ebp-60]
		push eax
		call my_fread
		add esp, 16
		
		add dword[ebp-48], 8		;increment header by the length of the chunk descriptor
		
		;check if it is the data chunk
		;if so, it contains the data length an is the last chunk
		push 4
		push data_chunk_id
		lea eax, [ebp-60]
		push eax
		call my_memcmp
		add esp, 12
		test eax, eax
		jnz sigmaudio_readWaveHeader_parseChunks_loop_continue
			;set the data size
			mov eax, dword[ebp-56]
			mov dword[ebp-52], eax
			jmp sigmaudio_readWaveHeader_parseChunks_loop_end
		
		sigmaudio_readWaveHeader_parseChunks_loop_continue:
		;add chunk size to the header size
		mov eax, dword[ebp-56]
		add dword[ebp-48], eax
		
		;skip chunk
		push 69				;from current
		push dword[ebp-56]	;chunk size
		push dword[ebp-40]	;file
		call my_fjmp
		add esp, 12
		jmp sigmaudio_readWaveHeader_parseChunks_loop_start
		
	sigmaudio_readWaveHeader_parseChunks_loop_end:
	
	
	
	;close the file
	push dword[ebp-40]
	call my_fclose
	add esp, 4
	test eax, eax
	jz sigmaudio_readWaveHeader_error_read_failure
	
	
	;is the chunk id kosher?
	lea eax, [ebp-36]
	push 4
	push eax
	push based_chunk_id
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz sigmaudio_readWaveHeader_invalid_chunk_id
	
	;is the file type halal?
	lea eax, [ebp-28]
	push 4
	push eax
	push based_file_type
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz sigmaudio_readWaveHeader_invalid_file_type
	
	;is the format marker shuddha?
	lea eax, [ebp-24]
	push 4
	push eax
	push based_format_marker
	call my_memcmp
	add esp, 12
	test eax, eax
	jnz sigmaudio_readWaveHeader_invalid_format_marker
	
	;copy the header data to the actual buffer
	push 36
	lea eax, [ebp-36]
	push eax
	push dword[ebp+12]
	call my_memcpy
	add esp, 12
	
	;copy the other things
	mov eax, dword[ebp+16]
	mov ecx, dword[ebp-48]
	mov dword[eax], ecx			;dataStart
	
	mov eax, dword[ebp+20]
	mov ecx, dword[ebp-52]
	mov dword[eax], ecx			;dataLength
	
	jmp sigmaudio_readWaveHeader_end
	
	sigmaudio_readWaveHeader_error_read_failure:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_read_failure
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
		
		
	sigmaudio_readWaveHeader_invalid_chunk_id:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_chunk_id
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
		
		
	sigmaudio_readWaveHeader_invalid_file_type:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_file_type
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
		
		
	sigmaudio_readWaveHeader_invalid_format_marker:
		mov dword[ebp-44], 69
	
		push dword[ebp+8]
		push error_invalid_format_chunk_marker
		call my_printf
		add esp, 8
		jmp sigmaudio_readWaveHeader_end
	
	sigmaudio_readWaveHeader_end:
	mov eax, dword[ebp-44]		;set return value
	
	mov esp, ebp
	pop ebp
	ret
	
	
;retrieves the WAVEFORMATEX struct corresponding to the file
;returns zero if there were no problems
;int sigmaudio_getWAVEFORMATEX(WAVEFORMATEX* buffer, WaveHeader* header)
sigmaudio_getWAVEFORMATEX:
	push ebp
	mov ebp, esp
	
	sub esp, 36			;wave header		;36
	sub esp, 4			;return value		;40
	
	mov dword[ebp-40], 0
	
	
	;set the values
	mov eax, dword[ebp+8]		;buffer in eax
	mov edx, dword[ebp+12]		;header in edx
	
	;wFormatTag
	mov cx, word[edx+20]
	mov word[eax], cx
	
	;nChannels
	mov cx, word[edx+22]
	mov word[eax+2], cx
	
	;nSamplesPerSec
	mov ecx, dword[edx+24]
	mov dword[eax+4], ecx
	
	;nAvgBytesPerSec
	mov ecx, dword[edx+28]
	mov dword[eax+8], ecx
	
	;nBlockAlign
	mov cx, word[edx+32]
	mov word[eax+12], cx
	
	;wBitsPerSample
	mov cx, word[edx+34]
	mov word[eax+14], cx
	
	;cbSize
	mov word[eax+16], 0
	

	mov eax, dword[ebp-40]		;set return value
	
	mov esp, ebp
	pop ebp
	ret