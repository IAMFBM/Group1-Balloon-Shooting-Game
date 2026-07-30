; Balloon Shooting Game for EMU8086 / DOSBox (Top-Down, Player Death)
; Environment: DOS 16-bit
; Video Mode: VGA Mode 13h (320x200, 256 colors)

org 100h
jmp start

; --- VARIABLES ---
player_x    dw 150
player_y    dw 185
player_w    dw 20
player_h    dw 10
player_col  db 9

old_px      dw 150
old_py      dw 185

balloon_x   dw 100
balloon_y   dw 0      ; Start at TOP
balloon_w   dw 15
balloon_h   dw 15
balloon_col db 4
balloon_act db 1

old_bx      dw 100
old_by      dw 0
old_bact    db 1

bullet_x    dw 0
bullet_y    dw 0
bullet_w    dw 2
bullet_h    dw 5
bullet_col  db 14
bullet_act  db 0

old_bulx    dw 0
old_buly    dw 0
old_bulact  db 0

score       dw 0

rect_x dw 0
rect_y dw 0
rect_w dw 0
rect_h dw 0
rect_c db 0

; --- MAIN CODE ---
start:
    mov ax, 0013h
    int 10h

game_loop:
    ; 1. Handle Input
    mov ah, 01h
    int 16h
    jz no_key
    
    mov ah, 00h
    int 16h
    
    cmp ah, 4Bh ; Left
    je move_left
    cmp ah, 4Dh ; Right
    je move_right
    cmp al, ' ' ; Space
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
    cmp bullet_act, 1
    je no_key
    mov bullet_act, 1
    mov ax, player_x
    add ax, 9
    mov bullet_x, ax
    mov ax, player_y
    mov bullet_y, ax
    jmp no_key

no_key:
    ; 2. Game Logic
    call update_bullet
    call update_balloon
    call check_collision

    ; 3. Wait for Vertical Blank (VBLANK) to prevent flickering and control speed (70 FPS)
    call wait_vblank

    ; 4. ERASE OLD POSITIONS
    call erase_old

    ; 5. DRAW NEW POSITIONS
    call draw_new

    ; 6. SAVE CURRENT TO OLD
    call save_old

    jmp game_loop

player_die:
    ; Turn player red to indicate death
    mov player_col, 4
    call draw_new
    
    ; 1.5 second delay so the player can see they died
    mov cx, 0016h
    mov dx, 0E360h ; ~1.5 million microseconds
    mov ah, 86h
    int 15h
    
    jmp exit_game

exit_game:
    mov ax, 0003h
    int 10h
    mov ah, 4Ch
    int 21h

; --- GAME LOGIC PROCEDURES ---

update_balloon proc
    cmp balloon_act, 1
    je move_balloon
    
    ; respawn logic
    mov balloon_act, 1
    mov balloon_y, 0   ; Spawn at the top of the screen
    
    ; randomize X 
    push ax
    push bx
    push cx
    push dx
    mov ah, 2Ch 
    int 21h
    xor ax, ax
    mov al, dl
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
    cmp balloon_y, 185 ; Check if it reached the bottom (near player)
    jl check_player_col
    
    ; Despawn if it missed the player and hit the ground
    mov balloon_act, 0
    ret
    
check_player_col:
    ; Check if balloon intersects the player
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
    cmp bullet_act, 1
    jne end_update_bullet
    sub bullet_y, 5
    cmp bullet_y, 0
    jg end_update_bullet
    mov bullet_act, 0
end_update_bullet:
    ret
update_bullet endp

check_collision proc
    cmp bullet_act, 1
    jne end_collision
    cmp balloon_act, 1
    jne end_collision

    mov ax, bullet_x
    add ax, bullet_w
    cmp ax, balloon_x
    jl end_collision

    mov ax, balloon_x
    add ax, balloon_w
    cmp bullet_x, ax
    jg end_collision

    mov ax, bullet_y
    add ax, bullet_h
    cmp ax, balloon_y
    jl end_collision

    mov ax, balloon_y
    add ax, balloon_h
    cmp bullet_y, ax
    jg end_collision

    mov balloon_act, 0
    mov bullet_act, 0
    inc score
end_collision:
    ret
check_collision endp

; --- RENDERING PROCEDURES ---

wait_vblank proc
    push dx
    push ax
    mov dx, 03DAh
wait_vblank_loop1:
    in al, dx
    test al, 8
    jnz wait_vblank_loop1
wait_vblank_loop2:
    in al, dx
    test al, 8
    jz wait_vblank_loop2
    pop ax
    pop dx
    ret
wait_vblank endp

erase_old proc
    ; Erase Player
    mov ax, old_px
    mov rect_x, ax
    mov ax, old_py
    mov rect_y, ax
    mov ax, player_w
    mov rect_w, ax
    mov ax, player_h
    mov rect_h, ax
    mov rect_c, 0 ; Black
    call draw_rect

    ; Erase Balloon
    cmp old_bact, 1
    jne skip_erase_b
    mov ax, old_bx
    mov rect_x, ax
    mov ax, old_by
    mov rect_y, ax
    mov ax, balloon_w
    mov rect_w, ax
    mov ax, balloon_h
    mov rect_h, ax
    mov rect_c, 0
    call draw_rect
skip_erase_b:

    ; Erase Bullet
    cmp old_bulact, 1
    jne skip_erase_bul
    mov ax, old_bulx
    mov rect_x, ax
    mov ax, old_buly
    mov rect_y, ax
    mov ax, bullet_w
    mov rect_w, ax
    mov ax, bullet_h
    mov rect_h, ax
    mov rect_c, 0
    call draw_rect
skip_erase_bul:
    ret
erase_old endp

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

    ; Draw Balloon
    cmp balloon_act, 1
    jne skip_draw_b
    mov ax, balloon_x
    mov rect_x, ax
    mov ax, balloon_y
    mov rect_y, ax
    mov ax, balloon_w
    mov rect_w, ax
    mov ax, balloon_h
    mov rect_h, ax
    mov al, balloon_col
    mov rect_c, al
    call draw_rect
skip_draw_b:

    ; Draw Bullet
    cmp bullet_act, 1
    jne skip_draw_bul
    mov ax, bullet_x
    mov rect_x, ax
    mov ax, bullet_y
    mov rect_y, ax
    mov ax, bullet_w
    mov rect_w, ax
    mov ax, bullet_h
    mov rect_h, ax
    mov al, bullet_col
    mov rect_c, al
    call draw_rect
skip_draw_bul:
    ret
draw_new endp

save_old proc
    mov ax, player_x
    mov old_px, ax
    mov ax, player_y
    mov old_py, ax

    mov ax, balloon_x
    mov old_bx, ax
    mov ax, balloon_y
    mov old_by, ax
    mov al, balloon_act
    mov old_bact, al

    mov ax, bullet_x
    mov old_bulx, ax
    mov ax, bullet_y
    mov old_buly, ax
    mov al, bullet_act
    mov old_bulact, al
    ret
save_old endp

draw_rect proc
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0A000h
    mov es, ax

    mov cx, rect_h
    mov bx, rect_y
row_loop:
    push cx
    mov cx, rect_w
    
    mov ax, 320
    push dx
    mul bx      ; DX:AX = AX * BX
    pop dx
    add ax, rect_x
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

end start
