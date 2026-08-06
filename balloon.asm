; Balloon Shooting Game for EMU8086 / DOSBox (Top-Down, Player Death)
; Environment: DOS 16-bit (.COM)
; Video Mode: VGA Mode 13h (320x200, 256 colors)

org 100h
jmp start

MAX_BULLETS equ 5

; --- VARIABLES ---
player_x    dw 150
player_y    dw 185    ; At the bottom
player_w    dw 20
player_h    dw 10
player_col  db 9

balloon_x   dw 100
balloon_y   dw 0      ; Start at TOP (Falling down)
balloon_w   dw 15
balloon_h   dw 15
balloon_col db 4
balloon_act db 1

bullet_x    dw MAX_BULLETS dup(0)
bullet_y    dw MAX_BULLETS dup(0)
bullet_act  db MAX_BULLETS dup(0)
bullet_w    dw 6
bullet_h    dw 5
bullet_col  db 14

fire_cooldown dw 0

score       dw 0

rect_x dw 0
rect_y dw 0
rect_w dw 0
rect_h dw 0
rect_c db 0

; UI Strings
score_str   db 'SCORE: 0000', 0
go_str      db 'GAME OVER! PRESS R TO RETRY', 0

; Sprite Data (15x15 Circular Balloon)
balloon_bmp db 0,0,0,0,0,1,1,1,1,1,0,0,0,0,0
            db 0,0,0,1,1,1,1,1,1,1,1,1,0,0,0
            db 0,0,1,1,1,1,1,1,1,1,1,1,1,0,0
            db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,0
            db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,0
            db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
            db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
            db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
            db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
            db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
            db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,0
            db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,0
            db 0,0,1,1,1,1,1,1,1,1,1,1,1,0,0
            db 0,0,0,1,1,1,1,1,1,1,1,1,0,0,0
            db 0,0,0,0,0,1,1,1,1,1,0,0,0,0,0

; --- MAIN CODE ---
start:
    ; Set VGA Mode 13h
    mov ax, 0013h
    int 10h

game_loop:
    ; 1. Handle Input (Non-blocking)
    mov ah, 01h
    int 16h
    jz no_key
    
    ; Flush keybuffer
    mov ah, 00h
    int 16h
    
    cmp ah, 4Bh ; Left Arrow
    je move_left
    cmp ah, 4Dh ; Right Arrow
    je move_right
    cmp al, ' ' ; Spacebar
    je shoot
    cmp ah, 01h ; Esc
    je exit_game
    jmp no_key

move_left:
    cmp player_x, 0
    jle no_key
    sub player_x, 5
    jmp no_key

move_right:
    cmp player_x, 300
    jge no_key
    add player_x, 5
    jmp no_key

shoot:
    cmp fire_cooldown, 0
    jg no_key
    
    mov cx, MAX_BULLETS
    xor bx, bx ; byte index
    xor di, di ; word index
shoot_find_loop:
    cmp bullet_act[bx], 0
    je found_slot
    inc bx
    add di, 2
    loop shoot_find_loop
    jmp no_key ; No empty slots

found_slot:
    mov bullet_act[bx], 1
    mov ax, player_x
    add ax, 7
    mov bullet_x[di], ax
    mov ax, player_y
    sub ax, 5
    mov bullet_y[di], ax
    mov fire_cooldown, 5 ; Cooldown between shots
    jmp no_key

no_key:
    ; 2. Game Logic
    cmp fire_cooldown, 0
    jle skip_cd
    dec fire_cooldown
skip_cd:

    call update_bullet
    call update_balloon
    call check_collision

    ; 3. Render Pipeline (Double Buffered to eliminate flickering)
    call clear_buffer    ; Fill offscreen buffer with black
    call draw_new        ; Draw game objects to offscreen buffer
    call blit_screen     ; Wait for VSYNC and copy buffer to Video Memory
    call draw_score      ; Draw Score UI over the top via BIOS

    jmp game_loop

player_die:
    ; Turn player red to indicate death
    mov player_col, 4
    call clear_buffer
    call draw_new
    call blit_screen
    call draw_score
    call draw_game_over

wait_retry:
    mov ah, 00h
    int 16h
    cmp al, 'r'
    je reset_game
    cmp al, 'R'
    je reset_game
    cmp ah, 01h ; Esc
    je exit_game
    jmp wait_retry

