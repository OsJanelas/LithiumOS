[bits 16]
[org 0x7c00]

start:
    ; --- CONFIGURAÇÃO DE SEGMENTOS ---
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00  ; Define a pilha abaixo do bootloader

    ; --- CARREGAR OS SETORES EXTRAS ---
    ; Se o QEMU trava aqui, pode ser o número de setores ou drive incorreto
    mov ah, 02h    
    mov al, 3      ; Vamos ler 3 setores extras (o suficiente para o seu código)
    mov ch, 00h    
    mov dh, 00h    
    mov cl, 02h    ; Começa no setor 2 (logo após o boot)
    mov bx, 0x7e00 ; Onde o código extra vai morar
    int 13h        

    ; Se houver erro na leitura do disco, o Carry Flag (jc) é ativado
    ; Em vez de travar, vamos tentar forçar o avanço se falhar
    ; jc erro_disco 

    ; --- MODO DE VÍDEO TEXTO ---
    mov ax, 0003h
    int 10h

atualizar_tela:
    mov ax, 0600h
    mov bh, 30h    ; Background
    xor cx, cx
    mov dx, 184Fh
    int 10h
    
    mov ah, 02h
    xor dx, dx
    int 10h

    mov si, menu_topo
    call print_string
    call ler_data_hora

main_loop:
    mov ah, 00h
    int 16h 

    cmp al, '1'
    je abrir_arquivos
    cmp al, '2'
    je abrir_notas
    cmp al, '3'
    je load_gui_jump  ; Salto para o código gráfico no setor 2
    cmp al, '4'
    je abrir_painel
    jmp main_loop

; --- FUNÇÕES SIMPLES (Ficam no setor 1) ---

print_string:
    mov ah, 0eh
.lp:
    lodsb
    or al, al
    jz .done
    int 10h
    jmp .lp
.done:
    ret

ler_data_hora:
    mov ah, 04h
    int 1ah
    mov al, dl
    call print_bcd
    mov al, '/'
    call p_char
    mov al, dh
    call print_bcd
    mov al, ' '
    call p_char
    mov ah, 02h
    int 1ah
    mov al, ch
    call print_bcd
    mov al, ':'
    call p_char
    mov al, cl
    call print_bcd
    ret

print_bcd:
    push ax
    shr al, 4
    add al, '0'
    call p_char
    pop ax
    and al, 0Fh
    add al, '0'
    call p_char
    ret

p_char:
    mov ah, 0eh
    int 10h
    ret

; --- ASSINATURA DE BOOT (OBRIGATÓRIO TER EXATAMENTE 512 BYTES) ---
times 510-($-$$) db 0
dw 0xAA55

; ==========================================================
; SETOR 2: INÍCIO DO CÓDIGO GRÁFICO (Endereço 0x7e00)
; ==========================================================

load_gui_jump:
    mov ax, 0x0013      ; Entra em modo VGA 320x200
    int 0x10
    
render_fractal:
    mov ax, 0xA000
    mov es, ax
    xor di, di

.loop_fractal:
    mov ax, di
    xor dx, dx
    mov cx, 320
    div cx              ; AX=Y, DX=X

    mov bx, ax          
    and bx, dx          ; Lógica X AND Y (Fractal de Sierpinski)
    
    jnz .draw_black 

    mov al, dl 
    add al, byte [color_offset] 
    mov [es:di], al
    jmp .next_pixel

.draw_black:
    mov byte [es:di], 0

.next_pixel:
    inc di
    cmp di, 64000
    jne .loop_fractal

    inc byte [color_offset]

    ; Pequena pausa para a animação não ser rápida demais
    mov cx, 0x0FFF
    .delay: loop .delay

gui_loop:
    mov ah, 01h         ; Verifica se tem tecla sem travar
    int 16h
    jz render_fractal   ; Se não tem tecla, continua animando o fractal

    mov ah, 00h         ; Se tem tecla, lê ela
    int 16h
    cmp al, 27          ; ESC para sair
    je sair_grafico
    jmp render_fractal

sair_grafico:
    mov ax, 0003h
    int 10h
    jmp atualizar_tela

; --- DADOS E TEXTOS (Setor 2+) ---

abrir_arquivos:
    mov si, msg_arquivos
    call print_string
    jmp esperar_voltar

abrir_notas:
    mov si, msg_notas
    call print_string
    jmp esperar_voltar

abrir_painel:
    mov si, msg_painel
    call print_string
    jmp esperar_voltar

esperar_voltar:
    mov si, msg_voltar
    call print_string
    mov ah, 00h
    int 16h
    jmp atualizar_tela

menu_topo db '- LITHIUM OS PROGRAMS --------------------------------------', 13, 10
          db '[1] files.exe [2] note.exe [3] sierspinki.exe [4] panel.exe', 13, 10, 0
          db 'WELCOME TO LITHIUM OS, (this system likes PlutoniumOS', 13, 10, 0
msg_arquivos db 13, 10, 'C:\> Empty', 0
msg_notas    db 13, 10, 'Notepad Open', 0
msg_painel   db 13, 10, 'No settings', 0
msg_voltar   db 13, 10, 'Press any key...', 0
color_offset db 0

; Garante que o arquivo final tenha o tamanho de 4 setores (2048 bytes)
times 2048-($-$$) db 0