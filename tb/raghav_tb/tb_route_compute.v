`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 03:42:34 PM
// Design Name: 
// Module Name: tb_route_compute
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define PORT_N     0
`define PORT_S     1
`define PORT_E     2
`define PORT_W     3
`define PORT_NE    4
`define PORT_NW    5
`define PORT_SE    6
`define PORT_SW    7
`define PORT_SER_N 8
`define PORT_SER_S 9
`define PORT_SER_E 10
`define PORT_SER_W 11
`define N_PORTS    12

module tb_route_compute;

parameter TILE_BITS = 2;
parameter LOCAL_BITS = 2;

reg pkt_valid;
reg [TILE_BITS-1:0] curr_tile_x;
reg [TILE_BITS-1:0] curr_tile_y;
reg [TILE_BITS-1:0] dest_tile_x;
reg [TILE_BITS-1:0] dest_tile_y;
reg [LOCAL_BITS-1:0] curr_lx;
reg [LOCAL_BITS-1:0] curr_ly;
reg [LOCAL_BITS-1:0] dest_lx;
reg [LOCAL_BITS-1:0] dest_ly;
reg [1:0] vc_class;
reg [`N_PORTS-1:0] link_up;

wire [`N_PORTS-1:0] req_ports;
wire [`N_PORTS-1:0] test;
wire retry; 

route_compute #(
    .TILE_BITS(TILE_BITS),
    .LOCAL_BITS(LOCAL_BITS)
) dut (
    .pkt_valid(pkt_valid),    // packet validity check
    .curr_tile_x(curr_tile_x),  // current tile x_id
    .curr_tile_y(curr_tile_y),  // current tile y_id
    .curr_lx(curr_lx),      // current local x_id
    .curr_ly(curr_ly),      // current local y_id
    .dest_tile_x(dest_tile_x),  // destination tile x_id
    .dest_tile_y(dest_tile_y),  // destination tile y_id
    .dest_lx(dest_lx),      // destination local x_id
    .dest_ly(dest_ly),      // destination local y_id
    .vc_class(vc_class),     // virtual channel class (for arbitration)
    .link_up(link_up),      // link availability (link-awareness)
    .test(test),
    .req_ports(req_ports),
    .retry(retry)
);

// one-hot constants (verilator safe)
localparam [`N_PORTS-1:0] OH_N     = 12'b000000000001;
localparam [`N_PORTS-1:0] OH_S     = 12'b000000000010;
localparam [`N_PORTS-1:0] OH_E     = 12'b000000000100;
localparam [`N_PORTS-1:0] OH_W     = 12'b000000001000;
localparam [`N_PORTS-1:0] OH_NE    = 12'b000000010000;
localparam [`N_PORTS-1:0] OH_NW    = 12'b000000100000;
localparam [`N_PORTS-1:0] OH_SE    = 12'b000001000000;
localparam [`N_PORTS-1:0] OH_SW    = 12'b000010000000;
localparam [`N_PORTS-1:0] OH_SER_N = 12'b000100000000;
localparam [`N_PORTS-1:0] OH_SER_S = 12'b001000000000;
localparam [`N_PORTS-1:0] OH_SER_E = 12'b010000000000;
localparam [`N_PORTS-1:0] OH_SER_W = 12'b100000000000;

