# 📝 Project Report: 8086 Balloon Shooting Game

**Course:** FF12 — Assembly Language Programming  
**Group:** Group 1  
**Project Name:** Retro Balloon Shooting Game  
**Target Architecture:** Intel 8086 Microprocessor (Real-Mode)  
**Development Environment:** EMU8086 Emulator  

---

## 1. Introduction & Objectives
The purpose of this project is to design, implement, and document a real-time arcade-style game utilizing low-level x86 Assembly language. 

### Key Objectives:
- **Low-Level Control:** Gain hands-on experience interfacing with system hardware registers and basic input/output subsystems.
- **BIOS/DOS Interrupts Integration:** Utilize system-provided software interrupts to handle text-mode rendering, cursor manipulation, precise system timing, and asynchronous keyboard polling.
- **Game Engine Architecture:** Design a lightweight, single-threaded game engine in assembly that coordinates user input, physics updates, collision detection, and screen rendering within a continuous loop.

---

## 2. Technical System Specifications
- **Processor Mode:** Intel 8086 16-bit real address mode.
- **Memory Model:** `Small` (Code fits in a 64KB segment; Data fits in a 64KB segment).
- **Stack Allocation:** `100h` (256 bytes) for call-stack frames, interrupt service routines, and register pushing/popping.
- **Display Subsystem:** Standard IBM PC BIOS Video Mode 3 (80x25 characters, 16-color color text mode).
- **Coordinate Space:** 
  - Horizontal Axis (Columns): `0` to `79`
  - Vertical Axis (Rows): `0` to `24`

---

## 3. Game Architecture & Core Flow
The game operates on a centralized **Game Loop** structure, executing subroutines sequentially in a continuous cycle until a terminating condition is met (reaching maximum misses or pressing the ESC key).

### System Block Diagram (Execution Flow):
```
       +---------------------------------------------+
       |             Initialize Program              |
       |  - Load Data Segment, Run show_title        |
       |  - Clear Screen, Draw static score frames  |
       +---------------------------------------------+
                              |
                              v
+======================= GAME LOOP =======================+
|                                                         |
|  +--------------------+      +-----------------------+  |
|  |    check_input     | ---> |    update_shooter     |  |
|  | - Poll buffer      |      | - Erase old position  |  |
|  | - Set fire/quit    |      | - Draw new position   |  |
|  +--------------------+      +-----------------------+  |
|                                          |              |
|                                          v              |
|  +--------------------+      +-----------------------+  |
|  |  check_collision   | <--- |     update_bullet     |  |
|  | - Check row match  |      | - Erase old position  |  |
|  | - Compare columns  |      | - Draw new position   |  |
|  +--------------------+      +-----------------------+  |
|            |                                            |
|            v                                            |
|  +--------------------+      +-----------------------+  |
|  |   update_balloon   | ---> |      draw_score       |  |
|  | - Move left        |      | - Refresh Scoreboard  |  |
|  | - Check boundary   |      +-----------------------+  |
|  +--------------------+                  |              |
|                                          v              |
|  +--------------------+      +-----------------------+  |
|  |       delay        | <--- |   Check Game Over     |  |
|  | - Busy-wait pacing |      | - Misses >= MAX_MISS? |  |
|  +--------------------+      +-----------------------+  |
|            |                                            |
+============|============================================+
             | (If Game Over / Escape Pressed)
             v
       +---------------------------------------------+
       |             Terminate Program               |
       |  - Display show_gameover screen             |
       |  - Restore control to DOS via INT 21h AH=4Ch|
       +---------------------------------------------+
```

---

## 4. Interrupts & System Services Table
The application relies heavily on software interrupts to execute system level input/output operations:

| Interrupt Vector | Service Command (`AH`) | Purpose | Registers / Parameters |
|---|---|---|---|
| **`INT 10h`** | `00h` | Set Video Mode | `AL = 03h` (Text mode 80x25) |
| **`INT 10h`** | `02h` | Set Cursor Position | `DH = Row`, `DL = Column`, `BH = Page Number (0)` |
| **`INT 21h`** | `02h` | Write Character to Standard Output | `DL = Character ASCII code` |
| **`INT 21h`** | `09h` | Write String to Standard Output | `DX = Offset of '$'-terminated string` |
| **`INT 16h`** | `01h` | Check Keyboard Status (Non-blocking status query) | Returns `ZF = 1` if no key; `ZF = 0` if key is waiting |
| **`INT 16h`** | `00h` | Read Keyboard Buffer (Extract key) | Returns `AL = ASCII Code`, `AH = Hardware Scan Code` |
| **`INT 1Ah`** | `00h` | Read System Time Clock | Returns ticks since midnight in `CX:DX` (lower word `DX` used as random seed) |

