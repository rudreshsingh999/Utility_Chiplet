`timescale 1ns/1ps

module tb_input_port;

  localparam int NUM_PORTS    = 12;
  localparam int PACKET_WIDTH = 128;
  localparam int FIFO_DEPTH   = 8;
  localparam int COORD_W      = 2;
  localparam int COORD_L_W    = 2;

  logic clk, rst;

  logic [COORD_W-1:0]   cur_x, cur_y;
  logic [COORD_L_W-1:0] cur_lx, cur_ly;
  logic [NUM_PORTS-1:0] link_up;

  logic                 in_valid;
  logic [PACKET_WIDTH-1:0] in_packet;
  logic                 in_ready;

  logic [NUM_PORTS-1:0] fifo_empty;
  logic [PACKET_WIDTH-1:0] fifo_rd_data [NUM_PORTS];
  logic [NUM_PORTS-1:0] fifo_rd_en;

  input_port #(
    .NUM_PORTS(NUM_PORTS),
    .PACKET_WIDTH(PACKET_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .COORD_W(COORD_W),
    .COORD_L_W(COORD_L_W)
  ) dut (
    .clk(clk),
    .rst(rst),
    .cur_x(cur_x),
    .cur_y(cur_y),
    .cur_lx(cur_lx),
    .cur_ly(cur_ly),
    .link_up(link_up),
    .in_valid(in_valid),
    .in_packet(in_packet),
    .in_ready(in_ready),
    .fifo_empty(fifo_empty),
    .fifo_rd_data(fifo_rd_data),
    .fifo_rd_en(fifo_rd_en)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk; // 100 MHz

 
  typedef logic [PACKET_WIDTH-1:0] pkt_t;
  pkt_t exp_q[NUM_PORTS][$];

  int sent_cnt, rcv_cnt, err_cnt;


  function automatic pkt_t make_packet(
    int dstx, int dsty,
    int dlx,  int dly,
    int vc,
    int seq
  );
    pkt_t p;
    int msb;
    begin
      p = '0;
      msb = PACKET_WIDTH-1;

      p[msb -: COORD_W]    = dstx[COORD_W-1:0];    msb -= COORD_W;
      p[msb -: COORD_W]    = dsty[COORD_W-1:0];    msb -= COORD_W;
      p[msb -: COORD_L_W]  = dlx[COORD_L_W-1:0];   msb -= COORD_L_W;
      p[msb -: COORD_L_W]  = dly[COORD_L_W-1:0];   msb -= COORD_L_W;
      p[msb -: 2]          = vc[1:0];

      // debug identity fields
      p[32 +: 16] = seq[15:0];
      p[96 +: 16] = (seq * 17) ^ 16'hBEEF;

      return p;
    end
  endfunction

  task automatic reset_dut();
    begin
      rst      = 1'b1;
      in_valid = 1'b0;
      in_packet= '0;
      fifo_rd_en = '0;

      cur_x  = 2'd1;
      cur_y  = 2'd1;
      cur_lx = 2'd1;
      cur_ly = 2'd1;

      link_up = '1; // all links up

      repeat (5) @(posedge clk);
      rst = 1'b0;
      repeat (2) @(posedge clk);
    end
  endtask

 task automatic send_packet(pkt_t p);
  int sel_latched;
  int guard;
  begin
    // drive packet + valid
    in_packet <= p;
    in_valid  <= 1'b1;

    guard = 0;
    while (1) begin
      @(posedge clk);

      if (in_ready === 1'b1) begin
        // accept packet on this edge
        sel_latched = dut.dest_port;
        sent_cnt++;
        exp_q[sel_latched].push_back(p);

        // deassert IMMEDIATELY this is what was giving me issues, I was accepting an extra packet in tb
        in_valid  <= 1'b0;
        in_packet <= '0;
        break;
      end

       
      guard++;
      //guard check was to debug infinite runtime errors
      if (guard > 2000) begin
        $display("[%0t] ERROR: TIMEOUT waiting for accept. in_ready=%b retry=%b req_port=%b dest_port=%0d",
                 $time, in_ready, dut.retry, dut.req_port, dut.dest_port);
        $finish;
      end
    end
  end
endtask


 task automatic pop_and_check_one(int p);
  pkt_t got, exp;
  begin
    if (fifo_empty[p]) return;

    fifo_rd_en = '0;
    fifo_rd_en[p] = 1'b1;

    @(posedge clk);          // pop occurs here
    fifo_rd_en[p] = 1'b0;

    got = fifo_rd_data[p];   // sample immediately after the pop edge

    if (exp_q[p].size() == 0) begin
      $display("[%0t] ERROR: VOQ %0d produced packet but scoreboard empty. got=%h",
               $time, p, got);
      err_cnt++;
    end else begin
      exp = exp_q[p].pop_front();
      if (got !== exp) begin
        $display("[%0t] ERROR: VOQ %0d mismatch. exp=%h got=%h",
                 $time, p, exp, got);
        err_cnt++;
      end else begin
        rcv_cnt++;
      end
    end
  end
endtask

task automatic drain_all();
  int   p;
  pkt_t got;
  pkt_t exp;
  begin
    // Drain exactly what we EXPECT per port
    for (p = 0; p < NUM_PORTS; p++) begin
      while (exp_q[p].size() > 0) begin
        fifo_rd_en = '0;
        fifo_rd_en[p] = 1'b1;
        @(posedge clk);
        fifo_rd_en[p] = 1'b0;

        // FIFO is assumed 1-cycle latency
        @(posedge clk);
        got = fifo_rd_data[p];

        exp = exp_q[p].pop_front();
        if (got !== exp) begin
          $display("[%0t] ERROR: VOQ %0d mismatch. exp=%h got=%h",
                   $time, p, exp, got);
          err_cnt++;
        end else begin
          rcv_cnt++;
        end
      end
    end

    // After draining expected, now check for unexpected leftovers
    @(posedge clk);
    for (p = 0; p < NUM_PORTS; p++) begin
      if (!fifo_empty[p]) begin
        $display("[%0t] ERROR: VOQ %0d has unexpected data (fifo_empty=0) after draining expected",
                 $time, p);
        err_cnt++;
      end
    end
  end
endtask

//Used CHATGPT to generate the test packets and the tests below 


  // ----------------------------
  // Directed packet generation that "makes sense"
  // Using:
  //   cur tile  = (1,1)
  //   cur local = (1,1)
  //
  // Intra-tile (dst tile = cur tile):
  //   N  : dest_ly > cur_ly, dest_lx == cur_lx
  //   S  : dest_ly < cur_ly, dest_lx == cur_lx
  //   E  : dest_lx > cur_lx, dest_ly == cur_ly
  //   W  : dest_lx < cur_lx, dest_ly == cur_ly
  //   NE : both >
  //   NW : ly >, lx <
  //   SE : ly <, lx >
  //   SW : both <
  //
  // Inter-tile (dst tile != cur tile):
  //   SER_N/S/E/W decided by tile direction
  // ----------------------------
  task automatic send_directed_set();
    pkt_t p;
    int seq;
    int cx, cy, clx, cly;
    begin
      seq = 1000;

      cx  = cur_x;  cy  = cur_y;
      clx = cur_lx; cly = cur_ly;

      // -------- Intra-tile (local) --------
      // Keep dst tile = current tile
      p = make_packet(cx, cy, clx, cly+1, 0, seq++); send_packet(p); // N
      p = make_packet(cx, cy, clx, cly-1, 0, seq++); send_packet(p); // S
      p = make_packet(cx, cy, clx+1, cly, 0, seq++); send_packet(p); // E
      p = make_packet(cx, cy, clx-1, cly, 0, seq++); send_packet(p); // W

      p = make_packet(cx, cy, clx+1, cly+1, 0, seq++); send_packet(p); // NE
      p = make_packet(cx, cy, clx-1, cly+1, 0, seq++); send_packet(p); // NW
      p = make_packet(cx, cy, clx+1, cly-1, 0, seq++); send_packet(p); // SE
      p = make_packet(cx, cy, clx-1, cly-1, 0, seq++); send_packet(p); // SW

      // -------- Inter-tile (SerDes) --------
      // Keep locals same (doesn't matter for inter_tile route)
      p = make_packet(cx, cy+1, clx, cly, 0, seq++); send_packet(p); // SER_N (dst_y > cur_y)
      p = make_packet(cx, cy-1, clx, cly, 0, seq++); send_packet(p); // SER_S
      p = make_packet(cx+1, cy, clx, cly, 0, seq++); send_packet(p); // SER_E
      p = make_packet(cx-1, cy, clx, cly, 0, seq++); send_packet(p); // SER_W
    end
  endtask

  // ----------------------------
  // Main test
  // ----------------------------
  initial begin
    sent_cnt = 0;
    rcv_cnt  = 0;
    err_cnt  = 0;

    reset_dut();

    // Directed sanity set that covers all 12 output ports (ideally)
    send_directed_set();

    // Drain everything and check segregation
    drain_all();

    // Final scoreboard empty check
    for (int p = 0; p < NUM_PORTS; p++) begin
      if (exp_q[p].size() != 0) begin
        $display("[%0t] ERROR: scoreboard not empty for VOQ %0d, remaining=%0d",
                 $time, p, exp_q[p].size());
        err_cnt++;
      end
    end

    $display("---- TEST DONE ---- sent=%0d rcv=%0d err=%0d", sent_cnt, rcv_cnt, err_cnt);
    if (err_cnt == 0) $display("PASS");
    else $display("FAIL");

    $finish;
  end

  // Optional global timeout so you never wait forever
  initial begin
    #200_000; // 200us
    $display("[%0t] ERROR: GLOBAL TIMEOUT", $time);
    $finish;
  end

endmodule
