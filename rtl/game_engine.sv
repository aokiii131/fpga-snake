module game_engine 
// 1. Parameters, input, output
    #(  
        parameter int DEFAULT_LENGTH      = 5,
        parameter int LED_COUNT            = 60
) (
    input  logic         rst,
    input  logic         clk,
    input  logic         snake_tick,
    input  logic         bullet_tick,
    input  logic [3:0]   btn_event,

    output logic [2:0]   pixel_data [0:LED_COUNT - 1]
);
    // Color Encoding
    localparam logic [2:0] OFF    = 3'b000;
    localparam logic [2:0] RED    = 3'b001;
    localparam logic [2:0] GREEN  = 3'b010;
    localparam logic [2:0] BLUE   = 3'b011;
    localparam logic [2:0] YELLOW = 3'b100;
// 2. FSM States
    typedef enum logic [1:0]{
        IDLE,
        PLAYING,
        WIN,
        LOSE
    } state_t;
    state_t current_state;
    state_t next_state;

// 3. Game-state registers
    // Snake registers
    logic [2:0]                         snake_array [0:LED_COUNT - 1];
    logic [$clog2(LED_COUNT):0]         snake_length;
    logic [$clog2(LED_COUNT) - 1:0]     head_position;
    

    // Bullet registers
    logic                               bullet_active;
    logic [$clog2(LED_COUNT) - 1:0]     bullet_position;
    logic [2:0]                         bullet_color;
    logic [2:0]                         set_color;
    
    // 3.3 
    always_comb begin
        // Priority Encoder
        if      (btn_event[0]) set_color = RED;
        else if (btn_event[1]) set_color = GREEN;
        else if (btn_event[2]) set_color = BLUE;
        else if (btn_event[3]) set_color = YELLOW;
        else                   set_color = OFF;
    end

    // 3.4 Look-ahead Movement Block
    logic [$clog2(LED_COUNT) - 1:0] next_head;
    logic [$clog2(LED_COUNT) - 1:0] next_bullet;
    logic [2:0]                     next_color;
    logic                           next_active;
    logic [$clog2(LED_COUNT):0]     next_length;

    logic                           is_collis;
    logic                           is_hit;

    always_comb begin
        // 1. Default
        next_head   = head_position;
        next_bullet = bullet_position;
        next_active = bullet_active;
        next_color  = bullet_color;
        next_length = snake_length;

        is_collis   = 1'b0;
        is_hit      = 1'b0;

        // 2. Snake movement and bullet look-ahead.
        // At the final LED a bullet holds position. Its lifetime ends only
        // when it collides with the snake.
        if (snake_tick && head_position != 0 && snake_length != 0)
            next_head = head_position - 1'b1;

        if (bullet_tick && bullet_active && bullet_position < LED_COUNT-1)
            next_bullet = bullet_position + 1'b1;

        // 3. Collision
        if (bullet_active && (next_bullet >= next_head))
            is_collis = 1'b1;

        // 4. Hit / Miss
        if (is_collis) begin
            if (bullet_color == snake_array[head_position])
                is_hit = 1'b1;
        end

        // 5. Collision result
        if (is_collis) begin
            // Bullet disappears after any collision
            next_active = 1'b0;
            next_color  = OFF;

            // Same-color hit
            if (is_hit) begin
                next_head   = head_position + 1'b1;
                next_length = snake_length - 1'b1;
            end
        end

        // 6. Fire
        if (!bullet_active && (|btn_event)) begin
            next_active = 1'b1;
            next_bullet = '0;
            next_color  = set_color;
        end
    end
// 4. FSM Block
    // -------------------------------------------------------------------------
    // 4.1 Next-state / control logic
    // -------------------------------------------------------------------------   
    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if(|btn_event)              // Có ít nhất 1 nút bấm
                    next_state = PLAYING;
            end
            
            PLAYING: begin
                if      (snake_length == 0)
                    next_state = WIN;
                else if (head_position == 0)
                    next_state = LOSE;
            end

            WIN, LOSE: begin
                next_state = current_state;
            end

            default: next_state = IDLE;
        endcase
    end
    
    // -------------------------------------------------------------------------
    // 4.2. Datapath & State Update (Sequential)
    // -------------------------------------------------------------------------
    always_ff @ (posedge clk or posedge rst) begin
        if(rst) begin
            // Initialize game
            current_state   <= IDLE;
            snake_length    <= DEFAULT_LENGTH;
            head_position   <= LED_COUNT - DEFAULT_LENGTH;
            bullet_active   <= 1'b0;
            bullet_position <= '0;
            bullet_color    <= OFF;

            for(int i = 0; i < LED_COUNT; i++) begin
                snake_array[i] <= OFF;
                end
            // Initialize Snake
            snake_array[55] <= RED;
            snake_array[56] <= GREEN;
            snake_array[57] <= BLUE;
            snake_array[58] <= YELLOW;
            snake_array[59] <= RED;
        
        end else begin
            // update FSM
            current_state <= next_state;

            case (current_state)
                
                IDLE: begin
                    bullet_active <= 0;
                end

                PLAYING: begin
                    // Commit next game state
                    head_position   <= next_head;
                    snake_length    <= next_length;

                    bullet_position <= next_bullet;
                    bullet_active   <= next_active;
                    bullet_color    <= next_color;

                    // Snake array update
                    if (is_hit) begin
                            snake_array[head_position] <= OFF;
                    end
                    else if (snake_tick &&
                             head_position != 0 &&
                             snake_length != 0) begin

                            for (int i = 0; i < LED_COUNT-1; i++) begin
                                snake_array[i] <= snake_array[i+1];
                            end

                            snake_array[LED_COUNT-1] <= OFF;
                    end
                end

                WIN, LOSE: begin
                    bullet_active <= 0;
                end
            endcase
        end
    end
// 6. Pixel rendering logic

    always_comb begin
        case(current_state)

            IDLE, PLAYING: begin
                for (int i = 0; i < LED_COUNT; i++) begin
                    if (bullet_active && (bullet_position == i)) begin
                        pixel_data[i] = bullet_color;
                    end else begin
                        pixel_data[i] = snake_array[i];
                    end
                end 
            end

            WIN: begin
                for(int i = 0; i < LED_COUNT; i++) begin
                    pixel_data[i] = GREEN;
                end 
            end
            LOSE: begin
                for(int i = 0; i < LED_COUNT; i++) begin
                    pixel_data[i] = RED;
                end 
            end

            default: begin
                for(int i = 0; i < LED_COUNT; i++) begin
                    pixel_data[i] = OFF;
                end
            end
        endcase
    end
endmodule
