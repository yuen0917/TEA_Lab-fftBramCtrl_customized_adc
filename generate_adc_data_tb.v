`timescale 1ns / 1ps

module generate_adc_data_tb;
    parameter DATA_WIDTH = 24;
    parameter DATA_DEPTH = 512;
    parameter LATENCY    = 2;
    
    // Clock and reset
    reg clk;
    reg rst;
    reg start;
    
    // Outputs
    wire [DATA_WIDTH-1:0] sd_0, sd_1, sd_2, sd_3, sd_4, sd_5, sd_6, sd_7;
    
    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    // Reset and start signal generation
    initial begin
        rst = 1;
        start = 0;
        #100;  // Wait 100ns
        
        rst = 0;
        #20;   // Wait 20ns after reset release
        
        start = 1;  // Start signal goes high and stays high
        // Simulation will auto-finish after 512 samples are displayed
        #50000;      // Maximum simulation time (will finish earlier if 512 samples reached)
        
        $display("\nWarning: Simulation timeout - not all 512 samples were displayed");
        $finish;
    end
    
    // Instantiate DUT
    generate_adc_data #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_DEPTH(DATA_DEPTH),
        .LATENCY(LATENCY)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .sd_0(sd_0),
        .sd_1(sd_1),
        .sd_2(sd_2),
        .sd_3(sd_3),
        .sd_4(sd_4),
        .sd_5(sd_5),
        .sd_6(sd_6),
        .sd_7(sd_7)
    );
    
    // Local parameters for display
    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);
    localparam ADDR_INCREMENT = 1;
    
    // Track output cycle count
    reg [31:0] output_cycle;
    reg [LATENCY:0] start_reg_tb;
    reg data_valid;
    
    initial begin
        output_cycle = 0;
        start_reg_tb = 0;
        data_valid = 0;
    end
    
    // Track start_reg behavior (same as DUT)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start_reg_tb <= 0;
            data_valid <= 0;
        end else begin
            start_reg_tb <= {start_reg_tb[LATENCY-1:0], start};
            data_valid <= start_reg_tb[LATENCY];
        end
    end
    
    // Count output cycles
    always @(posedge clk) begin
        if (rst) begin
            output_cycle <= 0;
        end else if (data_valid) begin
            output_cycle <= output_cycle + 1;
        end
    end
    
    // Display header
    initial begin
        $display("\n========================================");
        $display("ADC Data Generator Testbench (Signed Decimal)");
        $display("========================================\n");
        $display("Time(ns) | Cycle | Expected Addr |      sd_0 |      sd_1 |      sd_2 |      sd_3 |      sd_4 |      sd_5 |      sd_6 |      sd_7");
        $display("---------|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------");
    end
    
    // Display data when outputs are valid (signed decimal)
    // Only display first 512 samples (DATA_DEPTH)
    // Note: output_cycle starts from 1 when first valid data appears
    always @(posedge clk) begin
        if (!rst && data_valid && output_cycle >= 1 && output_cycle <= DATA_DEPTH) begin
            // Calculate expected address: (output_cycle - 1) because cycle 1 corresponds to address 0
            $display("%8t | %5d | %13d | %10d | %10d | %10d | %10d | %10d | %10d | %10d | %10d",
                $time,
                output_cycle,
                (output_cycle - 1) * ADDR_INCREMENT,
                $signed(sd_0), $signed(sd_1), $signed(sd_2), $signed(sd_3),
                $signed(sd_4), $signed(sd_5), $signed(sd_6), $signed(sd_7)
            );
            
            // Stop simulation after displaying 512 samples
            if (output_cycle == DATA_DEPTH) begin
                $display("\n========================================");
                $display("Finished displaying %0d samples", DATA_DEPTH);
                $display("========================================\n");
                #100;  // Wait a bit before finishing
                $finish;
            end
        end
    end
    
    // Alternative: Use $monitor for continuous monitoring (signed decimal)
    // Uncomment the following if you prefer $monitor
    /*
    initial begin
        $monitor("Time: %0t ns | sd_0=%0d | sd_1=%0d | sd_2=%0d | sd_3=%0d | sd_4=%0d | sd_5=%0d | sd_6=%0d | sd_7=%0d",
            $time, $signed(sd_0), $signed(sd_1), $signed(sd_2), $signed(sd_3),
            $signed(sd_4), $signed(sd_5), $signed(sd_6), $signed(sd_7));
    end
    */
    
    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("generate_adc_data_tb.vcd");
        $dumpvars(0, generate_adc_data_tb);
    end
    
endmodule
