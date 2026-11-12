@echo off & setlocal enabledelayedexpansion

:INIT
call :SETESC
call :SETTOKEN
set "FF_FLAGS=-v info -hide_banner -stats -err_detect ignore_err -fflags +genpts+igndts"
set "AC3_BR_LOW=192k" & set "AC3_BR_HIGH=384k"
set "AAC_BR_LOW=128k" & set "AAC_BR_HIGH=256k"
set "EXTRA_PARAM=-rematrix_maxval 1.0"
set "SELECT=0"
set "MP3_BR=320k"
set "INPUT_GLOBS=*.mkv *.mp4 *.mpg *.mov *.avi *.webm *.wav"
set "INPUT_GLOBS_AUDIO=*.mkv *.mp4 *.mpg *.mov *.avi *.webm *.wav *.aac *.ac3 *.ogg *.m4a *.mp3"
set "DOWNMIX_FILTER=pan=stereo|FL=FL+0.707*FC+0.707*SL+0.5*BL|FR=FR+0.707*FC+0.707*SR+0.5*BR,volume=0.5,alimiter=limit=0.95:level=0"
set "UPMIX_FILTER=pan=5.1(side)|FL=FL|FR=FR|FC=0.2*FL+0.2*FR|LFE<FL+FR|SL=0.3*FL-0.3*FR|SR=0.3*FR-0.3*FL"

if '%1'=='-h' goto USAGE
if '%1'=='' goto USAGE

call :VALIDATE-PARAMS %*
if "!PARAM_ERR!"=="1" goto :END

if /i "%2"=="select" set "SELECT=1"

call :SETPROFILE %1
call :MAIN
goto :END

:SETPROFILE
set "MODE=" & set "MATCH_CODEC=" & set "ENC_CODEC=" & set "BR_LOW=" & set "BR_HIGH=" & set "CHANNELS=" & set "LANG=" & set "UP=" & set "DOWN="
set "OUT_EXT=.mkv"
if /i "%1"=="ac3"    (set "MODE=AUDIO" & set "MATCH_CODEC=ac3" & set "ENC_CODEC=ac3" & set "BR_LOW=!AC3_BR_LOW!" & set "BR_HIGH=!AC3_BR_HIGH!")
if /i "%1"=="ac351"  (set "MODE=AUDIO" & set "MATCH_CODEC=ac3" & set "ENC_CODEC=ac3" & set "BR_LOW=!AC3_BR_HIGH!" & set "BR_HIGH=!AC3_BR_HIGH!" & set "CHANNELS=6")
if /i "%1"=="ac351u" (set "MODE=AUDIO" & set "MATCH_CODEC=ac3" & set "ENC_CODEC=ac3" & set "BR_LOW=!AC3_BR_HIGH!" & set "BR_HIGH=!AC3_BR_HIGH!" & set "CHANNELS=6" & set "UP=1")
if /i "%1"=="ac320"  (set "MODE=AUDIO" & set "MATCH_CODEC=ac3" & set "ENC_CODEC=ac3" & set "BR_LOW=!AC3_BR_LOW!" & set "BR_HIGH=!AC3_BR_LOW!" & set "CHANNELS=2")
if /i "%1"=="ac320d" (set "MODE=AUDIO" & set "MATCH_CODEC=ac3" & set "ENC_CODEC=ac3" & set "BR_LOW=!AC3_BR_LOW!" & set "BR_HIGH=!AC3_BR_LOW!" & set "CHANNELS=2" & set "DOWN=1")
if /i "%1"=="aac"    (set "MODE=AUDIO" & set "MATCH_CODEC=aac" & set "ENC_CODEC=aac" & set "BR_LOW=!AAC_BR_LOW!" & set "BR_HIGH=!AAC_BR_HIGH!" & set "CHANNELS=2")
if /i "%1"=="aac51"  (set "MODE=AUDIO" & set "MATCH_CODEC=aac" & set "ENC_CODEC=aac" & set "BR_LOW=!AAC_BR_LOW!" & set "BR_HIGH=!AAC_BR_HIGH!" & set "CHANNELS=6")
if /i "%1"=="aac51u" (set "MODE=AUDIO" & set "MATCH_CODEC=aac" & set "ENC_CODEC=aac" & set "BR_LOW=!AAC_BR_LOW!" & set "BR_HIGH=!AAC_BR_HIGH!" & set "CHANNELS=6" & set "UP=1")
if /i "%1"=="aac20"  (set "MODE=AUDIO" & set "MATCH_CODEC=aac" & set "ENC_CODEC=aac" & set "BR_LOW=!AAC_BR_LOW!" & set "BR_HIGH=!AAC_BR_HIGH!" & set "CHANNELS=2")
if /i "%1"=="aac20d" (set "MODE=AUDIO" & set "MATCH_CODEC=aac" & set "ENC_CODEC=aac" & set "BR_LOW=!AAC_BR_LOW!" & set "BR_HIGH=!AAC_BR_HIGH!" & set "CHANNELS=2" & set "DOWN=1")
if /i "%1"=="eng"    (set "MODE=TAG" & set "LANG=eng")
if /i "%1"=="ger"    (set "MODE=TAG" & set "LANG=ger")
if /i "%1"=="copy"   (set "MODE=COPY")
if /i "%1"=="mp3"    (set "MODE=MP3" & set "OUT_EXT=.mp3" & set "INPUT_GLOBS=!INPUT_GLOBS_AUDIO!")
if /i "%1"=="silence" (set "MODE=SILENCE")
exit /b

