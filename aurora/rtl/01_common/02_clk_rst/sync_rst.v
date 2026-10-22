// =================================================================================================
// file name      : sync_rst.v
// module         : sync_rst
// function       : sync_rst 
// type           : rtl
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/08/11   lxl        create new              semigth
// =================================================================================================

`timescale 1 ns/1 ps

module sync_rst #(
    parameter p_dly_cyc_num                     = 15                                     
) (
    input                                       i_001_clk                                       ,
    input                                       i_001_rst                                       ,
    output                                      o_001_rst
);

    localparam integer p_dwt                    = width_cal(p_dly_cyc_num)                      ;

    reg                                         r_001_rst_r1                                    ;
    reg                                         r_001_rst_r2                                    ;
    reg                                         r_001_rst_r3                                    ;

    reg  [                             p_dwt:0] r_00n_cnt                                       ;
    reg                                         r_001_rst                                       ;

    always @ (posedge i_001_clk) begin
        r_001_rst_r1                            <= i_001_rst                                    ;
        r_001_rst_r2                            <= r_001_rst_r1                                 ;
        r_001_rst_r3                            <= r_001_rst_r2                                 ;
    end

    always @ (posedge i_001_clk) begin
        if (r_001_rst_r3)
            r_00n_cnt                           <= p_dly_cyc_num                                ;
        else if (|r_00n_cnt)
            r_00n_cnt                           <= r_00n_cnt - 1'b1                             ;
        else
            r_00n_cnt                           <= 'b0                                          ;
    end
    
    always @(posedge i_001_clk) begin
        r_001_rst                               <= |r_00n_cnt;
    end

    BUFG U00 (
        .I                                      (r_001_rst                                      ),
        .O                                      (o_001_rst                                      )
    );

    function integer width_cal (input integer depth);
    begin
        for (width_cal=0; depth>1; width_cal=width_cal+1)
            depth                               = depth>>1                                      ;
    end
    endfunction
endmodule