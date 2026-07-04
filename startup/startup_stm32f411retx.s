/**
 ******************************************************************************
 * @file      startup_stm32f411retx.s
 * @brief     STM32F411RETx startup file for GCC toolchain.
 *            Sets up the initial stack pointer, the reset vector, the full
 *            exception/interrupt vector table, and branches to main().
 ******************************************************************************
 */

/* ----------------------------------------------------------------------- */
/* Assembler directives                                                    */
/* ----------------------------------------------------------------------- */
/* cortex-m4 + fpv4-sp-d16: the F411 has a single-precision hardware FPU,
 * so we target it directly instead of the software floating point ABI. */
.syntax unified
.cpu cortex-m4
.fpu fpv4-sp-d16
.thumb

.global g_pfnVectors
.global Default_Handler

/* Symbols provided by the linker script, used below to relocate .data
 * and to zero .bss. */
.word _sidata
.word _sdata
.word _edata
.word _sbss
.word _ebss

/* ----------------------------------------------------------------------- */
/* Reset_Handler                                                            */
/* ----------------------------------------------------------------------- */
/**
 * @brief  Entry point after a core reset. Brings up the C runtime
 *         environment before handing control to main().
 */
  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
Reset_Handler:
  /* The stack pointer is not set by hardware on this core the way the
   * vector table's first word implies for some other reset paths, so we
   * set it explicitly to guarantee a valid stack before touching memory. */
  ldr   r0, =_estack
  mov   sp, r0

  /* SystemInit configures the clock tree (PLL, bus prescalers) before any
   * C code that might assume a particular core frequency runs. */
  bl  SystemInit

  /* Copy the .data section from Flash to RAM. Global/static variables with
   * non-zero initializers live in Flash at link time (_sidata) but must be
   * read/write at runtime, which only RAM provides — so we copy their
   * initial values into the RAM addresses (_sdata.._edata) the rest of the
   * program will reference. */
  ldr r0, =_sdata
  ldr r1, =_edata
  ldr r2, =_sidata
  movs r3, #0
  b LoopCopyDataInit

CopyDataInit:
  ldr r4, [r2, r3]
  str r4, [r0, r3]
  adds r3, r3, #4

LoopCopyDataInit:
  adds r4, r0, r3
  cmp r4, r1
  bcc CopyDataInit

  /* Zero-fill the .bss section. The C standard guarantees uninitialized
   * globals/statics start at zero, but RAM powers up with arbitrary
   * content, so we must clear that region ourselves before main() runs. */
  ldr r2, =_sbss
  ldr r4, =_ebss
  movs r3, #0
  b LoopFillZerobss

FillZerobss:
  str  r3, [r2]
  adds r2, r2, #4

LoopFillZerobss:
  cmp r2, r4
  bcc FillZerobss

  /* __libc_init_array runs the .init_array table, which is how C++ global/
   * static objects get their constructors called and how libc registers
   * its own init hooks. Skipping this means any C++ object with a
   * constructor is silently left uninitialized. */
  bl __libc_init_array

  /* Hand off to the application. */
  bl main

  /* main() should never return on bare metal (there is no OS to return
   * to); if it does anyway, trap here rather than run off into whatever
   * garbage follows in memory. */
LoopForever:
  b LoopForever

  .size Reset_Handler, .-Reset_Handler

/* ----------------------------------------------------------------------- */
/* Default_Handler                                                          */
/* ----------------------------------------------------------------------- */
/**
 * @brief  Fallback for any exception/interrupt without an application-
 *         supplied handler. An unhandled interrupt firing usually means a
 *         peripheral is misconfigured or a bug enabled an interrupt the
 *         application never intended to service; looping here instead of
 *         falling through keeps the core state intact for inspection
 *         under a debugger rather than executing undefined behavior.
 */
  .section .text.Default_Handler,"ax",%progbits
Default_Handler:
Infinite_Loop:
  b Infinite_Loop
  .size Default_Handler, .-Default_Handler

/* ----------------------------------------------------------------------- */
/* Vector table                                                             */
/* ----------------------------------------------------------------------- */
/**
 * @brief  The STM32F411RETx vector table. Must be placed at address
 *         0x0000.0000 (or wherever VTOR points) so the core finds the
 *         initial SP and Reset_Handler on power-up, and so each exception/
 *         IRQ number indexes the correct handler address.
 */
  .section .isr_vector,"a",%progbits
  .type g_pfnVectors, %object

