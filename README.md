# NVEncC64_Wrapper

Since [rigaya's](https://github.com/rigaya) excellent [NVEncC64](https://github.com/rigaya/NVEnc) encoder unfortunately does not have an automatic cropping function, and this is only rudimentary in FFmpeg, I have extended my wrapper and added this function.

## Simply calling the wrapper without parameters shows the usage:
```
Usage: nvencc64_wrapper <encoder(hevc)> <audio(ac3)> <quality(28)> <crop> <filter> <mode> <decoder(avhw)>

encoder = [def|hevc|he10|h264|av1]
audio   = [copy(1/2/12)|ac3(lq)|aac(lq)|eac3(lq)]
quality = [def|auto|lq|ulq|hq|uhq]
crop    = [copy|auto|c(1-6)|696|768|800|804|808|812|816|872|960|1012|1024|1036|1040|720(f/p)|1080(f/p)|2160(f/p)]
          [1440|1348|1420|1480|1500|1792|1764|1780|1788|1800]
filter  = [copy|f(1-6)|edgelevel|smooth(31/63)|nlmeans|gauss(5)|sharp|ss|denoise(hq)|artifact(hq)|superres(hq)]
          [vsr|vsrdenoise(hq)|vsrartifact(hq)]
mode    = [copy|deint|yadif(bob)|double|23fps|25fps|30fps|60fps|29fps|59fps]
          [brighter|darker|vintage|linear|tweak|HDRtoSDR(R/M/H)|dv/dolby-vision]
decoder = [def|hw|sw]

Example: nvencc64_wrapper | encoder | audio | quality | crop | filter | mode | decoder |
Example: nvencc64_wrapper   hevc      ac3
Example: nvencc64_wrapper   hevc      ac3     auto      auto
Example: nvencc64_wrapper   hevc      copy    auto      1080   vsr
Example: nvencc64_wrapper   hevc      copy    hq        1080   copy
Example: nvencc64_wrapper   hevc      copy    def       copy   copy     copy   sw
```

## Preparations:
### FFmpeg and FFprobe
The _absolute paths_ need to be adjusted beforehand for the both ffmpeg applications:<br>
```
$ffmpegCmd = "D:\Apps\ffmpeg.exe"
$ffprobeCmd = "D:\Apps\ffprobe.exe"
```
### GNU sed
Install GNU sed version 4.0.7 or higher in your path or simply comment out the line containing sed.
## Enable automatic cropping:
You can activate auto-cropping for all files in the current path:
C:\>nvencc64_wrapper.cmd hevc ac3 **auto** **auto**
The first **auto** parameter enables automatic quality upgrade based on the year (for older films which generally have more pronounced film grain).
The second **auto** parameter activates auto-cropping.
## Hints:
- To display debug output and see how auto-cropping works, use: set "DEBUG_AUTOCROP=1" otherwise "DEBUG_AUTOCROP=0"
- Error handling is also implemented in exceptional cases where no valid crop values ​​could be determined.
- Completed encoded files are saved to the "_Converted" folder; the original files are not deleted.
- Files with inconsistent black borders are not encoded and are immediately moved to the "_Check" folder for further manual review.
