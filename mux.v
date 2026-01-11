`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/09 23:57:35
// Design Name: 
// Module Name: mux
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module mux(
    // Clock and reset
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    
    // AXI Stream Slave Interface
    input  wire        S_AXIS_tready,
    output reg [255:0] S_AXIS_tdata,
    output reg         S_AXIS_tvalid,
    output reg         S_AXIS_tlast,
    
    // Data inputs (8 channels, 32-bit each)
    input  wire [31:0] data1,
    input  wire [31:0] data2,
    input  wire [31:0] data3,
    input  wire [31:0] data4,
    input  wire [31:0] data5,
    input  wire [31:0] data6,
    input  wire [31:0] data7,
    input  wire [31:0] data8,
    
    // Flag inputs
    input  wire        flag1_in,
    input  wire        flag2_in,
    input  wire        flag3_in,
    input  wire        flag4_in,
    input  wire        flag5_in,
    input  wire        flag6_in,
    input  wire        flag7_in,
    input  wire        flag8_in,
    
    // Flag outputs
    output reg         flag1_out,
    output reg         flag2_out,
    output reg         flag3_out,
    output reg         flag4_out,
    output reg         flag5_out,
    output reg         flag6_out,
    output reg         flag7_out,
    output reg         flag8_out
);

    // Internal registers
    reg [2:0] count;
    reg       state;

    // Initialize
    initial begin
        count         <= 3'd0;
        state         <= 1'b0;
        S_AXIS_tvalid <= 1'b0;
        S_AXIS_tlast  <= 1'b0;
    end

    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count         <= 3'd0;
            S_AXIS_tvalid <= 1'b0;
            S_AXIS_tlast  <= 1'b0;
            state         <= 1'b0;
            flag1_out     <= 1'b0;
            flag2_out     <= 1'b0;
            flag3_out     <= 1'b0;
            flag4_out     <= 1'b0;
            flag5_out     <= 1'b0;
            flag6_out     <= 1'b0;
            flag7_out     <= 1'b0;
            flag8_out     <= 1'b0;
        end else begin
            // Start state machine
            if (start) begin
                state <= 1'b1;
            end

            // State machine logic
            if (state) begin
                case (count)
                    3'd0: begin
                        // Wait for all flags to be ready
                        if (S_AXIS_tready && flag1_in && flag2_in && flag3_in && flag4_in && 
                            flag5_in && flag6_in && flag7_in && flag8_in) begin
                            count     <= count + 3'd1;
                            flag1_out <= 1'b1;
                            flag2_out <= 1'b1;
                            flag3_out <= 1'b1;
                            flag4_out <= 1'b1;
                            flag5_out <= 1'b1;
                            flag6_out <= 1'b1;
                            flag7_out <= 1'b1;
                            flag8_out <= 1'b1;
                        end
                    end

                    3'd1: begin
                        // Send data (flag refer to act_data_valid)
                        if (S_AXIS_tready && flag1_in && flag2_in && flag3_in && flag4_in && 
                            flag5_in && flag6_in && flag7_in && flag8_in) begin
                            S_AXIS_tvalid <= 1'b1;
                            S_AXIS_tdata  <= {data8, data7, data6, data5, data4, data3, data2, data1};
                            S_AXIS_tlast  <= 1'b0;
                            count          <= count + 3'd1;
                            flag1_out      <= 1'b0;
                            flag2_out      <= 1'b0;
                            flag3_out      <= 1'b0;
                            flag4_out      <= 1'b0;
                            flag5_out      <= 1'b0;
                            flag6_out      <= 1'b0;
                            flag7_out      <= 1'b0;
                            flag8_out      <= 1'b0;
                        end
                    end

                    3'd2: begin
                        // Clear valid signal and reset
                        S_AXIS_tvalid <= 1'b0;
                        S_AXIS_tlast  <= 1'b0;
                        count         <= 3'd0;
                    end

                    default: begin
                        count <= 3'd0;
                    end
                endcase
            end
        end
    end

endmodule
