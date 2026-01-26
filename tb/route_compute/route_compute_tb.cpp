#include <iostream>
#include <iomanip>
#include <cstdint>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vroute_compute.h"

static constexpr int N_PORTS = 12;

static constexpr int PORT_N     = 0;
static constexpr int PORT_S     = 1;
static constexpr int PORT_E     = 2;
static constexpr int PORT_W     = 3;
static constexpr int PORT_NE    = 4;
static constexpr int PORT_NW    = 5;
static constexpr int PORT_SE    = 6;
static constexpr int PORT_SW    = 7;
static constexpr int PORT_SER_N = 8;
static constexpr int PORT_SER_S = 9;
static constexpr int PORT_SER_E = 10;
static constexpr int PORT_SER_W = 11;

static inline uint32_t ONEHOT(int p) {
    return (uint32_t(1) << p);
}


// Binary print helper 
static inline void print_bin(uint32_t v, int width) {
    for (int i = width - 1; i >= 0; --i)
        std::cout << ((v >> i) & 1);

}


// Single test helper 
void run_test(
    Vroute_compute* dut,
    uint32_t curr_tile_x,
    uint32_t curr_tile_y,
    uint32_t curr_lx,
    uint32_t curr_ly,
    uint32_t dest_tile_x,
    uint32_t dest_tile_y,
    uint32_t dest_lx,
    uint32_t dest_ly,
    uint32_t vc_class,
    uint32_t link_up,
    uint32_t expected_ports,
    const char* msg
) {
    dut->curr_tile_x = curr_tile_x;
    dut->curr_tile_y = curr_tile_y;
    dut->curr_lx     = curr_lx;
    dut->curr_ly     = curr_ly;
    dut->dest_tile_x = dest_tile_x;
    dut->dest_tile_y = dest_tile_y;
    dut->dest_lx     = dest_lx;
    dut->dest_ly     = dest_ly;
    dut->vc_class    = vc_class;
    dut->link_up     = link_up;
    dut->pkt_valid   = 1;

    dut->eval();

    uint32_t got = dut->req_ports & link_up;

    if (got == expected_ports) {
        std::cout << "SUCCESS: " << msg << " | req_ports=";
        print_bin(dut->req_ports, N_PORTS);
        std::cout << " | retry=" << int(dut->retry) << "\n";
    } else {
        std::cout << "FAIL   : " << msg << " | expected=";
        print_bin(expected_ports, N_PORTS);
        std::cout << " got=";
        print_bin(got, N_PORTS);
        std::cout << " | retry=" << int(dut->retry) << "\n";

    }
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vroute_compute* dut = new Vroute_compute;

    // Optional waveform
    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("route_compute.vcd");

    // Defaults
    dut->pkt_valid = 0;
    dut->vc_class  = 0;
    dut->link_up   = (1u << N_PORTS) - 1;
    dut->eval();


    // Short-range test
    run_test(dut,0,0,1,1,0,0,2,1,0,(1u<<N_PORTS)-1,ONEHOT(PORT_E),"Short-range East");
    run_test(dut,0,0,1,1,0,0,0,1,0,(1u<<N_PORTS)-1,ONEHOT(PORT_W),"Short-range West");
    run_test(dut,0,0,1,1,0,0,1,2,0,(1u<<N_PORTS)-1,ONEHOT(PORT_N),"Short-range North");
    run_test(dut,0,0,1,1,0,0,1,0,0,(1u<<N_PORTS)-1,ONEHOT(PORT_S),"Short-range South");


    // Mid-range test
    run_test(dut,0,0,1,1,0,0,2,2,0,(1u<<N_PORTS)-1,ONEHOT(PORT_NE),"Mid-range NE");
    run_test(dut,0,0,1,1,0,0,0,2,0,(1u<<N_PORTS)-1,ONEHOT(PORT_NW),"Mid-range NW");


    // Inter-cluster (SerDes) test
    run_test(dut,1,1,1,1,2,1,1,1,0,(1u<<N_PORTS)-1,ONEHOT(PORT_SER_E),"Inter-cluster East");
    run_test(dut,1,1,1,1,0,1,1,1,0,(1u<<N_PORTS)-1,ONEHOT(PORT_SER_W),"Inter-cluster West");
    run_test(dut,1,1,1,1,1,2,1,1,0,(1u<<N_PORTS)-1,ONEHOT(PORT_SER_N),"Inter-cluster North");
    run_test(dut,1,1,1,1,0,0,1,1,0,(1u<<N_PORTS)-1,ONEHOT(PORT_SER_S),"Inter-cluster South");


    // VC disables SerDes
    run_test(dut,0,0,1,1,1,0,1,1,1,(1u<<N_PORTS)-1,0,"VC disables SerDes East");


    // Rerouting tests
    run_test(dut,0,0,1,1,0,0,2,1,0,((1u<<N_PORTS)-1) & ~ONEHOT(PORT_E),ONEHOT(PORT_N),"Reroute East -> North");
    run_test(dut,1,1,1,1,2,1,1,1,0,((1u<<N_PORTS)-1) & ~ONEHOT(PORT_SER_E),ONEHOT(PORT_SER_N),"Reroute SER_E -> SER_N");
    run_test(dut,1,1,1,1,2,1,1,1,0,0,0,"Reroute exhausted -> retry");

    std::cout << "All scalability tests completed.\n";

    tfp->close();
    delete tfp;
    delete dut;
    return 0;
}
