# Toolchain file for cross-compiling to the STM32F411RE (ARM Cortex-M4).
# Passed to CMake via -DCMAKE_TOOLCHAIN_FILE, and must be set before project()
# so that CMake's compiler-detection step never touches the host compiler.

set(CMAKE_SYSTEM_NAME Generic)
# "Generic" tells CMake there is no OS underneath (bare metal), so it skips
# all the OS-specific assumptions (shared libs, dynamic loader, etc.) it
# would normally make for "Linux"/"Windows"/etc.

set(CMAKE_SYSTEM_PROCESSOR arm)
# Declares the target CPU architecture as ARM so CMake configures its
# platform modules for an ARM target instead of the host's architecture.

set(CMAKE_C_COMPILER   arm-none-eabi-gcc)
# Use the ARM bare-metal (eabi = Embedded Application Binary Interface) C
# cross-compiler instead of the host's native gcc.

set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
# Same reasoning as above, but for C++ sources.

set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
# The startup file is assembly; gcc is used as the assembler driver so it
# shares the same target flags (-mcpu, -mfpu, ...) as the C/C++ compiler.

set(CMAKE_OBJCOPY arm-none-eabi-objcopy)
# Needed post-build to convert the linked .elf into flashable .hex/.bin
# images; the host's objcopy would not understand the ARM ELF machine type.

set(CMAKE_SIZE arm-none-eabi-size)
# Reports Flash/RAM section sizes from the ARM .elf; the host's size tool
# cannot parse an ARM binary's section headers correctly.

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
# By default CMake's compiler check builds AND RUNS a tiny test executable
# on the host to confirm the compiler "works". A bare-metal ELF has no OS
# to run it under, so we tell CMake to only build a static library instead
# of an executable — this avoids a guaranteed failure at configure time.

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Programs (e.g. code generators) should still be searched for on the host
# system, not inside the ARM sysroot, since they run on the build machine.

set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Libraries must be found only within the target's root path so we never
# accidentally link against host (x86/ARM64 macOS) libraries.

set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
# Same reasoning as libraries: only pull headers meant for the ARM target,
# never host system headers, to avoid ABI/type mismatches.
