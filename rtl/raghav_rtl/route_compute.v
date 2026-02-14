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

module route_compute
#(
    parameter TILE_BITS  = 2,   // bits for tile coordinates
    parameter LOCAL_BITS = 2    // bits for local coordinates within tile
)
(
    input  wire                   pkt_valid,    // packet validity check
    input  wire [TILE_BITS-1:0]   cur_x,  // current tile x_id
    input  wire [TILE_BITS-1:0]   cur_y,  // current tile y_id
    input  wire [LOCAL_BITS-1:0]  cur_lx,      // current local x_id
    input  wire [LOCAL_BITS-1:0]  cur_ly,      // current local y_id
    input  wire [TILE_BITS-1:0]   dst_x,  // destination tile x_id
    input  wire [TILE_BITS-1:0]   dst_y,  // destination tile y_id
    input  wire [LOCAL_BITS-1:0]  dest_lx,      // destination local x_id
    input  wire [LOCAL_BITS-1:0]  dest_ly,      // destination local y_id
    input  wire [1:0]             vc_class,     // virtual channel class (for arbitration)
    input  wire [`N_PORTS-1:0]    link_up,      // link availability (link-awareness)
    
    output wire [`N_PORTS-1:0]    req_port,
    output wire                   retry
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

    // determine if packet is inter-tile (SerDes) or intra-tile
    wire inter_tile = (cur_x != dst_x) || (cur_y != dst_y);

    // direction to destination tile
    wire east_tile  = dst_x > cur_x;
    wire west_tile  = dst_x < cur_x;
    wire north_tile = dst_y > cur_y;
    wire south_tile = dst_y < cur_y;

    // intra-tile direction
    wire east_local  = dest_lx > cur_lx;
    wire west_local  = dest_lx < cur_lx;
    wire north_local = dest_ly > cur_ly;
    wire south_local = dest_ly < cur_ly;

    // primary route request (no link awareness)
    wire [`N_PORTS-1:0] primary_req =
        pkt_valid ?
        (inter_tile ?
            (north_tile ? OH_SER_N :
             south_tile ? OH_SER_S :
             east_tile  ? OH_SER_E :
             west_tile  ? OH_SER_W : {`N_PORTS{1'b0}})
        :
            (north_local & ~east_local & ~west_local) ? OH_N  :
            (south_local & ~east_local & ~west_local) ? OH_S  :
            (east_local  & ~north_local & ~south_local) ? OH_E :
            (west_local  & ~north_local & ~south_local) ? OH_W :
            (north_local & east_local) ? OH_NE :
            (north_local & west_local) ? OH_NW :
            (south_local & east_local) ? OH_SE :
            (south_local & west_local) ? OH_SW :
            {`N_PORTS{1'b0}})
        :
            {`N_PORTS{1'b0}};

    // VC mask example
    wire [`N_PORTS-1:0] vc_mask =
        (vc_class == 2'b01) ?
        ~(OH_SER_N | OH_SER_S | OH_SER_E | OH_SER_W) :
        {`N_PORTS{1'b1}};

    // masked primary
    wire [`N_PORTS-1:0] primary_ok = primary_req & vc_mask & link_up;

    // reroute candidates (closest progress first)
    wire [`N_PORTS-1:0] reroute_req =
        pkt_valid?
            inter_tile ?
                north_tile ?
                    (link_up[`PORT_SER_E] ? OH_SER_E :
                    link_up[`PORT_SER_W] ? OH_SER_W :
                    link_up[`PORT_SER_S] ? OH_SER_S : {`N_PORTS{1'b0}})
                :
                south_tile ?
                    (link_up[`PORT_SER_E] ? OH_SER_E :
                    link_up[`PORT_SER_W] ? OH_SER_W :
                    link_up[`PORT_SER_N] ? OH_SER_N : {`N_PORTS{1'b0}})
                :
                east_tile ?
                    (link_up[`PORT_SER_N] ? OH_SER_N :
                    link_up[`PORT_SER_S] ? OH_SER_S :
                    link_up[`PORT_SER_W] ? OH_SER_W : {`N_PORTS{1'b0}})
                :
                west_tile ?
                    (link_up[`PORT_SER_N] ? OH_SER_N :
                    link_up[`PORT_SER_S] ? OH_SER_S :
                    link_up[`PORT_SER_E] ? OH_SER_E : {`N_PORTS{1'b0}})
                :
                    {`N_PORTS{1'b0}}
            :
                north_local ?
                    (link_up[`PORT_E] ? OH_E :
                    link_up[`PORT_W] ? OH_W :
                    link_up[`PORT_S] ? OH_S : {`N_PORTS{1'b0}})
                :
                south_local ?
                    (link_up[`PORT_E] ? OH_E :
                    link_up[`PORT_W] ? OH_W :
                    link_up[`PORT_N] ? OH_N : {`N_PORTS{1'b0}})
                :
                east_local ?
                    (link_up[`PORT_N] ? OH_N :
                    link_up[`PORT_S] ? OH_S :
                    link_up[`PORT_W] ? OH_W : {`N_PORTS{1'b0}})
                :
                west_local ?
                    (link_up[`PORT_N] ? OH_N :
                    link_up[`PORT_S] ? OH_S :
                    link_up[`PORT_E] ? OH_E : {`N_PORTS{1'b0}})
                :
                    {`N_PORTS{1'b0}}
            :
            {`N_PORTS{1'b0}};

    // final output
    assign req_port = (primary_ok != 0) ? primary_ok : (reroute_req & vc_mask);
    assign retry     = pkt_valid & (req_port == {`N_PORTS{1'b0}});

endmodule
