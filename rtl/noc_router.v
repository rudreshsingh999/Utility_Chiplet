module noc_router #(
    parameter int NUM_PORTS    = 5,
    parameter int PACKET_WIDTH = 128,
    parameter int FIFO_DEPTH  = 8,
    parameter int COORD_W     = 4,
    parameter int COORD_L_W   = 2
)(
    input  logic                        clk,
    input  logic                        rst,

    input  logic [COORD_W-1:0]          cur_x,
    input  logic [COORD_W-1:0]          cur_y,
    input logic [COORD_W-1:0]           cur_lx,
    input logic [COORD_W-1:0]           cur_ly,
    input logic [NUM_PORTS-1:0]         link_up,

    input  logic [NUM_PORTS-1:0]        in_valid,
    input  logic [PACKET_WIDTH-1:0]     in_packet [NUM_PORTS],
    output logic [NUM_PORTS-1:0]        in_ready,

    output logic [NUM_PORTS-1:0]        out_valid,
    output logic [PACKET_WIDTH-1:0]     out_packet [NUM_PORTS],
    input  logic [NUM_PORTS-1:0]        out_ready,

    input  logic [NUM_PORTS-1:0]        downstream_credit, // credit from downstream routers
    output logic [NUM_PORTS-1:0]        upstream_credit
);

    // ------------------------------------------------------------
    // Input ports
    // ------------------------------------------------------------
    logic [NUM_PORTS-1:0] fifo_empty   [NUM_PORTS];
    logic [PACKET_WIDTH-1:0] fifo_data [NUM_PORTS][NUM_PORTS];
    logic [NUM_PORTS-1:0] fifo_rd_en   [NUM_PORTS];

    genvar i;
    generate
        for (i = 0; i < NUM_PORTS; i++) begin : IN_PORTS
            input_port #(
                .NUM_PORTS(NUM_PORTS),
                .PACKET_WIDTH(PACKET_WIDTH),
                .FIFO_DEPTH(FIFO_DEPTH),
                .COORD_W(COORD_W)
            ) ip (
                .clk(clk),
                .rst(rst),
                .cur_x(cur_x),
                .cur_y(cur_y),
                .cur_lx(cur_lx),
                .cur_ly(cur_ly),
                .link_up(link_up),
                .in_valid(in_valid[i]),
                .in_packet(in_packet[i]),
                .in_ready(in_ready[i]),
                .fifo_empty(fifo_empty[i]),
                .fifo_rd_data(fifo_data[i]),
                .fifo_rd_en(fifo_rd_en[i])
            );
        end
    endgenerate

    // Output arbiters
    logic [NUM_PORTS-1:0] arb_grant_valid;
    logic [NUM_PORTS-1:0] can_send;

    genvar o;
    generate
        for (o = 0; o < NUM_PORTS; o++) begin : ARBITERS
            output_arbiter #(
                .NUM_INPUTS(NUM_PORTS)
            ) arb (
                .clk(clk),
                .rst(rst),
                .fifo_empty({fifo_empty[NUM_PORTS-1:0][o]}),
                .outq_ready(can_send[o]),
                .fifo_rd_en({fifo_rd_en[NUM_PORTS-1:0][o]}),
                .grant_valid(arb_grant_valid[o])
            );
        end
    endgenerate

    // ------------------------------------------------------------
    // Pipeline register (FIFO read latency fix)
    // ------------------------------------------------------------
    logic [PACKET_WIDTH-1:0] pipe_data [NUM_PORTS];
    logic                    pipe_valid[NUM_PORTS];

    integer pi, po;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (po = 0; po < NUM_PORTS; po++) begin
                pipe_valid[po] <= 1'b0;
            end
        end else begin
            for (po = 0; po < NUM_PORTS; po++) begin
                pipe_valid[po] <= arb_grant_valid[po];
                for (pi = 0; pi < NUM_PORTS; pi++) begin
                    if (fifo_rd_en[pi][po])
                        pipe_data[po] <= fifo_data[pi][po];
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Output queues
    // ------------------------------------------------------------
    logic [NUM_PORTS-1:0] credit_return;

    generate
        for (o = 0; o < NUM_PORTS; o++) begin : OUT_Q
            output_queue #(
                .PACKET_WIDTH(PACKET_WIDTH),
                .DEPTH(FIFO_DEPTH)
            ) oq (
                .clk(clk),
                .rst(rst),
                .enq_valid(pipe_valid[o]),
                .enq_data(pipe_data[o]),
                .enq_ready(), // already protected by credits
                .out_valid(out_valid[o]),
                .out_data(out_packet[o]),
                .out_ready(out_ready[o]),
                .credit_return(credit_return[o])
            );
        end
    endgenerate

    // ------------------------------------------------------------
    // Credit manager
    // ------------------------------------------------------------
    credit_manager #(
        .NUM_PORTS(NUM_PORTS),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) cm (
        .clk(clk),
        .rst(rst),
        .outq_credit_return(credit_return),
        .downstream_credit(downstream_credit),
        .can_send(can_send),
        .upstream_credit(upstream_credit)
    );

endmodule
