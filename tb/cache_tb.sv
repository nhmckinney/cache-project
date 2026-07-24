
`timescale 1ns/1ps

import cache_pkg::*;

module cache_tb;

    // -----------------------------------------------------------
    // Clock / reset
    // -----------------------------------------------------------
    logic clk;
    logic rst_n;

    always #5 clk = ~clk;

    task automatic reset_dut();

        rst_n <= '0;
        #15;
        rst_n <= '1;

    endtask

    // -----------------------------------------------------------
    // DUT connections
    // -----------------------------------------------------------
    logic                  req_valid;
    logic                  req_ready;
    addr_t                 req_addr;
    req_kind_e             req_kind;
    data_t                 req_wdata;

    logic                  resp_valid;
    data_t                 resp_rdata;
    logic                  resp_hit;

    logic                  mem_req_valid;
    mem_op_e               mem_req_op;
    addr_t                 mem_req_addr;
    line_data_t            mem_req_wdata;
    logic                  mem_req_done;
    line_data_t            mem_rd_line;

    logic                  instr_access_valid;
    logic                  instr_hit;
    logic [31:0]           instr_cycle_count;

    cache_controller dut (.*);

    memory_interface #(.MEM_SIZE_LINES(4096)) mem (
        .clk            (clk),
        .rst_n          (rst_n),
        .req_valid      (mem_req_valid),
        .req_op         (mem_req_op),
        .req_addr       (mem_req_addr),
        .req_wdata      (mem_req_wdata),
        .req_done       (mem_req_done),
        .rd_line        (mem_rd_line)
    );

    // -----------------------------------------------------------
    // Software reference model
    //
    // Mirrors expected memory state independent of cache structure
    // (no sets/ways/tags -- just "what value should address A read
    // as right now"). This is deliberately dumber than the RTL cache
    // so it's trustworthy as a golden reference.
    // -----------------------------------------------------------
    class reference_model;
        data_t mem_model[addr_t];

        function new();
            mem_model.delete();
        endfunction

        function void apply_write(addr_t addr, data_t data);
            mem_model[addr] = data;
        endfunction

        function data_t apply_read(addr_t addr);
            if (!mem_model.exists(addr)) begin
                $display("WARNING: read from uninitialized address 0x%08x", addr);
                return 32'hDEADBEEF;
            end
            return mem_model[addr];
        endfunction
    endclass

    reference_model ref_model;

    // -----------------------------------------------------------
    // Bookkeeping
    // -----------------------------------------------------------
    int unsigned checks = 0;
    int unsigned errors = 0;
    int unsigned hits   = 0;
    int unsigned misses = 0;

    // -----------------------------------------------------------
    // Stimulus helper tasks
    // -----------------------------------------------------------

    // Drives a single request and waits for req_ready handshake.
    task automatic drive_request(input addr_t addr,
                                  input req_kind_e kind,
                                  input data_t wdata);
        req_valid <= 1'b1;
        req_addr  <= addr;
        req_kind  <= kind;
        req_wdata <= wdata;
        @(posedge clk);
        wait(req_ready);
        @(posedge clk);
        req_valid <= 1'b0;
    endtask

    // Waits for and captures the response for the most recently
    // driven request.
    task automatic wait_response(output data_t rdata, output logic hit);
        wait(resp_valid);
        @(posedge clk);
        rdata = resp_rdata;
        hit = resp_hit;
    endtask

    // Directed single-request check: drives a request, waits for the
    // response, and compares against the reference model.
    task automatic check_access(input string name,
                                 input addr_t addr,
                                 input req_kind_e kind,
                                 input data_t wdata);
        data_t   got_rdata;
        logic    got_hit;
        data_t   exp_rdata;

        checks++;
        drive_request(addr, kind, wdata);
        wait_response(got_rdata, got_hit);

        if (kind == REQ_WRITE) begin
            ref_model.apply_write(addr, wdata);
        end else begin
            exp_rdata = ref_model.apply_read(addr);
            if (got_rdata !== exp_rdata) begin
                errors++;
                $display("[%s] ERROR: addr=0x%08x expected=0x%08x got=0x%08x",
                         name, addr, exp_rdata, got_rdata);
            end
        end

        if (got_hit) hits++; else misses++;
    endtask

    // Checks a specific cache line's tag/valid/dirty state via
    // hierarchical reference into the DUT, mirroring lob_tb.sv's
    // check_level pattern. Useful for directed miss/eviction tests.
    task automatic check_tag_state(input string name,
                                    input index_t set_idx,
                                    input way_t way,
                                    input logic exp_valid,
                                    input logic exp_dirty,
                                    input tag_t exp_tag);
        // Fill in: reference dut.tag_arr_inst... (exact hierarchy
        // depends on instance names chosen inside cache_controller)
        // and compare against expected valid/dirty/tag.
    endtask

    // -----------------------------------------------------------
    // Randomized stimulus item
    //
    // NOTE: Icarus Verilog does not support SystemVerilog
    // `constraint`/`randomize()` (class-based constrained-random).
    // Using $urandom_range by hand here so this actually simulates
    // on your current toolchain. If you later move to a simulator
    // that supports constraints (Questa/VCS/Xcelium/Verilator+extra
    // work), this can be rewritten as a proper `rand` class with
    // `constraint` blocks for more expressive distributions.
    // -----------------------------------------------------------
    function automatic addr_t rand_addr();
        // Fill in: constrain to a small, reusable working set (e.g. a
        // handful of distinct line addresses) so hits/misses/evictions
        // actually get exercised, rather than every access being a
        // cold miss across a huge address space.
        return addr_t'($urandom_range(0, 32'h0000_0FFF));
    endfunction

    function automatic req_kind_e rand_kind();
        return $urandom_range(0, 1) ? REQ_WRITE : REQ_READ;
    endfunction

    function automatic data_t rand_wdata();
        return data_t'($urandom());
    endfunction

    // -----------------------------------------------------------
    // Test sequence
    // -----------------------------------------------------------
    initial begin
        clk = 0;
        rst_n = 0;
        req_valid = 1'b0;
        req_addr  = '0;
        req_kind  = REQ_NONE;
        req_wdata = '0;

        ref_model = new();
        reset_dut();

        // ---- Directed tests ----
        // Test 1: Write then read-back (should hit on second access)
        $display("[TEST] Write 0xDEADBEEF to 0x00000100");
        check_access("write_0x100", 32'h00000100, REQ_WRITE, 32'hDEADBEEF);

        #50;  // Wait for any pending memory transactions

        $display("[TEST] Read back from 0x00000100 (expect hit)");
        check_access("read_0x100", 32'h00000100, REQ_READ, 32'h00000000);

        // ---- Randomized tests ----
        // Fill in: loop driving N randomized accesses through
        // check_access, e.g.:
        //
        // for (int i = 0; i < 1000; i++) begin
        //     check_access($sformatf("rand_%0d", i),
        //                  rand_addr(), rand_kind(), rand_wdata());
        // end

        $display("=====================================");
        $display("Checks: %0d  Errors: %0d", checks, errors);
        $display("Hits: %0d  Misses: %0d  Hit rate: %0.2f%%",
                  hits, misses, (hits + misses) ? (100.0 * hits / (hits + misses)) : 0.0);
        $display("=====================================");
        if (errors == 0) $display("ALL CHECKS PASSED");
        else $display("%0d CHECK(S) FAILED", errors);

        $finish;
    end

    // -----------------------------------------------------------
    // SVA invariant checks (placeholders)
    //
    // Fill in properties such as:
    //   - no cache line may be dirty while invalid
    //   - within a set, no two ways may simultaneously claim to be
    //     the LRU victim
    //   - resp_valid should never assert without a preceding req_valid
    //     handshake
    // Bind these against cache_controller's internal sub-module
    // instances once their instance names are fixed.
    // -----------------------------------------------------------

endmodule : cache_tb
