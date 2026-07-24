# Cache Project

A 2-way set-associative L1 cache with DMA streaming interface, designed for FPGA-based systems.

## Architecture Overview

The cache subsystem provides:
- **Cache Controller**: Orchestrates hit/miss logic, tag/data arrays, and replacement policy
- **2-way Set-Associative Design**: 16 sets, 2 ways per set (configurable via `cache_pkg.sv`)
- **DMA Streaming Interface**: AXI-Stream-style burst descriptor and data path
- **Backing Memory Interface**: Abstract interface to off-chip or different-clocked memory
- **Miss Handling FSM**: State machine for memory transactions and cache line fills

## Module Hierarchy

```
cache_controller (top-level cache logic)
├── tag_array (per-way metadata: valid, dirty, tag)
├── data_array (per-way cache line storage)
├── tag_compare (hit/miss detection)
├── replacement_policy (LRU or round-robin eviction)
└── miss_fsm (memory transaction orchestration)

dma_stream_if (front-end interface translator)
└── connects to cache_controller

mem_if (abstract memory interface)
└── connects backing store
```

## Configuration Parameters

Edit `cache_pkg.sv` to adjust:
- `ADDR_WIDTH` (32 bits) — address space
- `DATA_WIDTH` (32 bits) — word size
- `LINE_SIZE` (16 bytes) — cache line size
- `NUM_SETS` (16) — number of sets
- `WAYS` (2) — associativity
- `MEM_LATENCY` (4 cycles) — simulated backing store latency

## Design Goals & Roadmap

### Phase 1: Core Cache (Current)
- [x] Basic tag/data array storage
- [x] Hit/miss detection logic
- [x] Simple miss FSM for memory fill
- [x] DMA streaming burst translation
- [ ] Comprehensive testbench coverage
- [ ] Timing closure on target FPGA

### Phase 2: Clock Domain Crossing (Planned)
Decouple the cache logic from external interfaces and backing memory by adding **Clock Domain Crossing (CDC)** synchronizers. This adds architectural depth and handles real-world multi-clock systems.

**Rationale**: Real designs often have different clock domains (e.g., core clock, memory clock, external I/O clock). Synchronous caches require CDC to prevent metastability and data corruption.

**Implementation Strategy**:
1. **CDC FIFO between DMA and Cache**: Async burst descriptor queue with gray-code pointers
   - Allows DMA to run on an independent `clk_dma` while cache runs on `clk_core`
   
2. **CDC Handshake for mem_if**: Toggle-based synchronizer for memory transaction valid/done signals
   - Decouples cache controller (core clock) from memory subsystem (potentially slower/faster clock)
   
3. **Instrumentation CDC**: Separate clock domain for cycle counting and statistics
   - Avoids timing closure impact on critical path

**Key CDC Techniques**:
- Gray-code pointers for read/write pointers in async FIFOs
- Toggle synchronizers for single-bit control signals
- Double-flop registers for async inputs
- Clock domain boundary documentation in module headers

### Phase 3: Performance Enhancements (Future)
- Pipelined request handling (multiple outstanding requests)
- Configurable replacement policy (LRU, PLRU, random)
- Write-back vs write-through modes
- Prefetch logic and stream detection

## Testing

Run simulation with `cache_tb.sv`:
```bash
# Compile and run (simulation tool command)
# Examine waveforms for hit rates, latencies, and memory transactions
```

## Deliverables

- SystemVerilog RTL modules with clear port definitions
- Package file (`cache_pkg.sv`) for all typedefs and parameters
- Synthesizable code targeting modern FPGAs
- CDC implementation with metastability protection
- Comprehensive documentation and testbench
