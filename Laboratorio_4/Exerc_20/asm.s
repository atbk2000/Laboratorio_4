       PUBLIC  __iar_program_start
        PUBLIC  GPIOJ_Handler
        EXTERN  __vector_table

        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB

; System Control definitions
SYSCTL_RCGCGPIO_R       EQU     0x400FE608
SYSCTL_PRGPIO_R		EQU     0x400FEA08
PORTF_BIT               EQU     0000000000100000b ; bit  5 = Port F
PORTJ_BIT               EQU     0000000100000000b ; bit  8 = Port J
PORTN_BIT               EQU     0001000000000000b ; bit 12 = Port N

; NVIC definitions
NVIC_BASE               EQU     0xE000E000
NVIC_EN1                EQU     0x0104 ; escrita de 1 habilita fonte de interrupção
VIC_DIS1                EQU     0x0184 ; escrita de 1 desabilita fonte de interrupção
NVIC_PEND1              EQU     0x0204 ; escrita de 1 define IRQ pendente
NVIC_UNPEND1            EQU     0x0284 ; escrita de 1 limpa IRQ pendente
NVIC_ACTIVE1            EQU     0x0304 ; indica se há IRQ ativa
NVIC_PRI12              EQU     0x0430 ; contém as prioridades da fonte de interrupção

; GPIO Port definitions
GPIO_PORTF_BASE    	EQU     0x4005D000
GPIO_PORTJ_BASE    	EQU     0x40060000
GPIO_PORTN_BASE    	EQU     0x40064000
GPIO_DIR                EQU     0x0400 ; indica terminal de entrada ou saída
GPIO_IS                 EQU     0x0404 ; indica se interrupção será sensível a nível lógico ou a transição
GPIO_IBE                EQU     0x0408 ; indica se interrupção será gerada em ambas as transições (subida e descida)
GPIO_IEV                EQU     0x040C ; indica se interrupção será gerada em transição de subida ou descida
GPIO_IM                 EQU     0x0410 ; indica se interrupção está habilitada
GPIO_RIS                EQU     0x0414 ; indica que condições para interrupção ocorreram
GPIO_MIS                EQU     0x0418 ; indica que condições para interrupção ocorreram e dispara interrupção no NVIC
GPIO_ICR                EQU     0x041C ; escrita de 1 limpa bits correspondentes em GPIOMIS e GPIORIS
GPIO_PUR                EQU     0x0510 ; ativação do modo pull-up
GPIO_DEN                EQU     0x051C ; habilitação de função digital


; ROTINAS DE SERVIÇO DE INTERRUPÇÃO

