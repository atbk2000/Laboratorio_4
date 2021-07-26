# Laboratorio_4
Laboratório 4 para a disciplina de sistemas microcontrolados da UTFPR.

Alguns comentários referentes às perguntas do exercício 20:

1. As interrupções são geradas quando o botão é pressionado. A configuração 1 no bit correspondente ao SW1 no registrador GPIO_IS, 1 no registrador GPIO_IBE e 0 no registrador GPIO_IEV determinam essas características.

2. Os registradores R0-R3, R12, LR, PC e xPSR são salvos automaticamente pelo hardware. Quando a interrupção é terminada, o programa volta ao programa principal através do registrador PC salvo na pilha.

3. A contagem binária não é efetuada pois a modificação de R12 não é salva no programa principal, apenas dentro da interrupção.

4. Mudar valor de R2 de 00000001b para 00000011b para ativar interrupções no bit 1.

5. É possível lendo-se o valor do registrador GPIO_ICR.

6. Mudar a interrupção para ser sensível a nível lógico e implementar uma constante de atraso que é decrementada fora de GPIOJ_Handler, para que o contador só seja alterado se a constante de atraso for zero. A constante de atraso é reinicializada cada vez que a interrupção ocorre, garantindo que mudanças muito rápidas no nível lógico sejam desconsideradas.
