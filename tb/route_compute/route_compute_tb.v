`timescale 1ns/1ps
`include "rtl/route_compute.v"

// one-hot helper (Verilator-safe)
`define ONEHOT(p) ({{(`N_PORTS-1){1'b0}},1'b1} << (p))

module route_compute_tb;

    // Parameters for scalability
    parameter TILE_BITS = 16;
    parameter LOCAL_BITS = 2;

    reg                    pkt_valid;
    reg  [TILE_BITS-1:0]   curr_tile_x;
    reg  [TILE_BITS-1:0]   curr_tile_y;
    reg  [LOCAL_BITS-1:0]  curr_lx;
    reg  [LOCAL_BITS-1:0]  curr_ly;
    reg  [TILE_BITS-1:0]   dest_tile_x;
    reg  [TILE_BITS-1:0]   dest_tile_y;
    reg  [LOCAL_BITS-1:0]  dest_lx;
    reg  [LOCAL_BITS-1:0]  dest_ly;
    reg  [1:0]             vc_class;
    reg  [`N_PORTS-1:0]    link_up;

    wire [`N_PORTS-1:0] req_ports;
    wire                retry;

    route_compute #(
        .TILE_BITS(TILE_BITS),
        .LOCAL_BITS(LOCAL_BITS)
    ) dut (
        .pkt_valid(pkt_valid),
        .curr_tile_x(curr_tile_x),
        .curr_tile_y(curr_tile_y),
        .curr_lx(curr_lx),
        .curr_ly(curr_ly),
        .dest_tile_x(dest_tile_x),
        .dest_tile_y(dest_tile_y),
        .dest_lx(dest_lx),
        .dest_ly(dest_ly),
        .vc_class(vc_class),
        .link_up(link_up),
        .req_ports(req_ports),
        .retry(retry)
    );

    initial begin
        $dumpfile("vcd_saif/route_logic.vcd");
        $dumpvars(0, route_compute_tb);
    end

    reg [`N_PORTS-1:0] expected_ports;

    // Task to run a single test and check
    task run_test;
        input [TILE_BITS-1:0]   t_curr_tile_x;
        input [TILE_BITS-1:0]   t_curr_tile_y;
        input [LOCAL_BITS-1:0]  t_curr_lx;
        input [LOCAL_BITS-1:0]  t_curr_ly;
        input [TILE_BITS-1:0]   t_dest_tile_x;
        input [TILE_BITS-1:0]   t_dest_tile_y;
        input [LOCAL_BITS-1:0]  t_dest_lx;
        input [LOCAL_BITS-1:0]  t_dest_ly;
        input [1:0]             t_vc_class;
        input [`N_PORTS-1:0]    t_link_up;
        input [`N_PORTS-1:0]    t_expected_ports;
        input [8*50:1]          t_msg;
        begin
            curr_tile_x = t_curr_tile_x;
            curr_tile_y = t_curr_tile_y;
            curr_lx     = t_curr_lx;
            curr_ly     = t_curr_ly;
            dest_tile_x = t_dest_tile_x;
            dest_tile_y = t_dest_tile_y;
            dest_lx     = t_dest_lx;
            dest_ly     = t_dest_ly;
            vc_class    = t_vc_class;
            link_up     = t_link_up;
            pkt_valid   = 1'b1;
            #5;

            expected_ports = t_expected_ports;

            if ((req_ports & t_link_up) === expected_ports)
                $display("SUCCESS: %s | req_ports=%b | retry=%b", t_msg, req_ports, retry);
            else
                $display("FAIL   : %s | expected=%b got=%b | retry=%b",
                         t_msg, expected_ports, req_ports, retry);
        end
    endtask

    initial begin
        pkt_valid = 0;
        vc_class  = 2'b00;
        link_up   = {`N_PORTS{1'b1}};
        #5;

        // Short-range
        run_test(0,0,1,1,0,0,2,1,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_E),"Short-range East");
        run_test(0,0,1,1,0,0,0,1,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_W),"Short-range West");
        run_test(0,0,1,1,0,0,1,2,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_N),"Short-range North");
        run_test(0,0,1,1,0,0,1,0,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_S),"Short-range South");

        // Mid-range
        run_test(0,0,1,1,0,0,2,2,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_NE),"Mid-range NE");
        run_test(0,0,1,1,0,0,0,2,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_NW),"Mid-range NW");

        // Inter-cluster (SerDes)
        run_test(1,1,1,1,2,1,1,1,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_SER_E),"Inter-cluster East");
        run_test(1,1,1,1,0,1,1,1,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_SER_W),"Inter-cluster West");
        run_test(1,1,1,1,1,2,1,1,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_SER_N),"Inter-cluster North");
        run_test(1,1,1,1,0,0,1,1,2'b00,{`N_PORTS{1'b1}},`ONEHOT(`PORT_SER_S),"Inter-cluster South");

        // VC disables SerDes
        run_test(0,0,1,1,1,0,1,1,2'b01,{`N_PORTS{1'b1}},{`N_PORTS{1'b0}},"VC disables SerDes East");

        // Rerouting
        run_test(0,0,1,1,0,0,2,1,2'b00,{`N_PORTS{1'b1}} & ~`ONEHOT(`PORT_E),`ONEHOT(`PORT_N),"Reroute East -> North");
        run_test(1,1,1,1,2,1,1,1,2'b00,{`N_PORTS{1'b1}} & ~`ONEHOT(`PORT_SER_E),`ONEHOT(`PORT_SER_N),"Reroute SER_E -> SER_N");
        run_test(1,1,1,1,2,1,1,1,2'b00,{`N_PORTS{1'b0}},{`N_PORTS{1'b0}},"Reroute exhausted -> retry");

        #10 $display("All scalability tests completed.");
        $finish;
    end

endmodule
