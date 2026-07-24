// dma_stream_interface.sv
//
// AXI-Stream-style burst front end. Accepts a burst descriptor
// (start address, length, read/write) and, for writes, a stream of
// data words; converts the burst into a sequence of individual
// cache_controller requests, one word per beat.
//
// Simple valid/ready handshake on both the stream input and the
// cache_controller-facing request output, matching AXI-Stream
// semantics without pulling in a full AXI-Stream IP dependency.

import cache_pkg::*;

module dma_stream_interface (
    input  logic                  clk,
    input  logic                  rst_n,

    // Burst descriptor in
    input  logic                  burst_valid,
    output logic                  burst_ready,
    input  addr_t                  burst_addr,
    input  logic [15:0]            burst_len,      // number of words
    input  req_kind_e              burst_kind,     // REQ_READ / REQ_WRITE

    // Write data stream in (valid for burst_kind == REQ_WRITE)
    input  logic                  wdata_valid,
    output logic                  wdata_ready,
    input  data_t                 wdata,

    // Read data stream out (valid for burst_kind == REQ_READ)
    output logic                  rdata_valid,
    input  logic                  rdata_ready,
    output data_t                 rdata,

    // Burst completion
    output logic                  burst_done,

    // Interface to cache_controller
    output logic                  cc_req_valid,
    input  logic                  cc_req_ready,
    output addr_t                 cc_req_addr,
    output req_kind_e             cc_req_kind,
    output data_t                 cc_req_wdata,
    input  logic                  cc_resp_valid,
    input  data_t                 cc_resp_rdata,
    input  logic                  cc_resp_hit
);

endmodule : dma_stream_interface
