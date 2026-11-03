#include <stddef.h>

/* Keep the reset clock configuration. This example does not enable the FPU. */
void SystemInit(void)
{
}

typedef void (*init_function)(void);
extern init_function __preinit_array_start[];
extern init_function __preinit_array_end[];
extern init_function __init_array_start[];
extern init_function __init_array_end[];

/* The upstream startup files call this after copying .data and clearing .bss. */
void __libc_init_array(void)
{
    for (init_function *p = __preinit_array_start; p < __preinit_array_end; ++p) {
        (*p)();
    }
    for (init_function *p = __init_array_start; p < __init_array_end; ++p) {
        (*p)();
    }
}
