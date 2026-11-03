# Vendor startup files

- `cmsis-device-g4/startup_stm32g474xx.s`: [STMicroelectronics/cmsis-device-g4](https://github.com/STMicroelectronics/cmsis-device-g4), commit `626ee412334a5ed2e5b320af5a8d77d69f03a558`.
- `cmsis-device-f1/startup_stm32f103xb.s`: [STMicroelectronics/cmsis-device-f1](https://github.com/STMicroelectronics/cmsis-device-f1), commit `c8e9a4a4f16b6d2cb2a2083cbe5161025280fb22`.

Each directory includes the upstream Apache-2.0 license. These startup files are unmodified. `firmware/starter/runtime.c` supplies the initialization functions they call.
