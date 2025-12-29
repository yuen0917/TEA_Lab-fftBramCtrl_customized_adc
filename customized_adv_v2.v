`timescale 1ns / 1ps
// v2.0

module customized_adc_v2(
    input              sck,
    input              ws,
    input       [23:0] sd,
    input              rst,
    input              start,
    input              flag_in,
    output wire [31:0] data,
    output reg         flag_out
);
    (* keep = "true" *) reg [31:0] data_reg;
    assign data = data_reg;

    reg [4:0] bit_count;
    reg       delay;
    reg       state;
    reg       flag_in_d1;
    wire      flag_in_negedge;

    assign flag_in_negedge = flag_in_d1 & ~flag_in;

    // if rst is working, this initial block can be ignored
    initial begin
        bit_count  <= 5'd0;
        delay      <= 1'b0;
        state      <= 1'b0;
        flag_in_d1 <= 1'b0;
        flag_out   <= 1'b0;
    end

    always @(posedge sck or posedge rst) begin
        if(rst) begin
            flag_in_d1 <= 1'b0;
        end else begin
            flag_in_d1 <= flag_in;
        end
    end

    always @(posedge sck or posedge rst) begin
        if(rst) begin
            state <= 1'b0;
        end else begin
            if(start) begin
                state <= 1'b1;
            end else begin
                state <= state;
            end
        end
    end

    always @(posedge sck or posedge rst) begin
        if(rst) begin
            bit_count <=  5'd0;
            delay     <=  1'b0;
            flag_out  <=  1'b0;
            data_reg  <= 32'd0;
        end else if (flag_in_negedge) begin
            flag_out  <=  1'b0;
            bit_count <=  5'd0;
            delay     <=  1'b0;
        end else if (state) begin
            if(~ws && !flag_out) begin
                if(delay == 1'b0) begin
                    delay    <= 1'b1;
                    flag_out <= 1'b0;
                end else begin
                    if(bit_count == 5'd24) begin
                        data_reg[31:8] <= sd;
                        flag_out       <= 1'b1;
                        bit_count      <= 5'd0;
                        delay          <= 1'b0;
                    end else begin
                        bit_count      <= bit_count + 5'b1;
                    end
                end
            end else begin
                bit_count <= 5'd0;
                delay     <= 1'b0;
            end
        end
    end
endmodule