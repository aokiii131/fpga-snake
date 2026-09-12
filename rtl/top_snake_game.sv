module top_snake_game #(
    // 1. Khai báo I/O và các Parameter then chốt
    parameter int LED_COUNT = 60,
    parameter int DEFAULT_SNAKE_LENGTH = 5
) (
    input logic clk_50m,
    input logic rst_sw,
    input logic [3:0] key,

    output logic led_data_out
);
    // 2. Khai báo các tín hiệu kết nối giữa các module

    // Tick Generator
    logic snake_tick;
    logic bullet_tick;

    // Button Conditioner
    logic [3:0] btn_event;

    // Game Engine
    logic [2:0] pixel_data [0:LED_COUNT - 1];

    // Gọi các module con và cắm dây 
    tick_generator u_tick_generator (
        .clk(clk_50m),
        .rst(rst_sw),
        .snake_tick(snake_tick),
        .bullet_tick(bullet_tick)
    );

    button_conditioner u_button_conditioner (
        .clk(clk_50m),
        .rst(rst_sw),
        .key(key),
        .btn_event(btn_event)
    );

    ws2812b_driver  #(
        .LED_COUNT(LED_COUNT),
        .BITS_PER_PIXEL(24)
    ) u_ws2812b_driver (
        .clk(clk_50m),
        .rst(rst_sw),
        .pixel_data(pixel_data),
        .led_data_out(led_data_out)
    );

    game_engine #(
        .DEFAULT_LENGTH(DEFAULT_SNAKE_LENGTH),
        .LED_COUNT(LED_COUNT)
    ) u_game_engine (
        .clk(clk_50m),
        .rst(rst_sw),
        .snake_tick(snake_tick),
        .bullet_tick(bullet_tick),
        .btn_event(btn_event),
        .pixel_data(pixel_data)
    );



endmodule