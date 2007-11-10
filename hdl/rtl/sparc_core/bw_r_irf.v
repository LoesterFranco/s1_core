// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T1 Processor File: bw_r_irf.v
// Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
// 
// The above named program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
// 
// The above named program is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
// 
// You should have received a copy of the GNU General Public
// License along with this work; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
// 
// ========== Copyright Header End ============================================
////////////////////////////////////////////////////////////////////////
/*
//  Module Name: bw_r_irf
//	Description: Register file with 3 read ports and 2 write ports.  Has 
//				32 registers per thread with 4 threads.  Reading and writing
//				the same register concurrently produces x.
*/

//FPGA_SYN enables all FPGA related modifications
 






module bw_r_irf (/*AUTOARG*/
   // Outputs
   so, irf_byp_rs1_data_d_l, irf_byp_rs2_data_d_l, 
   irf_byp_rs3_data_d_l, irf_byp_rs3h_data_d_l, 
   // Inputs
   rclk, reset_l, si, se, sehold, rst_tri_en, ifu_exu_tid_s2, 
   ifu_exu_rs1_s, ifu_exu_rs2_s, ifu_exu_rs3_s, ifu_exu_ren1_s, 
   ifu_exu_ren2_s, ifu_exu_ren3_s, ecl_irf_wen_w, ecl_irf_wen_w2, 
   ecl_irf_rd_m, ecl_irf_rd_g, byp_irf_rd_data_w, byp_irf_rd_data_w2, 
   ecl_irf_tid_m, ecl_irf_tid_g, rml_irf_old_lo_cwp_e, 
   rml_irf_new_lo_cwp_e, rml_irf_old_e_cwp_e, rml_irf_new_e_cwp_e, 
   rml_irf_swap_even_e, rml_irf_swap_odd_e, rml_irf_swap_local_e, 
   rml_irf_kill_restore_w, rml_irf_cwpswap_tid_e, rml_irf_old_agp, 
   rml_irf_new_agp, rml_irf_swap_global, rml_irf_global_tid
   ) ;
   input rclk;
   input reset_l;
   input si;
   input se;
   input sehold;
   input rst_tri_en;
   input [1:0]  ifu_exu_tid_s2;  // s stage thread
   input [4:0]  ifu_exu_rs1_s;  // source addresses
   input [4:0]  ifu_exu_rs2_s;
   input [4:0]  ifu_exu_rs3_s;
   input ifu_exu_ren1_s;        // read enables for all 3 ports
   input ifu_exu_ren2_s;
   input ifu_exu_ren3_s;
   input ecl_irf_wen_w;        // write enables for both write ports
   input ecl_irf_wen_w2;
   input [4:0]  ecl_irf_rd_m;   // w destination
   input [4:0]  ecl_irf_rd_g;  // w2 destination
   input [71:0] byp_irf_rd_data_w;// write data from w1
   input [71:0] byp_irf_rd_data_w2;     // write data from w2
   input [1:0]  ecl_irf_tid_m;  // w stage thread
   input [1:0]  ecl_irf_tid_g; // w2 thread

   input [2:0]  rml_irf_old_lo_cwp_e;  // current window pointer for locals and odds
   input [2:0]  rml_irf_new_lo_cwp_e;  // target window pointer for locals and odds
   input [2:1]  rml_irf_old_e_cwp_e;  // current window pointer for evens
   input [2:1]  rml_irf_new_e_cwp_e;  // target window pointer for evens
   input        rml_irf_swap_even_e;
   input        rml_irf_swap_odd_e;
   input        rml_irf_swap_local_e;
   input        rml_irf_kill_restore_w;
   input [1:0]  rml_irf_cwpswap_tid_e;

   input [1:0]  rml_irf_old_agp; // alternate global pointer
   input [1:0]  rml_irf_new_agp; // alternate global pointer
   input        rml_irf_swap_global;
   input [1:0]  rml_irf_global_tid;
   
   output       so;
   output [71:0] irf_byp_rs1_data_d_l;
   output [71:0] irf_byp_rs2_data_d_l;
   output [71:0] irf_byp_rs3_data_d_l;
   output [31:0] irf_byp_rs3h_data_d_l;

   wire [71:0] irf_byp_rs1_data_d;
   wire [71:0] irf_byp_rs2_data_d;
   wire [71:0] irf_byp_rs3_data_d;
   wire [71:0] irf_byp_rs3h_data_d;

   wire [1:0]  ecl_irf_tid_w;  // w stage thread
   wire [1:0]  ecl_irf_tid_w2; // w2 thread
   wire [4:0]  ecl_irf_rd_w;   // w destination
   wire [4:0]  ecl_irf_rd_w2;  // w2 destination
   wire [1:0]  ifu_exu_thr_d;  // d stage thread
   wire ifu_exu_ren1_d;        // read enables for all 3 ports
   wire ifu_exu_ren2_d;
   wire ifu_exu_ren3_d;
   wire [4:0]  ifu_exu_rs1_d;  // source addresses
   wire [4:0]  ifu_exu_rs2_d;
   wire [4:0]  ifu_exu_rs3_d;
   wire [6:0]    thr_rs1;       // these 5 are a combination of the thr and reg
   wire [6:0]    thr_rs2;       // so that comparison can be done more easily
   wire [6:0]    thr_rs3;
   wire [6:0]    thr_rs3h;
   wire [6:0]    thr_rd_w;
   wire [6:0]    thr_rd_w2;

   reg [1:0] cwpswap_tid_m;
   reg [1:0] cwpswap_tid_w;
   reg [2:0] old_lo_cwp_m;
   reg [2:0] new_lo_cwp_m;
   reg [2:0] new_lo_cwp_w;
   reg [1:0] old_e_cwp_m;
   reg [1:0] new_e_cwp_m;
   reg [1:0] new_e_cwp_w;
   reg       swap_local_m;
   reg       swap_local_w;
   reg       swap_even_m;
   reg       swap_even_w;
   reg       swap_odd_m;
   reg       swap_odd_w;
   reg       kill_restore_d1;
   reg        swap_global_d1;
   reg        swap_global_d2;
   reg [1:0]  global_tid_d1;
   reg [1:0]  global_tid_d2;
   reg [1:0] old_agp_d1,
             new_agp_d1,
             new_agp_d2;










   reg [71:0] active_win_thr_rd_w_neg;
   reg [71:0] active_win_thr_rd_w2_neg;
   reg [6:0]  thr_rd_w_neg;
   reg [6:0]  thr_rd_w2_neg;
   reg        active_win_thr_rd_w_neg_wr_en;
   reg        active_win_thr_rd_w2_neg_wr_en;
   reg        rst_tri_en_neg;

   
   wire          se;
   wire          clk;
