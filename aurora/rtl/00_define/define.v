// =================================================================================================
// file name      : define.v
// module         : -
// function       : project define
// type           : header
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/21   lxl        create new              semigth
// =================================================================================================

`ifndef DEFINE_V
`define DEFINE_V

// sim : define p_sim in sim compile

// pkt : packet
`define p_pkt_preamble                  16'h7e7e
`define p_pkt_idle                      32'h7654_3210
`define p_pkt_ok                        32'h6666_6666
`define p_pkt_fail                      32'hf0f0_f0f0
`define p_pkt_ok_64                     64'h6666_6666_6666_6666
`define p_pkt_fail_64                   64'hf0f0_f0f0_f0f0_f0f0
`define p_pkt_min_byte                  32'd32
`define p_pkt_max_byte                  32'd16384

// msg : message type
`define p_msg_reg_wr                    16'h0001
`define p_msg_reg_wr_ack                16'h0003
`define p_msg_reg_wr_rsp                16'h0004
`define p_msg_reg_bwr                   16'h0005
`define p_msg_reg_bwr_ack               16'h0007
`define p_msg_reg_bwr_rsp               16'h0008
`define p_msg_reg_rd                    16'h0009
`define p_msg_reg_rd_rsp                16'h000a
`define p_msg_reg_brd                   16'h000b
`define p_msg_reg_brd_rsp               16'h000c
`define p_msg_ram_wr                    16'h0011
`define p_msg_ram_wr_ack                16'h0013
`define p_msg_ram_wr_rsp                16'h0014
`define p_msg_ram_rd                    16'h0015
`define p_msg_ram_rd_rsp                16'h0016
`define p_msg_ddr_wr                    16'h0021
`define p_msg_ddr_wr_ack                16'h0023
`define p_msg_ddr_wr_rsp                16'h0024
`define p_msg_ddr_rd                    16'h0025
`define p_msg_ddr_rd_rsp                16'h0026

// id : node type / local fpga
`define p_ntype_fpga                    4'h3
`define p_fpga_pl                       4'h1
`define p_fpga_sw                       4'h2
`define p_fpga_ku0                      4'h3
`define p_fpga_ku1                      4'h4
`define p_fpga_ku2                      4'h5
`define p_fpga_ku3                      4'h6
`define p_ntype_host                    4'h1
`define p_slot_loc                      4'hf                                    // loc/pl slot

`endif
