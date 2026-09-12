// Input: clk (50MHz), rst
// Output: bullet_tick (1 tick every 50ms), snake_tick (1 tick every 250ms)
// The module generates clock-enable pulses only; it does not create derived clocks.

module tick_generator#
(
    parameter int BULLET_CYCLES = 2_500_000,
    parameter int SNAKE_TICKS_COUNT = 5
) (
    input logic clk,
    input logic rst,

    output logic snake_tick,
    output logic bullet_tick
);

    logic [$clog2(BULLET_CYCLES)-1:0] bullet_counter;
    logic [$clog2(SNAKE_TICKS_COUNT)-1:0] snake_count;
    
    always_ff @(posedge clk or posedge rst) begin

        
        if(rst) begin
            snake_tick  <= 0;
            bullet_tick <= 0;
            bullet_counter <= 0;
            snake_count <= 0;
        end
        else begin
            snake_tick  <= 0;
            bullet_tick <= 0;
            
            if(bullet_counter == BULLET_CYCLES - 1) begin
                bullet_tick <= 1;
                bullet_counter <= 0;
                
                if(snake_count == SNAKE_TICKS_COUNT - 1) begin
                    snake_tick <= 1;
                    snake_count <= 0;
                end

                else snake_count <= snake_count + 1'b1;
            end
            
            else bullet_counter <= bullet_counter + 1'b1;
        end
    end


endmodule
                                                    
