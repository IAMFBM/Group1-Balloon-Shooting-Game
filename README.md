# Balloon Shooting Game

An 8086 real-mode assembly language game written and tested in EMU8086. The player controls a shooter that moves vertically and fires bullets at balloons drifting across the screen.

**Course:** FF12 — Group 1

## How to Run

1. Open EMU8086
2. File > Load `src/balloon_shooter.asm`
3. Click **Compile**
4. Click **Emulate**

## Controls

| Key | Action |
|-----|--------|
| UP / DOWN | Move shooter |
| SPACE | Fire bullet |
| ESC | Quit |

## Game Rules

- A balloon spawns on the right side of the screen and drifts left
- Shoot it before it reaches the left edge
- Each hit adds to your score
- Each miss (balloon reaches the left) counts against you
- 5 misses = game over

## Project Structure

```
src/            Assembly source code
docs/           Project report
extras/         Feature notes and presentation slides
test/           Test logs
```

- Member 5
