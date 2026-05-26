# FFmpeg Wrapper

Batch-Videotranscoding-Wrapper für FFmpeg mit NVENC-Hardwareencoding, automatischer Croperkennung, dynamischer Audio-Wahl und Metadaten-Bereinigung.

Ursprünglich abgeleitet vom [NVEncC64 Wrapper](https://github.com/rainman74/NVEncC64_Wrapper), da FFmpeg keine eingebaute automatische Croperkennung bietet.

## Features

- **Auto-Crop** — Ermittelt schwarze Balken per `ffmpeg cropdetect` an 3 Zeitpunkten und mapped auf Standard-16:9-Resolutionen
- **Auto-Quality** — Wählt Qualitätsstufe anhand des Jahrzehnts im Dateinamen (`(19xx)` = hq, `(20xx)` = def)
- **Auto-Skip** — Bereits im Zielcodec vorliegende Dateien werden ohne Neukodierung verschoben
- **Dynamische Audio-Logik** — Jeder Audiostream wird einzeln per `ffprobe` analysiert: gleicher Codec → Kopie, sonst Encoding mit passender Bitrate
- **Videofilter** — Denoise, Sharpening, Upscaling, Deinterlacing, HDR→SDR, Dolby-Vision-Tonemapping u.v.m.
- **Tag-Bereinigung** — Automatische MKV-Metadaten-Normalisierung via `mkvpropedit`
- **Fehlerbehandlung** — Nicht analysierbare Dateien landen in `_Check/` zur manuellen Prüfung
- **Debug-Modus** — Detaillierte Ausgabe des Auto-Crop-Prozesses via `DEBUG_AUTOCROP=1`

## Voraussetzungen

Folgende Programme müssen im Pfad verfügbar sein:

```
ffmpeg.exe / ffprobe.exe
mediainfo.exe
mkvpropedit.exe / mkvmerge.exe
```

## Aufruf

```
ffmpeg_wrapper <encoder> [audio] [quality] [crop] [filter] [mode] [decoder] [chkenc]
```

| Pos | Parameter | Default | Beschreibung |
|-----|-----------|---------|--------------|
| 1 | **encoder** | (required) | Videoencoder |
| 2 | **audio** | `ac3` | Audiobehandlung |
| 3 | **quality** | `def` | Qualitätsstufe (CQ-Wert) |
| 4 | **crop** | `none` | Crop-Modus / Zielauflösung |
| 5 | **filter** | `none` | Videofilter (Nachbearbeitung) |
| 6 | **mode** | `none` | Spezialmodi (Deinterlace, FPS, HDR→SDR, Dolby Vision) |
| 7 | **decoder** | `cuda` | Hardware- oder Software-Decoder |
| 8 | **chkenc** | `true` | Bereits kodierte Dateien erkennen |

### Parameter-Details

#### encoder (Position 1)
| Wert | Codec | FFmpeg-Encoder | Profil |
|------|-------|---------------|--------|
| `def` / `hevc` | HEVC (H.265) | hevc_nvenc | main |
| `he10` | HEVC (H.265) | hevc_nvenc | main10 |
| `h264` | H.264 | h264_nvenc | high |
| `av1` | AV1 | av1_nvenc | main |
| `av10` | AV1 | av1_nvenc | main |

#### audio (Position 2)
| Wert | Verhalten |
|------|-----------|
| `ac3` (default) | Auto-Logik: jeden Stream einzeln prüfen — gleicher Codec → copy, sonst encoden (384k / 192k) |
| `aac` | Wie `ac3`, aber mit AAC-Bitraten (256k / 128k) |
| `eac3` | Wie `ac3`, aber mit E-AC3-Bitraten (640k / 320k) |
| `copy` | Alle Audiostreams unverändert kopieren |
| `copy1` | Nur ersten Audiostream (Index 0) kopieren |
| `copy2` | Nur zweiten Audiostream (Index 1) kopieren |
| `copy12` | Ersten beiden Streams separat kopieren |
| `copy23` | Zweiten und dritten Stream separat kopieren |

#### quality (Position 3)

Legt den CQ-Wert (Constant Quality) fest. Höher = niedrigere Bitrate = schlechtere Qualität.

| Stufe | H.265 (hevc) | H.264 | AV1 |
|-------|-------------|-------|-----|
| `uhq` | 22 | 20 | 22 |
| `hq` | 24 | 22 | 24 |
| `def` (default) | 26 | 24 | 26 |
| `lq` | 28 | 26 | 28 |
| `ulq` | 30 | 28 | 30 |
| `auto` | auto | auto | auto |

**`auto`** — erkennt das Jahr im Dateinamen: `(19xx)` → `hq`, `(20xx)` → `def`, sonst Fallback auf `def`.

#### crop (Position 4)
**Automatisch:**
| Wert | Verhalten |
|------|-----------|
| `auto` | Führt `ffmpeg cropdetect` an 3 Zeitpunkten durch, ermittelt per Median schwarze Balken und mapped auf Standard-16:9-Resolutionen |
| `none` | Kein Crop, keine Skalierung |

**Vertikaler Crop (schwarze Balken oben/unten entfernen, Zielbreite 1920):**
`696`, `768`, `800`, `804`, `808`, `812`, `816`, `872`, `960`, `1012`, `1024`, `1036`, `1040`

**Resolutionen (kein aktiver Crop, nur Skalierung):**
| Wert | Auflösung |
|------|-----------|
| `720` | 1280x-2 (Breite fix) |
| `720p` | -2x720 (Höhe fix) |
| `720f` | 1280x720 (fest) |
| `1080` | 1920x-2 (Breite fix) |
| `1080p` | -2x1080 (Höhe fix) |
| `1080f` | 1920x1080 (fest) |
| `2160` | 3840x-2 (Breite fix) |
| `2160p` | -2x2160 (Höhe fix) |
| `2160f` | 3840x2160 (fest) |

**Letterbox-Standards (1920x1080 Basis mit horizontalem Crop):**
`1440`, `1348`, `1420`, `1480`, `1500`, `1764`, `1780`, `1788`, `1792`, `1800`

**Aliase (alle = kein Crop):** `c1`, `c2`, `c3`, `c4`, `c5`, `c6`

#### filter (Position 5)
| Wert | FFmpeg-Filter | Effekt |
|------|---------------|--------|
| `none` | — | Kein Filter |
| `text` | `drawtext` | Text einblenden (Test) |
| `reverb` | `afftdn` | Rauschentfernung (Audio!) |
| `deblock` | `hqdn3d` | Leichtes Deblocking/Denoising |
| `edgelevel` | `unsharp=0.5` | Kanten verstärken |
| `smooth` | `avgblur=3x3` | Weichzeichner |
| `smooth31` | `avgblur=31x31` | Starker Weichzeichner |
| `smooth63` | `avgblur=63x63` | Extrem starker Weichzeichner |
| `nlmeans` | `nlmeans` | Non-local Means Denoise |
| `gauss` | `gblur=sigma=1` | Gaußscher Weichzeichner |
| `gauss5` | `gblur=sigma=5` | Starker Gaußscher Weichzeichner |
| `sharp` | `unsharp=1.0` | Schärfen |
| `denoise` | `atadenoise` | Zeitliches Denoising |
| `denoisehq` | `dctdnoiz` + `atadenoise` | Hochwertiges Denoising |
| `artifact` | `deblock=weak` | Kompressionsartefakte reduzieren |
| `artifacthq` | `deblock=strong` | Artefakte stark reduzieren |
| `superres` | `scale=lanczos` ×2 | Hochskalieren ×2 (Lanczos) |
| `superreshq` | `scale=spline` ×2 | Hochskalieren ×2 (Spline) |
| `ushrp` | `scale` ×2 + `unsharp` | Hochskalieren ×2 + Schärfen |
| `ushrpdenoise` | ×2 + unsharp + atadenoise | Hochskalieren + Schärfen + Denoise |
| `ushrpdenoisehq` | ×2 + unsharp + dctdnoiz + atadenoise | Hochskalieren + HQ-Denoise |
| `ushrpartifact` | ×2 + unsharp + deblock | Hochskalieren + Artefaktentfernung |
| `ushrpartifacthq` | ×2 + unsharp + deblock(strong) | Hochskalieren + starke Artefaktentfernung |
| `log` | — | Platzhalter (kein Filter) |
| `f1`–`f6` | — | Platzhalter (kein Filter) |

#### mode (Position 6)
| Wert | FFmpeg-Filter | Effekt |
|------|---------------|--------|
| `none` | — | Kein Modus |
| `deint` | `bwdif` | Deinterlacing (BWDIF) |
| `yadif` | `yadif=0` | Deinterlacing (YADIF, Einzelfeld) |
| `yadifbob` | `yadif=1` | Deinterlacing (YADIF, 2× Bildrate/Bob) |
| `double` | `minterpolate=fps=60` | Frameverdopplung auf 60 fps |
| `23fps` | `fps=23.976` | FPS auf 23,976 setzen |
| `25fps` | `fps=25` | FPS auf 25 setzen |
| `30fps` | `fps=30` | FPS auf 30 setzen |
| `60fps` | `fps=60` | FPS auf 60 setzen |
| `29fps` | `fps=29.97` | FPS auf 29,97 setzen |
| `59fps` | `fps=59.94` | FPS auf 59,94 setzen |
| `tweak` | `eq` | Helligkeit/Kontrast/Gamma/Sättigung anpassen |
| `lighter` | `eq=brightness=0.03` | Aufhellen |
| `darker` | `eq=brightness=-0.03` | Abdunkeln |
| `vintage` | `curves=vintage` | Vintage-Look |
| `linear` | `curves` | Linearer Kontrast |
| `HDRtoSDR` | zscale + tonemap(bt2390) | HDR→SDR Konvertierung |
| `HDRtoSDRR` | zscale + tonemap(reinhard) | HDR→SDR (Reinhard) |
| `HDRtoSDRM` | zscale + tonemap(mobius) | HDR→SDR (Mobius) |
| `HDRtoSDRH` | zscale + tonemap(hable) | HDR→SDR (Hable) |
| `dv` / `dolby-vision` | `libplacebo=tonemapping=bt2390` | Dolby-Vision Tonemapping |

#### decoder (Position 7)
| Wert | Decoder |
|------|---------|
| `def` / `cuda` | `-hwaccel cuda -hwaccel_output_format cuda` |
| `cuvid` | `-hwaccel cuvid` |
| `sw` | Kein Hardware-Decoder (reine Software) |
| `auto` | `-hwaccel auto` |
| `vp8` | CUVID + vp8\_cuvid |
| `vp9` | CUVID + vp9\_cuvid |
| `vpx` | CUVID + libvpx |
| `mpeg2` | CUVID + mpeg2\_cuvid + adaptives Deinterlacing |

#### chkenc (Position 8)
| Wert | Verhalten |
|------|-----------|
| `def` / `true` (default) | Prüft, ob Quelle bereits im Zielcodec vorliegt → überspringt Neukodierung |
| `false` | Immer neu kodieren |

## Auto-Crop im Detail

Das Herzstück — eine in PowerShell eingebettete Analyse, die schwarze Balken (Letterbox/Pillarbox) erkennt und automatisch entfernt.

### Ablauf

1. **ffprobe** ermittelt Breite × Höhe der Quelle
2. **ffmpeg cropdetect** wird an 3 Zeitpunkten ausgeführt (00:02:00, 00:10:00, 00:20:00) mit je 5s Probe
3. **Median** der ermittelten Crop-Werte wird berechnet
4. **Entscheidungslogik**:
   - Weniger als 4px vertikal / 10px horizontal → kein Crop (`0:0:0:0`)
   - Vertikal symmetrisch (max. 10px Differenz) → Matching auf Standard-Letterbox-Höhen (696, 768, 800, …, 1040)
   - Horizontales Letterbox (z. B. 4:3 Inhalt in 16:9) → Matching auf Standardbreiten (1348–1800)
   - Asymmetrische oder einseitige schwarze Balken → Datei wird nach `_Check\` verschoben (manuelle Prüfung)
5. **Ergebnis** wird als Batch-Variablen (`NVEnc_Crop`, `NVEnc_Res`) an den Hauptprozess zurückgegeben

### Unterstützte Crop-Profile

**Letterbox (vertikal)** — 1920px Breite:
| Höhe | Crop |
|------|------|
| 696 | `0:192:0:192` |
| 768 | `0:156:0:156` |
| 800 | `0:140:0:140` |
| 804 | `0:138:0:138` |
| 808 | `0:136:0:136` |
| 812 | `0:134:0:134` |
| 816 | `0:132:0:132` |
| 872 | `0:104:0:104` |
| 960 | `0:60:0:60` |
| 1012 | `0:34:0:34` |
| 1024 | `0:28:0:28` |
| 1036 | `0:22:0:22` |
| 1040 | `0:20:0:20` |
| 1080 | `0:0:0:0` |

**Pillarbox (horizontal)** — 1080px Höhe:
| Breite | Crop |
|--------|------|
| 1348 | `286:0:286:0` |
| 1420 | `250:0:250:0` |
| 1440 | `240:0:240:0` |
| 1480 | `220:0:220:0` |
| 1500 | `210:0:210:0` |
| 1764 | `78:0:78:0` |
| 1780 | `70:0:70:0` |
| 1788 | `66:0:66:0` |
| 1792 | `64:0:64:0` |
| 1800 | `60:0:60:0` |

## Dynamische Audio-Logik

Wenn `audio=ac3`/`aac`/`eac3` gesetzt ist, wird jeder Audiostream einzeln per `ffprobe` analysiert:

- Gleicher Codec wie Ziel → `-c:a:N copy`
- Anderer Codec → encoden mit passender Bitrate:
  - ≤ 2 Kanäle: niedrige Bitrate (192k / 128k / 320k)
  - > 2 Kanäle: hohe Bitrate (384k / 256k / 640k)

## Metadaten-Bereinigung (Tag-Edit)

Nach der Kodierung werden automatisch MKV-Metadaten via `mkvpropedit` normalisiert:

- **Video-Track**: Sprache auf `und`, Default/Forced-Flags auf 0, Name gelöscht
- **Audio**: Erster deutscher Track (`ger`/`deu`) wird als Default markiert
- **Subtitles**: Forced-Tracks werden korrekt geflaggt (erster Forced-Track = Default+Forced)
- **Track-Namen**: Reine Sprachennamen (`Deutsch`, `English`), `Full` oder `SDH`/`Forced` werden normalisiert oder gelöscht
- **Global**: `--delete title` entfernt den Movie-Title aus den Metadaten

## Debug-Modus

```cmd
set "DEBUG_AUTOCROP=1"
```

Aktiviert detaillierte Ausgabe der Crop-Erkennung, FFmpeg-Parameter und Zwischenergebnisse.

## Arbeitsablauf

1. Alle Videodateien im aktuellen Ordner werden nacheinander verarbeitet
2. Pro Datei: Codec-Prüfung → ggf. Auto-Crop → Encoding nach `_Converted/<name>.mkv`
3. Nach Encoding: 5s Pause, dann nächste Datei
4. Am Ende: Anzeige der Speicherersparnis (komprimierte vs. originale Größe)

## Fehlerbehandlung

- **Unbekannter Codec** → Datei wird nach `_Check/` verschoben
- **Crop-Probe fehlgeschlagen** → Datei wird nach `_Check/` verschoben
- **Asymmetrische schwarze Balken** → Datei wird nach `_Check/` verschoben
- **Quelle zu klein** (< 1280×696) → Datei wird nach `_Check/` verschoben
- **FFmpeg-Fehler** → Skript bricht ab (exit /b errorlevel)
- **Tag-Edit fehlgeschlagen** → Datei wird nach `_Check/` verschoben

## Beispiele

```cmd
ffmpeg_wrapper hevc ac3
```
Standard: HEVC, AC3-Audio, Qualität def, kein Crop, kein Filter.

```cmd
ffmpeg_wrapper hevc ac3 auto auto
```
Automatische Qualität (anhand Jahreszahl) + automatischer Crop.

```cmd
ffmpeg_wrapper hevc copy hq 1080 ushrp
```
HEVC, Audio Kopie, hohe Qualität, Skalierung auf 1080p, Upscaling + Schärfen.

```cmd
ffmpeg_wrapper hevc ac3 auto auto none none sw false
```
HEVC, AC3-Audio, Auto-Qualität, Auto-Crop, Software-Decoder, immer kodieren.

```cmd
ffmpeg_wrapper av1 eac3 def none denoise deint cuda true
```
AV1, E-AC3-Audio, Qualität def, Denoising, Deinterlacing, CUDA-Hardware-Decoder.

```cmd
ffmpeg_wrapper hevc copy auto auto none HDRtoSDR
```
HDR→SDR-Konvertierung mit BT.2390-Tonemapping.

## Täglicher Gebrauch

Für einen automatisierten Workflow empfiehlt sich ein minimaler Parametersatz. Der Wrapper übernimmt dann Qualitätsauswahl, Crop und Audio automatisch:

```cmd
ffmpeg_wrapper hevc ac3 auto auto
```

Neue Dateien im Verzeichnis werden damit einheitlich und ohne manuelle Eingriffe verarbeitet.

---

## Lizenz

Private Nutzung / experimentell. Keine Garantie.