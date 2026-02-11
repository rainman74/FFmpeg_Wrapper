@echo off

:INIT
call setesc
set "FF_FLAGS=-fflags +genpts+igndts"

:MAIN
if not exist _Converted md _Converted

for %%I in (*.avs) do if not exist "_Converted\%%~nI.mkv" (
	echo %ESC%[101;93m %%~nI %ESC%[0m
	ffmpeg -y -v error -stats %FF_FLAGS% -hwaccel auto -i "%%I" -c:v h264_nvenc -preset p7 -cq:v 20 -rc:v vbr -c:a ac3 -b:a 192k -metadata:s:a:0 language=ger "_Converted\%%~nI.mkv"
)

REM for %%I in (*.avs) do if not exist "_Converted\%%~nI.mkv" (
	REM echo %ESC%[101;93m %%~nI %ESC%[0m
	REM ffmpeg -y -v error -stats %FF_FLAGS% -hwaccel auto -i "%%I" -c:v ffv1 -level 3 -c:a ac3 -b:a 192k -metadata:s:a:0 language=ger "_Converted\%%~nI.mkv"
REM )
