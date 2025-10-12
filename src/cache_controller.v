//AUTHOR: SANJAY JAYARAMAN
//
// Word Length = 8 bits (byte addressable)
// L1 Cache Size: (L1_LINES x BLOCK_BYTES) -- DIRECT MAPPING
// L2 Cache Size: ({L2_SETS * L2_WAYS} x BLOCK_BYTES) -- SET ASSOCIATIVE MAPPING


module cache_controller #(
    parameter ADDR_BITS = 11,
    parameter DATA_BITS = 8, // word length - byte addressable
    parameter BLOCK_BYTES = 2, // 2 bytes in one line of cache 
    parameter BLOCK_OFFSET = 1 // log2(BLOCK_BYTES)
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  core_id,
    input  wire [ADDR_BITS-1:0]  addr,
    input  wire [DATA_BITS-1:0]  data_in,
    input  wire                  mode,
    
    // Bus interface
    output reg  [1:0]            bus_cmd,
    output reg  [ADDR_BITS-1:0]  bus_addr,
    output reg  [DATA_BITS-1:0]  bus_data,
    input  wire [1:0]            bus_cmd_in,
    input  wire [ADDR_BITS-1:0]  bus_addr_in,
    input  wire [DATA_BITS-1:0]  bus_data_in,
    
    input  wire [0:0]            bus_src_id,
    output wire [0:0]            bus_src_out,
    
    // Memory interface ports
    output reg  [5:0]            mem_rd_addr,
    input  wire [DATA_BITS-1:0]  mem_rd_data,
    output reg                   mem_rd_en,
    output reg  [5:0]            mem_wr_addr,
    output reg  [DATA_BITS-1:0]  mem_wr_data,
    output reg                   mem_wr_en,
    
    output reg  [DATA_BITS-1:0]  data_out,
    output wire                   hit1,
    output wire                   hit2,
    output wire                   wait_req
);

    // Cache parameters
    localparam L1_LINES      = 4;
    localparam L1_INDEX_BITS = 2;
    localparam L1_TAG_BITS   = ADDR_BITS - L1_INDEX_BITS - BLOCK_OFFSET;
    localparam L1_BLOCK_BITS = BLOCK_BYTES*8;
    
    localparam L2_SETS       = 16;
    localparam L2_WAYS       = 1;
    localparam L2_INDEX_BITS = 4;
    localparam L2_TAG_BITS   = ADDR_BITS - L2_INDEX_BITS - BLOCK_OFFSET;
    localparam L2_BLOCK_BITS = BLOCK_BYTES*8;
    
    // MSI Protocol states
    localparam INVALID  = 2'b00;
    localparam SHARED   = 2'b01;
    localparam MODIFIED = 2'b10;
    
    // Bus Commands
    localparam BUS_IDLE   = 2'b00;
    localparam BUS_RD     = 2'b01;
    localparam BUS_WR     = 2'b10;
    localparam BUS_UPDATE = 2'b11;

    // Cache Arrays
    reg [L1_BLOCK_BITS-1:0] l1_data   [0:L1_LINES-1];
    reg [L1_TAG_BITS-1:0]   l1_tag    [0:L1_LINES-1];
    reg [1:0]               l1_msi    [0:L1_LINES-1];
    
    reg [L2_BLOCK_BITS-1:0] l2_data   [0:L2_SETS-1][0:L2_WAYS-1];
    reg [L2_TAG_BITS-1:0]   l2_tag    [0:L2_SETS-1][0:L2_WAYS-1];
    reg [1:0]               l2_msi    [0:L2_SETS-1][0:L2_WAYS-1];

    // Internal registers
    reg mem_rd_pending;
    integer j, k;

    // Address breakdown
    wire [L1_INDEX_BITS-1:0]    l1_index;
    wire [L1_TAG_BITS-1:0]      l1_tag_in;
    wire [L2_INDEX_BITS-1:0]    l2_index;
    wire [L2_TAG_BITS-1:0]      l2_tag_in;
    
    
    // Combinational hit/wait outputs
    wire miss_both = !l1_hit_detected && !l2_hit_detected;
    assign hit1     = (!mem_rd_pending && mode == 0 && l1_hit_detected);
    assign hit2     = (!mem_rd_pending && mode == 0 && !l1_hit_detected && l2_hit_detected);
    assign wait_req = ( mem_rd_pending )
                    || ( mode == 0 && miss_both )|| (mode==1 && miss_both);


    
    // Hit detection wires
    wire l1_hit_detected;
    wire l2_hit_detected;
    wire [L2_WAYS-1:0] l2_way_hit;
    
    assign l1_index = addr[BLOCK_OFFSET + L1_INDEX_BITS - 1 : BLOCK_OFFSET];
    assign l1_tag_in = addr[ADDR_BITS-1 : L1_INDEX_BITS + BLOCK_OFFSET];
    assign l2_index = addr[BLOCK_OFFSET + L2_INDEX_BITS - 1 : BLOCK_OFFSET];
    assign l2_tag_in = addr[ADDR_BITS-1 : L2_INDEX_BITS + BLOCK_OFFSET];
    
    // Snooping address breakdown
    wire [L1_INDEX_BITS-1:0]    snoop_l1_index;
    wire [L1_TAG_BITS-1:0]      snoop_l1_tag;
    wire [L2_INDEX_BITS-1:0]    snoop_l2_index;
    wire [L2_TAG_BITS-1:0]      snoop_l2_tag;
    
    assign snoop_l1_index = bus_addr_in[BLOCK_OFFSET + L1_INDEX_BITS - 1 : BLOCK_OFFSET];
    assign snoop_l1_tag = bus_addr_in[ADDR_BITS-1:L1_INDEX_BITS+BLOCK_OFFSET];
    assign snoop_l2_index = bus_addr_in[BLOCK_OFFSET + L2_INDEX_BITS - 1 : BLOCK_OFFSET];
    assign snoop_l2_tag = bus_addr_in[ADDR_BITS-1:L2_INDEX_BITS+BLOCK_OFFSET];
    
    assign bus_src_out = core_id;
    
    // Combinational hit detection
    assign l1_hit_detected = (l1_msi[l1_index] != INVALID) && (l1_tag[l1_index] == l1_tag_in);
    
    // L2 hit detection for each way
    genvar w;
    generate
        for (w = 0; w < L2_WAYS; w = w + 1) begin : l2_hit_gen
            assign l2_way_hit[w] = (l2_msi[l2_index][w] != INVALID) && (l2_tag[l2_index][w] == l2_tag_in);
        end
    endgenerate
    
    assign l2_hit_detected = |l2_way_hit; // OR of all way hits
    
    initial begin
        // Initialize caches
        for (j = 0; j < L1_LINES; j = j + 1) begin
            l1_data[j] = 16'b0;
            l1_tag[j] = 7'b0;
            l1_msi[j] = INVALID;
        end
        for (j = 0; j < L2_SETS; j = j + 1) begin
            for (k = 0; k < L2_WAYS; k = k + 1) begin
                l2_data[j][k] = 16'b0;
                l2_tag[j][k] = 6'b0;
                l2_msi[j][k] = INVALID;
            end
        end
        
        bus_cmd = BUS_IDLE;
        bus_addr = 0;
        bus_data = 0;
        mem_rd_addr = 0;
        mem_rd_en = 0;
        mem_wr_addr = 0;
        mem_wr_data = 0;
        mem_wr_en = 0;
        data_out = 0;
        mem_rd_pending = 0;
    end

