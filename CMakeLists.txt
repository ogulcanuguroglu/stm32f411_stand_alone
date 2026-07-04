cmake_minimum_required(VERSION 3.20)

# ---------------------------------------------------------------------------
# Build flow (bare-metal, no OS):
#
#   source files (.cpp / .s)
#         |  arm-none-eabi-g++ / arm-none-eabi-gcc  (compile)
#         v
#   object files (.o)
#         |  arm-none-eabi-g++  (link, using the .ld linker script)
#         v
#   stm32f411_stand_alone.elf   <- full debug info, used by GDB/OpenOCD
#         |  arm-none-eabi-objcopy
#         v
#   .hex / .bin                <- flat images, used to flash the MCU
# ---------------------------------------------------------------------------

# Must be set before project() — this is what makes CMake invoke the ARM
# cross-compiler for its initial compiler checks instead of the host compiler.
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_SOURCE_DIR}/cmake/arm-none-eabi.cmake)

project(stm32f411_stand_alone C CXX ASM)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# CPU/FPU flags: these MUST exactly match the ".cpu" and ".fpu" directives in
# startup/startup_stm32f411retx.s. If they diverge, the compiler and the
# assembler disagree on which FPU registers/instructions exist, producing a
# binary with incompatible floating-point calling conventions (hard faults or
# corrupted floats at runtime).
set(CPU_FLAGS
    -mcpu=cortex-m4
    -mthumb
    -mfpu=fpv4-sp-d16
    -mfloat-abi=hard
)

set(COMPILE_FLAGS
    ${CPU_FLAGS}
    -ffunction-sections   # place each function in its own section so --gc-sections can drop unused ones
    -fdata-sections       # same as above, but for global/static data
    -fno-exceptions       # no unwind tables/landing pads — bare metal has no exception runtime to support them
    -fno-rtti             # drop RTTI (typeid/dynamic_cast) tables — pure Flash-size savings, unused here
    -Wall -Wextra         # surface likely bugs (uninitialized use, sign mismatches, etc.) at compile time
)

# LINKER_FLAGS:
#   -specs=nano.specs  -> link against newlib-nano, a stripped-down libc built
#                         for code size instead of features (no locale, no
#                         wide-char printf, etc.) — critical on a part with
#                         only 512 KB Flash / 128 KB RAM.
#   -specs=nosys.specs -> provide stub implementations of the syscalls libc
#                         expects (_write, _sbrk, _exit, ...) since there is
#                         no OS to service them. Without this, linking fails
#                         with "undefined reference to `_write'" etc.
#   Both specs are needed together: nano.specs selects the small libc, and
#   nosys.specs supplies the syscall stubs that libc calls into.
set(LINKER_FLAGS
    ${CPU_FLAGS}
    -T${CMAKE_SOURCE_DIR}/linker/STM32F411RETX_FLASH.ld
    -Wl,--gc-sections
    -Wl,-Map=${CMAKE_BINARY_DIR}/stm32f411_stand_alone.map
    -specs=nano.specs
    -specs=nosys.specs
    -Wl,--print-memory-usage
)

set(INCLUDE_DIRS
    drivers/cmsis/arm
    drivers/cmsis/st
    core
)

set(SOURCES
    startup/startup_stm32f411retx.s
    core/main.cpp
)

add_executable(stm32f411_stand_alone.elf ${SOURCES})

target_include_directories(stm32f411_stand_alone.elf PRIVATE ${INCLUDE_DIRS})

# STM32F411xE selects the exact device header (stm32f411xe.h, with its
# register/memory map) from within the family umbrella header stm32f4xx.h.
target_compile_definitions(stm32f411_stand_alone.elf PRIVATE STM32F411xE)

target_compile_options(stm32f411_stand_alone.elf PRIVATE ${COMPILE_FLAGS})
target_link_options(stm32f411_stand_alone.elf PRIVATE ${LINKER_FLAGS})

# Post-build: derive the flashable images from the linked .elf.
#   .elf -> full ELF with debug symbols/sections; used by a debugger (GDB/
#           OpenOCD) to set breakpoints and resolve addresses to source lines.
#   .hex -> Intel HEX, an ASCII text format encoding address + data; many
#           flashing tools (ST-LINK utilities, some bootloaders) accept it.
#   .bin -> raw flat binary, just the bytes to write starting at the base
#           Flash address; used by simpler programmers/loaders that don't
#           parse a container format.
add_custom_command(TARGET stm32f411_stand_alone.elf POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:stm32f411_stand_alone.elf> ${CMAKE_BINARY_DIR}/stm32f411_stand_alone.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:stm32f411_stand_alone.elf> ${CMAKE_BINARY_DIR}/stm32f411_stand_alone.bin
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:stm32f411_stand_alone.elf>
    COMMENT "Generating .hex/.bin images and printing section sizes"
)
