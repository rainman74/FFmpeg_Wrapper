@echo off & setlocal enabledelayedexpansion

:INIT
call :SETESC
call :SETTOKEN
set "FF_FLAGS=-v info -hide_banner -stats -err_detect ignore_err -fflags +genpts+igndts"
set "NVENC_PARAM=-c:v hevc_nvenc -profile:v main -preset:v p7 -tune:v hq -rc:v vbr -cq:v 26 -multipass:v fullres -spatial-aq:v 1 -temporal-aq:v 1 -aq-strength:v 10 -rc-lookahead:v 24 -refs:v 4 -bf:v 3 -b_ref_mode:v middle"
set "AC3_BR_LOW=192k" & set "AC3_BR_HIGH=384k"
set "PIX_FMT=yuv420p"
set "INPUT_GLOBS=*.mkv *.mp4 *.mpg *.mov *.avi *.webm"
set "MASK_SEEK=00:05:00"
set "MASK_SPAN=00:00:30"
set "CUT_SEGMENT=300"
set "JOIN_LIST=%TEMP%\_ffmpeg_join.txt"
set "LUT_TMP=_lut_tmp"
set "PARAM="

if '%1'=='-h' goto USAGE
if '%1'=='' goto USAGE

call :VALIDATE-PARAMS %*
if "!PARAM_ERR!"=="1" goto :END

call :SETPROFILE %1
call :MAIN
goto :END

:SETPROFILE
set "MODE=" & set "OUT_EXT=.mkv"
if /i "%1"=="srt_extract" (set "MODE=EXTRACT")
if /i "%1"=="srt_burn"    (set "MODE=BURN")
if /i "%1"=="srt_merge"   (set "MODE=SRTMERGE")
if /i "%1"=="gif"         (set "MODE=GIF" & set "OUT_EXT=.gif")
if /i "%1"=="lut"         (set "MODE=LUT")
if /i "%1"=="mask"        (set "MODE=MASK")
if /i "%1"=="strip"       (set "MODE=STRIP" & set "INPUT_GLOBS=*.mkv")
if /i "%1"=="cut"         (set "MODE=CUT")
if /i "%1"=="join"        (set "MODE=JOIN")
exit /b

