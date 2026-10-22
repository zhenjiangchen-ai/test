// =================================================================================================
// file name      : ram_rcp_tx.v
// module         : ram_rcp_tx
// function       : pack ram wr/rd response, 32byte align
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// =================================================================================================

`include "../../00_define/define.v"

`timescale 1ns / 1ps

module ram_rcp_tx (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    // rcp cmd
    input                                       i_001_rcp_req                                   ,
    output                                      o_001_rcp_ack                                   ,
    input                                       i_001_rcp_rd                                    , // 1 ram read rsp
    input                                       i_001_rcp_fail                                  ,
    input      [                          15:0] i_016_qid                                       ,
    input      [                          15:0] i_016_dst                                       ,
    input      [                          15:0] i_016_src                                       ,
    input      [                          15:0] i_016_ackn                                      ,
    input      [                          15:0] i_016_msg                                       ,
    input      [                          15:0] i_016_cs                                        ,
    input      [                          23:0] i_024_addr                                      ,
    input      [                          23:0] i_024_len                                       ,
    // ram rd
    input                                       i_001_ram_rd_sop                                ,
    input                                       i_001_ram_rd_eop                                ,
    input                                       i_001_ram_rd_dvld                               ,
    input      [                          63:0] i_064_ram_rd_data                               ,
    output                                      o_001_ram_rd_rdy                                ,
    // loc tx
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
    reg        [                           2:0] r_003_hdr_cnt                                   ;
    reg        [                           1:0] r_002_pad_cnt                                   ;
    reg        [                           1:0] r_002_pad_need                                  ;

    // latch
    reg        [                          15:0] r_016_qid                                       ;
    reg        [                          15:0] r_016_dst                                       ;
    reg        [                          15:0] r_016_src                                       ;
    reg        [                          15:0] r_016_ackn                                      ;
    reg        [                          15:0] r_016_msg                                       ;
    reg        [                          15:0] r_016_cs                                        ;
    reg        [                          23:0] r_024_addr                                      ;
    reg        [                          23:0] r_024_len                                       ;
    reg                                         r_001_rcp_rd                                    ;
    reg                                         r_001_rcp_fail                                  ;
    reg        [                          31:0] r_032_crc                                       ;

    // 2-beat skid
    reg        [                           1:0] r_002_dcnt                                      ;
    reg                                         r_001_eop0                                      ;
    reg                                         r_001_eop1                                      ;
    reg        [                          63:0] r_064_d0                                        ;
    reg        [                          63:0] r_064_d1                                        ;
    wire                                        w_001_ram_push                                  ;
    wire                                        w_001_tx_pop                                    ;

    // hdr word
    wire       [                          63:0] w_064_w0                                        ;
    wire       [                          63:0] w_064_w1                                        ;
    wire       [                          63:0] w_064_w2                                        ;
    wire       [                          31:0] w_032_crc_n                                     ;
    wire       [                          15:0] w_016_data_beat                                 ;
    wire       [                          15:0] w_016_tot                                       ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_001_rcp_ack                        = r_001_rcp_ack                                 ;
    assign o_001_tx_req                         = r_001_tx_req                                  ;
    assign o_001_tx_sop                         = r_001_tx_sop                                  ;
    assign o_001_tx_eop                         = r_001_tx_eop                                  ;
    assign o_001_tx_dvld                        = r_001_tx_dvld                                 ;
    assign o_064_tx_data                        = r_064_tx_data                                 ;
    // 2-beat skid : rdy low only when full and tx not taking
    assign o_001_ram_rd_rdy                     = (r_003_st == p_st_data) &
                                                  ((r_002_dcnt != 2'd2) | i_001_tx_rdy)         ;
    assign w_001_ram_push                       = (r_003_st == p_st_data) & i_001_ram_rd_dvld &
                                                  ((r_002_dcnt != 2'd2) | i_001_tx_rdy)         ;
    assign w_001_tx_pop                         = (r_003_st == p_st_data) & i_001_tx_rdy &
                                                  (r_002_dcnt != 2'd0)                          ;

    assign w_016_data_beat                      = r_001_rcp_rd ? r_024_len[18:3] : 16'd0         ;
    assign w_016_tot                            = 16'd3 + w_016_data_beat                       ; // hdr+meta+ctrl + data
    assign w_064_w0                             = {r_016_qid, r_016_src, r_016_dst, `p_pkt_preamble};
    assign w_064_w1                             = { {13'h0, w_016_tot + {14'h0, r_002_pad_need} + 16'd1, 3'h0},
                                                    r_016_ackn, r_016_msg }                     ;
    assign w_064_w2                             = r_001_rcp_rd ?
                                                  {r_024_len, r_024_addr, r_016_cs} :
                                                  (r_001_rcp_fail ? `p_pkt_fail_64 : `p_pkt_ok_64);

    wire                                        w_001_crc_en                                    ;
    wire       [                          63:0] w_064_crc_dat                                   ;

    assign w_001_crc_en                         = i_001_tx_rdy &
                                                  ((r_003_st == p_st_hdr) |
                                                   ((r_003_st == p_st_data) & (r_002_dcnt != 2'd0)) |
                                                   (r_003_st == p_st_pad))                      ;
    assign w_064_crc_dat                        = (r_003_st == p_st_hdr) ?
                                                  ((r_003_hdr_cnt == 3'd0) ? w_064_w0 :
                                                   ((r_003_hdr_cnt == 3'd1) ? w_064_w1 : w_064_w2)) :
                                                  ((r_003_st == p_st_data) ? r_064_d0 : 64'h0);

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
            if (i_001_tx_rdy & (r_003_hdr_cnt == 3'd2)) begin
                if (r_001_rcp_rd)
                    r_003_st                    <= p_st_data                                    ;
                else
                    r_003_st                    <= p_st_crc                                     ;
            end
        end else if (r_003_st == p_st_data) begin
            if (w_001_tx_pop & r_001_eop0) begin
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
            r_016_cs                            <= 16'h0                                        ;
            r_024_addr                          <= 24'h0                                        ;
            r_024_len                           <= 24'h0                                        ;
            r_001_rcp_rd                        <= 1'b0                                         ;
            r_001_rcp_fail                      <= 1'b0                                         ;
        end else if ((r_003_st == p_st_idle) & i_001_rcp_req & ~r_001_rcp_ack) begin
            r_016_qid                           <= i_016_qid                                    ;
            r_016_dst                           <= i_016_dst                                    ;
            r_016_src                           <= i_016_src                                    ;
            r_016_ackn                          <= i_016_ackn                                   ;
            r_016_msg                           <= i_016_msg                                    ;
            r_016_cs                            <= i_016_cs                                     ;
            r_024_addr                          <= i_024_addr                                   ;
            r_024_len                           <= i_024_len                                    ;
            r_001_rcp_rd                        <= i_001_rcp_rd                                 ;
            r_001_rcp_fail                      <= i_001_rcp_fail                               ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_pad_need                      <= 2'd0                                         ;
        else if (i_001_tx_ack) begin
            // (tot + pad + 1 crc) % 4 == 0
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
            r_003_hdr_cnt                       <= 3'd0                                         ;
        else if (r_003_st != p_st_hdr)
            r_003_hdr_cnt                       <= 3'd0                                         ;
        else if (i_001_tx_rdy)
            r_003_hdr_cnt                       <= r_003_hdr_cnt + 1'b1                         ;
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
            r_001_tx_sop                        <= (r_003_hdr_cnt == 3'd0)                      ;
            r_001_tx_eop                        <= 1'b0                                         ;
            case (r_003_hdr_cnt)
                3'd0    : r_064_tx_data         <= w_064_w0                                     ;
                3'd1    : r_064_tx_data         <= w_064_w1                                     ;
                default : r_064_tx_data         <= w_064_w2                                     ;
            endcase
        end else if ((r_003_st == p_st_data) & w_001_tx_pop) begin
            r_001_tx_dvld                       <= 1'b1                                         ;
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_064_tx_data                       <= r_064_d0                                     ;
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
        end else if (i_001_tx_rdy) begin
            r_001_tx_sop                        <= 1'b0                                         ;
            r_001_tx_eop                        <= 1'b0                                         ;
            r_001_tx_dvld                       <= 1'b0                                         ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_002_dcnt                          <= 2'd0                                         ;
        else if (r_003_st == p_st_idle)
            r_002_dcnt                          <= 2'd0                                         ;
        else if (w_001_ram_push & ~w_001_tx_pop)
            r_002_dcnt                          <= r_002_dcnt + 1'b1                            ;
        else if (~w_001_ram_push & w_001_tx_pop)
            r_002_dcnt                          <= r_002_dcnt - 1'b1                            ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_064_d0                            <= 64'h0                                        ;
            r_064_d1                            <= 64'h0                                        ;
            r_001_eop0                          <= 1'b0                                         ;
            r_001_eop1                          <= 1'b0                                         ;
        end else if (w_001_tx_pop) begin
            if (r_002_dcnt == 2'd2) begin
                r_064_d0                        <= r_064_d1                                     ;
                r_001_eop0                      <= r_001_eop1                                   ;
                if (w_001_ram_push) begin
                    r_064_d1                    <= i_064_ram_rd_data                            ;
                    r_001_eop1                  <= i_001_ram_rd_eop                             ;
                end
            end else if (w_001_ram_push) begin
                r_064_d0                        <= i_064_ram_rd_data                            ;
                r_001_eop0                      <= i_001_ram_rd_eop                             ;
            end
        end else if (w_001_ram_push) begin
            if (r_002_dcnt == 2'd0) begin
                r_064_d0                        <= i_064_ram_rd_data                            ;
                r_001_eop0                      <= i_001_ram_rd_eop                             ;
            end else begin
                r_064_d1                        <= i_064_ram_rd_data                            ;
                r_001_eop1                      <= i_001_ram_rd_eop                             ;
            end
        end
    end

endmodule
