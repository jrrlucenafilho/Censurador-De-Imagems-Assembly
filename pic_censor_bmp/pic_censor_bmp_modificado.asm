.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\msvcrt.inc
include \masm32\include\masm32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\msvcrt.lib
includelib \masm32\lib\masm32.lib

include \masm32\macros\macros.asm
.data
    ;Strings a serem preenchidas
    nome_arquivo_str db 50 dup(0)
    coord_x_str db 50 dup(0)
    coord_y_str db 50 dup(0)
    largura_str db 50 dup(0)
    altura_str db 50 dup(0)
    

    ;Vari�veis que guardar�o os valores num�ricos
    coord_x DWORD 0
    coord_y DWORD 0
    largura DWORD 0
    altura DWORD 0

    ;Prompt strings
    prompt_nome_arq db "Digite o nome do arquivo: ", 0
    prompt_coord_x db "Digite a coordenada x: ", 0
    prompt_coord_y db "Digite a coordenada y: ", 0
    prompt_largura db "Digite a largura da censura: ", 0
    prompt_altura db "Digite a altura da censura: ", 0

    inputHandle dd 0    ;Variavel para armazenar o handle de entrada
    outputHandle dd 0   ;Variavel para armazenar o handle de saida
    console_count dd 0  ;Variavel para armazenar caracteres lidos/escritos na console
    tamanho_string dd 0     ;Variavel para armazenar tamanho de string terminada em 0

.code
start:
;;;Prompts de entrada;;;
    ;Setup dos Handles
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov inputHandle, eax
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov outputHandle, eax

    ;handle para escrever no console de sa�da 
    push std_output_handle

    ;Handle � gravado em EAX
    call GetStdHandle
    mov outputHandle, eax
    invoke WriteConsole, outputHandle, addr output, 50, addr write_count, NULL
   

    ;Escrever prompt do nome do arq
    invoke StdOut, addr prompt_nome_arq
    
    ;Entrada do nome do arquivo
    invoke ReadConsole, inputHandle, addr nome_arquivo_str, sizeof nome_arquivo_str, addr console_count, NULL

    ;Escrever prompt da coord x
    invoke StdOut, addr prompt_coord_x

    ;Entrada da coord x (como str)
    invoke ReadConsole, inputHandle, addr coord_x_str, sizeof coord_x_str, addr console_count, NULL

    ;Escrever prompt da coord y
    invoke StdOut, addr prompt_coord_y
    
    ;Entrada da coord y (como str)
    invoke ReadConsole, inputHandle, addr coord_y_str, sizeof coord_y_str, addr console_count, NULL

    ;Escrever prompt largura
    invoke StdOut, addr prompt_largura

    ;Entrada da largura (como str)
    invoke ReadConsole, inputHandle, addr largura_str, sizeof largura_str, addr console_count, NULL

    ;Escrever prompt altura
    invoke StdOut, addr prompt_altura

    ;Entrada da altura (como str)
    invoke ReadConsole, inputHandle, addr altura_str, sizeof altura_str, addr console_count, NULL

;;;Remo��o do '/n' em coord_x, coord_y, altura e largura;;;
    ;Tirar CR da coord_x
    mov esi, offset coord_x_str ;Salva o ptr da string
proximo_label_coord_x_str:
    mov al, [esi]   ;move char da iter atual pra al (8-bit)
    inc esi ;move ptr + 1 (prox char)
    cmp al, 13  ;Verifica se al esta com o CR
    jne proximo_label_coord_x_str   ;Ele so passa daqui se al estiver guardando CR
    dec esi ;ptr pro char anterior
    xor al, al ;zera al
    mov [esi], al   ;Troca o cr por 0

    ;Zera esi e al pra usar de novo
    xor esi, esi
    xor al, al

   ;Tirar CR da coord_y
    mov esi, offset coord_y_str

proximo_label_coord_y_str:
    mov al, [esi]   ;move char da iter atual pra al (8-bit)
    inc esi ;move ptr + 1 (prox char)
    cmp al, 13  ;Verifica se al esta com o CR
    jne proximo_label_coord_y_str   ;Ele so passa daqui se al estiver guardando CR
    dec esi ;ptr pro char anterior
    xor al, al ;zera al
    mov [esi], al   ;Troca o cr por 0

    ;Zera esi e al pra usar de novo
    xor esi, esi
    xor al, al

    ;Tirar CR da largura
    mov esi, offset largura_str

proximo_label_largura_str:
    mov al, [esi]   ;move char da iter atual pra al (8-bit)
    inc esi ;move ptr + 1 (prox char)
    cmp al, 13  ;Verifica se al esta com o CR
    jne proximo_label_largura_str   ;Ele so passa daqui se al estiver guardando CR
    dec esi ;ptr pro char anterior
    xor al, al ;zera al
    mov [esi], al   ;Troca o cr por 0

    ;Zera esi e al pra usar de novo
    xor esi, esi
    xor al, al

    ;Tirar CR da altura
    mov esi, offset altura_str

proximo_label_altura_str:
    mov al, [esi]   ;move char da iter atual pra al (8-bit)
    inc esi ;move ptr + 1 (prox char)
    cmp al, 13  ;Verifica se al esta com o CR
    jne proximo_label_altura_str   ;Ele so passa daqui se al estiver guardando CR
    dec esi ;ptr pro char anterior
    xor al, al ;zera al
    mov [esi], al   ;Troca o cr por 0

    ;Zera esi e al pra usar de novo
    xor esi, esi
    xor al, al

;;;Convers�es de coord_x, coord_y, altura e largura para dword (4 bytes);;;
    ;Limpar eax que vai armazenar os valores num�ricos
    xor eax, eax

    ;Converte as strings em dwords (num ir� pra o eax)
    ;e as armazena nas vari�veis
    invoke atodw, addr coord_x_str  ;TODO: pode ser necessario esvaziar eax cada vez, mas acho que nao
    mov coord_x, eax

    invoke atodw, addr coord_y_str
    mov coord_y, eax

    invoke atodw, addr largura_str
    mov largura, eax

    invoke atodw, addr altura_str
    mov altura, eax

    invoke ExitProcess, 0
end start

;;;Entrada
;Prompt e entrada do nome do arquivo - 
;Prompt de entrada de posi��o x - 
;Prompt de entrada de posi��o y - 
;Prompt de largura -
;Prompt de altura -

;;Remover /n da str de numeros -
;;Converter posicoes x e y e largura e altura em dword -

;;;Manipula�ao de arquivo
;Pegar a str do nome de arquivo e abrir o arquivo com esse nome
;;Censura do arquivo (fun��o(ender_array, coordX, largura_da_censura)
;Escrever no arquivo de sa�da