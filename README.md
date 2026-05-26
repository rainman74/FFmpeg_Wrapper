# FFmpeg Wrapper

Batch-Videotranscoding-Wrapper für FFmpeg mit NVENC-Hardwareencoding, automatischer Crop-Erkennung, Qualitätsautomatik, Audio-Behandlung und Metadaten-Bereinigung. Abgeleitet vom [NVEncC64 Wrapper](https://github.com/rainman74/NVEncC64_Wrapper).

## Features

- **Auto-Crop** — Ermittelt schwarze Balken per `ffmpeg cropdetect` an 3 Zeitpunkten und mapped auf Standard-16:9-Resolutionen
- **Auto-Quality** — Wählt Qualitätsstufe anhand des Jahrzehnts im Dateinamen (`(19xx)` = hq, `(20xx)` = def)
- **Auto-Skip** — Bereits im Zielcodec vorliegende Dateien werden ohne Neukodierung verschoben
- **Audio-Encoding** — AC3, AAC, E-AC3 oder direkte Kopie (auch selektive Streams); dynamische Erkennung pro Stream
- **Videofilter** — Denoise, Sharpening, Upscaling, Deinterlacing, HDR→SDR u.v.m.
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
| Wert | Codec | Profil |
|------|-------|--------|
| `def` / `hevc` | HEVC (H.265) — hevc_nvenc | main |
| `he10` | HEVC (H.265) — hevc_nvenc | main10 |
| `h264` | H.264 — h264_nvenc | high |
| `av1` | AV1 — av1_nvenc | main |
| `av10` | AV1 — av1_nvenc | main |

#### audio (Position 2)
| Wert | Verhalten |
|------|-----------|
| `ac3` (default) | Dynamische Erkennung pro Stream: gleicher Codec → copy, sonst encoden (384k / 192k) |
| `aac` | Wie `ac3`, aber mit AAC-Bitraten (256k / 128k) |
| `eac3` | Wie `ac3`, aber mit E-AC3-Bitraten (640k / 320k) |
| `copy` | Alle Audiostreams unverändert kopieren |
| `copy1` | Nur Stream 1 kopieren |
| `copy2` | Nur Stream 2 kopieren |
| `copy12` | Streams 1 und 2 kopieren |
| `copy23` | Streams 2 und 3 kopieren |

#### quality (Position 3)
| Stufe | H.265 (hevc) | H.264 | AV1 |
|-------|-------------|-------|-----|
| `uhq` | 22 | 20 | 22 |
| `hq` | 24 | 22 | 24 |
| `def` (default) | 26 | 24 | 26 |
| `lq` | 28 | 26 | 28 |
| `ulq` | 30 | 28 | 30 |
| `auto` | auto | auto | Automatisch anhand Jahr im Dateinamen: `(19xx)` → hq, `(20xx)` → def, sonst def |

#### crop (Position 4)
**Automatisch:**
| Wert | Verhalten |
|------|-----------|
| `auto` | Führt `ffmpeg cropdetect` an 3 Zeitpunkten durch, ermittelt per Median schwarze Balken und mapped auf Standard-16:9-Resolutionen |
| `none` | Kein Crop |

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
| Wert | Effekt |
|------|--------|
| `none` | Kein Filter |
| `text` | Text einblenden (`drawtext`) |
| `reverb` | Rauschentfernung Audio (`afftdn`) |
| `deblock` | Leichtes Deblocking/Denoising (`hqdn3d`) |
| `edgelevel` | Kanten verstärken (`unsharp=0.5`) |
| `smooth` | Weichzeichner (`avgblur=3x3`) |
| `smooth31` | Starker Weichzeichner (`avgblur=31x31`) |
| `smooth63` | Extrem starker Weichzeichner (`avgblur=63x63`) |
| `nlmeans` | Non-local Means Denoise (`nlmeans`) |
| `gauss` | Gaußscher Weichzeichner (`gblur=sigma=1`) |
| `gauss5` | Starker Gaußscher Weichzeichner (`gblur=sigma=5`) |
| `sharp` | Schärfung (`unsharp=1.0`) |
| `denoise` | Zeitliches Denoising (`atadenoise`) |
| `denoisehq` | Hochwertiges Denoising (`dctdnoiz` + `atadenoise`) |
| `artifact` | Kompressionsartefakte reduzieren (`deblock=weak`) |
| `artifacthq` | Artefakte stark reduzieren (`deblock=strong`) |
| `superres` | Hochskalieren ×2 (Lanczos) |
| `superreshq` | Hochskalieren ×2 (Spline) |
| `ushrp` | Hochskalieren ×2 + Schärfen |
| `ushrpdenoise` | Hochskalieren + Schärfen + Denoise |
| `ushrpdenoisehq` | Hochskalieren + HQ-Denoise |
| `ushrpartifact` | Hochskalieren + Artefaktentfernung |
| `ushrpartifacthq` | Hochskalieren + starke Artefaktentfernung |
| `log` | Platzhalter (kein Filter) |
| `f1`–`f6` | Aliase = kein Filter |

#### mode (Position 6)
| Wert | Effekt |
|------|--------|
| `none` | Kein Spezialmodus |
| `deint` | Deinterlacing (BWDIF) |
| `yadif` | Deinterlacing (YADIF, Einzelfeld) |
| `yadifbob` | Deinterlacing (YADIF Bob, verdoppelt Framerate) |
| `double` | Frameverdopplung auf 60 fps (`minterpolate`) |
| `23fps` | FPS auf 23,976 erzwingen |
| `25fps` | FPS auf 25 erzwingen |
| `30fps` | FPS auf 30 erzwingen |
| `60fps` | FPS auf 60 erzwingen |
| `29fps` | FPS auf 29,97 erzwingen |
| `59fps` | FPS auf 59,94 erzwingen |
| `tweak` | Helligkeit/Kontrast/Gamma/Sättigung anpassen (`eq`) |
| `lighter` | Aufhellen (`eq=brightness=0.03`) |
| `darker` | Abdunkeln (`eq=brightness=-0.03`) |
| `vintage` | Curves Vintage-Look |
| `linear` | Lineare Curves (alle Kanäle) |
| `HDRtoSDR` | HDR→SDR (BT.2390 via zscale + tonemap) |
| `HDRtoSDRR` | HDR→SDR (Reinhard) |
| `HDRtoSDRM` | HDR→SDR (Mobius) |
| `HDRtoSDRH` | HDR→SDR (Hable) |
| `dv` / `dolby-vision` | Dolby-Vision Tonemapping (`libplacebo`) |

#### decoder (Position 7)
| Wert | Verhalten |
|------|-----------|
| `def` / `cuda` | Hardware-Decoder (`-hwaccel cuda -hwaccel_output_format cuda`) |
| `cuvid` | CUVID-Decoder (`-hwaccel cuvid`) |
| `sw` | Software-Decoder (kein Hardware-Beschleuniger) |
| `auto` | Automatische Decoderwahl (`-hwaccel auto`) |
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

Der Auto-Crop (`crop=auto`) funktioniert folgendermaßen:

1. **Probe**: `ffmpeg cropdetect` wird an 3 Zeitpunkten ausgeführt (00:02:00, 00:10:00, 00:20:00)
2. **Median**: Aus den Crop-Ergebnissen wird der Median gebildet
3. **Mapping**: Der ermittelte vertikale Crop wird auf eine Standard-16:9-Höhe gemappt:
   - 696px ↔ 192+192, 768px ↔ 156+156, 800px ↔ 140+140, …
   - 1080px ↔ 0+0 (kein Crop = Full HD)
4. **Asymmetrie-Erkennung**: Bei zu großen Abweichungen zwischen oberem und unterem Crop wird die Datei nach `_Check/` verschoben

Der Auto-Crop skaliert auf 1920px Breite. Horizontale Letterbox-Varianten (z.B. 2.35:1) werden auf passende Breiten gemapped.

## Metadaten-Bereinigung (Tag-Edit)

Nach der Kodierung werden automatisch MKV-Metadaten via `mkvpropedit` normalisiert:

- **Video-Track**: Sprache auf `und`, Default/Forced-Flags auf 0, Name gelöscht
- **Audio**: Erster deutscher Track (`ger`/`deu`) wird als Default markiert
- **Subtitles**: Forced-Tracks werden korrekt geflaggt (erster Forced-Track = Default+Forced)
- **Track-Namen**: Reine Sprachennamen (`Deutsch`, `English`), `Full` oder `SDH`/`Forced` werden normalisiert oder gelöscht

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
ffmpeg_wrapper hevc copy auto 1080 ushrp
```
HEVC, Audio Kopie, Auto-Qualität, Skalierung auf 1080p, Upscaling + Schärfen.

```cmd
ffmpeg_wrapper he10 copy hq 1080 gauss sw false
```
10-bit HEVC, Audio Kopie, hohe Qualität, Gauss-Weichzeichner, Software-Decoder, immer neu kodieren.

```cmd
ffmpeg_wrapper hevc eac3 auto auto ushrpdenoise auto false
```
HEVC, E-AC3-Audio, Auto-Qualität, Auto-Crop, Upscaling+Denoise, HW-Decoder, immer kodieren.

```cmd
ffmpeg_wrapper av1 aac lq 720p sharp
```
AV1, AAC-Audio, niedrige Qualität, 720p Höhen-skaliert, Schärfung.

```cmd
ffmpeg_wrapper hevc ac3 auto none none HDRtoSDR
```
HDR→SDR-Konvertierung mit BT.2390-Tonemapping.

## Täglicher Gebrauch

Für einen automatisierten Workflow empfiehlt sich ein minimaler Parametersatz. Der Wrapper übernimmt dann Qualitätsauswahl, Crop und Audio automatisch:

```cmd
ffmpeg_wrapper hevc ac3 auto auto
```

Neue Dateien im Verzeichnis werden damit einheitlich und ohne manuelle Eingriffe verarbeitet.

## Manual

Für weiterführende Fragen: [Wiki](https://github.com/rainman74/NVEncC64_Wrapper/wiki)

---

## Lizenz

Private use / experimental. No warranty.