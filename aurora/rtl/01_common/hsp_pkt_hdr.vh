// =================================================================================================
// file name      : hsp_pkt_hdr.vh
// module         : -
// function       : HSP 帧头字段偏移（图1），供 `include
// type           : header
// -------------------------------------------------------------------------------------------------
// rev.level    date         coded by   contents                comp
// 0.0.1        2026/09/04   lxl        create new              semigth
// 0.0.2        2026/09/07   lxl        match 图1; lowercase     semigth
// 0.0.3        2026/09/22   lxl        word0 src then dest      semigth
// =================================================================================================
//
// QDMA 512b 首拍小端布局（与图1一致）：
//   word0 = tdata[63:0]
//   word1 = tdata[127:64]
//   下文 *_lsb 均为该字段在 tdata 上的最低 bit 下标（可用 [lsb +: w] 切片）
// 目标 Cage id = 1..4  -> Aurora lane 0..3
// 板内 FPGA id : pl=1, sw=2, ku0=3, ku1=4, ku2=5, ku3=6
//
// -------------------------------------------------------------------------------------------------
// 简写说明 / Abbreviations
//   hdr      : header                 帧头
//   lsb      : least significant bit  字段最低有效位在总线上的下标
//   w        : width                  位宽（bit 数）
//   qid      : queue id               队列 id
//   src      : source                 源头
//   dst      : destination / target   目标
//   fpga     : FPGA id                FPGA 编号（板内路由）
//   slot     : Slot id                Slot 编号
//   cage     : Cage id                Cage 编号（路由到 Aurora lane）
//   node     : node type              节点类型
//   preamble : preamble               前导头（固定 0x7E7E）
//   len      : frame length           帧长度（单位：字节）
//   ack      : frame ACK code         帧 ACK 码
//   msg_type : message type           消息类型
//   payload  : message body           消息体（可变长，8 字节对齐）
//   crc32    : CRC-32                 帧尾校验
//   idle     : idle / reserved        空闲填充（固定 0x76543210）
// -------------------------------------------------------------------------------------------------
// 说明：.vh 是 Verilog header（`define），不是 VHDL
//-----------------------------------------------------------------------------

// `define p_sim

`ifndef HSP_PKT_HDR_VH
`define HSP_PKT_HDR_VH

// 板内 FPGA id

`define hsp_fpga_pl                     4'h1
`define hsp_fpga_sw                     4'h2
`define hsp_fpga_ku0                    4'h3
`define hsp_fpga_ku1                    4'h4
`define hsp_fpga_ku2                    4'h5
`define hsp_fpga_ku3                    4'h6

// =============================================================================
// word0 = tdata[63:0]  （图1 第1行，bit63 左 / bit0 右）
// =============================================================================
// [63:48] 队列id

`define hsp_hdr_qid_lsb                 48
`define hsp_hdr_qid_w                   16

// [47:32] src id : fpga / slot / cage / ntype  （源头，节点类型在 [35:32]）
// [47:44] 源头 Fpga id

`define hsp_hdr_src_fpga_lsb            44
`define hsp_hdr_src_fpga_w               4

// [43:40] 源头 Slot id

`define hsp_hdr_src_slot_lsb            40
`define hsp_hdr_src_slot_w               4

// [39:36] 源头 Cage id

`define hsp_hdr_src_cage_lsb            36
`define hsp_hdr_src_cage_w               4

// [35:32] 源头 节点类型

`define hsp_hdr_src_node_lsb            32
`define hsp_hdr_src_node_w               4

// [31:16] dest id : fpga / slot / cage / ntype  （目标，节点类型在 [19:16]）
// [31:28] 目标 Fpga id

`define hsp_hdr_dst_fpga_lsb            28
`define hsp_hdr_dst_fpga_w               4

// [27:24] 目标 Slot id

`define hsp_hdr_dst_slot_lsb            24
`define hsp_hdr_dst_slot_w               4

// [23:20] 目标 Cage id

`define hsp_hdr_dst_cage_lsb            20
`define hsp_hdr_dst_cage_w               4

// [19:16] 目标 节点类型

`define hsp_hdr_dst_node_lsb            16
`define hsp_hdr_dst_node_w               4

// [15:0]  前导头

`define hsp_hdr_preamble_lsb             0
`define hsp_hdr_preamble_w              16
`define hsp_hdr_preamble                16'h7E7E

// =============================================================================
// word1 = tdata[127:64]  （图1 第2行；绝对 bit = 64 + word1内偏移）
// =============================================================================
// [127:96] / word1[63:32] 帧长度（字节）

`define hsp_hdr_len_lsb                 96
`define hsp_hdr_len_w                   32

// [95:80]  / word1[31:16] 帧 ACK 码

`define hsp_hdr_ack_lsb                 80
`define hsp_hdr_ack_w                   16

// [79:64]  / word1[15:0]  消息类型

`define hsp_hdr_msg_type_lsb            64
`define hsp_hdr_msg_type_w              16
`define hsp_msg_reg_wr                  16'h0001                                // register write
`define hsp_msg_reg_rd                  16'h0009                                // register read

// =============================================================================
// 帧尾（末拍 word，相对该 64b word 内偏移；payload 之后）
// =============================================================================

// [63:32] crc32

`define hsp_trl_crc32_lsb               32
`define hsp_trl_crc32_w                 32

// [31:0]  空闲

`define hsp_trl_idle_lsb                 0
`define hsp_trl_idle_w                  32
`define hsp_trl_idle                    32'h7654_3210

`endif
