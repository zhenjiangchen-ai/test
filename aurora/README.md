# Aurora communication subsystem

Snapshot of `aurora_top` and its direct RTL/IP dependencies, uploaded on 2026-10-22. Original source bytes are preserved; this upload does not implement the planned XDMA replacement or fix existing logic.

## Structure

- `rtl/01_common/03_aur/`: 13-channel Aurora wrapper, upstream/downstream forwarding, local register/RAM packet decoder, response packing, CRC and NFC.
- `rtl/00_define/define.v` and `rtl/01_common/hsp_pkt_hdr.vh`: protocol definitions.
- `rtl/01_common/02_clk_rst/sync_rst.v`: user reset helper.
- `rtl/01_common/00_amd_ip/`: required XCI configurations and four external GT/clock support sources.
- `SOURCE_MANIFEST.json`: original file paths, byte lengths and SHA-256 hashes.

## Integration

Top module: `aurora_top`. Default topology: 1 upstream plus 12 downstream links, 7 reference clock groups. Destination Slot 1..12 forwards to downstream links; Slot F selects local register/RAM access. Link configuration requests 10.3125 Gbit/s and 156.25 MHz reference clocks.

Supply initialization and local clocks/resets externally. Register and RAM endpoints are external interfaces; this snapshot does not include `common_top`, board `sync_top`, `reg_if`, `ram_if`, system registers or RAM test endpoints. Local RAM data is 64 bits; command addresses and lengths are 24 bits.

Use Vivado to regenerate the four top-level IPs from their XCI files: `aurora_64b66b`, `axis_afifo_i64o64_d1024`, `axis_afifo_i64o64_d2048`, and `sfifo_i64o64_d2048`. Nested Aurora XCI configurations are included for completeness; avoid importing generated subcores twice. Add the four example-design support sources only once. Preserve the source hierarchy and enable relative include resolution (`verilog_dir` in Vivado), or configure equivalent include paths.

Define `p_sim` for the existing GT-bypass simulation interface. It does not model asynchronous multichannel traffic or real link recovery.

## Validation and limitations

No Vivado synthesis, implementation or simulation was run for this upload. Board pin/timing constraints, complete project scripts, generated checkpoints/netlists and proprietary documents are not included. Original vendor copyright notices remain intact; no new license is granted over third-party sources.

Known review items remain: upstream frame arbitration, local ready/valid handling, invalid-destination queue blocking, CRC failure side effects, and coordinated FIFO reset/link recovery. See the source before relying on this snapshot for hardware deployment.
