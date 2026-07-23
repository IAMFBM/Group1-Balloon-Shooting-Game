# 🎈 Balloon Shooting Game

An **8086 real-mode assembly language game** written and tested for the **EMU8086 microprocessor emulator**. The player controls a vertical shooter (`>`) and fires bullets (`-`) to pop balloons (`O`) drifting across the screen from right to left.

**Course:** FF12 — Group 1

---

## 🛠️ How to Run

1. Download and open **EMU8086**.
2. Go to `File > Load` and select `src/balloon_shooter.asm`.
3. Click **Compile** to generate the binary.
4. Click **Emulate** to launch the emulator interface.
5. In the Emulation window, click **Run** (or press key shortcuts) to start playing.
6. *Optional:* If the game runs too fast/slow on your machine, adjust the outer counter value in the `delay` procedure (around line 500 in `src/balloon_shooter.asm`) and recompile.

---

## 🎮 Controls & Gameplay Mechanics

### Controls Table
| Key | Action | Technical Key/Scan Code |
|-----|--------|--------------------------|
| **UP ARROW** | Move shooter up | Scan Code `48h` |
| **DOWN ARROW** | Move shooter down | Scan Code `50h` |
| **SPACEBAR** | Fire a bullet | ASCII Code `20h` |
| **ESC** | Quit Game | ASCII Code `1Bh` |

### Core Mechanics
- **Player (Shooter):** Represented by the `>` character. Locked horizontally at column `5` (`SHOOTER_COL`). Can move vertically between row `3` (`TOP_ROW`) and row `22` (`BOTTOM_ROW`).
- **Bullet:** Represented by `-`. When fired, spawns at the shooter's row. Moves right at a rate of 2 columns per frame. Retires when reaching column `75` (`RIGHT_COL`). Only one bullet can be active at a time.
- **Balloon:** Represented by `O`. Spawns at a random vertical row (between `TOP_ROW` and `BOTTOM_ROW`) on the rightmost column (`RIGHT_COL`). Moves left 1 column every 2 frames (slower than the bullet).
- **Collision:** Checked every frame. If a bullet and balloon occupy the exact same row and the bullet's column is greater than or equal to the balloon's column, a hit is registered.
- **Scoring & Misses:**
  - **Hit:** Increments the score, triggers a speaker beep sound (`07h`), and respawns the balloon.
  - **Miss:** Occurs when a balloon reaches the shooter's column (`SHOOTER_COL`) unhit. Increments the misses count.
  - **Game Over:** Reaching 5 misses (`MAX_MISSES`) triggers the Game Over screen.

---

## 📂 Project Structure

```
├── README.md                  # Comprehensive project documentation (this file)
├── src/
│   └── balloon_shooter.asm    # Main 8086 Assembly source code
├── docs/
│   └── project_report.md      # Written project report
├── extras/
│   ├── feature_notes.md       # Bonus feature suggestions & enhancement notes
│   └── presentation/          
│       └── slides.pptx         # Team presentation slides
└── test/
    └── test_log.md            # Test log and debugging notes
```

---

## 💻 Detailed Assembly Code Documentation

This project uses standard **8086 Assembly Language** in real-mode and interacts directly with the PC BIOS interrupts for screen positioning, drawing, timing, and keyboard input.

### 1. Program Memory Model
```assembly
.model small
.stack 100h
```
- `.model small`: Configures the memory model where code fits in a single 64KB segment, and data fits in a single 64KB segment.
- `.stack 100h`: Allocates a 256-byte stack segment for subroutine calls and local register preservation.

### 2. Video System & Coordinate Drawing
The game runs in the BIOS standard 80x25 text mode (Mode 3). The coordinate space uses `(column, row)` where:
- Columns range from `0` to `79` (X-axis).
- Rows range from `0` to `24` (Y-axis).

Direct screen updates are handled using cursor movement followed by text rendering:
- **`clear_screen`**: Sets video mode `03h` via BIOS interrupt `INT 10h` (`AH = 00h`, `AL = 03h`). This resets the screen buffer and clears it.
- **`gotoxy`**: Sets the cursor position using BIOS interrupt `INT 10h` (`AH = 02h`), where `DH` stores the row and `DL` stores the column.
- **`print_char`**: Displays a single character at the current cursor position via DOS interrupt `INT 21h` (`AH = 02h`), passing the character in `DL`.
- **`print_string`**: Outputs a string ending with `$` using DOS interrupt `INT 21h` (`AH = 09h`), passing the address offset in `DX`.

### 3. Non-Blocking Input Subsystem
In a real-time game, blocking input (waiting for a key press) is unacceptable because the balloon and bullet must move even when the player doesn't press anything.
- **`get_key`** uses BIOS interrupt `INT 16h` with `AH = 01h` (Check Keyboard Status).
  - If the **Zero Flag (ZF)** is `1`, no key is in the buffer. The function returns immediately (`key_available = 0`).
  - If **ZF** is `0`, a key is waiting. The function calls `INT 16h` with `AH = 00h` to read it out of the buffer, storing the ASCII code in `AL` (saved to `key_ascii`) and the hardware Scan Code in `AH` (saved to `key_scan`), then sets `key_available = 1`.
