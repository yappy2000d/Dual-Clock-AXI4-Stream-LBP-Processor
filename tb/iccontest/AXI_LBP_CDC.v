`timescale 1ps/1ps

// Compatibility wrapper for the original IC Contest address-based fixture.
// The DUT itself remains a full-frame AXI-Stream block with no address ports.
module LBP (
    input  wire        clk,
    input  wire        reset,
    output reg  [13:0] gray_addr,
    output wire        gray_req,
    input  wire        gray_ready,
    input  wire [7:0]  gray_data,
    output reg  [13:0] lbp_addr,
    output wire        lbp_valid,
    output wire [7:0]  lbp_data,
    output reg         finish
);

wire aclk;
reg input_done;

wire       core_s_ready;
wire       core_m_valid;
wire [7:0] core_m_data;
wire       core_m_last;

wire input_fire;
wire output_fire;

div3_50duty u_div3_50duty (
    .clk    (clk),
    .rst_n  (~reset),
    .out_clk(aclk)
);

// Keep gray_req asserted while a source word is outstanding.  The contest
// fixture otherwise drives gray_data to Z during a stall, which is not legal
// AXI payload behavior.
assign gray_req   = !input_done;
assign input_fire = gray_ready && !input_done && core_s_ready;
assign output_fire = core_m_valid;

assign lbp_valid = core_m_valid;
assign lbp_data  = core_m_data;

CHIP TOP (
    .cclk          (clk),
    .cresetn       (~reset),
    .aclk          (aclk),
    .aresetn       (~reset),
    .s_axis_tvalid (gray_ready && !input_done),
    .s_axis_tready (core_s_ready),
    .s_axis_tdata  (gray_data),
    .s_axis_tlast  (gray_addr == 14'd16383),
    .m_axis_tvalid (core_m_valid),
    .m_axis_tready (1'b1),
    .m_axis_tdata  (core_m_data),
    .m_axis_tlast  (core_m_last)
);

reg input_fire_q;


// ============================================================
// 1. Sample AXI input handshake on the real AXI active edge.
// ============================================================
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        input_fire_q <= 1'b0;
    end
    else begin
        input_fire_q <= input_fire;
    end
end


// ============================================================
// 2. Advance legacy source HALF A CYCLE later.
//    Keep payload/address stable across DUT's delayed clock edge.
// ============================================================
always @(negedge aclk or posedge reset) begin
    if (reset) begin
        gray_addr  <= 14'd0;
        input_done <= 1'b0;
    end
    else if (input_fire_q) begin
        if (gray_addr == 14'd16383)
            input_done <= 1'b1;
        else
            gray_addr <= gray_addr + 14'd1;
    end
end


// ============================================================
// 3. Output accounting stays on posedge for now.
// ============================================================
always @(posedge aclk or posedge reset) begin
    if (reset) begin
        lbp_addr <= 14'd0;
        finish   <= 1'b0;
    end
    else begin
        if (output_fire) begin
            if (core_m_last)
                finish <= 1'b1;
            else
                lbp_addr <= lbp_addr + 14'd1;
        end
    end
end

endmodule

module div3_50duty (
    input  wire clk,
    input  wire rst_n,
    output wire out_clk
);

    reg [1:0] pos_cnt;
    reg [1:0] neg_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pos_cnt <= 2'b00;
        else if (pos_cnt == 2'b10)
            pos_cnt <= 2'b00;
        else
            pos_cnt <= pos_cnt + 1'b1;
    end

    always @(negedge clk or negedge rst_n) begin
        if (!rst_n)
            neg_cnt <= 2'b00;
        else
            neg_cnt <= pos_cnt;
    end

    wire clk_pos = (pos_cnt == 2'b00);
    wire clk_neg = (neg_cnt == 2'b00);

    assign out_clk = clk_pos | clk_neg;

endmodule

