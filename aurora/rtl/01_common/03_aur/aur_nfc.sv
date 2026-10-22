// =================================================================================================
// file name      : aur_nfc.sv
// module         : aur_nfc
// function       : aurora nfc from rx fifo watermark
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/08/27   lxl        create new              semigth
// 0.0.2        2026/09/17   lxl        d2048 watermark 12bit   semigth
// =================================================================================================

`timescale 1ns / 1ps

module aur_nfc #(
    parameter p_buf_cnt_width                   = 'd12                                          ,
    parameter p_buf_upp_water                   = 'd1024                                        ,
    parameter p_buf_low_water                   = 'd512
) (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       ,
    // fifo cnt
    input      [           p_buf_cnt_width-1:0] i_00n_buf_wr_cnt                                ,
    // nfc → aurora s_axi_nfc
    output reg                                  o_001_axi_nfc_tvalid                            ,
    output reg [                          15:0] o_016_axi_nfc_tdata                             ,
    input                                       i_001_axi_nfc_tready
);

    reg  [                 p_buf_cnt_width-1:0] r_00n_buf_wr_cnt                                ;

    reg                                         r_001_req_upp                                   ;
    reg                                         r_001_req_low                                   ;

    reg                                         r_001_req_upp_r1                                ;
    reg                                         r_001_req_low_r1                                ;

    reg                                         r_001_req_upp_pos                               ;
    reg                                         r_001_req_low_pos                               ;

    reg                                         r_001_req_upp_latch                             ;
    reg                                         r_001_req_low_latch                             ;

    always @(posedge i_001_clk) begin
        if(i_001_rst)
            r_00n_buf_wr_cnt                    <= 'b0                                          ;
        else
            r_00n_buf_wr_cnt                    <= i_00n_buf_wr_cnt                             ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_req_upp                       <= 'b0                                          ;
            r_001_req_low                       <= 'b0                                          ;
        end else begin
            r_001_req_upp                       <= (r_00n_buf_wr_cnt >= p_buf_upp_water)        ;
            r_001_req_low                       <= (r_00n_buf_wr_cnt <= p_buf_low_water)        ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_req_upp_r1                    <= 'b0                                          ;
            r_001_req_low_r1                    <= 'b0                                          ;
        end else begin
            r_001_req_upp_r1                    <= r_001_req_upp                                ;
            r_001_req_low_r1                    <= r_001_req_low                                ;
        end
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_001_req_upp_pos                   <= 'b0                                          ;
            r_001_req_low_pos                   <= 'b0                                          ;
        end else begin
            r_001_req_upp_pos                   <= (!r_001_req_upp_r1) && r_001_req_upp         ;
            r_001_req_low_pos                   <= (!r_001_req_low_r1) && r_001_req_low         ;
        end
    end

    always @(posedge i_001_clk) begin
        if(i_001_rst)
            r_001_req_upp_latch                 <= 'b0                                          ;
        else if(r_001_req_upp_pos)
            r_001_req_upp_latch                 <= 'b1                                          ;
        else if(o_001_axi_nfc_tvalid && i_001_axi_nfc_tready && (o_016_axi_nfc_tdata == 16'h0100))
            r_001_req_upp_latch                 <= 'b0                                          ;
    end

    always @(posedge i_001_clk) begin
        if(i_001_rst)
            r_001_req_low_latch                 <= 'b0                                          ;
        else if(r_001_req_low_pos)
            r_001_req_low_latch                 <= 'b1                                          ;
        else if(o_001_axi_nfc_tvalid && i_001_axi_nfc_tready && (o_016_axi_nfc_tdata == 16'h0000))
            r_001_req_low_latch                 <= 'b0                                          ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            o_001_axi_nfc_tvalid                <= 'b0                                          ;
        else if ((r_001_req_upp_latch || r_001_req_low_latch) && (!o_001_axi_nfc_tvalid))
            o_001_axi_nfc_tvalid                <= 1'b1                                         ;
        else if(o_001_axi_nfc_tvalid && i_001_axi_nfc_tready)
            o_001_axi_nfc_tvalid                <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            o_016_axi_nfc_tdata                 <= 16'h0000                                     ;
        else if(r_001_req_upp_latch && (!o_001_axi_nfc_tvalid))
            o_016_axi_nfc_tdata                 <= 16'h0100                                     ; // XOFF, PG074 NFC bit8
        else if(r_001_req_low_latch && (!o_001_axi_nfc_tvalid))
            o_016_axi_nfc_tdata                 <= 16'h0000                                     ; // xon
    end
endmodule
