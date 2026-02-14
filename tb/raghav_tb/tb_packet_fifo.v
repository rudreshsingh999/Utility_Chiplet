`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 01:38:33 PM
// Design Name: 
// Module Name: packet_fifo_tb
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


module tb_packet_fifo;

parameter PACKET_WIDTH = 128;
parameter DEPTH = 8;

reg clk;
reg rst;

reg wr_en;
reg [PACKET_WIDTH-1:0] wr_data;
wire full;

reg rd_en;
wire [PACKET_WIDTH-1:0] rd_data;
wire empty;

packet_fifo #(
    .PACKET_WIDTH(PACKET_WIDTH),
    .DEPTH(DEPTH)
) dut (
    .clk(clk),
    .rst(rst),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .full(full),
    .rd_en(rd_en),
    .rd_data(rd_data),
    .empty(empty)
);

initial clk = 1'b0;
always #5 clk = ~clk;

integer i;

//fill up and drain FIFO and check if empty/full signals all function correctly
initial begin
    rst = 1;
    wr_en = 0;
    rd_en = 0;
    wr_data = {PACKET_WIDTH{1'b0}};
    
    repeat(3) @(posedge clk);
    rst = 0;
    
    $display("SIMULATION START");
    
    //fill FIFO
    $display("FILLING FIFO");
    for (i = 0; i < DEPTH; i=i+1) begin
        wr_en = 1'b1;
        rd_en = 1'b0;
        wr_data = i;
        
        @(posedge clk);
        
        $display("data=%0d full=%0b empty=%0b", wr_data, full, empty);
    end
    
    wr_en = 1'b0;
    @(posedge clk);
    
    //drain FIFO
    $display("DRAINING FIFO");
    for(i = 0; i < DEPTH; i=i+1) begin
        rd_en = 1'b1;
        @(posedge clk);
        rd_en = 1'b0;
        @(posedge clk);
        $display("data=%0d full=%0b empty=%0b", rd_data, full, empty);
    end
    
    $display("SIMULTANEOUS READ/WRITE");
    //check simultaneous read and write
    for(i = 0; i < DEPTH; i=i+1) begin
        wr_en = 1'b1;
        wr_data = i;
        @(posedge clk);
    end
    
    for(i = 8; i < 2*DEPTH; i=i+1) begin
        wr_en = 1'b1;
        rd_en = 1'b1;
        wr_data = i;
        @(posedge clk);
        rd_en = 1'b0;
        $display("data=%0d full=%0b empty=%0b", wr_data, full, empty);
        @(posedge clk);
        $display("data=%0d full=%0b empty=%0b", rd_data, full, empty); 
    end
    
    //check reset
    rst = 1;
    repeat(3)@(posedge clk);
    $display("full=%0b empty=%0b", full, empty);
    $display("END SIM");
    $finish;
    
end
    
endmodule