; GPIOJ_Handler: Interrupt Service Routine for port GPIO J
; Utiliza R11 para se comunicar com o programa principal
GPIOJ_Handler:

        CMP R5, #0
        ITE EQ
         MOVEQ R2, #1 ; constante de atraso igual a 0
         MOVNE R2, #0 ; constante de atraso diferente de 0

        LDR R1, =GPIO_PORTJ_BASE
        LDR R0, [R1, #GPIO_RIS] ; leitura para identificar interrupção
        
        ANDS R0, R0, #1b ; mascaramento para identificar apenas bit 0
        ITT NE
         ADDNE R11, R11, R2 ; incrementar apenas se constante de atraso for 0
         STRNE R0, [R1, #GPIO_ICR] 

        LDR R0, [R1, #GPIO_RIS] ; leitura para identificar interrupção
        
        ANDS R0, R0, #10b ; mascaramento para identificar apenas bit 1
        ITT NE
         SUBNE R11, R11, R2 ; decrementar apenas se constante de atraso for 0
         STRNE R0, [R1, #GPIO_ICR]

        MOV R5, #0xF000 ; constante de atraso

        BX LR ; retorno da ISR


; PROGRAMA PRINCIPAL

__iar_program_start
        
main:   MOV R0, #(PORTN_BIT | PORTF_BIT)
	BL GPIO_enable ; habilita clock dos ports N, F e J

        MOV R0, #(PORTJ_BIT)
	BL GPIO_enable ; habilita clock dos ports N, F e J
        
	LDR R0, =GPIO_PORTN_BASE
        MOV R1, #00000011b ; bits 0 e 1 como saída
        BL GPIO_digital_output

	LDR R0, =GPIO_PORTF_BASE
        MOV R1, #00010001b ; bits 0 e 4 como saída
        BL GPIO_digital_output

	LDR R0, =GPIO_PORTJ_BASE
        MOV R1, #00000011b ; bits 0 e 1 como entrada
        BL GPIO_digital_input
        
        BL Button_int_conf ; habilita interrupção do botão SW1

        MOV R11, #0
loop: 	MOV R0, R11
        BL LED_write
        BL SW_delay

        B loop


; SUB-ROTINAS

; GPIO_enable: habilita clock para os ports de GPIO selecionados em R0
; R0 = padrão de bits de habilitação dos ports
; Destrói: R1 e R2
GPIO_enable:
        LDR R2, =SYSCTL_RCGCGPIO_R
	LDR R1, [R2]
	ORR R1, R0 ; habilita ports selecionados
	STR R1, [R2]

        LDR R2, =SYSCTL_PRGPIO_R
wait	LDR R0, [R2]
	TEQ R0, R1 ; clock dos ports habilitados?
	BNE wait

        BX LR

; GPIO_digital_output: habilita saídas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como saídas digitais
; Destrói: R2
GPIO_digital_output:
	LDR R2, [R0, #GPIO_DIR]
	ORR R2, R1 ; configura bits de saída
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_write: escreve nas saídas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits a serem escritos
GPIO_write:
        STR R2, [R0, R1, LSL #2] ; escreve bits com máscara de acesso
        BX LR

; GPIO_digital_input: habilita entradas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como entradas digitais
; Destrói: R2
GPIO_digital_input:
	LDR R2, [R0, #GPIO_DIR]
	BIC R2, R1 ; configura bits de entrada
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

	LDR R2, [R0, #GPIO_PUR]
	ORR R2, R1 ; habilita resitor de pull-up
	STR R2, [R0, #GPIO_PUR]

        BX LR

; GPIO_read: lê as entradas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits lidos
GPIO_read:
        LDR R2, [R0, R1, LSL #2] ; lê bits com máscara de acesso
        BX LR

; SW_delay: atraso de tempo por software
; R5 = valor do atraso
; Destrói: R5
SW_delay:
        CBZ R5, out_delay
        SUB R5, R5, #1
        B SW_delay        
out_delay:
        BX LR

; LED_write: escreve um valor binário nos LEDs D1 a D4 do kit
; R0 = valor a ser escrito nos LEDs (bit 3 a bit 0)
; Destrói: R1, R2, R3 e R4
LED_write:
        AND R3, R0, #0010b
        LSR R3, R3, #1
        AND R4, R0, #0001b
        ORR R3, R3, R4, LSL #1 ; LEDs D1 e D2
        LDR R1, =GPIO_PORTN_BASE
        MOV R2, #000000011b ; máscara PN1|PN0
        STR R3, [R1, R2, LSL #2]

        AND R3, R0, #1000b
        LSR R3, R3, #3
        AND R4, R0, #0100b
        ORR R3, R3, R4, LSL #2 ; LEDs D3 e D4
        LDR R1, =GPIO_PORTF_BASE
        MOV R2, #00010001b ; máscara PF4|PF0
        STR R3, [R1, R2, LSL #2]
        
        BX LR

; Button_read: lê o estado dos botões SW1 e SW2 do kit
; R0 = valor lido dos botões (bit 1 e bit 0)
; Destrói: R1, R2, R3 e R4
Button_read:
        LDR R1, =GPIO_PORTJ_BASE
        MOV R2, #00000011b ; máscara PJ1|PJ0
        LDR R0, [R1, R2, LSL #2]
        
dbc:    MOV R3, #50 ; constante de debounce
again:  CBZ R3, last
        LDR R4, [R1, R2, LSL #2]
        CMP R0, R4
        MOV R0, R4
        ITE EQ
          SUBEQ R3, R3, #1
          BNE dbc
        B again
last:
        BX LR

; Button_int_conf: configura interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button_int_conf:
        MOV R2, #00000011b ; bits 1 e 0 do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        BIC R0, R0, R2 ; desabilita interrupções
        STR R0, [R1, #GPIO_IM]
        
        LDR R0, [R1, #GPIO_IS]
        ORR R0, R0, R2 ; interrupção por nível lógico
        STR R0, [R1, #GPIO_IS]
        
        LDR R0, [R1, #GPIO_IBE]
        BIC R0, R0, R2 ; uma transição apenas
        STR R0, [R1, #GPIO_IBE]
        
        LDR R0, [R1, #GPIO_IEV]
        BIC R0, R0, R2 ; transição de descida
        STR R0, [R1, #GPIO_IEV]
        
        LDR R0, [R1, #GPIO_ICR]
        ORR R0, R0, R2 ; limpeza de pendências
        STR R0, [R1, #GPIO_ICR]
        
        LDR R0, [R1, #GPIO_IM]
        ORR R0, R0, R2 ; habilita interrupções no port GPIO J
        STR R0, [R1, #GPIO_IM]

        MOV R2, #0xE0000000 ; prioridade mais baixa para a IRQ51
        LDR R1, =NVIC_BASE
        
        LDR R0, [R1, #NVIC_PRI12]
        ORR R0, R0, R2 ; define prioridade da IRQ51 no NVIC
        STR R0, [R1, #NVIC_PRI12]

        MOV R2, #10000000000000000000b ; bit 19 = IRQ51
        MOV R0, R2 ; limpa pendências da IRQ51 no NVIC
        STR R0, [R1, #NVIC_UNPEND1]

        LDR R0, [R1, #NVIC_EN1]
        ORR R0, R0, R2 ; habilita IRQ51 no NVIC
        STR R0, [R1, #NVIC_EN1]
        
        BX LR

; Button1_int_enable: habilita interrupções dos botões SW1 e SW2 do kit
; Destrói: R0, R1 e R2
Button1_int_enable:
        MOV R2, #00000011b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        ORR R0, R0, R2 ; habilita interrupções
        STR R0, [R1, #GPIO_IM]

        BX LR

; Button1_int_disable: desabilita interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button1_int_disable:
        MOV R2, #00000011b ; bits 1 e 0 do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        BIC R0, R0, R2 ; desabilita interrupções
        STR R0, [R1, #GPIO_IM]

        BX LR

; Button1_int_clear: limpa pendências de interrupções dos botões SW1 e SW2 do kit
; Destrói: R0 e R1
Button1_int_clear:
        MOV R0, #00000011b ; limpa os bit 0 e 1
        LDR R1, =GPIO_PORTJ_BASE
        STR R0, [R1, #GPIO_ICR]

        BX LR

        END

