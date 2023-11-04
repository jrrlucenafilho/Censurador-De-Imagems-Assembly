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
    inputHandle dd 0    ;Guarda handle de entrada
    outputHandle dd 0   ;Guarda handle de saída
    console_count dd 0  ;Guarda chars lidos/escritos na console

    ;Prompt strings
    prompt_nome_arq db "Digite o nome do arquivo de entrada: ", 0
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

    ;Guardará os primeiros 18 bytes do header do arq de input
    ;E os últimos 32 bytes do header
    header_section1 db 18 dup(0)
    header_section2 db 32 dup(0)

    ;Guardar largura do arq de input
    arquivo_largura DWORD 0

    ;Guarda o número de bytes que uma linha possui (guarda largura_imagem * 3)
    img_line_byte_num DWORD 0

    ;Contador de quantos bytes efetivamente foram lidos e escritos (basically an EOF flag aq)
    effectively_read_bytes DWORD 0
    effectively_written_bytes DWORD 0

    ;Nome do arq de saída
    output_file_name db "imagem_censurada_output.bmp", 0

    ;Array que guardará os bytes de uma linha da imagem (tam max p/ imagens 4k)
    ;3 bytes/pixel multiplicados por 2160 pixels
    img_line_bytes_buffer db 6480 dup(0)

    ;Counts the number of pixels that have been currently iterated through in the line buffer
    ;So as to check when to start censoring and when to stop censoring the line buffer
    buffer_painted_pixels_counter DWORD 0

    ;Counts the height currently iterated by line buffer (in lines ofc)
    y_pos_counter DWORD 0

.code
;;Censoring-line-buffer function
;;CensorLineBuffer(img_line_bytes_buffer, coord_x, largura_censura)
CensorLineBuffer:
    ;Prologue
    push ebp
    mov ebp, esp
    sub esp, 20 ;Reserva bytes para 5 vars locais de 4 bytes (5 vars * 4 bytes = 20 bytes)

