global _start

section .data

message: db 'Qual seu nome? ', 0
hello: db 'Hello, ', 0

section .bss

; resb = reserve byte
; reservando um buufer de 16 bytes
name: resb 16

section .text

; rdi recebe o código de saída
; executa a chamada de sistema exite
; encerra o processo atual 
exit:
    mov rax, 60
    syscall

; rdi contem o endereço do primeiro caractere da string
; itera sobre a string atá encontrar o caractere 0
; incremente rax a cada iteração
; ao final rax contem o tamanho da string
strlen:
    xor rax, rax

.loop:
    cmp byte [rdi+rax], 0
    je .end

    inc rax
    jmp .loop

.end:
    ret

; rdi contem o endereço do primeiro caractere da string
; utiliza strlen para descobrir o tamanho da string
; printa a string através da chamada de sistema write em stdout
print:
    push rdi

    call strlen
    mov rdx, rax

    pop rsi
    mov rax, 1
    mov rdi, 1
    syscall

    ret

; rdi recebe o código de um caractere diretamente
; syscall write espera um endereço de memória em rsi 
; por isso não podemos passar rdi direto para rsi
; o valor de rdi é emplinhado e o valor de rsp é movido para rsi
; rsp (stack pointer) contem o endereço do último elemento da pilha
print_char:
    push rdi

    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall

    pop rdi
    ret

; imprime o caractere newline
print_newline:
    ; 10 (0xA em hexadecimal) corresponde ao caractere newline (\n) na tabela ascii
    mov rdi, 10
    jmp print_char

; rdi recebe o unsigned integer (inteteiro sem sinal) de 8 bytes
; é feito uma alocação de 32 bytes na pilha (mais que o necessário por conta do alinhamento da pilha)
; o inteiro é dividido por 10 (decimal) até que seu quociente seja 0
; o resto da divisão é somado 48 (0x30) para pegar o código ascii corresponde do dígito
; ao final da iteração e imprimido o número armazenado no buffer
print_uint:
    push rbp

    mov rbp, rsp
    sub rsp, 32

    mov rax, rdi

    push rbx
    mov rbx, 10

    xor rcx, rcx

    mov rsi, rbp

.loop:
    ; rdx: parte alta do dividendo (zera)
    xor rdx, rdx 
    ; div funciona de maneira diferente de add ou sub
    ; seus argumentos são passados da forma:
    ;   rdx:rax: dividendo (rax = parte baixa; rdx = parte alta)
    ;   div src (src: divisor), nesse caso src é rbx

    ; após operação:
    ;   rax = quociente; rdx = resto

    ; ou seja: (rdx:rax) / rbx
    div rbx

    add dl, '0'

    dec rsi
    ; TODO: estudar partes dos registradores
    mov [rsi], dl

    inc rcx

    test rax, rax
    jnz .loop

    mov rax, 1
    mov rdi, 1
    mov rdx, rcx
    syscall

    ; voltando ao estado original da pilha e dos registradores callee-saved
    add rsp, 32
    pop rbx
    pop rbp

    ret

; rdi recebe o signed integer (inteteiro com sinal) de 8 bytes
; compara rdi com 0:
;   caso rdi for maior ou igual a 0 pula para .print e chama print_uint
;   caso for menor que 0 imprime '-', inverte o valor e segue para print_uint
print_int:
    cmp rdi, 0
    ; jge = jump if greater or equal
    jge .print
    
    push rdi

    mov rdi, '-'
    call print_char

    pop rdi

    ; o bit mais significativo indica o sinal:
    ;   0 -> positivo
    ;   1 -> negativo
    ; a instrução neg primeiro inverte todos os bits do operando 
    ; então, adiciona 1 ao resultado:
    ;   mov al, 5 -> al = 00000101b
    ;   neg al    -> al = 11111011b = -5
    neg rdi

.print:
    ; tail call optimization (otimização de chamada na cauda)
    ; como a chamda de print_uint é a ultima instrução da função
    ; não há necessidade de utilizar call, podemos simplemente pular para ela
    ; evita criar um novo frame de pilha ao chamar a função
    ; print_uint já possui a instrução ret, não sendo necessário repití-la aqui
    jmp print_uint

