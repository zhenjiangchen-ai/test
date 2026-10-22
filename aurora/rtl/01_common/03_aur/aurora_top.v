// =================================================================================================
// file name      : aurora_top.v
// module         : aurora_top
// function       : 13-lane aurora, one_to_mul and mul_to_one
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/08/12   lxl        create new              semigth
// 0.0.2        2026/09/14   lxl        match project style     semigth
// 0.0.3        2026/09/17   lxl        1to12 12to1 local ku    semigth
// 0.0.4        2026/09/18   lxl        sim hsp axis inject     semigth
// 0.0.5        2026/09/24   lxl        loc parse pack          semigth
// 0.0.6        2026/10/08   lxl        one/mul share module    semigth
// 0.0.7        2026/10/09   lxl        loc clk ila sts probe   semigth
// =================================================================================================

`include "../../00_define/define.v"
`include "../hsp_pkt_hdr.vh"

`timescale 1ns / 1ps

module aurora_top #(
    parameter p_aur_quad_num                    = 7                                             ,
    parameter p_aur_lane_num                    = 13                                            ,
    parameter p_aur_sub_num                     = 12
) (
`ifdef p_sim
    // sim aur axis, same as aur rx/tx
    output                                      o_001_aur_clk                                   , // aur user clk
    output                                      o_001_aur_rst                                   , // aur user rst
    // aur rx
    input      [                          63:0] i_064_sim_aur_rx_tdata                          ,
    input      [                           7:0] i_008_sim_aur_rx_tkeep                          ,
    input                                       i_001_sim_aur_rx_tlast                          ,
    input                                       i_001_sim_aur_rx_tvalid                         ,
    // aur tx
    output                                      o_001_sim_aur_tx_tvalid                         ,
    output     [                          63:0] o_064_sim_aur_tx_tdata                          ,
    output     [                           7:0] o_008_sim_aur_tx_tkeep                          ,
    output                                      o_001_sim_aur_tx_tlast                          ,
    input                                       i_001_sim_aur_tx_tready                         ,
    // status
    output     [            p_aur_lane_num-1:0] o_00n_chan_up                                   , // channel up
    output     [            p_aur_lane_num-1:0] o_00n_lane_up                                   , // lane up
