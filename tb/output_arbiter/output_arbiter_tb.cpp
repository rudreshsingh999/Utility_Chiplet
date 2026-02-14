#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Voutput_arbiter.h"

#define CLK_PERIOD 10
#define NUM_INPUTS 5

class OutputArbiterTB {
private:
    Voutput_arbiter* dut;
    VerilatedVcdC* tfp;
    vluint64_t sim_time;
    int test_count;
    int passed;
    int failed;

public:
    OutputArbiterTB() {
        dut = new Voutput_arbiter;
        tfp = new VerilatedVcdC;
        sim_time = 0;
        test_count = 0;
        passed = 0;
        failed = 0;
        Verilated::traceEverOn(true);
        dut->trace(tfp, 99);
        tfp->open("output_arbiter.vcd");
    }

    ~OutputArbiterTB() {
        tfp->close();
        delete tfp;
        delete dut;
    }

    void tick() {
        dut->clk = 0;
        dut->eval();
        tfp->dump(sim_time++);
        dut->clk = 1;
        dut->eval();
        tfp->dump(sim_time++);
    }

    void init_inputs() {
        dut->rst = 1;
        dut->fifo_empty = (1 << NUM_INPUTS) - 1; // all empty
        dut->outq_ready = 0;
        dut->eval();
    }

    void apply_reset() {
        dut->rst = 1;
        dut->fifo_empty = (1 << NUM_INPUTS) - 1;
        dut->outq_ready = 0;
        tick(); tick();
        dut->rst = 0;
        dut->eval();
    }

    void wait_cycles(int n) {
        for(int i = 0; i < n; i++) tick();
    }

    void set_fifo_status(uint8_t empty) {
        dut->fifo_empty = empty;
        dut->eval();
    }
    void fifo_has_data(int idx) {
        dut->fifo_empty &= ~(1 << idx);
        dut->eval();
    }
    void fifo_is_empty(int idx) {
        dut->fifo_empty |= (1 << idx);
        dut->eval();
    }

    int count_ones(uint8_t val) {
        int count = 0;
        for(int i = 0; i < NUM_INPUTS; i++){
            if(val & (1 << i)) count++;
        }
        return count;
    }

    int find_one_pos(uint8_t val) {
        for(int i = 0; i < NUM_INPUTS; i++){
            if(val & (1 << i)) return i;
        }
        return -1;
    }

    uint8_t encoding_fn(int idx) { return (1 << idx); }

    bool check_grant_valid(bool expected) {
        test_count++;
        bool actual = dut->grant_valid;
        if(actual == expected){ passed++; return true; }
        failed++;
        printf("FAIL test %d: grant_valid=%d expected=%d\n", test_count, actual, expected);
        return false;
    }

    bool check_fifo_rd_en(uint8_t expected) {
        test_count++;
        uint8_t actual = dut->fifo_rd_en;
        if(actual == expected){ passed++; return true; }
        failed++;
        printf("FAIL test %d: fifo_rd_en=0x%x expected=0x%x\n", test_count, actual, expected);
        return false;
    }

    bool check_granted_port(int expected_port) {
        test_count++;
        bool grant_ok = dut->grant_valid;
        uint8_t rd_en = dut->fifo_rd_en;
        int actual_port = find_one_pos(rd_en);
        if(grant_ok && rd_en == encoding_fn(expected_port)){
            passed++; return true;
        }
        failed++;
        printf("FAIL test %d: granted port=%d expected=%d grant_valid=%d\n",
            test_count, actual_port, expected_port, grant_ok);
        return false;
    }

    bool check_only_one_grant() {
        test_count++;
        int ones = count_ones(dut->fifo_rd_en);
        if(ones <= 1){ passed++; return true; }
        failed++;
        printf("FAIL test %d: multiple grants (%d)\n", test_count, ones);
        return false;
    }

