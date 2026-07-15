# Balloon Shooting Game — FF12, Group 1

An 8086 assembly game built in EMU8086, where the player moves a shooter up/down and pops balloons drifting in from the right before too many get past.

**Deadline:** July 20



## Controls

| Key | Action |
|---|---|
| Up / Down arrow | Move the shooter |
| Space | Fire |
| Esc | Quit |

## How to run

1. Download and open [EMU8086](https://emu8086-microprocessor-emulator.en.softonic.com/) 
2. `File > Load` and select `src/balloon_shooter.asm`.
3. Click **Compile**, then **Emulate** to run it in the virtual PC window.
4. If the game runs too fast or too slow, adjust the delay loop constant near the bottom of the file (`delay proc`) and recompile.

## Repo structure

```
├── README.md                  this file
├── src/
│   └── balloon_shooter.asm    the game — Core coding team
├── tests/
│   └── test_log.md            bug/test log — Testing & QA team
├── docs/
│   ├── project_report.md      written report — Documentation team
│   ├── flowchart.png          game loop flowchart — Documentation team
│   └── contribution_log.md    who did what — Documentation team
├── extras/
│   └── feature_notes.md       bonus features writeup — Extras & demo team
└── presentation/
    ├── slides.pptx             Extras & demo team
    └── demo_recording.mp4      Extras & demo team
```

## Features

- Shooter movement, single-bullet firing, balloon spawn/movement, collision detection, score & miss tracking, simple hit sound.
