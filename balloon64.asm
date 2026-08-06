; Balloon Shooting Game (64-bit Windows Console Version)
; Assembler: MASM64 (ml64.exe)
; Target: Windows 64-bit (Console)

; --- EXTERN DECLARATIONS ---
; These declare Windows API functions that we will call from kernel32.dll and user32.dll
extrn GetStdHandle:proc            ; Retrieves a handle to standard input/output/error
extrn WriteConsoleOutputA:proc     ; Writes directly to the console's character/attribute buffer
extrn Sleep:proc                   ; Suspends the thread's execution for a specified number of milliseconds
extrn GetAsyncKeyState:proc        ; Determines whether a key is up or down at the time the function is called
extrn ExitProcess:proc             ; Ends the calling process and all its threads
extrn CreateFileA:proc             ; Creates or opens a file or I/O device
extrn WriteFile:proc               ; Writes data to the specified file or I/O device
extrn ReadFile:proc                ; Reads data from the specified file or I/O device
extrn GetFileSize:proc             ; Retrieves the size of the specified file
extrn SetFilePointer:proc          ; Moves the file pointer of the specified file
extrn CloseHandle:proc             ; Closes an open object handle (like a file handle)

; --- INITIALIZED DATA SEGMENT ---
.data
    hOut            dq 0            ; 64-bit variable (quadword) to store the standard output handle
    writeRegion     dw 0, 0, 79, 24 ; Defines the rectangle of the console to write to (Left, Top, Right, Bottom)

    ; Game State Variables
    player_x        dq 40           ; Player's starting X coordinate (center of 80-column screen)
    balloon_x       dq 20           ; Balloon's starting X coordinate
    balloon_y       dq 0            ; Balloon's starting Y coordinate (top of screen)
    balloon_act     dq 1            ; Flag: 1 if balloon is active (falling), 0 if it was shot
    balloon_timer   dq 0            ; Frame counter used to throttle the balloon's falling speed

    bullet_x        dq 10 dup(0)    ; Array of 10 Bullet X coordinates
    bullet_y        dq 10 dup(0)    ; Array of 10 Bullet Y coordinates
    bullet_act      dq 10 dup(0)    ; Array of 10 Bullet active flags
    fire_cooldown   dq 0            ; Cooldown timer for shooting
    
    game_over       dq 0            ; Flag: 1 if Game Over state is active, 0 if playing
    score           dq 0            ; The player's current score
    level           dq 1            ; The player's current level (increases every 5 score)
    balloon_speed   dq 3            ; Base speed of balloon (lower = faster)
    player_speed    dq 1            ; Player movement speed
    
    ; Name Entry State Variables (for Leaderboard)
    name_entry      dq 0            ; Flag: 1 if user is currently typing their name for the leaderboard
    name_len        dq 0            ; Current length of the typed username
    user_name       db 10 dup(' '), 0 ; 10-byte array for the username, initialized with spaces, plus null terminator
    key_cooldown    dq 0            ; Timer to prevent "ghost typing" multiple letters in a single frame

    ; String Constants (Null-terminated)
    go_msg          db "GAME OVER! PRESS R TO RETRY OR ESC TO QUIT", 0
    name_msg        db "NEW HIGH SCORE! ENTER NAME:", 0
    lb_title        db "--- LEADERBOARD ---", 0
    score_pfx       db "SCORE: ", 0
    level_pfx       db "LEVEL: ", 0
    separator       db " - ", 0
    newline         db 13, 10       ; ASCII Carriage Return (13) and Line Feed (10) for Windows newlines
    filename        db "leaderboard.txt", 0

; --- UNINITIALIZED DATA SEGMENT ---
.data?
    screen_buf      dd 2000 dup(?)  ; 2000 double-words (8000 bytes) for the 80x25 screen buffer (Char + Color Attribute)
    score_buf       db 16 dup(?)    ; 16-byte buffer to hold the ASCII string representation of the score
    dummy_bytes     dd ?            ; 4-byte variable used to catch "bytes read/written" from Windows API
    leaderboard_buf db 512 dup(?)   ; 512-byte buffer to hold the contents read from the leaderboard.txt file

