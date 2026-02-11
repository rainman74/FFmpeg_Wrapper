@echo off & setlocal enabledelayedexpansion

:INIT
call :SETESC

echo %ESC%[92mPlease choose (ENTER = ARCHIVE):%ESC%[0m
echo 1 = ARCHIVE, encoded to H.264/AC3
echo 2 = UPSCALE, encoded to FFV1/AC3 for later Topaz upscale
echo 3 = STANDARD, encoded to HEVC/AC3
echo.

set /p CHOICE="Auswahl: "

if "%CHOICE%"=="2" (
	set PROFILE=UPSCALE
) else if "%CHOICE%"=="3" (
	set PROFILE=STANDARD
) else (
	set PROFILE=ARCHIVE
)

echo %ESC%[104;97m PROFIL: !PROFILE! %ESC%[0m
echo.

:MAIN
if not exist _Converted md _Converted

call :SET_ENCODER_PARAMS

for %%I in (*.avs) do if not exist "_Converted\%%~nI.mkv" (
	echo %ESC%[101;93m %%~nI %ESC%[0m

	call :CONVERT "%%I"
)

goto :END

:SET_ENCODER_PARAMS
set "INPUT_ARGS=-v info -hide_banner -stats -err_detect ignore_err -fflags +genpts+igndts -hwaccel auto"

if "%PROFILE%"=="ARCHIVE" goto :ARCHIVE
if "%PROFILE%"=="UPSCALE" goto :UPSCALE
if "%PROFILE%"=="STANDARD" goto :STANDARD
goto :EOF

:ARCHIVE
set ENCODER_CMD=ffmpeg
set ENCODER_ARGS=-c:v h264_nvenc -profile:v high -preset p7 -tune hq -rc:v vbr -cq:v 24 -multipass fullres -spatial-aq 1 -temporal-aq 1 -aq-strength 10 -rc-lookahead:v 24 -refs 4 -bf 3 -b_ref_mode middle -c:s copy -c:t copy
goto :EOF

:UPSCALE
set ENCODER_CMD=ffmpeg
set ENCODER_ARGS=-c:v ffv1 -level 3 -slices 16 -c:s copy -c:t copy
goto :EOF

:STANDARD
set ENCODER_CMD=ffmpeg
set ENCODER_ARGS=-c:v hevc_nvenc -profile:v main -preset p7 -tune hq -rc:v vbr -cq:v 26 -multipass fullres -spatial-aq 1 -temporal-aq 1 -aq-strength 10 -rc-lookahead:v 24 -refs 4 -bf 3 -b_ref_mode middle -c:s copy -c:t copy
goto :EOF

:CONVERT
set "INPUT_FILE=%~1"
set "SOURCE_FILE="
set "OUTPUT_FILE=_Converted\%~n1.mkv"

if exist "%~n1.mkv" ( set "SOURCE_FILE=%~n1.mkv" ) else if exist "%~n1.mp4" ( set "SOURCE_FILE=%~n1.mp4" )

for /f "tokens=*" %%C in ('ffprobe -hide_banner -v error -select_streams a:0 -show_entries stream^=channels -of default^=noprint_wrappers^=1:nokey^=1 "!SOURCE_FILE!"') do (
	if %%C LEQ 2 ( set "BITRATE_AVS=192k" ) else ( set "BITRATE_AVS=384k" )
)
set "AUDIO_CODECS=-c:a:0 ac3 -b:a:0 !BITRATE_AVS!"

set /a "IDX_TARGET=1"
set "SKIP_FIRST="
for /f "tokens=1,2 delims=," %%A in ('ffprobe -hide_banner -v error -select_streams a -show_entries stream^=codec_name^,channels -of default^=noprint_wrappers^=1:nokey^=1 "!SOURCE_FILE!"') do (
	if defined SKIP_FIRST (
		set "CUR_CODEC=%%A"
		set "CUR_CHANNELS=%%B"
		if !CUR_CHANNELS! LEQ 2 ( set "BITRATE=192k" ) else ( set "BITRATE=384k" )
		if /i "!CUR_CODEC!"=="ac3" (
			set "AUDIO_CODECS=!AUDIO_CODECS! -c:a:!IDX_TARGET! copy"
		) else (
			set "AUDIO_CODECS=!AUDIO_CODECS! -c:a:!IDX_TARGET! ac3 -b:a:!IDX_TARGET! !BITRATE!"
		)
		set /a "IDX_TARGET+=1"
	)
	set "SKIP_FIRST=1"
)

%ENCODER_CMD% %INPUT_ARGS% -i "%INPUT_FILE%" -i "!SOURCE_FILE!" ^
-map 0:v -map 0:a:0 -map 1:a? -map -1:a:0 -map 1:s? -map 1:t? ^
-map_metadata 1 -map_chapters 1 ^
-metadata:s:a:0 language=ger ^
-disposition:a:0 default -disposition:a:1 0 ^
!AUDIO_CODECS! %ENCODER_ARGS% "%OUTPUT_FILE%"

goto :EOF

:SETESC
for /f "delims=" %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "UL=%ESC%[4m"
set "NO=%ESC%[24m"
exit /b

:END
endlocal
exit /b 0
