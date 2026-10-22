// =================================================================================================
// file name      : aur_one_to_mul.v
// module         : aur_one_to_mul
// function       : one aurora rx fanout to n mul + loc
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/17   lxl        create new              semigth
// 0.0.2        2026/10/08   lxl        param n, dest id map    semigth
// =================================================================================================
//
// dest map (first 64b beat):
//   this ku : p_dst_id_lsb = dst slot [27:24], loc 0xf, mul 1..n
//   pe      : p_dst_id_lsb = dst fpga [31:28], loc 0x1, mul 2..n+1
//
//-----------------------------------------------------------------------------

`include "../hsp_pkt_hdr.vh"

`timescale 1ns / 1ps

module aur_one_to_mul #(
    parameter p_aur_sub_num                     = 12                                            , // mul lane num
    parameter p_loc_id                          = 4'hf                                          , // dest id -> loc
    parameter p_mul_id_min                      = 4'h1                                          , // dest id -> mul[0]
    parameter p_dst_id_lsb                      = `hsp_hdr_dst_slot_lsb                         , // dest field lsb
    parameter p_dst_id_w                        = `hsp_hdr_dst_slot_w                             // dest field width
) (
    // one clk rst
    input                                       i_001_one_clk                                   , // one aurora user clk
    input                                       i_001_one_rst                                   , // one aurora user rst
    // loc clk rst
    input                                       i_001_loc_clk                                   , // loc clk
    input                                       i_001_loc_rst                                   , // loc rst, high active
    // mul clk
    input      [             p_aur_sub_num-1:0] i_00n_mul_clk                                   , // mul aurora user clk
    // one rx
    input      [                          63:0] i_064_one_rx_tdata                              ,
    input      [                           7:0] i_008_one_rx_tkeep                              ,
    input                                       i_001_one_rx_tlast                              ,
    input                                       i_001_one_rx_tvalid                             ,
    // one nfc
    output                                      o_001_one_nfc_tvalid                            ,
    output     [                          15:0] o_016_one_nfc_tdata                             ,
    input                                       i_001_one_nfc_tready                            ,
    // mul tx
    output     [          64*p_aur_sub_num-1:0] o_64n_mul_tx_tdata                              ,
    output     [           8*p_aur_sub_num-1:0] o_08n_mul_tx_tkeep                              ,
    output     [             p_aur_sub_num-1:0] o_01n_mul_tx_tlast                              ,
    output     [             p_aur_sub_num-1:0] o_01n_mul_tx_tvalid                             ,
    input      [             p_aur_sub_num-1:0] i_01n_mul_tx_tready                             ,
    // loc rx
    output                                      o_001_loc_rx_tvalid                             ,
    output     [                          63:0] o_064_loc_rx_tdata                              ,
    output     [                           7:0] o_008_loc_rx_tkeep                              ,
    output                                      o_001_loc_rx_tlast                              ,
    input                                       i_001_loc_rx_tready
);

    // ********************************************************************************************
    // localparameter declare
    // ********************************************************************************************

    genvar                                      i                                               ;

    localparam [               p_dst_id_w-1:0] p_mul_id_max    = p_mul_id_min + p_aur_sub_num - 1;

    // =============================================================================
    // internal signal define
    // =============================================================================

    // one rx ingress fifo

    wire       [                          63:0] w_064_ing_tdata                                 ;
    wire       [                           7:0] w_008_ing_tkeep                                 ;
    wire                                        w_001_ing_tlast                                 ;
    wire                                        w_001_ing_tvalid                                ;
    wire                                        w_001_ing_tready_m                              ;
    wire       [                          31:0] w_032_ing_wrcnt                                 ;

    // dest id

    reg                                         r_001_sop                                       ;

    reg        [                p_dst_id_w-1:0] r_00n_dst_id                                    ;

    wire       [                p_dst_id_w-1:0] w_00n_dst_id                                    ;

    wire                                        w_001_hit_mul                                   ;

    wire       [             p_aur_sub_num-1:0] w_00n_mul_sel                                   ;

    wire                                        w_001_loc_sel                                   ;

    wire       [             p_aur_sub_num-1:0] w_00n_mul_s_tvalid                              ;
    wire       [             p_aur_sub_num-1:0] w_00n_mul_s_tready                              ;

    wire                                        w_001_loc_s_tvalid                              ;
    wire                                        w_001_loc_s_tready                              ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    // one rx ingress buf, nfc watermark

    axis_afifo_i64o64_d2048 u00_one_rx_buf (
        .s_axis_aresetn                         (~i_001_one_rst                                 ), // input wire s_axis_aresetn
        .s_axis_aclk                            (i_001_one_clk                                  ), // input wire s_axis_aclk
        .s_axis_tvalid                          (i_001_one_rx_tvalid                            ), // input wire s_axis_tvalid
        .s_axis_tready                          (                                               ), // output wire s_axis_tready
        .s_axis_tdata                           (i_064_one_rx_tdata                             ), // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep                           (i_008_one_rx_tkeep                             ), // input wire [7 : 0] s_axis_tkeep
        .s_axis_tlast                           (i_001_one_rx_tlast                             ), // input wire s_axis_tlast
        .m_axis_aclk                            (i_001_one_clk                                  ), // input wire m_axis_aclk
        .m_axis_tvalid                          (w_001_ing_tvalid                               ), // output wire m_axis_tvalid
        .m_axis_tready                          (w_001_ing_tready_m                             ), // input wire m_axis_tready
        .m_axis_tdata                           (w_064_ing_tdata                                ), // output wire [63 : 0] m_axis_tdata
        .m_axis_tkeep                           (w_008_ing_tkeep                                ), // output wire [7 : 0] m_axis_tkeep
        .m_axis_tlast                           (w_001_ing_tlast                                ), // output wire m_axis_tlast
        .axis_wr_data_count                     (w_032_ing_wrcnt                                )  // output wire [31 : 0] axis_wr_data_count
    );

    aur_nfc #(
        .p_buf_cnt_width                        ('d12                                           ),
        .p_buf_upp_water                        ('d1024                                         ),
        .p_buf_low_water                        ('d512                                          )
    ) u01_one_nfc (
        .i_001_clk                              (i_001_one_clk                                  ),
        .i_001_rst                              (i_001_one_rst                                  ),
        .i_00n_buf_wr_cnt                       (w_032_ing_wrcnt         [                  11:0]),
        .o_001_axi_nfc_tvalid                   (o_001_one_nfc_tvalid                           ),
        .o_016_axi_nfc_tdata                    (o_016_one_nfc_tdata                            ),
        .i_001_axi_nfc_tready                   (i_001_one_nfc_tready                           )
    );

    // sop, first beat of a frame

    always @(posedge i_001_one_clk) begin
        if (i_001_one_rst)
            r_001_sop                           <= 1'b1                                         ;
        else if (w_001_ing_tvalid && w_001_ing_tready_m)
            r_001_sop                           <= w_001_ing_tlast                              ;
    end

    assign w_00n_dst_id                         = r_001_sop ?
                                                  w_064_ing_tdata[p_dst_id_lsb +: p_dst_id_w] :
                                                  r_00n_dst_id                                  ;

    always @(posedge i_001_one_clk) begin
        if (i_001_one_rst)
            r_00n_dst_id                        <= {p_dst_id_w{1'b0}}                           ;
        else if (w_001_ing_tvalid && w_001_ing_tready_m && r_001_sop)
            r_00n_dst_id                        <= w_064_ing_tdata[p_dst_id_lsb +: p_dst_id_w]  ;
    end

    assign w_001_hit_mul                        = (w_00n_dst_id >= p_mul_id_min) && (w_00n_dst_id <= p_mul_id_max);

    assign w_001_loc_sel                        = (w_00n_dst_id == p_loc_id)                    ;

    generate for (i = 0; i < p_aur_sub_num; i = i + 1) begin : gen_mul_sel

        assign w_00n_mul_sel[i]                 = w_001_hit_mul && (w_00n_dst_id == (i + p_mul_id_min));

        assign w_00n_mul_s_tvalid[i]            = w_001_ing_tvalid && w_00n_mul_sel[i]          ;

    end
    endgenerate

    assign w_001_loc_s_tvalid                   = w_001_ing_tvalid && w_001_loc_sel             ;

    assign w_001_ing_tready_m                   = w_001_hit_mul ?
                                                  |(w_00n_mul_s_tready & w_00n_mul_sel) :
                                                  (w_001_loc_sel ? w_001_loc_s_tready : 1'b0)   ;

    // mul cdc, one clk -> mul clk

    generate for (i = 0; i < p_aur_sub_num; i = i + 1) begin : gen_mul_tx

        axis_afifo_i64o64_d1024 u02_mul_tx_cdc (
            .s_axis_aresetn                     (~i_001_one_rst                                 ), // input wire s_axis_aresetn
            .s_axis_aclk                        (i_001_one_clk                                  ), // input wire s_axis_aclk
            .s_axis_tvalid                      (w_00n_mul_s_tvalid           [               i]), // input wire s_axis_tvalid
            .s_axis_tready                      (w_00n_mul_s_tready           [               i]), // output wire s_axis_tready
            .s_axis_tdata                       (w_064_ing_tdata                                ), // input wire [63 : 0] s_axis_tdata
            .s_axis_tkeep                       (w_008_ing_tkeep                                ), // input wire [7 : 0] s_axis_tkeep
            .s_axis_tlast                       (w_001_ing_tlast                                ), // input wire s_axis_tlast
            .m_axis_aclk                        (i_00n_mul_clk                [               i]), // input wire m_axis_aclk
            .m_axis_tvalid                      (o_01n_mul_tx_tvalid          [               i]), // output wire m_axis_tvalid
            .m_axis_tready                      (i_01n_mul_tx_tready          [               i]), // input wire m_axis_tready
            .m_axis_tdata                       (o_64n_mul_tx_tdata           [ 64*(i+1)-1:64*i]), // output wire [63 : 0] m_axis_tdata
            .m_axis_tkeep                       (o_08n_mul_tx_tkeep           [  8*(i+1)-1: 8*i]), // output wire [7 : 0] m_axis_tkeep
            .m_axis_tlast                       (o_01n_mul_tx_tlast           [               i]), // output wire m_axis_tlast
            .axis_wr_data_count                 (                                               )  // output wire [31 : 0] axis_wr_data_count
        );

    end
    endgenerate

    // loc rx cache

    axis_afifo_i64o64_d1024 u03_loc_rx_buf (
        .s_axis_aresetn                         (~(i_001_one_rst | i_001_loc_rst)               ), // wr/rd both rst
        .s_axis_aclk                            (i_001_one_clk                                  ), // input wire s_axis_aclk
        .s_axis_tvalid                          (w_001_loc_s_tvalid                             ), // input wire s_axis_tvalid
        .s_axis_tready                          (w_001_loc_s_tready                             ), // output wire s_axis_tready
        .s_axis_tdata                           (w_064_ing_tdata                                ), // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep                           (w_008_ing_tkeep                                ), // input wire [7 : 0] s_axis_tkeep
        .s_axis_tlast                           (w_001_ing_tlast                                ), // input wire s_axis_tlast
        .m_axis_aclk                            (i_001_loc_clk                                  ), // input wire m_axis_aclk
        .m_axis_tvalid                          (o_001_loc_rx_tvalid                            ), // output wire m_axis_tvalid
        .m_axis_tready                          (i_001_loc_rx_tready                            ), // input wire m_axis_tready
        .m_axis_tdata                           (o_064_loc_rx_tdata                             ), // output wire [63 : 0] m_axis_tdata
        .m_axis_tkeep                           (o_008_loc_rx_tkeep                             ), // output wire [7 : 0] m_axis_tkeep
        .m_axis_tlast                           (o_001_loc_rx_tlast                             ), // output wire m_axis_tlast
        .axis_wr_data_count                     (                                               )  // output wire [31 : 0] axis_wr_data_count
    );

endmodule
