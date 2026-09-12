`timescale 1ns/1ps

module game_engine_tb;

    // 1. Tham số & Tín hiệu kết nối DUT
    localparam int LENGTH_TEST    = 5;
    localparam int LED_TEST       = 60;

    logic       rst;
    logic       clk;
    logic       snake_tick;
    logic       bullet_tick;
    logic [3:0] btn_event;

    logic [2:0] pixel_data [0:59];

    // 2. Kết nối DUT
    game_engine #(
        .DEFAULT_LENGTH(LENGTH_TEST),
        .LED_COUNT (LED_TEST)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .snake_tick(snake_tick),
        .bullet_tick(bullet_tick),
        .btn_event(btn_event),
        .pixel_data(pixel_data)
    );
    // 3. Biến quản lý Self-Checking
    int   error_count;          // Biến đếm lỗi
    int   test_count;           // Biến đếm tổng số bài test đã chạy

    // Helper task để tự động kiểm tra và in kết quả
    task automatic check(
        input string tc_name,
        input logic  condition,     // Biểu thức điều kiện cần kiểm tra
        input string  fail_msg       // Fail message: thông báo lỗi khi condition không đạt
    );
        test_count++;
        if(!condition) begin
            $error("Time: %8t | [FAIL] %s: %s",$time, tc_name, fail_msg);
            error_count++;
        end
        else begin
            $display("Time: %8t | [PASS] %s", $time, tc_name);
        end

    endtask

    // Clock generator 50MHz (Chu kỳ 20ns)
    initial clk = 0;
    always #10 clk = ~clk;

    // =========================================================================
    // CÁC TEST CASES
    // =========================================================================

    task automatic tc1_reset_initial_state();
        rst = 1;
        repeat(2) @(negedge clk);
        rst = 0;
        #1;

        // 1. Kiểm tra trạng thái và các thông số rắn
        check("TC1_STATE", 
              (DUT.current_state == DUT.IDLE), 
              "FSM khong ve IDLE sau RESET");
        
        check("TC1_LENGTH", 
              (DUT.snake_length == LENGTH_TEST), 
              "Do dai ran khong duoc khoi tao dung");
        
        check("TC1_HEAD_POS", 
              (DUT.head_position == LED_TEST - LENGTH_TEST), 
              "Vi tri dau ran khoi tao sai");

        // 2. Kiểm tra trạng thái đạn
        check("TC1_BULLET_ACTIVE", 
              (DUT.bullet_active == 1'b0), 
              "bullet_active khong reset ve 0");

        // 3. Kiểm tra khởi tạo màu rắn (LED 55 tới 59)
        check("TC1_SNAKE_COLOR", 
          (DUT.snake_array[55] == DUT.RED   && 
           DUT.snake_array[56] == DUT.GREEN && 
           DUT.snake_array[57] == DUT.BLUE  && 
           DUT.snake_array[58] == DUT.YELLOW&& 
           DUT.snake_array[59] == DUT.RED), 
          "Mau sac ran khoi tao khong dung");

          $display("TC1: Reset & Initial State checks completed.");
          $display("--------------------------------------------------");
    endtask

    task automatic tc2_idle_to_playing();
    repeat(2) @(negedge clk);
    btn_event = 4'b1000; 
    @(negedge clk);
    btn_event = 4'b0000;    #1;

    check("TC2_STATE",
          DUT.current_state == DUT.PLAYING,
          "FSM khong chuyen sang PLAYING sau khi nhan btn");
    
    $display("TC2: IDLE to PLAYING transition check completed.");
    $display("--------------------------------------------------");
    endtask

    task automatic tc3_snake_movement();
    @(negedge clk);
    snake_tick = 1; @(negedge clk); snake_tick = 0; #1;

    check("TC3_HEAD_POS",
          DUT.head_position == $past(DUT.head_position, 1, , @(posedge clk)) - 1,
          "Dau Ran khong di chuyen khi PLAYING");
    
    check("TC3_SNAKE_MOVEMENT", 
          (DUT.snake_array[54] == DUT.RED   && 
           DUT.snake_array[55] == DUT.GREEN && 
           DUT.snake_array[56] == DUT.BLUE  && 
           DUT.snake_array[57] == DUT.YELLOW&& 
           DUT.snake_array[58] == DUT.RED   &&
           DUT.snake_array[59] == DUT.OFF), 
          "Toan bo ran khong di chuyen dung khi PLAYING");

    $display("TC3: Snake Movement check completed.");
    $display("--------------------------------------------------");
    endtask

    task automatic tc4_bullet_fire();
        @(negedge clk);
        btn_event = 4'b0001;
        repeat(1)@(negedge clk);
        btn_event = 4'b0000;
        #1;
        // Checking Bullet Generating
        check("TC4_BULLET_FIRE",
              DUT.bullet_position == 0       &&
              DUT.bullet_color    == DUT.RED && 
              DUT.bullet_active   == 1,
              "Bullet fire that bai.");

        // Check Bullet Rendering
        check("TC4_BULLET_RENDER", 
              pixel_data[0] == DUT.RED &&
              pixel_data[1] == DUT.OFF,
              "Dan khong duoc hien thi len LED.");

        $display("TC4: Bullet Generating check completed.");
        $display("--------------------------------------------------");
    endtask

    task automatic tc5_bullet_movement();
        @(negedge clk);
        bullet_tick = 1;
        repeat(1)@(negedge clk);
        bullet_tick = 0;
        #1;
        // Checking Bullet Generating
        check("TC5_BULLET_MOVEMENT",
              DUT.bullet_position == $past(DUT.bullet_position, 1, , @(posedge clk)) + 1  &&
              DUT.bullet_color    == DUT.RED && 
              DUT.bullet_active   == 1,
              "Bullet khong dich chuyen.");

        // Check Bullet Rendering
        check("TC5_BULLET_RENDER", 
              pixel_data[1] == DUT.RED &&
              pixel_data[0] == DUT.OFF, 
              "Bullet khong duoc dich chuyen tren LED.");

        $display("TC5: Bullet Movement check completed.");
        $display("--------------------------------------------------");
    endtask


    task automatic tc6_bullet_hit_snake();
        // Setup: Fire a bullet and move it to hit the snake
        while (DUT.bullet_active &&
               DUT.bullet_position < DUT.head_position - 1) begin
            bullet_tick = 1;
            @(negedge clk);
            bullet_tick = 0;
            @(negedge clk);
        end

        // Stimulus
        @(negedge clk);
        bullet_tick = 1;
        repeat(1)@(negedge clk);
        bullet_tick = 0;
        #1;

        // Check Collision
        check("TC6_COLLISION",
              DUT.bullet_active == 0 &&
              DUT.bullet_color == DUT.OFF,
              "Bullet khong mat sau khi va cham voi ran.");

        // Check Same-color hit
        $display("TC6: Bullet Hit Snake - Checking length and head position update:");
        check("TC6_SNAKE_LENGTH_UPDATE",
              DUT.snake_length == $past(DUT.snake_length, 1, , @(posedge clk)) - 1,
              "Ran khong tu update length.");

        check("TC6_SNAKE_HEAD_UPDATE",
              DUT.head_position == $past(DUT.head_position, 1, , @(posedge clk)) + 1,
              "Ran khong tu update head position.");
        // Check Rendering
        check("TC6_RENDERING_LED",
                (pixel_data[53] == DUT.OFF   &&
                 pixel_data[54] == DUT.OFF   && 
                 pixel_data[55] == DUT.GREEN && 
                 pixel_data[56] == DUT.BLUE  && 
                 pixel_data[57] == DUT.YELLOW&& 
                 pixel_data[58] == DUT.RED   &&
                 pixel_data[59] == DUT.OFF),
                "LED khong duoc update dung sau khi va cham.");

        $display("TC6: Bullet Hit Snake check completed.");
        $display("--------------------------------------------------");
    endtask

    task automatic tc7_different_color_hit();
        // Setup
        @(negedge clk);
        btn_event = 4'b1000;
        repeat(1)@(negedge clk);
        btn_event = 4'b0000;
        #1;

        while (DUT.bullet_active &&
               DUT.bullet_position < DUT.head_position - 1) begin
            bullet_tick = 1;
            @(negedge clk);
            bullet_tick = 0;
            @(negedge clk);
        end

        // Stimulus
        @(negedge clk);
        bullet_tick = 1;
        repeat(1)@(negedge clk);
        bullet_tick = 0;
        #1;

        // Check Collision
        check("TC7_COLLISION",
              DUT.bullet_active == 0 &&
              DUT.bullet_color == DUT.OFF,
              "Bullet khong mat sau khi va cham voi ran.");

        check("TC7_STATE_STILL_PLAYING",
            (DUT.current_state == DUT.PLAYING),
            "Game bi vang khoi PLAYING khi ban lech mau.");

        // Check Differrent-color hit
        check("TC7_SNAKE_LENGTH_UPDATE",
              DUT.snake_length == $past(DUT.snake_length, 1, , @(posedge clk)),
              "Ran tu update length du ban bullet khac color.");

        check("TC7_SNAKE_HEAD_UPDATE",
              DUT.head_position == $past(DUT.head_position, 1, , @(posedge clk)),
              "Ran tu update head position du ban bullet khac color.");
        // Check Rendering
        check("TC7_RENDERING_LED",
                (pixel_data[53] == DUT.OFF   &&
                 pixel_data[54] == DUT.OFF   && 
                 pixel_data[55] == DUT.GREEN && 
                 pixel_data[56] == DUT.BLUE  && 
                 pixel_data[57] == DUT.YELLOW&& 
                 pixel_data[58] == DUT.RED   &&
                 pixel_data[59] == DUT.OFF),
                "LED khong duoc update dung sau khi va cham.");

        $display("TC7: Differrent-color Bullet hit.");
        $display("--------------------------------------------------");

    endtask

    function automatic logic [3:0] get_btn_from_color (input [2:0] color);
        case(color)
            DUT.RED: return 4'b0001;
            DUT.GREEN:  return 4'b0010;
            DUT.BLUE:   return 4'b0100;
            DUT.YELLOW: return 4'b1000;
            default:    return 4'b0000; 
        endcase
    endfunction


    task automatic tc8_win_state(); // Simulate snake eating all bullets and reaching length 0
        $display("TC8: Starting auto-elimination to WIN state...");
        
            // Tạo đạn (tự động) khớp với đầu rắn
            while (DUT.snake_length > 0) begin
                  @(negedge clk);
                  btn_event = get_btn_from_color(DUT.snake_array[DUT.head_position]);
                  @(negedge clk);
                  btn_event = 4'b0000;
                  #1;
            
            // Đẩy đạn tới ngay trước đầu rắn
            while(DUT.bullet_active && (DUT.bullet_position < DUT.head_position - 1)) begin
                  @(negedge clk);
                  bullet_tick = 1;
                  @(negedge clk);
                  bullet_tick = 0;
                  @(negedge clk);
            end

            // Kích thích va chạm
            @(negedge clk);
            bullet_tick = 1;
            @(negedge clk);
            bullet_tick = 0;
            #1;
      end
      @(negedge clk);
      // Kiểm tra điều kiện WIN
        check("TC8_SNAKE_LENGTH_ZERO",
              DUT.snake_length == 0,
              "Do dai ran chua ve 0.");

        check("TC8_FSM_WIN", 
              DUT.current_state == DUT.WIN,
              "FSM khong chuyen sang trang thai WIN");

      $display("TC8: Win State check completed.");
      $display("--------------------------------------------------");

    endtask

    task automatic tc9_lose_state();
      // 1. Reset game moi sau khi da WIN o TC8
        rst = 1;
        repeat(2) @(negedge clk);
        rst = 0;
        @(negedge clk);

        // Chuyen tu IDLE sang PLAYING
        btn_event = 4'b1000;
        @(negedge clk);
        btn_event = 4'b0000;
        @(negedge clk);

      $display("TC9: Starting snake movement to LOSE state...");
      // Đẩy rắn về LED số 1
      while(DUT.head_position > 1) begin
            @(negedge clk);
            snake_tick = 1;
            @(negedge clk);
            snake_tick = 0;
      end

      // Kích đi vào LED 0
      repeat(2) @(negedge clk);
      snake_tick = 1;
      @(negedge clk);
      snake_tick = 0;
      
      @(negedge clk);
      // Kiểm tra điều kiện LOSE
        check("TC9_HEAD_POSITION_ZERO",
              DUT.head_position == 0,
              "Dau ran khong cham LED 0.");

        check("TC9_FSM_LOSE", 
              DUT.current_state == DUT.LOSE,
              "FSM khong chuyen sang trang thai LOSE");

      $display("TC9: Lose State check completed.");
      $display("--------------------------------------------------");
    endtask

     task automatic tc10_restart_from_lose();
      @(negedge clk);
      rst = 1;
      repeat(2) @(negedge clk);
      rst = 0;
      #1;

      check("TC10_STATE_RETURN_IDLE", 
            DUT.current_state == DUT.IDLE,
            "FSM khong ve IDLE State sau khi reset");

      check("TC10_SNAKE_RESET_DEFAULT",
            DUT.snake_length  == LENGTH_TEST &&
            DUT.head_position == LED_TEST - LENGTH_TEST,
            "Sanke khong reset ve dung trang thai ban dau");

      
      check("TC10_BULLET_CLEARED", 
            DUT.bullet_active == 0,
            "Bullet khong duoc xoa");
      $display("TC10 Restart from LOSE State check completed.");
      $display("--------------------------------------------------");

    endtask

    task automatic tc11_simultaneous_ticks();
      
      // Chuyen tu IDLE sang PLAYING
      btn_event = 4'b1000;
      @(negedge clk);
      btn_event = 4'b0000;
      @(negedge clk);

      // Bullet fire (RED)
      btn_event = 4'b0001;
      @(negedge clk);
      btn_event = 4'b0000;
      @(negedge clk);

      // TC11_SIMULTANEOUS_MOVEMENT
      bullet_tick = 1; snake_tick  = 1;
      @(negedge clk);
      bullet_tick = 0; snake_tick  = 0;
      #1;
      check("TC11_BULLET_CHECKING",
              DUT.bullet_position == $past(DUT.bullet_position, 1, , @(posedge clk)) + 1  &&
              DUT.bullet_color    == DUT.RED && 
              DUT.bullet_active   == 1,
              "Bullet khong dich chuyen khi STIMULTANEOUS.");

      check("TC11_SNAKE_CHECKING", 
          (DUT.snake_array[54] == DUT.RED   && 
           DUT.snake_array[55] == DUT.GREEN && 
           DUT.snake_array[56] == DUT.BLUE  && 
           DUT.snake_array[57] == DUT.YELLOW&& 
           DUT.snake_array[58] == DUT.RED   &&
           DUT.snake_array[59] == DUT.OFF), 
          "Toan bo ran khong di chuyen dung khi STIMULTANEOUS");

      check("TC11_RENDER_BULLET_1", 
              pixel_data[0] == DUT.OFF &&
              pixel_data[1] == DUT.RED,
              "Dan khong duoc hien thi dung len LED.");
      
      check("TC11_RENDER_SNAKE", 
           (pixel_data[54] == DUT.RED   && 
            pixel_data[55] == DUT.GREEN && 
            pixel_data[56] == DUT.BLUE  && 
            pixel_data[57] == DUT.YELLOW&& 
            pixel_data[58] == DUT.RED   &&
            pixel_data[59] == DUT.OFF), 
            "Dan khong duoc hien thi dung len LED.");

      // TC11_HEAD_COLLISION_SAME_CYCLE
      while(DUT.bullet_position < DUT.head_position - 1) begin
            bullet_tick = 1;
            @(negedge clk);
            bullet_tick = 0;
            @(negedge clk);
      end
      
      // Kich thich va cham
      bullet_tick = 1; snake_tick  = 1;
      @(negedge clk);
      bullet_tick = 0; snake_tick  = 0;
      #1;

      // Check Collision
        check("TC11_COLLISION",
              DUT.bullet_active == 0 &&
              DUT.bullet_color == DUT.OFF,
              "Bullet khong mat sau khi va cham voi ran.");

        // Check Same-color hit
        $display("TC11: Bullet Hit Snake - Checking length and head position update:");
        check("TC11_SNAKE_LENGTH_UPDATE",
              DUT.snake_length == $past(DUT.snake_length, 1, , @(posedge clk)) - 1,
              "Ran khong tu update length.");

        check("TC11_SNAKE_HEAD_UPDATE",
              DUT.head_position == $past(DUT.head_position, 1, , @(posedge clk)) + 1,
              "Ran khong tu update head position.");
        // Check Rendering
        check("TC11_COLLISION_LED_OFF", 
        pixel_data[53] == DUT.OFF &&
        pixel_data[54] == DUT.OFF,
       "Dan khong duoc hien thi dung len LED.");

        check("TC11_RENDERING_LED",
                (pixel_data[53] == DUT.OFF   &&
                 pixel_data[54] == DUT.OFF   && 
                 pixel_data[55] == DUT.GREEN && 
                 pixel_data[56] == DUT.BLUE  && 
                 pixel_data[57] == DUT.YELLOW&& 
                 pixel_data[58] == DUT.RED   &&
                 pixel_data[59] == DUT.OFF),
                "LED khong duoc update dung sau khi va cham.");
      $display("TC11 Simultaneous Ticks check completed.");
      $display("--------------------------------------------------");

    endtask

task automatic tc12_button_behavior();
        int bullet_pos_before_spam;
        logic [2:0] bullet_color_before_spam;

        $display("TC12: Starting Rapid Fire Prevention stress test...");

        // 1. Bullet fire (GREEN)
        btn_event = 4'b0010;
        @(negedge clk);
        btn_event = 4'b0000;
        @(negedge clk);

        // 2. Đẩy đạn đi 3 tick
        repeat (3) begin
            @(negedge clk);
            bullet_tick = 1;
            @(negedge clk);
            bullet_tick = 0;
            @(negedge clk);
        end

        // Biến lưu vị trí đạn trước khi spam
        bullet_pos_before_spam   = DUT.bullet_position;
        bullet_color_before_spam = DUT.bullet_color;

        // --- PHA 1: Bấm random các nút ---
        repeat(3) begin
            @(negedge clk);
            btn_event = (4'b0001 << $urandom_range(0,3));
            @(negedge clk);
            btn_event = 4'b0000;
        end
        #1;
        check("TC12_RANDOM_SPAM_IGNORED",
              (DUT.bullet_color == bullet_color_before_spam && 
               DUT.bullet_position == bullet_pos_before_spam && 
               DUT.bullet_active == 1),
              "Dan bi anh huong khi spam random nut.");

        // --- PHA 2: Bấm tổ hợp cùng lúc nhiều nút ---
        btn_event = 4'b1111;
        @(negedge clk);
        btn_event = 4'b0000;
        @(negedge clk);
        #1;
        check("TC12_MULTI_BTN_IGNORED",
              (DUT.bullet_color == bullet_color_before_spam && 
               DUT.bullet_position == bullet_pos_before_spam && 
               DUT.bullet_active == 1),
              "Dan bi anh huong khi bam to hop tat ca nut.");

        // --- PHA 3: Giữ đè 1 nút trong nhiều chu kỳ clock ---
        btn_event = 4'b0001; // Giu nut RED
        repeat(5) @(negedge clk);
        btn_event = 4'b0000;
        @(negedge clk);
        #1;
        check("TC12_HOLD_BTN_IGNORED",
              (DUT.bullet_color == bullet_color_before_spam && 
               DUT.bullet_position == bullet_pos_before_spam && 
               DUT.bullet_active == 1),
              "Dan bi anh huong khi giu de nut lau.");

        // --- PHA 4: Kiem tra vi tri goc LED 0 ---
        check("TC12_NO_BULLET_GENERATED_AT_ZERO",
              (pixel_data[0] == DUT.OFF),
              "Sinh dan moi de len vi tri LED 0 trong khi dan cu chua bay xong.");

        $display("TC12: Rapid Fire Prevention check completed.");
        $display("--------------------------------------------------");
    endtask

    // =========================================================================
    // Main Flow Execution
    // =========================================================================
    initial begin
        // Khởi tạo các tín hiệu đầu vào về 0
        rst         = 0;
        snake_tick  = 0;
        bullet_tick = 0;
        btn_event   = 4'b0000;

      repeat (2)@(negedge clk);
        // Gọi các test case tuần tự ở đây
         tc1_reset_initial_state();
         tc2_idle_to_playing();
         tc3_snake_movement();
         tc4_bullet_fire();
         tc5_bullet_movement();
         tc6_bullet_hit_snake();
         tc7_different_color_hit();
         tc8_win_state();
         tc9_lose_state();
         tc10_restart_from_lose();
         tc11_simultaneous_ticks();
         tc12_button_behavior();
        repeat(5) @(negedge clk);
        $display("\n==============================================");
        if (error_count == 0)
            $display("ALL %0d CHECKS PASSED SUCCESSFULLY!", test_count);
        else
            $display("VERIFICATION COMPLETED WITH %0d ERRORS!", error_count);
        $display("==============================================");
        $finish;
    end

endmodule
