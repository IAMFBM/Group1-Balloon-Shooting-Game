;===============================================================================
; BALLOON SHOOTING GAME - Starter Skeleton
; FF12 - Group 1
;
; Target: 8086 real-mode assembly, written and tested in EMU8086
; (File > Load, then click Compile, then Emulate)
;
; HOW THIS PROGRAM IS STRUCTURED (read this first if you're new to asm):
;   - There is no "if/else" - everything is CMP (compare) followed by a
;     conditional JUMP (jne/je/jg/jl/etc). Get comfortable reading these.
;   - There are no functions with return values like in C/Python. Instead we
;     have PROC/ENDP blocks called with CALL, and they "return" data through
;     registers or DS-segment variables (see .data section below).
;   - Screen text is placed by moving the cursor (gotoxy) then printing one
;     character or one string at a time. There is no "draw everything at once".
;   - This file is intentionally a full, playable single-balloon game - not a
;     toy demo - so every sub-team has real, working code to read, test, and
;     extend. See the "EXTENSION IDEAS" comment block near the bottom for
;     where to plug in the creativity/innovation features.
;
; IMPORTANT: This has been carefully written and hand-checked, but it has
; NOT been run through EMU8086 yet (no 8086 assembler is available in this
; environment to test it here). Compiling it in EMU8086 on day 1-2 to catch
; any typos is the very first job of the Core coding team - don't wait.
;===============================================================================

.model small
.stack 100h

; ---- tunable constants (change these to tune difficulty / layout) ----------
TOP_ROW      equ 3        ; topmost row the shooter/balloon can occupy
BOTTOM_ROW   equ 22       ; bottommost row the shooter/balloon can occupy
SHOOTER_COL  equ 5        ; fixed column of the shooter
RIGHT_COL    equ 75       ; column where balloons spawn / bullets expire
MAX_MISSES   equ 5        ; misses allowed before game over

.data
    ; ---- text shown on screen ----
    title_msg     db 'BALLOON SHOOTING GAME', 0dh, 0ah, 0dh, 0ah, '$'
    instr_msg     db 'UP/DOWN = move    SPACE = shoot    ESC = quit', 0dh, 0ah
                  db 'Press any key to start...', '$'
    score_lbl     db 'Score: $'
    miss_lbl      db 'Misses: $'
    gameover_msg  db 0dh, 0ah, 'GAME OVER  -  Final score: $'
    playagain_msg db 0dh, 0ah, 0dh, 0ah, 'Press any key to exit.$'

    ; ---- shooter state ----
    shooter_row      dw 12
    prev_shooter_row dw 12

    ; ---- bullet state (only one bullet on screen at a time in this version) ----
    bullet_active    db 0
    bullet_row       dw 0
    bullet_col       dw 0
    prev_bullet_col  dw 0

    ; ---- balloon state (only one balloon at a time in this version) ----
    balloon_row       dw 10
    balloon_col       dw RIGHT_COL
    prev_balloon_col  dw RIGHT_COL
    balloon_tick      db 0   ; throttles balloon speed vs bullet speed

    ; ---- score tracking ----
    score   dw 0
    misses  dw 0

    ; ---- input handling ----
    key_ascii      db 0
    key_scan       db 0
    key_available  db 0
    quit_flag      db 0
    fire_now       db 0

.code

;-------------------------------------------------------------------------
; main - program entry point
;-------------------------------------------------------------------------
main proc
    mov ax, @data
    mov ds, ax

    call show_title
    call clear_screen
    call draw_static
    call draw_score

main_loop:
    call check_input
    cmp quit_flag, 1
    je main_loop_end

    call update_shooter

    cmp fire_now, 1
    jne skip_fire
    cmp bullet_active, 1
    je skip_fire
    mov bullet_active, 1
    mov ax, shooter_row
    mov bullet_row, ax
    mov ax, SHOOTER_COL + 2
    mov bullet_col, ax
    mov prev_bullet_col, ax
skip_fire:

    call update_bullet
    call update_balloon
    call check_collision
    call draw_score

    cmp misses, MAX_MISSES
    jge main_loop_end

    call delay
    jmp main_loop

main_loop_end:
    call show_gameover
    mov ax, 4c00h
    int 21h
main endp

;-------------------------------------------------------------------------
; clear_screen - reset to text mode 80x25 (also clears the screen)
;-------------------------------------------------------------------------
clear_screen proc
    push ax
    mov ax, 0003h
    int 10h
    pop ax
    ret
clear_screen endp

;-------------------------------------------------------------------------
; gotoxy - move the cursor.  Input: DH = row, DL = column
;-------------------------------------------------------------------------
gotoxy proc
    push ax
    push bx
    mov ah, 02h
    mov bh, 0
    int 10h
    pop bx
    pop ax
    ret
gotoxy endp

;-------------------------------------------------------------------------
; print_char - print one character at the current cursor position.
; Input: DL = character
;-------------------------------------------------------------------------
print_char proc
    push ax
    mov ah, 02h
    int 21h
    pop ax
    ret
print_char endp

;-------------------------------------------------------------------------
; print_string - print a '$'-terminated string. Input: DX = offset of string
;-------------------------------------------------------------------------
print_string proc
    push ax
    mov ah, 09h
    int 21h
    pop ax
    ret
print_string endp

;-------------------------------------------------------------------------
; print_num - print AX as an unsigned decimal number (no leading zeros)
;-------------------------------------------------------------------------
print_num proc
    push ax
    push bx
    push cx
    push dx

    mov cx, 0
    mov bx, 10

    cmp ax, 0
    jne pn_convert
    mov dl, '0'
    call print_char
    jmp pn_done

pn_convert:
pn_loop:
    cmp ax, 0
    je pn_print
    xor dx, dx
    div bx              ; ax = ax/10, dx = remainder digit
    push dx
    inc cx
    jmp pn_loop

pn_print:
    cmp cx, 0
    je pn_done
    pop dx
    add dl, '0'
    call print_char
    dec cx
    jmp pn_print

pn_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_num endp

;-------------------------------------------------------------------------
; show_title - title screen, waits for a keypress to start
;-------------------------------------------------------------------------
show_title proc
    call clear_screen
    mov dx, offset title_msg
    call print_string
    mov dx, offset instr_msg
    call print_string
    mov ah, 00h
    int 16h                 ; blocking wait for any key
    ret
show_title endp

;-------------------------------------------------------------------------
; draw_static - prints the score/misses labels once (not every frame)
;-------------------------------------------------------------------------
draw_static proc
    mov dh, 0
    mov dl, 0
    call gotoxy
    mov dx, offset score_lbl
    call print_string

    mov dh, 0
    mov dl, 20
    call gotoxy
    mov dx, offset miss_lbl
    call print_string
    ret
draw_static endp

;-------------------------------------------------------------------------
; draw_score - repaints just the numbers (called every frame)
;-------------------------------------------------------------------------
draw_score proc
    mov dh, 0
    mov dl, 7
    call gotoxy
    mov ax, score
    call print_num
    mov dl, ' '
    call print_char
    call print_char

    mov dh, 0
    mov dl, 28
    call gotoxy
    mov ax, misses
    call print_num
    mov dl, ' '
    call print_char
    call print_char
    ret
draw_score endp

;-------------------------------------------------------------------------
; get_key - non-blocking keyboard check.
; Sets key_available=1 and key_ascii/key_scan if a key was waiting.
;-------------------------------------------------------------------------
get_key proc
    mov ah, 01h
    int 16h
    jz gk_none
    mov ah, 00h
    int 16h
    mov key_ascii, al
    mov key_scan, ah
    mov key_available, 1
    ret
gk_none:
    mov key_available, 0
    ret
get_key endp

;-------------------------------------------------------------------------
; check_input - reads keyboard, updates shooter_row / fire_now / quit_flag
;-------------------------------------------------------------------------
check_input proc
    mov fire_now, 0
    call get_key
    cmp key_available, 1
    jne ci_done

    mov al, key_ascii
    cmp al, 1bh              ; ESC
    jne ci_check_space
    mov quit_flag, 1
    jmp ci_done

ci_check_space:
    cmp al, ' '
    jne ci_check_arrows
    mov fire_now, 1
    jmp ci_done

ci_check_arrows:
    mov ah, key_scan
    cmp ah, 48h               ; up arrow scan code
    jne ci_check_down
    cmp shooter_row, TOP_ROW
    jle ci_done
    dec shooter_row
    jmp ci_done

ci_check_down:
    cmp ah, 50h               ; down arrow scan code
    jne ci_done
    cmp shooter_row, BOTTOM_ROW
    jge ci_done
    inc shooter_row

ci_done:
    ret
check_input endp

;-------------------------------------------------------------------------
; update_shooter - erase old shooter glyph, draw it at the new row
;-------------------------------------------------------------------------
update_shooter proc
    mov dh, byte ptr prev_shooter_row
    mov dl, SHOOTER_COL
    call gotoxy
    mov dl, ' '
    call print_char

    mov dh, byte ptr shooter_row
    mov dl, SHOOTER_COL
    call gotoxy
    mov dl, '>'
    call print_char

    mov ax, shooter_row
    mov prev_shooter_row, ax
    ret
update_shooter endp

;-------------------------------------------------------------------------
; update_bullet - moves the bullet right each tick, retires it off-screen
;-------------------------------------------------------------------------
update_bullet proc
    cmp bullet_active, 1
    jne ub_done

    mov dh, byte ptr bullet_row
    mov dl, byte ptr prev_bullet_col
    call gotoxy
    mov dl, ' '
    call print_char

    mov ax, bullet_col
    mov prev_bullet_col, ax
    add ax, 2                 ; bullet speed: 2 columns per tick
    mov bullet_col, ax

    cmp bullet_col, RIGHT_COL
    jl ub_draw
    mov bullet_active, 0
    jmp ub_done

ub_draw:
    mov dh, byte ptr bullet_row
    mov dl, byte ptr bullet_col
    call gotoxy
    mov dl, '-'
    call print_char

ub_done:
    ret
update_bullet endp

;-------------------------------------------------------------------------
; update_balloon - moves the balloon left, slower than the bullet.
; Counts a miss if it reaches the shooter's side unhit.
;-------------------------------------------------------------------------
update_balloon proc
    inc balloon_tick
    cmp balloon_tick, 2        ; balloon speed: moves every 2nd tick
    jl ubn_done
    mov balloon_tick, 0

    mov dh, byte ptr balloon_row
    mov dl, byte ptr prev_balloon_col
    call gotoxy
    mov dl, ' '
    call print_char

    mov ax, balloon_col
    mov prev_balloon_col, ax
    dec ax
    mov balloon_col, ax

    cmp balloon_col, SHOOTER_COL
    jg ubn_draw

    inc misses
    call respawn_balloon
    jmp ubn_done

ubn_draw:
    mov dh, byte ptr balloon_row
    mov dl, byte ptr balloon_col
    call gotoxy
    mov dl, 'O'
    call print_char

ubn_done:
    ret
update_balloon endp

;-------------------------------------------------------------------------
; respawn_balloon - places the balloon back at the right edge, new row
;-------------------------------------------------------------------------
respawn_balloon proc
    call random_row
    mov balloon_row, ax
    mov balloon_col, RIGHT_COL
    mov prev_balloon_col, RIGHT_COL
    ret
respawn_balloon endp

;-------------------------------------------------------------------------
; random_row - returns a pseudo-random row between TOP_ROW and BOTTOM_ROW
; (uses the system tick counter as a cheap source of randomness)
;-------------------------------------------------------------------------
random_row proc
    push bx
    push cx
    push dx

    mov ah, 00h
    int 1ah                   ; cx:dx = system tick count
    mov ax, dx
    mov bx, BOTTOM_ROW - TOP_ROW + 1
    xor dx, dx
    div bx                    ; dx = ax mod bx
    mov ax, dx
    add ax, TOP_ROW

    pop dx
    pop cx
    pop bx
    ret
random_row endp

;-------------------------------------------------------------------------
; check_collision - did the bullet reach the balloon on the same row?
;-------------------------------------------------------------------------
check_collision proc
    cmp bullet_active, 1
    jne cc_done

    mov ax, bullet_row
    cmp ax, balloon_row
    jne cc_done

    mov ax, bullet_col
    cmp ax, balloon_col
    jl cc_done                ; hasn't reached the balloon's column yet

    inc score
    mov bullet_active, 0

    mov dh, byte ptr bullet_row
    mov dl, byte ptr bullet_col
    call gotoxy
    mov dl, ' '
    call print_char

    mov dl, 07h                ; ASCII bell - simple "hit" sound feedback
    call print_char

    call respawn_balloon

cc_done:
    ret
check_collision endp

;-------------------------------------------------------------------------
; delay - crude busy-wait to pace the game loop. Tune the outer count
; once you see the real speed in EMU8086 - emulator speed varies a lot
; by machine, so this constant WILL need adjusting.
;-------------------------------------------------------------------------
delay proc
    push cx
    push dx
    mov cx, 0ffffh
d_outer:
    mov dx, 0004h
d_inner:
    dec dx
    jnz d_inner
    loop d_outer
    pop dx
    pop cx
    ret
delay endp

;-------------------------------------------------------------------------
; show_gameover - final screen
;-------------------------------------------------------------------------
show_gameover proc
    call clear_screen
    mov dx, offset gameover_msg
    call print_string
    mov ax, score
    call print_num
    mov dx, offset playagain_msg
    call print_string
    mov ah, 00h
    int 16h
    ret
show_gameover endp

end main

;===============================================================================
; EXTENSION IDEAS - good places for the Core coding / Extras teams to add
; the "creativity and innovation" features the brief rewards:
;
;   - Difficulty ramp: in check_collision, after "inc score", compare score
;     to a threshold and reduce the balloon_tick throttle value (faster
;     balloons) or increase bullet speed.
;   - Multiple balloons: turn balloon_row/col/prev_col/active into small
;     arrays (e.g. 3 entries) and loop update_balloon/check_collision over
;     each index instead of using single variables.
;   - High score persistence: use INT 21h AH=3Ch (create file), 3Dh (open),
;     40h (write), 3Eh (close) to save/load a high score to a text file.
;   - Two-player mode: duplicate shooter_row/score/misses per player and
;     alternate turns in show_gameover / a new turn-management loop.
;   - Nicer visuals: swap print_char's plain output for direct writes to
;     video memory (segment 0B800h) so each character can have its own
;     color attribute, not just the default console color.
;===============================================================================