; --- CODE SEGMENT ---
.code
main proc
    ; Microsoft x64 Calling Convention requires 32 bytes of "Shadow Space" for API calls,
    ; plus we need to ensure RSP is 16-byte aligned before any `call`.
    ; The OS entry leaves RSP at an offset of 8, so subtracting 40 aligns it to 16-bytes (40 = 32 + 8).
    sub rsp, 40

    ; GetStdHandle(STD_OUTPUT_HANDLE)
    mov rcx, -11                    ; -11 is the constant for STD_OUTPUT_HANDLE
    call GetStdHandle               ; RAX now contains the console handle
    mov hOut, rax                   ; Save the handle for later rendering

    ; Attempt to load the leaderboard from file at startup
    call load_leaderboard

game_loop:
    ; 1. Clear the screen buffer every frame to prevent trails
    call clear_buffer

    ; Check if we are dead. If so, jump to Game Over logic
    cmp qword ptr [game_over], 1
    je game_over_state

    ; --- NORMAL GAME INPUT (Non-Blocking) ---
    ; Check Left Arrow (Virtual Key 0x25)
    mov rcx, 25h
    call GetAsyncKeyState
    test ax, 8000h                  ; Check if the most significant bit (0x8000) is set (key is currently held down)
    jz not_left                     ; If not pressed, skip to next check
    mov rax, qword ptr [player_x]
    sub rax, qword ptr [player_speed] ; Move player left by speed
    cmp rax, 0
    jge set_left
    mov rax, 0                      ; Clamp to left edge
set_left:
    mov qword ptr [player_x], rax
not_left:

    ; Check Right Arrow (Virtual Key 0x27)
    mov rcx, 27h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_right
    mov rax, qword ptr [player_x]
    add rax, qword ptr [player_speed] ; Move player right by speed
    cmp rax, 79
    jle set_right
    mov rax, 79                     ; Clamp to right edge
set_right:
    mov qword ptr [player_x], rax
not_right:

    ; Check Spacebar (Virtual Key 0x20)
    mov rcx, 20h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_space
    cmp qword ptr [fire_cooldown], 0
    jg not_space

    mov rcx, 10
    xor rbx, rbx
shoot_loop64:
    lea r8, bullet_act
    cmp qword ptr [r8 + rbx*8], 0
    je shoot_found64
    inc rbx
    dec rcx
    jnz shoot_loop64
    jmp not_space

shoot_found64:
    lea r8, bullet_act
    lea r9, bullet_x
    lea r10, bullet_y
    mov qword ptr [r8 + rbx*8], 1
    mov rax, player_x
    mov qword ptr [r9 + rbx*8], rax
    mov qword ptr [r10 + rbx*8], 22
    mov qword ptr [fire_cooldown], 3 ; Cooldown
not_space:

    cmp qword ptr [fire_cooldown], 0
    jle skip_fcd64
    dec qword ptr [fire_cooldown]
skip_fcd64:

    ; Check Esc Key (Virtual Key 0x1B)
    mov rcx, 1Bh
    call GetAsyncKeyState
    test ax, 8000h
    jnz exit_game                   ; If Esc is pressed, terminate the program

    ; --- GAME LOGIC ---
    call update_bullet              ; Move the bullet upwards
    call update_balloon             ; Move the balloon downwards or spawn a new one
    call check_collision            ; Check if bullet hit balloon
    jmp render_scene                ; Skip Game Over logic and render the frame

game_over_state:
    ; Check if we are currently prompting the user to type their name
    cmp name_entry, 1
    je do_name_entry
    
    ; If score is greater than 0, we initiate the Name Entry sequence
    cmp score, 0
    jle no_name_entry               ; If score is 0, skip name entry
    mov name_entry, 1               ; Activate name entry mode
    mov name_len, 0                 ; Reset name length to 0
    jmp render_scene                ; Render the frame