    void run_tests() {
        printf("output_arbiter testbench\n");

        // all fifos empty, outq ready
        init_inputs();
        tick();
        apply_reset();
        dut->outq_ready = 1;
        dut->fifo_empty = (1 << NUM_INPUTS) - 1;
        dut->eval();
        check_grant_valid(false);
        check_fifo_rd_en(0);

        // single request from each port
        for(int port = 0; port < NUM_INPUTS; port++){
            apply_reset();
            dut->outq_ready = 1;
            dut->fifo_empty = (1 << NUM_INPUTS) - 1;
            fifo_has_data(port);
            dut->eval();
            check_granted_port(port);
        }

        // round robin with all fifos having data
        apply_reset();
        dut->outq_ready = 1;
        dut->fifo_empty = 0;
        dut->eval();
        check_granted_port(1); // after reset rr_ptr=0 so first grant is 1
        tick(); dut->eval();
        check_granted_port(2);
        tick(); dut->eval();
        check_granted_port(3);
        tick(); dut->eval();
        check_granted_port(4);
        tick(); dut->eval();
        check_granted_port(0);
        tick(); dut->eval();
        check_granted_port(1);

        // sparse requests - ports 0 and 3 have data
        apply_reset();
        dut->outq_ready = 1;
        dut->fifo_empty = 0b10110;
        dut->eval();
        check_granted_port(3);
        tick(); dut->eval();
        check_granted_port(0);

        // wrap around
        apply_reset();
        dut->outq_ready = 1;
        dut->fifo_empty = (1 << NUM_INPUTS) - 1;
        fifo_has_data(4);
        dut->eval();
        check_granted_port(4);
        tick();
        dut->fifo_empty = (1 << NUM_INPUTS) - 1;
        fifo_has_data(1);
        dut->eval();
        check_granted_port(1);
        tick();
        dut->fifo_empty = (1 << NUM_INPUTS) - 1;
        fifo_has_data(0);
        dut->eval();
        check_granted_port(0);

        // outq_ready=0 should block
        apply_reset();
        dut->fifo_empty = 0;
        dut->outq_ready = 0;
        dut->eval();
        check_grant_valid(false);
        check_fifo_rd_en(0);
        dut->outq_ready = 1;
        dut->eval();
        check_grant_valid(true);
        check_only_one_grant();
        tick();
        dut->outq_ready = 0;
        dut->eval();
        check_grant_valid(false);
        dut->outq_ready = 1;
        dut->eval();
        check_grant_valid(true);

        // all empty with ready high - rr_ptr shouldnt move
        apply_reset();
        dut->outq_ready = 1;
        dut->fifo_empty = (1 << NUM_INPUTS) - 1;
        dut->eval();
        check_grant_valid(false);
        check_fifo_rd_en(0);
        tick(); tick(); tick();
        fifo_has_data(2);
        dut->eval();
        check_granted_port(2);

        // consecutive grants to same port when its the only one
        apply_reset();
        dut->outq_ready = 1;
        dut->fifo_empty = 0b11011; // only port 2
        dut->eval();
        check_granted_port(2);
        tick();
        dut->fifo_empty = 0b11011;
        dut->eval();
        check_granted_port(2);

        // stress test
        apply_reset();
        dut->outq_ready = 1;
        int errors = 0;
        for(int cycle = 0; cycle < 200; cycle++){
            uint8_t random_empty = rand() % (1 << NUM_INPUTS);
            dut->outq_ready = (rand() % 100) < 80 ? 1 : 0;
            dut->fifo_empty = random_empty;
            uint8_t data_avail = ~random_empty & ((1 << NUM_INPUTS) - 1);
            dut->eval();

            if(dut->outq_ready && data_avail != 0){
                if(!dut->grant_valid) errors++;
                else if((dut->fifo_rd_en & data_avail) == 0) errors++;
            } else if(!dut->outq_ready || data_avail == 0){
                if(dut->fifo_rd_en != 0 && !dut->outq_ready) errors++;
            }
            tick();
        }
        test_count++;
        if(errors == 0){ passed++; }
        else { failed++; printf("FAIL stress: %d errors\n", errors); }

        printf("\n%d/%d tests passed\n", passed, test_count);
        if(failed > 0) printf("%d FAILED\n", failed);
    }

    bool all_passed() { return failed == 0; }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    OutputArbiterTB* tb = new OutputArbiterTB();
    tb->run_tests();
    bool success = tb->all_passed();
    delete tb;
    return success ? 0 : 1;
}
