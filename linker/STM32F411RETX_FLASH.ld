/*
 * File   : STM32F411RETX_FLASH.ld
 * Target : STM32F411RETx
 * Flash  : 512KB at 0x08000000
 * RAM    : 128KB at 0x20000000
 */

/* Reset_Handler is the first instruction the core runs out of reset (it
 * lives at word 1 of the vector table); the linker needs an explicit
 * ENTRY so tools that inspect the ELF (debuggers, `readelf`, etc.) know
 * where execution actually begins, even though the hardware itself
 * only ever reads the vector table, not this ELF header field. */
ENTRY(Reset_Handler)

/* The Cortex-M stack grows downward (each push decrements SP), so the
 * initial SP must point one past the highest valid RAM address, i.e.
 * the top of RAM, not the bottom — starting at the bottom would fault
 * on the very first push. */
_estack = ORIGIN(RAM) + LENGTH(RAM);

/* _Min_Heap_Size / _Min_Stack_Size do not reserve or allocate memory
 * themselves; they only pad ._user_heap_stack so the linker fails the
 * build if .data + .bss + this padding would overflow RAM. If the
 * project links FreeRTOS, the RTOS heap is carved out of its own static
 * array sized by configTOTAL_HEAP_SIZE (heap_4.c and friends) and never
 * touches the C library heap at all — so _Min_Heap_Size here is just an
 * overflow guard for whatever the C library / bare-metal code allocates
 * with malloc/new, not a sizing knob for the RTOS heap. */
_Min_Heap_Size = 0x200;
_Min_Stack_Size = 0x400;

/* Memories definition
 * Fixed by the STM32F411RE datasheet: 512K Flash at 0x08000000,
 * 128K SRAM at 0x20000000. Every SECTIONS placement below (`>FLASH`,
 * `>RAM`) resolves against these two regions, so getting the origin/
 * length wrong here would silently relocate code into nonexistent
 * memory. */
MEMORY
{
  RAM    (xrw)    : ORIGIN = 0x20000000,   LENGTH = 128K
  FLASH    (rx)    : ORIGIN = 0x8000000,   LENGTH = 512K
}

