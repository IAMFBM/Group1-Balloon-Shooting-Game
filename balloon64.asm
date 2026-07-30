; Balloon Shooting Game (64-bit Windows Console Version)
; Assembler: MASM64 (ml64.exe)
; Target: Windows 64-bit (Console)

extrn GetStdHandle:proc
extrn WriteConsoleOutputA:proc
extrn Sleep:proc
extrn GetAsyncKeyState:proc
extrn ExitProcess:proc

.data
    hOut            dq 0
    writeRegion     dw 0, 0, 79, 24 ; Left, Top, Right, Bottom

    ; Game state (64-bit quadwords for easy register loading)
    player_x        dq 40
    balloon_x       dq 20
    balloon_y       dq 0
    balloon_act     dq 1
    balloon_timer   dq 0

    bullet_x        dq 0
    bullet_y        dq 0
    bullet_act      dq 0
    
    game_over       dq 0

    go_msg          db "GAME OVER! PRESS R TO RETRY OR ESC TO QUIT", 0

.data?
    screen_buf      dd 2000 dup(?)  ; 2000 CHAR_INFO structures (4 bytes each)

.code
main proc
    ; 16-byte stack alignment and 32 bytes shadow space for Win64 Calling Convention
    sub rsp, 40

    ; GetStdHandle(STD_OUTPUT_HANDLE = -11)
    mov rcx, -11
    call GetStdHandle
    mov hOut, rax

game_loop:
    call clear_buffer

    cmp qword ptr [game_over], 1
    je game_over_state

    ; --- NORMAL GAME INPUT ---

    ; Check Left Arrow (VK_LEFT = 0x25)
    mov rcx, 25h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_left
    cmp player_x, 0
    jle not_left
    dec player_x
not_left:

    ; Check Right Arrow (VK_RIGHT = 0x27)
    mov rcx, 27h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_right
    cmp player_x, 79
    jge not_right
    inc player_x
not_right:

    ; Check Spacebar (VK_SPACE = 0x20)
    mov rcx, 20h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_space
    cmp bullet_act, 1
    je not_space
    mov bullet_act, 1
    mov rax, player_x
    mov bullet_x, rax
    mov qword ptr [bullet_y], 22
not_space:

    ; Check Esc (VK_ESCAPE = 0x1B)
    mov rcx, 1Bh
    call GetAsyncKeyState
    test ax, 8000h
    jnz exit_game

    ; --- GAME LOGIC ---
    call update_bullet
    call update_balloon
    call check_collision
    jmp render_scene

game_over_state:
    ; --- GAME OVER INPUT ---
    
    ; Check 'R' (VK_R = 0x52)
    mov rcx, 52h
    call GetAsyncKeyState
    test ax, 8000h
    jz check_go_esc
    
    ; Reset game
    mov qword ptr [game_over], 0
    mov qword ptr [player_x], 40
    mov qword ptr [balloon_act], 1
    mov qword ptr [balloon_y], 0
    mov qword ptr [balloon_timer], 0
    mov qword ptr [bullet_act], 0
    jmp render_scene
    
check_go_esc:
    ; Check Esc
    mov rcx, 1Bh
    call GetAsyncKeyState
    test ax, 8000h
    jnz exit_game
    
    ; Draw Game Over text
    mov rcx, 19      ; X
    mov rdx, 12      ; Y
    lea r8, go_msg   ; String
    mov r9d, 000Ch   ; Red attribute
    call draw_string

render_scene:
    ; Draw Player (Blue '^')
    mov rcx, player_x
    mov rdx, 23
    mov r8d, 0009005Eh 
    call draw_char

    ; Draw Balloon (Red 'OOO')
    cmp balloon_act, 1
    jne no_balloon_draw
    mov rcx, balloon_x
    mov rdx, balloon_y
    mov r8d, 000C004Fh 
    call draw_char
    mov rcx, balloon_x
    inc rcx
    mov rdx, balloon_y
    mov r8d, 000C004Fh 
    call draw_char
    mov rcx, balloon_x
    add rcx, 2
    mov rdx, balloon_y
    mov r8d, 000C004Fh 
    call draw_char
