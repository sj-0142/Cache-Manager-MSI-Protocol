

module dual_core_cache_system #(
    parameter ADDR_BITS = 11,
    parameter DATA_BITS = 16,
    parameter BLOCK_BYTES = 4,
    parameter BLOCK_OFFSET = 2
)(
    input  wire  clk,
    input  wire  rst,
    
    // Core 0 interface i/o
    input  wire [ADDR_BITS-1:0]  addr_0,
    input  wire [DATA_BITS-1:0]  data_in_0,
    input  wire                  mode_0,
    output wire [DATA_BITS-1:0]  data_out_0,
    output wire                  hit1_0,
    output wire                  hit2_0,
    output wire                  wait_req_0,
    
    // Core 1 interface i/o
    input  wire [ADDR_BITS-1:0]  addr_1,
    input  wire [DATA_BITS-1:0]  data_in_1,
    input  wire                  mode_1,
    output wire [DATA_BITS-1:0]  data_out_1,
    output wire                  hit1_1,
    output wire                  hit2_1,
    output wire                  wait_req_1
);

    // Universal common bus signals
    wire [1:0]            universal_bus_cmd;
    wire [ADDR_BITS-1:0]  universal_bus_addr;
    wire [DATA_BITS-1:0]  universal_bus_data;
    
    // Bus signals from each core
    wire [1:0]            bus_cmd_0, bus_cmd_1;
    wire [ADDR_BITS-1:0]  bus_addr_0, bus_addr_1;
    wire [DATA_BITS-1:0]  bus_data_0, bus_data_1;
    
    // Priority scheme (Core 0 has priority over Core 1)
    assign universal_bus_cmd = (bus_cmd_0 != 2'b00) ? bus_cmd_0 : 
                               (bus_cmd_1 != 2'b00) ? bus_cmd_1 : 2'b00;
    assign universal_bus_addr = (bus_cmd_0 != 2'b00) ? bus_addr_0 : bus_addr_1;
    assign universal_bus_data = (bus_cmd_0 != 2'b00) ? bus_data_0 : bus_data_1;

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
        .bus_cmd_in(universal_bus_cmd),
        .bus_addr_in(universal_bus_addr),
        .bus_data_in(universal_bus_data),
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
        .bus_cmd_in(universal_bus_cmd),
        .bus_addr_in(universal_bus_addr),
        .bus_data_in(universal_bus_data),
        .data_out(data_out_1),
        .hit1(hit1_1),
        .hit2(hit2_1),
        .wait_req(wait_req_1)
    );

endmodule
