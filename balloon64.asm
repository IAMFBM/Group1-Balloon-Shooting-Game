; Balloon Shooting Game (64-bit Windows Console Version)
; Assembler: MASM64 (ml64.exe)
; Target: Windows 64-bit (Console)

extrn GetStdHandle:proc
extrn WriteConsoleOutputA:proc
extrn Sleep:proc
extrn GetAsyncKeyState:proc
extrn ExitProcess:proc
extrn CreateFileA:proc
extrn WriteFile:proc
extrn ReadFile:proc
extrn GetFileSize:proc
extrn SetFilePointer:proc
extrn CloseHandle:proc

.data
    hOut            dq 0
    writeRegion     dw 0, 0, 79, 24 ; Left, Top, Right, Bottom

    ; Game state
    player_x        dq 40
    balloon_x       dq 20
    balloon_y       dq 0
    balloon_act     dq 1
    balloon_timer   dq 0

    bullet_x        dq 0
    bullet_y        dq 0
    bullet_act      dq 0
    
    game_over       dq 0
    score           dq 0
    
    ; Name Entry State
    name_entry      dq 0
    name_len        dq 0
    user_name       db 10 dup(' ')

    ; Strings
    go_msg          db "GAME OVER! PRESS R TO RETRY OR ESC TO QUIT", 0
    name_msg        db "NEW HIGH SCORE! ENTER NAME:", 0
    lb_title        db "--- LEADERBOARD ---", 0
    score_pfx       db "SCORE: ", 0
    separator       db " - ", 0
    newline         db 13, 10
    filename        db "leaderboard.txt", 0

.data?
    screen_buf      dd 2000 dup(?)
    score_buf       db 16 dup(?)
    dummy_bytes     dd ?
    leaderboard_buf db 512 dup(?)

.code
main proc
    sub rsp, 40

    mov rcx, -11
    call GetStdHandle
    mov hOut, rax

    ; Preload leaderboard if it exists
    call load_leaderboard

game_loop:
    call clear_buffer

    cmp qword ptr [game_over], 1
    je game_over_state

    ; --- NORMAL GAME INPUT ---
    mov rcx, 25h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_left
    cmp player_x, 0
    jle not_left
    dec player_x
not_left:

    mov rcx, 27h
    call GetAsyncKeyState
    test ax, 8000h
    jz not_right
    cmp player_x, 79
    jge not_right
    inc player_x
not_right:

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
    ; Are we entering a name?
    cmp name_entry, 1
    je do_name_entry
    
    ; If score > 0, switch to name entry
    cmp score, 0
    jle no_name_entry
    mov name_entry, 1
    mov name_len, 0
    jmp render_scene

no_name_entry:
    ; Normal Game Over Input
    mov rcx, 52h ; 'R'
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
    mov qword ptr [score], 0
    jmp render_scene
    
check_go_esc:
    mov rcx, 1Bh ; Esc
    call GetAsyncKeyState
    test ax, 8000h
    jnz exit_game
    
    ; Draw Game Over text
    mov rcx, 19
    mov rdx, 6
    lea r8, go_msg
    mov r9d, 000Ch
    call draw_string
    
    ; Draw Leaderboard Title
    mov rcx, 30
    mov rdx, 8
    lea r8, lb_title
    mov r9d, 000Bh ; Cyan
    call draw_string
    
    ; Draw Leaderboard Data
    mov rcx, 30
    mov rdx, 10
    lea r8, leaderboard_buf
    mov r9d, 000Fh ; White
    call draw_multiline_string

    jmp render_scene

do_name_entry:
    ; Name Entry Input (A-Z)
    mov r12, 41h
check_keys:
    mov rcx, r12
    call GetAsyncKeyState
    test ax, 1 ; Check if pressed since last call
    jz next_key
    
    cmp name_len, 8
    jge next_key
    
    mov r13, name_len
    lea r14, user_name
    mov byte ptr [r14 + r13], r12b
    inc name_len