always @(posedge clk) begin
    if (rst) begin
        // Reset L1
        for (j = 0; j < L1_LINES; j = j + 1) begin
            l1_data[j] <= {L1_BLOCK_BITS{1'b0}};
            l1_tag[j]  <= {L1_TAG_BITS{1'b0}};
            l1_msi[j]  <= INVALID;
        end
        // Reset L2
        for (j = 0; j < L2_SETS; j = j + 1) begin
            for (k = 0; k < L2_WAYS; k = k + 1) begin
                l2_data[j][k] <= {L2_BLOCK_BITS{1'b0}};
                l2_tag[j][k]  <= {L2_TAG_BITS{1'b0}};
                l2_msi[j][k]  <= INVALID;
            end
        end

        // Reset outputs
        bus_cmd        <= BUS_IDLE;
        bus_addr       <= {ADDR_BITS{1'b0}};
        bus_data       <= {DATA_BITS{1'b0}};
        mem_rd_addr    <= 0;
        mem_rd_en      <= 1'b0;
        mem_wr_addr    <= 0;
        mem_wr_data    <= {DATA_BITS{1'b0}};
        mem_wr_en      <= 1'b0;
        data_out       <= {DATA_BITS{1'b0}};
        mem_rd_pending <= 1'b0;
    end else begin
        // Default outputs every cycle
        bus_cmd   <= BUS_IDLE;
        bus_addr  <= {ADDR_BITS{1'b0}};
        bus_data  <= {DATA_BITS{1'b0}};
        mem_rd_en <= 1'b0;
        mem_wr_en <= 1'b0;

        // -------------------------
        // SNOOPING LOGIC
        // -------------------------
        if (bus_src_id == ~core_id && bus_cmd_in != BUS_IDLE) begin
            if (bus_cmd_in == BUS_UPDATE || bus_cmd_in == BUS_WR) begin
                // L1 update & downgrade to SHARED if present
                if (l1_tag[snoop_l1_index] == snoop_l1_tag && l1_msi[snoop_l1_index] != INVALID) begin
                    l1_data[snoop_l1_index] <= bus_data_in;
                    l1_msi[snoop_l1_index]  <= SHARED;
                end
                // L2 update - check each way explicitly
                if (L2_WAYS >= 1 && l2_tag[snoop_l2_index][0] == snoop_l2_tag && l2_msi[snoop_l2_index][0] != INVALID) begin
                    l2_data[snoop_l2_index][0] <= bus_data_in;
                    l2_msi[snoop_l2_index][0]  <= SHARED;
                end
            end

            if (bus_cmd_in == BUS_RD) begin
                if (l1_tag[snoop_l1_index] == snoop_l1_tag && l1_msi[snoop_l1_index] == MODIFIED) begin
                    l1_msi[snoop_l1_index] <= SHARED;
                end
                if (L2_WAYS >= 1 && l2_tag[snoop_l2_index][0] == snoop_l2_tag && l2_msi[snoop_l2_index][0] == MODIFIED) begin
                    l2_msi[snoop_l2_index][0] <= SHARED;
                end
            end
        end

        // -------------------------
        // Handle memory read completion
        // -------------------------
        if (mem_rd_pending) begin
            mem_rd_pending <= 1'b0;
            data_out <= mem_rd_data;

            // Allocate into L2 (way 0 for simplicity since L2_WAYS=1)
            l2_data[l2_index][0] <= mem_rd_data;
            l2_tag[l2_index][0]  <= l2_tag_in;
            l2_msi[l2_index][0]  <= SHARED;

            // Promote to L1
            l1_data[l1_index] <= mem_rd_data;
            l1_tag[l1_index]  <= l1_tag_in;
            l1_msi[l1_index]  <= SHARED;
        end

        // -------------------------
        // CORE OPERATION LOGIC
        // -------------------------
        if (!mem_rd_pending) begin
            if (mode == 0) begin
                // READ OPERATION
                if (l1_hit_detected) begin
                    // L1 HIT
                    data_out <= l1_data[l1_index];
                end else if (l2_hit_detected) begin
                    // L2 HIT (check way 0 since L2_WAYS=1)
                    if (l2_way_hit[0]) begin
                        data_out <= l2_data[l2_index][0];

                        // Promote to L1
                        l1_data[l1_index] <= l2_data[l2_index][0];
                        l1_tag[l1_index]  <= l1_tag_in;
                        l1_msi[l1_index]  <= l2_msi[l2_index][0];
                    end
                end else begin
                    // MISS in both L1 & L2: issue memory read
                    mem_rd_addr    <= addr[6:1]; // Convert to memory address
                    mem_rd_en      <= 1'b1;
                    mem_rd_pending <= 1'b1;

                    // Issue bus read
                    bus_cmd  <= BUS_RD;
                    bus_addr <= addr;
                end
            end else begin
                // WRITE OPERATION
                if (l1_hit_detected) begin
                    // L1 HIT: update and set MODIFIED
                    l1_data[l1_index] <= data_in;
                    l1_msi[l1_index]  <= MODIFIED;

                    // Broadcast write
                    bus_cmd  <= BUS_WR;
                    bus_addr <= addr;
                    bus_data <= data_in;
                    
                    // Write through to memory
                    mem_wr_addr <= addr[6:1];
                    mem_wr_data <= data_in;
                    mem_wr_en   <= 1'b1;
                end else if (l2_hit_detected) begin
                    // L2 HIT: update and promote
                    if (l2_way_hit[0]) begin
                        l2_data[l2_index][0] <= data_in;
                        l2_msi[l2_index][0]  <= MODIFIED;

                        // Promote to L1
                        l1_data[l1_index] <= data_in;
                        l1_tag[l1_index]  <= l1_tag_in;
                        l1_msi[l1_index]  <= MODIFIED;

                        bus_cmd  <= BUS_WR;
                        bus_addr <= addr;
                        bus_data <= data_in;
                        
                        // Write through to memory
                        mem_wr_addr <= addr[6:1];
                        mem_wr_data <= data_in;
                        mem_wr_en   <= 1'b1;
                    end
                end else begin
                    // MISS in both: allocate and write
                    // Allocate in L2 (way 0)
                    l2_data[l2_index][0] <= data_in;
                    l2_tag[l2_index][0]  <= l2_tag_in;
                    l2_msi[l2_index][0]  <= MODIFIED;

                    // Allocate in L1
                    l1_data[l1_index] <= data_in;
                    l1_tag[l1_index]  <= l1_tag_in;
                    l1_msi[l1_index]  <= MODIFIED;

                    // Write through to memory
                    mem_wr_addr <= addr[6:1];
                    mem_wr_data <= data_in;
                    mem_wr_en   <= 1'b1;

                    // Broadcast update
                    bus_cmd  <= BUS_UPDATE;
                    bus_addr <= addr;
                    bus_data <= data_in;
                end
            end
        end
    end
end

endmodule
