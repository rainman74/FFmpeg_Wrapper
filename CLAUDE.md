# Projekt: FFmpeg_Wrapper

Batch-Wrapper für `ffmpeg.exe` (NVENC-Hardwareencoding) plus zwei Master-Converter für gezielte Audio-/Video-Aufgaben. Zielplattform: **Windows 11**, cmd.exe. Deployment über `.___PUSH___.cmd` (xcopy `*.cmd` → `%CMDPATH%\bin`, dann `git commit/push`).

## Dateien im Repo

| Datei | Zweck |
|---|---|
| `ffmpeg_wrapper.cmd` | Haupt-Wrapper: Encoder/Audio/Qualität/Crop/Filter/Mode/Decoder + Token-Validierung, `_Converted`/`_Check`, EDIT_TAGS/REMUX |
| `ffmpeg_avs.cmd` | AviSynth-Batch: Auswahl 1 = H.264/AC3 (ARCHIVE), 2 = FFV1/AC3 (UPSCALE), 3 = HEVC/AC3 (STANDARD) |
| `ffmpeg_audio_converter.cmd` | Master für Audiospuren: konvertieren, up-/downmixen, taggen, MP3-Export, stumme Spur |
| `ffmpeg_video_converter.cmd` | Master für Video: SRT extrahieren/einbrennen/muxen, Metadaten strippen, GIF, LUT, Mask, Cut/Join |
| `README.md` | Nutzer-Doku (wird von `. ___PUSH___.cmd` **nicht** nach bin kopiert) |

**Nur im `bin` (nicht im Repo):** `funac.cmd`, `funvc.cmd` (Start-Wrapper mit `CALLER_NAME`), `cube.cmd`, `clut.cmd` (HaldCLUT/Cube-Erzeugung).

## Konventionen der Converter

