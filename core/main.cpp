extern "C" int main(void) {
    // SystemInit() is declared "weak" in startup_stm32f411retx.s, so the
    // linker is happy to leave it out entirely — the startup file's own
    // weak definition (a no-op) is used instead. This is intentional for
    // now: no clock tree configuration has been implemented yet. Once we
    // configure the PLL/clocks, we provide a strong SystemInit() here (or
    // in a dedicated source file) and it will override the weak default.
    while (1) {}
}
