cmake_minimum_required(VERSION 3.22)
project(stm32_bench_starters LANGUAGES C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

function(add_stm32_starter target board cpu startup linker)
    add_executable(${target}
        firmware/starter/main.c
        firmware/starter/runtime.c
        ${startup}
    )
    target_compile_definitions(${target} PRIVATE ${board})
    target_compile_options(${target} PRIVATE
        -mcpu=${cpu} -mthumb -mfloat-abi=soft
        -ffunction-sections -fdata-sections
        $<$<COMPILE_LANGUAGE:C>:-Wall;-Wextra;-Wpedantic;-ffreestanding>
    )
    target_link_options(${target} PRIVATE
        -mcpu=${cpu} -mthumb -mfloat-abi=soft -nostdlib
        "-L${CMAKE_CURRENT_SOURCE_DIR}"
        "-T${CMAKE_CURRENT_SOURCE_DIR}/${linker}"
        "-Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${target}.map"
        -Wl,--gc-sections
    )
    set_target_properties(${target} PROPERTIES SUFFIX .elf
        LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${linker};${CMAKE_CURRENT_SOURCE_DIR}/firmware/linker/sections.ld")
    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${target}> "${CMAKE_CURRENT_BINARY_DIR}/${target}.bin"
        COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${target}>
        VERBATIM
    )
endfunction()

add_stm32_starter(firmware_g474 BOARD_G474 cortex-m4
    firmware/vendor/cmsis-device-g4/startup_stm32g474xx.s firmware/linker/stm32g474re.ld)
add_stm32_starter(firmware_f103 BOARD_F103 cortex-m3
    firmware/vendor/cmsis-device-f1/startup_stm32f103xb.s firmware/linker/stm32f103rb.ld)
