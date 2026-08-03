/// Basys3 Test Module - Counter Display
/// Displays a 16-bit counter on the 16 LEDs and its decimal value (0-9999)
/// on the 4-digit 7-segment display. Counter increments at ~1 Hz for easy
/// visual observation.

module basys3_top (
    input  logic        clk,
    input  logic        rst_n,
    output logic [15:0] led,
    output logic [7:0]  seg,
    output logic [3:0]  an
);

    // 16-bit counter for LEDs (incremented every second)
    logic [15:0] led_counter;
    logic [26:0] clk_divider;  // Divide 100 MHz to ~1 Hz
    logic        tick;

    // Clock divider: 100 MHz -> ~1 Hz (100M ticks per increment)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider <= 27'b0;
            tick        <= 1'b0;
        end else begin
            if (clk_divider == 27'd99_999_999) begin
                clk_divider <= 27'b0;
                tick        <= 1'b1;
            end else begin
                clk_divider <= clk_divider + 1'b1;
                tick        <= 1'b0;
            end
        end
    end

    // 16-bit counter (displays on LEDs)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_counter <= 16'b0;
        end else if (tick) begin
            led_counter <= led_counter + 1'b1;
        end
    end

    // Drive LEDs directly from counter
    assign led = led_counter;

    // 7-segment display controller
    // Multiplexes between 4 digits, each displaying one decimal digit
    logic [3:0] digit_value;
    logic [1:0] digit_select;
    logic [26:0] refresh_divider;

    // Binary-to-BCD conversion (double dabble) for decimal display
    logic [3:0] bcd_thousands, bcd_hundreds, bcd_tens, bcd_ones;

    always_comb begin
        logic [15:0] value;
        logic [31:0] shift_reg;
        value = (led_counter > 16'd9999) ? (led_counter % 16'd10000) : led_counter;
        shift_reg = {16'b0, value};
        for (int i = 0; i < 16; i++) begin
            if (shift_reg[19:16] >= 5) shift_reg[19:16] += 3;
            if (shift_reg[23:20] >= 5) shift_reg[23:20] += 3;
            if (shift_reg[27:24] >= 5) shift_reg[27:24] += 3;
            if (shift_reg[31:28] >= 5) shift_reg[31:28] += 3;
            shift_reg = shift_reg << 1;
        end
        bcd_ones      = shift_reg[19:16];
        bcd_tens      = shift_reg[23:20];
        bcd_hundreds  = shift_reg[27:24];
        bcd_thousands = shift_reg[31:28];
    end

    // Digit refresh clock (~1 kHz for smooth multiplexing)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_divider <= 27'b0;
            digit_select    <= 2'b0;
        end else begin
            if (refresh_divider == 27'd99_999) begin  // 100 MHz / 100k = 1 kHz
                refresh_divider <= 27'b0;
                digit_select    <= digit_select + 1'b1;
            end else begin
                refresh_divider <= refresh_divider + 1'b1;
            end
        end
    end

    // Multiplex counter to display 4 decimal digits
    always_comb begin
        case (digit_select)
            2'd0: digit_value = bcd_ones;       // Digit 0 (rightmost)
            2'd1: digit_value = bcd_tens;       // Digit 1
            2'd2: digit_value = bcd_hundreds;   // Digit 2
            2'd3: digit_value = bcd_thousands;  // Digit 3 (leftmost)
            default: digit_value = 4'b0;
        endcase
    end

    // Anode control (active high - turn on selected digit)
    always_comb begin
        case (digit_select)
            2'd0: an = 4'b0001;  // AN0
            2'd1: an = 4'b0010;  // AN1
            2'd2: an = 4'b0100;  // AN2
            2'd3: an = 4'b1000;  // AN3
            default: an = 4'b0000;
        endcase
    end

    // Decimal digit to 7-segment decoder
    // Common cathode: 1 = LED on, 0 = LED off
    // seg[7:0] = {DP, G, F, E, D, C, B, A}
    always_comb begin
        case (digit_value)
            4'h0: seg = 8'b00111111;  // 0
            4'h1: seg = 8'b00000110;  // 1
            4'h2: seg = 8'b01011011;  // 2
            4'h3: seg = 8'b01001111;  // 3
            4'h4: seg = 8'b01100110;  // 4
            4'h5: seg = 8'b01101101;  // 5
            4'h6: seg = 8'b01111101;  // 6
            4'h7: seg = 8'b00000111;  // 7
            4'h8: seg = 8'b01111111;  // 8
            4'h9: seg = 8'b01101111;  // 9
            default: seg = 8'b00000000;
        endcase
    end

endmodule