reset_game:
    mov score, 0
    mov balloon_y, 0
    mov balloon_act, 1
    mov player_x, 150
    mov player_col, 9
    mov fire_cooldown, 0
    
    ; Clear all bullets
    mov cx, MAX_BULLETS
    xor bx, bx
clear_bul:
    mov bullet_act[bx], 0
    inc bx
    loop clear_bul

    jmp game_loop

exit_game:
    ; Return to Text Mode (03h)
    mov ax, 0003h
    int 10h
    mov ah, 4Ch
    int 21h

; --- GAME LOGIC PROCEDURES ---

update_balloon proc
    cmp balloon_act, 1
    je move_balloon
    
    ; Respawn logic
    mov balloon_act, 1
    mov balloon_y, 0     ; Spawn at the top of the screen
    
    ; Randomize X coordinate
    push ax
    push bx
    push cx
    push dx
    mov ah, 2Ch        ; Get System Time
    int 21h
    xor ax, ax
    mov al, dl         ; Hundredths of a second
    mov bl, 3
    mul bl
    mov balloon_x, ax
    pop dx
    pop cx
    pop bx
    pop ax
    ret

move_balloon:
    add balloon_y, 2   ; Balloon moves DOWN
    cmp balloon_y, 185 ; Check if it reached the bottom
    jl check_player_col
    
    ; GAME OVER if it reached the bottom without getting shot
    jmp player_die
    
check_player_col:
    ; Box Collision Detection (Player vs Balloon)
    mov ax, balloon_x
    add ax, balloon_w
    cmp ax, player_x
    jl end_update_balloon

    mov ax, player_x
    add ax, player_w
    cmp balloon_x, ax
    jg end_update_balloon

    mov ax, balloon_y
    add ax, balloon_h
    cmp ax, player_y
    jl end_update_balloon

    mov ax, player_y
    add ax, player_h
    cmp balloon_y, ax
    jg end_update_balloon

    ; HIT PLAYER! 
    jmp player_die
    
end_update_balloon:
    ret
update_balloon endp

update_bullet proc
    mov cx, MAX_BULLETS
    xor bx, bx
    xor di, di
ub_loop:
    cmp bullet_act[bx], 1
    jne ub_next
    mov ax, bullet_y[di]
    sub ax, 5          ; Bullet moves UP
    mov bullet_y[di], ax
    cmp ax, 0
    jg ub_next
    mov bullet_act[bx], 0
ub_next:
    inc bx
    add di, 2
    loop ub_loop
    ret
update_bullet endp

check_collision proc
    cmp balloon_act, 1
    jne end_collision

    mov cx, MAX_BULLETS
    xor bx, bx
    xor di, di
cc_loop:
    cmp bullet_act[bx], 1
    jne cc_next

    ; Collision detection for bullet[di] vs balloon
    mov ax, bullet_x[di]
    add ax, bullet_w
    cmp ax, balloon_x
    jl cc_next

    mov ax, balloon_x
    add ax, balloon_w
    cmp bullet_x[di], ax
    jg cc_next

    mov ax, bullet_y[di]
    add ax, bullet_h
    cmp ax, balloon_y
    jl cc_next

    mov ax, balloon_y
    add ax, balloon_h
    cmp bullet_y[di], ax
    jg cc_next

    ; HIT BALLOON!
    mov balloon_act, 0
    mov bullet_act[bx], 0
    inc score
    jmp end_collision ; Balloon destroyed, stop checking bullets

cc_next:
    inc bx
    add di, 2
    loop cc_loop

end_collision:
    ret
check_collision endp

; --- RENDERING PROCEDURES (Double Buffered) ---

clear_buffer proc
    push ax
    push cx
    push di
    push es
    
    push ds
    pop es
    mov di, offset double_buffer
    mov cx, 32000      ; 64000 bytes / 2 bytes per word
    xor ax, ax         ; Fill with 0 (Black)
    rep stosw
    
    pop es
    pop di
    pop cx
    pop ax
    ret
clear_buffer endp

draw_new proc
    ; Draw Player
    mov ax, player_x
    mov rect_x, ax
    mov ax, player_y
    mov rect_y, ax
    mov ax, player_w
    mov rect_w, ax
    mov ax, player_h
    mov rect_h, ax
    mov al, player_col
    mov rect_c, al
    call draw_rect

    ; Draw Balloon Sprite
    cmp balloon_act, 1
    jne skip_draw_b
    mov ax, balloon_x
    mov rect_x, ax
    mov ax, balloon_y
    mov rect_y, ax
    mov al, balloon_col
    mov rect_c, al
    call draw_balloon_sprite
