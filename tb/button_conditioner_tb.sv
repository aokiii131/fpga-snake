`timescale 1ns/1ps
module button_conditioner_tb;
    logic clk;
    logic rst;
    logic [3:0] key;
    logic [3:0] btn_event;

    logic [3:0] expected_btn_event;
    int event_count;
    button_conditioner DUT(
        .btn_event(btn_event),
        .clk(clk),
        .key(key),
        .rst(rst)
    );

    initial clk = 0;
    always #10 clk = ~clk;          // Clock = 50 MHz -> T = 20ns

    initial begin
        key = 4'b1111;
        
        // TC1: Reset
        // Reset module and verify all outputs/state return to idle.
        rst = 1;
        repeat(2) @(negedge clk);
        rst = 0;

        expected_btn_event = 4'b0000;
        @(negedge clk);
        if (btn_event !== expected_btn_event)
            $error("TC1 FAILED: expected no button event, got %b", btn_event);

        @(posedge clk);
        // TC2: Single Press
        // Press one button and verify exactly one press event is generated.
        
        key = 4'b1110;
        repeat(2) @(negedge clk);
        key = 4'b1111;

        expected_btn_event = 4'b0001;
        @(negedge clk);
        if (btn_event !== expected_btn_event)
            $error("TC2 FAILED: expected 1 button event, got %b", btn_event);


        repeat(2) @(negedge clk);
        // TC3: Button Hold & Release
        // Hold one button for multiple clock cycles and verify no repeated events occur.
        event_count = 0;

        @(negedge clk);
        key = 4'b1110;

        // Observe the button while it is held
        repeat (5) begin
            @(posedge clk);
            #1;

            if (btn_event === 4'b0001)
                event_count++;
        end

        @(negedge clk);
        key = 4'b1111;

        // Exactly one event must have occurred
        if (event_count != 1)
            $error("TC3 FAILED: expected exactly 01 event, got %0d", event_count);

        // Release must not generate another event
        @(posedge clk);
        #1;
        if (btn_event !== 4'b0000)
            $error("TC3 FAILED: release generated an unexpected event");
        // TC 4: 
        repeat(5) @(negedge clk);
    $finish;
    end
endmodule