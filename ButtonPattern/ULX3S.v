`default_nettype none

module ULX3S (
	input clk_25mhz,
	output [3:0] gpdi_dp, gpdi_dn,
	output wifi_gpio0,
	input  [6:0] btn,
	output [7:0] led);

  assign wifi_gpio0 = 1'b1;

  // Mirror btn[6:1] to led[6:1] so you can see which button is pressed
  assign led = {1'b0, btn[6:1], 1'b0};

  wire clk_25MHz, clk_250MHz;
  clock clock_instance(
      .clkin_25MHz(clk_25mhz),
      .clk_25MHz(clk_25MHz),
      .clk_250MHz(clk_250MHz)
  );

  wire [7:0] red, grn, blu;
  wire [23:0] pixel;
  assign red = pixel[23:16];
  assign grn = pixel[15:8];
  assign blu = pixel[7:0];

  wire o_red, o_grn, o_blu;
  wire o_rd, o_newline, o_newframe;

  // Reset line that goes low after 8 ticks
  /* verilator lint_off WIDTHTRUNC */
  reg [2:0] reset_cnt = 0;
  /* verilator lint_on WIDTHTRUNC */
  wire reset = ~reset_cnt[2];
  always @(posedge clk_25mhz)
    if (reset) reset_cnt <= reset_cnt + 1;

  llhdmi llhdmi_instance(
    .i_tmdsclk(clk_250MHz), .i_pixclk(clk_25MHz),
    .i_reset(reset), .i_red(red), .i_grn(grn), .i_blu(blu),
    .o_rd(o_rd), .o_newline(o_newline), .o_newframe(o_newframe),
    .o_red(o_red), .o_grn(o_grn), .o_blu(o_blu));

  vgatestsrc #(.BITS_PER_COLOR(8))
    vgatestsrc_instance(
      .i_pixclk(clk_25MHz), .i_reset(reset),
      .i_width(640), .i_height(480),
      .i_rd(o_rd), .i_newline(o_newline), .i_newframe(o_newframe),
      .i_btn(btn[6:1]),
      .o_pixel(pixel));

  OBUFDS OBUFDS_red(.I(o_red), .O(gpdi_dp[2]), .OB(gpdi_dn[2]));
  OBUFDS OBUFDS_grn(.I(o_grn), .O(gpdi_dp[1]), .OB(gpdi_dn[1]));
  OBUFDS OBUFDS_blu(.I(o_blu), .O(gpdi_dp[0]), .OB(gpdi_dn[0]));
  OBUFDS OBUFDS_clock(.I(clk_25MHz), .O(gpdi_dp[3]), .OB(gpdi_dn[3]));

endmodule
