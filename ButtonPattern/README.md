# ButtonPattern — How It Works

A "hello world+" FPGA demo for the ULX3S board. Displays an HDMI color-bar test pattern, and fills the screen with a solid color while any of the six game buttons are held. The corresponding LED lights up to confirm the press.

---

## Button → Color Mapping

| Button | Label  | Screen color |
|--------|--------|-------------|
| `btn[1]` | FIRE1  | Red         |
| `btn[2]` | FIRE2  | Green       |
| `btn[3]` | UP     | Blue        |
| `btn[4]` | DOWN   | White       |
| `btn[5]` | LEFT   | Cyan        |
| `btn[6]` | RIGHT  | Magenta     |
| *(none)* | —      | Color-bar test pattern |

---

## Signal Flow

```
clk_25mhz (crystal)
    │
    ▼
clock.v  ──────────────────────────────────────────┐
  clk_25MHz  (pixel clock)                         │
  clk_250MHz (TMDS bit clock)                      │
    │                                              │
    ▼                                              ▼
vgatestsrc.v ──o_pixel──► ULX3S.v ◄── llhdmi.v
  (pixel color)              (top-level)    (VGA timing + serializer)
                                │                  │
                           btn[6:1]           TMDS_encoder.v
                           led[6:1]           OBUFDS.v
                                │                  │
                                └──────────────────►
                                              gpdi_dp/dn
                                              (HDMI out)
```

---

## 1. Clock Generation (`clock.v`)

The board provides a 25 MHz crystal. The ECP5's built-in PLL (`EHXPLLL`) multiplies this up to two clocks used by the rest of the design:

```verilog
EHXPLLL #(
    .CLKOS2_DIV(20),   // ÷20 → 25 MHz  (pixel clock)
    .CLKOS_DIV(2),     // ÷2  → 250 MHz (TMDS bit clock)
    ...
) pll_i (
    .CLKI(clkin_25MHz),
    .CLKOS(clk_250MHz),
    .CLKOS2(clk_25MHz),
    ...
);
```

- **25 MHz** — one clock per pixel at 640×480 @ ~60 Hz
- **250 MHz** — 10× the pixel clock, needed to serialize 10-bit TMDS words one bit at a time

---

## 2. Top-Level Glue (`ULX3S.v`)

The top-level module wires everything together. It also holds the design in reset for the first 8 clock cycles to give the PLL time to lock:

```verilog
reg [2:0] reset_cnt = 0;
wire reset = ~reset_cnt[2];
always @(posedge clk_25mhz)
  if (reset) reset_cnt <= reset_cnt + 1;
```

Buttons are passed down to the pixel generator, and mirrored to the LEDs so you can see which button is active:

```verilog
assign led = {1'b0, btn[6:1], 1'b0};

vgatestsrc #(.BITS_PER_COLOR(8))
  vgatestsrc_instance(
    ...
    .i_btn(btn[6:1]),
    .o_pixel(pixel));
```

`wifi_gpio0` is tied high to prevent the onboard ESP32 from rebooting the FPGA:

```verilog
assign wifi_gpio0 = 1'b1;
```

---

## 3. HDMI Timing (`llhdmi.v`)

HDMI at this resolution is electrically identical to VGA — just with TMDS encoding instead of analog voltages. `llhdmi` implements a **640×480 @ 60 Hz** timing state machine.

Two counters track the current position across the full frame (visible + blanking):

```verilog
always @(posedge i_pixclk)
  CounterX <= (CounterX==799) ? 0 : CounterX+1;   // 640 visible + 160 blanking

always @(posedge i_pixclk)
  if (CounterX==799)
    CounterY <= (CounterY==524) ? 0 : CounterY+1;  // 480 visible + 45 blanking
```

`DrawArea` is high only during the visible region. `o_rd` ("read") tells `vgatestsrc` to emit the next pixel:

```verilog
always @(posedge i_pixclk)
  DrawArea <= (CounterX<640) && (CounterY<480);

assign o_rd = ~i_reset & DrawArea;
```

Sync pulses are generated at fixed offsets inside the blanking region:

```verilog
always @(posedge i_pixclk)
  hSync <= (CounterX>=656) && (CounterX<752);

always @(posedge i_pixclk)
  vSync <= (CounterY>=490) && (CounterY<492);
```

---

## 4. TMDS Encoding (`TMDS_encoder.v`)

HDMI carries data as **TMDS** (Transition-Minimized Differential Signaling). Each 8-bit color value is encoded into a 10-bit word that minimizes transitions and maintains DC balance (equal 0s and 1s over time).

The encoder tracks a running disparity counter (`balance_acc`) and inverts the output word when needed to stay balanced:

```verilog
wire invert_q_m = (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;

wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};

always @(posedge clk) TMDS <= VDE ? TMDS_data : TMDS_code;
always @(posedge clk) balance_acc <= VDE ? balance_acc_new : 4'h0;
```

`llhdmi` instantiates one encoder per color channel, then serializes the 10-bit output one bit per 250 MHz clock:

```verilog
TMDS_encoder encode_R(.clk(i_pixclk), .VD(i_red), .CD(2'b00),    .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(i_pixclk), .VD(i_grn), .CD(2'b00),    .VDE(DrawArea), .TMDS(TMDS_grn));
TMDS_encoder encode_B(.clk(i_pixclk), .VD(i_blu), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blu));
```

Note that the blue channel carries the sync bits (`CD`) in its control period — this is part of the HDMI spec.

The 10-bit TMDS words are loaded into shift registers and clocked out one bit at a time at 250 MHz:

