// miss_fsm.sv
//
// Multi-cycle miss handler. Intended state sequence on a miss:
//   IDLE
//     -> CHECK_DIRTY   (combinational: look at victim_dirty from tag_compare)
//     -> WRITEBACK      (if victim dirty: issue MEM_WRITE to mem_if, wait req_done)
//     -> FILL_REQ       (issue MEM_READ to mem_if for the new line)
//     -> FILL_WAIT      (wait for mem_if req_done)
//     -> FILL_COMMIT    (write tag_array + data_array, touch replacement_policy)
//     -> IDLE
//
// This module owns the stall signal back to cache_controller: the
// pipeline should hold the requesting transaction until miss_fsm
// returns to IDLE with done asserted.
//
// Suggested state enum (define in this file or promote to cache_pkg
// if reused elsewhere):
//   typedef enum logic [2:0] {
//       MISS_IDLE, MISS_CHECK_DIRTY, MISS_WRITEBACK,
//       MISS_FILL_REQ, MISS_FILL_WAIT, MISS_FILL_COMMIT
//   } miss_state_e;

import cache_pkg::*;

module miss_fsm (
    input  logic                  clk,
    input  logic                  rst_n,

    // Miss request in (from cache_controller, on a tag_compare miss)
    input  logic                  miss_valid,
    input  addr_fields_t          miss_addr,
    input  req_kind_e              miss_kind,     // REQ_READ or REQ_WRITE
    input  data_t                  miss_wdata,    // valid for REQ_WRITE
    input  offset_t                miss_wr_offset,

    // Victim info (from tag_compare / replacement_policy, sampled at miss_valid)
    input  way_t                   victim_way,
    input  logic                   victim_dirty,
    input  tag_t                   victim_tag,
    input  line_data_t             victim_line,   // for writeback

    // Interface to mem_if
    output logic                   mem_req_valid,
    output mem_op_e                mem_req_op,
    output addr_t                  mem_req_addr,
    output line_data_t             mem_req_wdata,
    input  logic                   mem_req_done,
    input  line_data_t             mem_rd_line,

    // Interface to tag_array / data_array (fill commit)
    output logic                   fill_wr_en,
    output tag_entry_t              fill_tag_entry,
    output line_data_t             fill_line,

    // Interface to replacement_policy (touch on fill commit)
    output logic                   fill_touch_en,

    // Status back to cache_controller
    output logic                   busy,
    output logic                   done          // pulses one cycle on completion
);

endmodule : miss_fsm
