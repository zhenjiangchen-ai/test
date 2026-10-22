// =================================================================================================
// file name      : ddr_rcp_tx.v
// module         : ddr_rcp_tx
// function       : pack ddr response stub
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// =================================================================================================

`include "../../00_define/define.v"

`timescale 1ns / 1ps

module ddr_rcp_tx (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    input                                       i_001_rcp_req                                   ,
    output                                      o_001_rcp_ack                                   ,
    input      [                          15:0] i_016_qid                                       ,
    input      [                          15:0] i_016_dst                                       ,
    input      [                          15:0] i_016_src                                       ,
    input      [                          15:0] i_016_ackn                                      ,
    input      [                          15:0] i_016_msg                                       ,
    input                                       i_001_rcp_fail                                  ,
    output                                      o_001_tx_req                                    ,
    input                                       i_001_tx_ack                                    ,
    input                                       i_001_tx_rdy                                    ,
    output                                      o_001_tx_sop                                    ,
    output                                      o_001_tx_eop                                    ,
    output                                      o_001_tx_dvld                                   ,
    output     [                          63:0] o_064_tx_data
);

    // =============================================================================
    // internal signal define
    // =============================================================================

    localparam p_st_idle                        = 2'd0                                          ;
    localparam p_st_req                         = 2'd1                                          ;
    localparam p_st_send                        = 2'd2                                          ;

    reg        [                           1:0] r_002_st                                        ;
    reg                                         r_001_rcp_ack                                   ;
    reg                                         r_001_tx_req                                    ;
    reg                                         r_001_tx_sop                                    ;
    reg                                         r_001_tx_eop                                    ;
    reg                                         r_001_tx_dvld                                   ;
    reg        [                          63:0] r_064_tx_data                                   ;
    reg        [                           1:0] r_002_cnt                                       ;
    reg        [                          15:0] r_016_qid                                       ;
    reg        [                          15:0] r_016_dst                                       ;
    reg        [                          15:0] r_016_src                                       ;
    reg        [                          15:0] r_016_ackn                                      ;
    reg        [                          15:0] r_016_msg                                       ;
    reg                                         r_001_rcp_fail                                  ;
    reg        [                          31:0] r_032_crc                                       ;

    wire       [                          63:0] w_064_w0                                        ;
    wire       [                          63:0] w_064_w1                                        ;
    wire       [                          63:0] w_064_w2                                        ;
    wire       [                          31:0] w_032_crc0                                      ;
    wire       [                          31:0] w_032_crc1                                      ;
    wire       [                          31:0] w_032_crc2                                      ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_001_rcp_ack                        = r_001_rcp_ack                                 ;
    assign o_001_tx_req                         = r_001_tx_req                                  ;
    assign o_001_tx_sop                         = r_001_tx_sop                                  ;
    assign o_001_tx_eop                         = r_001_tx_eop                                  ;
    assign o_001_tx_dvld                        = r_001_tx_dvld                                 ;
    assign o_064_tx_data                        = r_064_tx_data                                 ;

    assign w_064_w0                             = {r_016_qid, r_016_src, r_016_dst, `p_pkt_preamble};
    assign w_064_w1                             = {32'd32, r_016_ackn, r_016_msg}               ;
    assign w_064_w2                             = r_001_rcp_fail ? `p_pkt_fail_64 : `p_pkt_ok_64 ;

    crc32_d64 u00_crc0 (
        .i_032_crc                              (32'hffff_ffff                                  ),
        .i_064_data                             (w_064_w0                                       ),
        .o_032_crc                              (w_032_crc0                                     )
    );

    crc32_d64 u01_crc1 (
        .i_032_crc                              (w_032_crc0                                     ),
        .i_064_data                             (w_064_w1                                       ),
        .o_032_crc                              (w_032_crc1                                     )
    );

    crc32_d64 u02_crc2 (
        .i_032_crc                              (w_032_crc1                                     ),
        .i_064_data                             (w_064_w2                                       ),
        .o_032_crc                              (w_032_crc2                                     )
    );

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_st                            <= p_st_idle                                    ;
        else if (r_002_st == p_st_idle) begin
            if (i_001_rcp_req & ~r_001_rcp_ack)
                r_002_st                        <= p_st_req                                     ;
        end else if (r_002_st == p_st_req) begin
            if (i_001_tx_ack)
                r_002_st                        <= p_st_send                                    ;
        end else if (r_002_st == p_st_send) begin
            if (r_001_tx_eop & i_001_tx_rdy)
                r_002_st                        <= p_st_idle                                    ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_016_qid                           <= 16'h0                                        ;
            r_016_dst                           <= 16'h0                                        ;
            r_016_src                           <= 16'h0                                        ;
            r_016_ackn                          <= 16'h0                                        ;
            r_016_msg                           <= 16'h0                                        ;
            r_001_rcp_fail                      <= 1'b0                                         ;
        end else if ((r_002_st == p_st_idle) & i_001_rcp_req & ~r_001_rcp_ack) begin
            r_016_qid                           <= i_016_qid                                    ;
            r_016_dst                           <= i_016_dst                                    ;
            r_016_src                           <= i_016_src                                    ;
            r_016_ackn                          <= i_016_ackn                                   ;
            r_016_msg                           <= i_016_msg                                    ;
            r_001_rcp_fail                      <= i_001_rcp_fail                               ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_032_crc                           <= 32'h0                                        ;
        else
            r_032_crc                           <= ~w_032_crc2                                  ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_tx_req                        <= 1'b0                                         ;
        else if (r_002_st == p_st_req)
            r_001_tx_req                        <= ~i_001_tx_ack                                ;
        else
            r_001_tx_req                        <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_rcp_ack                       <= 1'b0                                         ;
        else
            r_001_rcp_ack                       <= (r_002_st == p_st_send) & r_001_tx_eop & i_001_tx_rdy;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_cnt                           <= 2'd0                                         ;
        else if (r_002_st != p_st_send)
            r_002_cnt                           <= 2'd0                                         ;
        else if (i_001_tx_rdy)
            r_002_cnt                           <= r_002_cnt + 1'b1                             ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_001_tx_dvld                       <= 1'b0                                         ;
            r_064_tx_data                       <= 64'h0                                        ;
        end else if ((r_002_st == p_st_send) & i_001_tx_rdy) begin
            r_001_tx_dvld                       <= 1'b1                                         ;
            r_001_tx_sop                        <= (r_002_cnt == 2'd0)                          ;
            r_001_tx_eop                        <= (r_002_cnt == 2'd3)                          ;
            case (r_002_cnt)
                2'd0    : r_064_tx_data         <= w_064_w0                                     ;
                2'd1    : r_064_tx_data         <= w_064_w1                                     ;
                2'd2    : r_064_tx_data         <= w_064_w2                                     ;
                default : r_064_tx_data         <= {r_032_crc, `p_pkt_idle}                     ;
            endcase
        end else begin
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_001_tx_dvld                       <= 1'b0                                         ;
        end
    end

endmodule
