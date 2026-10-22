// =================================================================================================
// file name      : aur_rx_if.v
// module         : aur_rx_if
// function       : axis to local sop eop, ready backpressure
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// =================================================================================================

`timescale 1ns / 1ps

module aur_rx_if (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    // axis rx
    input      [                          63:0] i_064_axis_tdata                                ,
    input      [                           7:0] i_008_axis_tkeep                                ,
    input                                       i_001_axis_tlast                                ,
    input                                       i_001_axis_tvalid                               ,
    output                                      o_001_axis_tready                               ,
    // local sop : start of packet
    input                                       i_001_aur_rx_rdy                                , // ready
    output                                      o_001_aur_rx_sop                                , // start of packet
    output                                      o_001_aur_rx_eop                                , // end of packet
    output                                      o_001_aur_rx_dvld                               , // data valid
    output     [                          63:0] o_064_aur_rx_data
);

    // =============================================================================
    // internal signal define
    // =============================================================================

    reg                                         r_001_in_pkt                                    ;
    reg                                         r_001_axis_tready                               ;
    reg                                         r_001_aur_rx_sop                                ;
    reg                                         r_001_aur_rx_eop                                ;
    reg                                         r_001_aur_rx_dvld                               ;
    reg        [                          63:0] r_064_aur_rx_data                               ;

    wire                                        w_001_fire                                      ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_001_axis_tready                    = r_001_axis_tready                             ;
    assign o_001_aur_rx_sop                     = r_001_aur_rx_sop                              ;
    assign o_001_aur_rx_eop                     = r_001_aur_rx_eop                              ;
    assign o_001_aur_rx_dvld                    = r_001_aur_rx_dvld                             ;
    assign o_064_aur_rx_data                    = r_064_aur_rx_data                             ;

    assign w_001_fire                           = i_001_axis_tvalid & r_001_axis_tready         ;

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_axis_tready                   <= 1'b0                                         ;
        else
            r_001_axis_tready                   <= i_001_aur_rx_rdy                             ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_in_pkt                        <= 1'b0                                         ;
        else if (w_001_fire)
            r_001_in_pkt                        <= ~i_001_axis_tlast                            ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_aur_rx_dvld                   <= 1'b0                                         ;
        else
            r_001_aur_rx_dvld                   <= w_001_fire                                   ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_aur_rx_sop                    <= 1'b0                                         ;
        else
            r_001_aur_rx_sop                    <= w_001_fire & (~r_001_in_pkt)                 ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_aur_rx_eop                    <= 1'b0                                         ;
        else
            r_001_aur_rx_eop                    <= w_001_fire & i_001_axis_tlast                ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_064_aur_rx_data                   <= 64'h0                                        ;
        else if (w_001_fire)
            r_064_aur_rx_data                   <= i_064_axis_tdata                             ;
    end

endmodule
