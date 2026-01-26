module input_port #(
    parameter int NUM_PORTS    = 5,
    parameter int PACKET_WIDTH = 128,
    parameter int FIFO_DEPTH  = 8,
    parameter int COORD_W     = 4,
    parameter int COORD_L_W   = 2
)(
    input  logic                    clk,
    input  logic                    rst,

    input  logic [COORD_W-1:0]      cur_x,
    input  logic [COORD_W-1:0]      cur_y,

    input logic [COORD_L_W-1:0]      cur_lx,
    input logic [COORD_L_W-1:0]      cur_ly,

    input logic [NUM_PORTS-1:0]      link_up,

    input  logic                    in_valid,
    input  logic [PACKET_WIDTH-1:0] in_packet,
    output logic                    in_ready,

    output logic [NUM_PORTS-1:0]                    fifo_empty,
    output logic [PACKET_WIDTH-1:0]                 fifo_rd_data [NUM_PORTS],
    input  logic [NUM_PORTS-1:0]                    fifo_rd_en
);

    // -----------------------------
    // Extract destination fields
    // -----------------------------
    logic [COORD_W-1:0] dst_x, dst_y;
    logic [COORD_L_W-1:0] dest_lx, dest_ly;
    logic [1:0] vc_class;
    logic [NUM_PORTS-1:0] req_port;

    assign dst_x = in_packet[PACKET_WIDTH-1 -: COORD_W];
    assign dst_y = in_packet[PACKET_WIDTH-1-COORD_W -: COORD_W];
    assign dst_lx = in_packet[PACKET_WIDTH-1-2*COORD_W -: COORD_L_W];
    assign dst_ly = in_packet[PACKET_WIDTH-1-2*COORD_W-COORD_L_W -: COORD_L_W];
    assign vc_class = in_packet[PACKET_WIDTH-1-2*COORD_W-2*COORD_L_W -: 2];
    // -----------------------------
    // Route computation
    // -----------------------------
    logic [$clog2(NUM_PORTS)-1:0] dest_port;
    logic retry;
    route_compute #(
        .TILE_BITS(COORD_W),
        .LOCAL_BITS(COORD_L_W)
    ) rc (
        .pkt_valid(in_valid),
        .cur_tile_x(cur_x),
        .cur_tile_y(cur_y),
        .curr_lx(cur_lx),
        .curr_ly(cur_ly),
        .dst_tile_x(dst_x),
        .dst_tile_y(dst_y),
        .dest_lx(dest_lx),
        .dest_ly(dest_ly),
        .vc_class(vc_class),
        .link_up(link_up),
        .req_port(req_port),
        .retry(retry)
    );

    integer i;
    always @(*) begin
        index = '0;
        for (i = 0; i < NUM_PORTS; i = i + 1) begin
            if (req_port[i])
                dest_port = i[$clog2(NUM_PORTS)-1:0];
        end
    end

    // -----------------------------
    // VOQ FIFOs
    // -----------------------------
    logic [NUM_PORTS-1:0] fifo_full;
    logic [NUM_PORTS-1:0] fifo_wr_en;

    genvar i;
    generate
        for (i = 0; i < NUM_PORTS; i++) begin : VOQ
            packet_fifo #(
                .PACKET_WIDTH(PACKET_WIDTH),
                .DEPTH(FIFO_DEPTH)
            ) fifo (
                .clk     (clk),
                .rst     (rst),
                .wr_en   (fifo_wr_en[i]),
                .wr_data (in_packet),
                .full    (fifo_full[i]),
                .rd_en   (fifo_rd_en[i]),
                .rd_data (fifo_rd_data[i]),
                .empty   (fifo_empty[i])
            );
        end
    endgenerate

    // -----------------------------
    // Demux + backpressure
    // -----------------------------
    integer p;
    always_comb begin
        fifo_wr_en = '0;
        in_ready   = 1'b0;

        if (in_valid) begin
            if (!fifo_full[dest_port] && !retry) begin
                fifo_wr_en[dest_port] = 1'b1;
                in_ready              = 1'b1;
            end
        end
    end

endmodule
