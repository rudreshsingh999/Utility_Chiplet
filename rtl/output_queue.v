module output_queue #(
    parameter int PACKET_WIDTH = 128,
    parameter int DEPTH        = 8
)(
    input  logic                    clk,
    input  logic                    rst,

    // Enqueue interface
    input  logic                    enq_valid,
    input  logic [PACKET_WIDTH-1:0] enq_data,
    output logic                    enq_ready,

    // Dequeue interface
    output logic                    out_valid,
    output logic [PACKET_WIDTH-1:0] out_data,
    input  logic                    out_ready,

    // Credit return
    output logic                    credit_return
);

    logic fifo_full;
    logic fifo_empty;
    logic fifo_wr_en;
    logic fifo_rd_en;

    // Instantiate packet FIFO
    packet_fifo #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .DEPTH(DEPTH)
    ) fifo (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (fifo_wr_en),
        .wr_data (enq_data),
        .full    (fifo_full),
        .rd_en   (fifo_rd_en),
        .rd_data (out_data),
        .empty   (fifo_empty)
    );

    // Enqueue logic
    assign enq_ready = ~fifo_full;
    assign fifo_wr_en = enq_valid && enq_ready;

    // Dequeue logic
    assign out_valid  = ~fifo_empty;
    assign fifo_rd_en = out_valid && out_ready;

    // Credit return when a packet leaves output queue
    assign credit_return = fifo_rd_en;

endmodule
