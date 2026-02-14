#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcredit_manager.h"

#define CLK_PERIOD 10
#define NUM_PORTS 5
#define FIFO_DEPTH 8
#define CREDIT_W 4  // clog2(8+1) = 4

class CreditManagerTB {
private:
    Vcredit_manager* dut;
    VerilatedVcdC* tfp;
    vluint64_t sim_time;
    int test_count;
    int passed;
    int failed;

    // shadow credits for checking
    int shadow_credit[NUM_PORTS];

public:
    CreditManagerTB() {
        dut = new Vcredit_manager;
        tfp = new VerilatedVcdC;
        sim_time = 0;
        test_count = 0;
        passed = 0;
        failed = 0;
        Verilated::traceEverOn(true);
        dut->trace(tfp, 99);
        tfp->open("credit_manager.vcd");

        for(int i = 0; i < NUM_PORTS; i++){
            shadow_credit[i] = FIFO_DEPTH;
        }
    }

    ~CreditManagerTB() {
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

        // update shadow on posedge
        if(!dut->rst){
            for(int p = 0; p < NUM_PORTS; p++){
                bool ds = (dut->downstream_credit >> p) & 1;
                bool ret = (dut->outq_credit_return >> p) & 1;
                if(ds && !ret){
                    shadow_credit[p]--;
                } else if(!ds && ret){
                    shadow_credit[p]++;
                }
            }
        }
    }

    void init_inputs() {
        dut->rst = 1;
        dut->outq_credit_return = 0;
        dut->downstream_credit = 0;
        dut->eval();
    }

    void apply_reset() {
        dut->rst = 1;
        dut->outq_credit_return = 0;
        dut->downstream_credit = 0;
        tick(); tick();
        dut->rst = 0;
        tick();
        for(int i = 0; i < NUM_PORTS; i++)
            shadow_credit[i] = FIFO_DEPTH;
    }

    void wait_cycles(int n) {
        for(int i = 0; i < n; i++) tick();
    }

    void decrement_credit(int port) {
        dut->downstream_credit |= (1 << port);
        tick();
        dut->downstream_credit &= ~(1 << port);
    }
    void increment_credit(int port) {
        dut->outq_credit_return |= (1 << port);
        tick();
        dut->outq_credit_return &= ~(1 << port);
    }

    bool check_can_send(int port, bool expected) {
        test_count++;
        bool actual = (dut->can_send >> port) & 1;
        if(actual == expected){ passed++; return true; }
        failed++;
        printf("FAIL test %d: can_send[%d]=%d expected=%d\n", test_count, port, actual, expected);
        return false;
    }

    bool check_all_can_send(uint8_t expected) {
        test_count++;
        uint8_t actual = dut->can_send;
        if(actual == expected){ passed++; return true; }
        failed++;
        printf("FAIL test %d: can_send=0x%x expected=0x%x\n", test_count, actual, expected);
        return false;
    }

    bool check_upstream_credit(uint8_t expected) {
        test_count++;
        uint8_t actual = dut->upstream_credit;
        if(actual == expected){ passed++; return true; }
        failed++;
        printf("FAIL test %d: upstream_credit=0x%x expected=0x%x\n", test_count, actual, expected);
        return false;
    }

