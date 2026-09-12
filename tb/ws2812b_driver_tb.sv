`timescale 1ns/1ps
module ws2812b_driver_tb;
    
    localparam int TEST_LEDS = 3;
    localparam int TEST_RES  = 50;
    
    logic       clk;
    logic       rst;
    logic [2:0] pixel_data [0:TEST_LEDS-1];
    logic       led_data_out;

    ws2812b_driver #(
        .LED_COUNT(TEST_LEDS),
        .RES(TEST_RES)
    ) 
    DUT(
        .clk(clk),
        .rst(rst),
        .pixel_data(pixel_data),
        .led_data_out(led_data_out)
    );

    task automatic reset_behavior();
        @ (negedge clk);
        $display("----------------------------------------------");
        $display("TEST CASE 1: RESET BEHAVIOR");
        rst = 1;
        repeat(2) @(negedge clk);
        rst = 0;
        #1;
        $display("Time = %0t ns | State = %s | pixel_counter = %0d | bit_counter = %0d | timing_counter = %b",
             $time, 
             DUT.current_state.name(), // .name() để in tên enum (LOAD, SEND, LATCH)
             DUT.pixel_counter, 
             DUT.bit_counter, 
             DUT.timing_counter);
    endtask

    task automatic capturing_txframe();
        @ (negedge clk);
        $display("----------------------------------------------");
        $display("TEST CASE 2: TX FRAME CAPTURING");
        rst = 1;
        @(negedge clk);
        rst = 0;
        #1;
        for(int i = TEST_LEDS-1; i >= 0; i--) begin
            pixel_data[i] = $urandom_range(4,0);
        end

        @(negedge clk); #1;
        $display("Time = %0t ns | State = %s",
             $time, 
             DUT.current_state.name(), // .name() để in tên enum (LOAD, SEND, LATCH)
                );

        for(int i = 0; i <= TEST_LEDS - 1; i++) begin
            $display("pixel_data[%0d] = %03b | tx_frame[%0d] = %03b", i, pixel_data[i], i, DUT.tx_frame[i]);      
        end

    endtask
    

    task automatic wait_sending();
        wait (DUT.current_state == DUT.LATCH);
        $display("[%0t ns] TEST CASE 3: SENDING FRAME COMPLETED! Entered LATCH state.", $time);
    endtask

    task automatic wait_latching();
        wait (DUT.current_state == DUT.LOAD);
        $display("[%0t ns] TEST CASE 4: LATCHING FRAME COMPLETED! Entered LOAD state.", $time);
    endtask

    task automatic frame_snapshot();
        @ (negedge clk);
        $display("----------------------------------------------");
        $display("TEST CASE 5 : SNAPSHOT ISOLATION");
        rst = 1;
        @(negedge clk);
        rst = 0;
        #1;
        for(int i = TEST_LEDS-1; i >= 0; i--) begin
            pixel_data[i] = $urandom_range(4,0);
        end
        $display("Before pixel_data change:");
        for(int i = 0; i < TEST_LEDS; i++)
            $display("pixel_data[%0d] = %03b | tx_frame[%0d] = %03b",
                    i, pixel_data[i], i, DUT.tx_frame[i]);

        pixel_data[0] = 3'b010;
        pixel_data[1] = 3'b011;
        pixel_data[2] = 3'b000;

        #1;

        $display("After pixel_data change:");
        for(int i = 0; i < TEST_LEDS; i++)
            $display("pixel_data[%0d] = %03b | tx_frame[%0d] = %03b",
                    i, pixel_data[i], i, DUT.tx_frame[i]);
    endtask

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        int i;
        // Apply reset and initial stimulus
        for(i = TEST_LEDS-1; i >= 0; i--) begin
            pixel_data[i] = 0;
        end
        
        //reset_behavior();
        //capturing_txframe();
        //wait_sending();
        //wait_latching();
        frame_snapshot();
        
        repeat(10) @(negedge clk);
        $finish;
    end
endmodule