no_name_entry:
    ; --- GAME OVER INPUT ---
    ; Check 'R' Key (Virtual Key 0x52) for Restart
    mov rcx, 52h
    call GetAsyncKeyState
    test ax, 8000h
    jz check_go_esc                 ; If 'R' not pressed, check 'Esc'
    
    ; Reset game state variables for a new session
    mov qword ptr [game_over], 0
    mov qword ptr [player_x], 40
    mov qword ptr [balloon_act], 1
    mov qword ptr [balloon_y], 0
    mov qword ptr [balloon_timer], 0
    mov qword ptr [score], 0
    mov qword ptr [fire_cooldown], 0
    ; Clear bullets
    mov rcx, 10
    xor rbx, rbx
clear_b64:
    lea r8, bullet_act
    mov qword ptr [r8 + rbx*8], 0
    inc rbx
    dec rcx
    jnz clear_b64
    mov qword ptr [level], 1
    mov qword ptr [balloon_speed], 3
    mov qword ptr [player_speed], 1
    jmp render_scene
    
check_go_esc:
    ; Check Esc Key (Virtual Key 0x1B) to quit during Game Over
    mov rcx, 1Bh
    call GetAsyncKeyState
    test ax, 8000h
    jnz exit_game
    
    ; Setup text rendering for "GAME OVER" message
    mov rcx, 19                     ; X coordinate
    mov rdx, 6                      ; Y coordinate
    lea r8, go_msg                  ; Pointer to string
    mov r9d, 000Ch                  ; Color attribute: Light Red (0x0C)
    call draw_string
    
    ; Setup text rendering for "--- LEADERBOARD ---" message
    mov rcx, 30
    mov rdx, 8
    lea r8, lb_title
    mov r9d, 000Bh                  ; Color attribute: Light Cyan (0x0B)
    call draw_string
    
    ; Draw the actual contents of leaderboard.txt to the screen
    mov rcx, 30
    mov rdx, 10
    lea r8, leaderboard_buf
    mov r9d, 000Fh                  ; Color attribute: White (0x0F)
    call draw_multiline_string

    jmp render_scene

do_name_entry:
    ; Debounce logic to prevent typing 20 letters a second if you hold a key
    cmp qword ptr [key_cooldown], 0
    jle check_enter                 ; If cooldown is <= 0, process keys
    dec qword ptr [key_cooldown]    ; Otherwise, decrement cooldown and skip input
    jmp render_name_entry

check_enter:
    ; Check Enter Key (Virtual Key 0x0D) to save score
    mov rcx, 0Dh
    call GetAsyncKeyState
    test ax, 8000h
    jz do_name_keys                 ; If not Enter, check letter keys
    
    call save_score                 ; Write score to file
    call load_leaderboard           ; Reload the file so we can see our new score
    mov name_entry, 0               ; Exit name entry mode
    mov score, 0                    ; Reset score so we don't trigger entry again
    
    ; Zero out the user_name buffer for the next time we play
    push rdi
    lea rdi, user_name
    mov ecx, 10
    mov al, ' '
    rep stosb                       ; Fill buffer with space (' ') characters
    pop rdi
    jmp render_name_entry

do_name_keys:
    ; Check Backspace Key (Virtual Key 0x08)
    mov rcx, 08h
    call GetAsyncKeyState
    test ax, 8000h
    jz check_letters
    
    cmp name_len, 0                 ; Don't backspace if name is already empty
    jle set_cooldown
    dec name_len                    ; Reduce length counter
    mov r13, name_len
    lea r14, user_name
    mov byte ptr [r14 + r13], ' '   ; Overwrite last character with a space
    jmp set_cooldown

check_letters:
    ; Loop through Virtual Keys 0x41 ('A') to 0x5A ('Z')
    mov r12, 41h
check_letters_loop:
    mov rcx, r12
    call GetAsyncKeyState
    test ax, 8000h
    jz next_letter                  ; If not pressed, try next letter
    
    cmp name_len, 8                 ; Max name length is 8 characters
    jge set_cooldown
    
    mov r13, name_len
    lea r14, user_name
    mov byte ptr [r14 + r13], r12b  ; Append the ASCII character (R12B is lower 8-bits of R12)
    inc name_len
    jmp set_cooldown                ; Only process one key per frame

next_letter:
    inc r12
    cmp r12, 5Ah
    jle check_letters_loop
    jmp render_name_entry

