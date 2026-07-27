
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
    // Performance metrics
    // -----------------------------------------------------------
    int unsigned checks = 0;
    int unsigned errors = 0;
    int unsigned hits   = 0;
    int unsigned misses = 0;
    int unsigned total_latency = 0;
    int unsigned latency_samples = 0;

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
    // Also measures latency (cycles from request to response).
    task automatic check_access(input string name,
                                 input addr_t addr,
                                 input req_kind_e kind,
                                 input data_t wdata);
        data_t   got_rdata;
        logic    got_hit;
        data_t   exp_rdata;
        int      latency = 0;

        checks++;
        drive_request(addr, kind, wdata);

        // Measure latency from request to response
        while (!resp_valid) begin
            @(posedge clk);
            latency++;
        end
        @(posedge clk);
        got_rdata = resp_rdata;
        got_hit = resp_hit;

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

        if (got_hit) begin
            hits++;
        end else begin
            misses++;
        end

        total_latency += latency;
        latency_samples++;
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
    // Constrain to small working set so hits/misses/evictions actually occur
    // Working set: ~256 bytes (fits ~16 cache lines in 2-way cache with 16 sets)
    function automatic addr_t rand_addr();
        return addr_t'($urandom_range(0, 32'h0000_00FF));
    endfunction

    // Biased toward reads (80/20 read/write split, realistic for caches)
    function automatic req_kind_e rand_kind();
        return $urandom_range(0, 99) < 80 ? REQ_READ : REQ_WRITE;
    endfunction

    function automatic data_t rand_wdata();
        return data_t'($urandom());
    endfunction

    // -----------------------------------------------------------
    // Test sequence
    // -----------------------------------------------------------
    initial begin
        int i;
        addr_t addr;
        data_t data;
        real hit_rate;
        real avg_latency;

        clk = 0;
        rst_n = 0;
        req_valid = 1'b0;
        req_addr  = '0;
        req_kind  = REQ_NONE;
        req_wdata = '0;

        ref_model = new();
        reset_dut();
        $dumpfile("cache_sim.vcd");
        $dumpvars(0, cache_tb);

        // ---- Test 1: Sequential reads (all hits after first miss) ----
        $display("\n=== TEST 1: Sequential Reads ===");
        for (i = 0; i < 5; i = i + 1) begin
            addr = addr_t'(32'h00000000 + (i << 2));
            check_access($sformatf("seq_read_%0d", i), addr, REQ_READ, 32'b0);
            #10;
        end

        // ---- Test 2: Sequential writes (all misses, fills cache) ----
        $display("\n=== TEST 2: Sequential Writes ===");
        for (i = 0; i < 8; i = i + 1) begin
            addr = addr_t'(32'h00000100 + (i << 2));
            data = data_t'(32'hDEAD_0000 + i);
            check_access($sformatf("seq_write_%0d", i), addr, REQ_WRITE, data);
            #10;
        end

        // ---- Test 3: Read back written data (expect hits) ----
        $display("\n=== TEST 3: Read-After-Write (Expect Hits) ===");
        for (i = 0; i < 8; i = i + 1) begin
            addr = addr_t'(32'h00000100 + (i << 2));
            check_access($sformatf("read_after_write_%0d", i), addr, REQ_READ, 32'b0);
            #10;
        end

        // ---- Test 4: Random access pattern ----
        $display("\n=== TEST 4: Random Access Pattern (200 accesses) ===");
        for (i = 0; i < 200; i = i + 1) begin
            check_access($sformatf("random_%0d", i),
                         rand_addr(), rand_kind(), rand_wdata());
            #5;
        end

        // ---- Test 5: Full cache saturation and eviction ----
        $display("\n=== TEST 5: Full Cache Saturation & LRU Eviction ===");
        // Compute how many distinct addresses fill the cache:
        // 16 sets * 2 ways = 32 cache lines * 16 bytes/line = 512 bytes
        // So writing to sequential addresses should eventually evict
        for (i = 0; i < 40; i = i + 1) begin
            addr = addr_t'(32'h00000200 + (i << 4));  // 16-byte stride
            data = data_t'(32'hCAFE_0000 + i);
            check_access($sformatf("saturate_%0d", i), addr, REQ_WRITE, data);
            #10;
        end

        // ---- Test 6: Verify LRU eviction by accessing old data ----
        $display("\n=== TEST 6: Verify LRU Eviction (Should Miss) ===");
        for (i = 0; i < 10; i = i + 1) begin
            addr = addr_t'(32'h00000200 + (i << 4));
            check_access($sformatf("verify_evict_%0d", i), addr, REQ_READ, 32'b0);
            #10;
        end

        // ---- Performance summary ----
        $display("\n=====================================");
        $display("PERFORMANCE SUMMARY");
        $display("=====================================");
        $display("Total Checks:       %0d", checks);
        $display("Errors:             %0d", errors);
        $display("Hits:               %0d", hits);
        $display("Misses:             %0d", misses);

        if (hits + misses > 0) begin
            hit_rate = (100.0 * hits) / (hits + misses);
            $display("Hit Rate:           %.2f%%", hit_rate);
        end

        if (latency_samples > 0) begin
            avg_latency = real'(total_latency) / real'(latency_samples);
            $display("Average Latency:    %.2f cycles", avg_latency);
        end

        $display("=====================================");

        if (errors == 0) begin
            $display("ALL CHECKS PASSED");
        end else begin
            $display("FAILURES: %0d CHECK(S) FAILED", errors);
        end

        $finish;
    end

endmodule : cache_tb
