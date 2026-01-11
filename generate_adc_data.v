module generate_adc_data#(
    parameter DATA_WIDTH = 24,
    parameter DATA_DEPTH = 512,
    parameter LATENCY    = 2
)(
    input clk,
    input rst,
    input start,
    output reg [DATA_WIDTH-1:0] sd_0, sd_1, sd_2, sd_3, sd_4, sd_5, sd_6, sd_7
);
    localparam ADDR_WIDTH     = $clog2(DATA_DEPTH);
    localparam ADDR_INCREMENT = 1;

    reg  [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] data_0, data_1, data_2, data_3, data_4, data_5, data_6, data_7;

    reg [LATENCY:0] start_reg;

    always @(posedge clk or posedge rst) begin 
        if(rst) begin
            start_reg <= 0;
        end else begin
            start_reg <= {start_reg[LATENCY-1:0], start};
        end
    end

    blk_mem_gen_3 u_rom_0(
        .clka(clk),
        .addra(addr),
        .douta(data_0),
        .ena(start)
    );

    blk_mem_gen_4 u_rom_1(
        .clka(clk),
        .addra(addr),
        .douta(data_1),
        .ena(start)
    );

    blk_mem_gen_5 u_rom_2(
        .clka(clk),
        .addra(addr),
        .douta(data_2),
        .ena(start)
    );

    blk_mem_gen_6 u_rom_3(
        .clka(clk),
        .addra(addr),
        .douta(data_3),
        .ena(start)
    );

    blk_mem_gen_7 u_rom_4(
        .clka(clk),
        .addra(addr),
        .douta(data_4),
        .ena(start)
    );

    blk_mem_gen_8 u_rom_5(
        .clka(clk),
        .addra(addr),
        .douta(data_5),
        .ena(start)
    );

    blk_mem_gen_9 u_rom_6(
        .clka(clk),
        .addra(addr),
        .douta(data_6),
        .ena(start)
    );

    blk_mem_gen_10 u_rom_7(
        .clka(clk),
        .addra(addr),
        .douta(data_7),
        .ena(start)
    );

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            addr   <= 0;
            sd_0   <= 0;
            sd_1   <= 0;
            sd_2   <= 0;
            sd_3   <= 0;
            sd_4   <= 0;
            sd_5   <= 0;
            sd_6   <= 0;
            sd_7   <= 0;
        end else if(start_reg[LATENCY]) begin
            addr <= addr + ADDR_INCREMENT;
            sd_0 <= data_0;
            sd_1 <= data_1;
            sd_2 <= data_2;
            sd_3 <= data_3;
            sd_4 <= data_4;
            sd_5 <= data_5;
            sd_6 <= data_6;
            sd_7 <= data_7;
        end
    end
endmodule