// Input: clk, rst, key[3:0] (active-low)
// Output: btn_event[3:0]
// Timing: btn_event (1-cycle)
// Note: using 2 FF to sync the signal from kit.

module button_conditioner(
    input logic clk,
    input logic rst,
    input logic [3:0] key,

    output logic [3:0] btn_event
);
    logic [3:0] sync_ff1;
    logic [3:0] sync_ff2;
    logic [3:0] prev_sync;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
                sync_ff1   <= '1;
                sync_ff2   <= '1;
                prev_sync  <= '1;
            end
        else begin
            // 2-FF Synchronization Block
            sync_ff1   <= key;
            sync_ff2   <= sync_ff1;
            prev_sync  <= sync_ff2;        // Previous-stage register
        end
    end
    // Edge Detector 
    assign btn_event = prev_sync & ~sync_ff2;
endmodule