#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vvgatestsrc.h"
#include <cstdio>
#include <cstdint>
#include <cassert>

#define WIDTH  640
#define HEIGHT 480

static uint64_t sim_time = 0;

static void tick(Vvgatestsrc *dut, VerilatedVcdC *trace) {
    dut->i_pixclk = 0; dut->eval();
    if (trace) trace->dump(10 * sim_time);
    dut->i_pixclk = 1; dut->eval();
    if (trace) trace->dump(10 * sim_time + 5);
    sim_time++;
}

// Simulate one complete 640x480 frame.
// pixels[HEIGHT*WIDTH]: if non-null, o_pixel values are stored row-major.
// Returns number of pixels that don't match exp_pixel (0xFFFFFFFF = no check).
static int run_frame(Vvgatestsrc *dut, VerilatedVcdC *trace,
                     uint32_t *pixels, uint32_t exp_pixel) {
    int mismatches = 0;
    int idx = 0;

    // Pulse newframe+newline together to reset all counters
    dut->i_newframe = 1;
    dut->i_newline  = 1;
    dut->i_rd       = 0;
    tick(dut, trace);
    dut->i_newframe = 0;
    dut->i_newline  = 0;

    for (int y = 0; y < HEIGHT; y++) {
        // Newline pulse advances vertical position
        dut->i_newline = 1;
        dut->i_rd      = 0;
        tick(dut, trace);
        dut->i_newline = 0;

        for (int x = 0; x < WIDTH; x++) {
            dut->i_rd = 1;
            tick(dut, trace);
            uint32_t p = dut->o_pixel;
            if (pixels) pixels[idx] = p;
            if (exp_pixel != 0xFFFFFFFF && p != exp_pixel)
                mismatches++;
            idx++;
        }
        dut->i_rd = 0;

        // Minimal horizontal blanking
        for (int b = 0; b < 4; b++) tick(dut, trace);
    }

    // Minimal vertical blanking
    for (int b = 0; b < 10; b++) tick(dut, trace);

    return mismatches;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vvgatestsrc *dut = new Vvgatestsrc;
    VerilatedVcdC *trace = new VerilatedVcdC;
    dut->trace(trace, 99);
    trace->open("vgatestsrc.vcd");

    dut->i_pixclk   = 0;
    dut->i_reset    = 1;
    dut->i_newframe = 0;
    dut->i_newline  = 0;
    dut->i_rd       = 0;
    dut->i_btn      = 0;
    dut->i_width    = WIDTH;
    dut->i_height   = HEIGHT;
    dut->eval();

    for (int i = 0; i < 8; i++) tick(dut, trace);
    dut->i_reset = 0;

    // --- Capture no-button frame as PPM ---
    static uint32_t frame[HEIGHT * WIDTH];
    run_frame(dut, trace, frame, 0xFFFFFFFF);  // priming frame
    run_frame(dut, trace, frame, 0xFFFFFFFF);  // capture frame
    {
        FILE *f = fopen("image.ppm", "w");
        fprintf(f, "P3\n%d %d\n255\n", WIDTH, HEIGHT);
        for (int i = 0; i < WIDTH * HEIGHT; i++)
            fprintf(f, "%d %d %d\n",
                (frame[i] >> 16) & 0xFF,
                (frame[i] >>  8) & 0xFF,
                 frame[i]        & 0xFF);
        fclose(f);
        printf("Wrote image.ppm (no-button test pattern)\n");
    }

    // --- Button solid-color tests ---
    // Pixel layout with BPC=8: [23:16]=R [15:8]=G [7:0]=B
    struct { uint32_t color; const char *name; } tests[6] = {
        {0xFF0000, "btn[0] FIRE1  -> red"},
        {0x00FF00, "btn[1] FIRE2  -> green"},
        {0x0000FF, "btn[2] UP     -> blue"},
        {0xFFFFFF, "btn[3] DOWN   -> white"},
        {0x00FFFF, "btn[4] LEFT   -> cyan"},
        {0xFF00FF, "btn[5] RIGHT  -> magenta"},
    };

    int total_failures = 0;
    for (int b = 0; b < 6; b++) {
        dut->i_btn = (uint8_t)(1 << b);
        run_frame(dut, trace, NULL, 0xFFFFFFFF);  // warmup with btn held
        int fails = run_frame(dut, trace, NULL, tests[b].color);
        dut->i_btn = 0;

        if (fails == 0)
            printf("PASS: %s\n", tests[b].name);
        else {
            printf("FAIL: %s  (%d pixels wrong)\n", tests[b].name, fails);
            total_failures++;
        }
    }

    trace->close();
    delete trace;
    delete dut;

    if (total_failures == 0)
        printf("\nAll tests passed.\n");
    else
        printf("\n%d test(s) FAILED.\n", total_failures);

    return total_failures ? 1 : 0;
}