`endif
    // init
    input                                       i_001_init_clk                                  , // init clock
    input                                       i_001_init_rst                                  , // init reset
    input                                       i_001_loc_clk                                   ,
    input                                       i_001_loc_rst                                   ,
    // pin
    input      [            p_aur_lane_num-1:0] i_00n_aur_rx_p                                  ,
    input      [            p_aur_lane_num-1:0] i_00n_aur_rx_n                                  ,
    output     [            p_aur_lane_num-1:0] o_00n_aur_tx_p                                  ,
    output     [            p_aur_lane_num-1:0] o_00n_aur_tx_n                                  ,
    input      [            p_aur_quad_num-1:0] i_00n_aur_clk_p                                 ,
    input      [            p_aur_quad_num-1:0] i_00n_aur_clk_n                                 ,
    output     [            p_aur_lane_num-1:0] o_00n_sts_chan_up                               ,
    output     [            p_aur_lane_num-1:0] o_00n_sts_lane_up                               ,
    // reg
    output                                      o_001_reg_wr_req                                ,
    input                                       i_001_reg_wr_ack                                ,
    output     [                          31:0] o_032_reg_wr_data                               ,
    output                                      o_001_reg_rd_req                                ,
    input                                       i_001_reg_rd_ack                                ,
    input      [                          31:0] i_032_reg_rd_data                               ,
    output     [                          31:0] o_032_reg_addr                                  ,
    input                                       i_001_reg_rdy                                   ,
    input                                       i_001_reg_fail                                  ,
    // ram
    output                                      o_001_ram_rd_req                                ,
    output     [                          23:0] o_024_ram_rd_addr                               ,
    output     [                          23:0] o_024_ram_rd_size                               ,
    output     [                          15:0] o_016_ram_rd_bsel                               ,
    output                                      o_001_ram_rd_rdy                                ,
    input                                       i_001_ram_cbuf_rdy                              ,
    input                                       i_001_ram_rd_sop                                ,
    input                                       i_001_ram_rd_eop                                ,
    input                                       i_001_ram_rd_dvld                               ,
    input      [                          63:0] i_064_ram_rd_data                               ,
    output                                      o_001_ram_wr_req                                ,
    output     [                          23:0] o_024_ram_wr_addr                               ,
    output     [                          23:0] o_024_ram_wr_size                               ,
    output     [                          15:0] o_016_ram_wr_bsel                               ,
    output     [                          63:0] o_064_ram_wr_data                               ,
    output                                      o_001_ram_wr_dvld                               ,
    output                                      o_001_ram_wr_sop                                ,
    output                                      o_001_ram_wr_eop                                ,
    input                                       i_001_ram_wr_fail
);

    // ********************************************************************************************
    // localparameter declare
    // ********************************************************************************************

    // =============================================================================
    // internal signal define
    // =============================================================================

    // aur clk rst

    wire       [            p_aur_lane_num-1:0] w_00n_aur_clk                                   ;
    wire       [            p_aur_lane_num-1:0] w_00n_aur_rst                                   ;

    // link

    wire       [            p_aur_lane_num-1:0] w_00n_chan_up                                   ;
    wire       [            p_aur_lane_num-1:0] w_00n_lane_up                                   ;

    // loc clk probe, ila

    (*mark_debug = "true"*) reg        [            p_aur_lane_num-1:0] r_00n_aur_rst                                   ;
    (*mark_debug = "true"*) reg        [            p_aur_lane_num-1:0] r_00n_chan_up                                   ;
    (*mark_debug = "true"*) reg        [            p_aur_lane_num-1:0] r_00n_lane_up                                   ;

    // xch tx

    wire       [         64*p_aur_lane_num-1:0] w_64n_xch_tx_tdata                              ;
    wire       [          8*p_aur_lane_num-1:0] w_08n_xch_tx_tkeep                              ;
    wire       [            p_aur_lane_num-1:0] w_01n_xch_tx_tlast                              ;
    wire       [            p_aur_lane_num-1:0] w_01n_xch_tx_tvalid                             ;
    wire       [            p_aur_lane_num-1:0] w_01n_xch_tx_tready                             ;

    // xch rx

    wire       [         64*p_aur_lane_num-1:0] w_64n_xch_rx_tdata                              ;
    wire       [          8*p_aur_lane_num-1:0] w_08n_xch_rx_tkeep                              ;
    wire       [            p_aur_lane_num-1:0] w_01n_xch_rx_tlast                              ;
    wire       [            p_aur_lane_num-1:0] w_01n_xch_rx_tvalid                             ;

    // nfc

    (*mark_debug = "true"*) wire       [            p_aur_lane_num-1:0] w_01n_nfc_tvalid                                ;
    (*mark_debug = "true"*) wire       [         16*p_aur_lane_num-1:0] w_16n_nfc_tdata                                 ;
    (*mark_debug = "true"*) wire       [            p_aur_lane_num-1:0] w_01n_nfc_tready                                ;

    // mul tx from one_to_mul

    wire       [          64*p_aur_sub_num-1:0] w_64n_mul_tx_tdata                              ;
    wire       [           8*p_aur_sub_num-1:0] w_08n_mul_tx_tkeep                              ;
    wire       [             p_aur_sub_num-1:0] w_01n_mul_tx_tlast                              ;
    wire       [             p_aur_sub_num-1:0] w_01n_mul_tx_tvalid                             ;
    wire       [             p_aur_sub_num-1:0] w_01n_mul_tx_tready                             ;

    // one rx to one_to_mul

    (*mark_debug = "true"*) wire       [                          63:0] w_064_one_rx_tdata                              ;
    (*mark_debug = "true"*) wire       [                           7:0] w_008_one_rx_tkeep                              ;
    (*mark_debug = "true"*) wire                                        w_001_one_rx_tlast                              ;
    (*mark_debug = "true"*) wire                                        w_001_one_rx_tvalid                             ;

    // one tx from mul_to_one

    (*mark_debug = "true"*) wire                                        w_001_one_tx_tvalid                             ;
    (*mark_debug = "true"*) wire       [                          63:0] w_064_one_tx_tdata                              ;
    (*mark_debug = "true"*) wire       [                           7:0] w_008_one_tx_tkeep                              ;
    (*mark_debug = "true"*) wire                                        w_001_one_tx_tlast                              ;
    (*mark_debug = "true"*) wire                                        w_001_one_tx_tready                             ;

    // mul rx to mul_to_one

    wire       [             64*p_aur_sub_num-1:0] w_64n_mul_rx_tdata                              ;
    wire       [              8*p_aur_sub_num-1:0] w_08n_mul_rx_tkeep                              ;
    wire       [                p_aur_sub_num-1:0] w_01n_mul_rx_tlast                              ;
    wire       [                p_aur_sub_num-1:0] w_01n_mul_rx_tvalid                             ;

    // loc rx, later local logic, init clk

    (*mark_debug = "true"*) wire                                        w_001_loc_rx_tvalid                             ;
    (*mark_debug = "true"*) wire       [                          63:0] w_064_loc_rx_tdata                              ;
    (*mark_debug = "true"*) wire       [                           7:0] w_008_loc_rx_tkeep                              ;
    (*mark_debug = "true"*) wire                                        w_001_loc_rx_tlast                              ;
    (*mark_debug = "true"*) wire                                        w_001_loc_rx_tready                             ;
    (*mark_debug = "true"*) wire                                        w_001_loc_tx_tvalid                             ;
    (*mark_debug = "true"*) wire       [                          63:0] w_064_loc_tx_tdata                              ;
    (*mark_debug = "true"*) wire       [                           7:0] w_008_loc_tx_tkeep                              ;
    (*mark_debug = "true"*) wire                                        w_001_loc_tx_tlast                              ;
    (*mark_debug = "true"*) wire                                        w_001_loc_tx_tready                             ;

    // loc sop
    wire                                        w_001_aur_rx_rdy                                ;
    wire                                        w_001_aur_rx_sop                                ;
    wire                                        w_001_aur_rx_eop                                ;
    wire                                        w_001_aur_rx_dvld                               ;
    wire       [                          63:0] w_064_aur_rx_data                               ;
    wire                                        w_001_aur_tx_rdy                                ;
    wire                                        w_001_aur_tx_sop                                ;
    wire                                        w_001_aur_tx_eop                                ;
    wire                                        w_001_aur_tx_dvld                               ;
    wire       [                          63:0] w_064_aur_tx_data                               ;

    // reg rsp
    wire                                        w_001_reg_rcp_req                               ;
    wire                                        w_001_reg_rcp_ack                               ;
    wire       [                          15:0] w_016_reg_rcp_qid                               ;
    wire       [                          15:0] w_016_reg_rcp_dst                               ;
    wire       [                          15:0] w_016_reg_rcp_src                               ;
    wire       [                          15:0] w_016_reg_rcp_ackn                              ;
    wire       [                          15:0] w_016_reg_rcp_msg                               ;
    wire       [                          31:0] w_032_reg_rcp_addr                              ;
    wire       [                          31:0] w_032_reg_rcp_data                              ;
    wire                                        w_001_reg_rcp_multi                             ;
    wire       [                          15:0] w_016_reg_rcp_nbeat                             ;
    wire       [                          63:0] w_064_reg_rcp_beat                              ;
    wire                                        w_001_reg_rcp_beat_re                           ;

    // ram rsp
    wire                                        w_001_ram_rcp_req                               ;
    wire                                        w_001_ram_rcp_ack                               ;
    wire       [                          15:0] w_016_ram_rcp_qid                               ;
    wire       [                          15:0] w_016_ram_rcp_dst                               ;
    wire       [                          15:0] w_016_ram_rcp_src                               ;
    wire       [                          15:0] w_016_ram_rcp_ackn                              ;
    wire       [                          15:0] w_016_ram_rcp_msg                               ;
    wire       [                          15:0] w_016_ram_rcp_cs                                ;
    wire       [                          23:0] w_024_ram_rcp_addr                              ;
    wire       [                          23:0] w_024_ram_rcp_len                               ;
    wire                                        w_001_ram_rcp_rd                                ;
    wire                                        w_001_ram_rcp_fail                              ;

    // ddr rsp
    wire                                        w_001_ddr_rcp_req                               ;
    wire                                        w_001_ddr_rcp_ack                               ;
    wire       [                          15:0] w_016_ddr_rcp_qid                               ;
    wire       [                          15:0] w_016_ddr_rcp_dst                               ;
    wire       [                          15:0] w_016_ddr_rcp_src                               ;
    wire       [                          15:0] w_016_ddr_rcp_ackn                              ;
    wire       [                          15:0] w_016_ddr_rcp_msg                               ;
    wire                                        w_001_ddr_rcp_fail                              ;

    // tx arbit, 3 ch
    wire       [                           2:0] w_003_chi_req                                   ;
    wire       [                           2:0] w_003_chi_ack                                   ;
    wire       [                           2:0] w_003_chi_rdy                                   ;
    wire       [                           2:0] w_003_chi_sop                                   ;
    wire       [                           2:0] w_003_chi_eop                                   ;
    wire       [                           2:0] w_003_chi_dvld                                  ;
    wire       [                         191:0] w_192_chi_data                                  ;

`ifdef p_sim
    // sim aur rx, 1 beat

    reg        [                          63:0] r_064_sim_aur_rx_tdata                          ;
    reg        [                           7:0] r_008_sim_aur_rx_tkeep                          ;
    reg                                         r_001_sim_aur_rx_tlast                          ;
    reg                                         r_001_sim_aur_rx_tvalid                         ;
