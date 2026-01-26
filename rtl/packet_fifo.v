module packet_fifo #(
    parameter int PACKET_WIDTH = 128,
    parameter int DEPTH        = 8
)(
    input  logic                   clk,
    input  logic                   rst,

    // Write side
    input  logic                   wr_en,
    input  logic [PACKET_WIDTH-1:0] wr_data,
    output logic                   full,

    // Read side
    input  logic                   rd_en,
    output logic [PACKET_WIDTH-1:0] rd_data,
    output logic                   empty
);

    localparam int ADDR_W = $clog2(DEPTH);

    logic [PACKET_WIDTH-1:0] mem [DEPTH];
    logic [ADDR_W:0]         wr_ptr;
    logic [ADDR_W:0]         rd_ptr;
    logic [ADDR_W:0]         count;

    // Status flags
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Read data (registered)
    always_ff @(posedge clk) begin
        if (rd_en && !empty)
            rd_data <= mem[rd_ptr[ADDR_W-1:0]];
    end

    // Write / Read pointers and count
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})

                2'b10: begin // write only
                    mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
                    wr_ptr <= wr_ptr + 1;
                    count  <= count + 1;
                end

                2'b01: begin // read only
                    rd_ptr <= rd_ptr + 1;
                    count  <= count - 1;
                end

                2'b11: begin // simultaneous read & write
                    mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
                    wr_ptr <= wr_ptr + 1;
                    rd_ptr <= rd_ptr + 1;
                    // count unchanged
                end

                default: ; // no-op
            endcase
        end
    end

endmodule
