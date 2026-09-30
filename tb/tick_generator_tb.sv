`timescale 1ns/1ps

module tick_generator_tb;
    logic clk;
    logic rst;
    logic snake_tick;
    logic bullet_tick;

    localparam int TB_BULLET_CYCLES = 5;
    localparam int TB_SNAKE_TICKS   = 5;

    tick_generator #(
        .BULLET_CYCLES(TB_BULLET_CYCLES),
        .SNAKE_TICKS_COUNT(TB_SNAKE_TICKS)
    ) DUT(
        .clk(clk),
        .rst(rst),
        .snake_tick(snake_tick),
        .bullet_tick(bullet_tick)
    );

    initial clk = 0;
    always #10 clk = ~clk;          // Clock = 50 MHz -> T = 20ns

    initial begin
        #10us;
        $fatal(1, "[TIMEOUT] tick_generator_tb exceeded 10 us");
    end

    initial begin
        rst = 1;
        repeat(2) @(negedge clk);
        rst = 0;
        #1;
        if (bullet_tick !== 1'b0 || snake_tick !== 1'b0)
            $fatal(1, "TC0 FAILED: ticks must be low after reset");

        repeat(TB_BULLET_CYCLES) @(negedge clk);
        #1;
        if (bullet_tick !== 1)
            $fatal(1, "TC1 FAILED: expected bullet_tick to be high, got %b", bullet_tick);

        repeat(TB_SNAKE_TICKS - 1) begin
            repeat(TB_BULLET_CYCLES) @(negedge clk); 
        end
        if (snake_tick !== 1)
            $fatal(1, "TC2 FAILED: expected snake_tick to be high, got %b", snake_tick);


        @(negedge clk);
        if (bullet_tick !== 0)
            $fatal(1, "TC3 FAILED: expected bullet_tick to be low, got %b", bullet_tick);
        
        if (snake_tick !== 0)
            $fatal(1, "TC4 FAILED: expected snake_tick to be low, got %b", snake_tick);
        $display("TICK GENERATOR CHECKS PASSED");
        $finish;
    end
endmodule