; faz a leitura de um caractere em stdin
; retorna o caractere em rax
read_char:
    push rbp

    mov rbp, rsp
    sub rsp, 1

    ; 0 system call read
    mov rax, 0
    ; rdi: descritor do arquivo do qual será feito a leitura
    ; 0 para stdin
    mov rdi, 0
    ; rsi: endereço do primeiro byte em uma sequência de bytes
    ; os bytes recebido serão colocado aí
    mov rsi, rsp
    ; rdx: quantidade de bytes a serem lidos
    mov rdx, 1
    syscall
    
    ; movzx = move and zero extend
    ; copia apenas 1 byte e preenche o resto de rax com zeros
    movzx rax, byte [rsp]

    add rsp, 1
    pop rbp

    ret

; rdi recebe o endereço do primeiro byte do buffer
; rsi recebe o tamanho do buffer
; faz a leitura de uma string em stdin
; devolve 0 se a string for muito grande para o buffer
; caso contrário devolve o endereço do buffer
read:
    mov rdx, rsi
    mov rsi, rdi

    mov rax, 0
    mov rdi, 0
    syscall
    
    ; ao realizar uma chamada de sistema read
    ; é devolvido em rax o número de bytes lidos
    cmp rax, rdx
    jb .save

    xor rax, rax
    ret

.save:
    ; adiciona o caractere nulo ao final da string
    mov byte [rsi + rax - 1], 0
    mov rax, rsi

    ret

; rdi recebe uma string terminada em nulo
; faz parse de uma string para um inteiro sem sinal
parse_uint:
    call strlen

    push rax

    mov rcx, rax
    xor rax, rax
    
    ; dacimal = base 10
    mov rdx, 10

; itera do primeiro byte até o ultimo na string
; soma o número em decimal e multiplicando por 10 quando necessário
; por exemplo:
;   '2025\0' rcx = 4 rdi; = endereço do char '2'
;   
;   primeira iteração:
;       rsi = '2' (código ascii é 0x32 ou 50)
;       subtraimos '0' (código ascii é 0x30 ou 48)
;       com isso conseguimos seu número em decimal
;
;   lógica:
;   2025 = (((((((0 *10) + 2) * 10) + 0) * 10) + 2) * 10) + 5
.next_number:
    test rcx, rcx
    jz .end

    movzx rsi, byte [rdi]
    sub rsi, '0'

    imul rax, rdx
    add rax, rsi

    inc rdi
    dec rcx
    jmp .next_number

.end:
    pop rdx
    ret

; rdi recebe um string
; faz o parse de uma string para um inteiro com sinal
parse_int:
    cmp byte [rdi], '-'
    jne parse_uint
    
    inc rdi
    call parse_uint

    neg rax
    ret

; rdi e rsi recebem dois ponteiros para strings
; compara as duas strings:
;   1 = iguais
;   0 = diferentes
string_equals:
    xor rax, rax

; percorre as strings verificando seus caracteres são iguais
; para se forem diferentes ou se for encontrado o caractere nulo
.compare:
    movzx rcx, byte [rsi]
    movzx rdx, byte [rdi]
    cmp rdx, rcx
    jne .end

    test rdx, rdx
    jz .equal

    inc rdi
    inc rsi
    jmp .compare

.equal:
    mov rax, 1

.end:
    ret

; rdi recebe o ponteiro para uma string
; rsi recebe o ponteiro para um buffer onde a string será compiada
; rdx recebe o tamanho do buffer
; caso a string caiba no buffer o endereço de destino será devolvido
; caso a string não caiba no buffer será devolvido zero
string_copy:
    call strlen

    inc rax
    cmp rdx, rax
    jl .less

    mov rax, rsi

.next_char:
    mov bl, [rdi]
    mov [rsi], bl

    cmp bl, 0 
    je .end

    inc rsi
    inc rdi
    jmp .next_char

.less:
    xor rax, rax

.end:
    ret

_start:
    ; mov rdi, 0xFFFFFFFFFFFFFFFF
    ; call print_uint
    ; call print_newline

    ; mov rdi, -273
    ; call print_int
    ; call print_newline

    mov rdi, message
    call print
    
    mov rdi, name
    mov rsi, 16
    call read

    test rax, rax
    jz .end

    push rax

    mov rdi, hello
    call print

    pop rax
    
    mov rdi, rax
    call print
    
    mov rdi, '!'
    call print_char
    call print_newline
.end:
    xor rdi, rdi
    jmp exit

; obs: se atentar ao alinhamento da pilha ao realizar chamadas de sistema
; o código não stpa seguindo a convensão do System V ABI quando a isso
; pesquisar mias sobre 'stack alignment' e 'ABI SysV'