no_balloon_draw:

    ; Draw Bullet (Yellow '|')
    cmp bullet_act, 1
    jne no_bullet_draw
    mov rcx, bullet_x
    mov rdx, bullet_y
    mov r8d, 000E007Ch
    call draw_char
no_bullet_draw:

    ; Render screen buffer to console
    mov rcx, hOut
    lea rdx, screen_buf
    mov r8d, 00190050h  ; Size: X=80 (50h), Y=25 (19h)
    mov r9d, 0          ; Coord: X=0, Y=0
    lea rax, writeRegion
    mov qword ptr [rsp+32], rax
    call WriteConsoleOutputA

    ; Frame delay (50ms -> ~20 FPS)
    mov rcx, 50
    call Sleep

    jmp game_loop

exit_game:
    add rsp, 40
    mov rcx, 0
    call ExitProcess
main endp

clear_buffer proc
    push rdi
    lea rdi, screen_buf
    mov ecx, 2000
    mov eax, 00000020h ; Space character with Black background (0000h)
    rep stosd
    pop rdi
    ret
clear_buffer endp

draw_char proc
    ; RCX = X, RDX = Y, R8D = Char/Attr
    imul rax, rdx, 80
    add rax, rcx
    lea r9, screen_buf
    mov dword ptr [r9 + rax*4], r8d
    ret
draw_char endp

draw_string proc
    ; RCX = X, RDX = Y, R8 = string pointer, R9D = Attribute
    imul rax, rdx, 80
    add rax, rcx
    shl rax, 2      ; multiply by 4
    lea r10, screen_buf
    add r10, rax    ; R10 points to destination in screen_buf
    
ds_loop:
    mov al, byte ptr [r8]
    test al, al
    jz ds_end
    
    ; Write Char
    mov byte ptr [r10], al
    ; Write Attribute
    mov word ptr [r10 + 2], r9w
    
    inc r8
    add r10, 4
    jmp ds_loop
ds_end:
    ret
draw_string endp

update_balloon proc
    cmp balloon_act, 1
    je move_balloon

    mov balloon_act, 1
    mov qword ptr [balloon_y], 0
    
    ; Generate random X using RDTSC
    rdtsc
    xor edx, edx
    mov ecx, 78 ; 77 is max X (so 3 chars fit on 80 char width)
    div ecx
    mov balloon_x, rdx ; Remainder (0-77) becomes the X coordinate
    ret

move_balloon:
    ; Slow down balloon fall rate (only moves every 3 frames)
    inc qword ptr [balloon_timer]
    cmp qword ptr [balloon_timer], 3
    jl end_update_balloon
    mov qword ptr [balloon_timer], 0

    inc qword ptr [balloon_y]
    cmp qword ptr [balloon_y], 23
    jl end_update_balloon
    
    ; Balloon reached the bottom! GAME OVER!
    mov qword ptr [game_over], 1

end_update_balloon:
    ret
update_balloon endp

update_bullet proc
    cmp bullet_act, 1
    jne end_update_bullet
    dec qword ptr [bullet_y]
    cmp qword ptr [bullet_y], 0
    jge end_update_bullet
    mov bullet_act, 0
end_update_bullet:
    ret
update_bullet endp

check_collision proc
    cmp bullet_act, 1
    jne end_check
    cmp balloon_act, 1
    jne end_check

    mov rax, bullet_x
    cmp rax, balloon_x
    jl end_check
    mov rcx, balloon_x
    add rcx, 2
    cmp rax, rcx
    jg end_check

    mov rax, bullet_y
    cmp rax, balloon_y
    jg end_check

    ; Bullet hit balloon!
    mov balloon_act, 0
    mov bullet_act, 0
end_check:
    ret
check_collision endp

end
