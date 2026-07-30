# 🎈 Balloon Shooting Game

A classic top-down Balloon Shooting Game implemented purely in Assembly Language! 

This repository contains two distinct versions of the game, demonstrating the evolution of Assembly Language from old-school 16-bit MS-DOS graphics to modern 64-bit native Windows programming.

---

## 🎮 The Games

### 1. The 16-bit MS-DOS Version (`balloon.asm`)
A retro-style game using raw BIOS interrupts and hardware VGA graphics.
- **Architecture**: 16-bit Real Mode x86 Assembly.
- **Graphics**: Hardware VGA Mode 13h (320x200 resolution, 256 colors).
- **Features**: Flicker-free rendering using VBLANK monitor synchronization and dirty-rectangle rendering.
- **Environment**: Must be run in an emulator like **EMU8086** or **DOSBox**.

### 2. The 64-bit Windows Version (`balloon64.asm`)
A modern port of the game that runs natively on modern computers.
- **Architecture**: 64-bit x64 Assembly (Microsoft x64 Calling Convention).
- **Graphics**: Windows Console API (Colored ASCII text buffer).
- **Features**: Interfaces directly with the modern Windows Operating System via `kernel32.dll` and `user32.dll`. Does not use any DOS interrupts.
- **Environment**: Runs natively on 64-bit Windows via the Command Prompt.

---

## 🕹️ Gameplay & Controls

You control a ship at the bottom of the screen and must shoot down the falling balloons before they crash into you or reach the ground!

- **Left / Right Arrow Keys**: Move your ship horizontally.
- **Spacebar**: Fire a bullet upwards.
- **Esc**: Quit the game immediately.
- **R**: Restart the game when you hit a Game Over screen.

If a balloon hits your ship or reaches the bottom of the screen, you lose!

---

## 🛠️ How to Compile & Run

### Running the 16-bit Version (`balloon.asm`)
1. Download and install **EMU8086**.
2. Open `balloon.asm` in EMU8086.
3. Click the **Compile** button to assemble it into a `.com` executable.
4. For the best performance (perfect 70 FPS), open **DOSBox**, mount the folder containing the compiled `.com` file, and run it.

### Running the 64-bit Version (`balloon64.asm`)
*Note: You do not need DOSBox or EMU8086 for this!*
1. Open your Windows Start Menu and launch the **x64 Native Tools Command Prompt for VS**.
2. Navigate to the folder containing the source code.
3. Compile and link the code using the Microsoft Macro Assembler (`ml64.exe`):
   ```cmd
   ml64.exe balloon64.asm /link /subsystem:console /entry:main kernel32.lib user32.lib
   ```
4. Run the newly generated `balloon64.exe` file directly from your command prompt!