- **`check_input`** evaluates this key state:
  - If `ESC` (`1Bh`) is pressed, `quit_flag` is set.
  - If `Space` (`' '`) is pressed, `fire_now` is set to trigger bullet creation.
  - If `Up Arrow` (Scan Code `48h`) or `Down Arrow` (Scan Code `50h`) is pressed, it adjusts `shooter_row` after checking boundaries.

### 4. Game Object Physics & Updates
- **Double Buffering (Draw-Erase Logic):**
  To prevent leaving trails on the screen, objects must erase their old positions before moving.
  - `prev_shooter_row`, `prev_bullet_col`, and `prev_balloon_col` store the coordinates from the previous frame.
  - Every frame, a space character (`' '`) is printed at the previous coordinate, and the object's symbol (`>`, `-`, or `O`) is printed at the new coordinate.
- **Throttling (Speed Regulation):**
  - The game loop runs very fast. If the balloon moved every frame, it would fly across the screen instantly.
  - The balloon's speed is regulated using `balloon_tick`. The coordinate updates only when `balloon_tick` reaches `2` (every second tick), reducing its speed relative to the bullet.

### 5. Random Spawn System (`random_row`)
Balloons must spawn at random heights to keep the game interesting.
1. The game calls BIOS system time interrupt `INT 1Ah` (`AH = 00h`).
2. This returns the clock tick count in `CX:DX` (representing ticks since midnight).
3. The lower word (`DX`) is moved into `AX`.
4. We divide `AX` by the range of active rows: `BOTTOM_ROW - TOP_ROW + 1` (which is `20`).
5. The remainder (`DX`) from the division (`DIV`) represents a number between `0` and `19`.
6. Adding `TOP_ROW` (`3`) shifts this number to the valid range: `3` to `22`.

### 6. Collision Resolution (`check_collision`)
- Collision is checked on every game loop iteration.
- A collision is active only if a bullet is currently on screen (`bullet_active == 1`).
- The code compares `bullet_row` and `balloon_row`. If they do not match, collision is impossible.
- If the rows match, it checks if `bullet_col >= balloon_col`. If true, the bullet has reached or passed the balloon.
- **Action on collision:**
  - Erases the bullet sprite.
  - Triggers the system bell (`INT 21h`, character `07h`), which commands the hardware speaker to beep.
  - Increments `score`.
  - Respawns the balloon at `RIGHT_COL` at a new random row.
  - Sets `bullet_active = 0` to allow the player to fire again.

---

## 🎓 Project Defense Cheat Sheet (Q&A)

Prepare for your project presentation by understanding these common questions:

### Q1: How does your game implement real-time movement without pausing for keyboard input?
> **Answer:** We use **non-blocking keyboard polling**. Instead of calling standard input functions (which pause the CPU until a key is pressed), we call BIOS Interrupt `INT 16h` with `AH = 01h`. This checks the keyboard buffer status flags. If no key has been pressed, the Zero Flag (ZF) is set, and we jump immediately to updating the physics. If ZF is cleared, we use `INT 16h` with `AH = 00h` to extract the key and act on it without stalling.

### Q2: How is the random row generation implemented?
> **Answer:** We read the system clock using BIOS Interrupt `INT 1A` (`AH = 00h`), which returns the system ticks in registers `CX` and `DX`. We use the low-order register `DX` as a pseudo-random seed. We divide this seed by the height of our playing field (20 rows) using the `DIV` instruction and add the top-row offset (`3`) to the remainder (`DX`). This guarantees a random row coordinate between `3` and `22`.

### Q3: Why do characters on the screen not leave trails when they move?
> **Answer:** Before updating the position of the shooter, bullet, or balloon, we store their current coordinates in "previous" variables (`prev_shooter_row`, `prev_bullet_col`, etc.). In the next frame, we move the cursor to those previous coordinates and write a blank space character (`' '`) to clear them, then draw the character at the new coordinate.

### Q4: How is collision detected between the bullet and the balloon?
> **Answer:** Inside `check_collision`, we verify two conditions:
> 1. The bullet and balloon must share the exact same row (`bullet_row == balloon_row`).
> 2. The bullet's column must be equal to or greater than the balloon's column (`bullet_col >= balloon_col`).
> If both match, it triggers a hit.

### Q5: How do you trigger the hit sound effect?
> **Answer:** We print the ASCII Bell character (`07h`) using DOS interrupt `INT 21h` (`AH = 02h`). When the operating system console receives this code, it signals the motherboard speaker or emulator to play a default system beep.
