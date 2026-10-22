// =================================================================================================
// file name      : aur_mul_to_one.v
// module         : aur_mul_to_one
// function       : n mul aurora + loc aggregate to one
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/17   lxl        create new              semigth
// 0.0.2        2026/10/08   lxl        param n, one/mul name   semigth
// =================================================================================================

`timescale 1ns / 1ps

module aur_mul_to_one #(
    parameter p_aur_sub_num                     = 12                                              // mul lane num
) (
    // one clk rst
    input                                       i_001_one_clk                                   , // one aurora user clk
    input                                       i_001_one_rst                                   , // one aurora user rst
    // loc clk rst
    input                                       i_001_loc_clk                                   , // loc clk
    input                                       i_001_loc_rst                                   , // loc rst, high active
    // mul clk rst
    input      [             p_aur_sub_num-1:0] i_00n_mul_clk                                   , // mul aurora user clk
    input      [             p_aur_sub_num-1:0] i_00n_mul_rst                                   , // mul aurora user rst
    // mul rx
    input      [          64*p_aur_sub_num-1:0] i_64n_mul_rx_tdata                              ,
    input      [           8*p_aur_sub_num-1:0] i_08n_mul_rx_tkeep                              ,
    input      [             p_aur_sub_num-1:0] i_01n_mul_rx_tlast                              ,
    input      [             p_aur_sub_num-1:0] i_01n_mul_rx_tvalid                             ,
    // mul nfc
    output     [             p_aur_sub_num-1:0] o_01n_mul_nfc_tvalid                            ,
    output     [          16*p_aur_sub_num-1:0] o_16n_mul_nfc_tdata                             ,
    input      [             p_aur_sub_num-1:0] i_01n_mul_nfc_tready                            ,
    // loc tx
    input                                       i_001_loc_tx_tvalid                             ,
    input      [                          63:0] i_064_loc_tx_tdata                              ,
    input      [                           7:0] i_008_loc_tx_tkeep                              ,
    input                                       i_001_loc_tx_tlast                              ,
    output                                      o_001_loc_tx_tready                             ,
    // one tx
    output                                      o_001_one_tx_tvalid                             ,
    output     [                          63:0] o_064_one_tx_tdata                              ,
    output     [                           7:0] o_008_one_tx_tkeep                              ,
    output                                      o_001_one_tx_tlast                              ,
    input                                       i_001_one_tx_tready
);

    // ********************************************************************************************
    // localparameter declare
    // ********************************************************************************************

    genvar                                      i                                               ;

    localparam p_src_num                        = p_aur_sub_num + 1                             ; // n mul + loc
    localparam p_gnt_w                          = 4                                             ; // src <= 16

    // =============================================================================
    // internal signal define
    // =============================================================================

    wire       [             p_aur_sub_num-1:0] w_00n_cdc_tvalid                                ;
    wire       [             p_aur_sub_num-1:0] w_00n_cdc_tready                                ;
    wire       [          64*p_aur_sub_num-1:0] w_64n_cdc_tdata                                 ;
    wire       [           8*p_aur_sub_num-1:0] w_08n_cdc_tkeep                                 ;
    wire       [             p_aur_sub_num-1:0] w_00n_cdc_tlast                                 ;

    wire       [          32*p_aur_sub_num-1:0] w_32n_cdc_wrcnt                                 ;

    // loc tx cdc, loc clk -> one clk

    wire                                        w_001_loc_tvalid                                ;
    wire                                        w_001_loc_tready                                ;
    wire       [                          63:0] w_064_loc_tdata                                 ;
    wire       [                           7:0] w_008_loc_tkeep                                 ;
    wire                                        w_001_loc_tlast                                 ;

    wire       [                 p_src_num-1:0] w_00n_req                                       ;

    wire       [                   p_gnt_w-1:0] w_00n_next_grant                                ;

    wire       [                   p_gnt_w-1:0] w_00n_grant_mul                                 ;

    wire                                        w_001_src_tvalid                                ;
    wire                                        w_001_src_tready                                ;
    wire       [                          63:0] w_064_src_tdata                                 ;
    wire       [                           7:0] w_008_src_tkeep                                 ;
    wire                                        w_001_src_tlast                                 ;

    reg        [                   p_gnt_w-1:0] r_00n_grant                                     ;

    reg                                         r_001_busy                                      ;

    reg                                         r_001_one_tx_tvalid                             ;
    reg        [                          63:0] r_064_one_tx_tdata                              ;
    reg        [                           7:0] r_008_one_tx_tkeep                              ;
    reg                                         r_001_one_tx_tlast                              ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    // mul rx cdc + nfc, mul clk -> one clk

    generate for (i = 0; i < p_aur_sub_num; i = i + 1) begin : gen_mul_rx

        axis_afifo_i64o64_d2048 u00_mul_rx_cdc (
            .s_axis_aresetn                     (~i_00n_mul_rst               [               i]), // input wire s_axis_aresetn
            .s_axis_aclk                        (i_00n_mul_clk                [               i]), // input wire s_axis_aclk
            .s_axis_tvalid                      (i_01n_mul_rx_tvalid          [               i]), // input wire s_axis_tvalid
            .s_axis_tready                      (                                               ), // output wire s_axis_tready
            .s_axis_tdata                       (i_64n_mul_rx_tdata           [ 64*(i+1)-1:64*i]), // input wire [63 : 0] s_axis_tdata
            .s_axis_tkeep                       (i_08n_mul_rx_tkeep           [  8*(i+1)-1: 8*i]), // input wire [7 : 0] s_axis_tkeep
            .s_axis_tlast                       (i_01n_mul_rx_tlast           [               i]), // input wire s_axis_tlast
            .m_axis_aclk                        (i_001_one_clk                                  ), // input wire m_axis_aclk
            .m_axis_tvalid                      (w_00n_cdc_tvalid             [               i]), // output wire m_axis_tvalid
            .m_axis_tready                      (w_00n_cdc_tready             [               i]), // input wire m_axis_tready
            .m_axis_tdata                       (w_64n_cdc_tdata              [ 64*(i+1)-1:64*i]), // output wire [63 : 0] m_axis_tdata
            .m_axis_tkeep                       (w_08n_cdc_tkeep              [  8*(i+1)-1: 8*i]), // output wire [7 : 0] m_axis_tkeep
            .m_axis_tlast                       (w_00n_cdc_tlast              [               i]), // output wire m_axis_tlast
            .axis_wr_data_count                 (w_32n_cdc_wrcnt              [ 32*(i+1)-1:32*i])  // output wire [31 : 0] axis_wr_data_count
        );

        aur_nfc #(
            .p_buf_cnt_width                    ('d12                                           ),
            .p_buf_upp_water                    ('d1024                                         ),
            .p_buf_low_water                    ('d512                                          )
        ) u01_mul_nfc (
            .i_001_clk                          (i_00n_mul_clk                [               i]),
            .i_001_rst                          (i_00n_mul_rst                [               i]),
            .i_00n_buf_wr_cnt                   (w_32n_cdc_wrcnt              [    32*i+11:32*i]),
            .o_001_axi_nfc_tvalid               (o_01n_mul_nfc_tvalid         [               i]),
            .o_016_axi_nfc_tdata                (o_16n_mul_nfc_tdata          [ 16*(i+1)-1:16*i]),
            .i_001_axi_nfc_tready               (i_01n_mul_nfc_tready         [               i])
        );

    end
    endgenerate

    // loc tx cache

    axis_afifo_i64o64_d1024 u02_loc_tx_buf (
        .s_axis_aresetn                         (~i_001_loc_rst                                 ), // input wire s_axis_aresetn
        .s_axis_aclk                            (i_001_loc_clk                                  ), // input wire s_axis_aclk
        .s_axis_tvalid                          (i_001_loc_tx_tvalid                            ), // input wire s_axis_tvalid
        .s_axis_tready                          (o_001_loc_tx_tready                            ), // output wire s_axis_tready
        .s_axis_tdata                           (i_064_loc_tx_tdata                             ), // input wire [63 : 0] s_axis_tdata
        .s_axis_tkeep                           (i_008_loc_tx_tkeep                             ), // input wire [7 : 0] s_axis_tkeep
        .s_axis_tlast                           (i_001_loc_tx_tlast                             ), // input wire s_axis_tlast
        .m_axis_aclk                            (i_001_one_clk                                  ), // input wire m_axis_aclk
        .m_axis_tvalid                          (w_001_loc_tvalid                               ), // output wire m_axis_tvalid
        .m_axis_tready                          (w_001_loc_tready                               ), // input wire m_axis_tready
        .m_axis_tdata                           (w_064_loc_tdata                                ), // output wire [63 : 0] m_axis_tdata
        .m_axis_tkeep                           (w_008_loc_tkeep                                ), // output wire [7 : 0] m_axis_tkeep
        .m_axis_tlast                           (w_001_loc_tlast                                ), // output wire m_axis_tlast
        .axis_wr_data_count                     (                                               )  // output wire [31 : 0] axis_wr_data_count
    );

    assign w_00n_req                            = {w_001_loc_tvalid, w_00n_cdc_tvalid}          ;

    assign w_00n_next_grant                     = f_rr_grant(r_00n_grant, w_00n_req)            ;

    assign w_00n_grant_mul                      = (r_00n_grant >= p_aur_sub_num) ? {p_gnt_w{1'b0}}  : r_00n_grant;

    assign w_001_src_tvalid                     = (r_00n_grant == p_aur_sub_num) ? w_001_loc_tvalid : w_00n_cdc_tvalid[w_00n_grant_mul]         ;
    assign w_064_src_tdata                      = (r_00n_grant == p_aur_sub_num) ? w_064_loc_tdata  : w_64n_cdc_tdata[64*w_00n_grant_mul +: 64] ;
    assign w_008_src_tkeep                      = (r_00n_grant == p_aur_sub_num) ? w_008_loc_tkeep  : w_08n_cdc_tkeep[ 8*w_00n_grant_mul +:  8] ;
    assign w_001_src_tlast                      = (r_00n_grant == p_aur_sub_num) ? w_001_loc_tlast  : w_00n_cdc_tlast[w_00n_grant_mul]          ;
    assign w_001_src_tready                     = (!r_001_one_tx_tvalid) || i_001_one_tx_tready                                                 ;

    assign w_001_loc_tready                     = (r_00n_grant == p_aur_sub_num) && w_001_src_tready    ;

    generate for (i = 0; i < p_aur_sub_num; i = i + 1) begin : gen_src_ready

        assign w_00n_cdc_tready[i]              = (r_00n_grant == i) && w_001_src_tready        ;

    end
    endgenerate

    always @(posedge i_001_one_clk) begin
        if (i_001_one_rst)
            r_00n_grant                         <= {p_gnt_w{1'b0}}                              ;
        else if ((!r_001_busy) || (w_001_src_tvalid && w_001_src_tready && w_001_src_tlast))
            r_00n_grant                         <= w_00n_next_grant                             ;
    end

    always @(posedge i_001_one_clk) begin
        if (i_001_one_rst)
            r_001_busy                          <= 1'b0                                         ;
        else if (w_001_src_tvalid && w_001_src_tready && w_001_src_tlast)
            r_001_busy                          <= 1'b0                                         ;
        else if (w_001_src_tvalid && w_001_src_tready)
            r_001_busy                          <= 1'b1                                         ;
    end

    always @(posedge i_001_one_clk) begin
        if (i_001_one_rst)
            r_001_one_tx_tvalid                 <= 1'b0                                         ;
        else if (w_001_src_tready)
            r_001_one_tx_tvalid                 <= w_001_src_tvalid                             ;
    end

    always @(posedge i_001_one_clk) begin
        if (w_001_src_tvalid && w_001_src_tready)
            r_064_one_tx_tdata                  <= w_064_src_tdata                              ;
    end

    always @(posedge i_001_one_clk) begin
        if (w_001_src_tvalid && w_001_src_tready)
            r_008_one_tx_tkeep                  <= w_008_src_tkeep                              ;
    end

    always @(posedge i_001_one_clk) begin
        if (w_001_src_tvalid && w_001_src_tready)
            r_001_one_tx_tlast                  <= w_001_src_tlast                              ;
    end

    assign o_001_one_tx_tvalid                  = r_001_one_tx_tvalid                           ;
    assign o_064_one_tx_tdata                   = r_064_one_tx_tdata                            ;
    assign o_008_one_tx_tkeep                   = r_008_one_tx_tkeep                            ;
    assign o_001_one_tx_tlast                   = r_001_one_tx_tlast                            ;

    function [p_gnt_w-1:0] f_rr_grant;
        input      [               p_gnt_w-1:0] i_00n_cur                                       ;
        input      [             p_src_num-1:0] i_00n_req                                       ;

        integer                                 k                                               ;
        integer                                 idx                                             ;
        integer                                 found                                           ;
    begin
        f_rr_grant                              = i_00n_cur                                     ;
        found                                   = 0                                             ;

        for (k = 0; k < p_src_num; k = k + 1) begin
            idx                                 = i_00n_cur + 1 + k                             ;

            if (idx >= p_src_num)
                idx                             = idx - p_src_num                               ;

            if ((!found) && i_00n_req[idx]) begin
                f_rr_grant                      = idx[p_gnt_w-1:0]                              ;
                found                           = 1                                             ;
            end
        end
    end
    endfunction

endmodule
