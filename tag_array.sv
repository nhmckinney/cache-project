// tag_array.sv
//
// Storage for tag/valid/dirty metadata, NUM_SETS x WAYS entries.
// Purely storage + combinational read; no hit/miss decision logic here
// (that's tag_compare's job). One synchronous write port, indexed by
// set + way (way typically comes from replacement_policy on a miss,
// or from tag_compare's hit-way on a dirty-bit update).

import cache_pkg::*;

module tag_array (
    input  logic                  clk,
    input  logic                  rst_n,

    // Read port (combinational, all ways at the given index)
    input  index_t                rd_index,
    output tag_entry_t            rd_entries [WAYS],

    // Write port (synchronous, single way)
    input  logic                  wr_en,
    input  index_t                wr_index,
    input  way_t                  wr_way,
    input  tag_entry_t             wr_entry
);

endmodule : tag_array
