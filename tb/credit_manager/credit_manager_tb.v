`timescale 1ns/1ps

module credit_manager_tb;
    parameter NUM_PORTS = 5;
    parameter FIFO_DEPTH = 8;
    parameter CLK_PERIOD = 10;

    localparam CREDIT_W = $clog2(FIFO_DEPTH + 1);

    reg clk;
    reg rst;
    reg [NUM_PORTS-1:0] outq_credit_return;
    reg [NUM_PORTS-1:0] downstream_credit;
    wire [NUM_PORTS-1:0] can_send;
    wire [NUM_PORTS-1:0] upstream_credit;

    integer test_count;
    integer passed;
    integer failed;

    reg [CREDIT_W-1:0] shadow_credit [NUM_PORTS-1:0];
    integer port_idx;

    //dut
    credit_manager #(
        .NUM_PORTS(NUM_PORTS),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .outq_credit_return(outq_credit_return),
        .downstream_credit(downstream_credit),
        .can_send(can_send),
        .upstream_credit(upstream_credit)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        $dumpfile("credit_manager.vcd");
        $dumpvars(0, credit_manager_tb);
    end

    always @(posedge clk) begin
        if (rst) begin
            for (port_idx = 0; port_idx < NUM_PORTS; port_idx = port_idx + 1) begin
                shadow_credit[port_idx] <= FIFO_DEPTH;
            end
        end else begin
            for (port_idx = 0; port_idx < NUM_PORTS; port_idx = port_idx + 1) begin
                case ({downstream_credit[port_idx], outq_credit_return[port_idx]})
                    2'b10: shadow_credit[port_idx] <= shadow_credit[port_idx] - 1;
                    2'b01: shadow_credit[port_idx] <= shadow_credit[port_idx] + 1;
                    default: ;
                endcase
            end
        end
    end

    task init_inputs;
        begin
            rst = 1;
            outq_credit_return = 0;
            downstream_credit = 0;
        end
    endtask

    task apply_reset;
        begin
            rst = 1;
            @(posedge clk);
            @(posedge clk);
            rst = 0;
            @(posedge clk);
        end
    endtask

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task check_can_send;
        input integer port;
        input expected;
        begin
            test_count = test_count + 1;
            if (can_send[port] === expected) begin
                passed = passed + 1;
                $display("PASSED, Test: %0d, can_send[%0d]=%b, expected=%b", test_count, port, can_send[port], expected);
            end else begin
                failed = failed + 1;
                $display("FAILED, Test: %0d, can_send[%0d]=%b, expected=%b", test_count, port, can_send[port], expected);
            end
        end
    endtask

    task check_all_can_send;
        input [NUM_PORTS-1:0] expected;
        begin
            test_count = test_count + 1;
            if (can_send === expected) begin
                passed = passed + 1;
                $display("PASSED, Test: %0d, can_send=%b, expected=%b", test_count, can_send, expected);
            end else begin
                failed = failed + 1;
                $display("FAILED, Test: %0d, can_send=%b, expected=%b", test_count, can_send, expected);
            end
        end
    endtask

    task check_upstream_credit;
        input [NUM_PORTS-1:0] expected;
        begin
            test_count = test_count + 1;
            if (upstream_credit === expected) begin
                passed = passed + 1;
                $display("PASSED, Test: %0d, upstream_credit=%b, expected=%b", test_count, upstream_credit, expected);
            end else begin
                failed = failed + 1;
                $display("FAILED, Test: %0d, upstream_credit=%b, expected=%b", test_count, upstream_credit, expected);
            end
        end
    endtask

    task decrement_credit;
        input integer port;
        begin
            downstream_credit[port] = 1;
            @(posedge clk);
            downstream_credit[port] = 0;
        end
    endtask

    task increment_credit;
        input integer port;
        begin
            outq_credit_return[port] = 1;
            @(posedge clk);
            outq_credit_return[port] = 0;
        end
    endtask

    initial begin
        test_count = 0;
        passed = 0;
        failed = 0;

        init_inputs();
        @(posedge clk);

        //reset behavior
        apply_reset();
        check_all_can_send({NUM_PORTS{1'b1}});

        //credit decrement
        apply_reset();
        decrement_credit(0);
        @(posedge clk);
        check_can_send(0, 1);

        repeat (FIFO_DEPTH - 1) begin
            decrement_credit(0);
        end
        @(posedge clk);
        check_can_send(0, 0);
        check_can_send(1, 1);
        check_can_send(2, 1);

        //credit increment
        apply_reset();
        repeat (FIFO_DEPTH) begin
            decrement_credit(0);
        end
        @(posedge clk);
        check_can_send(0, 0);

        increment_credit(0);
        @(posedge clk);
        check_can_send(0, 1);

        repeat (FIFO_DEPTH - 1) begin
            increment_credit(0);
        end
        @(posedge clk);
        check_can_send(0, 1);

        //simultaneous inc/dec
        apply_reset();
        repeat (4) begin
            decrement_credit(0);
        end
        @(posedge clk);

        downstream_credit[0] = 1;
        outq_credit_return[0] = 1;
        @(posedge clk);
        downstream_credit[0] = 0;
        outq_credit_return[0] = 0;
        @(posedge clk);
        check_can_send(0, 1);

        //multi-port operations
        apply_reset();
        downstream_credit[0] = 1;
        downstream_credit[1] = 1;
        outq_credit_return[2] = 1;
        @(posedge clk);
        downstream_credit = 0;
        outq_credit_return = 0;
        @(posedge clk);
        check_can_send(0, 1);
        check_can_send(1, 1);
        check_can_send(2, 1);

        //exhaustion and recovery
        apply_reset();
        repeat (FIFO_DEPTH) begin
            downstream_credit = {NUM_PORTS{1'b1}};
            @(posedge clk);
            downstream_credit = 0;
        end
        @(posedge clk);
        check_all_can_send({NUM_PORTS{1'b0}});

        increment_credit(0);
        @(posedge clk);
        check_can_send(0, 1);
        check_can_send(1, 0);

        increment_credit(1);
        @(posedge clk);
        check_can_send(1, 1);

        repeat (FIFO_DEPTH) begin
            outq_credit_return = {NUM_PORTS{1'b1}};
            @(posedge clk);
            outq_credit_return = 0;
        end
        @(posedge clk);
        check_all_can_send({NUM_PORTS{1'b1}});

        //multi-port independence
        apply_reset();
        repeat (FIFO_DEPTH) decrement_credit(0);
        repeat (FIFO_DEPTH/2) decrement_credit(1);
        decrement_credit(2);
        repeat (FIFO_DEPTH) decrement_credit(4);
        increment_credit(4);

        @(posedge clk);
        check_can_send(0, 0);
        check_can_send(1, 1);
        check_can_send(2, 1);
        check_can_send(3, 1);
        check_can_send(4, 1);

        //upstream credit passthrough
        apply_reset();
        outq_credit_return = 5'b00001;
        #1;
        check_upstream_credit(5'b00001);

        outq_credit_return = 5'b10101;
        #1;
        check_upstream_credit(5'b10101);

        outq_credit_return = 5'b11111;
        #1;
        check_upstream_credit(5'b11111);

        outq_credit_return = 5'b00000;
        #1;
        check_upstream_credit(5'b00000);

        //reset during operation
        apply_reset();
        repeat (3) decrement_credit(0);
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        check_all_can_send({NUM_PORTS{1'b1}});

        //rapid toggling
        apply_reset();
        repeat (20) begin
            downstream_credit[0] = 1;
            @(posedge clk);
            downstream_credit[0] = 0;
            outq_credit_return[0] = 1;
            @(posedge clk);
            outq_credit_return[0] = 0;
        end
        @(posedge clk);
        check_can_send(0, 1);

        //credit at boundary
        apply_reset();
        repeat (FIFO_DEPTH - 1) decrement_credit(0);
        @(posedge clk);
        check_can_send(0, 1);
        decrement_credit(0);
        @(posedge clk);
        check_can_send(0, 0);

        //stress test
        apply_reset();
        begin: stress_test
            integer cycle;
            integer p;
            integer errors;
            reg [NUM_PORTS-1:0] random_downstream;
            reg [NUM_PORTS-1:0] random_return;

            errors = 0;
            for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
                random_downstream = $random;
                random_return = $random;

                for (p = 0; p < NUM_PORTS; p = p + 1) begin
                    if (shadow_credit[p] == 0) begin
                        random_downstream[p] = 0;
                    end
                    if (shadow_credit[p] == FIFO_DEPTH) begin
                        random_return[p] = 0;
                    end
                end

                downstream_credit = random_downstream;
                outq_credit_return = random_return;
                @(posedge clk);
                downstream_credit = 0;
                outq_credit_return = 0;
                @(posedge clk);

                for (p = 0; p < NUM_PORTS; p = p + 1) begin
                    if (can_send[p] !== (shadow_credit[p] != 0)) begin
                        errors = errors + 1;
                    end
                end
            end

            test_count = test_count + 1;
            if (errors == 0) begin
                passed = passed + 1;
            end else begin
                failed = failed + 1;
            end
        end

        //consecutive operations
        apply_reset();
        repeat (FIFO_DEPTH) decrement_credit(0);
        @(posedge clk);
        check_can_send(0, 0);

        repeat (FIFO_DEPTH) increment_credit(0);
        @(posedge clk);
        check_can_send(0, 1);

        apply_reset();
        repeat (10) begin
            decrement_credit(0);
            @(posedge clk);
            increment_credit(0);
            @(posedge clk);
        end
        check_can_send(0, 1);

        $display("\n==============================================================");
        $display("  Test Summary");
        $display("==============================================================");
        $display("  Total Tests: %0d", test_count);
        $display("  Passed:      %0d", passed);
        $display("  Failed:      %0d", failed);
        $display("==============================================================\n");

        $finish;
    end
endmodule