- Aufbau: `:INIT` (Flags, Bitraten, Filter, `INPUT_GLOBS`) → `:SETPROFILE` → `:MAIN` → `RUN_*`-Helfer → `:VALIDATE-PARAMS` → `:USAGE` → `:END`
- **Keine REM-Zeilen** in den Converter-Skripten; Echos nur für Fortschritt/`WARNING`/`ERROR`/`SKIP`
- `setlocal enabledelayedexpansion`, Tabs als Einrückung, CRLF, ASCII
- Ausgabe immer `_Converted\<Name>.<ext>` (Ausnahme: `mask`, `cut`, `join` im aktuellen Ordner); vorhandene Ausgaben werden übersprungen; Konvertierungsfehler lassen die Quelle stehen (Teil-Ausgabe gelöscht, kein `_Check`-Move) — `_Check\` nur im `ffmpeg_wrapper` für Vorprüf-/Nachbearbeitungsfehler (siehe Abschnitt „Abbruch-/CTRL+C-Sicherheit")
- **Bei „nichts zu tun" wird keine Meldung ausgegeben** (kein `No files found.`, keine `[INFO] Savings`-Zeile — beides am 2026-11-12 entfernt)
- `USAGE`/Fehlermeldungen über `:PRINT_TOK` + `CALLER_NAME` (bei Aufruf über `funac`/`funvc` erscheint der Wrapper-Name)
- Zweiter Parameter: nur wo sinnvoll (`select`, LUT-Datei); sonst ERROR „takes no second parameter"

### Audio-Converter (`ffmpeg_audio_converter <profile> [select]`)

- Profile: `ac3 ac351 ac351u ac320 ac320d aac aac51 aac51u aac20 aac20d eng ger copy mp3 silence`
- Copy-Regel: Codec **und** Kanal-Klasse müssen passen (2.0 = 1–2ch, 5.1 = 3–6ch, >6ch = 7.1→immer `-ac 6`)
- Up-/DownMix per `-filter:a:N` nur auf tatsächlich zu kodierenden Spuren; `-ac` + `-rematrix_maxval 1.0` global
- DownMix-Filter: `pan` + `volume=0.5` + `alimiter=limit=0.95:level=0`; UpMix: `pan=5.1(side)` mit 0.3-Differenz-Surround
- `select`: nur deu/ger/eng, DE zuerst; `mp3`: erster Audio-Track → 320k Stereo ohne Video, `.mp3`-Inputs werden nur verschoben; `silence`: stummer AAC-Track am Ende, `select` ignoriert

### Video-Converter (`ffmpeg_video_converter <profil> [param]`)

- Profile: `srt_extract srt_burn srt_merge strip gif lut mask cut join`
- Encoding nur bei `srt_burn`/`lut`: `hevc_nvenc` main, p7, tune hq, cq 26, multipass fullres, spatial/temporal AQ, lookahead 24, refs 4, bf 3, `-pix_fmt yuv420p`; Audio → AC3 (copy bei AC3, sonst 192k/384k nach Kanalzahl)
- `srt_extract`: alle Subtitle-Spuren → `<Name>.<DE|EN|UN>[.Forced][.N].srt` (ger/deu→DE, eng→EN, sonst UN, Forced aus disposition)
- `srt_merge`: alle passenden SRTs einmuxen, Reihenfolge DE → EN → UN, Forced jeweils zuerst; Forced-Spuren `-disposition:s:N forced+default`; vorhandene eingebettete Subs bleiben
- `strip`: nur `*.mkv`; ffmpeg-Remux (`-map 0 -c copy -map_metadata -1 -map_chapters -1`, Attachment-`filename`-Metadata pro Attachment) + `mkvpropedit -t all: --delete-track-statistics-tags -e info -s writing-application= -s muxing-application=`; Attachments bleiben, Sprachen/Titel entfallen
- `cut`: jede `*.mkv`/`*.mp4` → `<Name>_part_%02d.mkv` (Segment 300 s, copy); Skip wenn Parts existieren (Wildcard)
- `join`: alle `<Name>_part_*.mkv` → `<Name>.mkv` (concat); Skip wenn `<Name>.mkv` existiert
- **Nie löschen**: Quellen, Parts und Ausgaben bleiben erhalten; nur die temporäre Concat-Liste in `%TEMP%` wird gelöscht

## Deployment / Push

- `.___PUSH___.cmd` im jeweiligen Repo-Root ausführen: xcopy `*.cmd` → `%CMDPATH%\bin`, `git add .`, `git commit -m "Updates"`, `git push`
- **Repo ist maßgeblich:** `. ___PUSH___.cmd` überschreibt `bin` direkt mit der Repo-Version. **Custom Crops und Filter (`cX`/`fX`) sind nicht zu beachten** — im `ffmpeg_wrapper` (`c1`–`c6`/`f1`–`f6`) wie im `nvencc64_wrapper` des Schwester-Repos (`smooth`/`nlmeans`/`f1`–`f3`) sind das nur temporäre Werte, die jederzeit zurückgesetzt werden; maßgeblich ist immer die Repo-/Standardversion, kein Sichern/Zurückspielen nötig

## Fallstricke (aus der Praxis)

- Klammern in `echo`-Texten innerhalb von `if (...)`-Blöcken müssen escaped werden (`^(` `^)`), sonst cmd-Syntaxfehler
- In `for`-Schleifen keine `%%Duration…`-Templates (kollidiert mit For-Variablen) → solche Aufrufe in Unterroutinen auslagern
- `for /f`-Backquotes: `=`/`,` müssen mit `^` escaped werden (`stream^=index`); `-filter:a:N` statt globalem `-af` (Copy-Streams!)
- Dateinamen mit `!` sind wegen Delayed Expansion problematisch; LUT-Dateien werden als `_lut_tmp.<ext>` in den Ordner kopiert (Pfad-Escaping vermeiden)
- `-map_metadata -1` entfernt auch Stream-Tags (Sprach-/Titel-Tags) — beim `strip` gewollt, sonst nicht verwenden
- ffmpeg-Mappings: Audio-Codec-Argumente immer pro Stream (`-c:a:N`), sonst „Multiple -codec options specified"

## Zweistufige Codec-/Stream-Prüfung (Audio-Reencode-Pfad, 2026-11-27)

Stand `ffmpeg_wrapper.cmd`: **1108 Zeilen**. Bei `CHECK_ENCODED=1` (Parameter 8 leer/`def`/`true`) und passendem Video-Codec wird zusätzlich das Audio geprüft: `:SETAUDIO` setzt `AUDIO_MODE` (Z. 84–103), die neue Routine `:CHECK_AUDIO_STREAMS` (Z. 240–287) liest `ffprobe -select_streams a -show_entries stream=index,codec_name,channels -of csv=p=0` und baut `FF_AUDIO_ARGS`/`FF_AUDIO_INFO`.

- **Fall A — `copy`/`copy1`/`copy2`/`copy12`/`copy23`:** `AUDIO_MODE=copy` → unverändertes Verschieben/Muxen nach `_Converted`, `SKIP_FILE=1`; Track-Filter werden bei bereits encodiertem Video ignoriert.
- **Fall B — `ac3`/`aac`/`eac3` (leer = ac3):** keine Audiospuren **oder** alle Spuren konform → bisheriges Verschieben (`TARGET_DIR`). Mindestens eine Spur abweichend → `TARGET_DIR` bleibt leer, `AUDIO_ONLY_FFMPEG=1` (Entscheidungsmatrix Z. 329–343).
- **Stream-Regeln:** nur abweichende Spuren werden neu encodet, konforme bleiben `-c:a:<idx> copy` (auch bei abweichender Bitrate). `ac3`: ≤2ch 192k / >2ch 384k (`-ac:a:<idx> 6`, 7.1→5.1); `aac`: 128k/256k; `eac3`: 320k/640k. Ein `aacs`-Token existiert in diesem Wrapper nicht (`TOK_AUDIO` unverändert).
- **FFmpeg-Aufruf (Z. 379–408):** `-map 0:v -map 0:a? -map 0:s? -map 0:t? -map_chapters 0 -c:v copy -c:s copy -c:t copy <FF_AUDIO_ARGS>` → `_Converted\<Name>.part.mkv`; danach Rename, `EDIT_TAGS`, `REMUX_IF_NEEDED`, 5-s-Countdown. Quelle bleibt unangetastet; bei Fehler `.part.mkv` löschen + `WARNING: FFmpeg audio re-encoding failed or cancelled. Source not moved.` und `exit /b`.
- **VIDEO_MATCH:** `hevc`/`he10` → `ENCODER=hevc_nvenc` → HEVC; `h264` → `h264_nvenc` → AVC; `av1`/`av10` → `av1_nvenc` → AV1.
- **Grenze:** `mediainfo --Inform=Video;%Format%` liefert bei mehreren Videospuren verketteten Text (z. B. `HEVCHEVC`) → kein Video-Match → normaler Encode-Pfad.

**Tests (2026-11-27, real):** gemischt (`ac3` 2ch copy + `aac` 6ch → `ac3` 6ch 384k), alle konform → Verschieben, `copy`/`copy1` → Verschieben, ohne Audio → Verschieben, `aac`-/`eac3`-Ziel, `he10`-Ziel, `av1`/`av10`-Ziel (libsvtav1-Quelle) → Audio-Pfad mit Video-Copy; **Video-MD5 identisch**, Quelle bleibt, Untertitel + Font-Attachment erhalten, MP4-Quelle → MKV-Ausgabe, `CHECK_ENCODED=false` → normaler Encode-Pfad unverändert. Token-Tabellen und bestehende Routinen unverändert.

## Toter Code im `ffmpeg_wrapper.cmd` (Stand 2026-11-27; Zeilen nach Audio-Patch aktualisiert)

Der Wrapper ist aus `nvencc64_wrapper.cmd` (Schwester-Repo `NVEncC64_Wrapper`) abgeleitet. Dort ist die Resize-Logik **lebendig**, weil NVEncC getrennte Optionen für Crop (`--crop`), Zielauflösung (`--output-res`) und Resampler (`--vpp-resize spline36`) hat. Im ffmpeg-Wrapper ist sie **nicht nötig**: `-vf crop=W:H:X:Y` legt die Ausgabeauflösung direkt fest, Skalierung passiert nur über explizite `zscale`-Crop-Profile. Die folgenden Stellen sind deshalb inaktiv, bleiben aber absichtlich im Code (Referenz für ein späteres Aufräumen; Entfernen wäre eine reine Löschung ohne Verhaltensänderung):

**Bereits entfernt (2026-11-25):** `RESIZE_PARAM`-Zweige (ehem. 416–423), `RESIZE_REQUIRED` (ehem. 267/379/386/391), `FILTER_HAS_RESIZE`/`FILTER_HAS_SCALE_CUDA`/`FILTER_HAS_HWUPLOAD`-Block (ehem. 33–57). Übrig sind nur noch:

| Stelle | Zeilen | Befund |
|---|---|---|
| `AUTO_RES_W`, `AUTO_RES_H` | 300–302 | Initialisierung, nie gelesen (Zeilen 300/301 doppelt identisch) |
| `AUTO_RES` / `TEMP_RES` / `NVEnc_Res` | 741, 779, 782; PS-Probe 924/982/991/1015 | Probe liefert das `--output-res`-Analogon, wird aber nicht verwendet; Code 1:1 aus dem NVEncC-Repo übernommen |
| `FOUND` | 292, 296 | Zähler, nie gelesen |
| `!CROP!` (Debug) | 476 | `%DBG%`-Zeile nutzt eine nicht existierende Variable; korrekt wäre `CROP_VAL`; nur bei `DEBUG=1` sichtbar |

- **Erledigt (2026-11-25) — Spline36-Parität:** Die 9 Auflösungs-Profile in `:SETCROP` (Zeilen 128–136) skalieren jetzt mit `zscale=w=…:h=…:filter=spline36` — echtes Spline36 über zimg, Seitenverhältnis über `h=-1`/`w=-2`. `zscale` war im Wrapper bereits für HDR→SDR im Einsatz. Die `crop=`-Profile und Auto-Crop sind unverändert (crop skaliert nicht).
- **Auto-Crop für Nicht-1080p:** Die feste Basis `1920/1080` (Zeilen 459–460) und die Probe-Standardwerttabelle müssten dynamisch werden; die Skalierung gehörte dann als eigene `zscale`-Stufe in den `VF_CHAIN`.

## Historie (Auszug)

- 2026-11-12: `ffmpeg_converter.cmd` → `ffmpeg_audio_converter.cmd` umbenannt (der alte Dateiname existiert nicht mehr; Profile ac3/aac/ac32x/ac51x/eng/ger/copy + `mp3`, `silence`; `dual`/`ac3eng`/`aaceng` entfernt)
- 2026-11-12: `ffmpeg_video_converter.cmd` neu (srt_extract/srt_burn/srt_merge/strip/gif/lut/mask/cut/join); `funvc.cmd` im bin
- 2026-11-12: `No files found.` und `[INFO] Savings`-Ausgaben aus Wrapper und Convertern entfernt
- 2026-11-13: Filter `median` und `largemedian` in `ffmpeg_wrapper.cmd` ergänzt (`median=radius=1:radiusV=1:planes=7` bzw. `radius=2`); README-Tabelle nachgezogen
- 2026-11-13: `ffmpeg_avs.cmd` CTRL+C-Handling an `ffmpeg_wrapper` angeglichen (`RC=!ERRORLEVEL!`, Warntext „Encoding failed…", Rename-Check; Commits `87b316e`/`ae41055`)
- 2026-11-25: Doku-Drift in dieser Datei korrigiert (Warntexte, `_Check`-Scope, Start-Cleanup je Skript, `cube`/`clut`-Ausnahmen) und Abschnitt „Toter Code im `ffmpeg_wrapper.cmd`" ergänzt
- 2026-11-25: Toten Code aus `ffmpeg_wrapper.cmd` entfernt (`RESIZE_PARAM`, `RESIZE_REQUIRED`, `FILTER_HAS_*`); die 9 Auflösungs-Profile in `:SETCROP` von `scale=` auf `zscale=…:filter=spline36` umgestellt (echtes Spline36 via zimg, NVEncC-Parität)
- 2026-11-25: Horizontale Auto-Erkennung um Standardbreite `1772` ergänzt (`$StandardWidths` im Probe) und Crop-Profil `1772` (`crop=1772:1080:74:0`) inkl. Token/README aufgenommen
- 2026-11-27: Zweistufige Codec-/Stream-Prüfung im `ffmpeg_wrapper`: bei `CHECK_ENCODED=1` werden Audiospuren geprüft (`:SETAUDIO` mit `AUDIO_MODE`, neue Routine `:CHECK_AUDIO_STREAMS`, Entscheidungsmatrix in `:MAIN`); abweichende Spuren werden per FFmpeg-Audio-Reencode (Video `copy`, Quelle bleibt erhalten) neu encodet, konforme Spuren/`copy`-Fälle verschieben wie bisher

## Abbruch-/CTRL+C-Sicherheit (Stand 2026-11-13)

Bei CTRL+C während der Konvertierung bleiben keine unvollständigen Dateien unter dem finalen Namen liegen und die Quelle wird nicht mehr nach `_Check` verschoben:

- **Temp-Datei + Rename**: Jede Ausgabe wird zuerst als `<Name>.part.<ext>` geschrieben (in `_Converted`, bei `mask`/`join`/`cut` im Arbeitsordner) und **erst nach Erfolg** auf den finalen Namen umbenannt.
- **Fehlerpfad**: Bei ffmpeg-Fehler/Abbruch wird die Teil-Ausgabe **gelöscht**, eine WARNUNG ausgegeben und die **Quelle bleibt stehen**. Warntext je Skript: `ffmpeg_wrapper`/`ffmpeg_avs` → `WARNING: Encoding failed or cancelled. Source not moved.`; `ffmpeg_audio_converter`/`ffmpeg_video_converter` → `WARNING: Conversion failed or cancelled. Source not moved.` (bei `join`/`cut` → `Join failed or cancelled`/`Cut failed or cancelled`). Kein `_Check`-Move mehr.
- **Exitcode-Auswertung**: Nicht mehr `if errorlevel 1`, sondern `set "RC=!ERRORLEVEL!"` + `if not "!RC!"=="0"` — damit wird **jeder** Code ≠ 0 als Fehler/Abbruch erkannt, auch der CTRL+C-Status `0xC000013A` (als `-1073741510`). Vorher wurde ein Abbruch mit negativem Exitcode übersehen (Teil-Datei wurde dann als final umbenannt). Umgestellt: `ffmpeg_wrapper`, `ffmpeg_audio_converter`, `ffmpeg_video_converter` (Commit `9aea16d`) und `ffmpeg_avs` (Commit `ae41055`, 2026-11-13); `bin\cube.cmd` nutzt weiter `if errorlevel 1`, `bin\clut.cmd` prüft nur die Existenz der Teil-Datei — dort also keine CTRL+C-Erkennung.
- **`_Check`-Verwendung** (nur `ffmpeg_wrapper`; die drei Converter nutzen kein `_Check`): Vorprüf-Fehler — Codec nicht erkannt (Zeilen 324–326), Probe fehlgeschlagen (447–450) — sowie Nachbearbeitungs-/Remux-Fehler: EDIT_TAGS-PowerShell- oder mkvpropedit-Fehler (Ausgabe → `_Check`, 601–602, 608–609, 634–635) und defekter Re-Mux mit 0 Streams (Quelle → `_Check`, 676–679).
- **Aufräumen beim Start** (je Skript in `MAIN`): `ffmpeg_wrapper`/`ffmpeg_avs` → `_Converted\*.part.mkv`; `ffmpeg_audio_converter` → `_Converted\*.part.*`; `ffmpeg_video_converter` → `_Converted\*.part.*`, `*.part.mkv`, `*.part.gif`, `*_mask.part.png`, `*_clip.part.mkv` (läuft **nicht** bei `cut`/`join` — `MAIN` springt vorher zu `RUN_CUT`/`RUN_JOIN`); `bin\cube.cmd` → `*.part.cube`, `*_512.part.png`; `bin\clut.cmd` → `*_haldclut*.part.png`.
- **Grenze**: Die „Terminate batch job (Y/N)"-Beendigung von cmd lässt sich nicht abfangen — dann bleibt höchstens ein `.part`-Rest liegen, der beim nächsten Lauf entfernt wird.
- **Betroffen**: `ffmpeg_audio_converter` (normal/`mp3`/`silence`), `ffmpeg_video_converter` (burn/gif/lut/mask/extract/srt_merge/strip/cut/join), `ffmpeg_wrapper` (Encode + mkvmmerge-Re-Mux im Check-Encoded-Block), `ffmpeg_avs`; im NVEncC-Repo analog `nvencc64_wrapper`; dazu `bin\cube.cmd` und `bin\clut.cmd` (Part-Handling ja, aber ohne `RC=!ERRORLEVEL!`-Auswertung).

## Rollback: Version ohne Part-Handling

- **Part-Handling eingeführt**: Commit **`b511ade`** (Temp-Datei `.part.*` + Rename, Fehlerpfad ohne `_Check`-Move); danach **`9aea16d`** (Exitcode-Auswertung `RC=!ERRORLEVEL!` inkl. CTRL+C-Status `0xC000013A`; damals nur `ffmpeg_wrapper`/`ffmpeg_audio_converter`/`ffmpeg_video_converter` — `ffmpeg_avs` folgte mit `87b316e`/`ae41055` am 2026-11-13).
- **Letzter Stand OHNE Part-Handling: Commit `803938d`** (davor: `21364cf`/`362410c` = nur CLAUDE.md-Doku).
- **Rollback der Skripte**:
  ```
  git checkout 803938d -- ffmpeg_audio_converter.cmd ffmpeg_video_converter.cmd ffmpeg_wrapper.cmd ffmpeg_avs.cmd
  ```
  danach committen/pushen (Repo `FFmpeg_Wrapper`).
- **Achtung**: `bin\cube.cmd` und `bin\clut.cmd` sind **nicht** versioniert (nur im `bin`) — für einen Rollback dort die Vor-Version manuell wiederherstellen (Part-Handling: `_512.part.png`/`.part.cube` bzw. `*_haldclutN.part.png`).
