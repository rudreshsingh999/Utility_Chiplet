module output_arbiter #(
    parameter int NUM_INPUTS = 5
)(
    input  logic                 clk,
    input  logic                 rst,

    input  logic [NUM_INPUTS-1:0] fifo_empty,
    input  logic                 outq_ready,

    output logic [NUM_INPUTS-1:0] fifo_rd_en,
    output logic                 grant_valid
);

    localparam int PTR_W = $clog2(NUM_INPUTS);

    logic [PTR_W-1:0] rr_ptr;
    logic [PTR_W-1:0] grant_idx;
    logic             found;

    // -----------------------------
    // Combinational arbitration
    // -----------------------------
    integer i;
    always_comb begin
        fifo_rd_en  = '0;
        grant_valid = 1'b0;
        grant_idx   = rr_ptr;
        found       = 1'b0;

        if (outq_ready) begin
            for (i = 1; i <= NUM_INPUTS; i++) begin
                int idx;
                idx = (rr_ptr + i) % NUM_INPUTS;
                if (!fifo_empty[idx] && !found) begin
                    grant_idx   = idx[PTR_W-1:0];
                    found       = 1'b1;
                    grant_valid = 1'b1;
                end
            end

            if (found)
                fifo_rd_en[grant_idx] = 1'b1;
        end
    end

    // -----------------------------
    // Round-robin pointer update
    // -----------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            rr_ptr <= '0;
        end else if (grant_valid && outq_ready) begin
            rr_ptr <= grant_idx;
        end
    end

endmodule
