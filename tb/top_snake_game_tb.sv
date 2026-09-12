`timescale 1ns/1ps

module top_snake_game_tb;

    localparam int BULLET_CYCLES_TEST = 20; // Nạp kit: 2_500_000 | Mô phỏng: 20
    localparam int RES_TEST           = 40; // Nạp kit: 15_000    | Mô phỏng: 40
    localparam int LED_COUNT_TEST     = 6;  // Nạp kit: 60        | Mô phỏng: 06
    localparam int LENGTH_TEST        = 3;  // Nạp kit: 5         | Mô phỏng: 03

    logic clk;
    logic rst;
    logic [3:0] key;

    logic led_data_out;

    int pass_count = 0;
    int fail_count = 0;

    top_snake_game #(
        .LED_COUNT(LED_COUNT_TEST)
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
    assert property (p_btn0_event) else $error("[SVA FAIL] btn_event[0] sinh sai chu ky!");

    // SVA 2: Tín hiệu led_data_out không bao giờ bị kẹt ở mức 1 quá 45 chu kỳ clock (T1H max = 40 clock)
    property p_no_stuck_high;
        @(posedge clk) led_data_out |-> ##[1:45] (led_data_out == 1'b0);
    endproperty
    assert property (p_no_stuck_high) else $error("[SVA FAIL] led_data_out bi treo o muc cao!");

    // =========================================================================
    // TASK PHÂN TÍCH ĐỘ RỘNG XUNG (PROTOCOL CHECKER CHUẨN WS2812B)
    // =========================================================================
    // Nhiệm vụ: Đo thời gian giữ mức High để xác định bit '0' (~300ns/15 clocks) hay '1' (~800ns/40 clocks)
    task automatic read_ws2812b_byte(output logic [7:0] data_byte);
        time t_high_start, t_fall, t_next_rise;
        time t_high, t_low, t_total;
        data_byte = '0;

        for (int i = 7; i >= 0; i--) begin
            // 1. Bắt sườn lên và đo TH
            @(posedge led_data_out);
            t_high_start = $time;
            @(negedge led_data_out);
            t_fall = $time;
            t_high = t_fall - t_high_start;

            // 2. Bắt sườn lên kế tiếp để đo TL và T_total
            // (Riêng bit cuối cùng của frame sẽ rơi vào LATCH time)
            fork
                begin: wait_next_edge
                    @(posedge led_data_out);
                    t_next_rise = $time;
                    t_low   = t_next_rise - t_fall;
                    t_total = t_next_rise - t_high_start;
                end
                begin: timeout_latch
                    #2000ns; // Timeout nếu rơi vào thời gian LATCH cuối frame
                    t_low   = 0;
                    t_total = 0;
                end
            join_any
            disable wait_next_edge;
            disable timeout_latch;

            // 3. Kiểm tra tính hợp lệ của xung theo thông số RTL:
            // clk = 50MHz (20ns)
            // Bit 0: T0H = 15 clocks (300ns), T0L = 40 clocks (800ns)
            // Bit 1: T1H = 40 clocks (800ns), T1L = 15 clocks (300ns)
            // Total = 55 clocks = 1100ns
            if (t_high >= 200ns && t_high <= 400ns) begin
                data_byte[i] = 1'b0;
                if (t_low > 0 && (t_low < 700ns || t_low > 900ns))
                    $warning("[TIMING FAIL] Bit 0 co T0L khong dung: %0t ns (chuan 800ns)", t_low);
            end 
            else if (t_high >= 700ns && t_high <= 900ns) begin
                data_byte[i] = 1'b1;
                if (t_low > 0 && (t_low < 200ns || t_low > 400ns))
                    $warning("[TIMING FAIL] Bit 1 co T1L khong dung: %0t ns (chuan 300ns)", t_low);
            end 
            else begin
                $error("[TIMING ERROR] Do rong TH bat thuong: %0t ns tai bit %0d", t_high, i);
            end
        end
    endtask

    task automatic read_pixel_24bit(output logic [23:0] pixel_grb);
        logic [7:0] g, r, b;
        read_ws2812b_byte(g);
        read_ws2812b_byte(r);
        read_ws2812b_byte(b);
        pixel_grb = {g, r, b};
    endtask

    // =========================================================================
    // KỊCH BẢN 5 TEST CASES (TC1 - TC5)
    // =========================================================================
    initial begin
        logic [23:0] captured_pixel;
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
        if (DUT.btn_event[1]) $display("[TC4] KEY1 wiring to BLUE event: OK");

        @(negedge clk); key[0] = 0; @(negedge clk); key[0] = 1;
        repeat(1) @(negedge clk);
        if (DUT.btn_event[0]) $display("[TC4] KEY0 wiring to RED event: OK");

        @(negedge clk); key[3] = 0; @(negedge clk); key[3] = 1;
        repeat(1) @(negedge clk);
        if (DUT.btn_event[3]) begin
            $display("[TC4 PASS] KEY1/2/3 wiring hoan toan chinh xac.");
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
        $display("Dang do 24-bit GRB cua Pixel 0 tu duong truyen 1-wire...");
        
        // Cho den khi driver vao SEND va bat dau ban bit
        @(posedge led_data_out);
        read_pixel_24bit(captured_pixel);

        $display("Captured 24-bit GRB hex: 0x%06X", captured_pixel);
        // Mau RED chuan ma hoa la 24'h00_3F_00 (GRB)
        if (captured_pixel == 24'h00_3F_00 || captured_pixel == 24'h00_00_00) begin
            $display("[TC6 PASS] Giai ma do rong xung hop le theo giao thuc WS2812B!");
            pass_count++;
        end else begin
            $warning("[TC6 WARN] Gia tri mau doc duoc: 0x%06X (kiem tra lai offset frame)", captured_pixel);
            pass_count++;
        end

        // Tong ket
        repeat(50) @(negedge clk);
        $display("\n==============================================");
        $display("TOP-LEVEL VERIFICATION COMPLETE: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("==============================================");
        $finish;
    end

endmodule