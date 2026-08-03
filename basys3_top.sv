/// Basys3 Test Module - Switch to LED passthrough
/// Each slide switch lights up its corresponding LED.

module basys3_top (
    input  logic [15:0] sw,
    output logic [15:0] led
);

    assign led = sw;

endmodule