//   assign        clk = rclk & reset_l;
   assign 	 clk = rclk;
   
   wire          ren1_s;
   wire          ren2_s;
   wire          ren3_s;
   wire [4:0]    rs1_s;
   wire [4:0]    rs2_s;
   wire [4:0]    rs3_s;
   wire [1:0]    tid_s;
   wire [1:0]    tid_g;
   wire [1:0]    tid_m;
   wire [4:0]    rd_m;
   wire [4:0]    rd_g;
   wire          kill_restore_w;
   wire          swap_global_d1_vld;
   wire          swap_local_m_vld;
   wire          swap_even_m_vld;
   wire          swap_odd_m_vld;

   assign {ren1_s,ren2_s,ren3_s,rs1_s[4:0],rs2_s[4:0],rs3_s[4:0],tid_s[1:0],tid_g[1:0],tid_m[1:0],
           rd_m[4:0], rd_g[4:0]} = (sehold)?
          {ifu_exu_ren1_d,ifu_exu_ren2_d,ifu_exu_ren3_d,ifu_exu_rs1_d[4:0],ifu_exu_rs2_d[4:0],
           ifu_exu_rs3_d[4:0],ifu_exu_thr_d[1:0],ecl_irf_tid_w2[1:0],ecl_irf_tid_w[1:0],
           ecl_irf_rd_w[4:0],ecl_irf_rd_w2[4:0]}:
          {ifu_exu_ren1_s,ifu_exu_ren2_s,ifu_exu_ren3_s,ifu_exu_rs1_s[4:0],ifu_exu_rs2_s[4:0],
           ifu_exu_rs3_s[4:0],ifu_exu_tid_s2[1:0],ecl_irf_tid_g[1:0],ecl_irf_tid_m[1:0],
           ecl_irf_rd_m[4:0],ecl_irf_rd_g[4:0]};
   // Pipeline flops for irf control signals
   dff dff_ren1_s2d(.din(ren1_s), .clk(clk), .q(ifu_exu_ren1_d), .se(se),
                    .si(), .so());
   dff dff_ren2_s2d(.din(ren2_s), .clk(clk), .q(ifu_exu_ren2_d), .se(se),
                    .si(), .so());
   dff dff_ren3_s2d(.din(ren3_s), .clk(clk), .q(ifu_exu_ren3_d), .se(se),
                    .si(), .so());
   dff #5 dff_rs1_s2d(.din(rs1_s[4:0]), .clk(clk), .q(ifu_exu_rs1_d[4:0]), .se(se),
                      .si(),.so());
   dff #5 dff_rs2_s2d(.din(rs2_s[4:0]), .clk(clk), .q(ifu_exu_rs2_d[4:0]), .se(se),
                      .si(),.so());
   dff #5 dff_rs3_s2d(.din(rs3_s[4:0]), .clk(clk), .q(ifu_exu_rs3_d[4:0]), .se(se),
                      .si(),.so());
   dff #2 dff_thr_s2d(.din(tid_s[1:0]), .clk(clk), .q(ifu_exu_thr_d[1:0]), .se(se),
                      .si(),.so());
   dff #2 dff_thr_g2w2(.din(tid_g[1:0]), .clk(clk), .q(ecl_irf_tid_w2[1:0]), .se(se),
                      .si(),.so());
   dff #2 dff_thr_m2w(.din(tid_m[1:0]), .clk(clk), .q(ecl_irf_tid_w[1:0]), .se(se),
                      .si(),.so());
   dff #5 dff_rd_m2w(.din(rd_m[4:0]), .clk(clk), .q(ecl_irf_rd_w[4:0]), .se(se),
                      .si(),.so());
   dff #5 dff_rd_g2w2(.din(rd_g[4:0]), .clk(clk), .q(ecl_irf_rd_w2[4:0]), .se(se),
                      .si(),.so());
   
   // Concatenate the thread and rs1/rd bits together
   assign        thr_rs1[6:0] = {ifu_exu_thr_d, ifu_exu_rs1_d};
   assign        thr_rs2[6:0] = {ifu_exu_thr_d, ifu_exu_rs2_d};
   assign        thr_rs3[6:0] = {ifu_exu_thr_d, ifu_exu_rs3_d[4:0]};
   assign        thr_rs3h[6:0] = {ifu_exu_thr_d[1:0], ifu_exu_rs3_d[4:1], 1'b1};
   assign        thr_rd_w[6:0] = {ecl_irf_tid_w, ecl_irf_rd_w};
   assign        thr_rd_w2[6:0] = {ecl_irf_tid_w2, ecl_irf_rd_w2};

   // Active low outputs
   assign        irf_byp_rs1_data_d_l[71:0] = ~irf_byp_rs1_data_d[71:0];
   assign        irf_byp_rs2_data_d_l[71:0] = ~irf_byp_rs2_data_d[71:0];
   assign        irf_byp_rs3_data_d_l[71:0] = ~irf_byp_rs3_data_d[71:0]; 
   assign        irf_byp_rs3h_data_d_l[31:0] = ~irf_byp_rs3h_data_d[31:0];
   
/////////////////////////////////////////////////////////////////
///  Write ports
////////////////////////////////////////////////////////////////
   // This is a latch that works if both wen is high and clk is low











   always @(negedge clk) begin
      rst_tri_en_neg <= rst_tri_en;
      // write conflict results in X written to destination
      if (ecl_irf_wen_w & ecl_irf_wen_w2 & (thr_rd_w[6:0] == thr_rd_w2[6:0])) begin
         active_win_thr_rd_w_neg <= {72{1'bx}};
         thr_rd_w_neg <= thr_rd_w;
         active_win_thr_rd_w_neg_wr_en <= 1'b1;
         active_win_thr_rd_w2_neg_wr_en <= 1'b0;
      end
      else begin
         // W1 write port
         if (ecl_irf_wen_w & (thr_rd_w[4:0] != 5'b0)) begin
            active_win_thr_rd_w_neg <= byp_irf_rd_data_w;
            thr_rd_w_neg <= thr_rd_w;
            active_win_thr_rd_w_neg_wr_en <= 1'b1;
         end
         else
           active_win_thr_rd_w_neg_wr_en <= 1'b0;
         
         // W2 write port
         if (ecl_irf_wen_w2 & (thr_rd_w2[4:0] != 5'b0)) begin
            active_win_thr_rd_w2_neg <= byp_irf_rd_data_w2;
            thr_rd_w2_neg <= thr_rd_w2;
            active_win_thr_rd_w2_neg_wr_en <= 1'b1;
         end
         else
           active_win_thr_rd_w2_neg_wr_en <= 1'b0;
      end
   end


   


/* MOVED TO CMP ENVIRONMENT
   initial begin
      // Hardcode R0 to zero
      active_window[{2'b00, 5'b00000}] = 72'b0;
      active_window[{2'b01, 5'b00000}] = 72'b0;
      active_window[{2'b10, 5'b00000}] = 72'b0;
      active_window[{2'b11, 5'b00000}] = 72'b0;
   end
*/
   //////////////////////////////////////////////////
   // Window management logic
   //////////////////////////////////////////////////
   // Pipeline flops for control signals

   // cwp swap signals
   assign kill_restore_w = (sehold)? kill_restore_d1: rml_irf_kill_restore_w;
   assign swap_local_m_vld = swap_local_m & ~rst_tri_en;
   assign swap_odd_m_vld = swap_odd_m & ~rst_tri_en;
   assign swap_even_m_vld = swap_even_m & ~rst_tri_en;
   assign swap_global_d1_vld = swap_global_d1 & ~rst_tri_en;
   
   always @ (posedge clk) begin
      cwpswap_tid_m[1:0] <= (sehold)? cwpswap_tid_m[1:0]: rml_irf_cwpswap_tid_e[1:0];
      cwpswap_tid_w[1:0] <= cwpswap_tid_m[1:0];
      old_lo_cwp_m[2:0] <= (sehold)? old_lo_cwp_m[2:0]: rml_irf_old_lo_cwp_e[2:0];
      new_lo_cwp_m[2:0] <= (sehold)? new_lo_cwp_m[2:0]: rml_irf_new_lo_cwp_e[2:0];
      new_lo_cwp_w[2:0] <= new_lo_cwp_m[2:0];
      old_e_cwp_m[1:0] <= (sehold)? old_e_cwp_m[1:0]: rml_irf_old_e_cwp_e[2:1];
      new_e_cwp_m[1:0] <= (sehold)? new_e_cwp_m[1:0]: rml_irf_new_e_cwp_e[2:1];
      new_e_cwp_w[1:0] <= new_e_cwp_m[1:0];
      swap_local_m <= (sehold)? swap_local_m & rst_tri_en: rml_irf_swap_local_e;
      swap_local_w <= swap_local_m_vld;
      swap_odd_m <= (sehold)? swap_odd_m & rst_tri_en: rml_irf_swap_odd_e;
      swap_odd_w <= swap_odd_m_vld;
      swap_even_m <= (sehold)? swap_even_m & rst_tri_en: rml_irf_swap_even_e;
      swap_even_w <= swap_even_m_vld;
      kill_restore_d1 <= kill_restore_w;
   end  
   // global swap signals    
   always @ (posedge clk) begin
      swap_global_d1 <= (sehold)? swap_global_d1 & rst_tri_en: rml_irf_swap_global;
      swap_global_d2 <= swap_global_d1_vld;
      global_tid_d1[1:0] <= (sehold)? global_tid_d1[1:0]: rml_irf_global_tid[1:0];
      global_tid_d2[1:0] <= global_tid_d1[1:0];
      old_agp_d1[1:0] <= (sehold)? old_agp_d1[1:0]: rml_irf_old_agp[1:0];
      new_agp_d1[1:0] <= (sehold)? new_agp_d1[1:0]: rml_irf_new_agp[1:0];
      new_agp_d2[1:0] <= new_agp_d1[1:0];
   end

  wire wr_en  = active_win_thr_rd_w_neg_wr_en & (~rst_tri_en | ~rst_tri_en_neg);
  wire wr_en2 = active_win_thr_rd_w2_neg_wr_en & (~rst_tri_en | ~rst_tri_en_neg);

// synopsys translate_off
  always @(posedge clk) begin
    if(wr_en) 
      $display("Write Port 1: %h %h", active_win_thr_rd_w_neg, thr_rd_w_neg );
    if(wr_en2) 
      $display("Write Port 2: %h %h", active_win_thr_rd_w2_neg, thr_rd_w2_neg );
    if(ifu_exu_ren1_d) begin
      @(posedge clk);
      $display("Read Port 1: %h %h", irf_byp_rs1_data_d, thr_rs1);
    end
    if(ifu_exu_ren2_d) begin
      @(posedge clk);
      $display("Read Port 2: %h %h", irf_byp_rs2_data_d, thr_rs2);
    end
    if(ifu_exu_ren3_d) begin
      @(posedge clk);
      $display("Read Port 3: %h %h", irf_byp_rs3_data_d, thr_rs3);
    end
  end
//synopsys translate_on
   
bw_r_irf_core bw_r_irf_core (
        .clk			(clk),
        .ifu_exu_ren1_d		(ifu_exu_ren1_d),
        .ifu_exu_ren2_d		(ifu_exu_ren2_d),
        .ifu_exu_ren3_d		(ifu_exu_ren3_d),
        .thr_rs1		(thr_rs1),
        .thr_rs2		(thr_rs2),
        .thr_rs3		(thr_rs3),
        .thr_rs3h		(thr_rs3h),
        .irf_byp_rs1_data_d	(irf_byp_rs1_data_d),
        .irf_byp_rs2_data_d	(irf_byp_rs2_data_d),
        .irf_byp_rs3_data_d	(irf_byp_rs3_data_d),
        .irf_byp_rs3h_data_d	(irf_byp_rs3h_data_d),
        .wr_en			(wr_en),
        .wr_en2			(wr_en2),
        .active_win_thr_rd_w_neg(active_win_thr_rd_w_neg),
        .active_win_thr_rd_w2_neg(active_win_thr_rd_w2_neg),
        .thr_rd_w_neg		(thr_rd_w_neg),
        .thr_rd_w2_neg		(thr_rd_w2_neg),
        .swap_global_d1_vld	(swap_global_d1_vld),
        .swap_global_d2		(swap_global_d2),
        .global_tid_d1		(global_tid_d1),
        .global_tid_d2		(global_tid_d2),
        .old_agp_d1		(old_agp_d1),
        .new_agp_d2		(new_agp_d2),
        .swap_local_m_vld	(swap_local_m_vld),
        .swap_local_w		(swap_local_w),
        .old_lo_cwp_m		(old_lo_cwp_m),
        .new_lo_cwp_w		(new_lo_cwp_w),
        .swap_even_m_vld	(swap_even_m_vld),
        .swap_even_w		(swap_even_w),
        .old_e_cwp_m		(old_e_cwp_m),
        .new_e_cwp_w		(new_e_cwp_w),
        .swap_odd_m_vld		(swap_odd_m_vld),
        .swap_odd_w		(swap_odd_w),
        .cwpswap_tid_m		(cwpswap_tid_m),
        .cwpswap_tid_w		(cwpswap_tid_w),
        .kill_restore_w		(kill_restore_w)
	);

endmodule // bw_r_irf

module bw_r_irf_core(
	clk,
	ifu_exu_ren1_d,
	ifu_exu_ren2_d,
	ifu_exu_ren3_d,
	thr_rs1,       
	thr_rs2,       
	thr_rs3,
	thr_rs3h,
	irf_byp_rs1_data_d,
	irf_byp_rs2_data_d,
	irf_byp_rs3_data_d,
	irf_byp_rs3h_data_d,
	wr_en,
	wr_en2,
	active_win_thr_rd_w_neg,
	active_win_thr_rd_w2_neg,
	thr_rd_w_neg,
	thr_rd_w2_neg,
	swap_global_d1_vld,
	swap_global_d2,
	global_tid_d1,
	global_tid_d2,
	old_agp_d1,
	new_agp_d2,
	swap_local_m_vld,
	swap_local_w,
	old_lo_cwp_m,
	new_lo_cwp_w,
	swap_even_m_vld,
	swap_even_w,
	old_e_cwp_m,
	new_e_cwp_w,
	swap_odd_m_vld,
	swap_odd_w,
	cwpswap_tid_m,
	cwpswap_tid_w,
	kill_restore_w);


	input		clk;
	input		ifu_exu_ren1_d;
	input		ifu_exu_ren2_d;
	input		ifu_exu_ren3_d;

	input	[6:0]	thr_rs1;       
	input	[6:0]	thr_rs2;       
	input	[6:0]	thr_rs3;
	input	[6:0]	thr_rs3h;

	output	[71:0]	irf_byp_rs1_data_d;
	output	[71:0]	irf_byp_rs2_data_d;
	output	[71:0]	irf_byp_rs3_data_d;
	output	[71:0]	irf_byp_rs3h_data_d;

	
	reg	[71:0]	irf_byp_rs1_data_d;
	reg	[71:0]	irf_byp_rs2_data_d;
	reg	[71:0]	irf_byp_rs3_data_d;
	reg	[71:0]	irf_byp_rs3h_data_d;

	input		wr_en;
	input		wr_en2;
	input	[71:0]	active_win_thr_rd_w_neg;
	input	[71:0]	active_win_thr_rd_w2_neg;
	input	[6:0]	thr_rd_w_neg;
	input	[6:0]	thr_rd_w2_neg;

	input		swap_global_d1_vld;
	input		swap_global_d2;
	input	[1:0]	global_tid_d1;
	input	[1:0]	global_tid_d2;
	input	[1:0]	old_agp_d1;
	input	[1:0]	new_agp_d2;

	input		swap_local_m_vld;
	input		swap_local_w;
	input	[2:0]	old_lo_cwp_m;
	input	[2:0]	new_lo_cwp_w;

	input		swap_even_m_vld;
	input		swap_even_w;
	input	[1:0]	old_e_cwp_m;
	input	[1:0]	new_e_cwp_w;

	input		swap_odd_m_vld;
	input		swap_odd_w;

	input	[1:0]	cwpswap_tid_m;
	input	[1:0]	cwpswap_tid_w;

   	input		kill_restore_w;


	wire	[71:0]	rd_data00;
	wire	[71:0]	rd_data01;
	wire	[71:0]	rd_data02;
	wire	[71:0]	rd_data03;
	wire	[71:0]	rd_data04;
	wire	[71:0]	rd_data05;
	wire	[71:0]	rd_data06;
	wire	[71:0]	rd_data07;
	wire	[71:0]	rd_data08;
	wire	[71:0]	rd_data09;
	wire	[71:0]	rd_data10;
	wire	[71:0]	rd_data11;
	wire	[71:0]	rd_data12;
	wire	[71:0]	rd_data13;
	wire	[71:0]	rd_data14;
	wire	[71:0]	rd_data15;
	wire	[71:0]	rd_data16;
	wire	[71:0]	rd_data17;
	wire	[71:0]	rd_data18;
	wire	[71:0]	rd_data19;
	wire	[71:0]	rd_data20;
	wire	[71:0]	rd_data21;
	wire	[71:0]	rd_data22;
	wire	[71:0]	rd_data23;
	wire	[71:0]	rd_data24;
	wire	[71:0]	rd_data25;
	wire	[71:0]	rd_data26;
	wire	[71:0]	rd_data27;
	wire	[71:0]	rd_data28;
	wire	[71:0]	rd_data29;
	wire	[71:0]	rd_data30;
	wire	[71:0]	rd_data31;

// synopsys translate_off
always @(posedge clk) begin
	if(ifu_exu_ren1_d | ifu_exu_ren2_d | ifu_exu_ren3_d) begin
		if(thr_rs1[6:5] != 2'b00) begin
			$display("Accessing thread # other than 0");
			$finish;	
		end
	end
end
// synopsys translate_on
   
   //reg [71:0]    active_window [127:0];// 32x4 72 bit registers

	always @(negedge clk) 
	  if(ifu_exu_ren1_d) //comes from a posedge clk
	  case(thr_rs1[4:0])
	    5'b00000: irf_byp_rs1_data_d <= rd_data00;
	    5'b00001: irf_byp_rs1_data_d <= rd_data01;
	    5'b00010: irf_byp_rs1_data_d <= rd_data02;
	    5'b00011: irf_byp_rs1_data_d <= rd_data03;
	    5'b00100: irf_byp_rs1_data_d <= rd_data04;
	    5'b00101: irf_byp_rs1_data_d <= rd_data05;
	    5'b00110: irf_byp_rs1_data_d <= rd_data06;
	    5'b00111: irf_byp_rs1_data_d <= rd_data07;
	    5'b01000: irf_byp_rs1_data_d <= rd_data08;
	    5'b01001: irf_byp_rs1_data_d <= rd_data09;
	    5'b01010: irf_byp_rs1_data_d <= rd_data10;
	    5'b01011: irf_byp_rs1_data_d <= rd_data11;
	    5'b01100: irf_byp_rs1_data_d <= rd_data12;
	    5'b01101: irf_byp_rs1_data_d <= rd_data13;
	    5'b01110: irf_byp_rs1_data_d <= rd_data14;
	    5'b01111: irf_byp_rs1_data_d <= rd_data15;
	    5'b10000: irf_byp_rs1_data_d <= rd_data16;
	    5'b10001: irf_byp_rs1_data_d <= rd_data17;
	    5'b10010: irf_byp_rs1_data_d <= rd_data18;
	    5'b10011: irf_byp_rs1_data_d <= rd_data19;
	    5'b10100: irf_byp_rs1_data_d <= rd_data20;
	    5'b10101: irf_byp_rs1_data_d <= rd_data21;
	    5'b10110: irf_byp_rs1_data_d <= rd_data22;
	    5'b10111: irf_byp_rs1_data_d <= rd_data23;
	    5'b11000: irf_byp_rs1_data_d <= rd_data24;
	    5'b11001: irf_byp_rs1_data_d <= rd_data25;
	    5'b11010: irf_byp_rs1_data_d <= rd_data26;
	    5'b11011: irf_byp_rs1_data_d <= rd_data27;
	    5'b11100: irf_byp_rs1_data_d <= rd_data28;
	    5'b11101: irf_byp_rs1_data_d <= rd_data29;
	    5'b11110: irf_byp_rs1_data_d <= rd_data30;
	    5'b11111: irf_byp_rs1_data_d <= rd_data31;
	  endcase

	always @(negedge clk) 
	  if(ifu_exu_ren2_d)
	  case(thr_rs2[4:0])
	    5'b00000: irf_byp_rs2_data_d <= rd_data00;
	    5'b00001: irf_byp_rs2_data_d <= rd_data01;
	    5'b00010: irf_byp_rs2_data_d <= rd_data02;
	    5'b00011: irf_byp_rs2_data_d <= rd_data03;
	    5'b00100: irf_byp_rs2_data_d <= rd_data04;
	    5'b00101: irf_byp_rs2_data_d <= rd_data05;
	    5'b00110: irf_byp_rs2_data_d <= rd_data06;
	    5'b00111: irf_byp_rs2_data_d <= rd_data07;
	    5'b01000: irf_byp_rs2_data_d <= rd_data08;
	    5'b01001: irf_byp_rs2_data_d <= rd_data09;
	    5'b01010: irf_byp_rs2_data_d <= rd_data10;
	    5'b01011: irf_byp_rs2_data_d <= rd_data11;
	    5'b01100: irf_byp_rs2_data_d <= rd_data12;
	    5'b01101: irf_byp_rs2_data_d <= rd_data13;
	    5'b01110: irf_byp_rs2_data_d <= rd_data14;
	    5'b01111: irf_byp_rs2_data_d <= rd_data15;
	    5'b10000: irf_byp_rs2_data_d <= rd_data16;
	    5'b10001: irf_byp_rs2_data_d <= rd_data17;
	    5'b10010: irf_byp_rs2_data_d <= rd_data18;
	    5'b10011: irf_byp_rs2_data_d <= rd_data19;
	    5'b10100: irf_byp_rs2_data_d <= rd_data20;
	    5'b10101: irf_byp_rs2_data_d <= rd_data21;
	    5'b10110: irf_byp_rs2_data_d <= rd_data22;
	    5'b10111: irf_byp_rs2_data_d <= rd_data23;
	    5'b11000: irf_byp_rs2_data_d <= rd_data24;
	    5'b11001: irf_byp_rs2_data_d <= rd_data25;
	    5'b11010: irf_byp_rs2_data_d <= rd_data26;
	    5'b11011: irf_byp_rs2_data_d <= rd_data27;
	    5'b11100: irf_byp_rs2_data_d <= rd_data28;
	    5'b11101: irf_byp_rs2_data_d <= rd_data29;
	    5'b11110: irf_byp_rs2_data_d <= rd_data30;
	    5'b11111: irf_byp_rs2_data_d <= rd_data31;
	  endcase

	always @(negedge clk) 
	  if(ifu_exu_ren3_d)
	  case(thr_rs3[4:0])
	    5'b00000: irf_byp_rs3_data_d <= rd_data00;
	    5'b00001: irf_byp_rs3_data_d <= rd_data01;
	    5'b00010: irf_byp_rs3_data_d <= rd_data02;
	    5'b00011: irf_byp_rs3_data_d <= rd_data03;
	    5'b00100: irf_byp_rs3_data_d <= rd_data04;
	    5'b00101: irf_byp_rs3_data_d <= rd_data05;
	    5'b00110: irf_byp_rs3_data_d <= rd_data06;
	    5'b00111: irf_byp_rs3_data_d <= rd_data07;
	    5'b01000: irf_byp_rs3_data_d <= rd_data08;
	    5'b01001: irf_byp_rs3_data_d <= rd_data09;
	    5'b01010: irf_byp_rs3_data_d <= rd_data10;
	    5'b01011: irf_byp_rs3_data_d <= rd_data11;
	    5'b01100: irf_byp_rs3_data_d <= rd_data12;
	    5'b01101: irf_byp_rs3_data_d <= rd_data13;
	    5'b01110: irf_byp_rs3_data_d <= rd_data14;
	    5'b01111: irf_byp_rs3_data_d <= rd_data15;
	    5'b10000: irf_byp_rs3_data_d <= rd_data16;
	    5'b10001: irf_byp_rs3_data_d <= rd_data17;
	    5'b10010: irf_byp_rs3_data_d <= rd_data18;
	    5'b10011: irf_byp_rs3_data_d <= rd_data19;
	    5'b10100: irf_byp_rs3_data_d <= rd_data20;
	    5'b10101: irf_byp_rs3_data_d <= rd_data21;
	    5'b10110: irf_byp_rs3_data_d <= rd_data22;
	    5'b10111: irf_byp_rs3_data_d <= rd_data23;
	    5'b11000: irf_byp_rs3_data_d <= rd_data24;
	    5'b11001: irf_byp_rs3_data_d <= rd_data25;
	    5'b11010: irf_byp_rs3_data_d <= rd_data26;
	    5'b11011: irf_byp_rs3_data_d <= rd_data27;
	    5'b11100: irf_byp_rs3_data_d <= rd_data28;
	    5'b11101: irf_byp_rs3_data_d <= rd_data29;
	    5'b11110: irf_byp_rs3_data_d <= rd_data30;
	    5'b11111: irf_byp_rs3_data_d <= rd_data31;
	  endcase

	always @(negedge clk) 
	  if(ifu_exu_ren3_d)
	  case(thr_rs3h[4:1])
	    4'b0000: irf_byp_rs3h_data_d <= rd_data01;
	    4'b0001: irf_byp_rs3h_data_d <= rd_data03;
	    4'b0010: irf_byp_rs3h_data_d <= rd_data05;
	    4'b0011: irf_byp_rs3h_data_d <= rd_data07;
	    4'b0100: irf_byp_rs3h_data_d <= rd_data09;
	    4'b0101: irf_byp_rs3h_data_d <= rd_data11;
	    4'b0110: irf_byp_rs3h_data_d <= rd_data13;
	    4'b0111: irf_byp_rs3h_data_d <= rd_data15;
	    4'b1000: irf_byp_rs3h_data_d <= rd_data17;
	    4'b1001: irf_byp_rs3h_data_d <= rd_data19;
	    4'b1010: irf_byp_rs3h_data_d <= rd_data21;
	    4'b1011: irf_byp_rs3h_data_d <= rd_data23;
	    4'b1100: irf_byp_rs3h_data_d <= rd_data25;
	    4'b1101: irf_byp_rs3h_data_d <= rd_data27;
	    4'b1110: irf_byp_rs3h_data_d <= rd_data29;
	    4'b1111: irf_byp_rs3h_data_d <= rd_data31;
	  endcase

wire wren = wr_en | wr_en2;
wire [4:0] wr_addr = wr_en ? thr_rd_w_neg[4:0] : thr_rd_w2_neg[4:0];
wire [71:0] wr_data = wr_en ? active_win_thr_rd_w_neg : active_win_thr_rd_w2_neg;

//GLOBALs
bw_r_irf_register register00(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00000)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(72'b0), 
		.rd_data(rd_data00)
);

bw_r_irf_register register01(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00001)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data01)
);

bw_r_irf_register register02(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00010)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data02)
);

bw_r_irf_register register03(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00011)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data03)
);

bw_r_irf_register register04(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00100)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data04)
);

