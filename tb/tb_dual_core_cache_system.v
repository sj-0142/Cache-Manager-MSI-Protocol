
`timescale 1ns / 1ps

module tb_dual_core_cache_system();
    
    parameter ADDR_BITS = 11;
    parameter DATA_BITS = 8;
    parameter BLOCK_BYTES = 2;
    parameter BLOCK_OFFSET = 1;
    parameter CLOCK_PERIOD = 10;
    
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
    

    task display_status;
        input [31:0] test_num;
        input [127:0] description;
        begin
            $display("\n=== TEST %0d: %s ===", test_num, description);
            $display("Core 0: addr=0x%h, data_in=0x%h, mode=%b", addr_0, data_in_0, mode_0);
            $display("Core 0: data_out=0x%h, hit1=%b, hit2=%b, wait=%b", data_out_0, hit1_0, hit2_0, wait_req_0);
            $display("Core 1: addr=0x%h, data_in=0x%h, mode=%b", addr_1, data_in_1, mode_1);
            $display("Core 1: data_out=0x%h, hit1=%b, hit2=%b, wait=%b", data_out_1, hit1_1, hit2_1, wait_req_1);
            
            // Check if bus signals exist (for debugging)
            if ($test$plusargs("debug_bus")) begin
                $display("Core 0 Bus: cmd=0x%h, addr=0x%h, data=0x%h", dut.bus_cmd_0, dut.bus_addr_0, dut.bus_data_0);
                $display("Core 1 Bus: cmd=0x%h, addr=0x%h, data=0x%h", dut.bus_cmd_1, dut.bus_addr_1, dut.bus_data_1);
            end
        end
    endtask
    
    // Task to check expected results with proper timing
    task check_result;
        input [31:0] test_num;
        input [DATA_BITS-1:0] exp_data_0, exp_data_1;
        input exp_hit1_0, exp_hit2_0, exp_wait_0;
        input exp_hit1_1, exp_hit2_1, exp_wait_1;
        begin
            if (data_out_0 !== exp_data_0 || hit1_0 !== exp_hit1_0 || hit2_0 !== exp_hit2_0 || wait_req_0 !== exp_wait_0 ||
                data_out_1 !== exp_data_1 || hit1_1 !== exp_hit1_1 || hit2_1 !== exp_hit2_1 || wait_req_1 !== exp_wait_1) begin
                $display("ERROR in TEST %0d!", test_num);
                $display("Expected Core 0: data=0x%h, hit1=%b, hit2=%b, wait=%b", exp_data_0, exp_hit1_0, exp_hit2_0, exp_wait_0);
                $display("Actual   Core 0: data=0x%h, hit1=%b, hit2=%b, wait=%b", data_out_0, hit1_0, hit2_0, wait_req_0);
                $display("Expected Core 1: data=0x%h, hit1=%b, hit2=%b, wait=%b", exp_data_1, exp_hit1_1, exp_hit2_1, exp_wait_1);
                $display("Actual   Core 1: data=0x%h, hit1=%b, hit2=%b, wait=%b", data_out_1, hit1_1, hit2_1, wait_req_1);

            end else begin
                $display("PASS: TEST %0d", test_num);
            end
        end
    endtask


    task apply_and_check;
        input [ADDR_BITS-1:0] new_addr_0, new_addr_1;
        input [DATA_BITS-1:0] new_data_in_0, new_data_in_1;
        input new_mode_0, new_mode_1;
        input [31:0] test_num;
        input [127:0] description;
        input [DATA_BITS-1:0] exp_data_0, exp_data_1;
        input exp_hit1_0, exp_hit2_0, exp_wait_0;
        input exp_hit1_1, exp_hit2_1, exp_wait_1;
        begin
            // Apply inputs at clock edge
            @(posedge clk);
            addr_0 = new_addr_0;
            addr_1 = new_addr_1;
            data_in_0 = new_data_in_0;
            data_in_1 = new_data_in_1;
            mode_0 = new_mode_0;
            mode_1 = new_mode_1;
            
            // Wait for outputs to settle (sample at negative edge)
            @(negedge clk);
            display_status(test_num, description);
            check_result(test_num, exp_data_0, exp_data_1, exp_hit1_0, exp_hit2_0, exp_wait_0, exp_hit1_1, exp_hit2_1, exp_wait_1);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("Starting TIMING-FIXED Dual-Core Cache Controller Test");
        $display("====================================================");
        
        
        // Reset sequence
        #5
        rst = 0;
        #15
        
        $display("\n=== MEMORY LAYOUT VERIFICATION ===");
        $display("main_memory[0] = 0x10, main_memory[1] = 0x11, main_memory[2] = 0x12, ...");
        $display("Address 0x002 → memory[1] = 0x11");
        $display("Address 0x000 → memory[0] = 0x10");
        #10
        // TEST 1: Core 0 reads from memory (COMPULSORY MISS)
        $display("\n=== BASIC FUNCTIONALITY TESTS ===");
        apply_and_check(
            11'h002, 11'h000,      // addr_0, addr_1
            8'h00, 8'h00,          // data_in_0, data_in_1  
            1'b0, 1'b0,            // mode_0, mode_1 (both read)
            1, "Core 0 compulsory miss",
            8'h00, 8'h00,          // exp_data_0, exp_data_1
            1'b0, 1'b0, 1'b1,      // exp_hit1_0, exp_hit2_0, exp_wait_0
            1'b0, 1'b0, 1'b1       // exp_hit1_1, exp_hit2_1, exp_wait_1
        );
        #20
        // TEST 2: Core 0 reads same location again (L1 HIT)
        apply_and_check(
            11'h002, 11'h000,      // Keep same addresses
            8'h00, 8'h00,
            1'b0, 1'b0,
            2, "Core 0 L1 hit",
            8'h11, 8'h10,
            1'b1, 1'b0, 1'b0,      // Should be L1 hit now
            1'b1, 1'b0, 1'b0
        );
        #20
        // TEST 3: Core 1 reads same location (COMPULSORY MISS for Core 1)  
        apply_and_check(
            11'h002, 11'h002,      // Both cores access same address
            8'h00, 8'h00,
            1'b0, 1'b0,
            3, "Core 1 compulsory miss same address",
            8'h11, 8'h10,
            1'b1, 1'b0, 1'b0,      // Core 0 still hits
            1'b0, 1'b0, 1'b1       // Core 1 should miss
        );
        #20
        // TEST 4: Core 0 writes to the location (write update)
        apply_and_check(
            11'h002, 11'h002,
            8'hAB, 8'h00,
            1'b1, 1'b0,            // Core 0 write, Core 1 read
            4, "Core 0 write with broadcast",
            8'h11, 8'h11,          // Core 0 writes AB, Core 1 still has old data
            1'b0, 1'b0, 1'b0,      // Write doesn't set hit flags
            1'b1, 1'b0, 1'b0       // Core 1 should hit cached data
        );
        #20
        // TEST 5: Core 1 reads the updated location (should see updated data via snooping)
        
        apply_and_check(
            11'h002, 11'h002,
            8'h00, 8'h00,
            1'b0, 1'b0,
            5, "Core 1 read after Core 0 write update",
            8'hAB, 8'hAB,          // Both should see updated data
            1'b1, 1'b0, 1'b0,      // Core 0 L1 hit
            1'b1, 1'b0, 1'b0       // Core 1 L1 hit (snooped data)
        );
        #20
        // TEST 6: Test different addresses
        $display("\n=== DIFFERENT ADDRESS TESTS ===");
        apply_and_check(
            11'h004, 11'h006,      // Different addresses
            8'h00, 8'h00,
            1'b0, 1'b0,
            6, "Both cores read different addresses",
            8'hab, 8'hab,          // memory[2]=0x12, memory[3]=0x13
            1'b0, 1'b0, 1'b1,      // Core 0 miss
            1'b0, 1'b0, 1'b1       // Core 1 miss
        );
        #20
        // TEST 7: Verify L1 hits after allocation
        apply_and_check(
            11'h004, 11'h006,      // Same addresses as previous test
            8'h00, 8'h00,
            1'b0, 1'b0,
            7, "L1 hits after previous allocation",
            8'h12, 8'h13,
            1'b1, 1'b0, 1'b0,      // Core 0 L1 hit  
            1'b1, 1'b0, 1'b0       // Core 1 L1 hit
        );
         
        $finish;
    end
    
//    // Enhanced monitor for debugging
//    always @(posedge clk) begin
//        if (!rst) begin
//            $display("CLK+ T:%0t | C0[A:%h→D:%h H1:%b W:%b] C1[A:%h→D:%h H1:%b W:%b]",
//                     $time, addr_0, data_out_0, hit1_0, wait_req_0,
//                            addr_1, data_out_1, hit1_1, wait_req_1);
//        end
//    end
    
    // Generate VCD file
    initial begin
        $dumpfile("cache_timing_fixed_test.vcd");
        $dumpvars(0, tb_dual_core_cache_system);
    end
    
endmodule