;;Estrutura da Pilha durante essa função
    ;;Parameters:
    ;DWORD PTR [ebp+8] = offset img_line_bytes_buffer
    ;DWORD PTR [ebp+12] = coord_x
    ;DWORD PTR [ebp+16] = largura_censura

    ;Vars locais:
    ;DWORD PTR [ebp-4] = buffer_painted_pixels_counter
    ;DWORD PTR [ebp-8] = eax_initial_value   ;;These "reg_initial_value" will save the values of each reg before they were used in this function
    ;DWORD PTR [ebp-12] = ebx_initial_value  ;;Since this is a windows program, and so should follow the Callee Clean-up convention
    ;DWORD PTR [ebp-16] = ecx_initial_value  ;;Which means it just needs to preserve used regs' previous values
    ;DWORD PTR [ebp-20] = edx_initial_value

    ;Salva o valor inicial de eax na pilha
    ;(Deixa um "buraco" na pilha pois tenho que usar o eax para salvar buffer_painted_pixels_counter como a primeira var local)
    ;(Portanto, tenho que salvar eax antes de usá-lo, e fazer assim me permite deixar todos os "reg_initial_value"'s juntos no topo da pilha)
    mov DWORD PTR [ebp-8], eax

    ;Movendo buffer_painted_pixels_counter para a pilha como var local (grava zero mesmo, no início)
    mov eax, buffer_painted_pixels_counter
    mov DWORD PTR [ebp-4], eax

    ;Empilhando os outros valores dos regs usados antes de usá-los
    push ebx
    push ecx
    push edx

    ;First, save largura in ecx
    mov ecx, DWORD PTR [ebp+16]

    ;;Iterar pela pelo buffer
    ;if(pixel_atual >= coord_x && pixel_atual <= (coord_x + largura)){ pintar de preto }
    ;move ptr to x_coord in line buffer, using lea (load effective address)
    ;move coord_x in the line buffer to ebx (to be used as an index)
    ;But first, I need to multiply x_coord by 3, since x_coord is meant as in pixels
    ;And i need to convert it to bytes
    
    ;So I just load coord_x to ebx
    mov ebx, [ebp+12]

    ;Then multiply ebx by 3 (1 pixel = 3 bytes)
    imul ebx, 3

    ;Calculate the address of the desired first-to-be-censored byte in line buffer
    lea eax, img_line_bytes_buffer[ebx] 
    
    ;Now eax points to coord_x's pixel first byte, just need to paint it black until (coord_x + largura)
paint_it_black_label:
    ;First, set the first 3 bytes to 0 (sets the first pixel in line buffer to black)
    mov BYTE PTR [eax], 0    ;Set blue byte to 0
    mov BYTE PTR [eax+1], 0  ;Set green byte to 0
    mov BYTE PTR [eax+2], 0  ;Set red byte to 0

    ;Now we need to make eax point to (eax + 3) (next pixel's blue byte)
    add eax, 3 ;Now eax points to the next pixel's blue byte

    ;Increase the painted_pixels_counter by 1 for each pixel painted black
    inc DWORD PTR [ebp-4]

    ;;Setting up the stopping condition
    ;;Compares if buffer_painted_pixels_counter == (largura)
    ;First, loads buffer_painted_pixels_counter to edx
    mov edx, DWORD PTR [ebp-4]

    ;Compares if buffer_painted_pixels_counter (in edx) == (largura) (in ecx)
    cmp edx, ecx

    ;If they're different, it means it hasn't painted the whole section asked in line buffer to black
    ;So jump back to label
    jne paint_it_black_label
    ;If they're equal, then the correct width has been painted and the function is finished

    ;Epilogue
    ;Popping os regs usados, para recuperarem seus valores anteriores ao seu uso na função (Callee-Cleanup convention)
    pop edx
    pop ecx
    pop ebx
    mov eax, DWORD PTR [ebp-8]

    mov esp, ebp
    pop ebp
    ret 12  ;Desempilha os 3 params (4 bytes * 3 params = 12 bytes)

;;RemoveCarriageReturn(addr string)
;Tira CR da str recebida como param
RemoveCarriageReturn:
    ;Prologue
    push ebp
    mov ebp, esp
    sub esp, 8

;;Estrutura da Pilha durante essa função
    ;;Parameters:
    ;DWORD PTR [ebp+8] = offset to_be_cleaned_str

    ;;Local vars:
    ;DWORD PTR [ebp-4] = esi_initial_value  ;;Preserving previosu reg values in order to follow the Callee Clean-up convention
    ;DWORD PTR [ebp-8] = eax_initial_value (for al)

    ;Storing esi's and eax's previous values
    push esi
    push eax

    mov esi, DWORD PTR [ebp+8] ;Salva o ptr da string
next_to_be_cleaned_str_label:
    mov al, [esi]   ;Move char da iter atual pra al (8-bit)
    inc esi ;Move ptr + 1 (prox char)
    cmp al, 13  ;Verifica se al tá com o CR
    jne next_to_be_cleaned_str_label  ;Ele so passa daqui se al estiver guardando CR
    dec esi ;Aponta o ptr pro char anterior
    xor al, al  ;Zera al
    mov [esi], al   ;Troca o CR por 0

    ;Zera esi e al pra usar de novo
    xor esi, esi
    xor al, al    

    ;Epilogue
    pop eax
    pop esi

    mov esp, ebp
    pop ebp
    ret 4

start:
;;Prompts de entrada
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

    ;Tira CR da str nome_do_arquivo
    push offset nome_arquivo_str
    call RemoveCarriageReturn

    ;Tira CR da coord_x
    push offset coord_x_str
    call RemoveCarriageReturn

    ;Tira CR da coord_y
    push offset coord_y_str
    call RemoveCarriageReturn

    ;Tira CR da largura
    push offset largura_str
    call RemoveCarriageReturn

    ;Tira CR da altura
    push offset altura_str
    call RemoveCarriageReturn

;;Conversões de coord_x, coord_y e largura para dword (4 bytes)
    ;Converte as strings em dwords (por meio de eax) e as armazena nas variáveis
    invoke atodw, addr coord_x_str
    mov coord_x, eax

    invoke atodw, addr coord_y_str
    mov coord_y, eax

    invoke atodw, addr largura_str
    mov largura_censura, eax

    invoke atodw, addr altura_str
    mov altura_censura, eax

;;;Manipulando arquivos;;;
    ;Leitura do header do arquivo source
    ;Abrindo o arquivo source (bmp file)
    invoke CreateFile, addr nome_arquivo_str, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov input_file_handle, eax ;armazena o handle

    ;Ler 18 (14 + 4) bytes do header
    invoke ReadFile, input_file_handle, addr header_section1, 18, addr effectively_read_bytes, NULL

    ;;Ler largura da imagem e as salva em suas vars
    invoke ReadFile, input_file_handle, addr arquivo_largura, 4, addr effectively_read_bytes, NULL

    ;Ler os últimos 28 bytes do header
    invoke ReadFile, input_file_handle, addr header_section2, 32, addr effectively_read_bytes, NULL

;;Escrita para o header do arquivo de output
    ;Criação do arquivo de output
    invoke CreateFile, addr output_file_name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov output_file_handle, eax

    ;;Escrita do header do arquivo (52 bytes total)
    ;Escreve primeiros 18 bytes
    invoke WriteFile, output_file_handle, addr header_section1, 18, addr effectively_written_bytes, NULL

    ;Escreve largura da imagem
    invoke WriteFile, output_file_handle, addr arquivo_largura, 4, addr effectively_written_bytes, NULL

    ;Escreve últimos 32 bytes do header
    invoke WriteFile, output_file_handle, addr header_section2, 32, addr effectively_written_bytes, NULL

;;Lendo os bytes dos pixels da img de entrada e escrevendo na de saída
    ;1. Lê próx linha e a salva no buffer
    ;2. Escreve a linha do buffer na img de saída (E censura se for uma das linha escolhidas pra isso)
    ;3. se não chegar em EOF, volta pro 1.

    ;Multiplica a largura por 3 e guarda em img_line_byte_num
    mov ebx, arquivo_largura
    imul ebx, 3
    mov img_line_byte_num, ebx

copy_img_line_label:
    ;Lê bytes da img de input até a (largura da imagem * 3) e salva no buffer de linha
    invoke ReadFile, input_file_handle, addr img_line_bytes_buffer, img_line_byte_num, addr effectively_read_bytes, NULL

;;CensorLineBuffer function call here
    ;;Should only call this function if y_pos_counter is between y_pos and y_pos + altura
    ;;if(y_pos_counter < coord_y || y_pos_counter > (coord_y + (altura-1)){ não censurar essa linha }
    ;First, save the decreased-by-one value of height on eax
    mov eax, altura_censura

    ;Decrease it by one (censor should got from coord_y up to height-1)
    dec eax

    ;Checks if current line (y position) should not be censored, by comparing it to altura_censura-1 (in eax)
    mov ebx, coord_y
    cmp y_pos_counter, ebx

    ;And skips calling the censor-line-function if y_pos_counter is lower than coord_y
    jl line_should_skip_censoring_label

    ;Also skips calling the censor-line-function if y_pos_counter is higher than (coord_y + (altura_censura-1)) (in ebx)
    ;First loads (altura_censura-1) to ebx (from eax)
    mov ebx, eax

    ;Then adds coord_y's value to it, ebx now holds coord_y + (altura_censura-1)
    add ebx, coord_y

    ;Time to compare
    cmp y_pos_counter, ebx

    ;Skips censoring current line buffer in case y_pos_counter is higher than (coord_y + (altura_censura-1))
    jg line_should_skip_censoring_label

    ;Pushing params and calling function
    push largura_censura
    push coord_x
    push offset img_line_bytes_buffer
    call CensorLineBuffer

line_should_skip_censoring_label:
    ;Escreve na img de output a linha que está no buffer até a (largura da imagem * 3)
    invoke WriteFile, output_file_handle, addr img_line_bytes_buffer, img_line_byte_num, addr effectively_written_bytes, NULL

    ;+1 to y_pos_counter
    inc y_pos_counter

    ;Checa se chegou no EOF usando effectively_read_bytes != 0?
    ;Se não, volta pro início do label. Se sim, continua o programa
    cmp effectively_read_bytes, 0
    jne copy_img_line_label

    ;Close both file handles
    invoke CloseHandle, input_file_handle
    invoke CloseHandle, output_file_handle

    invoke ExitProcess, 0
end start