`endif

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_00n_sts_chan_up                    = w_00n_chan_up                                 ;
    assign o_00n_sts_lane_up                    = w_00n_lane_up                                 ;

    always @(posedge i_001_loc_clk) begin
        r_00n_aur_rst                           <= w_00n_aur_rst                                ;
        r_00n_chan_up                           <= w_00n_chan_up                                ;
        r_00n_lane_up                           <= w_00n_lane_up                                ;
    end

    // mul-lane aurora phy ; p_sim skip gt, use loc clk as user clk

`ifndef p_sim
    aurora_xch #(
        .p_aur_quad_num                         (p_aur_quad_num                                 ),
        .p_aur_lane_num                         (p_aur_lane_num                                 )
    ) u00_aurora_xch (
        // init
        .i_001_init_clk                         (i_001_init_clk                                 ),
        .i_001_init_rst                         (i_001_init_rst                                 ),
        // aur clk rst
        .o_00n_aur_clk                          (w_00n_aur_clk                                  ),
        .o_00n_aur_rst                          (w_00n_aur_rst                                  ),
        // link
        .o_00n_chan_up                          (w_00n_chan_up                                  ),
        .o_00n_lane_up                          (w_00n_lane_up                                  ),
        // tx data
        .i_64n_axis_tx_tdata                    (w_64n_xch_tx_tdata                             ),
        .i_08n_axis_tx_tkeep                    (w_08n_xch_tx_tkeep                             ),
        .i_01n_axis_tx_tlast                    (w_01n_xch_tx_tlast                             ),
        .i_01n_axis_tx_tvalid                   (w_01n_xch_tx_tvalid                            ),
        .o_01n_axis_tx_tready                   (w_01n_xch_tx_tready                            ),
        // rx data
        .o_64n_axis_rx_tdata                    (w_64n_xch_rx_tdata                             ),
        .o_08n_axis_rx_tkeep                    (w_08n_xch_rx_tkeep                             ),
        .o_01n_axis_rx_tlast                    (w_01n_xch_rx_tlast                             ),
        .o_01n_axis_rx_tvalid                   (w_01n_xch_rx_tvalid                            ),
        // nfc
        .i_01n_axi_nfc_tvalid                   (w_01n_nfc_tvalid                               ),
        .i_16n_axi_nfc_tdata                    (w_16n_nfc_tdata                                ),
        .o_01n_axi_nfc_tready                   (w_01n_nfc_tready                               ),
        // pin
        .i_00n_aur_rx_p                         (i_00n_aur_rx_p                                 ),
        .i_00n_aur_rx_n                         (i_00n_aur_rx_n                                 ),
        .o_00n_aur_tx_p                         (o_00n_aur_tx_p                                 ),
        .o_00n_aur_tx_n                         (o_00n_aur_tx_n                                 ),
        // ref clk
        .i_00n_aur_clk_p                        (i_00n_aur_clk_p                                ),
        .i_00n_aur_clk_n                        (i_00n_aur_clk_n                                )
    );
