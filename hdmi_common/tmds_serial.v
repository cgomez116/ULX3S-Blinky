`default_nettype none

// Serializes three 10-bit TMDS words to single-bit streams.
// Loads a new word every 10 i_tmdsclk cycles and shifts out LSB-first.
module tmds_serial(
  input  wire        i_tmdsclk,
  input  wire        i_reset,
  input  wire [9:0]  i_red,
  input  wire [9:0]  i_grn,
  input  wire [9:0]  i_blu,
  output wire        o_red,
  output wire        o_grn,
  output wire        o_blu
);

  // Strobe once every 10 cycles to load the next TMDS word
  reg [3:0] mod10;
  reg       load;
  initial mod10 = 0;
  initial load  = 0;

  always @(posedge i_tmdsclk) begin
    if (i_reset) begin
      mod10 <= 0;
      load  <= 0;
    end else begin
      mod10 <= (mod10 == 4'd9) ? 4'd0 : mod10 + 4'd1;
      load  <= (mod10 == 4'd9);
    end
  end

  // Latch the TMDS colour values into three shift registers
  // at the start of each pixel, then shift out LSB-first.
  reg [9:0] shift_red, shift_grn, shift_blu;
  initial shift_red = 0;
  initial shift_grn = 0;
  initial shift_blu = 0;

  always @(posedge i_tmdsclk) begin
    if (i_reset) begin
      shift_red <= 0;
      shift_grn <= 0;
      shift_blu <= 0;
    end else begin
      shift_red <= load ? i_red : {1'b0, shift_red[9:1]};
      shift_grn <= load ? i_grn : {1'b0, shift_grn[9:1]};
      shift_blu <= load ? i_blu : {1'b0, shift_blu[9:1]};
    end
  end

  assign o_red = shift_red[0];
  assign o_grn = shift_grn[0];
  assign o_blu = shift_blu[0];

endmodule