g_pfnVectors:
  .word _estack
  .word Reset_Handler
  .word NMI_Handler
  .word HardFault_Handler
  .word MemManage_Handler
  .word BusFault_Handler
  .word UsageFault_Handler
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word SVC_Handler
  .word DebugMon_Handler
  .word 0                                    /* Reserved */
  .word PendSV_Handler
  .word SysTick_Handler
  /* External (STM32F411-specific) interrupts */
  .word WWDG_IRQHandler                      /* Window Watchdog interrupt */
  .word PVD_IRQHandler                       /* EXTI Line 16 interrupt / PVD through EXTI */
  .word TAMP_STAMP_IRQHandler                /* Tamper and TimeStamp interrupts through EXTI */
  .word RTC_WKUP_IRQHandler                  /* RTC Wakeup interrupt through the EXTI line */
  .word FLASH_IRQHandler                     /* FLASH global interrupt */
  .word RCC_IRQHandler                       /* RCC global interrupt */
  .word EXTI0_IRQHandler                     /* EXTI Line0 interrupt */
  .word EXTI1_IRQHandler                     /* EXTI Line1 interrupt */
  .word EXTI2_IRQHandler                     /* EXTI Line2 interrupt */
  .word EXTI3_IRQHandler                     /* EXTI Line3 interrupt */
  .word EXTI4_IRQHandler                     /* EXTI Line4 interrupt */
  .word DMA1_Stream0_IRQHandler               /* DMA1 Stream0 global interrupt */
  .word DMA1_Stream1_IRQHandler               /* DMA1 Stream1 global interrupt */
  .word DMA1_Stream2_IRQHandler               /* DMA1 Stream2 global interrupt */
  .word DMA1_Stream3_IRQHandler               /* DMA1 Stream3 global interrupt */
  .word DMA1_Stream4_IRQHandler               /* DMA1 Stream4 global interrupt */
  .word DMA1_Stream5_IRQHandler               /* DMA1 Stream5 global interrupt */
  .word DMA1_Stream6_IRQHandler               /* DMA1 Stream6 global interrupt */
  .word ADC_IRQHandler                       /* ADC1 global interrupt */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word EXTI9_5_IRQHandler                   /* EXTI Line[9:5] interrupts */
  .word TIM1_BRK_TIM9_IRQHandler              /* TIM1 Break interrupt and TIM9 global interrupt */
  .word TIM1_UP_TIM10_IRQHandler              /* TIM1 Update interrupt and TIM10 global interrupt */
  .word TIM1_TRG_COM_TIM11_IRQHandler         /* TIM1 Trigger/Commutation interrupts and TIM11 global interrupt */
  .word TIM1_CC_IRQHandler                   /* TIM1 Capture Compare interrupt */
  .word TIM2_IRQHandler                      /* TIM2 global interrupt */
  .word TIM3_IRQHandler                      /* TIM3 global interrupt */
  .word TIM4_IRQHandler                      /* TIM4 global interrupt */
  .word I2C1_EV_IRQHandler                   /* I2C1 event interrupt */
  .word I2C1_ER_IRQHandler                   /* I2C1 error interrupt */
  .word I2C2_EV_IRQHandler                   /* I2C2 event interrupt */
  .word I2C2_ER_IRQHandler                   /* I2C2 error interrupt */
  .word SPI1_IRQHandler                      /* SPI1 global interrupt */
  .word SPI2_IRQHandler                      /* SPI2 global interrupt */
  .word USART1_IRQHandler                    /* USART1 global interrupt */
  .word USART2_IRQHandler                    /* USART2 global interrupt */
  .word 0                                    /* Reserved */
  .word EXTI15_10_IRQHandler                  /* EXTI Line[15:10] interrupts */
  .word RTC_Alarm_IRQHandler                  /* RTC Alarms (A and B) through EXTI line interrupt */
  .word OTG_FS_WKUP_IRQHandler                /* USB On-The-Go FS Wakeup through EXTI line interrupt */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word DMA1_Stream7_IRQHandler                /* DMA1 Stream7 global interrupt */
  .word 0                                    /* Reserved */
  .word SDIO_IRQHandler                       /* SDIO global interrupt */
  .word TIM5_IRQHandler                      /* TIM5 global interrupt */
  .word SPI3_IRQHandler                      /* SPI3 global interrupt */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word DMA2_Stream0_IRQHandler                /* DMA2 Stream0 global interrupt */
  .word DMA2_Stream1_IRQHandler                /* DMA2 Stream1 global interrupt */
  .word DMA2_Stream2_IRQHandler                /* DMA2 Stream2 global interrupt */
  .word DMA2_Stream3_IRQHandler                /* DMA2 Stream3 global interrupt */
  .word DMA2_Stream4_IRQHandler                /* DMA2 Stream4 global interrupt */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word OTG_FS_IRQHandler                     /* USB On The Go FS global interrupt */
  .word DMA2_Stream5_IRQHandler                /* DMA2 Stream5 global interrupt */
  .word DMA2_Stream6_IRQHandler                /* DMA2 Stream6 global interrupt */
  .word DMA2_Stream7_IRQHandler                /* DMA2 Stream7 global interrupt */
  .word USART6_IRQHandler                     /* USART6 global interrupt */
  .word I2C3_EV_IRQHandler                    /* I2C3 event interrupt */
  .word I2C3_ER_IRQHandler                    /* I2C3 error interrupt */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word FPU_IRQHandler                        /* FPU global interrupt */
  .word 0                                    /* Reserved */
  .word 0                                    /* Reserved */
  .word SPI4_IRQHandler                       /* SPI4 global interrupt */
  .word SPI5_IRQHandler                       /* SPI5 global interrupt */
  .size g_pfnVectors, .-g_pfnVectors

