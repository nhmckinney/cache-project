import cache_pkg::*;

module replacement_policy (
    input  logic                  clk,
    input  logic                  rst_n,

    // Update on access: mark way as most-recently-used for this set
    input  logic                  touch_en,
    input  index_t                touch_index,
    input  way_t                  touch_way,

    // Victim query (combinational, current LRU state for the set)
    input  index_t                victim_index,
    output way_t                  victim_way
);

endmodule : replacement_policy
