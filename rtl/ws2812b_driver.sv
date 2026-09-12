    // Input: clk, rst, pixel_data
    // Output: led_data_out
    // First, captured the pixel_data into tx_frame, then encode them into 24bits and 60 LED structure, then send it to the LED
    module ws2812b_driver #(
        parameter int RES = 15_000, // 300 us
        parameter int T0H = 15, // 300 ns
        parameter int T0L = 40, // 800 ns
        parameter int T1H = 40, // 800 ns
        parameter int T1L = 15, // 300 ns

        parameter int LED_COUNT        = 60,
        parameter int BITS_PER_PIXEL   = 24,
        parameter int BIT_TOTAL_CYCLES = T0H + T0L
    ) (
        input logic clk,
        input logic rst,
        input logic [2:0] pixel_data [0:LED_COUNT-1], // LED_COUNT pixels, 3-bit logical color code

        output logic led_data_out
    );
        typedef enum logic [1:0]{
            LOAD,
            SEND,
            LATCH
        } state_t;

        state_t current_state;
        state_t next_state;

        logic [2:0] tx_frame [0:LED_COUNT-1];
        logic [$clog2(LED_COUNT)-1:0] pixel_counter;
        logic [4:0] bit_counter;
        logic [$clog2(RES)-1:0] timing_counter;

        logic current_bit;
        logic [23:0] current_pixel_24;

        // 1. Decode 3 to 24 bit Block
        always_comb begin
            case (tx_frame[pixel_counter])        
                3'b001:  current_pixel_24 = 24'h00_3F_00;        // RED
                3'b010:  current_pixel_24 = 24'h3F_00_00;        // GREEN
                3'b011:  current_pixel_24 = 24'h00_00_3F;        // BLUE
                3'b100:  current_pixel_24 = 24'h3F_3F_00;        // YELLOW

                default: current_pixel_24 = 24'h00_00_00;        // OFF
            endcase
            current_bit = current_pixel_24[bit_counter];
        end

        // 2. FSM Block
            // 1.1 State Register (Next-State Logic) (awlays_comb)
        always_comb begin
            next_state = current_state;
            case (current_state)
                LOAD:
                        next_state = SEND;

                SEND:
                    if(pixel_counter == LED_COUNT - 1 && 
                       bit_counter == 0               && 
                       timing_counter == BIT_TOTAL_CYCLES - 1) 
                       begin
                        next_state = LATCH;
                    end    

                LATCH:
                    if(timing_counter == RES - 1) begin
                        next_state = LOAD;
                    end
            endcase  
        end

            // 1.2 state + counters + tx_frame
        always_ff @(posedge clk or posedge rst) begin
            if(rst) begin
                current_state   <= LOAD;
                pixel_counter   <= 0;
                bit_counter     <= 23;
                timing_counter  <= 0;
            end
            else begin
                current_state   <= next_state;
            
                case (current_state)
                    LOAD: begin
                        tx_frame       <= pixel_data;
                        pixel_counter  <= 0;
                        bit_counter    <= 23;
                        timing_counter <= 0;
                    end

                    SEND: begin     // Chỉ cập nhật các registers
                        if(timing_counter < BIT_TOTAL_CYCLES - 1) begin
                            timing_counter <= timing_counter + 1;
                        end
                        else begin
                            timing_counter <= 0;
                            if (bit_counter > 0) begin
                                bit_counter <= bit_counter - 1;
                            end
                            else if (bit_counter == 0) begin
                                if (pixel_counter < LED_COUNT - 1) begin
                                    pixel_counter <= pixel_counter + 1;
                                     bit_counter  <= BITS_PER_PIXEL - 1;
                                end
                            end
                        end
                    end

                    LATCH: begin
                        if (timing_counter < RES - 1)
                            timing_counter <= timing_counter + 1;
                    end
                endcase   
            end
        end

            // 1.3 Output Block
        always_comb begin
            led_data_out = 1'b0; 
            
            if (current_state == SEND) begin
                if (current_bit == 1'b0) begin
                    if (timing_counter < T0H)
                        led_data_out = 1'b1;
                end
                else begin // current_bit == 1'b1
                    if (timing_counter < T1H)
                        led_data_out = 1'b1;               
                end
            end
        end      
    endmodule