next_key:
    inc r12
    cmp r12, 5Ah
    jle check_keys

    ; Check Backspace
    mov rcx, 08h
    call GetAsyncKeyState
    test ax, 1
    jz no_backspace
    cmp name_len, 0
    jle no_backspace
    dec name_len
    mov r13, name_len
    lea r14, user_name
    mov byte ptr [r14 + r13], ' '
no_backspace:

    ; Check Enter
    mov rcx, 0Dh
    call GetAsyncKeyState
    test ax, 1
    jz no_enter
    call save_score
    call load_leaderboard ; Reload so we see the new score immediately
    mov name_entry, 0 ; Done entering name
    mov score, 0
no_enter:

    ; Draw Name Entry UI
    mov rcx, 25
    mov rdx, 10
    lea r8, name_msg
    mov r9d, 000Eh
    call draw_string
    
    mov rcx, 35
    mov rdx, 12
    lea r8, user_name
    mov r9d, 000Fh
    call draw_string
    
    jmp render_scene

render_scene:
    ; Draw Score
    mov rcx, 2
    mov rdx, 1
    lea r8, score_pfx
    mov r9d, 000Ah ; Green
    call draw_string
    
    mov rcx, score
    lea rdx, score_buf
    call itoa
    mov rcx, 9
    mov rdx, 1
    mov r8, rax
    mov r9d, 000Ah
    call draw_string

    ; Draw Player
    mov rcx, player_x
    mov rdx, 23
    mov r8d, 0009005Eh 
    call draw_char

    ; Draw Balloon
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

    ; Draw Bullet
    cmp bullet_act, 1
    jne no_bullet_draw
    mov rcx, bullet_x
    mov rdx, bullet_y
    mov r8d, 000E007Ch
    call draw_char
no_bullet_draw:

    ; Render
    mov rcx, hOut
    lea rdx, screen_buf
    mov r8d, 00190050h
    mov r9d, 0
    lea rax, writeRegion
    mov qword ptr [rsp+32], rax
    call WriteConsoleOutputA

    mov rcx, 50
    call Sleep
    jmp game_loop

exit_game:
    add rsp, 40
    mov rcx, 0
    call ExitProcess
main endp

; --- SUBROUTINES ---

clear_buffer proc
    push rdi
    lea rdi, screen_buf
    mov ecx, 2000
    mov eax, 00000020h
    rep stosd
    pop rdi
    ret
clear_buffer endp

draw_char proc
    imul rax, rdx, 80
    add rax, rcx
    lea r9, screen_buf
    mov dword ptr [r9 + rax*4], r8d
    ret
draw_char endp

draw_string proc
    imul rax, rdx, 80
    add rax, rcx
    shl rax, 2
    lea r10, screen_buf
    add r10, rax
ds_loop:
    mov al, byte ptr [r8]
    test al, al
    jz ds_end
    mov byte ptr [r10], al
    mov word ptr [r10 + 2], r9w
    inc r8
    add r10, 4
    jmp ds_loop
ds_end:
    ret
draw_string endp

draw_multiline_string proc
    ; RCX = Start X, RDX = Start Y, R8 = string pointer, R9D = Attribute
    push r11
    push r12
    mov r11, rcx ; Current X
    mov r12, rdx ; Current Y
    
dms_loop:
    mov al, byte ptr [r8]
    test al, al
    jz dms_end
    
    cmp al, 13 ; CR
    je skip_char
    cmp al, 10 ; LF
    je next_line
    
    ; Calculate offset
    mov rax, r12
    imul rax, rax, 80
    add rax, r11
    shl rax, 2
    lea r10, screen_buf
    add r10, rax
    
    mov al, byte ptr [r8]
    mov byte ptr [r10], al
    mov word ptr [r10 + 2], r9w
    
    inc r11
    jmp skip_char

next_line:
    mov r11, rcx ; Reset X to start X
    inc r12      ; Move down one line
    
skip_char:
    inc r8
    jmp dms_loop
