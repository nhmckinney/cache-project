// memory_interface.sv
//
// Backing store model. Fixed MEM_LATENCY-cycle response (start simple;
// a later stretch goal is variable/bursty latency to stress-test
// miss_fsm's stall behavior -- keep that as a parameterizable mode,
// not a rewrite, when you get there).
//
// Single outstanding request at a time to start; miss_fsm should not
// issue a new request before req_done is seen for the previous one.

import cache_pkg::*;

module memory_interface #(
    parameter int MEM_SIZE_LINES = 4096,  // backing store depth, in lines
    parameter int MEM_LATENCY = 5         // latency in cycles (default: 5)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Request
    input  logic                  req_valid,
    input  mem_op_e                req_op,
    input  addr_t                  req_addr,      // line-aligned
    input  line_data_t            req_wdata,     // valid for MEM_WRITE

    // Response
    output logic                  req_done,      // pulses when latency elapses
    output line_data_t            rd_line        // valid for MEM_READ on req_done
);

  // Main memory storage
  line_data_t memory [0:MEM_SIZE_LINES-1];

  // Latency counter and request tracking
  logic [$clog2(MEM_LATENCY+1)-1:0] latency_counter;
  mem_op_e pending_op;
  addr_t pending_addr;
  logic request_pending;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      latency_counter <= '0;
      request_pending <= 1'b0;
      pending_op <= MEM_READ;
      pending_addr <= '0;
    end
    else begin
      if (req_valid && !request_pending) begin
        // Start new request
        request_pending <= 1'b1;
        latency_counter <= MEM_LATENCY[($clog2(MEM_LATENCY+1)-1):0];
        pending_op <= req_op;
        pending_addr <= req_addr;

        // Write immediately for MEM_WRITE
        if (req_op == MEM_WRITE) begin
          memory[req_addr[($clog2(MEM_SIZE_LINES)-1):0]] <= req_wdata;
        end
      end
      else if (request_pending) begin
        if (latency_counter == '0) begin
          request_pending <= 1'b0;
        end
        else begin
          latency_counter <= latency_counter - 1;
        end
      end
    end
  end

  // Response signals
  assign req_done = request_pending && (latency_counter == '0);
  assign rd_line = memory[pending_addr[($clog2(MEM_SIZE_LINES)-1):0]];

endmodule : memory_interface
