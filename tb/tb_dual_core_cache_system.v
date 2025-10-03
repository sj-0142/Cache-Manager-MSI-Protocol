`timescale 1ns / 1ps

module tb_dual_core_cache_system();
    
    // Parameters
    parameter ADDR_BITS = 11;
    parameter DATA_BITS = 16;
    parameter BLOCK_BYTES = 4;
    parameter BLOCK_OFFSET = 2;
    parameter CLOCK_PERIOD = 10; // 10ns clock period (100MHz)
    
    // Testbench signals
    reg  clk;
    reg  rst;
    
    // Core 0 signals
    reg  [ADDR_BITS-1:0] addr_0;
    reg  [DATA_BITS-1:0] data_in_0;
    reg                  mode_0;
    wire [DATA_BITS-1:0] data_out_0;
    wire                 hit1_0, hit2_0, wait_req_0;
    
    // Core 1 signals
    reg  [ADDR_BITS-1:0] addr_1;
    reg  [DATA_BITS-1:0] data_in_1;
    reg                  mode_1;
    wire [DATA_BITS-1:0] data_out_1;
    wire                 hit1_1, hit2_1, wait_req_1;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Instantiate DUT
    dual_core_cache_system #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .BLOCK_BYTES(BLOCK_BYTES),
        .BLOCK_OFFSET(BLOCK_OFFSET)
    ) dut (
        .clk(clk),
        .rst(rst),
        .addr_0(addr_0),
        .data_in_0(data_in_0),
        .mode_0(mode_0),
        .data_out_0(data_out_0),
        .hit1_0(hit1_0),
        .hit2_0(hit2_0),
        .wait_req_0(wait_req_0),
        .addr_1(addr_1),
        .data_in_1(data_in_1),
        .mode_1(mode_1),
        .data_out_1(data_out_1),
        .hit1_1(hit1_1),
        .hit2_1(hit2_1),
        .wait_req_1(wait_req_1)
    );
    
    // Task to display test results
    task display_status;
        input [31:0] test_num;
        input [127:0] description;
        begin
            $display("\\n=== TEST %0d: %s ===", test_num, description);
            $display("Core 0: addr=0x%h, data_in=0x%h, mode=%b", addr_0, data_in_0, mode_0);
            $display("Core 0: data_out=0x%h, hit1=%b, hit2=%b, wait=%b", data_out_0, hit1_0, hit2_0, wait_req_0);
            $display("Core 1: addr=0x%h, data_in=0x%h, mode=%b", addr_1, data_in_1, mode_1);
            $display("Core 1: data_out=0x%h, hit1=%b, hit2=%b, wait=%b", data_out_1, hit1_1, hit2_1, wait_req_1);
            $display("Bus: cmd=0x%h, addr=0x%h, data=0x%h", dut.universal_bus_cmd, dut.universal_bus_addr, dut.universal_bus_data);
        end
    endtask
    
    // Task to wait for clock edges
    task wait_clocks;
        input [7:0] num_clocks;
        begin
            repeat(num_clocks) @(posedge clk);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("Starting Dual-Core Cache Controller with MSI Protocol Test");
        $display("=============================================================");
        
        // Initialize signals
        rst = 1;
        addr_0 = 0; data_in_0 = 0; mode_0 = 0;
        addr_1 = 0; data_in_1 = 0; mode_1 = 0;
        
        // Reset sequence
        wait_clocks(5);
        rst = 0;
        wait_clocks(2);
        
        // TEST 1: Core 0 reads from memory (miss)
        addr_0 = 11'h040;  // Address 0x040
        mode_0 = 0;        // Read
        wait_clocks(1);
        display_status(1, "Core 0 read miss from memory");
        
        // TEST 2: Core 0 reads same location again (L1 hit)
        wait_clocks(1);
        display_status(2, "Core 0 read hit from L1 cache");
        
        // TEST 3: Core 1 reads same location (should get from memory)
        addr_1 = 11'h040;  // Same address
        mode_1 = 0;        // Read
        wait_clocks(1);
        display_status(3, "Core 1 read same address");
        
        // TEST 4: Core 0 writes to the location (write update)
        addr_0 = 11'h040;
        data_in_0 = 16'hABCD;
        mode_0 = 1;        // Write
        wait_clocks(1);
        display_status(4, "Core 0 write with update broadcast");
        
        // TEST 5: Core 1 reads the updated location (should see updated data)
        addr_1 = 11'h040;
        mode_1 = 0;        // Read
        wait_clocks(1);
        display_status(5, "Core 1 read after Core 0 write update");
        
        // TEST 6: Core 1 writes to same location (write update)
        addr_1 = 11'h040;
        data_in_1 = 16'h1234;
        mode_1 = 1;        // Write
        wait_clocks(1);
        display_status(6, "Core 1 write with update broadcast");
        
        // TEST 7: Core 0 reads the location updated by Core 1
        addr_0 = 11'h040;
        mode_0 = 0;        // Read
        wait_clocks(1);
        display_status(7, "Core 0 read after Core 1 write update");
        
        // TEST 8: Different address for Core 0
        addr_0 = 11'h080;  // Different address
        mode_0 = 0;        // Read
        wait_clocks(1);
        display_status(8, "Core 0 read from different address");
        
        // TEST 9: Core 1 writes to different address
        addr_1 = 11'h0C0;  // Another different address
        data_in_1 = 16'h5678;
        mode_1 = 1;        // Write
        wait_clocks(1);
        display_status(9, "Core 1 write to different address");
        
        // TEST 10: Core 0 reads from Core 1's written address
        addr_0 = 11'h0C0;  // Same as Core 1's address
        mode_0 = 0;        // Read
        wait_clocks(1);
        display_status(10, "Core 0 read from Core 1's written address");
        
        // TEST 11: Test L2 cache behavior - access enough addresses to fill L1
        $display("\\n=== TESTING L2 CACHE BEHAVIOR ===");
        
        // Fill L1 cache of Core 0 with different addresses
        addr_0 = 11'h100; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h140; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h180; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h1C0; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h200; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h240; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h280; mode_0 = 0; wait_clocks(1);
        addr_0 = 11'h2C0; mode_0 = 0; wait_clocks(1);
        
        // Now access one more address (should cause L1 eviction and L2 allocation)
        addr_0 = 11'h300; mode_0 = 0; wait_clocks(1);
        display_status(11, "L1 cache full, accessing new address");
        
        // Access earlier address (should be L2 hit and promote to L1)
        addr_0 = 11'h100; mode_0 = 0; wait_clocks(1);
        display_status(12, "Access evicted address (L2 hit)");
        
        // TEST 12: Verify data consistency with multiple writes
        $display("\\n=== TESTING DATA CONSISTENCY ===");
        
        // Both cores write to same address with different data
        addr_0 = 11'h400; data_in_0 = 16'hDEAD; mode_0 = 1;
        addr_1 = 11'h400; data_in_1 = 16'hBEEF; mode_1 = 1;
        wait_clocks(1);
        display_status(13, "Both cores write to same address");
        
        // Read from both cores to see final value
        mode_0 = 0; mode_1 = 0;
        wait_clocks(1);
        display_status(14, "Both cores read after simultaneous write");
        
        // Final wait and summary
        wait_clocks(10);
        
        $display("\\n=============================================================");
        $display("Expected behaviors:");
        $display("1. Read misses should assert wait_req and fetch from memory");
        $display("2. Read hits should not assert wait_req");
        $display("3. Writes should broadcast updates via bus");
        $display("4. Updated data should be consistent across cores");
        $display("5. L1 misses should check L2 before going to memory");
        $display("=============================================================");
        
        $finish;
    end
    
    // Monitor for debugging
//    initial begin
//        $monitor("Time: %0t | Core0: A=%h D_in=%h M=%b D_out=%h H1=%b H2=%b W=%b | Core1: A=%h D_in=%h M=%b D_out=%h H1=%b H2=%b W=%b | Bus: C=%b A=%h D=%h",
//                 $time, addr_0, data_in_0, mode_0, data_out_0, hit1_0, hit2_0, wait_req_0,
//                        addr_1, data_in_1, mode_1, data_out_1, hit1_1, hit2_1, wait_req_1,
//                        dut.universal_bus_cmd, dut.universal_bus_addr, dut.universal_bus_data);
//    end
    
    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("cache_msi_test.vcd");
        $dumpvars(0, tb_dual_core_cache_system);
    end
    
endmodule