/* Sections */
SECTIONS
{
  /* The vector table must land at the exact base of FLASH (address
   * 0x08000000) because that is where the core reads the initial SP
   * and Reset_Handler address on power-up/reset. KEEP is required
   * because nothing in the C/C++ source ever references g_pfnVectors
   * by name — without KEEP, an aggressive linker `--gc-sections` pass
   * would see no live references to this section and discard it. */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector)) /* Startup code */
    . = ALIGN(4);
  } >FLASH

  /* The program code and other data into "FLASH" Rom type memory */
  .text :
  {
    . = ALIGN(4);
    *(.text)           /* .text sections (code) */
    *(.text*)          /* .text* sections (code) */
    *(.glue_7)         /* glue arm to thumb code */
    *(.glue_7t)        /* glue thumb to arm code */
    *(.eh_frame)

    KEEP (*(.init))
    KEEP (*(.fini))

    . = ALIGN(4);
    _etext = .;        /* define a global symbols at end of code */
  } >FLASH

  /* Constant data into "FLASH" Rom type memory */
  .rodata :
  {
    . = ALIGN(4);
    *(.rodata)         /* .rodata sections (constants, strings, etc.) */
    *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
    . = ALIGN(4);
  } >FLASH

  /* C++ exception unwind tables. Even if the application never throws,
   * the compiler still emits these for functions with cleanup
   * requirements (destructors of stack objects in scope during a call),
   * so they stay in FLASH rather than RAM since they're read-only and
   * only consulted during unwinding, never written. */
  .ARM.extab (READONLY) : /* The "READONLY" keyword is only supported in GCC11 and later, remove it if using GCC10 or earlier. */
  {
    . = ALIGN(4);
    *(.ARM.extab* .gnu.linkonce.armextab.*)
    . = ALIGN(4);
  } >FLASH

  /* Index into .ARM.extab used by the unwinder to find the right
   * unwind entry for a given PC; __exidx_start/__exidx_end bound the
   * table so libgcc's unwind code knows where it ends. */
  .ARM (READONLY) : /* The "READONLY" keyword is only supported in GCC11 and later, remove it if using GCC10 or earlier. */
  {
    . = ALIGN(4);
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
    . = ALIGN(4);
  } >FLASH

  /* Constructors that must run before any other C++ static constructor
   * (rarely used directly by application code, but some toolchain/libc
   * internals rely on it). Kept separate from .init_array and always
   * run first by __libc_init_array. */
  .preinit_array (READONLY) : /* The "READONLY" keyword is only supported in GCC11 and later, remove it if using GCC10 or earlier. */
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
    . = ALIGN(4);
  } >FLASH

  /* Table of function pointers to every C++ global/static object's
   * constructor. This is what makes C++ static initialization work on
   * bare metal: __libc_init_array (called from Reset_Handler) walks
   * __init_array_start..__init_array_end and calls each entry before
   * main() runs. Without this section (and without __libc_init_array
   * calling it), global C++ objects would reach main() with their
   * constructors never having executed. KEEP prevents the linker from
   * discarding entries it can't see being referenced directly. */
  .init_array (READONLY) : /* The "READONLY" keyword is only supported in GCC11 and later, remove it if using GCC10 or earlier. */
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
    . = ALIGN(4);
  } >FLASH

  /* Mirror of .init_array for destructors, run at exit() (which a bare-
   * metal app typically never calls, but the section still needs to
   * exist so libc/libstdc++ registration code has somewhere to place
   * these entries and so __libc_init_array's counterpart bookkeeping
   * doesn't break). */
  .fini_array (READONLY) : /* The "READONLY" keyword is only supported in GCC11 and later, remove it if using GCC10 or earlier. */
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array*))
    PROVIDE_HIDDEN (__fini_array_end = .);
    . = ALIGN(4);
  } >FLASH

  /* _sidata marks where .data's initial values live in FLASH (its Load
   * Memory Address, set by the `AT>FLASH` below). Reset_Handler needs
   * this address to know where to copy from, since .data's Virtual
   * Memory Address (in RAM) is a different address than where its
   * initializers are actually stored at rest. */
  _sidata = LOADADDR(.data);

  /* Initialized data sections into "RAM" Ram type memory */
  .data :
  {
    . = ALIGN(4);
    _sdata = .;        /* create a global symbol at data start */
    *(.data)           /* .data sections */
    *(.data*)          /* .data* sections */
    *(.RamFunc)        /* .RamFunc sections */
    *(.RamFunc*)       /* .RamFunc* sections */

    . = ALIGN(4);
    _edata = .;        /* define a global symbol at data end */

  /* `>RAM AT> FLASH` splits VMA from LMA: the section must be readable
   * and writable at its RAM address (VMA) at runtime since these are
   * mutable globals, but Flash is the only non-volatile storage that
   * survives a power cycle, so the initial values have to be stored
   * there (LMA) and copied into RAM by Reset_Handler on every boot.
   * Linking straight `>RAM` with no LMA would place the initializers
   * in RAM too, which is uninitialized garbage at power-up — the
   * values would never make it into FLASH to survive a reset. */
  } >RAM AT> FLASH

  /* Uninitialized data section into "RAM" Ram type memory */
  . = ALIGN(4);
  .bss :
  {
    /* This is used by the startup in order to initialize the .bss section */
    _sbss = .;         /* define a global symbol at bss start */
    __bss_start__ = _sbss;
    *(.bss)
    *(.bss*)
    *(COMMON)

    . = ALIGN(4);
    _ebss = .;         /* define a global symbol at bss end */
    __bss_end__ = _ebss;
  } >RAM

  /* This section has no content of its own — it exists purely to
   * advance the location counter past the space reserved for the heap
   * and stack, so that if .data + .bss + this reservation don't fit in
   * RAM, the linker errors out at build time ("region RAM overflowed")
   * instead of the firmware silently corrupting its own stack/heap at
   * runtime. `end`/`_end` mark where a real heap allocator (if any)
   * should start handing out memory. */
  ._user_heap_stack :
  {
    . = ALIGN(8);
    PROVIDE ( end = . );
    PROVIDE ( _end = . );
    . = . + _Min_Heap_Size;
    . = . + _Min_Stack_Size;
    . = ALIGN(8);
  } >RAM

  /* Without this, the linker would pull in the entirety of any object
   * file from these archives that satisfies a reference (e.g. one
   * function), potentially dragging in code that assumes a hosted OS
   * (memory-mapped files, syscalls) which either doesn't link on bare
   * metal or bloats FLASH with unreachable code. Removing this block
   * risks link-time bloat or pulling in libc/libm/libgcc internals
   * that don't belong in a freestanding embedded image. */
  /DISCARD/ :
  {
    libc.a ( * )
    libm.a ( * )
    libgcc.a ( * )
  }

  .ARM.attributes 0 : { *(.ARM.attributes) }
}