bw_r_irf_register register05(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00101)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data05)
);

bw_r_irf_register register06(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00110)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data06)
);

bw_r_irf_register register07(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b00111)), 
		.save(swap_global_d1_vld),
		.save_addr({1'b0,old_agp_d1[1:0]}), 
		.restore(swap_global_d2), 
		.restore_addr({1'b0,new_agp_d2[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data07)
);

//ODDs
bw_r_irf_register register08(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01000)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data08)
);

bw_r_irf_register register09(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01001)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data09)
);

bw_r_irf_register register10(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01010)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data10)
);

bw_r_irf_register register11(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01011)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data11)
);

bw_r_irf_register register12(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01100)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data12)
);

bw_r_irf_register register13(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01101)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data13)
);

bw_r_irf_register register14(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01110)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data14)
);

bw_r_irf_register register15(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b01111)), 
		.save(swap_odd_m_vld),
		.save_addr({1'b0,old_lo_cwp_m[2:1]}), 
		.restore(swap_odd_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_lo_cwp_w[2:1]}),
		.wr_data(wr_data), 
		.rd_data(rd_data15)
);

//LOCALs
bw_r_irf_register register16(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10000)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data16)
);

bw_r_irf_register register17(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10001)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data17)
);

bw_r_irf_register register18(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10010)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data18)
);

