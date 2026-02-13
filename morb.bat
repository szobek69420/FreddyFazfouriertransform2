setlocal

set BARE_COMMAND=.\build_tools\nasm.exe
set OPTIMIZATION_FLAG=-O0

if "%~1" == "harder" (set OPTIMIZATION_FLAG=-Ox)

set COMMAND=%BARE_COMMAND% %OPTIMIZATION_FLAG%

mkdir build
%COMMAND% -fobj src/main.asm -o build/main.o
%COMMAND% -fobj src/audio.asm -o build/audio.o
%COMMAND% -fobj src/ctype.asm -o build/ctype.o
%COMMAND% -fobj src/cvt.asm -o build/cvt.o
%COMMAND% -fobj src/complex.asm -o build/complex.o
%COMMAND% -fobj src/console.asm -o build/console.o
%COMMAND% -fobj src/dft.asm -o build/dft.o
%COMMAND% -fobj src/file.asm -o build/file.o
%COMMAND% -fobj src/filter.asm -o build/filter.o
%COMMAND% -fobj src/memory.asm -o build/memory.o
%COMMAND% -fobj src/string.asm -o build/string.o
%COMMAND% -fobj src/vector.asm -o build/vector.o

.\build_tools\alink.exe -subsys console -oPE ^
build/main.o ^
build/audio.o ^
build/ctype.o ^
build/cvt.o ^
build/complex.o ^
build/console.o ^
build/dft.o ^
build/file.o ^
build/filter.o ^
build/memory.o ^
build/string.o ^
build/vector.o ^
-o build/test.exe
copy build\test.exe resources
rmdir build /s /q
cd resources
test.exe

endlocal