```verilog
always @(posedge i_tmdsclk) begin
  TMDS_shift_red <= TMDS_shift_load ? TMDS_red : {1'b0, TMDS_shift_red[9:1]};
  TMDS_shift_grn <= TMDS_shift_load ? TMDS_grn : {1'b0, TMDS_shift_grn[9:1]};
  TMDS_shift_blu <= TMDS_shift_load ? TMDS_blu : {1'b0, TMDS_shift_blu[9:1]};
end

assign o_red = TMDS_shift_red[0];
assign o_grn = TMDS_shift_grn[0];
assign o_blu = TMDS_shift_blu[0];
```

---

## 5. Pixel Source (`vgatestsrc.v`)

This is where the image is generated one pixel at a time, in sync with `o_rd` pulses from `llhdmi`.

### Position Tracking

Two counters shadow `llhdmi`'s position and are divided into coarser "bar" indices that select which color block to draw:

```verilog
// hbar: which horizontal color bar we're in
always @(posedge i_pixclk)
if ((i_reset)||(i_newline)) begin
  hpos <= 0;
  hbar <= 0;
  hedge <= { 4'h0, i_width[(HW-1):4] };   // bar width = screen width / 16
end else if (i_rd) begin
  hpos <= hpos + 1'b1;
  if (hpos >= hedge) begin
    hbar  <= hbar + 1'b1;
    hedge <= hedge + { 4'h0, i_width[(HW-1):4] };
  end
end

// yline: which horizontal stripe we're in
always @(posedge i_pixclk)
if ((i_reset)||(i_newframe)) begin
  ypos  <= 0;
  yline <= 0;
  yedge <= { 4'h0, i_height[(VW-1):4] };  // stripe height = screen height / 16
end else if (i_newline) begin
  ypos <= ypos + { {(VW-1){1'h0}}, dline };
  if (ypos >= yedge) begin
    yline <= yline + 1'b1;
    yedge <= yedge + { 4'h0, i_height[(VW-1):4] };
  end
end
```

### Test Pattern

The pattern is a classic SMPTE-style color-bar chart. `yline` selects between three horizontal regions, and `hbar` selects the color within each region:

```verilog
// Top bars: white, yellow, cyan, green, magenta, red, blue
always @(posedge i_pixclk)
case(hbar[3:0])
4'h1: topbar <= mid_white;
4'h3: topbar <= mid_yellow;
4'h5: topbar <= mid_cyan;
4'h7: topbar <= mid_green;
4'h9: topbar <= mid_magenta;
4'hb: topbar <= mid_red;
4'hd: topbar <= mid_blue;
...
endcase

// Assign each yline stripe to a pattern layer
always @(posedge i_pixclk)
case(yline)
4'h0:        pattern <= black;
4'h1: ...
4'h8:        pattern <= topbar;    // rows 1-8: color bars
4'h9:        pattern <= midbar;    // row 9: complementary bars
4'ha: ...
4'hc:        pattern <= fatbar;    // rows 10-12: PLUGE bars
4'he:        pattern <= gradient;  // row 14: RGB + gray gradients
4'hf:        pattern <= black;
endcase
```

### Button Color Override

When a button is held, the normal `pattern` output is bypassed and a full-brightness solid color is emitted for every pixel instead:

```verilog
always @(posedge i_pixclk)
if (i_newline)
  o_pixel <= white;
else if (i_rd) begin
  if      (i_btn[0]) o_pixel <= solid_red;      // FIRE1
  else if (i_btn[1]) o_pixel <= solid_grn;      // FIRE2
  else if (i_btn[2]) o_pixel <= solid_blu;      // UP
  else if (i_btn[3]) o_pixel <= solid_white;    // DOWN
  else if (i_btn[4]) o_pixel <= solid_cyan;     // LEFT
  else if (i_btn[5]) o_pixel <= solid_magenta;  // RIGHT
  else if (hpos == i_width-12'd3)
    o_pixel <= white;                           // right border
  else if ((ypos == 0)||(ypos == i_height-1))
    o_pixel <= white;                           // top/bottom border
  else
    o_pixel <= pattern;
end
```

Because this runs at the pixel clock (25 MHz), the color change takes effect on the very next frame — no perceptible lag.

---

## 6. Differential Outputs (`OBUFDS.v`)

HDMI uses differential signaling: each data lane carries a signal and its logical inverse on a wire pair. The `OBUFDS` module drives both:

```verilog
module OBUFDS(input I, output O, output OB);
  assign O  =  I;
  assign OB = ~I;
endmodule
```

On real hardware the ECP5 synthesizes this using its built-in `LVCMOS33D` differential output cell. The Verilog stub here keeps simulation working without vendor primitives.

The top-level connects one `OBUFDS` per HDMI lane:

```verilog
OBUFDS OBUFDS_red  (.I(o_red),     .O(gpdi_dp[2]), .OB(gpdi_dn[2]));
OBUFDS OBUFDS_grn  (.I(o_grn),     .O(gpdi_dp[1]), .OB(gpdi_dn[1]));
OBUFDS OBUFDS_blu  (.I(o_blu),     .O(gpdi_dp[0]), .OB(gpdi_dn[0]));
OBUFDS OBUFDS_clock(.I(clk_25MHz), .O(gpdi_dp[3]), .OB(gpdi_dn[3]));
```

---

## Building

Requires [Yosys](https://github.com/YosysHQ/yosys), [nextpnr-ecp5](https://github.com/YosysHQ/nextpnr), and [ecppack](https://github.com/YosysHQ/prjtrellis).

```bash
cd ButtonPattern
make bitstream                              # synthesize + place-and-route + pack
fujprog ulx3s.bit                               # program the board over USB
```

The `--45k` flag in the Makefile targets the **ECP5-45F** (~45,000 LUTs). Change to `--12k`, `--25k`, or `--85k` if you have a different board variant.
