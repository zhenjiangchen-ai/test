// =================================================================================================
// file name      : aurora_xch.v
// module         : aurora_xch
// function       : variable-lane aurora 64b66b with shared gth qpll
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/17   lxl        create new              semigth
// 0.0.2        2026/09/18   lxl        per-quad ref clk        semigth
// 0.0.3        2026/09/18   lxl        lane-quad map vs phy    semigth
// =================================================================================================

`timescale 1ns / 1ps

module aurora_xch #(
    parameter p_aur_quad_num                    = 7                                             , // gt quad / ref clk num
    parameter p_aur_lane_num                    = 13                                              // 1 hsp + 12 slot
) (
    // init
    input                                       i_001_init_clk                                  , // init clock
    input                                       i_001_init_rst                                  , // init reset
    // aur clk rst
    output     [            p_aur_lane_num-1:0] o_00n_aur_clk                                   , // aurora user clk
    output     [            p_aur_lane_num-1:0] o_00n_aur_rst                                   , // aurora user rst
    // link
    output     [            p_aur_lane_num-1:0] o_00n_chan_up                                   , // channel up
    output     [            p_aur_lane_num-1:0] o_00n_lane_up                                   , // lane up
    // tx data
    input      [         64*p_aur_lane_num-1:0] i_64n_axis_tx_tdata                             ,
    input      [          8*p_aur_lane_num-1:0] i_08n_axis_tx_tkeep                             ,
    input      [            p_aur_lane_num-1:0] i_01n_axis_tx_tlast                             ,
    input      [            p_aur_lane_num-1:0] i_01n_axis_tx_tvalid                            ,
    output     [            p_aur_lane_num-1:0] o_01n_axis_tx_tready                            ,
    // rx data
    output     [         64*p_aur_lane_num-1:0] o_64n_axis_rx_tdata                             ,
    output     [          8*p_aur_lane_num-1:0] o_08n_axis_rx_tkeep                             ,
    output     [            p_aur_lane_num-1:0] o_01n_axis_rx_tlast                             ,
    output     [            p_aur_lane_num-1:0] o_01n_axis_rx_tvalid                            ,
    // nfc : near flow control
    input      [            p_aur_lane_num-1:0] i_01n_axi_nfc_tvalid                            ,
    input      [         16*p_aur_lane_num-1:0] i_16n_axi_nfc_tdata                             ,
    output     [            p_aur_lane_num-1:0] o_01n_axi_nfc_tready                            ,
    // pin
    input      [            p_aur_lane_num-1:0] i_00n_aur_rx_p                                  ,
    input      [            p_aur_lane_num-1:0] i_00n_aur_rx_n                                  ,
    output     [            p_aur_lane_num-1:0] o_00n_aur_tx_p                                  ,
    output     [            p_aur_lane_num-1:0] o_00n_aur_tx_n                                  ,
    input      [            p_aur_quad_num-1:0] i_00n_aur_clk_p                                 ,
    input      [            p_aur_quad_num-1:0] i_00n_aur_clk_n
);

    // ********************************************************************************************
    // localparameter declare
    // ********************************************************************************************

    genvar                                      i                                               ;

    genvar                                      q                                               ;

    // lane -> quad, same as phy.xdc
    // quad0 : aur0 hsp,  clk[0] AM10  rx[0] AR4
    // quad1 : aur1-2,    clk[1] AD32  rx[1:2]
    // quad2 : aur3-4,    clk[2] Y32   rx[3:4]
    // quad3 : aur5-6,    clk[3] T32   rx[5:6]
    // quad4 : aur7-8,    clk[4] AA8   rx[7:8]
    // quad5 : aur9-10,   clk[5] AE8   rx[9:10]
    // quad6 : aur11-12,  clk[6] AH10  rx[11:12]

    // =============================================================================
    // internal signal define
    // =============================================================================

    // ref clk

    wire       [            p_aur_quad_num-1:0] w_00n_ref_clk                                   ;

    // lane quad sel, 0 = first quad

    wire       [                           2:0] w_003_quad_sel  [0:p_aur_lane_num-1]            ;

    // qpll : quad pll

    wire       [            p_aur_quad_num-1:0] w_001_qpll_clk                                  ;
    wire       [            p_aur_quad_num-1:0] w_001_qpll_refclk                               ;
    wire       [            p_aur_quad_num-1:0] w_001_qpll_lock                                 ;
    wire       [            p_aur_quad_num-1:0] w_001_qpll_reflost                              ;
    wire       [            p_aur_quad_num-1:0] w_001_qpll_reset                                ;

    wire       [            p_aur_lane_num-1:0] w_00n_qpll_reset                                ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    // gt ref clk buffer, one per quad

    generate for (i = 0; i < p_aur_quad_num; i = i + 1) begin : gen_ref_clk

        IBUFDS_GTE3 u00_ref_clk (
            .I                                  (i_00n_aur_clk_p              [               i]),
            .IB                                 (i_00n_aur_clk_n              [               i]),
            .CEB                                (1'b0                                           ),
            .O                                  (w_00n_ref_clk                [               i]),
            .ODIV2                              (                                               )
        );

    end
    endgenerate

    // qpll common, one per gt quad, share gth0 lanes in the same bank

    generate for (q = 0; q < p_aur_quad_num; q = q + 1) begin : gen_qpll

        aurora_64b66b_gt_common_wrapper u01_gt_common (
            .qpll1_refclk                       (w_00n_ref_clk                [               q]), //(i)[  1]
            .qpll1_reset                        (w_001_qpll_reset             [               q]), //(i)[  1]
            .qpll1_lock_detclk                  (i_001_init_clk                                 ), //(i)[  1]
            .qpll1_lock                         (w_001_qpll_lock              [               q]), //(o)[  1]
            .qpll1_outclk                       (w_001_qpll_clk               [               q]), //(o)[  1]
            .qpll1_outrefclk                    (w_001_qpll_refclk            [               q]), //(o)[  1]
            .qpll1_refclklost                   (w_001_qpll_reflost           [               q])  //(o)[  1]
        );

    end
    endgenerate

    // lane -> quad : aur0 uses quad0 qpll, then 2 lane share 1 quad

    generate if (p_aur_lane_num == 13) begin : gen_quad_sel_13

        assign w_003_quad_sel[ 0]               = 3'd0                                          ; // aur0  hsp   / quad0
        assign w_003_quad_sel[ 1]               = 3'd1                                          ; // aur1  slot1 / quad1
        assign w_003_quad_sel[ 2]               = 3'd1                                          ; // aur2  slot2 / quad1
        assign w_003_quad_sel[ 3]               = 3'd2                                          ; // aur3  slot3 / quad2
        assign w_003_quad_sel[ 4]               = 3'd2                                          ; // aur4  slot4 / quad2
        assign w_003_quad_sel[ 5]               = 3'd3                                          ; // aur5  slot5 / quad3
        assign w_003_quad_sel[ 6]               = 3'd3                                          ; // aur6  slot6 / quad3
        assign w_003_quad_sel[ 7]               = 3'd4                                          ; // aur7  slot7 / quad4
        assign w_003_quad_sel[ 8]               = 3'd4                                          ; // aur8  slot8 / quad4
        assign w_003_quad_sel[ 9]               = 3'd5                                          ; // aur9  slot9 / quad5
        assign w_003_quad_sel[10]               = 3'd5                                          ; // aur10 slot10/ quad5
        assign w_003_quad_sel[11]               = 3'd6                                          ; // aur11 slot11/ quad6
        assign w_003_quad_sel[12]               = 3'd6                                          ; // aur12 slot12/ quad6

    end else begin : gen_quad_sel_sim

        assign w_003_quad_sel[ 0]               = 3'd0                                          ; // aur0  / quad0
        assign w_003_quad_sel[ 1]               = 3'd1                                          ; // aur1  / quad1
        assign w_003_quad_sel[ 2]               = 3'd1                                          ; // aur2  / quad1

    end
    endgenerate

    // qpll reset, or of lanes that share this quad

    generate for (q = 0; q < p_aur_quad_num; q = q + 1) begin : gen_qpll_rst

        wire   [            p_aur_lane_num-1:0] w_00n_rst_mask                                  ;

        for (i = 0; i < p_aur_lane_num; i = i + 1) begin : gen_rst_mask

            assign w_00n_rst_mask[i]            = (w_003_quad_sel[i] == q) ? w_00n_qpll_reset[i] : 1'b0;

        end

        assign w_001_qpll_reset[q]              = |w_00n_rst_mask                               ;

    end
    endgenerate

    // 13 lane aurora x1, 1 hsp + 12 slot

    generate for (i = 0; i < p_aur_lane_num; i = i + 1) begin : gen_lane

        aurora_x1 u02_aurora_x1 (
            // init
            .i_001_init_clk                     (i_001_init_clk                                 ),
            .i_001_init_rst                     (i_001_init_rst                                 ),
            // aur clk rst
            .o_001_aur_clk                      (o_00n_aur_clk               [                i]),
            .o_001_aur_rst                      (o_00n_aur_rst               [                i]),
            // tx data                                                        
            .i_064_axis_tx_tdata                (i_64n_axis_tx_tdata         [  64*(i+1)-1:64*i]),
            .i_008_axis_tx_tkeep                (i_08n_axis_tx_tkeep         [   8*(i+1)-1: 8*i]),
            .i_001_axis_tx_tlast                (i_01n_axis_tx_tlast         [                i]),
            .i_001_axis_tx_tvalid               (i_01n_axis_tx_tvalid        [                i]),
            .o_001_axis_tx_tready               (o_01n_axis_tx_tready        [                i]),
            // rx data                                                        
            .o_064_axis_rx_tdata                (o_64n_axis_rx_tdata         [  64*(i+1)-1:64*i]),
            .o_008_axis_rx_tkeep                (o_08n_axis_rx_tkeep         [   8*(i+1)-1: 8*i]),
            .o_001_axis_rx_tlast                (o_01n_axis_rx_tlast         [                i]),
            .o_001_axis_rx_tvalid               (o_01n_axis_rx_tvalid        [                i]),
            // nfc                                                            
            .i_001_axi_nfc_tvalid               (i_01n_axi_nfc_tvalid        [                i]),
            .i_016_axi_nfc_tdata                (i_16n_axi_nfc_tdata         [  16*(i+1)-1:16*i]),
            .o_001_axi_nfc_tready               (o_01n_axi_nfc_tready        [                i]),
            // aurora                                                         
            .i_001_rx_p                         (i_00n_aur_rx_p              [                i]),
            .i_001_rx_n                         (i_00n_aur_rx_n              [                i]),
            .o_001_tx_p                         (o_00n_aur_tx_p              [                i]),
            .o_001_tx_n                         (o_00n_aur_tx_n              [                i]),
            // refclk                                                         
            .i_001_ref_clk                      (w_00n_ref_clk               [w_003_quad_sel[i]]),
            // debug
            .o_001_hard_err                     (                                               ),
            .o_001_soft_err                     (                                               ),
            .o_001_crc_pass                     (                                               ),
            .o_001_crc_valid                    (                                               ),
            .o_001_chan_up                      (o_00n_chan_up               [                i]),
            .o_001_lane_up                      (o_00n_lane_up               [                i]),
            .o_001_link_reset                   (                                               ),
            // qpll                                                           
            .i_001_gt_qpllclk_quad1             (w_001_qpll_clk              [w_003_quad_sel[i]]),
            .i_001_gt_qpllrefclk_quad1          (w_001_qpll_refclk           [w_003_quad_sel[i]]),
            .o_001_gt_to_common_qpllreset       (w_00n_qpll_reset            [                i]),
            .i_001_gt_qplllock_quad1            (w_001_qpll_lock             [w_003_quad_sel[i]]),
            .i_001_gt_qpllrefclklost_quad1      (w_001_qpll_reflost          [w_003_quad_sel[i]])
        );

    end
    endgenerate

endmodule
