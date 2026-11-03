#include <stdint.h>

/* Minimal PA5/LD2 bring-up. No HAL, CAN, interrupts or motor control. */
#define REG32(address) (*(volatile uint32_t *)(uintptr_t)(address))

#if defined(BOARD_G474)
#define RCC_GPIO_ENABLE REG32(0x4002104CUL) /* RCC_AHB2ENR, GPIOAEN */
#define GPIO_MODE       REG32(0x48000000UL) /* GPIOA_MODER */
#define GPIO_BSRR       REG32(0x48000018UL)

static void led_init(void)
{
    RCC_GPIO_ENABLE |= 1UL;
    (void)RCC_GPIO_ENABLE;
    GPIO_MODE = (GPIO_MODE & ~(3UL << 10)) | (1UL << 10);
}
#elif defined(BOARD_F103)
#define RCC_GPIO_ENABLE REG32(0x40021018UL) /* RCC_APB2ENR, IOPAEN */
#define GPIO_CONFIG     REG32(0x40010800UL) /* GPIOA_CRL */
#define GPIO_BSRR       REG32(0x40010810UL)

static void led_init(void)
{
    RCC_GPIO_ENABLE |= (1UL << 2);
    (void)RCC_GPIO_ENABLE;
    GPIO_CONFIG = (GPIO_CONFIG & ~(15UL << 20)) | (2UL << 20); /* PA5: 2 MHz push-pull */
}
#else
#error Select a supported board.
#endif

static void delay_approximately(void)
{
    /* Deliberately clock-dependent: this is only a visible bring-up test. */
    for (volatile uint32_t i = 0; i < 500000UL; ++i) {
        __asm volatile ("nop");
    }
}

int main(void)
{
    led_init();
    for (;;) {
        GPIO_BSRR = (1UL << 5);
        delay_approximately();
        GPIO_BSRR = (1UL << 21);
        delay_approximately();
    }
}
