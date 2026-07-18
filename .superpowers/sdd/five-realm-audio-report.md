# Five-realm audio report

## Deliverable

Four 32.000 s stereo, 22.05 kHz Vorbis loops were rendered locally and added
under `assets/audio/`. All streams are set to loop by the importer and again by
`AudioManager` at runtime. The OGGs total 367,537 bytes (0.35 MiB), leaving a
large margin under the 70 MiB APK budget.

| track | bytes | mean | peak | join delta |
| --- | ---: | ---: | ---: | ---: |
| frost_ambient | 81,069 | -27.8 dB | -17.6 dB | 0.00110 FS |
| frost_boss | 97,873 | -27.1 dB | -15.3 dB | 0.00504 FS |
| abyss_ambient | 85,094 | -25.9 dB | -17.0 dB | 0.00000 FS |
| abyss_boss | 103,501 | -25.5 dB | -13.9 dB | 0.00266 FS |

`join delta` is the decoded final-sample/first-sample absolute difference;
each render has an integer-cycle 32-second design, including all modulation.
The highest decoded peak is -13.9 dBFS, so the material has substantial phone-
speaker and crossfade headroom.

## Synthesis

The render is deterministic (Python standard library, seed 1729), 32 seconds,
stereo PCM at 22.05 kHz, then `ffmpeg -c:a libvorbis -q:a 3`.

- Frost: 41.25/61.875 Hz ice drones, subdued 82.5 Hz choir, slow modulation,
  and decaying 523.125/659.375/783.75 Hz celesta fragments. Boss adds a soft
  96 BPM pulse and dissonant partials.
- Abyss: 36.5625/54.84375 Hz bronze drones, hull resonance and periodic
  descending bubbles. Boss adds a 60 BPM double leviathan heartbeat and an
  eight-step ritual ostinato.
- Final amplitude uses gentle `tanh` saturation at 0.62 full scale. All event
  tails end well before the loop join; no external packages or network assets
  were used.

## Verification

Commands run:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --import
Godot_v4.7.1-stable_win64_console.exe --headless --path . tests/audio_test.tscn
Godot_v4.7.1-stable_win64_console.exe --headless --path . tests/campaign_test.tscn
.\tools\validate_release.ps1 -ProjectRoot .
ffprobe -v error -show_entries format=duration,size ...
ffmpeg -i <track> -af volumedetect -f null -
```

Results: `audio_test` 22/22, `campaign_test` 114/114, and release budgets
passed (APK was not present, so its size was reported rather than measured).
Audio tests cover OGG resource loading, loop flag, audible area battle route,
Frost/Abyss boss crossfade, and the pre-existing true-mute behavior.