    void run_tests() {
        printf("credit_manager testbench\n");

        // reset: all ports should be able to send
        init_inputs();
        tick();
        apply_reset();
        check_all_can_send(0x1F);

        // credit decrement
        apply_reset();
        decrement_credit(0);
        tick();
        check_can_send(0, true); // still has credits (7)

        // drain port 0 completely
        for(int i = 0; i < FIFO_DEPTH-1; i++)
            decrement_credit(0);
        tick();
        check_can_send(0, false);
        check_can_send(1, true);
        check_can_send(2, true);

        // credit recovery
        apply_reset();
        for(int i = 0; i < FIFO_DEPTH; i++) decrement_credit(0);
        tick();
        check_can_send(0, false);
        increment_credit(0);
        tick();
        check_can_send(0, true);
        for(int i = 0; i < FIFO_DEPTH-1; i++) increment_credit(0);
        tick();
        check_can_send(0, true);

        // simultaneous inc/dec should cancel out
        apply_reset();
        for(int i = 0; i < 4; i++) decrement_credit(0);
        tick();
        dut->downstream_credit = 1;
        dut->outq_credit_return = 1;
        tick();
        dut->downstream_credit = 0;
        dut->outq_credit_return = 0;
        tick();
        check_can_send(0, true);

        // multi-port at once
        apply_reset();
        dut->downstream_credit = 0b00011; // ports 0,1
        dut->outq_credit_return = 0b00100; // port 2
        tick();
        dut->downstream_credit = 0;
        dut->outq_credit_return = 0;
        tick();
        check_can_send(0, true);
        check_can_send(1, true);
        check_can_send(2, true);

        // exhaust all ports then recover
        apply_reset();
        for(int i = 0; i < FIFO_DEPTH; i++){
            dut->downstream_credit = 0x1F;
            tick();
            dut->downstream_credit = 0;
        }
        tick();
        check_all_can_send(0x00);
        increment_credit(0);
        tick();
        check_can_send(0, true);
        check_can_send(1, false);
        increment_credit(1);
        tick();
        check_can_send(1, true);
        // recover all
        for(int i = 0; i < FIFO_DEPTH; i++){
            dut->outq_credit_return = 0x1F;
            tick();
            dut->outq_credit_return = 0;
        }
        tick();
        check_all_can_send(0x1F);

        // port independence - different levels on each port
        apply_reset();
        for(int i = 0; i < FIFO_DEPTH; i++) decrement_credit(0);
        for(int i = 0; i < FIFO_DEPTH/2; i++) decrement_credit(1);
        decrement_credit(2);
        for(int i = 0; i < FIFO_DEPTH; i++) decrement_credit(4);
        increment_credit(4);
        tick();
        check_can_send(0, false);
        check_can_send(1, true);
        check_can_send(2, true);
        check_can_send(3, true);
        check_can_send(4, true);

        // upstream credit is just a passthrough of outq_credit_return
        apply_reset();
        dut->outq_credit_return = 0b00001; dut->eval();
        check_upstream_credit(0b00001);
        dut->outq_credit_return = 0b10101; dut->eval();
        check_upstream_credit(0b10101);
        dut->outq_credit_return = 0b11111; dut->eval();
        check_upstream_credit(0b11111);
        dut->outq_credit_return = 0b00000; dut->eval();
        check_upstream_credit(0b00000);

        // reset in the middle of stuff
        apply_reset();
        for(int i = 0; i < 3; i++) decrement_credit(0);
        tick();
        dut->rst = 1; tick();
        dut->rst = 0; tick();
        for(int i = 0; i < NUM_PORTS; i++) shadow_credit[i] = FIFO_DEPTH;
        check_all_can_send(0x1F);

        // rapid toggling - dec then inc back, net zero
        apply_reset();
        for(int i = 0; i < 20; i++){
            dut->downstream_credit = 1;
            tick();
            dut->downstream_credit = 0;
            dut->outq_credit_return = 1;
            tick();
            dut->outq_credit_return = 0;
        }
        tick();
        check_can_send(0, true);

        // boundary check - 1 credit left then exhaust
        apply_reset();
        for(int i = 0; i < FIFO_DEPTH-1; i++) decrement_credit(0);
        tick();
        check_can_send(0, true);
        decrement_credit(0);
        tick();
        check_can_send(0, false);

        // stress test with random inputs
        apply_reset();
        int errors = 0;
        for(int cycle = 0; cycle < 100; cycle++){
            uint8_t random_downstream = rand() % (1 << NUM_PORTS);
            uint8_t random_return = rand() % (1 << NUM_PORTS);
            // dont underflow or overflow
            for(int p = 0; p < NUM_PORTS; p++){
                if(shadow_credit[p] == 0) random_downstream &= ~(1 << p);
                if(shadow_credit[p] == FIFO_DEPTH) random_return &= ~(1 << p);
            }
            dut->downstream_credit = random_downstream;
            dut->outq_credit_return = random_return;
            tick();
            dut->downstream_credit = 0;
            dut->outq_credit_return = 0;
            tick();

            for(int p = 0; p < NUM_PORTS; p++){
                bool expected = shadow_credit[p] != 0;
                bool actual = (dut->can_send >> p) & 1;
                if(actual != expected) errors++;
            }
        }
        test_count++;
        if(errors == 0){ passed++; }
        else { failed++; printf("FAIL stress: %d errors\n", errors); }

        // drain then refill
        apply_reset();
        for(int i = 0; i < FIFO_DEPTH; i++) decrement_credit(0);
        tick();
        check_can_send(0, false);
        for(int i = 0; i < FIFO_DEPTH; i++) increment_credit(0);
        tick();
        check_can_send(0, true);

        // alternating dec/inc
        apply_reset();
        for(int i = 0; i < 10; i++){
            decrement_credit(0);
            tick();
            increment_credit(0);
            tick();
        }
        check_can_send(0, true);

        printf("\n%d/%d tests passed\n", passed, test_count);
        if(failed > 0) printf("%d FAILED\n", failed);
    }

    bool all_passed() { return failed == 0; }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    CreditManagerTB* tb = new CreditManagerTB();
    tb->run_tests();
    bool success = tb->all_passed();
    delete tb;
    return success ? 0 : 1;
}
