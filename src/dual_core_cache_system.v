//AUTHOR: SANJAY JAYARAMAN

module dual_core_cache_system #(
    parameter ADDR_BITS = 11,
    parameter DATA_BITS = 8,
    parameter BLOCK_BYTES = 2,
    parameter BLOCK_OFFSET = 1
)(
    input  wire  clk,
    input  wire  rst,
    
    // Core 0 interface
    input  wire [ADDR_BITS-1:0]  addr_0,
    input  wire [DATA_BITS-1:0]  data_in_0,
    input  wire                  mode_0,
    output wire [DATA_BITS-1:0]  data_out_0,
    output wire                  hit1_0,
    output wire                  hit2_0,
    output wire                  wait_req_0,
    
    // Core 1 interface
    input  wire [ADDR_BITS-1:0]  addr_1,
    input  wire [DATA_BITS-1:0]  data_in_1,
    input  wire                  mode_1,
    output wire [DATA_BITS-1:0]  data_out_1,
    output wire                  hit1_1,
    output wire                  hit2_1,
    output wire                  wait_req_1
);
    localparam MEM_BLOCKS = 64;
    
    // Bus signals from each core
    wire [1:0]            bus_cmd_0, bus_cmd_1;
    wire [ADDR_BITS-1:0]  bus_addr_0, bus_addr_1;
    wire [DATA_BITS-1:0]  bus_data_0, bus_data_1;
    
    // Memory interface signals for Core 0
    wire [5:0]            mem_rd_addr_0;
    wire [DATA_BITS-1:0]  mem_rd_data_0;
    wire                  mem_rd_en_0;
    wire [5:0]            mem_wr_addr_0;
    wire [DATA_BITS-1:0]  mem_wr_data_0;
    wire                  mem_wr_en_0;
    
    // Memory interface signals for Core 1
    wire [5:0]            mem_rd_addr_1;
    wire [DATA_BITS-1:0]  mem_rd_data_1;
    wire                  mem_rd_en_1;
    wire [5:0]            mem_wr_addr_1;
    wire [DATA_BITS-1:0]  mem_wr_data_1;
    wire                  mem_wr_en_1;
    
    
    // Separate source ID signals for each core
    wire [0:0] bus_src_out_0;
    wire [0:0] bus_src_out_1;
    
    // Each core receives the other's source ID
    wire [0:0] bus_src_id_0;
    wire [0:0] bus_src_id_1;
    
    
    // Shared main memory
    reg [DATA_BITS-1:0] main_memory [0:MEM_BLOCKS-1];
    integer i;
    
    // Memory read data assignment
    assign mem_rd_data_0 = main_memory[mem_rd_addr_0];
    assign mem_rd_data_1 = main_memory[mem_rd_addr_1];
    
    
    // FIXED: Separate bus inputs for each core to prevent self-snooping
    wire [1:0]            bus_cmd_to_core0;
    wire [ADDR_BITS-1:0]  bus_addr_to_core0;
    wire [DATA_BITS-1:0]  bus_data_to_core0;
    
    wire [1:0]            bus_cmd_to_core1;
    wire [ADDR_BITS-1:0]  bus_addr_to_core1;
    wire [DATA_BITS-1:0]  bus_data_to_core1;
    
    // Core 0 sees only Core 1's bus activity
    assign bus_cmd_to_core0 = bus_cmd_1;
    assign bus_addr_to_core0 = bus_addr_1;
    assign bus_data_to_core0 = bus_data_1;
    
    // Core 1 sees only Core 0's bus activity
    assign bus_cmd_to_core1 = bus_cmd_0;
    assign bus_addr_to_core1 = bus_addr_0;
    assign bus_data_to_core1 = bus_data_0;
    
    // Memory initialization
    initial begin
        for (i = 0; i < MEM_BLOCKS; i = i + 1) begin
            main_memory[i] = i + 8'h10;
        end
    end
    
    // Memory write logic
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < MEM_BLOCKS; i = i + 1) begin
                main_memory[i] <= i + 8'h10;
            end
        end else begin
            // Handle memory writes from both cores
            if (mem_wr_en_0) begin
                main_memory[mem_wr_addr_0] <= mem_wr_data_0;
            end
            if (mem_wr_en_1) begin
                main_memory[mem_wr_addr_1] <= mem_wr_data_1;
            end
        end
    end
    
    // Cross-connect source IDs
    assign bus_src_id_0 = bus_src_out_1;  // Core0 snoops Core1
    assign bus_src_id_1 = bus_src_out_0;  // Core1 snoops Core0
    
    // Core 0 instantiation
    cache_controller #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .BLOCK_BYTES(BLOCK_BYTES),
        .BLOCK_OFFSET(BLOCK_OFFSET)
    ) core0_cache (
        .clk(clk),
        .rst(rst),
        .core_id(1'b0),
        .addr(addr_0),
        .data_in(data_in_0),
        .mode(mode_0),
        .bus_cmd(bus_cmd_0),
        .bus_addr(bus_addr_0),
        .bus_data(bus_data_0),
        .bus_cmd_in(bus_cmd_to_core0),
        .bus_addr_in(bus_addr_to_core0),
        .bus_data_in(bus_data_to_core0),
        
        .bus_src_out(bus_src_out_0),
        .bus_src_id(bus_src_id_0),

        
        .mem_rd_addr(mem_rd_addr_0),
        .mem_rd_data(mem_rd_data_0),
        .mem_rd_en(mem_rd_en_0),
        .mem_wr_addr(mem_wr_addr_0),
        .mem_wr_data(mem_wr_data_0),
        .mem_wr_en(mem_wr_en_0),
        .data_out(data_out_0),
        .hit1(hit1_0),
        .hit2(hit2_0),
        .wait_req(wait_req_0)
    );

    // Core 1 instantiation
    cache_controller #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .BLOCK_BYTES(BLOCK_BYTES),
        .BLOCK_OFFSET(BLOCK_OFFSET)
    ) core1_cache (
        .clk(clk),
        .rst(rst),
        .core_id(1'b1),
        .addr(addr_1),
        .data_in(data_in_1),
        .mode(mode_1),
        .bus_cmd(bus_cmd_1),
        .bus_addr(bus_addr_1),
        .bus_data(bus_data_1),
        .bus_cmd_in(bus_cmd_to_core1),
        .bus_addr_in(bus_addr_to_core1),
        .bus_data_in(bus_data_to_core1),
        
        .bus_src_out(bus_src_out_1),
        .bus_src_id(bus_src_id_1),

        
        .mem_rd_addr(mem_rd_addr_1),
        .mem_rd_data(mem_rd_data_1),
        .mem_rd_en(mem_rd_en_1),
        .mem_wr_addr(mem_wr_addr_1),
        .mem_wr_data(mem_wr_data_1),
        .mem_wr_en(mem_wr_en_1),
        .data_out(data_out_1),
        .hit1(hit1_1),
        .hit2(hit2_1),
        .wait_req(wait_req_1)
    );

endmodule