/* ----------------------------------------------------------------------- */
/* Weak aliases for exception/interrupt handlers                           */
/* ----------------------------------------------------------------------- */
/**
 * @brief  Every entry in the vector table above (other than Reset_Handler)
 *         is aliased to Default_Handler here. Declaring these weak lets an
 *         application source file define a handler with the same name and
 *         have the linker prefer that strong symbol over this alias,
 *         without us having to touch the vector table or this file.
 */
  .weak SystemInit

  .weak NMI_Handler
  .thumb_set NMI_Handler,Default_Handler

  .weak HardFault_Handler
  .thumb_set HardFault_Handler,Default_Handler

  .weak MemManage_Handler
  .thumb_set MemManage_Handler,Default_Handler

  .weak BusFault_Handler
  .thumb_set BusFault_Handler,Default_Handler

  .weak UsageFault_Handler
  .thumb_set UsageFault_Handler,Default_Handler

  .weak SVC_Handler
  .thumb_set SVC_Handler,Default_Handler

  .weak DebugMon_Handler
  .thumb_set DebugMon_Handler,Default_Handler

  .weak PendSV_Handler
  .thumb_set PendSV_Handler,Default_Handler

  .weak SysTick_Handler
  .thumb_set SysTick_Handler,Default_Handler

  .weak WWDG_IRQHandler
  .thumb_set WWDG_IRQHandler,Default_Handler

  .weak PVD_IRQHandler
  .thumb_set PVD_IRQHandler,Default_Handler

  .weak TAMP_STAMP_IRQHandler
  .thumb_set TAMP_STAMP_IRQHandler,Default_Handler

  .weak RTC_WKUP_IRQHandler
  .thumb_set RTC_WKUP_IRQHandler,Default_Handler

  .weak FLASH_IRQHandler
  .thumb_set FLASH_IRQHandler,Default_Handler

  .weak RCC_IRQHandler
  .thumb_set RCC_IRQHandler,Default_Handler

  .weak EXTI0_IRQHandler
  .thumb_set EXTI0_IRQHandler,Default_Handler

  .weak EXTI1_IRQHandler
  .thumb_set EXTI1_IRQHandler,Default_Handler

  .weak EXTI2_IRQHandler
  .thumb_set EXTI2_IRQHandler,Default_Handler

  .weak EXTI3_IRQHandler
  .thumb_set EXTI3_IRQHandler,Default_Handler

  .weak EXTI4_IRQHandler
  .thumb_set EXTI4_IRQHandler,Default_Handler

  .weak DMA1_Stream0_IRQHandler
  .thumb_set DMA1_Stream0_IRQHandler,Default_Handler

  .weak DMA1_Stream1_IRQHandler
  .thumb_set DMA1_Stream1_IRQHandler,Default_Handler

  .weak DMA1_Stream2_IRQHandler
  .thumb_set DMA1_Stream2_IRQHandler,Default_Handler

  .weak DMA1_Stream3_IRQHandler
  .thumb_set DMA1_Stream3_IRQHandler,Default_Handler

  .weak DMA1_Stream4_IRQHandler
  .thumb_set DMA1_Stream4_IRQHandler,Default_Handler

  .weak DMA1_Stream5_IRQHandler
  .thumb_set DMA1_Stream5_IRQHandler,Default_Handler

  .weak DMA1_Stream6_IRQHandler
  .thumb_set DMA1_Stream6_IRQHandler,Default_Handler

  .weak ADC_IRQHandler
  .thumb_set ADC_IRQHandler,Default_Handler

  .weak EXTI9_5_IRQHandler
  .thumb_set EXTI9_5_IRQHandler,Default_Handler

  .weak TIM1_BRK_TIM9_IRQHandler
  .thumb_set TIM1_BRK_TIM9_IRQHandler,Default_Handler

  .weak TIM1_UP_TIM10_IRQHandler
  .thumb_set TIM1_UP_TIM10_IRQHandler,Default_Handler

  .weak TIM1_TRG_COM_TIM11_IRQHandler
  .thumb_set TIM1_TRG_COM_TIM11_IRQHandler,Default_Handler

  .weak TIM1_CC_IRQHandler
  .thumb_set TIM1_CC_IRQHandler,Default_Handler

  .weak TIM2_IRQHandler
  .thumb_set TIM2_IRQHandler,Default_Handler

  .weak TIM3_IRQHandler
  .thumb_set TIM3_IRQHandler,Default_Handler

  .weak TIM4_IRQHandler
  .thumb_set TIM4_IRQHandler,Default_Handler

  .weak I2C1_EV_IRQHandler
  .thumb_set I2C1_EV_IRQHandler,Default_Handler

  .weak I2C1_ER_IRQHandler
  .thumb_set I2C1_ER_IRQHandler,Default_Handler

  .weak I2C2_EV_IRQHandler
  .thumb_set I2C2_EV_IRQHandler,Default_Handler

  .weak I2C2_ER_IRQHandler
  .thumb_set I2C2_ER_IRQHandler,Default_Handler

  .weak SPI1_IRQHandler
  .thumb_set SPI1_IRQHandler,Default_Handler

  .weak SPI2_IRQHandler
  .thumb_set SPI2_IRQHandler,Default_Handler

  .weak USART1_IRQHandler
  .thumb_set USART1_IRQHandler,Default_Handler

  .weak USART2_IRQHandler
  .thumb_set USART2_IRQHandler,Default_Handler

  .weak EXTI15_10_IRQHandler
  .thumb_set EXTI15_10_IRQHandler,Default_Handler

  .weak RTC_Alarm_IRQHandler
  .thumb_set RTC_Alarm_IRQHandler,Default_Handler

  .weak OTG_FS_WKUP_IRQHandler
  .thumb_set OTG_FS_WKUP_IRQHandler,Default_Handler

  .weak DMA1_Stream7_IRQHandler
  .thumb_set DMA1_Stream7_IRQHandler,Default_Handler

  .weak SDIO_IRQHandler
  .thumb_set SDIO_IRQHandler,Default_Handler

  .weak TIM5_IRQHandler
  .thumb_set TIM5_IRQHandler,Default_Handler

  .weak SPI3_IRQHandler
  .thumb_set SPI3_IRQHandler,Default_Handler

  .weak DMA2_Stream0_IRQHandler
  .thumb_set DMA2_Stream0_IRQHandler,Default_Handler

  .weak DMA2_Stream1_IRQHandler
  .thumb_set DMA2_Stream1_IRQHandler,Default_Handler

  .weak DMA2_Stream2_IRQHandler
  .thumb_set DMA2_Stream2_IRQHandler,Default_Handler

  .weak DMA2_Stream3_IRQHandler
  .thumb_set DMA2_Stream3_IRQHandler,Default_Handler

  .weak DMA2_Stream4_IRQHandler
  .thumb_set DMA2_Stream4_IRQHandler,Default_Handler

  .weak OTG_FS_IRQHandler
  .thumb_set OTG_FS_IRQHandler,Default_Handler

  .weak DMA2_Stream5_IRQHandler
  .thumb_set DMA2_Stream5_IRQHandler,Default_Handler

  .weak DMA2_Stream6_IRQHandler
  .thumb_set DMA2_Stream6_IRQHandler,Default_Handler

  .weak DMA2_Stream7_IRQHandler
  .thumb_set DMA2_Stream7_IRQHandler,Default_Handler

  .weak USART6_IRQHandler
  .thumb_set USART6_IRQHandler,Default_Handler

  .weak I2C3_EV_IRQHandler
  .thumb_set I2C3_EV_IRQHandler,Default_Handler

  .weak I2C3_ER_IRQHandler
  .thumb_set I2C3_ER_IRQHandler,Default_Handler

  .weak FPU_IRQHandler
  .thumb_set FPU_IRQHandler,Default_Handler

  .weak SPI4_IRQHandler
  .thumb_set SPI4_IRQHandler,Default_Handler

  .weak SPI5_IRQHandler
  .thumb_set SPI5_IRQHandler,Default_Handler
