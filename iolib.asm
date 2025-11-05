global _start

section .data

; 10 (0xA em hexadecimal) corresponde ao caractere newline (\n) na tabela ascii
newline: db 10

message: db 'Digite um caractere: ', 0

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
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    ret

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

    add dl, 48

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

    mov rax, [rsp]

    add rsp, 1
    pop rbp

    ret

_start:
    mov rdi, 0xFFFFFFFFFFFFFFFF
    call print_uint
    call print_newline

    mov rdi, -273
    call print_int
    call print_newline

    mov rdi, message
    call print

    call read_char
    
    mov rdi, rax
    call print_char
    call print_newline

    xor rdi, rdi
    jmp exit

; obs: se atentar ao alinhamento da pilha ao realizar chamadas de sistema
; o código não stpa seguindo a convensão do System V ABI quando a isso
; pesquisar mias sobre 'stack alignment' e 'ABI SysV'
