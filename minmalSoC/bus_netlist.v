/////////////////////////////////////////////////////////////
// Created by: Synopsys DC Expert(TM) in wire load mode
// Version   : V-2023.12-SP5
// Date      : Fri Feb 13 13:33:26 2026
/////////////////////////////////////////////////////////////


module wb_bus_b3 ( clk_i, rst_i, m_adr_i, m_dat_i, m_cyc_i, m_stb_i, m_sel_i, 
        m_we_i, m_cti_i, m_bte_i, m_dat_o, m_ack_o, m_err_o, m_rty_o, s_adr_o, 
        s_dat_o, s_cyc_o, s_stb_o, s_sel_o, s_we_o, s_cti_o, s_bte_o, s_dat_i, 
        s_ack_i, s_err_i, s_rty_i, snoop_adr_o, snoop_en_o, bus_hold, 
        bus_hold_ack );
  input [31:0] m_adr_i;
  input [31:0] m_dat_i;
  input [0:0] m_cyc_i;
  input [0:0] m_stb_i;
  input [3:0] m_sel_i;
  input [0:0] m_we_i;
  input [2:0] m_cti_i;
  input [1:0] m_bte_i;
  output [31:0] m_dat_o;
  output [0:0] m_ack_o;
  output [0:0] m_err_o;
  output [0:0] m_rty_o;
  output [63:0] s_adr_o;
  output [63:0] s_dat_o;
  output [1:0] s_cyc_o;
  output [1:0] s_stb_o;
  output [7:0] s_sel_o;
  output [1:0] s_we_o;
  output [5:0] s_cti_o;
  output [3:0] s_bte_o;
  input [63:0] s_dat_i;
  input [1:0] s_ack_i;
  input [1:0] s_err_i;
  input [1:0] s_rty_i;
  output [31:0] snoop_adr_o;
  input clk_i, rst_i, bus_hold;
  output snoop_en_o, bus_hold_ack;
  wire   \s_we_o[1] , \u_mux/N8 , \u_mux/N7 , \u_mux/arb_grant[0] , n1, n2, n3,
         n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, n18,
         n19, n20, n21, n22, n23, n24, n25, n26, n27, n28, n29, n30, n31, n32,
         n33, n34, n35, n36, n37, n38, n39, n40, n41, n42, n43, n44, n45, n46,
         n47, n48, n49, n50, n51, n52, n53, n54;
  assign snoop_adr_o[31] = s_adr_o[63];
  assign s_adr_o[31] = s_adr_o[63];
  assign snoop_adr_o[30] = s_adr_o[62];
  assign s_adr_o[30] = s_adr_o[62];
  assign snoop_adr_o[29] = s_adr_o[61];
  assign s_adr_o[29] = s_adr_o[61];
  assign snoop_adr_o[28] = s_adr_o[60];
  assign s_adr_o[28] = s_adr_o[60];
  assign snoop_adr_o[27] = s_adr_o[59];
  assign s_adr_o[27] = s_adr_o[59];
  assign snoop_adr_o[26] = s_adr_o[58];
  assign s_adr_o[26] = s_adr_o[58];
  assign snoop_adr_o[25] = s_adr_o[57];
  assign s_adr_o[25] = s_adr_o[57];
  assign snoop_adr_o[24] = s_adr_o[56];
  assign s_adr_o[24] = s_adr_o[56];
  assign snoop_adr_o[23] = s_adr_o[55];
  assign s_adr_o[23] = s_adr_o[55];
  assign snoop_adr_o[22] = s_adr_o[54];
  assign s_adr_o[22] = s_adr_o[54];
  assign snoop_adr_o[21] = s_adr_o[53];
  assign s_adr_o[21] = s_adr_o[53];
  assign snoop_adr_o[20] = s_adr_o[52];
  assign s_adr_o[20] = s_adr_o[52];
  assign snoop_adr_o[19] = s_adr_o[51];
  assign s_adr_o[19] = s_adr_o[51];
  assign snoop_adr_o[18] = s_adr_o[50];
  assign s_adr_o[18] = s_adr_o[50];
  assign snoop_adr_o[17] = s_adr_o[49];
  assign s_adr_o[17] = s_adr_o[49];
  assign snoop_adr_o[16] = s_adr_o[48];
  assign s_adr_o[16] = s_adr_o[48];
  assign snoop_adr_o[15] = s_adr_o[47];
  assign s_adr_o[15] = s_adr_o[47];
  assign snoop_adr_o[14] = s_adr_o[46];
  assign s_adr_o[14] = s_adr_o[46];
  assign snoop_adr_o[13] = s_adr_o[45];
  assign s_adr_o[13] = s_adr_o[45];
  assign snoop_adr_o[12] = s_adr_o[44];
  assign s_adr_o[12] = s_adr_o[44];
  assign snoop_adr_o[11] = s_adr_o[43];
  assign s_adr_o[11] = s_adr_o[43];
  assign snoop_adr_o[10] = s_adr_o[42];
  assign s_adr_o[10] = s_adr_o[42];
  assign snoop_adr_o[9] = s_adr_o[41];
  assign s_adr_o[9] = s_adr_o[41];
  assign snoop_adr_o[8] = s_adr_o[40];
  assign s_adr_o[8] = s_adr_o[40];
  assign snoop_adr_o[7] = s_adr_o[39];
  assign s_adr_o[7] = s_adr_o[39];
  assign snoop_adr_o[6] = s_adr_o[38];
  assign s_adr_o[6] = s_adr_o[38];
  assign snoop_adr_o[5] = s_adr_o[37];
  assign s_adr_o[5] = s_adr_o[37];
  assign snoop_adr_o[4] = s_adr_o[36];
  assign s_adr_o[4] = s_adr_o[36];
  assign snoop_adr_o[3] = s_adr_o[35];
  assign s_adr_o[3] = s_adr_o[35];
  assign snoop_adr_o[2] = s_adr_o[34];
  assign s_adr_o[2] = s_adr_o[34];
  assign snoop_adr_o[1] = s_adr_o[33];
  assign s_adr_o[1] = s_adr_o[33];
  assign snoop_adr_o[0] = s_adr_o[32];
  assign s_adr_o[0] = s_adr_o[32];
  assign s_dat_o[31] = s_dat_o[63];
  assign s_dat_o[30] = s_dat_o[62];
  assign s_dat_o[29] = s_dat_o[61];
  assign s_dat_o[28] = s_dat_o[60];
  assign s_dat_o[27] = s_dat_o[59];
  assign s_dat_o[26] = s_dat_o[58];
  assign s_dat_o[25] = s_dat_o[57];
  assign s_dat_o[24] = s_dat_o[56];
  assign s_dat_o[23] = s_dat_o[55];
  assign s_dat_o[22] = s_dat_o[54];
  assign s_dat_o[21] = s_dat_o[53];
  assign s_dat_o[20] = s_dat_o[52];
  assign s_dat_o[19] = s_dat_o[51];
  assign s_dat_o[18] = s_dat_o[50];
  assign s_dat_o[17] = s_dat_o[49];
  assign s_dat_o[16] = s_dat_o[48];
  assign s_dat_o[15] = s_dat_o[47];
  assign s_dat_o[14] = s_dat_o[46];
  assign s_dat_o[13] = s_dat_o[45];
  assign s_dat_o[12] = s_dat_o[44];
  assign s_dat_o[11] = s_dat_o[43];
  assign s_dat_o[10] = s_dat_o[42];
  assign s_dat_o[9] = s_dat_o[41];
  assign s_dat_o[8] = s_dat_o[40];
  assign s_dat_o[7] = s_dat_o[39];
  assign s_dat_o[6] = s_dat_o[38];
  assign s_dat_o[5] = s_dat_o[37];
  assign s_dat_o[4] = s_dat_o[36];
  assign s_dat_o[3] = s_dat_o[35];
  assign s_dat_o[2] = s_dat_o[34];
  assign s_dat_o[1] = s_dat_o[33];
  assign s_dat_o[0] = s_dat_o[32];
  assign s_sel_o[3] = s_sel_o[7];
  assign s_sel_o[2] = s_sel_o[6];
  assign s_sel_o[1] = s_sel_o[5];
  assign s_sel_o[0] = s_sel_o[4];
  assign s_we_o[0] = \s_we_o[1] ;
  assign s_we_o[1] = \s_we_o[1] ;

  dffs1 \u_mux/prev_grant_reg[0]  ( .DIN(\u_mux/N8 ), .CLK(clk_i), .QN(n54) );
  dffs1 \u_mux/prev_arb_grant_reg[0]  ( .DIN(\u_mux/N7 ), .CLK(clk_i), .Q(
        \u_mux/arb_grant[0] ) );
  nnd2s2 U2 ( .DIN1(n51), .DIN2(n52), .Q(n1) );
  i1s1 U3 ( .DIN(n1), .Q(n2) );
  hi1s1 U4 ( .DIN(n1), .Q(n3) );
  hi1s1 U5 ( .DIN(n17), .Q(n4) );
  hi1s1 U6 ( .DIN(n17), .Q(n5) );
  hi1s1 U7 ( .DIN(n17), .Q(n6) );
  ib1s1 U8 ( .DIN(n8), .Q(n7) );
  ib1s1 U9 ( .DIN(n8), .Q(n13) );
  or2s1 U10 ( .DIN1(rst_i), .DIN2(n4), .Q(\u_mux/N8 ) );
  or2s1 U11 ( .DIN1(\u_mux/arb_grant[0] ), .DIN2(rst_i), .Q(\u_mux/N7 ) );
  and3s1 U12 ( .DIN1(m_stb_i[0]), .DIN2(m_ack_o[0]), .DIN3(m_we_i[0]), .Q(
        snoop_en_o) );
  and2s1 U13 ( .DIN1(n4), .DIN2(m_we_i[0]), .Q(\s_we_o[1] ) );
  nor2s1 U14 ( .DIN1(n8), .DIN2(n9), .Q(s_stb_o[1]) );
  nor2s1 U15 ( .DIN1(n10), .DIN2(n9), .Q(s_stb_o[0]) );
  hi1s1 U16 ( .DIN(m_stb_i[0]), .Q(n9) );
  and2s1 U17 ( .DIN1(m_sel_i[3]), .DIN2(n6), .Q(s_sel_o[7]) );
  and2s1 U18 ( .DIN1(m_sel_i[2]), .DIN2(n5), .Q(s_sel_o[6]) );
  and2s1 U19 ( .DIN1(m_sel_i[1]), .DIN2(n4), .Q(s_sel_o[5]) );
  and2s1 U20 ( .DIN1(m_sel_i[0]), .DIN2(n6), .Q(s_sel_o[4]) );
  and2s1 U21 ( .DIN1(m_dat_i[31]), .DIN2(n5), .Q(s_dat_o[63]) );
  and2s1 U22 ( .DIN1(m_dat_i[30]), .DIN2(n4), .Q(s_dat_o[62]) );
  and2s1 U23 ( .DIN1(m_dat_i[29]), .DIN2(n6), .Q(s_dat_o[61]) );
  and2s1 U24 ( .DIN1(m_dat_i[28]), .DIN2(n5), .Q(s_dat_o[60]) );
  and2s1 U25 ( .DIN1(m_dat_i[27]), .DIN2(n4), .Q(s_dat_o[59]) );
  and2s1 U26 ( .DIN1(m_dat_i[26]), .DIN2(n6), .Q(s_dat_o[58]) );
  and2s1 U27 ( .DIN1(m_dat_i[25]), .DIN2(n5), .Q(s_dat_o[57]) );
  and2s1 U28 ( .DIN1(m_dat_i[24]), .DIN2(n4), .Q(s_dat_o[56]) );
  and2s1 U29 ( .DIN1(m_dat_i[23]), .DIN2(n6), .Q(s_dat_o[55]) );
  and2s1 U30 ( .DIN1(m_dat_i[22]), .DIN2(n5), .Q(s_dat_o[54]) );
  and2s1 U31 ( .DIN1(m_dat_i[21]), .DIN2(n4), .Q(s_dat_o[53]) );
  and2s1 U32 ( .DIN1(m_dat_i[20]), .DIN2(n6), .Q(s_dat_o[52]) );
  and2s1 U33 ( .DIN1(m_dat_i[19]), .DIN2(n5), .Q(s_dat_o[51]) );
  and2s1 U34 ( .DIN1(m_dat_i[18]), .DIN2(n4), .Q(s_dat_o[50]) );
  and2s1 U35 ( .DIN1(m_dat_i[17]), .DIN2(n6), .Q(s_dat_o[49]) );
  and2s1 U36 ( .DIN1(m_dat_i[16]), .DIN2(n5), .Q(s_dat_o[48]) );
  and2s1 U37 ( .DIN1(m_dat_i[15]), .DIN2(n4), .Q(s_dat_o[47]) );
  and2s1 U38 ( .DIN1(m_dat_i[14]), .DIN2(n6), .Q(s_dat_o[46]) );
  and2s1 U39 ( .DIN1(m_dat_i[13]), .DIN2(n5), .Q(s_dat_o[45]) );
  and2s1 U40 ( .DIN1(m_dat_i[12]), .DIN2(n4), .Q(s_dat_o[44]) );
  and2s1 U41 ( .DIN1(m_dat_i[11]), .DIN2(n6), .Q(s_dat_o[43]) );
  and2s1 U42 ( .DIN1(m_dat_i[10]), .DIN2(n5), .Q(s_dat_o[42]) );
  and2s1 U43 ( .DIN1(m_dat_i[9]), .DIN2(n4), .Q(s_dat_o[41]) );
  and2s1 U44 ( .DIN1(m_dat_i[8]), .DIN2(n6), .Q(s_dat_o[40]) );
  and2s1 U45 ( .DIN1(m_dat_i[7]), .DIN2(n5), .Q(s_dat_o[39]) );
  and2s1 U46 ( .DIN1(m_dat_i[6]), .DIN2(n4), .Q(s_dat_o[38]) );
  and2s1 U47 ( .DIN1(m_dat_i[5]), .DIN2(n6), .Q(s_dat_o[37]) );
  and2s1 U48 ( .DIN1(m_dat_i[4]), .DIN2(n5), .Q(s_dat_o[36]) );
  and2s1 U49 ( .DIN1(m_dat_i[3]), .DIN2(n4), .Q(s_dat_o[35]) );
  and2s1 U50 ( .DIN1(m_dat_i[2]), .DIN2(n6), .Q(s_dat_o[34]) );
  and2s1 U51 ( .DIN1(m_dat_i[1]), .DIN2(n5), .Q(s_dat_o[33]) );
  and2s1 U52 ( .DIN1(m_dat_i[0]), .DIN2(n4), .Q(s_dat_o[32]) );
  nor2s1 U53 ( .DIN1(n11), .DIN2(n8), .Q(s_cyc_o[1]) );
  nor2s1 U54 ( .DIN1(n11), .DIN2(n10), .Q(s_cyc_o[0]) );
  and2s1 U55 ( .DIN1(n6), .DIN2(m_adr_i[31]), .Q(s_adr_o[63]) );
  and2s1 U56 ( .DIN1(n5), .DIN2(m_adr_i[30]), .Q(s_adr_o[62]) );
  and2s1 U57 ( .DIN1(n4), .DIN2(m_adr_i[29]), .Q(s_adr_o[61]) );
  and2s1 U58 ( .DIN1(m_adr_i[27]), .DIN2(n6), .Q(s_adr_o[59]) );
  and2s1 U59 ( .DIN1(m_adr_i[26]), .DIN2(n5), .Q(s_adr_o[58]) );
  and2s1 U60 ( .DIN1(m_adr_i[25]), .DIN2(n4), .Q(s_adr_o[57]) );
  and2s1 U61 ( .DIN1(m_adr_i[24]), .DIN2(n6), .Q(s_adr_o[56]) );
  and2s1 U62 ( .DIN1(m_adr_i[23]), .DIN2(n5), .Q(s_adr_o[55]) );
  and2s1 U63 ( .DIN1(m_adr_i[22]), .DIN2(n4), .Q(s_adr_o[54]) );
  and2s1 U64 ( .DIN1(m_adr_i[21]), .DIN2(n6), .Q(s_adr_o[53]) );
  and2s1 U65 ( .DIN1(m_adr_i[20]), .DIN2(n5), .Q(s_adr_o[52]) );
  and2s1 U66 ( .DIN1(m_adr_i[19]), .DIN2(n4), .Q(s_adr_o[51]) );
  and2s1 U67 ( .DIN1(m_adr_i[18]), .DIN2(n6), .Q(s_adr_o[50]) );
  and2s1 U68 ( .DIN1(m_adr_i[17]), .DIN2(n5), .Q(s_adr_o[49]) );
  and2s1 U69 ( .DIN1(m_adr_i[16]), .DIN2(n4), .Q(s_adr_o[48]) );
  and2s1 U70 ( .DIN1(m_adr_i[15]), .DIN2(n6), .Q(s_adr_o[47]) );
  and2s1 U71 ( .DIN1(m_adr_i[14]), .DIN2(n5), .Q(s_adr_o[46]) );
  and2s1 U72 ( .DIN1(m_adr_i[13]), .DIN2(n4), .Q(s_adr_o[45]) );
  and2s1 U73 ( .DIN1(m_adr_i[12]), .DIN2(n6), .Q(s_adr_o[44]) );
  and2s1 U74 ( .DIN1(m_adr_i[11]), .DIN2(n5), .Q(s_adr_o[43]) );
  and2s1 U75 ( .DIN1(m_adr_i[10]), .DIN2(n4), .Q(s_adr_o[42]) );
  and2s1 U76 ( .DIN1(m_adr_i[9]), .DIN2(n6), .Q(s_adr_o[41]) );
  and2s1 U77 ( .DIN1(m_adr_i[8]), .DIN2(n5), .Q(s_adr_o[40]) );
  and2s1 U78 ( .DIN1(m_adr_i[7]), .DIN2(n4), .Q(s_adr_o[39]) );
  and2s1 U79 ( .DIN1(m_adr_i[6]), .DIN2(n6), .Q(s_adr_o[38]) );
  and2s1 U80 ( .DIN1(m_adr_i[5]), .DIN2(n5), .Q(s_adr_o[37]) );
  and2s1 U81 ( .DIN1(m_adr_i[4]), .DIN2(n4), .Q(s_adr_o[36]) );
  and2s1 U82 ( .DIN1(m_adr_i[3]), .DIN2(n6), .Q(s_adr_o[35]) );
  and2s1 U83 ( .DIN1(m_adr_i[2]), .DIN2(n5), .Q(s_adr_o[34]) );
  and2s1 U84 ( .DIN1(m_adr_i[1]), .DIN2(n6), .Q(s_adr_o[33]) );
  and2s1 U85 ( .DIN1(m_adr_i[0]), .DIN2(n5), .Q(s_adr_o[32]) );
  hi1s1 U86 ( .DIN(n12), .Q(m_rty_o[0]) );
  aoi22s1 U87 ( .DIN1(s_rty_i[1]), .DIN2(n7), .DIN3(s_rty_i[0]), .DIN4(n14), 
        .Q(n12) );
  aoi21s1 U88 ( .DIN1(n15), .DIN2(n16), .DIN3(n17), .Q(m_err_o[0]) );
  nnd2s1 U89 ( .DIN1(s_err_i[1]), .DIN2(n7), .Q(n16) );
  mxi21s1 U90 ( .DIN1(n8), .DIN2(s_err_i[0]), .SIN(n3), .Q(n15) );
  hi1s1 U91 ( .DIN(n18), .Q(m_dat_o[9]) );
  aoi22s1 U92 ( .DIN1(s_dat_i[41]), .DIN2(n7), .DIN3(s_dat_i[9]), .DIN4(n3), 
        .Q(n18) );
  hi1s1 U93 ( .DIN(n19), .Q(m_dat_o[8]) );
  aoi22s1 U94 ( .DIN1(s_dat_i[40]), .DIN2(n7), .DIN3(s_dat_i[8]), .DIN4(n3), 
        .Q(n19) );
  hi1s1 U95 ( .DIN(n20), .Q(m_dat_o[7]) );
  aoi22s1 U96 ( .DIN1(s_dat_i[39]), .DIN2(n7), .DIN3(s_dat_i[7]), .DIN4(n3), 
        .Q(n20) );
  hi1s1 U97 ( .DIN(n21), .Q(m_dat_o[6]) );
  aoi22s1 U98 ( .DIN1(s_dat_i[38]), .DIN2(n7), .DIN3(s_dat_i[6]), .DIN4(n3), 
        .Q(n21) );
  hi1s1 U99 ( .DIN(n22), .Q(m_dat_o[5]) );
  aoi22s1 U100 ( .DIN1(s_dat_i[37]), .DIN2(n7), .DIN3(s_dat_i[5]), .DIN4(n3), 
        .Q(n22) );
  hi1s1 U101 ( .DIN(n23), .Q(m_dat_o[4]) );
  aoi22s1 U102 ( .DIN1(s_dat_i[36]), .DIN2(n7), .DIN3(s_dat_i[4]), .DIN4(n3), 
        .Q(n23) );
  hi1s1 U103 ( .DIN(n24), .Q(m_dat_o[3]) );
  aoi22s1 U104 ( .DIN1(s_dat_i[35]), .DIN2(n7), .DIN3(s_dat_i[3]), .DIN4(n3), 
        .Q(n24) );
  hi1s1 U105 ( .DIN(n25), .Q(m_dat_o[31]) );
  aoi22s1 U106 ( .DIN1(s_dat_i[63]), .DIN2(n7), .DIN3(s_dat_i[31]), .DIN4(n3), 
        .Q(n25) );
  hi1s1 U107 ( .DIN(n26), .Q(m_dat_o[30]) );
  aoi22s1 U108 ( .DIN1(s_dat_i[62]), .DIN2(n7), .DIN3(s_dat_i[30]), .DIN4(n3), 
        .Q(n26) );
  hi1s1 U109 ( .DIN(n27), .Q(m_dat_o[2]) );
  aoi22s1 U110 ( .DIN1(s_dat_i[34]), .DIN2(n7), .DIN3(s_dat_i[2]), .DIN4(n3), 
        .Q(n27) );
  hi1s1 U111 ( .DIN(n28), .Q(m_dat_o[29]) );
  aoi22s1 U112 ( .DIN1(s_dat_i[61]), .DIN2(n7), .DIN3(s_dat_i[29]), .DIN4(n3), 
        .Q(n28) );
  hi1s1 U113 ( .DIN(n29), .Q(m_dat_o[28]) );
  aoi22s1 U114 ( .DIN1(s_dat_i[60]), .DIN2(n13), .DIN3(s_dat_i[28]), .DIN4(n3), 
        .Q(n29) );
  hi1s1 U115 ( .DIN(n30), .Q(m_dat_o[27]) );
  aoi22s1 U116 ( .DIN1(s_dat_i[59]), .DIN2(n13), .DIN3(s_dat_i[27]), .DIN4(n3), 
        .Q(n30) );
  hi1s1 U117 ( .DIN(n31), .Q(m_dat_o[26]) );
  aoi22s1 U118 ( .DIN1(s_dat_i[58]), .DIN2(n13), .DIN3(s_dat_i[26]), .DIN4(n3), 
        .Q(n31) );
  hi1s1 U119 ( .DIN(n32), .Q(m_dat_o[25]) );
  aoi22s1 U120 ( .DIN1(s_dat_i[57]), .DIN2(n13), .DIN3(s_dat_i[25]), .DIN4(n3), 
        .Q(n32) );
  hi1s1 U121 ( .DIN(n33), .Q(m_dat_o[24]) );
  aoi22s1 U122 ( .DIN1(s_dat_i[56]), .DIN2(n13), .DIN3(s_dat_i[24]), .DIN4(n2), 
        .Q(n33) );
  hi1s1 U123 ( .DIN(n34), .Q(m_dat_o[23]) );
  aoi22s1 U124 ( .DIN1(s_dat_i[55]), .DIN2(n13), .DIN3(s_dat_i[23]), .DIN4(n2), 
        .Q(n34) );
  hi1s1 U125 ( .DIN(n35), .Q(m_dat_o[22]) );
  aoi22s1 U126 ( .DIN1(s_dat_i[54]), .DIN2(n13), .DIN3(s_dat_i[22]), .DIN4(n2), 
        .Q(n35) );
  hi1s1 U127 ( .DIN(n36), .Q(m_dat_o[21]) );
  aoi22s1 U128 ( .DIN1(s_dat_i[53]), .DIN2(n13), .DIN3(s_dat_i[21]), .DIN4(n2), 
        .Q(n36) );
  hi1s1 U129 ( .DIN(n37), .Q(m_dat_o[20]) );
  aoi22s1 U130 ( .DIN1(s_dat_i[52]), .DIN2(n13), .DIN3(s_dat_i[20]), .DIN4(n2), 
        .Q(n37) );
  hi1s1 U131 ( .DIN(n38), .Q(m_dat_o[1]) );
  aoi22s1 U132 ( .DIN1(s_dat_i[33]), .DIN2(n13), .DIN3(s_dat_i[1]), .DIN4(n2), 
        .Q(n38) );
  hi1s1 U133 ( .DIN(n39), .Q(m_dat_o[19]) );
  aoi22s1 U134 ( .DIN1(s_dat_i[51]), .DIN2(n13), .DIN3(s_dat_i[19]), .DIN4(n2), 
        .Q(n39) );
  hi1s1 U135 ( .DIN(n40), .Q(m_dat_o[18]) );
  aoi22s1 U136 ( .DIN1(s_dat_i[50]), .DIN2(n13), .DIN3(s_dat_i[18]), .DIN4(n2), 
        .Q(n40) );
  hi1s1 U137 ( .DIN(n41), .Q(m_dat_o[17]) );
  aoi22s1 U138 ( .DIN1(s_dat_i[49]), .DIN2(n13), .DIN3(s_dat_i[17]), .DIN4(n2), 
        .Q(n41) );
  hi1s1 U139 ( .DIN(n42), .Q(m_dat_o[16]) );
  aoi22s1 U140 ( .DIN1(s_dat_i[48]), .DIN2(n13), .DIN3(s_dat_i[16]), .DIN4(n2), 
        .Q(n42) );
  hi1s1 U141 ( .DIN(n43), .Q(m_dat_o[15]) );
  aoi22s1 U142 ( .DIN1(s_dat_i[47]), .DIN2(n13), .DIN3(s_dat_i[15]), .DIN4(n2), 
        .Q(n43) );
  hi1s1 U143 ( .DIN(n44), .Q(m_dat_o[14]) );
  aoi22s1 U144 ( .DIN1(s_dat_i[46]), .DIN2(n13), .DIN3(s_dat_i[14]), .DIN4(n2), 
        .Q(n44) );
  hi1s1 U145 ( .DIN(n45), .Q(m_dat_o[13]) );
  aoi22s1 U146 ( .DIN1(s_dat_i[45]), .DIN2(n13), .DIN3(s_dat_i[13]), .DIN4(n2), 
        .Q(n45) );
  hi1s1 U147 ( .DIN(n46), .Q(m_dat_o[12]) );
  aoi22s1 U148 ( .DIN1(s_dat_i[44]), .DIN2(n13), .DIN3(s_dat_i[12]), .DIN4(n2), 
        .Q(n46) );
  hi1s1 U149 ( .DIN(n47), .Q(m_dat_o[11]) );
  aoi22s1 U150 ( .DIN1(s_dat_i[43]), .DIN2(n13), .DIN3(s_dat_i[11]), .DIN4(n2), 
        .Q(n47) );
  hi1s1 U151 ( .DIN(n48), .Q(m_dat_o[10]) );
  aoi22s1 U152 ( .DIN1(s_dat_i[42]), .DIN2(n13), .DIN3(s_dat_i[10]), .DIN4(n2), 
        .Q(n48) );
  hi1s1 U153 ( .DIN(n49), .Q(m_dat_o[0]) );
  aoi22s1 U154 ( .DIN1(s_dat_i[32]), .DIN2(n13), .DIN3(s_dat_i[0]), .DIN4(n2), 
        .Q(n49) );
  hi1s1 U155 ( .DIN(n50), .Q(m_ack_o[0]) );
  aoi22s1 U156 ( .DIN1(s_ack_i[1]), .DIN2(n13), .DIN3(s_ack_i[0]), .DIN4(n14), 
        .Q(n50) );
  hi1s1 U157 ( .DIN(n10), .Q(n14) );
  nnd2s1 U158 ( .DIN1(n3), .DIN2(n6), .Q(n10) );
  nnd2s1 U159 ( .DIN1(s_adr_o[60]), .DIN2(n51), .Q(n8) );
  oai13s1 U160 ( .DIN2(m_adr_i[29]), .DIN3(m_adr_i[31]), .DIN4(m_adr_i[30]), 
        .DIN1(n4), .Q(n51) );
  hi1s1 U161 ( .DIN(n52), .Q(s_adr_o[60]) );
  nnd2s1 U162 ( .DIN1(m_adr_i[28]), .DIN2(n5), .Q(n52) );
  nnd2s1 U163 ( .DIN1(\u_mux/arb_grant[0] ), .DIN2(n53), .Q(n17) );
  hi1s1 U164 ( .DIN(n53), .Q(bus_hold_ack) );
  oai21s1 U165 ( .DIN1(n11), .DIN2(n54), .DIN3(bus_hold), .Q(n53) );
  hi1s1 U166 ( .DIN(m_cyc_i[0]), .Q(n11) );
endmodule