:MAIN
call :ENSURE_DIR "_Converted"
if exist "_Converted\*.part.*" del /Q "_Converted\*.part.*" >nul 2>&1
set "FOUND=0"
for %%I in (!INPUT_GLOBS!) do if exist "%%I" if not exist "_Converted\%%~nI!OUT_EXT!" (
	echo %ESC%[101;93m %%I %ESC%[0m

	set "FOUND=1"
	set "SKIP_FILE="
	set "ENC_NEEDED="
	set "SEL_NOCHANGE="

	if /i "!MODE!"=="MP3" (
		call :RUN_MP3 "%%I"
	) else if /i "!MODE!"=="SILENCE" (
		call :RUN_SILENCE "%%I"
	) else (
		set "MAP_PARAM="
		set "CODEC_PARAM=-c copy"
		set "AUDIO_ARGS="
		set "CHANNEL_PARAM="

		if /i "!MODE!"=="AUDIO" (
			set "CODEC_PARAM=-c:v copy -c:s copy"
			call :BUILD_AUDIO "%%I"
			if not defined SKIP_FILE set "MAP_PARAM=-map 0:v:0? !AUDIO_MAP! -map 0:s?"
			if defined CHANNELS set "CHANNEL_PARAM=-ac !CHANNELS!"
		)
		if /i "!MODE!"=="TAG" (
			if "!SELECT!"=="1" (
				call :BUILD_AUDIO "%%I"
				if not defined SKIP_FILE set "MAP_PARAM=-map 0:v:0? !AUDIO_MAP! -map 0:s?"
				set "AUDIO_ARGS=-metadata:s:a language=!LANG!"
			) else (
				set "MAP_PARAM=-map 0"
				set "AUDIO_ARGS=-metadata:s:a language=!LANG!"
			)
		)
		if /i "!MODE!"=="COPY" (
			if "!SELECT!"=="1" (
				call :BUILD_AUDIO "%%I"
				if not defined SKIP_FILE set "MAP_PARAM=-map 0:v:0? !AUDIO_MAP! -map 0:s?"
				set "AUDIO_ARGS="
			) else (
				set "MAP_PARAM=-map 0"
			)
		)

		if not defined SKIP_FILE call :TRY_MOVE "%%I"

		if not defined SKIP_FILE (
			mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%%I"

			ffmpeg %FF_FLAGS% -i "%%I" !MAP_PARAM! !CODEC_PARAM! !AUDIO_ARGS! !EXTRA_PARAM! !CHANNEL_PARAM! -map_metadata 0 -map_chapters 0 "_Converted\%%~nI.part.mkv"

			if errorlevel 1 (
				if exist "_Converted\%%~nI.part.mkv" del /Q "_Converted\%%~nI.part.mkv" >nul 2>&1
				echo %ESC%[91mWARNING: Conversion failed or cancelled. Source not moved.%ESC%[0m
				set "SKIP_FILE=1"
			) else if not exist "_Converted\%%~nI.part.mkv" (
				echo %ESC%[91mWARNING: No output file.%ESC%[0m
				set "SKIP_FILE=1"
			) else (
				move /Y "_Converted\%%~nI.part.mkv" "_Converted\%%~nI.mkv" >nul
				if not exist "_Converted\%%~nI.mkv" echo %ESC%[91mWARNING: Rename failed.%ESC%[0m
			)
		)
	)
)

exit /b

:BUILD_AUDIO
set "AUDIO_ARGS="
set "AUDIO_MAP="
set "SEL_ORDER="
if "%SELECT%"=="1" goto :BUILD_AUDIO_SELECT
set /a "OUT_IDX=0"
for /f "usebackq tokens=1,2 delims=," %%A in (`ffprobe -hide_banner -v error -select_streams a -show_entries stream^=codec_name^,channels -of csv^=p^=0 "%~1" 2^>nul`) do (
	set "AUDIO_MAP=!AUDIO_MAP! -map 0:a:!OUT_IDX!"
	call :AUDIO_DECIDE "%%A" "%%B" !OUT_IDX!
	set /a "OUT_IDX+=1"
)
exit /b

:BUILD_AUDIO_SELECT
set "SEL_DE="
set "SEL_EN="
set /a "A_ORD=0"
for /f "usebackq tokens=1-4 delims=," %%A in (`ffprobe -hide_banner -v error -select_streams a -show_entries stream^=index^,codec_name^,channels:stream_tags^=language -of csv^=p^=0 "%~1" 2^>nul`) do (
	set "SEL_LANG=%%D"
	if /i "!SEL_LANG!"=="ger" set "SEL_DE=!SEL_DE! !A_ORD!"
	if /i "!SEL_LANG!"=="deu" set "SEL_DE=!SEL_DE! !A_ORD!"
	if /i "!SEL_LANG!"=="eng" set "SEL_EN=!SEL_EN! !A_ORD!"
	set /a "A_ORD+=1"
)
set "SEL_ORDER=!SEL_DE! !SEL_EN!"
if not defined SEL_DE if not defined SEL_EN (
	echo %ESC%[91mWARNING: No ger/deu/eng audio track. Skipping file.%ESC%[0m
	set "SKIP_FILE=1"
	exit /b
)
set "SEL_SAME=1"
set "SEL_N=0"
for %%o in (!SEL_ORDER!) do (
	if not "%%o"=="!SEL_N!" set "SEL_SAME="
	set /a "SEL_N+=1"
)
if defined SEL_SAME if !SEL_N! EQU !A_ORD! set "SEL_NOCHANGE=1"
set /a "OUT_IDX=0"
for %%o in (!SEL_ORDER!) do (
	set "AUDIO_MAP=!AUDIO_MAP! -map 0:a:%%o"
	for /f "usebackq tokens=1,2 delims=," %%X in (`ffprobe -hide_banner -v error -select_streams a:%%o -show_entries stream^=codec_name^,channels -of csv^=p^=0 "%~1" 2^>nul`) do (
		call :AUDIO_DECIDE "%%X" "%%Y" !OUT_IDX!
	)
	set /a "OUT_IDX+=1"
)
exit /b

:AUDIO_DECIDE
set "D_CODEC=%~1"
set "D_CH=%~2"
set "D_IDX=%~3"
set "D_CLASS=20"
if !D_CH! GTR 2 set "D_CLASS=51"
if !D_CH! GTR 6 set "D_CLASS=71"
set "TARGET_CLASS="
if "!CHANNELS!"=="2" set "TARGET_CLASS=20"
if "!CHANNELS!"=="6" set "TARGET_CLASS=51"
set "NEED_ENC=0"
if /i not "!D_CODEC!"=="!MATCH_CODEC!" set "NEED_ENC=1"
if defined TARGET_CLASS if not "!D_CLASS!"=="!TARGET_CLASS!" set "NEED_ENC=1"
if "!NEED_ENC!"=="1" (
	set "CALC_CH=!D_CH!"
	if defined CHANNELS set "CALC_CH=!CHANNELS!"
	if !CALC_CH! LEQ 2 (set "BITRATE=!BR_LOW!") else (set "BITRATE=!BR_HIGH!")
	set "AUDIO_ARGS=!AUDIO_ARGS! -c:a:!D_IDX! !ENC_CODEC! -b:a:!D_IDX! !BITRATE!"
	set "UP_CHAIN=!UPMIX_FILTER!"
	if "!D_CH!"=="1" set "UP_CHAIN=pan=stereo|c0=c0|c1=c0,!UPMIX_FILTER!"
	if "!UP!"=="1" if "!D_CLASS!"=="20" set "AUDIO_ARGS=!AUDIO_ARGS! -filter:a:!D_IDX! !UP_CHAIN!"
	if "!DOWN!"=="1" if !D_CH! GTR 2 set "AUDIO_ARGS=!AUDIO_ARGS! -filter:a:!D_IDX! !DOWNMIX_FILTER!"
	if /i "!MODE!"=="AUDIO" set "ENC_NEEDED=1"
) else (
	set "AUDIO_ARGS=!AUDIO_ARGS! -c:a:!D_IDX! copy"
)
exit /b

:RUN_MP3
if /i "%~x1"==".mp3" (
	move /Y "%~1" "_Converted\%~n1.mp3" >nul
	if errorlevel 1 echo %ESC%[91mWARNING: Move failed.%ESC%[0m
	exit /b
)
set "ACNT=0"
for /f "usebackq delims=" %%C in (`ffprobe -hide_banner -v error -select_streams a -show_entries stream^=index -of csv^=p^=0 "%~1" 2^>nul`) do set /a "ACNT+=1"
if !ACNT!==0 (
	echo %ESC%[91mWARNING: No audio track. Skipping file.%ESC%[0m
	exit /b
)
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
ffmpeg %FF_FLAGS% -i "%~1" -map 0:a:0 -vn -c:a mp3 -b:a !MP3_BR! -ac 2 !EXTRA_PARAM! -map_metadata 0 -map_chapters -1 "_Converted\%~n1.part.mp3"
if errorlevel 1 (
	if exist "_Converted\%~n1.part.mp3" del /Q "_Converted\%~n1.part.mp3" >nul 2>&1
	echo %ESC%[91mWARNING: Conversion failed or cancelled. Source not moved.%ESC%[0m
	exit /b
)
if not exist "_Converted\%~n1.part.mp3" (
	echo %ESC%[91mWARNING: No output file.%ESC%[0m
	exit /b
)
move /Y "_Converted\%~n1.part.mp3" "_Converted\%~n1.mp3" >nul
if not exist "_Converted\%~n1.mp3" echo %ESC%[91mWARNING: Rename failed.%ESC%[0m
exit /b

:RUN_SILENCE
set "ACNT=0"
for /f "usebackq delims=" %%C in (`ffprobe -hide_banner -v error -select_streams a -show_entries stream^=index -of csv^=p^=0 "%~1" 2^>nul`) do set /a "ACNT+=1"
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
ffmpeg %FF_FLAGS% -i "%~1" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -map 0 -map 1:a -c copy -c:a:!ACNT! aac -b:a 192k -shortest -map_metadata 0 -map_chapters 0 "_Converted\%~n1.part.mkv"
if errorlevel 1 (
	if exist "_Converted\%~n1.part.mkv" del /Q "_Converted\%~n1.part.mkv" >nul 2>&1
	echo %ESC%[91mWARNING: Conversion failed or cancelled. Source not moved.%ESC%[0m
	exit /b
)
if not exist "_Converted\%~n1.part.mkv" (
	echo %ESC%[91mWARNING: No output file.%ESC%[0m
	exit /b
)
move /Y "_Converted\%~n1.part.mkv" "_Converted\%~n1.mkv" >nul
if not exist "_Converted\%~n1.mkv" echo %ESC%[91mWARNING: Rename failed.%ESC%[0m
exit /b

:TRY_MOVE
set "SRC=%~1"
set "BASE=%~n1"
set "NAME=%~nx1"
if /i not "%~x1"==".mkv" exit /b
if /i "!MODE!"=="TAG" exit /b
if /i "!MODE!"=="MP3" exit /b
if /i "!MODE!"=="SILENCE" exit /b
if /i "!MODE!"=="AUDIO" if defined ENC_NEEDED exit /b
if "!SELECT!"=="1" if not defined SEL_NOCHANGE exit /b
call :COUNT_TYPE "!SRC!" v
if !CNT_TMP! GTR 1 exit /b
move /Y "!SRC!" "_Converted\!BASE!.mkv" >nul
if exist "_Converted\!BASE!.mkv" (
	echo %ESC%[93mMOVE: !NAME! already in target format.%ESC%[0m
	set "SKIP_FILE=1"
)
exit /b

:COUNT_TYPE
set "CNT_TMP=0"
for /f "usebackq delims=" %%C in (`ffprobe -hide_banner -v error -select_streams %~2 -show_entries stream^=index -of csv^=p^=0 "%~1" 2^>nul`) do set /a "CNT_TMP+=1"
exit /b

:VALIDATE-PARAMS
set "PARAM_ERR=0"
call :VALIDATE_ONE "%1" TOK_PROFILE profile 1
call :VALIDATE_ONE "%2" TOK_SELECT select 2
exit /b

:VALIDATE_ONE
if "%~1"=="" exit /b
set "VALID=0"
for %%A in (!%2!) do if /i "%~1"=="%%A" set "VALID=1"
if "!VALID!"=="0" (
	set "ERR_MSG=Invalid %3 '%~1' at position %4. Valid values: [!%2: =|!]"
	set "PARAM_ERR=1"
	echo %ESC%[91mERROR: !ERR_MSG!%ESC%[0m
)
exit /b

:PRINT_TOK
setlocal EnableDelayedExpansion
set "LABEL=%~1"
set "INFO=%~2"
set "TOKVAR=%~3"
set LABEL_PAD=10
set INFO_PAD=12
set PAD=22
set "SPACES=                              "
set "L=%LABEL%%SPACES%"
set "L=!L:~0,%LABEL_PAD%!"
set "I=%INFO%%SPACES%"
set "I=!I:~0,%INFO_PAD%!"
set "LEFT=!L!!I!"
set /a PAD1=%PAD%-1
set "INDENT=!SPACES:~0,%PAD1%!"
set "LINE=!LEFT!["
set FIRST=1
set WRAP=115
for %%T in (!%TOKVAR%!) do (
	if "!FIRST!"=="1" (
		set FIRST=0
		set "LINE=!LINE!%%T"
	) else (
		set "TEST=!LINE!|%%T"
		if not "!TEST:~0,%WRAP%!"=="!TEST!" (
			echo !LINE!]
			set "LINE=!INDENT! [%%T"
		) else (
			set "LINE=!LINE!|%%T"
		)
	)
)
echo !LINE!]
endlocal & exit /b

:USAGE
setlocal EnableDelayedExpansion
cls
set "USAGE_PARAMS=^<profile^> [select]"
if defined CALLER_NAME (
	set "COMMAND=%CALLER_NAME%"
) else (
	set "COMMAND=%~n0"
)
echo Usage: %COMMAND% %USAGE_PARAMS%
echo.
call :PRINT_TOK "profile" "(required)" TOK_PROFILE
call :PRINT_TOK "select" "(optional)" TOK_SELECT
echo.
echo Note: 'select' is ignored by profile 'silence'.
echo.
echo Example: %COMMAND% ac3
echo Example: %COMMAND% ac3 select
echo Example: %COMMAND% ac351
echo Example: %COMMAND% aac51 select
echo Example: %COMMAND% eng
echo Example: %COMMAND% copy select
echo Example: %COMMAND% mp3
echo Example: %COMMAND% silence
echo.
endlocal
goto :END

:SETESC
for /f "usebackq delims=" %%A in (`echo prompt $E^| cmd`) do set "ESC=%%A"
set "UL=%ESC%[4m"
set "NO=%ESC%[24m"
exit /b

:SETTOKEN
set "TOK_PROFILE=ac3 ac351 ac351u ac320 ac320d aac aac51 aac51u aac20 aac20d eng ger copy mp3 silence"
set "TOK_SELECT=select"
exit /b

:ENSURE_DIR
if not exist "%~1" md "%~1"
exit /b

:END
exit /b 0
