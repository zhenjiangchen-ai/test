// =================================================================================================
// file name      : aur_tx_if.v
// module         : aur_tx_if
// function       : local sop eop to axis, ready backpressure
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// =================================================================================================

`timescale 1ns / 1ps

module aur_tx_if (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    // local sop : start of packet
    output                                      o_001_aur_tx_rdy                                , // ready
    input                                       i_001_aur_tx_sop                                , // start of packet
    input                                       i_001_aur_tx_eop                                , // end of packet
    input                                       i_001_aur_tx_dvld                               , // data valid
    input      [                          63:0] i_064_aur_tx_data                               ,
    // axis tx
    output     [                          63:0] o_064_axis_tdata                                ,
    output     [                           7:0] o_008_axis_tkeep                                ,
    output                                      o_001_axis_tlast                                ,
    output                                      o_001_axis_tvalid                               ,
    input                                       i_001_axis_tready
);

    // =============================================================================
    // internal signal define
    // =============================================================================

    reg        [                          63:0] r_064_axis_tdata                                ;
    reg                                         r_001_axis_tlast                                ;
    reg                                         r_001_axis_tvalid                               ;
    reg                                         r_001_aur_tx_rdy                                ;

    wire                                        w_001_push                                      ;
    wire                                        w_001_pop                                       ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_064_axis_tdata                     = r_064_axis_tdata                              ;
    assign o_008_axis_tkeep                     = 8'hff                                         ;
    assign o_001_axis_tlast                     = r_001_axis_tlast                              ;
    assign o_001_axis_tvalid                    = r_001_axis_tvalid                             ;
    assign o_001_aur_tx_rdy                     = r_001_aur_tx_rdy                              ;

    assign w_001_push                           = i_001_aur_tx_dvld & r_001_aur_tx_rdy          ;
    assign w_001_pop                            = r_001_axis_tvalid & i_001_axis_tready         ;

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_aur_tx_rdy                    <= 1'b0                                         ;
        else
            r_001_aur_tx_rdy                    <= (~r_001_axis_tvalid) | i_001_axis_tready     ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_axis_tvalid                   <= 1'b0                                         ;
        else if (w_001_push)
            r_001_axis_tvalid                   <= 1'b1                                         ;
        else if (w_001_pop)
            r_001_axis_tvalid                   <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst) begin
            r_064_axis_tdata                    <= 64'h0                                        ;
            r_001_axis_tlast                    <= 1'b0                                         ;
        end else if (w_001_push) begin
            r_064_axis_tdata                    <= i_064_aur_tx_data                            ;
            r_001_axis_tlast                    <= i_001_aur_tx_eop                             ;
        end
    end

endmodule