skip_draw_b:

    ; Draw Bullets
    mov cx, MAX_BULLETS
    xor bx, bx
    xor di, di
draw_bul_loop:
    cmp bullet_act[bx], 1
    jne draw_bul_next
    
    push cx
    push bx
    push di
    
    mov ax, bullet_x[di]
    mov rect_x, ax
    mov ax, bullet_y[di]
    mov rect_y, ax
    mov ax, bullet_w
    mov rect_w, ax
    mov ax, bullet_h
    mov rect_h, ax
    mov al, bullet_col
    mov rect_c, al
    call draw_rect
    
    pop di
    pop bx
    pop cx
    
draw_bul_next:
    inc bx
    add di, 2
    loop draw_bul_loop

    ret
draw_new endp

draw_rect proc
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    push ds
    pop es             ; Point ES to our current data segment (where buffer is)

    mov cx, rect_h
    mov bx, rect_y
row_loop:
    push cx
    mov cx, rect_w
    
    mov ax, 320
    push dx
    mul bx             ; DX:AX = AX * BX
    pop dx
    add ax, rect_x
    
    add ax, offset double_buffer ; Add offset to offscreen buffer
    mov di, ax
    
    mov al, rect_c
col_loop:
    mov es:[di], al
    inc di
    loop col_loop
    
    inc bx
    pop cx
    loop row_loop
    
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_rect endp

draw_balloon_sprite proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    push ds
    pop es
    
    mov si, offset balloon_bmp
    mov cx, 15 ; height
    mov bx, rect_y
row_loop_b:
    push cx
    mov cx, 15 ; width
    
    mov ax, 320
    push dx
    mul bx
    pop dx
    add ax, rect_x
    add ax, offset double_buffer
    mov di, ax
    
    mov dl, rect_c
col_loop_b:
    lodsb      ; AL = [SI], SI++
    test al, al
    jz skip_pixel
    mov es:[di], dl ; Draw pixel if sprite data is 1
skip_pixel:
    inc di
    loop col_loop_b
    
    inc bx
    pop cx
    loop row_loop_b
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_balloon_sprite endp

blit_screen proc
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ax, 0A000h
    mov es, ax         ; Destination: VGA Video Memory
    xor di, di
    
    mov si, offset double_buffer ; Source: Offscreen Buffer
    mov cx, 32000      ; 32,000 Words (64,000 Bytes)
    
    ; Wait for VSYNC (Hardware Blanking Period)
    mov dx, 03DAh
wait_vblank_loop1:
    in al, dx
    test al, 8
    jnz wait_vblank_loop1
wait_vblank_loop2:
    in al, dx
    test al, 8
    jz wait_vblank_loop2
    
    ; Extremely fast memory copy from DS:SI to ES:DI
    rep movsw
    
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret
blit_screen endp

draw_score proc
    push ax
    push bx
    push cx
    push dx
    push bp
    push es

    ; Convert score integer to ASCII string
    mov ax, score
    mov cx, 10
    mov bx, offset score_str + 10 ; point to last digit '0'
convert_loop:
    xor dx, dx
    div cx
    add dl, '0'
    mov [bx], dl
    dec bx
    test ax, ax
    jnz convert_loop
    
    ; Draw String using BIOS int 10h (AH=13h)
    mov ax, ds
    mov es, ax
    mov bp, offset score_str
    mov ah, 13h
    mov al, 00h
    mov bh, 0
    mov bl, 0Ah ; Light green
    mov cx, 11  ; Length of "SCORE: 0000"
    mov dh, 1   ; Row
    mov dl, 1   ; Col
    int 10h
    
    pop es
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_score endp

draw_game_over proc
    push ax
    push bx
    push cx
    push dx
    push bp
    push es

    mov ax, ds
    mov es, ax
    mov bp, offset go_str
    mov ah, 13h
    mov al, 00h
    mov bh, 0
    mov bl, 0Ch ; Light Red
    mov cx, 27  ; Length
    mov dh, 12  ; Row (middle)
    mov dl, 6   ; Col (approx centered)
    int 10h
    
    pop es
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_game_over endp

; --- DOUBLE BUFFER ALLOCATION ---
; In a .COM file, DOS gives us all available memory in the segment (up to 64KB).
; By placing this label at the very end of our code, we can safely use the remaining
; ~64,000 bytes as our offscreen pixel buffer without overwriting our instructions.
double_buffer equ $

end start
