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
    inputHandle dd 0    ;Variavel para armazenar o handle de entrada
    outputHandle dd 0   ;Variavel para armazenar o handle de saida
    console_count dd 0  ;Variavel para armazenar caracteres lidos/escritos na console
    tamanho_string dd 0     ;Variavel para armazenar tamanho de string terminada em 0

    ;Prompt strings
    prompt_nome_arq db "Digite o nome do arquivo: ", 0
    prompt_coord_x db "Digite a coordenada x: ", 0
    prompt_coord_y db "Digite a coordenada y: ", 0
    prompt_largura db "Digite a largura da censura: ", 0
    prompt_altura db "Digite a altura da censura: ", 0

    ;Strings a serem preenchidas
    nome_arquivo_str db 50 dup(0)
    coord_x_str db 50 dup(0)
    coord_y_str db 50 dup(0)
    largura_str db 50 dup(0)
    altura_str db 50 dup(0)

    ;Variáveis que guardarão os valores numéricos
    coord_x DWORD 0
    coord_y DWORD 0
    largura_censura DWORD 0
    altura_censura DWORD 0

    ;Handle do arq (guarda retorno do readFile)
    input_file_handle DWORD 0
    output_file_handle DWORD 0

    ;Array que guardará uma linha da imagem (tam max p/ imagens 4k)
    ;3 bytes/pixel multiplicados por 2160 pixels
    img_width_pixel_buffer db 6480 dup(0)

    ;;Guardará os primeiros 18 bytes do header do arq de input
    ;;E os últimos 32 bytes do header
    header_section1 db 18 dup(0)
    header_section2 db 28 dup(0)

    ;;Guardar largura e altura do arq de input
    arquivo_largura db 4 dup(0)
    arquivo_altura db 4 dup(0)

    ;;Contador de quantos bytes efetivamente foram lidos em cada read (basically an EOF flag aq)
    effectively_read_bytes db 4 dup(0)
    effectively_written_bytes db 4 dup(0)

    ;;Nome do arq de saída
    output_file_name db "censura.bmp", 0

.code
start:
;;;Prompts de entrada;;;

    ;Setup dos Handles
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov inputHandle, eax
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov outputHandle, eax

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

;;;Remoção do '/n' em coord_x, coord_y, altura e largura;;;

    ;Tirar CR da str nome_do_arquivo
    mov esi, offset nome_arquivo_str ;Salva o ptr da string
proximo_label_nome_arquivo_str:
    mov al, [esi]   ;move char da iter atual pra al (8-bit)
    inc esi ;move ptr + 1 (prox char)
    cmp al, 13  ;Verifica se al esta com o CR
    jne proximo_label_nome_arquivo_str   ;Ele so passa daqui se al estiver guardando CR
    dec esi ;ptr pro char anterior
    xor al, al ;zera al
    mov [esi], al   ;Troca o cr por 0

    ;Zera esi e al pra usar de novo
    xor esi, esi
    xor al, al

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

;;;Conversões de coord_x, coord_y, altura e largura para dword (4 bytes);;;

    ;Limpar eax que vai armazenar os valores numéricos
    xor eax, eax

    ;Converte as strings em dwords (por meio de eax)
    ;e as armazena nas variáveis
    invoke atodw, addr coord_x_str
    mov coord_x, eax

    invoke atodw, addr coord_y_str
    mov coord_y, eax

    invoke atodw, addr largura_str
    mov largura_censura, eax

    invoke atodw, addr altura_str
    mov altura_censura, eax

;;;Manipulando arquivos;;;

;;Leitura do arquivo source
    ;Abrindo o arquivo source (bmp file)
    invoke CreateFile, addr nome_arquivo_str, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov input_file_handle, eax ;armazena o handle

    ;Ler 18 (14 + 4) bytes do header
    invoke ReadFile, input_file_handle, addr header_section1, 18, addr effectively_read_bytes, NULL

    ;;Ler largura e altura da imagem e as salva em suas vars
    invoke ReadFile, input_file_handle, addr arquivo_largura, 4, addr effectively_read_bytes, NULL
    invoke ReadFile, input_file_handle, addr arquivo_altura, 4, addr effectively_read_bytes, NULL

    ;Ler os últimos 32 bytes do header
    invoke ReadFile, input_file_handle, addr header_section2, 28, addr effectively_read_bytes, NULL

;;Escrita para o arquivo de censor
    ;Criação do arquivo de output
    invoke CreateFile, addr output_file_name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov output_file_handle, eax

    ;;Escrita do header do arquivo (52 bytes total)
    ;Escreve primeiros 18 bytes
    invoke WriteFile, output_file_handle, addr header_section1, 18, addr effectively_written_bytes, NULL

    ;Escreve largura e altura da imagem
    invoke WriteFile, output_file_handle, addr arquivo_largura, 4, addr effectively_written_bytes, NULL
    invoke WriteFile, output_file_handle, addr arquivo_altura, 4, addr effectively_written_bytes, NULL

    ;Escreve últimos 328 bytes do header
    invoke WriteFile, output_file_handle, addr header_section2, 28, addr effectively_written_bytes, NULL

    invoke ExitProcess, 0
end start

;;;Entrada
;Prompt e entrada do nome do arquivo - 
;Prompt de entrada de posição x - 
;Prompt de entrada de posição y - 
;Prompt de largura -
;Prompt de altura -

;;Remover /n da str de numeros -
;;Converter posicoes x e y e largura e altura em dword -

;;;Manipulaçao de arquivo
;;Abrir arquivo de input e ouput -
;;Ler header do arq. de input e escrever no arq. de output -
;;Copiar pixels da imagem em si
;;Add censura do arquivo (função(addr_array, coordX, largura_da_censura)