reg [`N_PORTS-1:0] expected_port;
reg [`N_PORTS-1:0] reroute;
reg [`N_PORTS-1:0] vc_mask;

task compute_expected;
    reg inter_tile;
    reg east_tile, west_tile, north_tile, south_tile;
    reg east_local, west_local, north_local, south_local;
    begin
        expected_port = {`N_PORTS{1'b0}};
        reroute       = {`N_PORTS{1'b0}};
        inter_tile  = 1'b0;
        east_tile   = 1'b0;
        west_tile  = 1'b0;
        north_tile = 1'b0;
        south_tile = 1'b0;
        east_local  = 1'b0;
        west_local = 1'b0;
        north_local= 1'b0;
        south_local= 1'b0;

        //stop if pkt is invalid - no point
        if (!pkt_valid) begin
        end else begin
            inter_tile  = (curr_tile_x != dest_tile_x) || (curr_tile_y != dest_tile_y);

            east_tile   = (dest_tile_x > curr_tile_x);
            west_tile   = (dest_tile_x < curr_tile_x);
            north_tile  = (dest_tile_y > curr_tile_y);
            south_tile  = (dest_tile_y < curr_tile_y);

            east_local  = (dest_lx > curr_lx);
            west_local  = (dest_lx < curr_lx);
            north_local = (dest_ly > curr_ly);
            south_local = (dest_ly < curr_ly);

            if (inter_tile) begin
                if      (north_tile) expected_port = OH_SER_N;
                else if (south_tile) expected_port = OH_SER_S;
                else if (east_tile)  expected_port = OH_SER_E;
                else if (west_tile)  expected_port = OH_SER_W;
                else                 expected_port = {`N_PORTS{1'b0}};
            end else begin
                if      (north_local && !east_local && !west_local) expected_port = OH_N;
                else if (south_local && !east_local && !west_local) expected_port = OH_S;
                else if (east_local  && !north_local && !south_local) expected_port = OH_E;
                else if (west_local  && !north_local && !south_local) expected_port = OH_W;
                else if (north_local && east_local) expected_port = OH_NE;
                else if (north_local && west_local) expected_port = OH_NW;
                else if (south_local && east_local) expected_port = OH_SE;
                else if (south_local && west_local) expected_port = OH_SW;
                else                                expected_port = {`N_PORTS{1'b0}};
            end

            reroute = inter_tile ?
                ( north_tile ?
                    ( link_up[`PORT_SER_E] ? OH_SER_E :
                      link_up[`PORT_SER_W] ? OH_SER_W :
                      link_up[`PORT_SER_S] ? OH_SER_S : {`N_PORTS{1'b0}} )
                  : south_tile ?
                    ( link_up[`PORT_SER_E] ? OH_SER_E :
                      link_up[`PORT_SER_W] ? OH_SER_W :
                      link_up[`PORT_SER_N] ? OH_SER_N : {`N_PORTS{1'b0}} )
                  : east_tile ?
                    ( link_up[`PORT_SER_N] ? OH_SER_N :
                      link_up[`PORT_SER_S] ? OH_SER_S :
                      link_up[`PORT_SER_W] ? OH_SER_W : {`N_PORTS{1'b0}} )
                  : west_tile ?
                    ( link_up[`PORT_SER_N] ? OH_SER_N :
                      link_up[`PORT_SER_S] ? OH_SER_S :
                      link_up[`PORT_SER_E] ? OH_SER_E : {`N_PORTS{1'b0}} )
                  : {`N_PORTS{1'b0}}
                )
              :
                ( north_local ?
                    ( link_up[`PORT_E] ? OH_E :
                      link_up[`PORT_W] ? OH_W :
                      link_up[`PORT_S] ? OH_S : {`N_PORTS{1'b0}} )
                  : south_local ?
                    ( link_up[`PORT_E] ? OH_E :
                      link_up[`PORT_W] ? OH_W :
                      link_up[`PORT_N] ? OH_N : {`N_PORTS{1'b0}} )
                  : east_local ?
                    ( link_up[`PORT_N] ? OH_N :
                      link_up[`PORT_S] ? OH_S :
                      link_up[`PORT_W] ? OH_W : {`N_PORTS{1'b0}} )
                  : west_local ?
                    ( link_up[`PORT_N] ? OH_N :
                      link_up[`PORT_S] ? OH_S :
                      link_up[`PORT_E] ? OH_E : {`N_PORTS{1'b0}} )
                  : {`N_PORTS{1'b0}}
                );

        end
    end
endtask
integer t;

initial begin
// ignore escape route and link awareness for now
//vc_class = 2'b00;
link_up  = {`N_PORTS{1'b1}};  // all links up

pkt_valid = 1'b1;

$display("STARTING TEST");

for (t = 0; t < 5000; t = t + 1) begin
    // randomze curr and dest tiles for stress testing
    curr_tile_x = $random & ((1<<TILE_BITS)-1);
    curr_tile_y = $random & ((1<<TILE_BITS)-1);
    dest_tile_x = $random & ((1<<TILE_BITS)-1);
    dest_tile_y = $random & ((1<<TILE_BITS)-1);

    curr_lx = $random & ((1<<LOCAL_BITS)-1);
    curr_ly = $random & ((1<<LOCAL_BITS)-1);
    dest_lx = $random & ((1<<LOCAL_BITS)-1);
    dest_ly = $random & ((1<<LOCAL_BITS)-1);
    
    //random vc channel
    vc_class = $urandom_range(1,0);
    
    //random link awareness
    link_up = $urandom;
    
    // occasionally test pkt_valid=0
    pkt_valid = ((t%97) == 0) ? 1'b0 : 1'b1;
    
    compute_expected;
    
    if(vc_class == 2'b01) begin
        vc_mask = ~(OH_SER_N|OH_SER_S|OH_SER_E|OH_SER_W);
    end else begin
        vc_mask = {`N_PORTS{1'b1}};
    end
    
    expected_port = expected_port & vc_mask & link_up;
    if (expected_port == 0) begin
        expected_port = reroute & vc_mask;
    end
    #1; 

    if (req_ports !== expected_port) begin
        $display("MISMATCH at t=%0d", t);
        $display(" pkt_valid=%0b vc_class=%b link_up=%b", pkt_valid, vc_class, link_up);
        $display(" curr_tile=(%0d,%0d) dest_tile=(%0d,%0d)", curr_tile_x,curr_tile_y,dest_tile_x,dest_tile_y);
        $display(" curr_local=(%0d,%0d) dest_local=(%0d,%0d)", curr_lx,curr_ly,dest_lx,dest_ly);
        $display(" got req_ports=%b expected=%b", req_ports, expected_port);
        $display(" primary_ok=%b", test);
        $stop;
    end

    // optional: check retry matches "no route"
    /*if (retry !== (pkt_valid && (expected_port == {`N_PORTS{1'b0}}))) begin
        $display("RETRY MISMATCH at t=%0d: retry=%0b exp=%0b pkt=%0b ", t, retry,
                 (pkt_valid && (expected_port == {`N_PORTS{1'b0}})));
        $stop;
      end*/
    end

    $display("PASS: no mismatches in %0d tests", t);
    $finish;
  end



endmodule