set_cooldown:
    mov qword ptr [key_cooldown], 3 ; Set a 3-frame (~150ms) block on reading new keys

render_name_entry:
    ; Draw "ENTER NAME:" UI
    mov rcx, 25
    mov rdx, 10
    lea r8, name_msg
    mov r9d, 000Eh                  ; Color attribute: Yellow (0x0E)
    call draw_string
    
    ; Draw the actual typed username
    mov rcx, 35
    mov rdx, 12
    lea r8, user_name
    mov r9d, 000Fh                  ; Color attribute: White (0x0F)
    call draw_string
    
    jmp render_scene

render_scene:
    ; Draw "SCORE: " prefix
    mov rcx, 2
    mov rdx, 1
    lea r8, score_pfx
    mov r9d, 000Ah                  ; Color attribute: Light Green (0x0A)
    call draw_string
    
    ; Convert binary score to text and draw it
    mov rcx, score
    lea rdx, score_buf
    call itoa                       ; Converts RCX into string at RDX, returns pointer in RAX
    mov rcx, 9                      ; X coordinate (right after "SCORE: ")
    mov rdx, 1
    mov r8, rax                     ; String pointer
    mov r9d, 000Ah
    call draw_string
    
    ; Draw "LEVEL: " prefix
    mov rcx, 65
    mov rdx, 1
    lea r8, level_pfx
    mov r9d, 000Eh                  ; Color attribute: Yellow (0x0E)
    call draw_string
    
    ; Convert binary level to text and draw it
    mov rcx, level
    lea rdx, score_buf
    call itoa
    mov rcx, 72
    mov rdx, 1
    mov r8, rax
    mov r9d, 000Eh
    call draw_string

    ; Draw Player ('^')
    mov rcx, player_x
    mov rdx, 23
    mov r8d, 0009005Eh              ; 0009 (Light Blue attribute), 005E (ASCII '^')
    call draw_char

    ; Draw Balloon ('OOO' block)
    cmp balloon_act, 1
    jne no_balloon_draw
    mov rcx, balloon_x
    mov rdx, balloon_y
    mov r8d, 000C004Fh              ; 000C (Light Red attribute), 004F (ASCII 'O')
    call draw_char                  ; Draw left 'O'
    mov rcx, balloon_x
    inc rcx
    mov rdx, balloon_y
    mov r8d, 000C004Fh 
    call draw_char                  ; Draw middle 'O'
    mov rcx, balloon_x
    add rcx, 2
    mov rdx, balloon_y
    mov r8d, 000C004Fh 
    call draw_char                  ; Draw right 'O'
no_balloon_draw:

    ; Draw Bullet ('|')
    mov rcx, 10
    xor rbx, rbx
draw_bul_loop64:
    lea r10, bullet_act
    cmp qword ptr [r10 + rbx*8], 1
    jne db_next64
    
    push rcx
    push rbx
    lea r10, bullet_x
    mov rcx, qword ptr [r10 + rbx*8]
    lea r10, bullet_y
    mov rdx, qword ptr [r10 + rbx*8]
    mov r8d, 000E007Ch              ; 000E (Yellow attribute), 007C (ASCII '|')
    call draw_char
    pop rbx
    pop rcx
db_next64:
    inc rbx
    dec rcx
    jnz draw_bul_loop64

    ; Blit the entire screen_buf to the actual Windows Console
    ; WriteConsoleOutputA(hConsoleOutput, lpBuffer, dwBufferSize, dwBufferCoord, lpWriteRegion)
    mov rcx, hOut                   ; Console handle
    lea rdx, screen_buf             ; Pointer to our offscreen buffer array
    mov r8d, 00190050h              ; Buffer Size: 25 rows (0x0019) by 80 columns (0x0050)
    mov r9d, 0                      ; Buffer Coord: X=0, Y=0 (Start of array)
    lea rax, writeRegion            
    mov qword ptr [rsp+32], rax     ; 5th Argument passed on the stack
    call WriteConsoleOutputA

    ; Pause execution for 50 milliseconds (~20 Frames Per Second)
    mov rcx, 50
    call Sleep
    
    ; Loop back to process the next frame
    jmp game_loop