---

## 5. Memory Variables & Data Structure Layout
The game utilizes memory-mapped variables in the `.data` segment to persist state:

- **Shooter Variables:**
  - `shooter_row` (dw): Represents current vertical row of player.
  - `prev_shooter_row` (dw): Keeps track of previous position to perform cleanup/erasing.
- **Bullet Variables:**
  - `bullet_active` (db): Binary flag (1 = active, 0 = inactive).
  - `bullet_row` (dw), `bullet_col` (dw): Horizontal and vertical coordinates.
  - `prev_bullet_col` (dw): Tracks previous column coordinate for erasing.
- **Balloon Variables:**
  - `balloon_row` (dw), `balloon_col` (dw): Coordinates of the current target.
  - `prev_balloon_col` (dw): Track previous position for erasing.
  - `balloon_tick` (db): Loop iteration counter used to scale and slow down balloon movement.
- **Game Metrics:**
  - `score` (dw): Total count of popped balloons.
  - `misses` (dw): Total count of balloons reaching the left screen margin.
- **Key Buffers:**
  - `key_ascii` (db), `key_scan` (db): Stores input codes.
  - `key_available` (db): Flag indicating whether an unhandled key resides in memory.

---

## 6. Subroutine & Code Walkthrough

### 6.1 `clear_screen`
Initializes or resets the display adapter state. By requesting Mode `03h`, the memory buffer mapped to video memory (`0B800h`) is fully flushed.

### 6.2 `gotoxy`
Moves the text cursor. It takes input registers `DH` (row) and `DL` (column), shifts registers to conform to standard BIOS interrupts and executes `INT 10h` service code `02h`.

### 6.3 `print_char` & `print_string`
Direct DOS console interfaces. `print_char` writes a character in register `DL` to output. `print_string` takes a pointer in `DX` and prints everything up to a dollar sign delimiter (`$`).

### 6.4 `print_num`
Converts a binary numerical value in `AX` to visual ASCII representation. It repeatedly divides the register by base 10 (`BX = 10`), pushes the remainder onto the hardware stack, counts the decimal length, and pops and prints each digit sequentially.

### 6.5 `get_key` & `check_input`
Performs **non-blocking asynchronous keyboard reading**. Calling `INT 16h AH=01h` queries the keyboard buffer flag without locking execution. If `ZF = 0` (input exists), a secondary `INT 16h AH=00h` consumes the key and processes it:
- If key is Space (`20h`), fires bullet if not already active.
- If key is Up/Down arrow scan codes (`48h`/`50h`), moves shooter up or down.
- If key is Escape (`1Bh`), sets the quit flag.

### 6.6 `update_shooter`, `update_bullet`, `update_balloon`
These functions implement the **Draw-Erase mechanism**:
1. Go to the previous coordinate variable (`prev_*`).
2. Print a space `' '` to erase the trail.
3. Update the coordinate variables.
4. Go to the new coordinate and render the sprite character (`>`, `-`, or `O`).

### 6.7 `check_collision`
Monitors coordinates:
- Verifies that `bullet_active == 1`.
- Compares `bullet_row` with `balloon_row`.
- If equal, checks if `bullet_col >= balloon_col`.
- If matched, increments `score`, executes `INT 21h` with ASCII code `07h` (Beep), erases bullet, and calls `respawn_balloon`.

### 6.8 `random_row`
Generates a random row by reading the BIOS timer clock tick (`INT 1Ah`). Dividing the clock tick low word `DX` by the vertical play boundary height (`BOTTOM_ROW - TOP_ROW + 1 = 20`) via the `DIV` instruction yields a remainder in `DX` between `0` and `19`. Adding `TOP_ROW` (`3`) maps the coordinate to the valid playing range of `3` to `22`.

---

## 7. Key Programming Challenges & Resolutions

### 1. The Challenge of Real-Time Control in Assembly
*Problem:* Standard inputs like `INT 21h AH=01h` block execution, freezing the game updates until a key is pressed.  
*Solution:* Polled the keyboard buffer status beforehand using BIOS `INT 16h AH=01h`. This enables the game to skip inputs if nothing is pressed, keeping the balloon and bullet in constant motion.

### 2. Eliminating Graphic Trails (Ghosting)
*Problem:* Moving characters leave behind a trail of duplicates across the screen.  
*Solution:* Implemented coordinate double-buffering. The game logs coordinates before updating them, erases the previous coordinate with a space character (`' '`), updates the state, and draws the symbol in the new position.

---

## 8. Conclusion
The 8086 Balloon Shooting Game successfully demonstrates low-level system design, memory management, and hardware interrupt querying. By building the logic manually, we gained deep insight into register constraints, non-blocking polling, and modular system subroutines.