`else
    assign w_00n_aur_clk                        = {p_aur_lane_num{i_001_loc_clk}}               ;
    assign w_00n_aur_rst                        = {p_aur_lane_num{i_001_loc_rst}}               ;
    assign w_00n_chan_up                        = {p_aur_lane_num{1'b1}}                        ;
    assign w_00n_lane_up                        = {p_aur_lane_num{1'b1}}                        ;
    assign w_01n_xch_tx_tready                  = {p_aur_lane_num{1'b1}}                        ;
    assign w_64n_xch_rx_tdata                   = {64*p_aur_lane_num{1'b0}}                     ;
    assign w_08n_xch_rx_tkeep                   = { 8*p_aur_lane_num{1'b0}}                     ;
    assign w_01n_xch_rx_tlast                   = {p_aur_lane_num{1'b0}}                        ;
    assign w_01n_xch_rx_tvalid                  = {p_aur_lane_num{1'b0}}                        ;
    assign w_01n_nfc_tready                     = {p_aur_lane_num{1'b1}}                        ;
    assign o_00n_aur_tx_p                       = {p_aur_lane_num{1'b0}}                        ;
    assign o_00n_aur_tx_n                       = {p_aur_lane_num{1'b0}}                        ;
`endif

`ifdef p_sim
    always @(posedge w_00n_aur_clk[0]) begin
        if (w_00n_aur_rst[0])
            r_001_sim_aur_rx_tvalid             <= 1'b0                                         ;
        else
            r_001_sim_aur_rx_tvalid             <= i_001_sim_aur_rx_tvalid                      ;
    end

    always @(posedge w_00n_aur_clk[0]) begin
        if (i_001_sim_aur_rx_tvalid) begin
            r_064_sim_aur_rx_tdata              <= i_064_sim_aur_rx_tdata                       ;
            r_008_sim_aur_rx_tkeep              <= i_008_sim_aur_rx_tkeep                       ;
            r_001_sim_aur_rx_tlast              <= i_001_sim_aur_rx_tlast                       ;
        end
    end

    assign w_064_one_rx_tdata                   = r_064_sim_aur_rx_tdata                        ;
    assign w_008_one_rx_tkeep                   = r_008_sim_aur_rx_tkeep                        ;
    assign w_001_one_rx_tlast                   = r_001_sim_aur_rx_tlast                        ;
    assign w_001_one_rx_tvalid                  = r_001_sim_aur_rx_tvalid                       ;
    assign w_001_one_tx_tready                  = i_001_sim_aur_tx_tready                       ;

    assign o_001_aur_clk                        = w_00n_aur_clk[0]                              ;
    assign o_001_aur_rst                        = w_00n_aur_rst[0]                              ;
    assign o_001_sim_aur_tx_tvalid              = w_001_one_tx_tvalid                           ;
    assign o_064_sim_aur_tx_tdata               = w_064_one_tx_tdata                            ;
    assign o_008_sim_aur_tx_tkeep               = w_008_one_tx_tkeep                            ;
    assign o_001_sim_aur_tx_tlast               = w_001_one_tx_tlast                            ;
    assign o_00n_chan_up                        = w_00n_chan_up                                 ;
    assign o_00n_lane_up                        = w_00n_lane_up                                 ;

    assign w_64n_mul_rx_tdata                   = w_64n_xch_rx_tdata [64*p_aur_lane_num-1:64]   ;
    assign w_08n_mul_rx_tkeep                   = w_08n_xch_rx_tkeep [ 8*p_aur_lane_num-1: 8]   ;
    assign w_01n_mul_rx_tlast                   = w_01n_xch_rx_tlast [   p_aur_lane_num-1: 1]   ;
    assign w_01n_mul_rx_tvalid                  = w_01n_xch_rx_tvalid[   p_aur_lane_num-1: 1]   ;
`else
    assign w_064_one_rx_tdata                   = w_64n_xch_rx_tdata [63:0]                     ;
    assign w_008_one_rx_tkeep                   = w_08n_xch_rx_tkeep [ 7:0]                     ;
    assign w_001_one_rx_tlast                   = w_01n_xch_rx_tlast [   0]                     ;
    assign w_001_one_rx_tvalid                  = w_01n_xch_rx_tvalid[   0]                     ;
    assign w_001_one_tx_tready                  = w_01n_xch_tx_tready[   0]                     ;
    assign w_64n_mul_rx_tdata                   = w_64n_xch_rx_tdata [64*p_aur_lane_num-1:64]   ;
    assign w_08n_mul_rx_tkeep                   = w_08n_xch_rx_tkeep [ 8*p_aur_lane_num-1: 8]   ;
    assign w_01n_mul_rx_tlast                   = w_01n_xch_rx_tlast [   p_aur_lane_num-1: 1]   ;
    assign w_01n_mul_rx_tvalid                  = w_01n_xch_rx_tvalid[   p_aur_lane_num-1: 1]   ;