:MAIN
set "FOUND=0"
if /i "!MODE!"=="JOIN" (
	call :RUN_JOIN
	goto :END
)
if /i "!MODE!"=="CUT" (
	call :RUN_CUT
	goto :END
)
call :ENSURE_DIR "_Converted"
for %%I in (!INPUT_GLOBS!) do if exist "%%I" (
	if /i "!MODE!"=="EXTRACT" (
		call :RUN_EXTRACT "%%I"
	) else (
		set "SKIP_OUT="
		if /i "!MODE!"=="MASK" (
			if exist "%%~nI_mask.png" if exist "%%~nI_clip.mkv" set "SKIP_OUT=1"
		) else (
			if exist "_Converted\%%~nI!OUT_EXT!" set "SKIP_OUT=1"
		)
		if not defined SKIP_OUT (
			echo %ESC%[101;93m %%I %ESC%[0m
			set "FOUND=1"
			if /i "!MODE!"=="BURN" call :RUN_BURN "%%I"
			if /i "!MODE!"=="GIF" call :RUN_GIF "%%I"
			if /i "!MODE!"=="LUT" call :RUN_LUT "%%I"
			if /i "!MODE!"=="MASK" call :RUN_MASK "%%I"
			if /i "!MODE!"=="SRTMERGE" call :RUN_SRTMERGE "%%I"
			if /i "!MODE!"=="STRIP" call :RUN_STRIP "%%I"
		)
	)
)

if "%FOUND%"=="0" (
	echo No files found.
) else if /i not "!MODE!"=="MASK" if /i not "!MODE!"=="EXTRACT" (
	powershell -command "$o=ls *.mkv,*.mp4,*.mpg,*.mov,*.avi,*.webm; $s=0; $d=0; foreach($f in $o){$c='_Converted\'+$f.BaseName+'!OUT_EXT!'; if(test-path $c){$s+=$f.Length; $d+=(ls $c).Length}}; if($s -gt 0){write-host ('[INFO] Savings: {0:N2} GB ({1:P1})' -f (($s-$d)/1GB), (($s-$d)/$s)) -ForegroundColor Green}"
)
exit /b

:RUN_BURN
if not exist "%~n1.srt" (
	echo %ESC%[91mWARNING: Subtitle file not found: %~n1.srt%ESC%[0m
	exit /b
)
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
call :BUILD_AC3 "%~1"
ffmpeg %FF_FLAGS% -i "%~1" -map 0:v:0 -map 0:a? -map 0:s? !AUDIO_ARGS! -c:s copy %NVENC_PARAM% -pix_fmt %PIX_FMT% -vf "subtitles=%~n1.srt" -map_metadata 0 -map_chapters 0 "_Converted\%~n1.mkv"
if errorlevel 1 (
	echo %ESC%[91mWARNING: Conversion failed.%ESC%[0m
	exit /b
)
if not exist "_Converted\%~n1.mkv" echo %ESC%[91mWARNING: No output file.%ESC%[0m
exit /b

:RUN_GIF
set "PAL=%TEMP%\_ffmpeg_gif_palette.png"
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
ffmpeg %FF_FLAGS% -i "%~1" -vf "palettegen=stats_mode=diff" -frames:v 1 -update 1 "%PAL%"
if not exist "%PAL%" (
	echo %ESC%[91mWARNING: Palette generation failed.%ESC%[0m
	exit /b
)
ffmpeg %FF_FLAGS% -i "%~1" -i "%PAL%" -lavfi "paletteuse=dither=bayer:bayer_scale=5" -map_metadata 0 "_Converted\%~n1.gif"
del /q "%PAL%" >nul
if not exist "_Converted\%~n1.gif" echo %ESC%[91mWARNING: No output file.%ESC%[0m
exit /b

:RUN_LUT
for %%E in ("!PARAM!") do set "LUTEXT=%%~xE"
set "LUTTMP=%LUT_TMP%!LUTEXT!"
copy /Y "!PARAM!" "!LUTTMP!" >nul
if not exist "!LUTTMP!" (
	echo %ESC%[91mWARNING: LUT copy failed: !PARAM!%ESC%[0m
	exit /b
)
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
call :BUILD_AC3 "%~1"
if /i "!LUTEXT!"==".cube" (
	ffmpeg %FF_FLAGS% -i "%~1" -map 0:v:0 -map 0:a? -map 0:s? !AUDIO_ARGS! -c:s copy %NVENC_PARAM% -pix_fmt %PIX_FMT% -vf "lut3d=file=!LUTTMP!" -map_metadata 0 -map_chapters 0 "_Converted\%~n1.mkv"
) else (
	ffmpeg %FF_FLAGS% -i "%~1" -i "!LUTTMP!" !AUDIO_ARGS! -c:s copy %NVENC_PARAM% -pix_fmt %PIX_FMT% -filter_complex "[1:v]crop=512:512:0:0[hald];[0:v:0][hald]haldclut[out]" -map "[out]" -map 0:a? -map 0:s? -map_metadata 0 -map_chapters 0 "_Converted\%~n1.mkv"
)
set "FFERR=!errorlevel!"
del /q "!LUTTMP!" >nul
if not "!FFERR!"=="0" (
	echo %ESC%[91mWARNING: Conversion failed.%ESC%[0m
	exit /b
)
if not exist "_Converted\%~n1.mkv" echo %ESC%[91mWARNING: No output file.%ESC%[0m
exit /b

:RUN_MASK
if not exist "%~n1_mask.png" (
	ffmpeg %FF_FLAGS% -ss %MASK_SEEK% -i "%~1" -frames:v 1 -update 1 "%~n1_mask.png"
	if not exist "%~n1_mask.png" ffmpeg %FF_FLAGS% -ss 00:00:00 -i "%~1" -frames:v 1 -update 1 "%~n1_mask.png"
	if not exist "%~n1_mask.png" echo %ESC%[91mWARNING: No mask frame: %~nx1%ESC%[0m
)
if not exist "%~n1_clip.mkv" (
	ffmpeg %FF_FLAGS% -ss %MASK_SEEK% -t %MASK_SPAN% -i "%~1" -map 0 -c copy -map_metadata 0 -map_chapters 0 "%~n1_clip.mkv"
	if not exist "%~n1_clip.mkv" ffmpeg %FF_FLAGS% -ss 00:00:00 -t %MASK_SPAN% -i "%~1" -map 0 -c copy -map_metadata 0 -map_chapters 0 "%~n1_clip.mkv"
	if not exist "%~n1_clip.mkv" echo %ESC%[91mWARNING: No clip: %~nx1%ESC%[0m
)
exit /b

:RUN_EXTRACT
set "BASE=%~n1"
set "SUBIDX=0"
set "EXTRACTED=0"
set "CNT_DE=0" & set "CNT_DEF=0" & set "CNT_EN=0" & set "CNT_ENF=0" & set "CNT_UN=0" & set "CNT_UNF=0"
for /f "usebackq tokens=1-4 delims=," %%A in (`ffprobe -hide_banner -v error -select_streams s -show_entries stream^=index^,codec_name:stream_tags^=language:stream_disposition^=forced -of csv^=p^=0 "%~1" 2^>nul`) do (
	set "S_FORCED=%%C"
	set "S_LANG=%%D"
	set "LANGCODE=UN"
	if /i "!S_LANG!"=="ger" set "LANGCODE=DE"
	if /i "!S_LANG!"=="deu" set "LANGCODE=DE"
	if /i "!S_LANG!"=="eng" set "LANGCODE=EN"
	set "SEG=!LANGCODE!"
	set "CKEY=!LANGCODE!"
	if "!S_FORCED!"=="1" (
		set "SEG=!SEG!.Forced"
		set "CKEY=!CKEY!F"
	)
	call :SUB_COUNT "!CKEY!"
	set "TARGET=_Converted\!BASE!.!SEG!"
	if !CNT! GTR 1 set "TARGET=!TARGET!.!CNT!"
	set "TARGET=!TARGET!.srt"
	if not exist "!TARGET!" call :EXTRACT_STREAM "%~1" !SUBIDX! "!TARGET!"
	set /a "SUBIDX+=1"
)
if "!EXTRACTED!"=="1" set "FOUND=1"
if "!SUBIDX!"=="0" echo %ESC%[91mWARNING: No subtitle track: %~nx1%ESC%[0m
exit /b

:SUB_COUNT
set /a "CNT_%~1+=1"
for %%V in (CNT_%~1) do set "CNT=!%%V!"
exit /b

:EXTRACT_STREAM
if "!EXTRACTED!"=="0" (
	mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
	echo %ESC%[101;93m %~nx1 %ESC%[0m
	set "EXTRACTED=1"
)
ffmpeg %FF_FLAGS% -i "%~1" -map 0:s:%~2 -c:s srt "%~3"
if not exist "%~3" echo %ESC%[91mWARNING: Extraction failed: stream %~2%ESC%[0m
exit /b

:RUN_SRTMERGE
set "BASE=%~n1"
set "SCNT=0"
for /f "usebackq delims=" %%C in (`ffprobe -hide_banner -v error -select_streams s -show_entries stream^=index -of csv^=p^=0 "%~1" 2^>nul`) do set /a "SCNT+=1"
set "SRT_ARGS="
set "SRT_MAPS="
set "SRT_META="
set "SRT_DISP="
set /a "SIDX=0"
for %%L in (DE EN UN) do (
	call :MERGE_SCAN "!BASE!" %%L Forced
	call :MERGE_SCAN "!BASE!" %%L ""
)
if not defined SRT_MAPS (
	echo %ESC%[91mWARNING: No matching srt files: %~nx1%ESC%[0m
	exit /b
)
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
ffmpeg %FF_FLAGS% -i "%~1" !SRT_ARGS! -map 0 !SRT_MAPS! -c copy !SRT_META! !SRT_DISP! -map_metadata 0 -map_chapters 0 "_Converted\%~n1.mkv"
if errorlevel 1 (
	echo %ESC%[91mWARNING: Conversion failed.%ESC%[0m
	exit /b
)
if not exist "_Converted\%~n1.mkv" echo %ESC%[91mWARNING: No output file.%ESC%[0m
exit /b

:MERGE_SCAN
set "MLANG=%~2"
set "MFORCED=%~3"
set "MN=1"
:MERGE_SCAN_LOOP
set "MFILE=%~1.!MLANG!"
if defined MFORCED set "MFILE=!MFILE!.Forced"
if !MN! GTR 1 set "MFILE=!MFILE!.!MN!"
set "MFILE=!MFILE!.srt"
if exist "!MFILE!" call :MERGE_ADD "!MFILE!" "!MLANG!" "!MFORCED!"
set /a "MN+=1"
if !MN! LEQ 20 goto :MERGE_SCAN_LOOP
exit /b

:MERGE_ADD
set /a "SIDX+=1"
set /a "OIDX=SCNT+SIDX-1"
set "SRT_ARGS=!SRT_ARGS! -i "%~1""
set "SRT_MAPS=!SRT_MAPS! -map !SIDX!:s"
set "LANGTAG=und"
if /i "%~2"=="DE" set "LANGTAG=ger"
if /i "%~2"=="EN" set "LANGTAG=eng"
set "SRT_META=!SRT_META! -metadata:s:s:!OIDX! language=!LANGTAG!"
if not "%~3"=="" set "SRT_DISP=!SRT_DISP! -disposition:s:!OIDX! forced+default"
exit /b

:RUN_STRIP
set "ATT_ARGS="
set /a "ATT_IDX=0"
for /f "usebackq tokens=1,2 delims=," %%A in (`ffprobe -hide_banner -v error -select_streams t -show_entries stream^=index:stream_tags^=filename -of csv^=p^=0 "%~1" 2^>nul`) do (
	if not "%%B"=="" (
		set "ATT_ARGS=!ATT_ARGS! -metadata:s:t:!ATT_IDX! "filename=%%B""
		set /a "ATT_IDX+=1"
	)
)
mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%~1"
ffmpeg %FF_FLAGS% -i "%~1" -map 0 -c copy -map_metadata -1 -map_chapters -1 !ATT_ARGS! "_Converted\%~n1.mkv"
if errorlevel 1 (
	echo %ESC%[91mWARNING: Conversion failed.%ESC%[0m
	exit /b
)
if not exist "_Converted\%~n1.mkv" (
	echo %ESC%[91mWARNING: No output file.%ESC%[0m
	exit /b
)
mkvpropedit --quiet "_Converted\%~n1.mkv" -t all: --delete-track-statistics-tags -e info -s writing-application= -s muxing-application=
if errorlevel 1 echo %ESC%[91mWARNING: mkvpropedit failed.%ESC%[0m
exit /b

:BUILD_AC3
set "AUDIO_ARGS="
set /a "A_IDX=0"
for /f "usebackq tokens=1,2 delims=," %%A in (`ffprobe -hide_banner -v error -select_streams a -show_entries stream^=codec_name^,channels -of csv^=p^=0 "%~1" 2^>nul`) do (
	set "A_BR=!AC3_BR_LOW!"
	if %%B GTR 2 set "A_BR=!AC3_BR_HIGH!"
	if /i "%%A"=="ac3" (
		set "AUDIO_ARGS=!AUDIO_ARGS! -c:a:!A_IDX! copy"
	) else (
		set "AUDIO_ARGS=!AUDIO_ARGS! -c:a:!A_IDX! ac3 -b:a:!A_IDX! !A_BR!"
	)
	set /a "A_IDX+=1"
)
exit /b

:RUN_JOIN
set "LASTBASE="
for /f "delims=" %%I in ('dir /b /o:n "*_part_*.mkv" 2^>nul') do (
	set "PARTNAME=%%~nI"
	set "TMPNAME=!PARTNAME:_part_=@!"
	set "BASENAME="
	for /f "tokens=1 delims=@" %%B in ("!TMPNAME!") do set "BASENAME=%%B"
	if not "!BASENAME!"=="" if not "!BASENAME!"=="!LASTBASE!" (
		set "LASTBASE=!BASENAME!"
		if exist "!BASENAME!.mkv" (
			echo %ESC%[93mSKIP: !BASENAME!.mkv already exists.%ESC%[0m
		) else (
			echo %ESC%[101;93m !BASENAME! %ESC%[0m
			if exist "!JOIN_LIST!" del /q "!JOIN_LIST!" >nul
			for /f "delims=" %%P in ('dir /b /o:n "!BASENAME!_part_*.mkv" 2^>nul') do echo file '%%~fP'>>"!JOIN_LIST!"
			ffmpeg %FF_FLAGS% -f concat -safe 0 -i "!JOIN_LIST!" -map 0 -c copy -map_metadata 0 "!BASENAME!.mkv"
			if not exist "!BASENAME!.mkv" echo %ESC%[91mWARNING: Join failed: !BASENAME!%ESC%[0m
		)
	)
)
if exist "!JOIN_LIST!" del /q "!JOIN_LIST!" >nul
exit /b

:RUN_CUT
for %%I in (*.mkv *.mp4) do (
	echo %%~nI| findstr /i "_part_" >nul
	if errorlevel 1 (
		if exist "%%~nI_part_*.mkv" (
			echo %ESC%[93mSKIP: %%~nI_part_*.mkv already exists.%ESC%[0m
		) else (
			echo %ESC%[101;93m %%I %ESC%[0m
			ffmpeg %FF_FLAGS% -i "%%I" -map 0 -c copy -f segment -segment_time %CUT_SEGMENT% -reset_timestamps 1 "%%~nI_part_%%02d.mkv"
			if not exist "%%~nI_part_00.mkv" echo %ESC%[91mWARNING: Cut failed: %%~nxI%ESC%[0m
		)
	)
)
exit /b

:VALIDATE-PARAMS
set "PARAM_ERR=0"
call :VALIDATE_ONE "%1" TOK_PROFILE profile 1
set "PARAM=%~2"
if /i "%~1"=="lut" (
	if "!PARAM!"=="" (
		echo %ESC%[91mERROR: profile 'lut' requires a LUT file as second parameter.%ESC%[0m
		set "PARAM_ERR=1"
	) else if not exist "!PARAM!" (
		echo %ESC%[91mERROR: LUT file not found: !PARAM!%ESC%[0m
		set "PARAM_ERR=1"
	)
) else if not "!PARAM!"=="" (
	echo %ESC%[91mERROR: profile '%~1' takes no second parameter.%ESC%[0m
	set "PARAM_ERR=1"
)
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
if defined CALLER_NAME (
	set "COMMAND=%CALLER_NAME%"
) else (
	set "COMMAND=%~n0"
)
echo Usage: %COMMAND% ^<profile^> [param]
echo.
call :PRINT_TOK "profile" "(required)" TOK_PROFILE
echo param     (optional)  [LUT file, only for 'lut']
echo.
echo Example: %COMMAND% srt_extract
echo Example: %COMMAND% srt_burn
echo Example: %COMMAND% srt_merge
echo Example: %COMMAND% strip
echo Example: %COMMAND% gif
echo Example: %COMMAND% mask
echo Example: %COMMAND% lut haldclut_regrade.png
echo Example: %COMMAND% cut
echo Example: %COMMAND% join
echo.
endlocal
goto :END

:SETESC
for /f "usebackq delims=" %%A in (`echo prompt $E^| cmd`) do set "ESC=%%A"
set "UL=%ESC%[4m"
set "NO=%ESC%[24m"
exit /b

:SETTOKEN
set "TOK_PROFILE=srt_extract srt_burn srt_merge strip gif lut mask cut join"
exit /b

:ENSURE_DIR
if not exist "%~1" md "%~1"
exit /b

:END
exit /b 0
