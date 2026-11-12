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
- Ausgabe immer `_Converted\<Name>.<ext>` (Ausnahme: `mask`, `cut`, `join` im aktuellen Ordner); vorhandene Ausgaben werden übersprungen; Fehler → Datei nach `_Check\`
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

## Historie (Auszug)

- 2026-11-12: `ffmpeg_converter.cmd` → `ffmpeg_audio_converter.cmd` umbenannt (der alte Dateiname existiert nicht mehr; Profile ac3/aac/ac32x/ac51x/eng/ger/copy + `mp3`, `silence`; `dual`/`ac3eng`/`aaceng` entfernt)
- 2026-11-12: `ffmpeg_video_converter.cmd` neu (srt_extract/srt_burn/srt_merge/strip/gif/lut/mask/cut/join); `funvc.cmd` im bin
- 2026-11-12: `No files found.` und `[INFO] Savings`-Ausgaben aus Wrapper und Convertern entfernt