`endif

    // one rx -> n mul tx, dest slot 0x1-0xc; loc slot 0xf to loc fifo

    aur_one_to_mul #(
        .p_aur_sub_num                          (p_aur_sub_num                                  ),
        .p_loc_id                               (`p_slot_loc                                    ),
        .p_mul_id_min                           (4'h1                                           ),
        .p_dst_id_lsb                           (`hsp_hdr_dst_slot_lsb                          ),
        .p_dst_id_w                             (`hsp_hdr_dst_slot_w                            )
    ) u01_aur_one_to_mul (
        // one clk rst
        .i_001_one_clk                          (w_00n_aur_clk               [                0]),
        .i_001_one_rst                          (w_00n_aur_rst               [                0]),
        // loc clk rst
        .i_001_loc_clk                          (i_001_loc_clk                                  ),
        .i_001_loc_rst                          (i_001_loc_rst                                  ),
        // mul clk
        .i_00n_mul_clk                          (w_00n_aur_clk               [     p_aur_sub_num:1]),
        // one rx
        .i_064_one_rx_tdata                     (w_064_one_rx_tdata                             ),
        .i_008_one_rx_tkeep                     (w_008_one_rx_tkeep                             ),
        .i_001_one_rx_tlast                     (w_001_one_rx_tlast                             ),
        .i_001_one_rx_tvalid                    (w_001_one_rx_tvalid                            ),
        // one nfc
        .o_001_one_nfc_tvalid                   (w_01n_nfc_tvalid            [                0]),
        .o_016_one_nfc_tdata                    (w_16n_nfc_tdata             [             15:0]),
        .i_001_one_nfc_tready                   (w_01n_nfc_tready            [                0]),
        // mul tx
        .o_64n_mul_tx_tdata                     (w_64n_mul_tx_tdata                             ),
        .o_08n_mul_tx_tkeep                     (w_08n_mul_tx_tkeep                             ),
        .o_01n_mul_tx_tlast                     (w_01n_mul_tx_tlast                             ),
        .o_01n_mul_tx_tvalid                    (w_01n_mul_tx_tvalid                            ),
        .i_01n_mul_tx_tready                    (w_01n_mul_tx_tready                            ),
        // loc rx, later local logic, hang
        .o_001_loc_rx_tvalid                    (w_001_loc_rx_tvalid                            ),
        .o_064_loc_rx_tdata                     (w_064_loc_rx_tdata                             ),
        .o_008_loc_rx_tkeep                     (w_008_loc_rx_tkeep                             ),
        .o_001_loc_rx_tlast                     (w_001_loc_rx_tlast                             ),
        .i_001_loc_rx_tready                    (w_001_loc_rx_tready                            )
    );

    // n mul rx -> one tx, round robin per frame

    aur_mul_to_one #(
        .p_aur_sub_num                          (p_aur_sub_num                                  )
    ) u02_aur_mul_to_one (
        // one clk rst
        .i_001_one_clk                          (w_00n_aur_clk          [                     0]),
        .i_001_one_rst                          (w_00n_aur_rst          [                     0]),
        // loc clk rst
        .i_001_loc_clk                          (i_001_loc_clk                                  ),
        .i_001_loc_rst                          (i_001_loc_rst                                  ),
        // mul clk rst
        .i_00n_mul_clk                          (w_00n_aur_clk          [     p_aur_sub_num:1]     ),
        .i_00n_mul_rst                          (w_00n_aur_rst          [     p_aur_sub_num:1]     ),
        // mul rx
        .i_64n_mul_rx_tdata                     (w_64n_mul_rx_tdata                             ),
        .i_08n_mul_rx_tkeep                     (w_08n_mul_rx_tkeep                             ),
        .i_01n_mul_rx_tlast                     (w_01n_mul_rx_tlast                             ),
        .i_01n_mul_rx_tvalid                    (w_01n_mul_rx_tvalid                            ),
        // mul nfc
        .o_01n_mul_nfc_tvalid                   (w_01n_nfc_tvalid       [   p_aur_lane_num-1: 1]),
        .o_16n_mul_nfc_tdata                    (w_16n_nfc_tdata        [16*p_aur_lane_num-1:16]),
        .i_01n_mul_nfc_tready                   (w_01n_nfc_tready       [   p_aur_lane_num-1: 1]),
        // loc tx
        .i_001_loc_tx_tvalid                    (w_001_loc_tx_tvalid                            ),
        .i_064_loc_tx_tdata                     (w_064_loc_tx_tdata                             ),
        .i_008_loc_tx_tkeep                     (w_008_loc_tx_tkeep                             ),
        .i_001_loc_tx_tlast                     (w_001_loc_tx_tlast                             ),
        .o_001_loc_tx_tready                    (w_001_loc_tx_tready                            ),
        // one tx
        .o_001_one_tx_tvalid                    (w_001_one_tx_tvalid                            ),
        .o_064_one_tx_tdata                     (w_064_one_tx_tdata                             ),
        .o_008_one_tx_tkeep                     (w_008_one_tx_tkeep                             ),
        .o_001_one_tx_tlast                     (w_001_one_tx_tlast                             ),
        .i_001_one_tx_tready                    (w_001_one_tx_tready                            )
    );

    // mul tx -> xch lane 1-mul

    assign w_64n_xch_tx_tdata [64*p_aur_lane_num-1:64] = w_64n_mul_tx_tdata                     ;
    assign w_08n_xch_tx_tkeep [ 8*p_aur_lane_num-1: 8] = w_08n_mul_tx_tkeep                     ;
    assign w_01n_xch_tx_tlast [   p_aur_lane_num-1: 1] = w_01n_mul_tx_tlast                     ;
    assign w_01n_xch_tx_tvalid[   p_aur_lane_num-1: 1] = w_01n_mul_tx_tvalid                    ;
    assign w_01n_mul_tx_tready                         = w_01n_xch_tx_tready[p_aur_lane_num-1:1];

