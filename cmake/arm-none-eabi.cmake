set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# On Windows, setup_stm32_windows.ps1 installs a pinned portable toolchain here.
# On other systems, or when the portable tools are absent, use PATH.
set(_portable "${CMAKE_CURRENT_LIST_DIR}/../.tools/stm32/xpack-arm-none-eabi-gcc-15.2.1-1.1/bin")
find_program(ARM_GCC NAMES arm-none-eabi-gcc HINTS "${_portable}" REQUIRED)
find_program(ARM_OBJCOPY NAMES arm-none-eabi-objcopy HINTS "${_portable}" REQUIRED)
find_program(ARM_SIZE NAMES arm-none-eabi-size HINTS "${_portable}" REQUIRED)
set(CMAKE_C_COMPILER "${ARM_GCC}")
set(CMAKE_ASM_COMPILER "${ARM_GCC}")
set(CMAKE_OBJCOPY "${ARM_OBJCOPY}")
set(CMAKE_SIZE "${ARM_SIZE}")
