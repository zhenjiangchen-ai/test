// =================================================================================================
// file name      : reg_rcp_tx.v
// module         : reg_rcp_tx
// function       : pack register rsp, single or batch rd
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// 0.0.2        2026/09/21   lxl        batch rd multi beat     semigth
// =================================================================================================

`include "../../00_define/define.v"

`timescale 1ns / 1ps

module reg_rcp_tx (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    // rcp cmd, single wr/rd use addr/data
    input                                       i_001_rcp_req                                   ,
    output                                      o_001_rcp_ack                                   ,
    input      [                          15:0] i_016_qid                                       ,
    input      [                          15:0] i_016_dst                                       ,
    input      [                          15:0] i_016_src                                       ,
    input      [                          15:0] i_016_ackn                                      ,
    input      [                          15:0] i_016_msg                                       ,
    input      [                          31:0] i_032_addr                                      ,
    input      [                          31:0] i_032_data                                      ,
    // batch rd : pop decoder rsp_mem
    input                                       i_001_multi                                     , // 1 batch rd, 0 one beat
    input      [                          15:0] i_016_nbeat                                     , // data beat num when multi
    input      [                          63:0] i_064_beat                                      , // {rd_data, addr}
    output                                      o_001_beat_re                                   , // 1 clk, next beat
    // loc tx
    output                                      o_001_tx_req                                    ,
    input                                       i_001_tx_ack                                    ,
    input                                       i_001_tx_rdy                                    ,
    output                                      o_001_tx_sop                                    ,
    output                                      o_001_tx_eop                                    ,
    output                                      o_001_tx_dvld                                   ,
    output     [                          63:0] o_064_tx_data
);

    localparam p_st_idle                        = 3'd0                                          ;
    localparam p_st_req                         = 3'd1                                          ;
    localparam p_st_hdr                         = 3'd2                                          ;
    localparam p_st_data                        = 3'd3                                          ;
    localparam p_st_pad                         = 3'd4                                          ;
    localparam p_st_crc                         = 3'd5                                          ;

    // fsm / tx
    reg        [                           2:0] r_003_st                                        ;
    reg                                         r_001_rcp_ack                                   ;
    reg                                         r_001_tx_req                                    ;
    reg                                         r_001_tx_sop                                    ;
    reg                                         r_001_tx_eop                                    ;
    reg                                         r_001_tx_dvld                                   ;
    reg        [                          63:0] r_064_tx_data                                   ;
    reg        [                           1:0] r_002_hdr_cnt                                   ;
    reg        [                          15:0] r_016_data_cnt                                  ;
    reg        [                           1:0] r_002_pad_cnt                                   ;
    reg        [                           1:0] r_002_pad_need                                  ;

    // latch
    reg        [                          15:0] r_016_qid                                       ;
    reg        [                          15:0] r_016_dst                                       ;
    reg        [                          15:0] r_016_src                                       ;
    reg        [                          15:0] r_016_ackn                                      ;
    reg        [                          15:0] r_016_msg                                       ;
    reg        [                          31:0] r_032_addr                                      ;
    reg        [                          31:0] r_032_data                                      ;
    reg                                         r_001_multi                                     ;
    reg        [                          15:0] r_016_nbeat                                     ;
    reg        [                          31:0] r_032_crc                                       ;

    // hdr
    wire       [                          63:0] w_064_w0                                        ;
    wire       [                          63:0] w_064_w1                                        ;
    wire       [                          63:0] w_064_w2                                        ;
    wire                                        w_001_wr_rsp                                    ;
    wire       [                          31:0] w_032_crc_n                                     ;
    wire       [                          15:0] w_016_data_beat                                 ;
    wire       [                          15:0] w_016_tot                                       ;
    wire       [                          31:0] w_032_pkt_len                                   ;

    assign o_001_rcp_ack                        = r_001_rcp_ack                                 ;
    assign o_001_tx_req                         = r_001_tx_req                                  ;
    assign o_001_tx_sop                         = r_001_tx_sop                                  ;
    assign o_001_tx_eop                         = r_001_tx_eop                                  ;
    assign o_001_tx_dvld                        = r_001_tx_dvld                                 ;
    assign o_064_tx_data                        = r_064_tx_data                                 ;
    assign o_001_beat_re                        = (r_003_st == p_st_data) & i_001_tx_rdy        ;

    assign w_016_data_beat                      = r_001_multi ? r_016_nbeat : 16'd1             ;
    assign w_016_tot                            = 16'd2 + w_016_data_beat                       ; // hdr+meta + data
    assign w_032_pkt_len                        = {13'h0, w_016_tot + {14'h0, r_002_pad_need} + 16'd1, 3'h0};
    assign w_064_w0                             = {r_016_qid, r_016_src, r_016_dst, `p_pkt_preamble};
    assign w_064_w1                             = {w_032_pkt_len, r_016_ackn, r_016_msg}        ;
    assign w_001_wr_rsp                         = (r_016_msg == `p_msg_reg_wr_rsp) |
                                                  (r_016_msg == `p_msg_reg_bwr_rsp)             ;
    assign w_064_w2                             = r_001_multi ? i_064_beat :
                                                  (w_001_wr_rsp ?
                                                   {r_032_data, r_032_data} :
                                                   {r_032_data, r_032_addr})                    ;

    wire                                        w_001_crc_en                                    ;
    wire       [                          63:0] w_064_crc_dat                                   ;

    assign w_001_crc_en                         = i_001_tx_rdy &
                                                  ((r_003_st == p_st_hdr) |
                                                   (r_003_st == p_st_data) |
                                                   (r_003_st == p_st_pad))                      ;
    assign w_064_crc_dat                        = (r_003_st == p_st_hdr) ?
                                                  ((r_002_hdr_cnt == 2'd0) ? w_064_w0 : w_064_w1) :
                                                  ((r_003_st == p_st_data) ? w_064_w2 : 64'h0)  ;

    // crc32

    crc32_d64 u00_crc (
        .i_032_crc                              (r_032_crc                                      ),
        .i_064_data                             (w_064_crc_dat                                  ),
        .o_032_crc                              (w_032_crc_n                                    )
    );

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_003_st                            <= p_st_idle                                    ;
        else if (r_003_st == p_st_idle) begin
            if (i_001_rcp_req & ~r_001_rcp_ack)
                r_003_st                        <= p_st_req                                     ;
        end else if (r_003_st == p_st_req) begin
            if (i_001_tx_ack)
                r_003_st                        <= p_st_hdr                                     ;
        end else if (r_003_st == p_st_hdr) begin
            if (i_001_tx_rdy & (r_002_hdr_cnt == 2'd1))
                r_003_st                        <= p_st_data                                    ;
        end else if (r_003_st == p_st_data) begin
            if (i_001_tx_rdy & (r_016_data_cnt + 16'd1 == w_016_data_beat)) begin
                if (r_002_pad_need != 2'd0)
                    r_003_st                    <= p_st_pad                                     ;
                else
                    r_003_st                    <= p_st_crc                                     ;
            end
        end else if (r_003_st == p_st_pad) begin
            if (i_001_tx_rdy & (r_002_pad_cnt + 1'b1 == r_002_pad_need))
                r_003_st                        <= p_st_crc                                     ;
        end else if (r_003_st == p_st_crc) begin
            if (i_001_tx_rdy)
                r_003_st                        <= p_st_idle                                    ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_016_qid                           <= 16'h0                                        ;
            r_016_dst                           <= 16'h0                                        ;
            r_016_src                           <= 16'h0                                        ;
            r_016_ackn                          <= 16'h0                                        ;
            r_016_msg                           <= 16'h0                                        ;
            r_032_addr                          <= 32'h0                                        ;
            r_032_data                          <= 32'h0                                        ;
            r_001_multi                         <= 1'b0                                         ;
            r_016_nbeat                         <= 16'd1                                        ;
        end else if ((r_003_st == p_st_idle) & i_001_rcp_req & ~r_001_rcp_ack) begin
            r_016_qid                           <= i_016_qid                                    ;
            r_016_dst                           <= i_016_dst                                    ;
            r_016_src                           <= i_016_src                                    ;
            r_016_ackn                          <= i_016_ackn                                   ;
            r_016_msg                           <= i_016_msg                                    ;
            r_032_addr                          <= i_032_addr                                   ;
            r_032_data                          <= i_032_data                                   ;
            r_001_multi                         <= i_001_multi                                  ;
            r_016_nbeat                         <= (i_016_nbeat == 16'h0) ? 16'd1 : i_016_nbeat ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_pad_need                      <= 2'd0                                         ;
        else if (i_001_tx_ack) begin
            case ((w_016_tot + 16'd1) & 16'd3)
                16'd0   : r_002_pad_need        <= 2'd0                                         ;
                16'd1   : r_002_pad_need        <= 2'd3                                         ;
                16'd2   : r_002_pad_need        <= 2'd2                                         ;
                default : r_002_pad_need        <= 2'd1                                         ;
            endcase
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_hdr_cnt                       <= 2'd0                                         ;
        else if (r_003_st != p_st_hdr)
            r_002_hdr_cnt                       <= 2'd0                                         ;
        else if (i_001_tx_rdy)
            r_002_hdr_cnt                       <= r_002_hdr_cnt + 1'b1                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_016_data_cnt                      <= 16'h0                                        ;
        else if (r_003_st != p_st_data)
            r_016_data_cnt                      <= 16'h0                                        ;
        else if (i_001_tx_rdy)
            r_016_data_cnt                      <= r_016_data_cnt + 1'b1                        ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_pad_cnt                       <= 2'd0                                         ;
        else if (r_003_st != p_st_pad)
            r_002_pad_cnt                       <= 2'd0                                         ;
        else if (i_001_tx_rdy)
            r_002_pad_cnt                       <= r_002_pad_cnt + 1'b1                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_tx_req                        <= 1'b0                                         ;
        else if (r_003_st == p_st_req)
            r_001_tx_req                        <= ~i_001_tx_ack                                ;
        else
            r_001_tx_req                        <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_rcp_ack                       <= 1'b0                                         ;
        else
            r_001_rcp_ack                       <= (r_003_st == p_st_crc) & i_001_tx_rdy        ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_032_crc                           <= 32'hffff_ffff                                ;
        else if (r_003_st == p_st_idle)
            r_032_crc                           <= 32'hffff_ffff                                ;
        else if (w_001_crc_en)
            r_032_crc                           <= w_032_crc_n                                  ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_001_tx_dvld                       <= 1'b0                                         ;
            r_064_tx_data                       <= 64'h0                                        ;
        end else if ((r_003_st == p_st_hdr) & i_001_tx_rdy) begin
            r_001_tx_dvld                       <= 1'b1                                         ;
            r_001_tx_sop                        <= (r_002_hdr_cnt == 2'd0)                      ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_064_tx_data                       <= (r_002_hdr_cnt == 2'd0) ? w_064_w0 : w_064_w1;
        end else if ((r_003_st == p_st_data) & i_001_tx_rdy) begin
            r_001_tx_dvld                       <= 1'b1                                         ;
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_064_tx_data                       <= w_064_w2                                     ;
        end else if ((r_003_st == p_st_pad) & i_001_tx_rdy) begin
            r_001_tx_dvld                       <= 1'b1                                         ;
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_064_tx_data                       <= 64'h0                                        ;
        end else if ((r_003_st == p_st_crc) & i_001_tx_rdy) begin
            r_001_tx_dvld                       <= 1'b1                                         ;
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b1                                         ;
            r_064_tx_data                       <= {~r_032_crc, `p_pkt_idle}                    ;
        end else begin
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_001_tx_dvld                       <= 1'b0                                         ;
        end
    end

endmodule