dms_end:
    pop r12
    pop r11
    ret
draw_multiline_string endp

itoa proc
    mov rax, rcx
    mov r8, 10
    lea r9, [rdx + 15]
    mov byte ptr [r9], 0
itoa_loop:
    dec r9
    xor edx, edx
    div r8
    add dl, '0'
    mov byte ptr [r9], dl
    test rax, rax
    jnz itoa_loop
    mov rax, r9
    ret
itoa endp

update_balloon proc
    cmp balloon_act, 1
    je move_balloon

    mov balloon_act, 1
    mov qword ptr [balloon_y], 0
    
    rdtsc
    xor edx, edx
    mov ecx, 78
    div ecx
    mov balloon_x, rdx
    ret

move_balloon:
    inc qword ptr [balloon_timer]
    cmp qword ptr [balloon_timer], 3
    jl end_update_balloon
    mov qword ptr [balloon_timer], 0

    inc qword ptr [balloon_y]
    cmp qword ptr [balloon_y], 23
    jl end_update_balloon
    
    mov qword ptr [game_over], 1
    call load_leaderboard ; Load leaderboard immediately upon death
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

    mov balloon_act, 0
    mov bullet_act, 0
    inc score
end_check:
    ret
check_collision endp

save_score proc
    sub rsp, 88
    
    lea rcx, filename
    mov rdx, 4 ; FILE_APPEND_DATA
    mov r8, 1  ; FILE_SHARE_READ
    mov r9, 0
    mov qword ptr [rsp+32], 4 ; OPEN_ALWAYS
    mov qword ptr [rsp+40], 80h ; FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp+48], 0
    call CreateFileA
    
    cmp rax, -1
    je save_score_end
    mov r15, rax ; handle
    
    ; Write Name
    mov rcx, r15
    lea rdx, user_name
    mov r8, name_len
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; Write Separator
    mov rcx, r15
    lea rdx, separator
    mov r8, 3
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; Write Score
    mov rcx, score
    lea rdx, score_buf
    call itoa
    mov rdi, rax
    
    mov rcx, 0
len_loop:
    cmp byte ptr [rdi + rcx], 0
    je got_len
    inc rcx
    jmp len_loop
got_len:
    mov r8, rcx
    mov rcx, r15
    mov rdx, rdi
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    ; Write Newline
    mov rcx, r15
    lea rdx, newline
    mov r8, 2
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call WriteFile
    
    mov rcx, r15
    call CloseHandle
    
save_score_end:
    add rsp, 88
    ret
save_score endp

load_leaderboard proc
    ; Zero out buffer
    push rdi
    lea rdi, leaderboard_buf
    mov ecx, 128
    xor eax, eax
    rep stosd
    pop rdi
    
    sub rsp, 88
    lea rcx, filename
    mov rdx, 80000000h ; GENERIC_READ
    mov r8, 1 ; FILE_SHARE_READ
    mov r9, 0
    mov qword ptr [rsp+32], 3 ; OPEN_EXISTING
    mov qword ptr [rsp+40], 80h ; FILE_ATTRIBUTE_NORMAL
    mov qword ptr [rsp+48], 0
    call CreateFileA
    
    cmp rax, -1
    je load_end
    mov r15, rax ; handle
    
    ; Get file size
    mov rcx, r15
    mov rdx, 0
    call GetFileSize
    
    cmp rax, 511
    jle no_seek
    
    ; Seek to end - 511 so we only read the newest scores
    sub rax, 511
    mov rcx, r15
    mov rdx, rax
    mov r8, 0
    mov r9, 0 ; FILE_BEGIN
    call SetFilePointer
    
no_seek:
    ; ReadFile
    mov rcx, r15
    lea rdx, leaderboard_buf
    mov r8, 511
    lea r9, dummy_bytes
    mov qword ptr [rsp+32], 0
    call ReadFile
    
    mov rcx, r15
    call CloseHandle
    
load_end:
    add rsp, 88
    ret
load_leaderboard endp

end
