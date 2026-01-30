`timescale 1ns/1ps

module output_arbiter_tb;
    parameter NUM_INPUTS=5;
    parameter CLK_PERIOD = 10;
    localparam PTR_W = $clog2(NUM_INPUTS);

    reg clk;
    reg rst;
    reg [NUM_INPUTS-1:0] fifo_empty;
    reg outq_ready;
    wire [NUM_INPUTS-1:0] fifo_rd_en;
    wire grant_valid;

    integer test_count;
    integer passed;
    integer failed;

    function [NUM_INPUTS-1:0] encoding_fn;
        input integer id_x;
        begin
            encoding_fn = (1 << id_x);
        end
    endfunction

    function integer num_ones;
        input [NUM_INPUTS-1:0] vect;
        integer i;
        begin
            num_ones = 0;
            for (i =0; i<NUM_INPUTS; i=i+1) begin
                if (vect[i]) num_ones = num_ones+1;
            end
        end
    endfunction

    function integer find_one_pos;
        input [NUM_INPUTS-1:0] vect;
        integer i;
        begin 
            find_one_pos = -1;
            for (i = 0;i<NUM_INPUTS; i=i+1) begin
                if (vect[i]) find_one_pos =i;
            end
        end
    endfunction

    //dut 
    output_arbiter #(
        .NUM_INPUTS(NUM_INPUTS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .fifo_empty(fifo_empty),
        .outq_ready(outq_ready),
        .fifo_rd_en(fifo_rd_en),
        .grant_valid(grant_valid)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        $dumpfile("output_arbiter.vcd");
        $dumpvars(0, output_arbiter_tb);
    end
    
    task init_inputs;
        begin
            rst = 1;
            fifo_empty = {NUM_INPUTS{1'b1}}; //empty
            outq_ready = 0;
        end
    endtask

    task apply_reset;
        begin
            rst = 1;
            fifo_empty = {NUM_INPUTS{1'b1}}; 
            outq_ready = 0;
            @(posedge clk); //first clk
            @(posedge clk); //for rr_ptr to go to 0
            @(negedge clk);  
            rst = 0;
        end
    endtask

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i=0; i<n; i=i+1) begin
                @(posedge clk);
            end
        end
    endtask

    task set_fifo_status;
        input [NUM_INPUTS-1:0] empty;
        begin
            fifo_empty = empty;
        end
    endtask

    task fifo_has_data;
        input integer id_x;
        begin
            fifo_empty[id_x] = 0;
        end
    endtask

    task fifo_is_empty;
        input integer id_x;
        begin
            fifo_empty[id_x] = 1;
        end
    endtask
    task check_grant_valid;
        input expected;
        begin
            test_count = test_count+1;
            if (grant_valid === expected) begin
                passed = passed +1;
                $display("PASSED, Test: %0d, %b, %b ",test_count, grant_valid, expected);
            end else begin
                failed = failed + 1;
                $display("FAILED, Test: %0d, %b, %b ",test_count, grant_valid, expected);
            end
        end
    endtask

    task check_fifo_rd_en;
        input [NUM_INPUTS-1:0] expected;
        begin
            test_count = test_count +1;
            if (fifo_rd_en === expected ) begin
                passed = passed+1;
                $display("PASSED, Test: %0d, %b, %b ",test_count, fifo_rd_en, expected);
            end else begin
                failed = failed+1;
                $display("FAILED, Test: %0d, %b, %b ",test_count, fifo_rd_en, expected);
            end
        end
    endtask

    task check_granted_port;
        input integer expected;
        begin
            test_count = test_count+1;
            if (grant_valid && fifo_rd_en ===encoding_fn(expected)) begin
                passed = passed+1;
                $display("PASSED, Test: %0d, %b, %b ",test_count, find_one_pos(fifo_rd_en), expected);
            end else begin
                failed = failed+1;
                $display("FAILED, Test: %0d, %b, %b ",test_count, find_one_pos(fifo_rd_en), expected);
            end
        end
    endtask

    task check_onlyone_grant;
        begin
            test_count = test_count + 1;
            if (num_ones(fifo_rd_en) <= 1) begin
                passed = passed +1;
            end else begin
                failed = failed+1;
            end
        end
    endtask

    initial begin
        test_count = 0;
        passed = 0;
        failed = 0;

        init_inputs();
        @(posedge clk);

        apply_reset();
        outq_ready = 1;
        fifo_empty = {NUM_INPUTS{1'b1}};
        #1;
        check_grant_valid(0);
        check_fifo_rd_en({NUM_INPUTS{1'b0}});

        begin: single_req
            integer port;
            for (port = 0; port <NUM_INPUTS; port = port+1) begin
                apply_reset();
                outq_ready = 1;
                fifo_empty ={NUM_INPUTS{1'b1}};
                fifo_has_data(port);
                #1;
                check_granted_port(port);
            end
        end

        apply_reset();
        outq_ready=1;
        fifo_empty = {NUM_INPUTS{1'b0}};
        #1;
        check_granted_port(1);

        @(posedge clk);
        #1;
        check_granted_port(2);
        @(posedge clk);
        #1;
        check_granted_port(3);
        @(posedge clk);
        #1;
        check_granted_port(4);
        @(posedge clk);
        #1;
        check_granted_port(0);
        @(posedge clk);
        #1;
        check_granted_port(1);

        apply_reset();
        outq_ready=1;
        fifo_empty = 5'b10110;
        #1;
        check_granted_port(3);
        @(posedge clk);
        #1;
        check_granted_port(0);

        //wrap around behavior
        apply_reset();
        outq_ready = 1;
        fifo_empty = {NUM_INPUTS{1'b1}};
        fifo_has_data(4);
        #1;
        check_granted_port(4);
        @(posedge clk);

        fifo_empty= {NUM_INPUTS{1'b1}};
        fifo_has_data(1);
        #1;
        check_granted_port(1);

        @(posedge clk);
        fifo_empty={NUM_INPUTS{1'b1}};
        fifo_has_data(0);
        #1;
        check_granted_port(0);

        //testing outq ready
        apply_reset();
        fifo_empty = {NUM_INPUTS{1'b0}};
        outq_ready= 0;
        #1;
        check_grant_valid(0);
        check_fifo_rd_en({NUM_INPUTS{1'b0}});

        outq_ready =1;
        #1;
        check_grant_valid(1);
        check_onlyone_grant();
        @(posedge clk);
        outq_ready =0;
        #1;
        check_grant_valid(0);

        outq_ready = 1;
        #1;
        check_grant_valid(1);

        //if all fifos are empty
        apply_reset();
        outq_ready = 1;

        fifo_empty = {NUM_INPUTS{1'b1}};
        #1;
        check_grant_valid(0);
        check_fifo_rd_en({NUM_INPUTS{1'b0}});

        //rr_ptr should not change when no grant
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        fifo_has_data(2);
        #1;
        check_granted_port(2);

        //consecutive grants, rr should still work
        apply_reset();
        outq_ready =1;

        fifo_empty = 5'b11011; //port 2 only
        #1;
        check_granted_port(2);
        @(posedge clk);
        fifo_empty = 5'b11011;
        #1;
        check_granted_port(2);

        apply_reset();
        outq_ready =1;
        begin: stress_test
            integer cycle;
            integer errors;

            reg[NUM_INPUTS-1:0] random_empty;
            reg[NUM_INPUTS-1:0] data_avail;

            errors = 0;
            for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
                random_empty = $random;
                outq_ready = ($random %100)<80;
                fifo_empty = random_empty;
                data_avail = ~fifo_empty;
                #1;
                if (outq_ready && data_avail!=0) begin
                    if (!grant_valid) begin
                        errors = errors+1;
                    end else if ((fifo_rd_en & data_avail)==0) begin
                        errors = errors+1;
                    end
                end else if (!outq_ready||data_avail==0) begin
                    if (fifo_rd_en !=0 && !outq_ready) begin
                        errors = errors +1;
                    end
                end
                @(posedge clk);
            end
            test_count = test_count + 1;
            if (errors == 0) begin
                passed = passed  + 1;
            end else begin
                failed = failed + 1;
            end
        end
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