exit_game:
    ; Cleanup shadow space and cleanly exit the OS process
    add rsp, 40
    mov rcx, 0
    call ExitProcess
main endp

; --- SUBROUTINES ---

; Wipes the 8000-byte screen_buf cleanly
clear_buffer proc
    push rdi
    lea rdi, screen_buf
    mov ecx, 2000                   ; 2000 double-words to process
    mov eax, 00000020h              ; 0x0000 (Black background), 0x0020 (ASCII Space)
    rep stosd                       ; Fill RDI with EAX exactly ECX times
    pop rdi
    ret
clear_buffer endp

; Draws a single character + color double-word into the screen_buf array
; RCX = X, RDX = Y, R8D = Character/Attribute Double-word
draw_char proc
    imul rax, rdx, 80               ; Y * 80 columns
    add rax, rcx                    ; (Y * 80) + X
    lea r9, screen_buf
    mov dword ptr [r9 + rax*4], r8d ; Write 4 bytes to array offset
    ret
draw_char endp

; Draws a null-terminated string into the screen_buf array
; RCX = Start X, RDX = Start Y, R8 = String Pointer, R9W = Color Attribute
draw_string proc
    imul rax, rdx, 80               ; (Y * 80) + X
    add rax, rcx
    shl rax, 2                      ; Multiply by 4 (bytes per cell)
    lea r10, screen_buf
    add r10, rax                    ; R10 now points to the starting cell in screen_buf
ds_loop:
    mov al, byte ptr [r8]           ; Read 1 character from string
    test al, al                     ; Check if character is NULL (0)
    jz ds_end                       ; If NULL, string is over, end loop
    mov byte ptr [r10], al          ; Write ASCII character to screen_buf
    mov word ptr [r10 + 2], r9w     ; Write color attribute to screen_buf
    inc r8                          ; Move to next string character
    add r10, 4                      ; Move to next screen cell (4 bytes forward)
    jmp ds_loop
ds_end:
    ret
draw_string endp

; Draws a string that contains Carriage Returns (13) and Line Feeds (10)
; RCX = Start X, RDX = Start Y, R8 = String Pointer, R9W = Color Attribute
draw_multiline_string proc
    push r11
    push r12
    mov r11, rcx                    ; R11 = Current X tracking
    mov r12, rdx                    ; R12 = Current Y tracking
    
dms_loop:
    cmp r12, 23
    jg dms_end                      ; Safety: Do not draw past the bottom edge of the screen!

    mov al, byte ptr [r8]
    test al, al
    jz dms_end                      ; Null terminator reached
    
    cmp al, 13                      ; Ignore Carriage Returns
    je skip_char
    cmp al, 10                      ; Handle Line Feeds
    je next_line
    
    cmp r11, 79
    jg skip_char                    ; Safety: Do not draw past the right edge of the screen!
    
    ; Calculate offset: ((Y * 80) + X) * 4
    mov rax, r12
    imul rax, rax, 80
    add rax, r11
    shl rax, 2
    lea r10, screen_buf
    add r10, rax
    
    ; Write to buffer
    mov al, byte ptr [r8]
    mov byte ptr [r10], al
    mov word ptr [r10 + 2], r9w
    
    inc r11                         ; Move X to the right
    jmp skip_char

next_line:
    mov r11, rcx                    ; Reset X back to the Start X
    inc r12                         ; Move Y down one row
    
skip_char:
    inc r8                          ; Advance string pointer
    jmp dms_loop
dms_end:
    pop r12
    pop r11
    ret
draw_multiline_string endp

; Converts a binary integer to an ASCII string (Integer-to-ASCII)
; RCX = Number to convert, RDX = Pointer to 16-byte destination buffer
; Returns pointer to start of generated string in RAX
itoa proc
    mov rax, rcx                    ; Copy number to RAX
    mov r8, 10                      ; Base 10 divisor
    lea r9, [rdx + 15]              ; Point R9 to the end of the buffer
    mov byte ptr [r9], 0            ; Write Null-terminator at the end
