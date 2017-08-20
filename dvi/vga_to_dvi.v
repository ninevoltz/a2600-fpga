

`timescale 1 ps / 1 ps

module vga_to_dvi (
  input  wire I_RESET,
  input  wire I_CLK,
  input  wire [7:0] I_VGA_R,
  input  wire [7:0] I_VGA_G,
  input  wire [7:0] I_VGA_B,
  input  wire I_HSYNC,
  input  wire I_VSYNC,
  input  wire I_BLANK,
  output wire [3:0] O_TMDS,
  output wire [3:0] O_TMDSB
);


  wire pllclk0, pllclk1, pllclk2;
  wire pclkx2, pclkx10, pll_lckd;
  wire clkfbout;
  wire reset;

  //
  // Pixel Rate clock buffer
  //
  BUFG pclkbufg (.I(pllclk1), .O(pclk));

  //////////////////////////////////////////////////////////////////
  // 2x pclk is going to be used to drive OSERDES2
  // on the GCLK side
  //////////////////////////////////////////////////////////////////
  BUFG pclkx2bufg (.I(pllclk2), .O(pclkx2));

  //////////////////////////////////////////////////////////////////
  // 10x pclk is used to drive IOCLK network so a bit rate reference
  // can be used by OSERDES2
  //////////////////////////////////////////////////////////////////
  PLL_BASE # (
    .CLKIN_PERIOD(20),
    .CLKFBOUT_MULT(10), //set VCO to 10x of CLKIN
    .CLKOUT0_DIVIDE(2),
    .CLKOUT1_DIVIDE(20),
    .CLKOUT2_DIVIDE(10),
    .COMPENSATION("INTERNAL")
  ) PLL_OSERDES (
    .CLKFBOUT(clkfbout),
    .CLKOUT0(pllclk0),
    .CLKOUT1(pllclk1),
    .CLKOUT2(pllclk2),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(pll_lckd),
    .CLKFBIN(clkfbout),
    .CLKIN(I_CLK),
    .RST(1'b0)
  );

  wire serdesstrobe;
  wire bufpll_lock;
  BUFPLL #(.DIVIDE(5)) ioclk_buf (.PLLIN(pllclk0), .GCLK(pclkx2), .LOCKED(pll_lckd),
           .IOCLK(pclkx10), .SERDESSTROBE(serdesstrobe), .LOCK(bufpll_lock));

  synchro #(.INITIALIZE("LOGIC1"))
  synchro_reset (.async(!pll_lckd),.sync(reset),.clk(pclk));


  assign active = !I_BLANK;

  reg active_q;
  reg vsync, hsync;
  reg VGA_HSYNC, VGA_VSYNC;
  reg de;

  always @ (posedge pclk)
  begin
    hsync <= I_HSYNC ;
    vsync <= I_VSYNC ;
    VGA_HSYNC <= hsync;
    VGA_VSYNC <= vsync;

    active_q <= active;
    de <= active_q;
  end
  


  wire [4:0] tmds_data0, tmds_data1, tmds_data2;

  dvi_encoder enc0 (
    .clkin      (pclk),
    .clkx2in    (pclkx2),
    .rstin      (reset),
    .blue_din   (I_VGA_B),
    .green_din  (I_VGA_G),
    .red_din    (I_VGA_R),
    .hsync      (VGA_HSYNC),
    .vsync      (VGA_VSYNC),
    .de         (de),
    .tmds_data0 (tmds_data0),
    .tmds_data1 (tmds_data1),
    .tmds_data2 (tmds_data2));


  wire [2:0] tmdsint;

  wire serdes_rst = I_RESET | ~bufpll_lock;

//`define DEBUG
               
  serdes_n_to_1 #(.SF(5)) oserdes0 (
             .ioclk(pclkx10),
             .serdesstrobe(serdesstrobe),
             .reset(serdes_rst),
             .gclk(pclkx2),
             .datain(tmds_data0),
             .iob_data_out(tmdsint[0])) ;

  serdes_n_to_1 #(.SF(5)) oserdes1 (
             .ioclk(pclkx10),
             .serdesstrobe(serdesstrobe),
             .reset(serdes_rst),
             .gclk(pclkx2),
             .datain(tmds_data1),
             .iob_data_out(tmdsint[1])) ;

  serdes_n_to_1 #(.SF(5)) oserdes2 (
             .ioclk(pclkx10),
             .serdesstrobe(serdesstrobe),
             .reset(serdes_rst),
             .gclk(pclkx2),
             .datain(tmds_data2),
             .iob_data_out(tmdsint[2])) ;

  OBUFDS TMDS0 (.I(tmdsint[0]), .O(O_TMDS[0]), .OB(O_TMDSB[0])) ;
  OBUFDS TMDS1 (.I(tmdsint[1]), .O(O_TMDS[1]), .OB(O_TMDSB[1])) ;
  OBUFDS TMDS2 (.I(tmdsint[2]), .O(O_TMDS[2]), .OB(O_TMDSB[2])) ;

  reg [4:0] tmdsclkint = 5'b00000;
  reg toggle = 1'b0;

  always @ (posedge pclkx2 or posedge serdes_rst) begin
    if (serdes_rst)
      toggle <= 1'b0;
    else
      toggle <= ~toggle;
  end

  always @ (posedge pclkx2) begin
    if (toggle)
      tmdsclkint <= 5'b11111;
    else
      tmdsclkint <= 5'b00000;
  end

  wire tmdsclk;

  serdes_n_to_1 #(
    .SF           (5))
  clkout (
    .iob_data_out (tmdsclk),
    .ioclk        (pclkx10),
    .serdesstrobe (serdesstrobe),
    .gclk         (pclkx2),
    .reset        (serdes_rst),
    .datain       (tmdsclkint));

  OBUFDS TMDS3 (.I(tmdsclk), .O(O_TMDS[3]), .OB(O_TMDSB[3])) ;// clock

  
endmodule
