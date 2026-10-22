// =================================================================================================
// file name      : aur_rst.v
// module         : aur_rst
// function       : aur_rst 
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/08/11   lxl        create new              semigth
// =================================================================================================

`timescale 1ps / 1ps


module aur_rst (
    input                                       i_001_init_clk                                  ,
    input                                       i_001_init_rst                                  ,
    input                                       i_001_aur_clk                                   ,
    input                                       i_001_lane_up                                   ,
    output reg                                  o_001_pma_rst                                   ,
    output                                      o_001_pcs_rst
);

// =============================================================================
// internal parameter declare
// =============================================================================

// =============================================================================
// internal signal define
// =============================================================================

    reg                                         r_001_lane_up_r1                                ;
    reg                                         r_001_lane_up_r2                                ;
    reg                                         r_001_lane_up_r3                                ;

    reg  [                                 7:0] r_008_rst_shift                                 ;
    reg                                         r_001_rst                                       ;

    reg  [                               127:0] r_128_rst_stage                                 ;
    reg                                         r_001_rst_or                                    ;

    initial r_128_rst_stage                     = {128{1'b1}}                                   ;
    initial r_008_rst_shift                     = 8'b11111111                                   ;
    initial r_001_rst                           = 'b1                                           ;

// ==================================================================================================
// rtl body
// ==================================================================================================

    always @(posedge i_001_init_clk) begin
        r_001_lane_up_r1                        <= i_001_lane_up                                ;
        r_001_lane_up_r2                        <= r_001_lane_up_r1                             ;
        r_001_lane_up_r3                        <= r_001_lane_up_r2                             ;
    end

    always @(posedge i_001_init_clk) begin
        r_008_rst_shift[0]                      <= r_001_lane_up_r3 && (!r_001_lane_up_r2)      ; // negedge 
        r_008_rst_shift[7:1]                    <= r_008_rst_shift[6:0]                         ;
        r_001_rst                               <= |r_008_rst_shift                             ;
    end

    always @(posedge i_001_init_clk) begin
        r_128_rst_stage[127:0]                  <= {r_128_rst_stage[126:0], r_001_rst_or}       ;
    end

    always @(posedge i_001_init_clk) begin
        r_001_rst_or                            <= i_001_init_rst || r_001_rst                  ;
    end

    always @(posedge i_001_init_clk) begin
        o_001_pma_rst                           <= r_001_rst_or || r_128_rst_stage[127]         ;
    end

    assign o_001_pcs_rst                        = o_001_pma_rst                                 ;
endmodule