itoa_loop:
    dec r9                          ; Move backwards in the buffer
    xor edx, edx                    ; Clear RDX for division
    div r8                          ; RDX:RAX / 10 (Quotient in RAX, Remainder in RDX)
    add dl, '0'                     ; Convert remainder integer (0-9) to ASCII character ('0'-'9')
    mov byte ptr [r9], dl           ; Write character to buffer
    test rax, rax                   ; Check if Quotient is 0 (we are done)
    jnz itoa_loop
    mov rax, r9                     ; Return pointer to the first digit
    ret
itoa endp

; Handles balloon movement and spawning
update_balloon proc
    cmp balloon_act, 1
    je move_balloon                 ; If balloon is alive, move it

    ; If balloon is dead, spawn a new one
    mov balloon_act, 1
    mov qword ptr [balloon_y], 0    ; Reset Y to Top of screen
    
    ; Generate a pseudo-random X coordinate using the CPU's Time Stamp Counter
    rdtsc                           ; Loads CPU tick count into EDX:EAX
    xor edx, edx
    mov ecx, 78                     ; Max width (78 instead of 80 so the 3-wide balloon doesn't clip)
    div ecx                         ; EDX:EAX / 78
    mov balloon_x, rdx              ; Store the Remainder (0-77) as the new X coordinate
    ret

move_balloon:
    ; Throttle speed: Balloon only moves downwards every N frames
    inc qword ptr [balloon_timer]
    mov rax, qword ptr [balloon_speed]
    cmp qword ptr [balloon_timer], rax
    jl end_update_balloon           ; If timer < speed, skip moving
    mov qword ptr [balloon_timer], 0; Reset timer
    
    ; Actually move the balloon down
    inc qword ptr [balloon_y]
    cmp qword ptr [balloon_y], 23
    jl end_update_balloon
    
    ; If balloon reached row 23 (bottom), it's Game Over
    mov qword ptr [game_over], 1
    call load_leaderboard           ; Load leaderboard file immediately upon death
end_update_balloon:
    ret
update_balloon endp

; Handles bullet upward movement
update_bullet proc
    mov rcx, 10
    xor rbx, rbx
ub_loop64:
    lea r8, bullet_act
    cmp qword ptr [r8 + rbx*8], 1
    jne ub_next64
    lea r9, bullet_y
    dec qword ptr [r9 + rbx*8]
    cmp qword ptr [r9 + rbx*8], 0
    jge ub_next64
    mov qword ptr [r8 + rbx*8], 0
ub_next64:
    inc rbx
    dec rcx
    jnz ub_loop64
    ret
update_bullet endp

; Checks if the bullet hitbox intersects the balloon hitbox
check_collision proc
    cmp balloon_act, 1
    jne end_check

    mov rcx, 10
    xor rbx, rbx
cc_loop64:
    lea r8, bullet_act
    cmp qword ptr [r8 + rbx*8], 1
    jne cc_next64

    lea r9, bullet_x
    mov rax, qword ptr [r9 + rbx*8]
    cmp rax, balloon_x
    jl cc_next64
    mov r10, balloon_x
    add r10, 2
    cmp rax, r10
    jg cc_next64

    lea r9, bullet_y
    mov rax, qword ptr [r9 + rbx*8]
    cmp rax, balloon_y
    jg cc_next64

    ; HIT!
    mov balloon_act, 0
    lea r8, bullet_act
    mov qword ptr [r8 + rbx*8], 0
    inc score
    
    ; Calculate Dynamic Level (Level = Score / 5 + 1)
    mov rax, score
    mov rcx, 5
    xor rdx, rdx
    div rcx
    inc rax
    mov qword ptr [level], rax
    
    ; Calculate Dynamic Balloon Speed
    mov rcx, 4
    sub rcx, rax
    cmp rcx, 1
    jge set_spd
    mov rcx, 1
set_spd:
    mov qword ptr [balloon_speed], rcx

    ; Calculate Player Speed
    mov rax, qword ptr [level]
    inc rax
    shr rax, 1
    cmp rax, 1
    jge set_pspd
    mov rax, 1
set_pspd:
    mov qword ptr [player_speed], rax
    jmp end_check ; Balloon destroyed, stop checking bullets

cc_next64:
    inc rbx
    dec rcx
    jnz cc_loop64

end_check:
    ret
check_collision endp

; Uses Windows API to append the player's name and score to leaderboard.txt
save_score proc
    ; Robust Stack Alignment Prologue for Windows API calls
    push rbp
    mov rbp, rsp
    and rsp, -16                    ; Force RSP to be 16-byte aligned
    sub rsp, 96                     ; Allocate shadow space (32 bytes) + 5th/6th/7th args
    
    ; CreateFileA("leaderboard.txt", FILE_APPEND_DATA, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL)
    lea rcx, filename
    mov rdx, 4                      ; FILE_APPEND_DATA
    mov r8, 1                       ; FILE_SHARE_READ
    mov r9, 0                       ; NULL
    mov qword ptr [rsp+32], 4       ; OPEN_ALWAYS (Creates file if it doesn't exist)
    mov qword ptr [rsp+40], 80h     ; FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp+48], 0       ; NULL
    call CreateFileA
    
    cmp rax, -1                     ; Check for INVALID_HANDLE_VALUE
    je save_score_end
    mov r15, rax                    ; Save File Handle to R15
    
    ; 1. Write the typed Name
    mov rcx, r15
    lea rdx, user_name
    mov r8, name_len
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; 2. Write the " - " separator
    mov rcx, r15
    lea rdx, separator
    mov r8, 3
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; 3. Convert Score to string and Write it
    mov rcx, score
    lea rdx, score_buf
    call itoa
    mov rdi, rax                    ; Save string pointer
    
    mov rcx, 0
len_loop:
    cmp byte ptr [rdi + rcx], 0     ; Measure string length to know how many bytes to write
    je got_len
    inc rcx
    jmp len_loop
got_len:
    mov r8, rcx                     ; Size of string
    mov rcx, r15
    mov rdx, rdi
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; 4. Write Windows Newline (CRLF)
    mov rcx, r15
    lea rdx, newline
    mov r8, 2
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; 5. Close File Handle
    mov rcx, r15
    call CloseHandle
    
save_score_end:
    ; Restore original stack pointer from before alignment
    mov rsp, rbp
    pop rbp
    ret
save_score endp

; Uses Windows API to read leaderboard.txt into memory for rendering
load_leaderboard proc
    ; Robust Stack Alignment Prologue for Windows API calls
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 96

    ; Zero out the global leaderboard_buf to prevent reading stale memory
    push rdi
    lea rdi, leaderboard_buf
    mov ecx, 128                    ; 128 double-words (512 bytes)
    xor eax, eax
    rep stosd
    pop rdi
    
    ; CreateFileA("leaderboard.txt", GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL)
    lea rcx, filename
    mov rdx, 80000000h              ; GENERIC_READ
    mov r8, 1                       ; FILE_SHARE_READ
    mov r9, 0
    mov qword ptr [rsp+32], 3       ; OPEN_EXISTING (Fails gracefully if file doesn't exist)
    mov qword ptr [rsp+40], 80h     ; FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp+48], 0
    call CreateFileA
    
    cmp rax, -1
    je load_end
    mov r15, rax                    ; Save File Handle to R15
    
    ; Get File Size to determine if we need to seek
    mov rcx, r15
    mov rdx, 0
    call GetFileSize
    
    cmp rax, 511
    jle no_seek                     ; If file is < 512 bytes, read from the beginning
    
    ; If file is huge, seek to (End - 511) to only read the newest high scores
    sub rax, 511
    mov rcx, r15
    mov rdx, rax                    ; Seek Distance
    mov r8, 0
    mov r9, 0                       ; FILE_BEGIN (Seek relative to start of file)
    call SetFilePointer
    
no_seek:
    ; ReadFile(hFile, lpBuffer, nNumberOfBytesToRead, lpNumberOfBytesRead, lpOverlapped)
    mov rcx, r15
    lea rdx, leaderboard_buf
    mov r8, 511                     ; Max bytes to read
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call ReadFile
    
    ; Close File Handle
    mov rcx, r15
    call CloseHandle
    
load_end:
    mov rsp, rbp
    pop rbp
    ret
load_leaderboard endp

end
