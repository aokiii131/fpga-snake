`timescale 1ns/1ps

module top_snake_game_tb;

    localparam int BULLET_CYCLES_TEST = 20; // Nạp kit: 2_500_000 | Mô phỏng: 20
    localparam int RES_TEST           = 40; // Nạp kit: 15_000    | Mô phỏng: 40
    localparam int LED_COUNT_TEST     = 12; // Nạp kit: 60        | Mô phỏng: 12
    localparam int LENGTH_TEST        = 5;  // Nạp kit: 5         | Mô phỏng: 05

    logic clk;
    logic rst;
    logic [3:0] key;

    logic led_data_out;

    int pass_count = 0;
    int fail_count = 0;

    top_snake_game #(
        .LED_COUNT(LED_COUNT_TEST),
        .DEFAULT_SNAKE_LENGTH(LENGTH_TEST)
    ) DUT (
        .clk_50m(clk),
        .rst_sw(rst),
        .key(key),
        .led_data_out(led_data_out)
    );

    // Dùng defparam can thiệp sâu vào module con (Cách 2)
    defparam DUT.u_tick_generator.BULLET_CYCLES = BULLET_CYCLES_TEST;
    defparam DUT.u_ws2812b_driver.RES           = RES_TEST;

    // Clock generator 50MHz (20ns)
    initial clk = 0;
    always #10 clk = ~clk;


    // =========================================================================
    // SYSTEMVERILOG ASSERTIONS (SVA) - GIÁM SÁT LIÊN TỤC 24/7
    // =========================================================================

 // SVA 1: Button Conditioner - Sườn xuống KEY[0] sinh xung 1 chu kỳ tại btn_event[0]
    property p_btn0_event;
        @(posedge clk) disable iff (rst)
        $fell(key[0]) |-> ##2 (DUT.btn_event[0] == 1'b1) ##1 (DUT.btn_event[0] == 1'b0);
    endproperty
    assert property (p_btn0_event) else $fatal(1, "[SVA FAIL] btn_event[0] sinh sai chu ky!");

    // SVA 2: Tín hiệu led_data_out không bao giờ bị kẹt ở mức 1 quá 45 chu kỳ clock (T1H max = 40 clock)
    property p_no_stuck_high;
        @(posedge clk) led_data_out |-> ##[1:45] (led_data_out == 1'b0);
    endproperty
    assert property (p_no_stuck_high) else $fatal(1, "[SVA FAIL] led_data_out bi treo o muc cao!");

    // =========================================================================
    // TASK PHÂN TÍCH ĐỘ RỘNG XUNG
    // =========================================================================
    // Caller da bat canh len dau tien. ref giu moc nay qua ca bien pixel.
    // Doc lien tuc 24 bit: [23:16] Green, [15:8] Red, [7:0] Blue.
    task automatic read_pixel_24bit(
        ref time t_high_start,
        input bit last_pixel,
        output logic [23:0] pixel_grb,
        output bit timing_ok
    );
        time t_fall, t_next_rise, t_high, t_low, t_total;
        pixel_grb = 'x;
        timing_ok = 1'b1;

        for (int i = 23; i >= 0; i--) begin
            // Canh len da duoc bat: cho canh xuong de do HIGH cua bit nay.
            @(negedge led_data_out);
            t_fall = $time;
            t_high = t_fall - t_high_start;

            // Kiem tra dung timing RTL tai clock 50 MHz.
            if (t_high == 300ns)
                pixel_grb[i] = 1'b0;
            else if (t_high == 800ns)
                pixel_grb[i] = 1'b1;
            else begin
                timing_ok = 1'b0;
                $error("[TIMING FAIL] Bit %0d: HIGH=%0t, expected 300 ns or 800 ns", i, t_high);
            end

            // Bit cuoi frame co LOW noi lien voi LATCH; khong coi do la
            // LOW cua mot bit thong thuong. LATCH duoc kiem tra o ws2812b_output_tb.
            if (!(last_pixel && i == 0)) begin
                @(posedge led_data_out);
                t_next_rise = $time;
                t_low = t_next_rise - t_fall;
                t_total = t_next_rise - t_high_start;

                if (t_total != 1100ns ||
                    (pixel_grb[i] === 1'b0 && t_low != 800ns) ||
                    (pixel_grb[i] === 1'b1 && t_low != 300ns)) begin
                    timing_ok = 1'b0;
                    $error("[TIMING FAIL] Bit %0d: LOW=%0t, total=%0t", i, t_low, t_total);
                end

                // Canh nay vua ket thuc LOW, vua bat dau HIGH cua bit sau.
                // Luu lai, KHONG cho them mot posedge o dau vong lap.
                t_high_start = t_next_rise;
            end
        end
    endtask

    // Bao ve tat ca cac lenh cho canh: mat tin hieu se FAIL, khong treo TB.
    initial begin
        #2ms;
        $fatal(1, "[TIMEOUT] Top TB khong hoan tat trong 2 ms.");
    end

    // =========================================================================
    // KỊCH BẢN 6 TEST CASES (TC1 - TC6)
    // =========================================================================
    initial begin
        logic [23:0] captured_pixel;
        logic [23:0] expected_pixel;
        time bit_start;
        bit pixel_timing_ok;
        bit frame_ok;
        bit tc4_ok;

        tc4_ok = 1;
        rst = 0;
        key = 4'b1111; // Active-low: mac dinh tha nut
        repeat(5) @(negedge clk);

        // ---------------------------------------------------------------------
        // TC1: Reset toàn hệ thống
        // ---------------------------------------------------------------------
        $display("\n--- TC1: RESET TOAN HE THONG ---");
        rst = 1;
        repeat(5) @(negedge clk);
        rst = 0;
        #1;

        if (DUT.u_game_engine.current_state == DUT.u_game_engine.IDLE &&
            DUT.u_ws2812b_driver.current_state == DUT.u_ws2812b_driver.LOAD) begin
            $display("[TC1 PASS] Tat ca cac module deu reset thanh cong ve IDLE/LOAD.");
            pass_count++;
        end else begin
            $error("[TC1 FAIL] Reset khong dua cac module ve trang thai ban dau!");
            fail_count++;
        end

        // ---------------------------------------------------------------------
        // TC2: Đưa toàn hệ thống vào trạng thái PlAYING
        // ---------------------------------------------------------------------
        $display("\n--- TC2: IDLE TO PLAYING ---");
        @(negedge clk);
        key[2] = 1'b0; // Nhan KEY2
        repeat(2) @(negedge clk);
        key[2] = 1'b1; // Nha KEY2

        repeat(5) @(negedge clk);
        #1;
        if (DUT.u_game_engine.current_state == DUT.u_game_engine.PLAYING) begin
            $display("[TC2 PASS] He thong dang sang trang thai PLAYING.");
            pass_count++;
        end else begin
            $error("[TC2 FAIL] Nhan nut bat ki khong dua game ve state PLAYING!");
            fail_count++;
        end
        // ---------------------------------------------------------------------
        // TC3: Button KEY0 xuyên suốt hệ thống (Tạo đạn RED)
        // ---------------------------------------------------------------------
        $display("\n--- TC3: BUTTON KEY0 XUYEN SUOT HE THONG ---");
        @(negedge clk);
        key[0] = 1'b0; // Nhan KEY0
        repeat(2) @(negedge clk);
        key[0] = 1'b1; // Nha KEY0

        repeat(5) @(negedge clk);
        #1;

        if (DUT.u_game_engine.bullet_active == 1'b1 &&
            DUT.u_game_engine.bullet_color == DUT.u_game_engine.RED &&
            DUT.pixel_data[0] == DUT.u_game_engine.RED) begin
            $display("[TC3 PASS] KEY0 -> btn_event[0] -> Game Engine fire Bullet RED -> pixel_data[0] OK.");
            pass_count++;
        end else begin
            $error("[TC3 FAIL] KEY0 khong kich hoat duoc dan RED xuyen he thong!");
            fail_count++;
        end

        // ---------------------------------------------------------------------
        // TC4: Wiring các nút màu khác (KEY0, KEY1, KEY3)
        // ---------------------------------------------------------------------
        repeat(5) @(negedge clk);
        $display("\n--- TC4: KIEM TRA WIRING CAC NUT CON LAI ---");
        // Kiem tra duong truyen tu pin ngoai vao btn_event
        @(negedge clk); key[1] = 0; @(negedge clk); key[1] = 1;
        repeat(1) @(negedge clk);
        if (DUT.btn_event == 4'b0010) $display("[TC4] KEY1 wiring to GREEN event: OK");
        else tc4_ok = 0;

        @(negedge clk); key[0] = 0; @(negedge clk); key[0] = 1;
        repeat(1) @(negedge clk);
        if (DUT.btn_event == 4'b0001) $display("[TC4] KEY0 wiring to RED event: OK");
        else tc4_ok = 0;

        @(negedge clk); key[3] = 0; @(negedge clk); key[3] = 1;
        repeat(1) @(negedge clk);
        if (DUT.btn_event == 4'b1000) $display("[TC4] KEY3 wiring to YELLOW event: OK");
        else tc4_ok = 0;

        #1;
        if (tc4_ok == 1) begin
            $display("[TC4 PASS] KEY0/1/3 wiring hoan toan chinh xac.");
            pass_count++;
        end else begin
            $error("[TC4 FAIL] Wiring cac nut con lai bi loi!");
            fail_count++;
        end

        // ---------------------------------------------------------------------
        // TC5: Tick thật sự tới Game Engine
        // ---------------------------------------------------------------------
        $display("\n--- TC5: TICK GENERATOR TO GAME ENGINE ---");
        // Cho qua 1 chu ky BULLET_CYCLES_TEST de xem dan co nhay vi tri
        repeat(BULLET_CYCLES_TEST + 5) @(negedge clk);
        #1;

        if (DUT.u_game_engine.bullet_position > 0) begin
            $display("[TC5 PASS] tick_generator da ban nhip thanh cong, dan di chuyen toi vi tri %0d.", 
                     DUT.u_game_engine.bullet_position);
            pass_count++;
        end else begin
            $error("[TC5 FAIL] Dan khong di chuyen, tick khong vao duoc Game Engine!");
            fail_count++;
        end

        // ---------------------------------------------------------------------
        // TC6: End-to-end output (Đo độ rộng xung giải mã bit tại led_data_out)
        // ---------------------------------------------------------------------
        $display("\n--- TC6: END-TO-END PULSE CHECK TAI LED_DATA_OUT ---");
        $display("Doc frame khoi tao: OFF, sau do 5 dot RED/GREEN/BLUE/YELLOW/RED.");

        // Reset de biet chinh xac frame mong doi. Khong bam nut, game giu IDLE.
        // Canh len dau tien sau reset chinh la bit 23 cua pixel 0.
        @(negedge clk);
        key = 4'b1111;
        rst = 1;
        repeat(5) @(negedge clk);
        rst = 0;
        @(posedge led_data_out);
        bit_start = $time;
        frame_ok = 1'b1;

        for (int p = 0; p < LED_COUNT_TEST; p++) begin
            // Expected lay tu mau ran khoi tao, khong lay tu decoder cua DUT.
            case (p - (LED_COUNT_TEST - LENGTH_TEST))
                0, 4: expected_pixel = 24'h00_3F_00;
                1:    expected_pixel = 24'h3F_00_00;
                2:    expected_pixel = 24'h00_00_3F;
                3:    expected_pixel = 24'h3F_3F_00;
                default: expected_pixel = 24'h00_00_00;
            endcase

            read_pixel_24bit(bit_start, p == LED_COUNT_TEST - 1,
                             captured_pixel, pixel_timing_ok);
            $display("[TC6] Pixel %0d: expected=%06h captured=%06h", p, expected_pixel, captured_pixel);
            if (captured_pixel !== expected_pixel || !pixel_timing_ok) begin
                frame_ok = 1'b0;
                $error("[TC6 FAIL] Pixel %0d sai du lieu hoac timing.", p);
            end
        end

        if (frame_ok) begin
            $display("[TC6 PASS] Ca frame dung GRB/MSB-first va timing cac bit.");
            pass_count++;
        end else begin
            fail_count++;
        end

        // Tong ket
        repeat(50) @(negedge clk);
        $display("\n==============================================");
        $display("TOP-LEVEL VERIFICATION COMPLETE: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("==============================================");
        if (fail_count != 0)
            $fatal(1, "Top-level verification failed.");
        $finish;
    end

endmodule
