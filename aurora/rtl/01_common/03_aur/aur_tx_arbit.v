// =================================================================================================
// file name      : aur_tx_arbit.v
// module         : aur_tx_arbit
// function       : sop stream arbiter, parameterized
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// =================================================================================================

`timescale 1ns / 1ps

module aur_tx_arbit #(
    parameter p_chnin                           = 3                                             ,
    parameter p_dwith                           = 64
) (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       , // high reset
    input                                       i_001_arbit_rdy                                 ,
    output                                      o_001_arbit_sop                                 ,
    output                                      o_001_arbit_eop                                 ,
    output                                      o_001_arbit_dvld                                ,
    output     [                   p_dwith-1:0] o_0nn_arbit_data                                ,
    input      [                   p_chnin-1:0] i_00n_chi_req                                   ,
    output     [                   p_chnin-1:0] o_00n_chi_ack                                   ,
    output     [                   p_chnin-1:0] o_00n_chi_rdy                                   ,
    input      [                   p_chnin-1:0] i_00n_chi_sop                                   ,
    input      [                   p_chnin-1:0] i_00n_chi_eop                                   ,
    input      [                   p_chnin-1:0] i_00n_chi_dvld                                  ,
    input      [           p_dwith*p_chnin-1:0] i_nnn_chi_data
);

    genvar                                      i                                               ;

    // =============================================================================
    // internal signal define
    // =============================================================================

    wire       [                   p_chnin-1:0] w_00n_chsel                                     ;

    reg        [                   p_chnin-1:0] r_00n_chsel                                     ;
    reg        [                   p_chnin-1:0] r_00n_chi_ack                                   ;
    reg                                         r_001_busy                                      ;
    reg                                         r_001_arbit_sop                                 ;
    reg                                         r_001_arbit_eop                                 ;
    reg                                         r_001_arbit_dvld                                ;
    reg        [                   p_dwith-1:0] r_0nn_arbit_data                                ;

    reg        [                   p_dwith-1:0] r_0nn_mux_data                                  ;

    // =================================================================================================
    // RTL Body
    // =================================================================================================

    assign o_001_arbit_sop                      = r_001_arbit_sop                               ;
    assign o_001_arbit_eop                      = r_001_arbit_eop                               ;
    assign o_001_arbit_dvld                     = r_001_arbit_dvld                              ;
    assign o_0nn_arbit_data                     = r_0nn_arbit_data                              ;
    assign o_00n_chi_ack                        = r_00n_chi_ack                                 ;

    generate
        for (i = 0; i < p_chnin; i = i + 1) begin : gen_arbit
            if (i == 0) begin : gen_ch0
                assign w_00n_chsel[i]           = i_00n_chi_req[i]                              ;
            end else begin : gen_chn
                assign w_00n_chsel[i]           = (i_00n_chi_req[i-1:0] == {i{1'b0}}) ? i_00n_chi_req[i] : 1'b0;
            end

            always @(posedge i_001_clk) begin
                if (i_001_rst)
                    r_00n_chsel[i]              <= 1'b0                                         ;
                else if (w_00n_chsel[i] & i_001_arbit_rdy & (~r_001_busy))
                    r_00n_chsel[i]              <= 1'b1                                         ;
                else if (i_00n_chi_eop[i] & i_00n_chi_dvld[i])
                    r_00n_chsel[i]              <= 1'b0                                         ;
            end

            always @(posedge i_001_clk) begin
                if (i_001_rst)
                    r_00n_chi_ack[i]            <= 1'b0                                         ;
                else
                    r_00n_chi_ack[i]            <= w_00n_chsel[i] & i_001_arbit_rdy & (~r_001_busy);
            end

            assign o_00n_chi_rdy[i]             = r_00n_chsel[i] & i_001_arbit_rdy              ;
        end
    endgenerate

    always @(*) begin
        if (r_00n_chsel[0])
            r_0nn_mux_data                      = i_nnn_chi_data[63:0]                          ;
        else if (r_00n_chsel[1])
            r_0nn_mux_data                      = i_nnn_chi_data[127:64]                        ;
        else if (r_00n_chsel[2])
            r_0nn_mux_data                      = i_nnn_chi_data[191:128]                       ;
        else
            r_0nn_mux_data                      = {p_dwith{1'b0}}                               ;
    end

    always @(posedge i_001_clk) begin
        if (i_001_rst)
            r_001_busy                          <= 1'b0                                         ;
        else if ((w_00n_chsel != {p_chnin{1'b0}}) & i_001_arbit_rdy & (~r_001_busy))
            r_001_busy                          <= 1'b1                                         ;
        else if (|(i_00n_chi_eop & i_00n_chi_dvld))
            r_001_busy                          <= 1'b0                                         ;
    end

    always @(posedge i_001_clk) begin
        r_001_arbit_sop                         <= |(r_00n_chsel & i_00n_chi_sop)               ;
        r_001_arbit_eop                         <= |(r_00n_chsel & i_00n_chi_eop)               ;
        r_001_arbit_dvld                        <= |(r_00n_chsel & i_00n_chi_dvld)              ;
        r_0nn_arbit_data                        <= r_0nn_mux_data                               ;
    end

endmodule