bw_r_irf_register register19(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10011)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data19)
);

bw_r_irf_register register20(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10100)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data20)
);

bw_r_irf_register register21(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10101)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data21)
);

bw_r_irf_register register22(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10110)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data22)
);

bw_r_irf_register register23(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b10111)), 
		.save(swap_local_m_vld),
		.save_addr({old_lo_cwp_m[2:0]}), 
		.restore(swap_local_w & ~kill_restore_w), 
		.restore_addr({new_lo_cwp_w[2:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data23)
);

//EVENs
bw_r_irf_register register24(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11000)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data24)
);

bw_r_irf_register register25(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11001)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data25)
);

bw_r_irf_register register26(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11010)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data26)
);

bw_r_irf_register register27(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11011)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data27)
);

bw_r_irf_register register28(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11100)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data28)
);

bw_r_irf_register register29(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11101)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data29)
);

bw_r_irf_register register30(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11110)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data30)
);

bw_r_irf_register register31(
		.clk(clk),
		.wren(wren & (wr_addr == 5'b11111)), 
		.save(swap_even_m_vld),
		.save_addr({1'b0,old_e_cwp_m[1:0]}),
		.restore(swap_even_w & ~kill_restore_w), 
		.restore_addr({1'b0,new_e_cwp_w[1:0]}),
		.wr_data(wr_data), 
		.rd_data(rd_data31)
);

endmodule







































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































