
module cache_controller #(

// MM Size -> MEM_SIZE X DATA_BITS bits
// L1 Cache Size -> L1_LINES x DATA_BITS bits
// L2 Cache Size -> (L2_SETS*L2_WAYS) x DATA_BITS


    parameter ADDR_BITS = 11,
    parameter DATA_BITS = 16,
    parameter BLOCK_BYTES = 4,
    parameter BLOCK_OFFSET = 2
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  core_id,     // 0 for Core0 and 1 for Core1
    input  wire [ADDR_BITS-1:0]  addr,
    input  wire [DATA_BITS-1:0]  data_in,
    input  wire                  mode,        // 0 = read, 1 = write
    
    // Bus interface i/o
    output reg  [1:0]            bus_cmd,     // 00=IDLE, 01=BUS_RD, 10=BUS_WR, 11=BUS_UPDATE
    output reg  [ADDR_BITS-1:0]  bus_addr,
    output reg  [DATA_BITS-1:0]  bus_data,
    input  wire [1:0]            bus_cmd_in,  // Bus commands from other core
    input  wire [ADDR_BITS-1:0]  bus_addr_in,
    input  wire [DATA_BITS-1:0]  bus_data_in,
    
    output reg  [DATA_BITS-1:0]  data_out,
    output reg                   hit1,
    output reg                   hit2,
    output reg                   wait_req
);

    // Cache parameters
    localparam L1_LINES      = 4;
    localparam L1_INDEX_BITS = 2;
    localparam L1_TAG_BITS   = ADDR_BITS - L1_INDEX_BITS - BLOCK_OFFSET; 
    localparam L1_BLOCK_BITS = DATA_BITS;
    
    localparam L2_SETS       = 16;
    localparam L2_WAYS       = 1;
    localparam L2_INDEX_BITS = 4;
    localparam L2_TAG_BITS   = ADDR_BITS - L2_INDEX_BITS - 2;
    localparam L2_BLOCK_BITS = DATA_BITS;
    
    localparam MEM_BLOCKS = 32;
    
    // MSI Protocol state initialisation
    localparam INVALID  = 2'b00;
    localparam SHARED   = 2'b01;
    localparam MODIFIED = 2'b10;
    
    // Bus Command initialisation
    localparam BUS_IDLE   = 2'b00;
    localparam BUS_RD     = 2'b01;
    localparam BUS_WR     = 2'b10;
    localparam BUS_UPDATE = 2'b11;

    // L1 Cache Arrays - separate for each core 
    reg [L1_BLOCK_BITS-1:0] l1_data   [0:1][0:L1_LINES-1];
    reg [L1_TAG_BITS-1:0]   l1_tag    [0:1][0:L1_LINES-1];
    reg [1:0]               l1_msi    [0:1][0:L1_LINES-1]; 
    
    // L2 Cache Arrays - separate for each core
    reg [L2_BLOCK_BITS-1:0] l2_data   [0:1][0:L2_SETS-1][0:L2_WAYS-1];
    reg [L2_TAG_BITS-1:0]   l2_tag    [0:1][0:L2_SETS-1][0:L2_WAYS-1];
    reg [1:0]               l2_msi    [0:1][0:L2_SETS-1][0:L2_WAYS-1];
    reg [1:0]               lru       [0:1][0:L2_SETS-1];

    // Shared Main Memory
    reg [DATA_BITS-1:0]     main_memory [0:MEM_BLOCKS-1];
    
    // Internal registers
    reg found;
    reg [DATA_BITS-1:0] fetched;
    integer i, j, k;

    // Address breakdown
    wire [1:0]                  offset;
    wire [L1_INDEX_BITS-1:0]    l1_index;
    wire [L1_TAG_BITS-1:0]      l1_tag_in;
    wire [L2_INDEX_BITS-1:0]    l2_index;
    wire [L2_TAG_BITS-1:0]      l2_tag_in;
    
    assign offset = addr[1:0];
    assign l1_index = addr[1+L1_INDEX_BITS:2];
    assign l1_tag_in = addr[ADDR_BITS-1:L1_INDEX_BITS+2];
    assign l2_index = addr[1+L2_INDEX_BITS:2];
    assign l2_tag_in = addr[ADDR_BITS-1:L2_INDEX_BITS+2];
    
    
    // Snooping address breakdown -> assigns the index and tag of the variable being processed by the bus in snoop variables
    wire [L1_INDEX_BITS-1:0]    snoop_l1_index;
    wire [L1_TAG_BITS-1:0]      snoop_l1_tag;
    wire [L2_INDEX_BITS-1:0]    snoop_l2_index;
    wire [L2_TAG_BITS-1:0]      snoop_l2_tag;
    
    assign snoop_l1_index = bus_addr_in[1+L1_INDEX_BITS:2];
    assign snoop_l1_tag = bus_addr_in[ADDR_BITS-1:L1_INDEX_BITS+2];
    assign snoop_l2_index = bus_addr_in[1+L2_INDEX_BITS:2];
    assign snoop_l2_tag = bus_addr_in[ADDR_BITS-1:L2_INDEX_BITS+2];

    always @(posedge clk) begin
        if (rst) begin
            // Initialize both caches and states (L1 and L2)
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < L1_LINES; j = j + 1) begin
                    l1_data[i][j] <= 0;
                    l1_tag[i][j] <= 0;
                    l1_msi[i][j] <= INVALID; //INVALID is initial state of all memory core addresses 
                end
                for (j = 0; j < L2_SETS; j = j + 1) begin
                    for (k = 0; k < L2_WAYS; k = k + 1) begin
                        l2_data[i][j][k] <= 0;
                        l2_tag[i][j][k] <= 0;
                        l2_msi[i][j][k] <= INVALID;
                    end
                    lru[i][j] <= 0; 
                end
            end
            
            for (i = 0; i < MEM_BLOCKS; i = i + 1) begin
                main_memory[i] <= i + 16'h1000; // Initialize Main Memory with distinct values
            end
            
            bus_cmd <= BUS_IDLE;
            bus_addr <= 0;
            bus_data <= 0;
            data_out <= 0;
            hit1 <= 0;
            hit2 <= 0;
            wait_req <= 0;
            
        end else begin
            // Default values
            hit1 <= 0;
            hit2 <= 0;
            wait_req <= 0;
            bus_cmd <= BUS_IDLE;
            
            // SNOOPING LOGIC -> Handle bus transactions from other cores
            if (bus_cmd_in == BUS_UPDATE) begin
               
                // Check if the address being updated (snoop_l1_tag)in the bus is the same as the one in L1 cache and it is not invalid
                // If so, the L1 cache takes this data from the bus and sets its state to SHARED
                if (l1_tag[core_id][snoop_l1_index] == snoop_l1_tag && 
                    l1_msi[core_id][snoop_l1_index] != INVALID) begin
                    l1_data[core_id][snoop_l1_index] <= bus_data_in;
                    l1_msi[core_id][snoop_l1_index] <= SHARED;
                end
                
                // Check L2 cache similarly
                for (j = 0; j < L2_WAYS; j = j + 1) begin
                    if (l2_tag[core_id][snoop_l2_index][j] == snoop_l2_tag && 
                        l2_msi[core_id][snoop_l2_index][j] != INVALID) begin
                        l2_data[core_id][snoop_l2_index][j] <= bus_data_in;
                        l2_msi[core_id][snoop_l2_index][j] <= SHARED;
                    end
                end
            end
            
            // CORE OPERATION LOGIC
            if (mode == 0) begin
                // ============== READ OPERATION ==============
                // Check L1 first does it have the required data in VALID state => L1 HIT
                if (l1_msi[core_id][l1_index] != INVALID && 
                    l1_tag[core_id][l1_index] == l1_tag_in) begin
                    // L1 HIT
                    data_out <= l1_data[core_id][l1_index];
                    hit1 <= 1;
                    
                end else begin
                    // L1 MISS => Check L2 similar to the block above but here once we find it, push it to L1 from L2
                    found = 0;
                    for (j = 0; j < L2_WAYS; j = j + 1) begin
                        if (l2_msi[core_id][l2_index][j] != INVALID && 
                            l2_tag[core_id][l2_index][j] == l2_tag_in && !found) begin
                            // L2 HIT
                            data_out <= l2_data[core_id][l2_index][j];
                            hit2 <= 1;
                            found = 1;
                            
                            // Promote to L1
                            l1_data[core_id][l1_index] <= l2_data[core_id][l2_index][j];
                            l1_tag[core_id][l1_index] <= l1_tag_in;
                            l1_msi[core_id][l1_index] <= l2_msi[core_id][l2_index][j];
                        end
                    end
                    
                    if (!found) begin
                        // MISS in both L1 and L2 either compulsory/coherence miss- Fetch from memory
                        fetched = main_memory[addr[7:2]];
                        data_out <= fetched;
                        wait_req <= 1;
                        
                        // Issue bus read
                        bus_cmd <= BUS_RD;
                        bus_addr <= addr;
                        
                        // Allocate in L2 while setting its tag to SHARED (inclusive type of cache L1 is subset of L2)
                        //No MODIFICATION happens yet
                        
                        j = lru[core_id][l2_index];
                        l2_data[core_id][l2_index][j] <= fetched;
                        l2_tag[core_id][l2_index][j] <= l2_tag_in;
                        l2_msi[core_id][l2_index][j] <= SHARED;
                        lru[core_id][l2_index] <= (lru[core_id][l2_index] + 1) % L2_WAYS;
                        
                        // Promote to L1
                        l1_data[core_id][l1_index] <= fetched;
                        l1_tag[core_id][l1_index] <= l1_tag_in;
                        l1_msi[core_id][l1_index] <= SHARED;
                    end
                end
                
            end else begin
                // ============== WRITE OPERATION ==============
                // Write Update Strategy: Whenever a modification is made, the change is broadcasted across all the cores and all of them are set to the shared state
                
                // Update local cache
                l1_data[core_id][l1_index] <= data_in;
                l1_tag[core_id][l1_index] <= l1_tag_in;
                
                // Broadcast update to other cores
                bus_cmd <= BUS_UPDATE;
                bus_addr <= addr;
                bus_data <= data_in;
                
                // Set local state to SHARED (write update strategy)
                l1_msi[core_id][l1_index] <= SHARED;
                
                // Update L2 if present
                found = 0;
                for (j = 0; j < L2_WAYS; j = j + 1) begin
                    if (l2_tag[core_id][l2_index][j] == l2_tag_in && 
                        l2_msi[core_id][l2_index][j] != INVALID && !found) begin
                        l2_data[core_id][l2_index][j] <= data_in;
                        l2_msi[core_id][l2_index][j] <= SHARED;
                        found = 1;
                    end
                end
                
                // If not in L2, allocate
                if (!found) begin
                    j = lru[core_id][l2_index];
                    l2_data[core_id][l2_index][j] <= data_in;
                    l2_tag[core_id][l2_index][j] <= l2_tag_in;
                    l2_msi[core_id][l2_index][j] <= SHARED;
                    lru[core_id][l2_index] <= (lru[core_id][l2_index] + 1) % L2_WAYS;
                end
                
                // Update main memory directly (write-through)
                main_memory[addr[7:2]] <= data_in;
            end
        end
    end

endmodule
