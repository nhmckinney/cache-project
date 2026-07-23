// cache_controller.sv
//
// Top-level cache datapath + control. Instantiates tag_array,
// data_array, tag_compare, replacement_policy, and miss_fsm; wires
// them together and exposes a simple request/response interface to
// dma_stream_if (or directly to a testbench, as here).
//
// Request/response protocol: single-request-at-a-time to start
// (req_valid/req_ready handshake in, resp_valid pulses out with
// hit/miss status). Pipelining multiple outstanding requests is a
// reasonable stretch goal once this works, not part of the initial
// bring-up.

import cache_pkg::*;

module cache_controller (
    input  logic                  clk,
    input  logic                  rst_n,

    // Request in
    input  logic                  req_valid,
    output logic                  req_ready,
    input  addr_t                 req_addr,
    input  req_kind_e             req_kind,      // REQ_READ / REQ_WRITE
    input  data_t                 req_wdata,     // valid for REQ_WRITE

    // Response out
    output logic                  resp_valid,
    output data_t                 resp_rdata,    // valid for REQ_READ
    output logic                  resp_hit,      // instrumentation: was it a hit

    // Backing store connection
    output logic                  mem_req_valid,
    output mem_op_e                mem_req_op,
    output addr_t                  mem_req_addr,
    output line_data_t             mem_req_wdata,
    input  logic                   mem_req_done,
    input  line_data_t             mem_rd_line,

    // Instrumentation (for hit-rate / latency reporting in the testbench
    // or on-board via LEDs/UART)
    output logic                  instr_access_valid, // pulses per completed request
    output logic                  instr_hit,
    output logic [31:0]           instr_cycle_count    // free-running cycle counter
);

endmodule : cache_controller
