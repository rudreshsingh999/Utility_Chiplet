module credit_manager #(
    parameter int NUM_PORTS   = 5,
    parameter int FIFO_DEPTH = 8
)(
    input  logic                  clk,
    input  logic                  rst,

    // Credit returned from output queues (packet sent out)
    input  logic [NUM_PORTS-1:0]  outq_credit_return,

    // Credit coming from downstream routers
    input  logic [NUM_PORTS-1:0]  downstream_credit,

    // Can this output port send a packet?
    output logic [NUM_PORTS-1:0]  can_send,

    // Credit returned upstream
    output logic [NUM_PORTS-1:0]  upstream_credit
);

    localparam int CREDIT_W = $clog2(FIFO_DEPTH + 1);

    logic [CREDIT_W-1:0] credit_cnt [NUM_PORTS];

    genvar p;
    generate
        for (p = 0; p < NUM_PORTS; p++) begin : CREDIT_TRACK
            always_ff @(posedge clk) begin
                if (rst) begin
                    credit_cnt[p] <= FIFO_DEPTH[CREDIT_W-1:0];
                end else begin
                    case ({downstream_credit[p], outq_credit_return[p]})
                        2'b10: credit_cnt[p] <= credit_cnt[p] - 1; // packet received
                        2'b01: credit_cnt[p] <= credit_cnt[p] + 1; // packet sent
                        default: ; // no change or simultaneous
                    endcase
                end
            end

            // Can send if at least one credit
            assign can_send[p] = (credit_cnt[p] != 0);
        end
    endgenerate

    // Upstream credit return
    // (One credit per packet that leaves this router)
    assign upstream_credit = outq_credit_return;

endmodule
