//AUTHOR: SANJAY JAYARAMAN

module dual_core_cache_system #(
    parameter ADDR_BITS = 11,
    parameter DATA_BITS = 8,
    parameter BLOCK_BYTES = 2,
    parameter BLOCK_OFFSET = 1
)(
    input  wire  clk,
    input  wire  rst,
    
    input  wire [ADDR_BITS-1:0]  addr_0,
    input  wire [DATA_BITS-1:0]  data_in_0,
    input  wire                  mode_0,
    output wire [DATA_BITS-1:0]  data_out_0,
    output wire                  hit1_0,
    output wire                  hit2_0,
    output wire                  wait_req_0,
    
    input  wire [ADDR_BITS-1:0]  addr_1,
    input  wire [DATA_BITS-1:0]  data_in_1,
    input  wire                  mode_1,
    output wire [DATA_BITS-1:0]  data_out_1,
    output wire                  hit1_1,
    output wire                  hit2_1,
    output wire                  wait_req_1
);
    localparam MEM_BLOCKS = 64;
    
    wire [1:0]            bus_cmd_0, bus_cmd_1;
    wire [ADDR_BITS-1:0]  bus_addr_0, bus_addr_1;
    wire [DATA_BITS-1:0]  bus_data_0, bus_data_1;
    
    wire [5:0]            mem_rd_addr_0;
    wire [DATA_BITS-1:0]  mem_rd_data_0;
    wire                  mem_rd_en_0;
    wire [5:0]            mem_wr_addr_0;
    wire [DATA_BITS-1:0]  mem_wr_data_0;
    wire                  mem_wr_en_0;
    
    wire [5:0]            mem_rd_addr_1;
    wire [DATA_BITS-1:0]  mem_rd_data_1;
    wire                  mem_rd_en_1;
    wire [5:0]            mem_wr_addr_1;
    wire [DATA_BITS-1:0]  mem_wr_data_1;
    wire                  mem_wr_en_1;
    
    wire [0:0] bus_src_out_0;
    wire [0:0] bus_src_out_1;
    
    wire [0:0] bus_src_id_0;
    wire [0:0] bus_src_id_1;
    
    reg [DATA_BITS-1:0] main_memory [0:MEM_BLOCKS-1];
    integer i;
    
    assign mem_rd_data_0 = main_memory[mem_rd_addr_0];
    assign mem_rd_data_1 = main_memory[mem_rd_addr_1];
    
    wire [1:0]            bus_cmd_to_core0;
    wire [ADDR_BITS-1:0]  bus_addr_to_core0;
    wire [DATA_BITS-1:0]  bus_data_to_core0;
    
    wire [1:0]            bus_cmd_to_core1;
    wire [ADDR_BITS-1:0]  bus_addr_to_core1;
    wire [DATA_BITS-1:0]  bus_data_to_core1;
    
    assign bus_cmd_to_core0 = bus_cmd_1;
    assign bus_addr_to_core0 = bus_addr_1;
    assign bus_data_to_core0 = bus_data_1;
    
    assign bus_cmd_to_core1 = bus_cmd_0;
    assign bus_addr_to_core1 = bus_addr_0;
    assign bus_data_to_core1 = bus_data_0;
    
    initial begin
        for (i = 0; i < MEM_BLOCKS; i = i + 1) begin
            main_memory[i] = i + 8'h10;
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < MEM_BLOCKS; i = i + 1) begin
                main_memory[i] <= i + 8'h10;
            end
        end else begin
            if (mem_wr_en_0) begin
                main_memory[mem_wr_addr_0] <= mem_wr_data_0;
            end
            if (mem_wr_en_1) begin
                main_memory[mem_wr_addr_1] <= mem_wr_data_1;
            end
        end
    end
    
    assign bus_src_id_0 = bus_src_out_1;  
    assign bus_src_id_1 = bus_src_out_0;  
    
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
