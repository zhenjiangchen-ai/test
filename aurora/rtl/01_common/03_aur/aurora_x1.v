// =================================================================================================
// file name      : aurora_x1.v
// module         : aurora_x1
// function       : aurora_x1 
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/08/11   lxl        create new              semigth
// =================================================================================================

`timescale 1ps/1ps

module aurora_x1 (
    // init
    input                               i_001_init_clk                          ,
    input                               i_001_init_rst                          ,
    // aur clk rst
    output                              o_001_aur_clk                           ,
    output                              o_001_aur_rst                           ,
    // tx data
    input      [                  63:0] i_064_axis_tx_tdata                     ,
    input      [                   7:0] i_008_axis_tx_tkeep                     ,
    input                               i_001_axis_tx_tlast                     ,
    input                               i_001_axis_tx_tvalid                    ,
    output                              o_001_axis_tx_tready                    ,
    // rx data  
    output     [                  63:0] o_064_axis_rx_tdata                     ,
    output     [                   7:0] o_008_axis_rx_tkeep                     ,
    output                              o_001_axis_rx_tlast                     ,
    output                              o_001_axis_rx_tvalid                    ,
    // nfc  
    input                               i_001_axi_nfc_tvalid                    ,
    input      [                  15:0] i_016_axi_nfc_tdata                     ,
    output                              o_001_axi_nfc_tready                    ,
    // aurora
    input                               i_001_rx_p                              ,
    input                               i_001_rx_n                              ,
    output                              o_001_tx_p                              ,
    output                              o_001_tx_n                              ,
    // refclk
    input                               i_001_ref_clk                           ,
    // debug
    output                              o_001_hard_err                          ,
    output                              o_001_soft_err                          ,
    output                              o_001_crc_pass                          ,
    output                              o_001_crc_valid                         ,
    output                              o_001_chan_up                           ,
    output                              o_001_lane_up                           ,
    output                              o_001_link_reset                        ,
    // qpll
    input                               i_001_gt_qpllclk_quad1                  ,
    input                               i_001_gt_qpllrefclk_quad1               ,
    output                              o_001_gt_to_common_qpllreset            ,
    input                               i_001_gt_qplllock_quad1                 ,
    input                               i_001_gt_qpllrefclklost_quad1
);

// ==============================================================================
// Internal Signal Declare
// ==============================================================================

    wire                                w_001_reset_pb                              ;
    wire                                w_001_pma_init                              ;

    wire                                w_001_tx_out_clk                            ;
    wire                                w_001_bufg_gt_clr_out                       ;

    wire                                w_001_sync_clk                              ;
    wire                                w_001_mmcm_ont_locked                       ;

    reg                                 r_001_chn_up_r1                         ;
    reg                                 r_001_chn_up_r2                         ;

    reg                                 r_001_chn_up_pos                        ;

// =================================================================================================
// RTL Body
// =================================================================================================

/*=============================================================================+/
||                                                                             ||
||                                 output                                      ||
||                                                                             ||
/+=============================================================================*/

/*=============================================================================+/
||                                                                             ||
||                               aur init rst                                  ||
||                                                                             ||
/+=============================================================================*/

    aur_rst u00_init_rst (
        .i_001_init_clk                 (i_001_init_clk                         ),
        .i_001_init_rst                 (i_001_init_rst                         ),
        .i_001_aur_clk                  (o_001_aur_clk                          ),
        .i_001_lane_up                  (o_001_chan_up                          ),
        .o_001_pma_rst                  (w_001_pma_init                         ),
        .o_001_pcs_rst                  (w_001_reset_pb                         ) 
    );

/*=============================================================================+/
||                                                                             ||
||                                   aur_clk                                   ||
||                                                                             ||
/+=============================================================================*/

    aurora_64b66b_CLOCK_MODULE u01_aur_clk (
        .CLK                            (w_001_tx_out_clk                       ),// i/p // this is output from GT module txoutclk_out lane 0
        .CLK_LOCKED                     (w_001_bufg_gt_clr_out                  ),// i/p // connect to bufg_gt_clr_out in GT module
        .USER_CLK                       (o_001_aur_clk                          ),// o/p // this is sync_clk/2 (use as userclk2_clk)
        .SYNC_CLK                       (w_001_sync_clk                         ),// o/p // this is sync clk   (use as userclk_clk)
        .MMCM_NOT_LOCKED                (w_001_mmcm_ont_locked                  ) // o/p // connect to gtwiz_userclk_tx_active_out
    );

/*=============================================================================+/
||                                                                             ||
||                                   aur_rst                                   ||
||                                                                             ||
/+=============================================================================*/

    always @ (posedge o_001_aur_clk) begin
        r_001_chn_up_r1                 <= o_001_chan_up                        ;
        r_001_chn_up_r2                 <= r_001_chn_up_r1                      ;
    end

    always @ (posedge o_001_aur_clk) begin
        r_001_chn_up_pos                <= (!r_001_chn_up_r2) && r_001_chn_up_r1;
    end

    sync_rst #(
        .p_dly_cyc_num                  (31                                     )                           
    ) u02_aur_rst (
        .i_001_clk                      (o_001_aur_clk                          ),
        .i_001_rst                      (r_001_chn_up_pos                       ),
        .o_001_rst                      (o_001_aur_rst                          )
    );

/*=============================================================================+/
||                                                                             ||
||                                 aur_core                                    ||
||                                                                             ||
/+=============================================================================*/

    aurora_64b66b u03_aur_core (
        // s axis
        .s_axi_tx_tdata                 (i_064_axis_tx_tdata                    ),// input wire [0 : 63] s_axi_tx_tdata
        .s_axi_tx_tkeep                 (i_008_axis_tx_tkeep                    ),// input wire [0 : 7] s_axi_tx_tkeep
        .s_axi_tx_tlast                 (i_001_axis_tx_tlast                    ),// input wire s_axi_tx_tlast
        .s_axi_tx_tvalid                (i_001_axis_tx_tvalid                   ),// input wire s_axi_tx_tvalid
        .s_axi_tx_tready                (o_001_axis_tx_tready                   ),// output wire s_axi_tx_tready
        // m axis   
        .m_axi_rx_tdata                 (o_064_axis_rx_tdata                    ),// output wire [0 : 63] m_axi_rx_tdata
        .m_axi_rx_tkeep                 (o_008_axis_rx_tkeep                    ),// output wire [0 : 7] m_axi_rx_tkeep
        .m_axi_rx_tlast                 (o_001_axis_rx_tlast                    ),// output wire m_axi_rx_tlast
        .m_axi_rx_tvalid                (o_001_axis_rx_tvalid                   ),// output wire m_axi_rx_tvalid
        // nfc  
        .s_axi_nfc_tvalid               (i_001_axi_nfc_tvalid                   ),// input wire s_axi_nfc_tvalid
        .s_axi_nfc_tdata                (i_016_axi_nfc_tdata                    ),// input wire [0 : 15] s_axi_nfc_tdata
        .s_axi_nfc_tready               (o_001_axi_nfc_tready                   ),// output wire s_axi_nfc_tready
        // pin
        .rxp                            (i_001_rx_p                             ),// input wire [0 : 0] rxp
        .rxn                            (i_001_rx_n                             ),// input wire [0 : 0] rxn
        .txp                            (o_001_tx_p                             ),// output wire [0 : 0] txp
        .txn                            (o_001_tx_n                             ),// output wire [0 : 0] txn
        .refclk1_in                     (i_001_ref_clk                          ),// input wire refclk1_in
        // error and statue
        .hard_err                       (o_001_hard_err                         ),// output wire hard_err
        .soft_err                       (o_001_soft_err                         ),// output wire soft_err
        .crc_pass_fail_n                (o_001_crc_pass                         ),// output wire crc_pass_fail_n
        .crc_valid                      (o_001_crc_valid                        ),// output wire crc_valid
        .channel_up                     (o_001_chan_up                          ),// output wire channel_up
        .lane_up                        (o_001_lane_up                          ),// output wire [0 : 0] lane_up
        // system interface
        .mmcm_not_locked                (!w_001_mmcm_ont_locked                 ),// input wire mmcm_not_locked
        .sys_reset_out                  (                                       ),// output wire sys_reset_out
        .tx_out_clk                     (w_001_tx_out_clk                       ),// output wire tx_out_clk
        .user_clk                       (o_001_aur_clk                          ),// input wire user_clk
        .sync_clk                       (w_001_sync_clk                         ),// input wire sync_clk
        .reset_pb                       (w_001_reset_pb                         ),// input wire reset_pb
        .gt_rxcdrovrden_in              (1'b0                                   ),// input wire gt_rxcdrovrden_in
        .pma_init                       (w_001_pma_init                         ),// input wire pma_init
        .power_down                     (1'b0                                   ),// input wire power_down
        .loopback                       (3'b000                                 ),// input wire [2 : 0] loopback
        .bufg_gt_clr_out                (w_001_bufg_gt_clr_out                  ),// output wire bufg_gt_clr_out
        .gt_pll_lock                    (                                       ),// output wire gt_pll_lock
        .init_clk                       (i_001_init_clk                         ),// input wire init_clk
        .link_reset_out                 (o_001_link_reset                       ),// output wire link_reset_out
        // gt common for the qpll reference clock
        .gt_qpllclk_quad1_in            (i_001_gt_qpllclk_quad1                 ),// input wire gt_qpllclk_quad1_in
        .gt_qpllrefclk_quad1_in         (i_001_gt_qpllrefclk_quad1              ),// input wire gt_qpllrefclk_quad1_in
        .gt_to_common_qpllreset_out     (o_001_gt_to_common_qpllreset           ),// output wire gt_to_common_qpllreset_out
        .gt_qplllock_quad1_in           (i_001_gt_qplllock_quad1                ),// input wire gt_qplllock_quad1_in
        .gt_qpllrefclklost_quad1        (i_001_gt_qpllrefclklost_quad1          ),// input wire gt_qpllrefclklost_quad1
        // gt drp ports
        .gt0_drpaddr                    ({09{1'b0}}                             ),// input wire [8 : 0] gt0_drpaddr
        .gt0_drpdi                      ({16{1'b0}}                             ),// input wire [15 : 0] gt0_drpdi
        .gt0_drprdy                     (                                       ),// output wire gt0_drprdy
        .gt0_drpwe                      ({01{1'b0}}                             ),// input wire gt0_drpwe
        .gt0_drpen                      ({01{1'b0}}                             ),// input wire gt0_drpen
        .gt0_drpdo                      (                                       ),// output wire [15 : 0] gt0_drpdo
        .gt_powergood                   (                                       ) // output wire [0 : 0] gt_powergood
    );

endmodule

