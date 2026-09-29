# Two-way set-associative L1 cache (SystemVerilog)

RTL prototype of a small L1 cache, with separate tag and data arrays, hit detection, replacement logic, and a miss state machine. The default configuration in `src/cache_pkg.sv` is 16 sets, 2 ways, 32-bit data, and 16-byte lines.

## Repository map

| Path | Purpose |
| --- | --- |
| `src/cache_controller.sv` | Top-level cache control and request/response handling. |
| `src/tag_array.sv`, `src/data_array.sv` | Tag and cache-line storage. |
| `src/tag_compare.sv`, `src/replacement_policy.sv`, `src/miss_fsm.sv` | Hit lookup, replacement, and miss flow. |
| `src/memory_interface.sv` | Backing-memory interface used by the cache design. |
| `tb/cache_tb.sv` | SystemVerilog testbench with a reference memory and check/error, hit/miss, and latency counters. |
| `basys3_top.sv`, `basys3.xdc` | Basys3 switch-to-LED top and pin constraints. |

## Status

The cache RTL and testbench are present. The Basys3 top currently demonstrates switch-to-LED passthrough; it does not exercise the cache. Cache integration with the [RV32I CPU](https://github.com/nhmckinney/riscv-cpu), FPGA synthesis/timing validation, and published simulation results remain next steps.

## Next steps

Run the cache testbench with a simulator that supports its SystemVerilog features, record reproducible correctness and latency results, connect the cache to the CPU memory stage, and validate the integrated design on Basys3.
