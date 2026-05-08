////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	vgatestsrc.v
//
// Project:	vgasim, a Verilator based VGA simulator demonstration
//
// Purpose:	Color-bar test pattern with button-controlled solid color overlays.
//		Holding a button fills the screen with a solid color:
//		  i_btn[0] FIRE1 -> red
//		  i_btn[1] FIRE2 -> green
//		  i_btn[2] UP    -> blue
//		  i_btn[3] DOWN  -> white
//		  i_btn[4] LEFT  -> cyan
//		  i_btn[5] RIGHT -> magenta
//		  (no button)    -> original color-bar test pattern
//
// Creator:	Dan Gisselquist, Ph.D. (original), button support added.
//
////////////////////////////////////////////////////////////////////////////////
`default_nettype	none
//
module	vgatestsrc(i_pixclk, i_reset,
		// External connections
		i_width, i_height,
		i_rd, i_newline, i_newframe,
		// Button inputs
		i_btn,
		// VGA connections
		o_pixel);
	parameter	BITS_PER_COLOR = 4,
			HW=12, VW=12;
	localparam	BPC = BITS_PER_COLOR,
			BITS_PER_PIXEL = 3 * BPC,
			BPP = BITS_PER_PIXEL;
	//
	input	wire			i_pixclk, i_reset;
	input	wire	[HW-1:0]	i_width;
	input	wire	[VW-1:0]	i_height;
	//
	input	wire		i_rd, i_newline, i_newframe;
	//
	input	wire	[5:0]	i_btn;
	//
	output	reg	[(BPP-1):0]	o_pixel;



	wire	[BPP-1:0]	white, black, purplish_blue, purple, dark_gray,
				darkest_gray, mid_white, mid_cyan, mid_magenta,
				mid_red, mid_green, mid_blue, mid_yellow;
	wire	[BPC-1:0]	midv, mid_off;

	assign	midv    = { 2'b11, {(BPC-2){1'b0}} };
	assign	mid_off = { (BPC){1'b0} };

	assign	white = {(BPP){1'b1}};
	assign	black = {(BPP){1'b0}};
	assign	purplish_blue = {
				{(BPC){1'b0}},
				3'b001,  {(BPC-3){1'b0}},
				2'b01, {(BPC-2){1'b0}} };
	assign	purple = { {2'b00, {(BPC-2){1'b1}} }, {(BPC){1'b0}},
			{ 1'b0, {(BPC-1){1'b1}} } };

	assign	dark_gray    = {(3){  { 4'b0010, {(BPC-4){1'b0}} } }};
	assign	darkest_gray = {(3){  { 4'b0001, {(BPC-4){1'b0}} } }};

	assign	mid_white   = { midv,    midv,    midv    };
	assign	mid_yellow  = { midv,    midv,    mid_off };
	assign	mid_red     = { midv,    mid_off, mid_off };
	assign	mid_green   = { mid_off, midv,    mid_off };
	assign	mid_blue    = { mid_off, mid_off, midv    };
	assign	mid_cyan    = { mid_off, midv,    midv    };
	assign	mid_magenta = { midv,    mid_off, midv    };

	// Full-brightness solid colors for button overlays
	wire [BPP-1:0] solid_red, solid_grn, solid_blu;
	wire [BPP-1:0] solid_white, solid_cyan, solid_magenta;
	assign solid_red     = { {(BPC){1'b1}}, {(BPC){1'b0}}, {(BPC){1'b0}} };
	assign solid_grn     = { {(BPC){1'b0}}, {(BPC){1'b1}}, {(BPC){1'b0}} };
	assign solid_blu     = { {(BPC){1'b0}}, {(BPC){1'b0}}, {(BPC){1'b1}} };
	assign solid_white   = { {(BPC){1'b1}}, {(BPC){1'b1}}, {(BPC){1'b1}} };
	assign solid_cyan    = { {(BPC){1'b0}}, {(BPC){1'b1}}, {(BPC){1'b1}} };
	assign solid_magenta = { {(BPC){1'b1}}, {(BPC){1'b0}}, {(BPC){1'b1}} };

	reg	[HW-1:0]	hpos, hedge;
	reg	[VW-1:0]	ypos, yedge;
	reg	[3:0]		yline, hbar;
	//
	reg	dline;
	always @(posedge i_pixclk)
	if ((i_reset)||(i_newframe)||(i_newline))
		dline <= 1'b0;
	else if (i_rd)
		dline <= 1'b1;

	always @(posedge i_pixclk)
	if ((i_reset)||(i_newframe))
	begin
		ypos  <= 0;
		yline <= 0;
		yedge <= { 4'h0, i_height[(VW-1):4] };
	end else if (i_newline)
	begin
		ypos <= ypos + { {(VW-1){1'h0}}, dline };
		if (ypos >= yedge)
		begin
			yline <= yline + 1'b1;
			yedge <= yedge + { 4'h0, i_height[(VW-1):4] };
		end
	end

	initial	hpos  = 0;
	initial	hbar  = 0;
	initial	hedge = 0;
	always @(posedge i_pixclk)
	if ((i_reset)||(i_newline))
	begin
		hpos <= 0;
		hbar <= 0;
		hedge <= { 4'h0, i_width[(HW-1):4] };
	end else if (i_rd)
	begin
		hpos <= hpos + 1'b1;
		if (hpos >= hedge)
		begin
			hbar <= hbar + 1'b1;
			hedge <= hedge + { 4'h0, i_width[(HW-1):4] };
		end
	end

	reg	[BPP-1:0]	topbar, midbar, fatbar, gradient, pattern;
	always @(posedge i_pixclk)
	case(hbar[3:0])
	4'h0: topbar <= black;
	4'h1: topbar <= mid_white;
	4'h2: topbar <= mid_white;
	4'h3: topbar <= mid_yellow;
	4'h4: topbar <= mid_yellow;
	4'h5: topbar <= mid_cyan;
	4'h6: topbar <= mid_cyan;
	4'h7: topbar <= mid_green;
	4'h8: topbar <= mid_green;
	4'h9: topbar <= mid_magenta;
	4'ha: topbar <= mid_magenta;
	4'hb: topbar <= mid_red;
	4'hc: topbar <= mid_red;
	4'hd: topbar <= mid_blue;
	4'he: topbar <= mid_blue;
	4'hf: topbar <= black;
	endcase

	always @(posedge i_pixclk)
	case(hbar[3:0])
	4'h0: midbar <= black;
	4'h1: midbar <= mid_blue;
	4'h2: midbar <= mid_blue;
	4'h3: midbar <= black;
	4'h4: midbar <= black;
	4'h5: midbar <= mid_magenta;
	4'h6: midbar <= mid_magenta;
	4'h7: midbar <= black;
	4'h8: midbar <= black;
	4'h9: midbar <= mid_cyan;
	4'ha: midbar <= mid_cyan;
	4'hb: midbar <= black;
	4'hc: midbar <= black;
	4'hd: midbar <= mid_white;
	4'he: midbar <= mid_white;
	4'hf: midbar <= black;
	endcase

	always @(posedge i_pixclk)
	case(hbar[3:0])
	4'h0: fatbar <= black;
	4'h1: fatbar <= purplish_blue;
	4'h2: fatbar <= purplish_blue;
	4'h3: fatbar <= purplish_blue;
	4'h4: fatbar <=	white;
	4'h5: fatbar <= white;
	4'h6: fatbar <= white;
	4'h7: fatbar <= purple;
	4'h8: fatbar <= purple;
	4'h9: fatbar <= purple;
	4'ha: fatbar <= darkest_gray;
	4'hb: fatbar <= black;
	4'hc: fatbar <= dark_gray;
	4'hd: fatbar <= darkest_gray;
	4'he: fatbar <= black;
	4'hf: fatbar <= black;
	endcase

	reg	[(HW-1):0]	last_width;
	always @(posedge i_pixclk)
		last_width <= i_width;

	localparam	FRACB=16;
	//
	reg	[(FRACB-1):0]	hfrac, h_step;
	always @(posedge i_pixclk)
	if ((i_reset)||(i_newline))
		hfrac <= 0;
	else if (i_rd)
		hfrac <= hfrac + h_step;

	always @(posedge i_pixclk)
	if ((i_reset)||(i_width != last_width))
		h_step <= 1;
	else if ((i_newline)&&(hfrac > 0))
	begin
		if (hfrac < {(FRACB){1'b1}} - { {(FRACB-HW){1'b0}}, i_width })
			h_step <= h_step + 1'b1;
		else if (hfrac < { {(FRACB-HW){1'b0}}, i_width })
			h_step <= h_step - 1'b1;
	end

	always @(posedge i_pixclk)
	case(hfrac[FRACB-1:FRACB-4])
	4'h0: gradient <= black;
	// Red
	4'h1: gradient <= { 1'b0, hfrac[(FRACB-5):(FRACB-3-BPC)], {(2){mid_off}} };
	4'h2: gradient <= { 1'b1, hfrac[(FRACB-5):(FRACB-3-BPC)], {(2){mid_off}} };
	4'h3: gradient <= black;
	// Green
	4'h4: gradient <= { mid_off, 1'b0, hfrac[(FRACB-5):(FRACB-3-BPC)], mid_off };
	4'h5: gradient <= { mid_off, 1'b1, hfrac[(FRACB-5):(FRACB-3-BPC)], mid_off };
	4'h6: gradient <= black;
	// Blue
	4'h7: gradient <= { {(2){mid_off}}, 1'b0, hfrac[(FRACB-5):(FRACB-3-BPC)] };
	4'h8: gradient <= { {(2){mid_off}}, 1'b1, hfrac[(FRACB-5):(FRACB-3-BPC)] };
	4'h9: gradient <= black;
	// Gray
	4'ha: gradient <= {(3){ 2'b00, hfrac[(FRACB-5):(FRACB-2-BPC)] }};
	4'hb: gradient <= {(3){ 2'b01, hfrac[(FRACB-5):(FRACB-2-BPC)] }};
	4'hc: gradient <= {(3){ 2'b10, hfrac[(FRACB-5):(FRACB-2-BPC)] }};
	4'hd: gradient <= {(3){ 2'b11, hfrac[(FRACB-5):(FRACB-2-BPC)] }};
	4'he: gradient <= black;
	//
	4'hf: gradient <= black;
	endcase

	always @(posedge i_pixclk)
	case(yline)
	4'h0: pattern <= black;
	4'h1: pattern <= topbar;
	4'h2: pattern <= topbar;
	4'h3: pattern <= topbar;
	4'h4: pattern <= topbar;
	4'h5: pattern <= topbar;
	4'h6: pattern <= topbar;
	4'h7: pattern <= topbar;
	4'h8: pattern <= topbar;
	4'h9: pattern <= midbar;
	4'ha: pattern <= fatbar;
	4'hb: pattern <= fatbar;
	4'hc: pattern <= fatbar;
	4'hd: pattern <= black;
	4'he: pattern <= gradient;
	4'hf: pattern <= black;
	endcase

	always @(posedge i_pixclk)
	if (i_newline)
		o_pixel <= white;
	else if (i_rd)
	begin
		if (i_btn[0])
			o_pixel <= solid_red;       // FIRE1
		else if (i_btn[1])
			o_pixel <= solid_grn;       // FIRE2
		else if (i_btn[2])
			o_pixel <= solid_blu;       // UP
		else if (i_btn[3])
			o_pixel <= solid_white;     // DOWN
		else if (i_btn[4])
			o_pixel <= solid_cyan;      // LEFT
		else if (i_btn[5])
			o_pixel <= solid_magenta;   // RIGHT
		else if (hpos == i_width-12'd3)
			o_pixel <= white;
		else if ((ypos == 0)||(ypos == i_height-1))
			o_pixel <= white;
		else
			o_pixel <= pattern;
	end

endmodule
