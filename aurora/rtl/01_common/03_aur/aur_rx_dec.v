// =================================================================================================
// file name      : aur_rx_dec.v
// module         : aur_rx_dec
// function       : unpack sop stream to reg ram ddr cmd
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// 0.0.2        2026/09/22   lxl        reg batch 16KB sfifo    semigth
// 0.0.3        2026/09/22   lxl        fifo wr pipe 1 clk      semigth
// 0.0.4        2026/09/23   lxl        split addr/ram always   semigth
// 0.0.5        2026/09/23   lxl        fsm one-hot             semigth
// =================================================================================================

`include "../../00_define/define.v"
`include "../hsp_pkt_hdr.vh"

`timescale 1ns / 1ps

module aur_rx_dec (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    // rx sop
    output                                      o_001_aur_rx_rdy                                ,
    input                                       i_001_aur_rx_sop                                ,
    input                                       i_001_aur_rx_eop                                ,
    input                                       i_001_aur_rx_dvld                               ,
    input      [                          63:0] i_064_aur_rx_data                               ,
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
    // ram wr
    output                                      o_001_ram_wr_req                                ,
    output     [                          23:0] o_024_ram_wr_addr                               ,
    output     [                          23:0] o_024_ram_wr_size                               , // byte len
    output     [                          15:0] o_016_ram_wr_bsel                               , // encoded chip 0..65535
    output     [                          63:0] o_064_ram_wr_data                               ,
    output                                      o_001_ram_wr_dvld                               ,
    output                                      o_001_ram_wr_sop                                ,
    output                                      o_001_ram_wr_eop                                ,
    input                                       i_001_ram_wr_fail                               ,
    // ram rd
    output                                      o_001_ram_rd_req                                ,
    output     [                          23:0] o_024_ram_rd_addr                               ,
    output     [                          23:0] o_024_ram_rd_size                               , // byte len
    output     [                          15:0] o_016_ram_rd_bsel                               ,
    input                                       i_001_ram_cbuf_rdy                              ,
    input                                       i_001_ram_rd_sop                                ,
    input                                       i_001_ram_rd_eop                                ,
    input                                       i_001_ram_rd_dvld                               ,
    input      [                          63:0] i_064_ram_rd_data                               ,
    // reg rcp : receipt pack start
    output                                      o_001_reg_rcp_req                               ,
    input                                       i_001_reg_rcp_ack                               ,
    output     [                          15:0] o_016_reg_rcp_qid                               ,
    output     [                          15:0] o_016_reg_rcp_dst                               , // reply dest = req src (host)
    output     [                          15:0] o_016_reg_rcp_src                               ,
    output     [                          15:0] o_016_reg_rcp_ackn                              , // frame ack
    output     [                          15:0] o_016_reg_rcp_msg                               ,
    output     [                          31:0] o_032_reg_rcp_addr                              ,
    output     [                          31:0] o_032_reg_rcp_data                              ,
    // ram rcp
    output                                      o_001_ram_rcp_req                               ,
    input                                       i_001_ram_rcp_ack                               ,
    output     [                          15:0] o_016_ram_rcp_qid                               ,
    output     [                          15:0] o_016_ram_rcp_dst                               ,
    output     [                          15:0] o_016_ram_rcp_src                               ,
    output     [                          15:0] o_016_ram_rcp_ackn                              ,
    output     [                          15:0] o_016_ram_rcp_msg                               ,
    output     [                          15:0] o_016_ram_rcp_cs                                ,
    output     [                          23:0] o_024_ram_rcp_addr                              ,
    output     [                          23:0] o_024_ram_rcp_len                               ,
    output                                      o_001_ram_rcp_rd                                , // 1 = ram read rsp
    output                                      o_001_ram_rcp_fail                              ,
    // ddr rcp
    output                                      o_001_ddr_rcp_req                               ,
    input                                       i_001_ddr_rcp_ack                               ,
    output     [                          15:0] o_016_ddr_rcp_qid                               ,
    output     [                          15:0] o_016_ddr_rcp_dst                               ,
    output     [                          15:0] o_016_ddr_rcp_src                               ,
    output     [                          15:0] o_016_ddr_rcp_ackn                              ,
    output     [                          15:0] o_016_ddr_rcp_msg                               ,
    output                                      o_001_ddr_rcp_fail                              ,
    // batch rd buf -> reg_rcp_tx
    output                                      o_001_reg_rcp_multi                             , // 1 = batch rd
    output     [                          15:0] o_016_reg_rcp_nbeat                             , // op num
    output     [                          63:0] o_064_reg_rcp_beat                              , // {rd_data, addr}
    input                                       i_001_reg_rcp_beat_re                             // pop rsp fifo
);

    // ********************************************************************************************
    // localparameter declare
    // ********************************************************************************************

    localparam p_st_idle                        = 0                                             ; //  idle, wait sop
    localparam p_st_meta                        = 1                                             ; //  latch len/ack/msg
    localparam p_st_body                        = 2                                             ; //  latch ctrl and payload
    localparam p_st_op                          = 3                                             ; //  issue local op
    localparam p_st_wait                        = 4                                             ; //  wait local ack
    localparam p_st_rcp                         = 5                                             ; //  start reply pkt
    localparam p_st_w                           = 6                                             ; //  one-hot width

    // =============================================================================
    // internal signal define
    // =============================================================================

    // fsm / hdr

    reg        [                    p_st_w-1:0] r_006_st                                        ; //  pkt fsm one-hot

    reg        [                          15:0] r_016_qid                                       ; //  queue id
    reg        [                          15:0] r_016_dst                                       ; //  dest node
    reg        [                          15:0] r_016_src                                       ; //  src node
    reg        [                          31:0] r_032_len                                       ; //  pkt byte len
    reg        [                          15:0] r_016_ackn                                      ; //  frame ack no
    reg        [                          15:0] r_016_msg                                       ; //  msg type
    reg        [                          31:0] r_032_addr                                      ; //  first op / ram addr
    reg        [                          31:0] r_032_data                                      ; //  first op wr data
    reg        [                          15:0] r_016_ram_cs                                    ; // ram chip select
    reg        [                          23:0] r_024_ram_len                                   ; // ram byte length
    reg        [                          23:0] r_024_ram_addr                                  ; // ram start addr
    reg        [                          20:0] r_021_beat_left                                 ; //  ram wr beats left

    reg                                         r_001_need_rsp                                  ; //  need reply pkt
    reg                                         r_001_is_rd                                     ; //  read cmd
    reg                                         r_001_is_ram                                    ; // ram cmd
    reg                                         r_001_is_ddr                                    ; // ddr cmd

    // reg

    reg                                         r_001_reg_wr_req                                ;
    reg                                         r_001_reg_rd_req                                ;
    reg        [                          31:0] r_032_reg_wr_data                               ;
    reg        [                          31:0] r_032_reg_addr                                  ;

    // ram wr

    reg                                         r_001_ram_wr_req                                ; //  wr req 1clk pulse
    reg                                         r_001_ram_wr_dvld                               ; //  wr data valid
    reg                                         r_001_ram_wr_sop                                ; //  wr data sop
    reg                                         r_001_ram_wr_eop                                ; //  wr data eop
    reg        [                          63:0] r_064_ram_wr_data                               ;
    reg        [                          23:0] r_024_ram_wr_addr                               ;
    reg        [                          23:0] r_024_ram_wr_size                               ;
    reg        [                          15:0] r_016_ram_wr_bsel                               ;

    // ram rd

    reg                                         r_001_ram_rd_req                                ;
    reg        [                          23:0] r_024_ram_rd_addr                               ;
    reg        [                          23:0] r_024_ram_rd_size                               ;
    reg        [                          15:0] r_016_ram_rd_bsel                               ;

    // rsp

    reg                                         r_001_reg_rcp_req                               ;
    reg                                         r_001_ram_rcp_req                               ;
    reg                                         r_001_ddr_rcp_req                               ;

    reg        [                          15:0] r_016_reg_rcp_msg                               ;
    reg        [                          31:0] r_032_reg_rcp_data                              ;
    reg                                         r_001_ram_rcp_rd                                ; // ram rcp is read
    reg                                         r_001_ctrl_got                                  ; //  ctrl word got

    reg        [                           7:0] r_008_time_out                                  ; //  timeout cnt
    reg                                         r_001_time_out                                  ; // timeout
    reg                                         r_001_rcp_fail                                  ;
    reg        [                          31:0] r_032_rx_crc                                    ;

    // batch op : sfifo 64b x 2048 = 16KB, ram/ddr not use

    reg                                         r_001_is_batch                                  ; //  multi-reg pkt
    reg        [                          11:0] r_012_op_n                                      ; //  ops pushed
    reg        [                          11:0] r_012_op_r                                      ; //  ops done
    reg        [                          11:0] r_012_nbeat                                     ; //  rcp beat num

    wire                                        w_001_rx_rdy                                    ; //  may accept rx
    wire                                        w_001_rx                                        ; //  accepted rx beat

    wire                                        w_001_reg_done                                  ; //  localbus wr/rd ack
    wire                                        w_001_ram_rd_go                                 ; // ram rd buf rdy

    wire                                        w_001_op_push                                   ; //  push op fifo
    wire                                        w_001_op_ren                                    ; //  pop op fifo
    wire                                        w_001_op_full                                   ;
    wire                                        w_001_op_empty                                  ;
    wire       [                          63:0] w_064_op_dout                                   ;

    wire                                        w_001_rsp_push                                  ; //  push rsp fifo
    wire                                        w_001_crc_en                                    ;
    wire                                        w_001_crc_bad                                   ;
    wire       [                          31:0] w_032_crc_in                                    ;
    wire       [                          31:0] w_032_crc_n                                     ;
    wire                                        w_001_rsp_ren                                   ; //  pop rsp fifo
    wire                                        w_001_rsp_full                                  ;
    wire                                        w_001_rsp_empty                                 ;
    wire       [                          63:0] w_064_rsp_dout                                  ;

    wire                                        w_001_op_wr_rst_busy                            ;
    wire                                        w_001_op_rd_rst_busy                            ;

    wire                                        w_001_rsp_wr_rst_busy                           ;
    wire                                        w_001_rsp_rd_rst_busy                           ;

    wire                                        w_001_fifo_rst_busy                             ; // fifo in reset
    wire                                        w_001_op_dout_rdy                               ; //  fwft dout stable
    wire                                        w_001_rsp_dout_rdy                              ; //  fwft rsp dout stable
    reg                                         r_001_op_vld                                    ; // ~empty dly
    reg                                         r_001_op_ren_d1                                 ;
    reg                                         r_001_rsp_vld                                   ;
    reg                                         r_001_rsp_ren_d1                                ;

    // fifo wr pipe

    reg                                         r_001_op_wen                                    ; //  op fifo wr en, +1 clk
    reg        [                          63:0] r_064_op_din                                    ; //  op fifo din, +1 clk
    reg                                         r_001_rsp_wen                                   ; //  rsp fifo wr en, +1 clk
    reg        [                          63:0] r_064_rsp_din                                   ; //  rsp fifo din, +1 clk

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_001_aur_rx_rdy                     = w_001_rx_rdy                                  ;

    assign o_001_reg_wr_req                     = r_001_reg_wr_req                              ;
    assign o_032_reg_wr_data                    = r_032_reg_wr_data                             ;
    assign o_001_reg_rd_req                     = r_001_reg_rd_req                              ;
    assign o_032_reg_addr                       = r_032_reg_addr                                ;

    assign o_001_ram_wr_req                     = r_001_ram_wr_req                              ;
    assign o_024_ram_wr_addr                    = r_024_ram_wr_addr                             ;
    assign o_024_ram_wr_size                    = r_024_ram_wr_size                             ;
    assign o_016_ram_wr_bsel                    = r_016_ram_wr_bsel                             ;
    assign o_064_ram_wr_data                    = r_064_ram_wr_data                             ;
    assign o_001_ram_wr_dvld                    = r_001_ram_wr_dvld                             ;
    assign o_001_ram_wr_sop                     = r_001_ram_wr_sop                              ;
    assign o_001_ram_wr_eop                     = r_001_ram_wr_eop                              ;
    assign o_001_ram_rd_req                     = r_001_ram_rd_req                              ;
    assign o_024_ram_rd_addr                    = r_024_ram_rd_addr                             ;
    assign o_024_ram_rd_size                    = r_024_ram_rd_size                             ;
    assign o_016_ram_rd_bsel                    = r_016_ram_rd_bsel                             ;

    assign o_001_reg_rcp_req                    = r_001_reg_rcp_req                             ;
    assign o_016_reg_rcp_qid                    = r_016_qid                                     ;
    assign o_016_reg_rcp_dst                    = r_016_src                                     ; // host
    assign o_016_reg_rcp_src                    = r_016_dst                                     ; // fpga
    assign o_016_reg_rcp_ackn                   = r_016_ackn                                    ;
    assign o_016_reg_rcp_msg                    = r_016_reg_rcp_msg                             ;
    assign o_032_reg_rcp_addr                   = r_032_addr                                    ;
    assign o_032_reg_rcp_data                   = r_032_reg_rcp_data                            ;

    assign o_001_ram_rcp_req                    = r_001_ram_rcp_req                             ;
    assign o_016_ram_rcp_qid                    = r_016_qid                                     ;
    assign o_016_ram_rcp_dst                    = r_016_src                                     ; // host
    assign o_016_ram_rcp_src                    = r_016_dst                                     ; // fpga
    assign o_016_ram_rcp_ackn                   = r_016_ackn                                    ;
    assign o_016_ram_rcp_msg                    = r_001_ram_rcp_rd ? `p_msg_ram_rd_rsp : `p_msg_ram_wr_rsp;
    assign o_016_ram_rcp_cs                     = r_016_ram_cs                                  ;
    assign o_024_ram_rcp_addr                   = r_024_ram_addr                                ;
    assign o_024_ram_rcp_len                    = r_024_ram_len                                 ;
    assign o_001_ram_rcp_rd                     = r_001_ram_rcp_rd                              ;
    assign o_001_ram_rcp_fail                   = r_001_rcp_fail                                ;

    assign o_001_ddr_rcp_req                    = r_001_ddr_rcp_req                             ;
    assign o_016_ddr_rcp_qid                    = r_016_qid                                     ;
    assign o_016_ddr_rcp_dst                    = r_016_src                                     ; // host
    assign o_016_ddr_rcp_src                    = r_016_dst                                     ; // fpga
    assign o_016_ddr_rcp_ackn                   = r_016_ackn                                    ;
    assign o_016_ddr_rcp_msg                    = `p_msg_ddr_wr_rsp                             ;
    assign o_001_ddr_rcp_fail                   = r_001_rcp_fail                                ;

    assign o_001_reg_rcp_multi                  = r_001_is_batch & r_001_is_rd                  ;
    assign o_016_reg_rcp_nbeat                  = {4'h0, r_012_nbeat}                           ;
    assign o_064_reg_rcp_beat                   = w_001_rsp_empty ? 64'h0 : w_064_rsp_dout      ;

    assign w_001_rx                             = i_001_aur_rx_dvld & w_001_rx_rdy              ;
    assign w_001_crc_en                         = w_001_rx & ~i_001_aur_rx_eop                  ;
    assign w_032_crc_in                         = (w_001_rx & i_001_aur_rx_sop) ? 32'hffff_ffff : r_032_rx_crc                ;
    assign w_001_crc_bad                        = w_001_rx & i_001_aur_rx_eop & (i_064_aur_rx_data[63:32] != ~r_032_rx_crc)   ;

    crc32_d64 u00_rx_crc (
        .i_032_crc                              (w_032_crc_in                                   ),
        .i_064_data                             (i_064_aur_rx_data                              ),
        .o_032_crc                              (w_032_crc_n                                    )
    );
    assign w_001_reg_done                       = i_001_reg_wr_ack | i_001_reg_rd_ack           ;
    assign w_001_ram_rd_go                      = i_001_ram_cbuf_rdy                            ;
    assign w_001_fifo_rst_busy                  = w_001_op_wr_rst_busy | w_001_op_rd_rst_busy | w_001_rsp_wr_rst_busy | w_001_rsp_rd_rst_busy ;
    assign w_001_op_dout_rdy                    = ~w_001_op_empty & r_001_op_vld & ~r_001_op_ren_d1;
    assign w_001_rsp_dout_rdy                   = ~w_001_rsp_empty & r_001_rsp_vld & ~r_001_rsp_ren_d1;

    // idle only when fifo empty, avoid sop overlap with leftover pop

    assign w_001_rx_rdy                         = ~w_001_fifo_rst_busy &
                                                  (((r_006_st[p_st_idle]) & w_001_op_empty & w_001_rsp_empty) |
                                                   (r_006_st[p_st_meta]) |
                                                   ((r_006_st[p_st_body]) & ~w_001_op_full));

    // push {data,addr} in body ; ram/ddr payload not enter

    assign w_001_op_push                        = (r_006_st[p_st_body]) & w_001_rx & ~i_001_aur_rx_eop &
                                                  ~r_001_is_ram & ~r_001_is_ddr & ~w_001_op_full &
                                                  ~w_001_fifo_rst_busy &
                                                  (i_064_aur_rx_data != 64'h0) &
                                                  (i_064_aur_rx_data != {`p_pkt_idle, `p_pkt_idle});

    assign w_001_op_ren                         = ((r_006_st[p_st_wait]) & w_001_reg_done & ~w_001_op_empty) |
                                                  ((r_006_st[p_st_idle]) & w_001_op_dout_rdy);

    assign w_001_rsp_push                       = i_001_reg_rd_ack & ~w_001_rsp_full & ~w_001_fifo_rst_busy;
    assign w_001_rsp_ren                        = (i_001_reg_rcp_beat_re & ~w_001_rsp_empty) | ((r_006_st[p_st_idle]) & w_001_rsp_dout_rdy);

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_op_wen                        <= 1'b0                                         ;
            r_064_op_din                        <= 64'h0                                        ;
            r_001_rsp_wen                       <= 1'b0                                         ;
            r_064_rsp_din                       <= 64'h0                                        ;
        end else begin
            r_001_op_wen                        <= w_001_op_push                                ;
            r_001_rsp_wen                       <= w_001_rsp_push                               ;

            if (w_001_op_push)
                r_064_op_din                    <= i_064_aur_rx_data                            ;

            if (w_001_rsp_push)
                r_064_rsp_din                   <= {i_032_reg_rd_data, r_032_reg_addr}          ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_op_vld                        <= 1'b0                                         ;
            r_001_op_ren_d1                     <= 1'b0                                         ;
            r_001_rsp_vld                       <= 1'b0                                         ;
            r_001_rsp_ren_d1                    <= 1'b0                                         ;
        end else begin
            r_001_op_vld                        <= ~w_001_op_empty                              ;
            r_001_op_ren_d1                     <= w_001_op_ren                                 ;
            r_001_rsp_vld                       <= ~w_001_rsp_empty                             ;
            r_001_rsp_ren_d1                    <= w_001_rsp_ren                                ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_006_st                            <= 6'd1 << p_st_idle                            ;
        else begin
            case (1'b1)
                r_006_st[p_st_idle] : begin
                    if (w_001_rx & i_001_aur_rx_sop)
                        r_006_st                <= 6'd1 << p_st_meta                            ;
                end

                r_006_st[p_st_meta] : begin
                    if (w_001_rx)
                        r_006_st                <= 6'd1 << p_st_body                            ;
                end

                r_006_st[p_st_body] : begin
                    if (w_001_rx & i_001_aur_rx_eop)
                        r_006_st                <= 6'd1 << p_st_op                              ;
                end

                r_006_st[p_st_op] : begin
                    if (r_001_is_ram | r_001_is_ddr)
                        r_006_st                <= 6'd1 << p_st_wait                            ;
                    else if (w_001_op_dout_rdy & i_001_reg_rdy)
                        r_006_st                <= 6'd1 << p_st_wait                            ;
                    else if (r_001_time_out)
                        r_006_st                <= r_001_need_rsp ? (6'd1 << p_st_rcp) : (6'd1 << p_st_idle);
                end

                r_006_st[p_st_wait] : begin
                    if (r_001_is_ddr)
                        r_006_st                <= r_001_need_rsp ? (6'd1 << p_st_rcp) : (6'd1 << p_st_idle);
                    else if (r_001_is_ram)
                        r_006_st                <= r_001_need_rsp ? (6'd1 << p_st_rcp) : (6'd1 << p_st_idle);
                    else if (w_001_reg_done | r_001_time_out) begin
                        if ((r_012_op_r + 12'd1 == r_012_op_n) | r_001_time_out)
                            r_006_st            <= r_001_need_rsp ? (6'd1 << p_st_rcp) : (6'd1 << p_st_idle);
                        else
                            r_006_st            <= 6'd1 << p_st_op                              ;
                    end
                end

                r_006_st[p_st_rcp] : begin
                    if (i_001_reg_rcp_ack | i_001_ram_rcp_ack | i_001_ddr_rcp_ack | (r_001_time_out & ~r_001_is_ram))
                        r_006_st                <= 6'd1 << p_st_idle                            ;
                end

                default :
                    r_006_st                    <= 6'd1 << p_st_idle                            ;
            endcase
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_008_time_out                      <= 8'h0                                         ;
        else if ((r_006_st[p_st_wait]) || (r_006_st[p_st_rcp]))
            r_008_time_out                      <= r_008_time_out + 1'b1                        ;
        else if ((r_006_st[p_st_op]) & ~w_001_op_dout_rdy & ~r_001_is_ram & ~r_001_is_ddr)
            r_008_time_out                      <= r_008_time_out + 1'b1                        ;
        else
            r_008_time_out                      <= 8'h0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_time_out                      <= 'b0                                          ;
        else
            r_001_time_out                      <= (r_008_time_out == 8'hfe)                    ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst | r_006_st[p_st_idle])
            r_001_rcp_fail                      <= 1'b0                                         ;
        else if (i_001_reg_fail | r_001_time_out | i_001_ram_wr_fail | w_001_crc_bad)
            r_001_rcp_fail                      <= 1'b1                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_032_rx_crc                        <= 32'hffff_ffff                                ;
        else if (w_001_crc_en)
            r_032_rx_crc                        <= w_032_crc_n                                  ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_016_qid                           <= 16'h0                                        ;
            r_016_dst                           <= 16'h0                                        ;
            r_016_src                           <= 16'h0                                        ;
        end else if (w_001_rx & i_001_aur_rx_sop) begin
            r_016_qid                           <= i_064_aur_rx_data[`hsp_hdr_qid_lsb      +: `hsp_hdr_qid_w];
            r_016_dst                           <= i_064_aur_rx_data[`hsp_hdr_dst_node_lsb +: 16];
            r_016_src                           <= i_064_aur_rx_data[`hsp_hdr_src_node_lsb +: 16];
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_032_len                           <= 32'h0                                        ;
            r_016_ackn                          <= 16'h0                                        ;
            r_016_msg                           <= 16'h0                                        ;
        end else if ((r_006_st[p_st_meta]) & w_001_rx) begin
            r_032_len                           <= i_064_aur_rx_data[63:32]                     ;
            r_016_ackn                          <= i_064_aur_rx_data[31:16]                     ;
            r_016_msg                           <= i_064_aur_rx_data[15: 0]                     ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_need_rsp                      <= 1'b0                                         ;
            r_001_is_rd                         <= 1'b0                                         ;
            r_001_is_ram                        <= 1'b0                                         ;
            r_001_is_ddr                        <= 1'b0                                         ;
            r_001_is_batch                      <= 1'b0                                         ;
        end else if ((r_006_st[p_st_meta]) & w_001_rx) begin
            r_001_is_ram                        <= (i_064_aur_rx_data[15:0] == `p_msg_ram_wr        ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ram_wr_ack    ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ram_rd        );

            r_001_is_ddr                        <= (i_064_aur_rx_data[15:0] == `p_msg_ddr_wr        ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ddr_wr_ack    ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ddr_rd        );

            r_001_is_rd                         <= (i_064_aur_rx_data[15:0] == `p_msg_reg_rd        ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_reg_brd       ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ram_rd        ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ddr_rd        );

            r_001_is_batch                      <= (i_064_aur_rx_data[15:0] == `p_msg_reg_bwr       ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_reg_bwr_ack   ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_reg_brd       );

            r_001_need_rsp                      <= (i_064_aur_rx_data[15:0] == `p_msg_reg_wr_ack    ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_reg_rd        ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_reg_bwr_ack   ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_reg_brd       ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ram_wr_ack    ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ram_rd        ) |
                                                   (i_064_aur_rx_data[15:0] == `p_msg_ddr_wr_ack    );
        end
    end

    //  body first accepted beat -> 1; idle/rst -> 0

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ctrl_got                      <= 1'b0                                         ;
        else if (r_006_st[p_st_idle])
            r_001_ctrl_got                      <= 1'b0                                         ;
        else if ((r_006_st[p_st_body]) & w_001_rx)
            r_001_ctrl_got                      <= 1'b1                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_032_addr                          <= 32'h0                                        ;
        else if ((r_006_st[p_st_body]) & w_001_rx & (~r_001_ctrl_got) & ~((r_016_msg == `p_msg_ram_wr      ) | 
                                                                          (r_016_msg == `p_msg_ram_wr_ack  ) |
                                                                          (r_016_msg == `p_msg_ram_rd      )))
            r_032_addr                          <= i_064_aur_rx_data[31: 0]                     ;
        else if ((r_006_st[p_st_body]) & w_001_rx & r_001_is_batch & ~i_001_aur_rx_eop & ~w_001_op_full)
            r_032_addr                          <= i_064_aur_rx_data[31: 0]                     ;
        else if ((r_006_st[p_st_body]) & w_001_rx & (~r_001_ctrl_got) & ((r_016_msg == `p_msg_ram_wr       ) | 
                                                                         (r_016_msg == `p_msg_ram_wr_ack   ) |
                                                                         (r_016_msg == `p_msg_ram_rd       )))
            r_032_addr                          <= {8'h0, i_064_aur_rx_data[39:16]}             ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_032_data                          <= 32'h0                                        ;
        else if ((r_006_st[p_st_body]) & w_001_rx & (~r_001_ctrl_got) &
                 ~((r_016_msg == `p_msg_ram_wr      ) | 
                   (r_016_msg == `p_msg_ram_wr_ack  ) |
                   (r_016_msg == `p_msg_ram_rd      )))
            r_032_data                          <= i_064_aur_rx_data[63:32]                     ;
        else if ((r_006_st[p_st_body]) & w_001_rx & r_001_is_batch & ~i_001_aur_rx_eop & ~w_001_op_full)
            r_032_data                          <= i_064_aur_rx_data[63:32]                     ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_016_ram_cs                        <= 16'h0                                        ;
            r_024_ram_len                       <= 24'h0                                        ;
            r_024_ram_addr                      <= 24'h0                                        ;
        end else if ((r_006_st[p_st_body]) & w_001_rx & (~r_001_ctrl_got) & ((r_016_msg == `p_msg_ram_wr      ) | 
                                                                             (r_016_msg == `p_msg_ram_wr_ack  ) | 
                                                                             (r_016_msg == `p_msg_ram_rd      ))) begin
            r_024_ram_len                       <= i_064_aur_rx_data[63:40]                     ;
            r_024_ram_addr                      <= i_064_aur_rx_data[39:16]                     ;
            r_016_ram_cs                        <= i_064_aur_rx_data[15: 0]                     ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_021_beat_left                     <= 21'h0                                        ;
        else if ((r_006_st[p_st_body]) & w_001_rx & (~r_001_ctrl_got) & ((r_016_msg == `p_msg_ram_wr) | 
                                                                         (r_016_msg == `p_msg_ram_wr_ack) |
                                                                         (r_016_msg == `p_msg_ram_rd))) begin
            if ((r_016_msg == `p_msg_ram_wr) | (r_016_msg == `p_msg_ram_wr_ack))
                r_021_beat_left                 <= i_064_aur_rx_data[63:43]                     ; // byte len [23:3]
            else
                r_021_beat_left                 <= 21'h0                                        ;
        end else if ((r_006_st[p_st_body]) & w_001_rx & (r_021_beat_left != 21'h0) & ~i_001_aur_rx_eop)
            r_021_beat_left                     <= r_021_beat_left - 1'b1                       ;
        else if (r_006_st[p_st_idle])
            r_021_beat_left                     <= 21'h0                                        ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_wr_req                    <= 1'b0                                         ;
        else
            r_001_ram_wr_req                    <= (r_006_st[p_st_body]) &
                                                   w_001_rx &
                                                   r_001_ctrl_got &
                                                   (r_021_beat_left == r_024_ram_len[23:3]) &
                                                   (r_021_beat_left != 21'h0) &
                                                   ((r_016_msg == `p_msg_ram_wr) | (r_016_msg == `p_msg_ram_wr_ack));
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_024_ram_wr_addr                   <= 24'h0                                        ;
            r_024_ram_wr_size                   <= 24'h0                                        ;
            r_016_ram_wr_bsel                   <= 16'h0                                        ;
        end else if ((r_006_st[p_st_body]) & w_001_rx & (~r_001_ctrl_got) & ((r_016_msg == `p_msg_ram_wr) | (r_016_msg == `p_msg_ram_wr_ack))) begin
            r_024_ram_wr_addr                   <= i_064_aur_rx_data[39:16]                     ;
            r_024_ram_wr_size                   <= i_064_aur_rx_data[63:40]                     ;
            r_016_ram_wr_bsel                   <= i_064_aur_rx_data[15: 0]                     ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_wr_dvld                   <= 1'b0                                         ;
        else
            r_001_ram_wr_dvld                   <= (r_006_st[p_st_body]) & w_001_rx & (r_021_beat_left != 21'h0);
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_wr_sop                    <= 1'b0                                         ;
        else
            r_001_ram_wr_sop                    <= (r_006_st[p_st_body]) & w_001_rx &
                                                   r_001_ctrl_got &
                                                   (r_021_beat_left == r_024_ram_len[23:3]) &
                                                   (r_021_beat_left != 21'h0);
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_wr_eop                    <= 1'b0                                         ;
        else
            r_001_ram_wr_eop                    <= (r_006_st[p_st_body]) & w_001_rx & (r_021_beat_left == 21'h1);
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_064_ram_wr_data                   <= 64'h0                                        ;
        else
            r_064_ram_wr_data                   <= i_064_aur_rx_data                            ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_reg_wr_req                    <= 1'b0                                         ;
        else
            r_001_reg_wr_req                    <= (r_006_st[p_st_op]) & ~r_001_is_ram & ~r_001_is_ddr & ~r_001_is_rd & i_001_reg_rdy & w_001_op_dout_rdy;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_reg_rd_req                    <= 1'b0                                         ;
        else
            r_001_reg_rd_req                    <= (r_006_st[p_st_op]) & ~r_001_is_ram & ~r_001_is_ddr & r_001_is_rd & i_001_reg_rdy & w_001_op_dout_rdy;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_032_reg_wr_data                   <= 32'h0                                        ;
            r_032_reg_addr                      <= 32'h0                                        ;
        end else if ((r_006_st[p_st_op]) & w_001_op_dout_rdy) begin
            r_032_reg_wr_data                   <= w_064_op_dout[63:32]                         ;
            r_032_reg_addr                      <= w_064_op_dout[31: 0]                         ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst | ((r_006_st[p_st_idle]) & w_001_op_empty))
            r_012_op_n                          <= 12'd0                                        ;
        else if (r_001_op_wen)
            r_012_op_n                          <= r_012_op_n + 1'b1                            ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst | ((r_006_st[p_st_idle]) & w_001_op_empty))
            r_012_op_r                          <= 12'd0                                        ;
        else if ((r_006_st[p_st_wait]) & w_001_reg_done)
            r_012_op_r                      <= r_012_op_r + 1'b1                                ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_012_nbeat                         <= 12'd0                                        ;
        else if ((r_006_st[p_st_wait]) & w_001_reg_done & ((r_012_op_r + 12'd1 == r_012_op_n) | r_001_time_out))
            r_012_nbeat                         <= r_012_op_n                                   ;
    end

    // reg op buf, fwft 16KB

    sfifo_i64o64_d2048 u00_reg_op_buf (
        .clk                                    (i_001_clk                                      ),
        .srst                                   (i_001_rst                                      ),
        .din                                    (r_064_op_din                                   ),
        .wr_en                                  (r_001_op_wen                                   ),
        .rd_en                                  (w_001_op_ren                                   ),
        .dout                                   (w_064_op_dout                                  ),
        .full                                   (w_001_op_full                                  ),
        .empty                                  (w_001_op_empty                                 ),
        .wr_rst_busy                            (w_001_op_wr_rst_busy                           ),
        .rd_rst_busy                            (w_001_op_rd_rst_busy                           )
    );

    // reg rd rsp buf, fwft 16KB

    sfifo_i64o64_d2048 u01_reg_rsp_buf (
        .clk                                    (i_001_clk                                      ),
        .srst                                   (i_001_rst                                      ),
        .din                                    (r_064_rsp_din                                  ),
        .wr_en                                  (r_001_rsp_wen                                  ),
        .rd_en                                  (w_001_rsp_ren                                  ),
        .dout                                   (w_064_rsp_dout                                 ),
        .full                                   (w_001_rsp_full                                 ),
        .empty                                  (w_001_rsp_empty                                ),
        .wr_rst_busy                            (w_001_rsp_wr_rst_busy                          ),
        .rd_rst_busy                            (w_001_rsp_rd_rst_busy                          )
    );

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_rd_req                    <= 1'b0                                         ;
        else
            r_001_ram_rd_req                    <= (r_006_st[p_st_op]) & r_001_is_ram & r_001_is_rd;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_024_ram_rd_addr                   <= 24'h0                                        ;
            r_024_ram_rd_size                   <= 24'h0                                        ;
            r_016_ram_rd_bsel                   <= 16'h0                                        ;
        end else if (r_006_st[p_st_op]) begin
            r_024_ram_rd_addr                   <= r_024_ram_addr                               ;
            r_024_ram_rd_size                   <= r_024_ram_len                                ;
            r_016_ram_rd_bsel                   <= r_016_ram_cs                                 ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_032_reg_rcp_data                  <= 32'h0                                        ;
        else if (i_001_reg_rd_ack)
            r_032_reg_rcp_data                  <= i_032_reg_rd_data                            ;
        else if (i_001_reg_wr_ack)
            r_032_reg_rcp_data                  <= (r_001_rcp_fail | i_001_reg_fail) ? `p_pkt_fail : `p_pkt_ok;
        else if (r_001_time_out & ~r_001_is_rd)
            r_032_reg_rcp_data                  <= `p_pkt_fail                                  ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_016_reg_rcp_msg                   <= 16'h0                                        ;
        else if (r_006_st[p_st_rcp]) begin
            if (r_001_is_batch & r_001_is_rd)
                r_016_reg_rcp_msg               <= `p_msg_reg_brd_rsp                           ;
            else if (r_001_is_batch)
                r_016_reg_rcp_msg               <= `p_msg_reg_bwr_rsp                           ;
            else if (r_001_is_rd)
                r_016_reg_rcp_msg               <= `p_msg_reg_rd_rsp                            ;
            else
                r_016_reg_rcp_msg               <= `p_msg_reg_wr_rsp                            ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_rcp_rd                    <= 1'b0                                         ;
        else if (r_006_st[p_st_op])
            r_001_ram_rcp_rd                    <= r_001_is_ram & r_001_is_rd                   ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_reg_rcp_req                   <= 1'b0                                         ;
        else if ((r_006_st[p_st_rcp]) & ~r_001_is_ram & ~r_001_is_ddr & r_001_need_rsp) begin
            if (i_001_reg_rcp_ack)
                r_001_reg_rcp_req               <= 1'b0                                         ;
            else
                r_001_reg_rcp_req               <= 1'b1                                         ;
        end else
            r_001_reg_rcp_req                   <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ram_rcp_req                   <= 1'b0                                         ;
        else if ((r_006_st[p_st_rcp]) & r_001_is_ram & r_001_need_rsp) begin
            if (i_001_ram_rcp_ack)
                r_001_ram_rcp_req               <= 1'b0                                         ;
            else
                r_001_ram_rcp_req               <= 1'b1                                         ;
        end else
            r_001_ram_rcp_req                   <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_ddr_rcp_req                   <= 1'b0                                         ;
        else if ((r_006_st[p_st_rcp]) & r_001_is_ddr & r_001_need_rsp) begin
            if (i_001_ddr_rcp_ack)
                r_001_ddr_rcp_req               <= 1'b0                                         ;
            else
                r_001_ddr_rcp_req               <= 1'b1                                         ;
        end else
            r_001_ddr_rcp_req                   <= 1'b0                                         ;
    end

endmodule