`ifdef p_sim
    // one aur tx disconnected, idle for link clk
    assign w_64n_xch_tx_tdata [63:0]            = 64'h0                                         ;
    assign w_08n_xch_tx_tkeep [ 7:0]            = 8'h00                                         ;
    assign w_01n_xch_tx_tlast [   0]            = 1'b0                                          ;
    assign w_01n_xch_tx_tvalid[   0]            = 1'b0                                          ;
`else
    // mul_to_one -> xch one tx lane 0
    assign w_64n_xch_tx_tdata [63:0]            = w_064_one_tx_tdata                            ;
    assign w_08n_xch_tx_tkeep [ 7:0]            = w_008_one_tx_tkeep                            ;
    assign w_01n_xch_tx_tlast [   0]            = w_001_one_tx_tlast                            ;
    assign w_01n_xch_tx_tvalid[   0]            = w_001_one_tx_tvalid                           ;
`endif

    // loc axis -> sop

    aur_rx_if u03_aur_rx_if (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        .i_064_axis_tdata                       (w_064_loc_rx_tdata                             ),
        .i_008_axis_tkeep                       (w_008_loc_rx_tkeep                             ),
        .i_001_axis_tlast                       (w_001_loc_rx_tlast                             ),
        .i_001_axis_tvalid                      (w_001_loc_rx_tvalid                            ),
        .o_001_axis_tready                      (w_001_loc_rx_tready                            ),
        .i_001_aur_rx_rdy                       (w_001_aur_rx_rdy                               ),
        .o_001_aur_rx_sop                       (w_001_aur_rx_sop                               ),
        .o_001_aur_rx_eop                       (w_001_aur_rx_eop                               ),
        .o_001_aur_rx_dvld                      (w_001_aur_rx_dvld                              ),
        .o_064_aur_rx_data                      (w_064_aur_rx_data                              )
    );

    // unpack

    aur_rx_dec u04_aur_rx_dec (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        // loc sop
        .o_001_aur_rx_rdy                       (w_001_aur_rx_rdy                               ),
        .i_001_aur_rx_sop                       (w_001_aur_rx_sop                               ),
        .i_001_aur_rx_eop                       (w_001_aur_rx_eop                               ),
        .i_001_aur_rx_dvld                      (w_001_aur_rx_dvld                              ),
        .i_064_aur_rx_data                      (w_064_aur_rx_data                              ),
        // reg
        .o_001_reg_wr_req                       (o_001_reg_wr_req                               ),
        .i_001_reg_wr_ack                       (i_001_reg_wr_ack                               ),
        .o_032_reg_wr_data                      (o_032_reg_wr_data                              ),
        .o_001_reg_rd_req                       (o_001_reg_rd_req                               ),
        .i_001_reg_rd_ack                       (i_001_reg_rd_ack                               ),
        .i_032_reg_rd_data                      (i_032_reg_rd_data                              ),
        .o_032_reg_addr                         (o_032_reg_addr                                 ),
        .i_001_reg_rdy                          (i_001_reg_rdy                                  ),
        .i_001_reg_fail                         (i_001_reg_fail                                 ),
        // ram wr
        .o_001_ram_wr_req                       (o_001_ram_wr_req                               ),
        .o_024_ram_wr_addr                      (o_024_ram_wr_addr                              ),
        .o_024_ram_wr_size                      (o_024_ram_wr_size                              ),
        .o_016_ram_wr_bsel                      (o_016_ram_wr_bsel                              ),
        .o_064_ram_wr_data                      (o_064_ram_wr_data                              ),
        .o_001_ram_wr_dvld                      (o_001_ram_wr_dvld                              ),
        .o_001_ram_wr_sop                       (o_001_ram_wr_sop                               ),
        .o_001_ram_wr_eop                       (o_001_ram_wr_eop                               ),
        .i_001_ram_wr_fail                      (i_001_ram_wr_fail                              ),
        // ram rd
        .o_001_ram_rd_req                       (o_001_ram_rd_req                               ),
        .o_024_ram_rd_addr                      (o_024_ram_rd_addr                              ),
        .o_024_ram_rd_size                      (o_024_ram_rd_size                              ),
        .o_016_ram_rd_bsel                      (o_016_ram_rd_bsel                              ),
        .i_001_ram_cbuf_rdy                     (i_001_ram_cbuf_rdy                             ),
        .i_001_ram_rd_sop                       (i_001_ram_rd_sop                               ),
        .i_001_ram_rd_eop                       (i_001_ram_rd_eop                               ),
        .i_001_ram_rd_dvld                      (i_001_ram_rd_dvld                              ),
        .i_064_ram_rd_data                      (i_064_ram_rd_data                              ),
        // reg rsp
        .o_001_reg_rcp_req                      (w_001_reg_rcp_req                              ),
        .i_001_reg_rcp_ack                      (w_001_reg_rcp_ack                              ),
        .o_016_reg_rcp_qid                      (w_016_reg_rcp_qid                              ),
        .o_016_reg_rcp_dst                      (w_016_reg_rcp_dst                              ),
        .o_016_reg_rcp_src                      (w_016_reg_rcp_src                              ),
        .o_016_reg_rcp_ackn                     (w_016_reg_rcp_ackn                             ),
        .o_016_reg_rcp_msg                      (w_016_reg_rcp_msg                              ),
        .o_032_reg_rcp_addr                     (w_032_reg_rcp_addr                             ),
        .o_032_reg_rcp_data                     (w_032_reg_rcp_data                             ),
        .o_001_reg_rcp_multi                    (w_001_reg_rcp_multi                            ),
        .o_016_reg_rcp_nbeat                    (w_016_reg_rcp_nbeat                            ),
        .o_064_reg_rcp_beat                     (w_064_reg_rcp_beat                             ),
        .i_001_reg_rcp_beat_re                  (w_001_reg_rcp_beat_re                          ),
        // ram rsp
        .o_001_ram_rcp_req                      (w_001_ram_rcp_req                              ),
        .i_001_ram_rcp_ack                      (w_001_ram_rcp_ack                              ),
        .o_016_ram_rcp_qid                      (w_016_ram_rcp_qid                              ),
        .o_016_ram_rcp_dst                      (w_016_ram_rcp_dst                              ),
        .o_016_ram_rcp_src                      (w_016_ram_rcp_src                              ),
        .o_016_ram_rcp_ackn                     (w_016_ram_rcp_ackn                             ),
        .o_016_ram_rcp_msg                      (w_016_ram_rcp_msg                              ),
        .o_016_ram_rcp_cs                       (w_016_ram_rcp_cs                               ),
        .o_024_ram_rcp_addr                     (w_024_ram_rcp_addr                             ),
        .o_024_ram_rcp_len                      (w_024_ram_rcp_len                              ),
        .o_001_ram_rcp_rd                       (w_001_ram_rcp_rd                               ),
        .o_001_ram_rcp_fail                     (w_001_ram_rcp_fail                             ),
        // ddr rsp
        .o_001_ddr_rcp_req                      (w_001_ddr_rcp_req                              ),
        .i_001_ddr_rcp_ack                      (w_001_ddr_rcp_ack                              ),
        .o_016_ddr_rcp_qid                      (w_016_ddr_rcp_qid                              ),
        .o_016_ddr_rcp_dst                      (w_016_ddr_rcp_dst                              ),
        .o_016_ddr_rcp_src                      (w_016_ddr_rcp_src                              ),
        .o_016_ddr_rcp_ackn                     (w_016_ddr_rcp_ackn                             ),
        .o_016_ddr_rcp_msg                      (w_016_ddr_rcp_msg                              ),
        .o_001_ddr_rcp_fail                     (w_001_ddr_rcp_fail                             )
    );

    // pack, ddr ports hang / tie 0 at req from dec

    reg_rcp_tx u05_reg_rcp_tx (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        // rcp cmd
        .i_001_rcp_req                          (w_001_reg_rcp_req                              ),
        .o_001_rcp_ack                          (w_001_reg_rcp_ack                              ),
        .i_016_qid                              (w_016_reg_rcp_qid                              ),
        .i_016_dst                              (w_016_reg_rcp_dst                              ),
        .i_016_src                              (w_016_reg_rcp_src                              ),
        .i_016_ackn                             (w_016_reg_rcp_ackn                             ),
        .i_016_msg                              (w_016_reg_rcp_msg                              ),
        .i_032_addr                             (w_032_reg_rcp_addr                             ),
        .i_032_data                             (w_032_reg_rcp_data                             ),
        // batch rd buf
        .i_001_multi                            (w_001_reg_rcp_multi                            ),
        .i_016_nbeat                            (w_016_reg_rcp_nbeat                            ),
        .i_064_beat                             (w_064_reg_rcp_beat                             ),
        .o_001_beat_re                          (w_001_reg_rcp_beat_re                          ),
        // loc tx
        .o_001_tx_req                           (w_003_chi_req[0]                               ),
        .i_001_tx_ack                           (w_003_chi_ack[0]                               ),
        .i_001_tx_rdy                           (w_003_chi_rdy[0]                               ),
        .o_001_tx_sop                           (w_003_chi_sop[0]                               ),
        .o_001_tx_eop                           (w_003_chi_eop[0]                               ),
        .o_001_tx_dvld                          (w_003_chi_dvld[0]                              ),
        .o_064_tx_data                          (w_192_chi_data[63:0]                           )
    );

    // ram rsp pack

    ram_rcp_tx u06_ram_rcp_tx (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        .i_001_rcp_req                          (w_001_ram_rcp_req                              ),
        .o_001_rcp_ack                          (w_001_ram_rcp_ack                              ),
        .i_001_rcp_rd                           (w_001_ram_rcp_rd                               ),
        .i_001_rcp_fail                         (w_001_ram_rcp_fail                             ),
        .i_016_qid                              (w_016_ram_rcp_qid                              ),
        .i_016_dst                              (w_016_ram_rcp_dst                              ),
        .i_016_src                              (w_016_ram_rcp_src                              ),
        .i_016_ackn                             (w_016_ram_rcp_ackn                             ),
        .i_016_msg                              (w_016_ram_rcp_msg                              ),
        .i_016_cs                               (w_016_ram_rcp_cs                               ),
        .i_024_addr                             (w_024_ram_rcp_addr                             ),
        .i_024_len                              (w_024_ram_rcp_len                              ),
        .i_001_ram_rd_sop                       (i_001_ram_rd_sop                               ),
        .i_001_ram_rd_eop                       (i_001_ram_rd_eop                               ),
        .i_001_ram_rd_dvld                      (i_001_ram_rd_dvld                              ),
        .i_064_ram_rd_data                      (i_064_ram_rd_data                              ),
        .o_001_ram_rd_rdy                       (o_001_ram_rd_rdy                               ),
        .o_001_tx_req                           (w_003_chi_req[1]                               ),
        .i_001_tx_ack                           (w_003_chi_ack[1]                               ),
        .i_001_tx_rdy                           (w_003_chi_rdy[1]                               ),
        .o_001_tx_sop                           (w_003_chi_sop[1]                               ),
        .o_001_tx_eop                           (w_003_chi_eop[1]                               ),
        .o_001_tx_dvld                          (w_003_chi_dvld[1]                              ),
        .o_064_tx_data                          (w_192_chi_data[127:64]                         )
    );

    // ddr rsp pack, stub

    ddr_rcp_tx u07_ddr_rcp_tx (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        .i_001_rcp_req                          (w_001_ddr_rcp_req                              ),
        .o_001_rcp_ack                          (w_001_ddr_rcp_ack                              ),
        .i_016_qid                              (w_016_ddr_rcp_qid                              ),
        .i_016_dst                              (w_016_ddr_rcp_dst                              ),
        .i_016_src                              (w_016_ddr_rcp_src                              ),
        .i_016_ackn                             (w_016_ddr_rcp_ackn                             ),
        .i_016_msg                              (w_016_ddr_rcp_msg                              ),
        .i_001_rcp_fail                         (w_001_ddr_rcp_fail                             ),
        .o_001_tx_req                           (w_003_chi_req[2]                               ),
        .i_001_tx_ack                           (w_003_chi_ack[2]                               ),
        .i_001_tx_rdy                           (w_003_chi_rdy[2]                               ),
        .o_001_tx_sop                           (w_003_chi_sop[2]                               ),
        .o_001_tx_eop                           (w_003_chi_eop[2]                               ),
        .o_001_tx_dvld                          (w_003_chi_dvld[2]                              ),
        .o_064_tx_data                          (w_192_chi_data[191:128]                        )
    );

    // pack mux

    aur_tx_arbit #(
        .p_chnin                                (3                                              ),
        .p_dwith                                (64                                             )
    ) u08_aur_tx_arbit (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        .i_001_arbit_rdy                        (w_001_aur_tx_rdy                               ),
        .o_001_arbit_sop                        (w_001_aur_tx_sop                               ),
        .o_001_arbit_eop                        (w_001_aur_tx_eop                               ),
        .o_001_arbit_dvld                       (w_001_aur_tx_dvld                              ),
        .o_0nn_arbit_data                       (w_064_aur_tx_data                              ),
        .i_00n_chi_req                          (w_003_chi_req                                  ),
        .o_00n_chi_ack                          (w_003_chi_ack                                  ),
        .o_00n_chi_rdy                          (w_003_chi_rdy                                  ),
        .i_00n_chi_sop                          (w_003_chi_sop                                  ),
        .i_00n_chi_eop                          (w_003_chi_eop                                  ),
        .i_00n_chi_dvld                         (w_003_chi_dvld                                 ),
        .i_nnn_chi_data                         (w_192_chi_data                                 )
    );

    // sop -> loc axis

    aur_tx_if u09_aur_tx_if (
        .i_001_clk                              (i_001_loc_clk                                  ),
        .i_001_rst                              (i_001_loc_rst                                  ),
        .o_001_aur_tx_rdy                       (w_001_aur_tx_rdy                               ),
        .i_001_aur_tx_sop                       (w_001_aur_tx_sop                               ),
        .i_001_aur_tx_eop                       (w_001_aur_tx_eop                               ),
        .i_001_aur_tx_dvld                      (w_001_aur_tx_dvld                              ),
        .i_064_aur_tx_data                      (w_064_aur_tx_data                              ),
        .o_064_axis_tdata                       (w_064_loc_tx_tdata                             ),
        .o_008_axis_tkeep                       (w_008_loc_tx_tkeep                             ),
        .o_001_axis_tlast                       (w_001_loc_tx_tlast                             ),
        .o_001_axis_tvalid                      (w_001_loc_tx_tvalid                            ),
        .i_001_axis_tready                      (w_001_loc_tx_tready                            )
    );

endmodule
