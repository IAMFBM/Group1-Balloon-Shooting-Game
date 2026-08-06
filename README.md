# 🎈 Balloon Shooting Game

A classic top-down Balloon Shooting Game implemented purely in Assembly Language! 

This repository contains two distinct versions of the game, demonstrating the evolution of Assembly Language from old-school 16-bit MS-DOS graphics to modern 64-bit native Windows programming.

---

## 🎮 The Games

### 1. The 64-bit Windows Console Version (`balloon64.asm`)
This is the primary, modern port of the game. It runs natively on modern computers and implements advanced mechanics like a persistent leaderboard.

- **Architecture**: 64-bit x64 Assembly.
- **Calling Convention**: Microsoft x64 Calling Convention (using 32-byte shadow space and 16-byte stack alignment).
- **Graphics**: Windows Console API. Instead of drawing raw pixels, it leverages the Console's character buffer to draw a Colored ASCII representation of the game.
- **Features**: 
  - **Multi-Bullet Rapid Fire**: Supports up to 10 independent bullets on screen simultaneously with a custom array-based object manager.
  - **Dynamic Difficulty**: The game scales in speed (player moves faster, balloons fall faster) every 5 points you score.
  - **Persistent Leaderboard**: Accepts keyboard input, creates/writes to a file (`leaderboard.txt`), and dynamically reads the file upon death to display High Scores directly in the console.
  - Interfaces directly with the modern Windows Operating System via `kernel32.dll`. 
  - Does not use any DOS interrupts, making it a true 64-bit executable.

### 2. The 16-bit MS-DOS Version (`balloon.asm`)
A retro-style game using raw BIOS interrupts and hardware VGA graphics.

- **Architecture**: 16-bit Real Mode x86 Assembly.
- **Graphics**: Hardware VGA Mode 13h (320x200 resolution, 256 colors). It writes pixels directly to video memory (`0xA000`).
- **Features**: 
  - **Zero-Flicker Double Buffering**: Allocates a 64KB off-screen canvas at the end of the `.com` executable footprint and uses an ultra-fast string instruction (`rep movsw`) during the hardware VBLANK cycle to completely eliminate flickering.
  - **Circular Sprites**: Uses a custom 15x15 binary matrix and rendering subroutine to draw perfectly round balloons with transparent corners.
  - **Multi-Bullet Rapid Fire**: Allows you to shoot a continuous stream of bullets using an array loop.
  - **BIOS Font Rendering**: Uses `int 10h, AH=13h` to draw a crisp `"SCORE: XXX"` UI overlay *after* the pixel buffer is blitted.
  - **Game Over & Retry Loop**: Instead of crashing or exiting to DOS, getting hit (or letting a balloon hit the ground) suspends physics and allows you to press `R` to retry instantly.
- **Environment**: Must be run in an emulator like **EMU8086** or **DOSBox**.

---

## 🕹️ Gameplay & Controls

You control a ship at the bottom of the screen and must shoot down the falling balloons before they crash into you or reach the ground!

### Controls Table
| Key | Action | Technical Mechanism |
|-----|--------|--------------------------|
| **Left / Right Arrow Keys** | Move ship horizontally | Handled via Windows `GetAsyncKeyState` (64-bit) or `int 16h` (16-bit) |
| **Spacebar (Hold)** | Rapid Fire bullets | Spawns bullet objects that travel upwards independently |
| **Esc** | Quit Game | Exits the game cleanly |
| **R** | Retry Game | Resets game variables inside the Game Over loop |

### The Leaderboard System (64-bit Version)
If you score at least 1 point before dying, the game enters a **Name Entry State**:
1. You can type up to 8 characters using the **A-Z** keys (with working **Backspace**).
2. Pressing **Enter** converts your binary score to an ASCII string (using a custom `itoa` subroutine).
3. The game calls `CreateFileA` and `WriteFile` to append your Name and Score to `leaderboard.txt`.
4. It immediately calls `ReadFile` to read the bottom of the text file, rendering the High Scores to the console using a custom multi-line string drawing subroutine.

---

## 🛠️ How to Compile & Run

### Running the 64-bit Version (`balloon64.asm`)
*Note: You do not need DOSBox or EMU8086 for this!*
1. Open your Windows Start Menu and launch the **x64 Native Tools Command Prompt for VS** (Installed with Visual Studio Build Tools).
2. Navigate to the folder containing the source code.
3. Compile and link the code using the Microsoft Macro Assembler (`ml64.exe`):
   ```cmd
   ml64.exe /c /Cx balloon64.asm
   link.exe /SUBSYSTEM:CONSOLE /ENTRY:main balloon64.obj kernel32.lib user32.lib
   ```
4. Run the newly generated `balloon64.exe` file directly from your command prompt!

### Running the 16-bit Version (`balloon.asm`)
1. Download and install **EMU8086** (or MASM).
2. Open `balloon.asm` in EMU8086.
3. Click the **Compile** button to assemble it into a `.com` executable.
4. For the best performance (perfect 70 FPS), open **DOSBox**, mount the folder containing the compiled `.com` file, and run it.

---

## 💻 Detailed Assembly Code Documentation (64-bit Version)

### 1. Non-Blocking Input
Instead of waiting for the user to press a key (which would freeze the falling balloons), the 64-bit version uses `GetAsyncKeyState` from the Windows API. 
We test the Most Significant Bit (`test ax, 8000h`) returned by this function, which tells us if a key is currently held down. This provides a clean input stream perfect for typing a name or moving a ship.

### 2. Double Buffering & Rendering
To prevent flickering in the console, the game uses an off-screen buffer (`screen_buf`). 
- Every frame, `clear_buffer` resets this 2000-character array to blank spaces.
- The player, bullets, and balloons are drawn into this buffer array manually using pointer arithmetic (e.g. `Y * 80 + X`).
- Finally, the entire buffer is blasted to the screen at once using the `WriteConsoleOutputA` Windows API.

### 3. Collision Detection
The game checks every frame if the bullets' X/Y coordinates overlap with the balloon's coordinates. Because the balloon is 3 characters wide (`OOO`), the collision logic checks if the bullet is anywhere between the balloon's `Left X` and `Right X` (which is `Left X + 2`).

### 4. File I/O
Assembly lacks standard libraries (like `printf` or `fprintf`). To write to the leaderboard:
1. `CreateFileA` opens `leaderboard.txt` in append mode.
2. The score is converted from a binary integer to text characters using a custom division loop (`itoa`).
3. `WriteFile` pushes the string buffer to the hard drive.
4. `CloseHandle` releases the file lock. 
To display the leaderboard, the game uses `SetFilePointer` to seek to the end of the file and reads the last 511 bytes to ensure only the most recent high scores are displayed on the Game Over screen.

### 5. Overcoming 64-bit Addressing Limitations
When migrating from 16/32-bit x86 to 64-bit x64, using standard scale-index-base addressing on global data variables (e.g. `mov rax, [bullet_x + rbx*8]`) results in `error LNK2017: 'ADDR32' relocation invalid` because the Microsoft Linker refuses to embed 32-bit absolute addresses in a 64-bit executable space. 
To overcome this without resorting to the ugly `/LARGEADDRESSAWARE:NO` linker flag, the 64-bit game explicitly utilizes **RIP-Relative Addressing** by loading the array's base address via the `lea` instruction (`lea r9, bullet_x`), and then performing register-register displacement (`mov rax, [r9 + rbx*8]`). This allows the code to remain fully 64-bit compliant!
