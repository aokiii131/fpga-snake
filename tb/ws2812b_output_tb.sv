`timescale 1ns/1ps
module ws2812b_output_tb;
    logic clk = 0;
    always #10 clk = ~clk;
    logic rst = 1;
    logic [2:0] pixels [0:59];
    wire serial_out;
    wire top_out;
    bit driver_done = 0;
    bit top_done = 0;
    ws2812b_driver driver(.clk(clk), .rst(rst), .pixel_data(pixels), .led_data_out(serial_out));
    top_snake_game top_dut(.clk_50m(clk), .rst_sw(rst), .key(4'b1111), .led_data_out(top_out));

    function automatic logic [23:0] color_word(input int code);
        case (code)
            1: return 24'h003f00;
            2: return 24'h3f0000;
            3: return 24'h00003f;
            4: return 24'h3f3f00;
            default: return 24'h000000;
        endcase
    endfunction

    initial begin
        for (int p = 0; p < 60; p++) pixels[p] = p % 5;
        repeat (20) @(negedge clk);
        rst = 0;
    end

    initial begin : driver_monitor
        time rise_at, fall_at, previous_fall, previous_rise;
        time high_ns, low_ns;
        logic [23:0] received, expected_word;
        bit previous_bit;
        for (int f = 0; f < 2; f++) begin
            for (int p = 0; p < 60; p++) begin
                received = 0;
                expected_word = color_word(f == 0 ? p % 5 : (p + 2) % 5);
                for (int b = 23; b >= 0; b--) begin
                    @(posedge serial_out);
                    rise_at = $time;
                    if (f != 0 || p != 0 || b != 23) begin
                        low_ns = rise_at - previous_fall;
                        if (p == 0 && b == 23) begin
                            if (low_ns != 300020ns + (previous_bit ? 300ns : 800ns))
                                $fatal(1, "Default latch duration incorrect: %0t", low_ns);
                        end else if (rise_at - previous_rise != 1100ns ||
                                     low_ns != (previous_bit ? 300ns : 800ns))
                            $fatal(1, "Inter-bit/pixel gap incorrect: %0t", low_ns);
                    end
                    if (f == 0 && p == 0 && b == 23) begin
                        // Change the live frame while the first snapshot is being serialized.
                        #1;
                        for (int j = 0; j < 60; j++) pixels[j] = (j + 2) % 5;
                    end
                    @(negedge serial_out);
                    fall_at = $time;
                    high_ns = fall_at - rise_at;
                    if (high_ns == 300ns) received[b] = 0;
                    else if (high_ns == 800ns) received[b] = 1;
                    else $fatal(1, "Unexpected HIGH width: %0t", high_ns);
                    previous_bit = received[b];
                    previous_fall = fall_at;
                    previous_rise = rise_at;
                end
                if (received !== expected_word)
                    $fatal(1, "Frame %0d pixel %0d expected %h got %h", f, p, expected_word, received);
            end
        end
        $display("PASS: default 60-pixel driver, 2 complete frames, all colors, snapshot isolation, 300 us latch and continuous bit timing");

        // Reset in the middle of a HIGH pulse, away from a clock edge.
        // The pin must drop immediately and stay LOW throughout reset.
        @(posedge serial_out);
        #37;
        rst = 1;
        #1;
        if (serial_out !== 0 || top_out !== 0)
            $fatal(1, "Reset did not clear the registered outputs");
        repeat (10) begin
            @(negedge clk);
            if (serial_out !== 0 || top_out !== 0)
                $fatal(1, "Output not LOW while reset was held");
        end
        rst = 0;
        // The restarted first pixel begins with a zero bit, with full width.
        @(posedge serial_out);
        rise_at = $time;
        @(negedge serial_out);
        if ($time - rise_at != 300ns)
            $fatal(1, "First HIGH pulse after reset has the wrong width");
        $display("PASS: mid-pulse reset, held-reset LOW, and clean restart");
        driver_done = 1;
    end

    initial begin : top_monitor
        time rise_at, high_ns;
        logic [23:0] received, expected_word;
        for (int p = 0; p < 60; p++) begin
            case (p)
                55, 59: expected_word = color_word(1);
                56: expected_word = color_word(2);
                57: expected_word = color_word(3);
                58: expected_word = color_word(4);
                default: expected_word = 0;
            endcase
            for (int b = 23; b >= 0; b--) begin
                @(posedge top_out);
                rise_at = $time;
                @(negedge top_out);
                high_ns = $time - rise_at;
                if (high_ns == 300ns) received[b] = 0;
                else if (high_ns == 800ns) received[b] = 1;
                else $fatal(1, "Top unexpected HIGH width %0t", high_ns);
            end
            if (received !== expected_word)
                $fatal(1, "Default top pixel %0d expected %h got %h", p, expected_word, received);
        end
        $display("PASS: hardware top defaults, all 60 pixels decoded at output");
        top_done = 1;
    end

    initial begin
        wait (driver_done && top_done);
        $display("WS2812B OUTPUT CHECKS PASSED");
        $finish;
    end
    initial begin
        #5ms;
        $fatal(1, "Review waveform test timed out");
    end
endmodule
