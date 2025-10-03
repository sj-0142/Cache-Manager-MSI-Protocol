# Dual-Core Cache Manager with MSI Coherence  


## Overview  
-This project implements a **dual-core cache system** in **Verilog HDL**, featuring **private L1 and L2 caches per core** and a **snooping-based MSI coherence protocol**. 
-The **L2 caches** implement an **LRU (Least Recently Used) replacement policy**, ensuring efficient block management and reduced conflict misses.  
-Each core maintains **its own cache hierarchy**, while **snooping + bus updates** ensure coherence across cores.  
-A **Write-Update Write-Through** snooping architecture has been followed. 
-Inclusive cache hierarchy used (Data in L1 guaranteed to be in L2)

---

## Features  
- **Dual-Core Design**: Two independent cores, each with a **private L1 and L2 cache**.  
- **Cache Hierarchy**:  
  - **L1 Cache**: Direct-mapped for fast access.  
  - **L2 Cache**: Set Associatively Mapped.  
- **MSI Coherence Protocol**: Write-update strategy with bus snooping.  
- **Snooping Mechanism**: Ensures data consistency between cores on every update.  
- **Configurable Parameters**: Cache size, block size, and associativity can be scaled.  
- **Performance**: Synthesizes at **130 MHz** with low dynamic power (**0.033 W**).  

---

### Key Design Parameters  

- **L1 Cache**: Direct-mapped 
- **L2 Cache**: Set-associatively mapped - (Parametrised)
- **Block Size**: 4 bytes  
- **Address Width**: 11 bits  
- **Data Width**: 16 bits  
- **Coherence States**: MSI (Modified, Shared, Invalid)  
- **Bus Commands**: `BUS_RD`, `BUS_WR`, `BUS_UPDATE`, `IDLE`  

---

## Architecture  

The cache system is composed of **two cache controller instances** and a **shared snooping bus**:  

1. **Cache Controller (`cache_controller.v`)**  
   - Manages **private L1 and L2 caches** for each core.  
   - Uses MSI protocol for coherence.  
   - Handles:  
     - **Read requests** (L1 → L2 → memory).  
     - **Write requests** (update local caches + memory) - uses LRU cache replacmeent policy.  
     - **Snooped updates** (incoming bus updates from the other core).  

   **MSI State Transitions**:  
   - **Invalid → Shared**: On read miss and bus/memory fetch.  
   - **Shared → Shared**: On receiving bus updates from other cores.  
   - **Any → Shared**: On local write with update broadcast.  

2. **Dual-Core Integration (`dual_core_cache_system.v`)**  
   - Instantiates two **independent cache controllers**.  
   - Provides a **shared bus** for snooping and propagating write updates.
   - Defines priority scheme between the two cores 

---

## Operation Flow  

### Read Operation  
1. Core issues a read.  
2. Check L1 → if hit, return data.  
3. On L1 miss → check L2.  
4. On L2 miss → fetch from main memory, update L2 and promote to L1.  

### Write Operation (Write-Update MSI Protocol)  
1. Update local L1 + memory (write-through).  
2. Broadcast **BUS_UPDATE** on snooping bus.  
3. Other core snoops the update → transitions its cache line to **Shared** (if present).  

---

## Implementation & Tools  

**HDL**: Verilog HDL (2001)  
**Synthesis Tool**: Xilinx Vivado Design Suite  
**Target FPGA**: Nexys 4 DDR (Artix-7 XC7A100TCSG324-1)  
**Verification**: RTL simulation with multi-core read/write workloads  
**Resource Usage**: Configurable L1/L2 sizes with LRU replacement policy  

---


