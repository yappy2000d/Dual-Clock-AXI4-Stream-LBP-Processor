// -----------------------------------------------------------------------------
// Active-low reset synchronizer
//   - asynchronous assertion
//   - two-stage synchronous deassertion
//
// The two stages must use the same destination-domain clock.  The output may
// drive asynchronous reset pins in that clock domain; its release is then
// generated only by a clock edge of that domain.
// -----------------------------------------------------------------------------
module RESET_SYNC_N (
    input  wire clk,
    input  wire arst_n,
    output wire srst_n
);

(* async_reg = "true" *) reg sync_ff1;
(* async_reg = "true" *) reg sync_ff2;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        sync_ff1 <= 1'b0;
        sync_ff2 <= 1'b0;
    end
    else begin
        sync_ff1 <= 1'b1;
        sync_ff2 <= sync_ff1;
    end
end

assign srst_n = sync_ff2;

endmodule

module CHIP (
    input  wire       cclk,
    input  wire       cresetn,
    input  wire       aclk,
    input  wire       aresetn,

    input  wire       s_axis_tvalid,
    output wire       s_axis_tready,
    input  wire [7:0] s_axis_tdata,
    input  wire       s_axis_tlast,

    output wire       m_axis_tvalid,
    input  wire       m_axis_tready,
    output wire [7:0] m_axis_tdata,
    output wire       m_axis_tlast
);

wire       i_cclk;
wire       i_cresetn;
wire       i_cresetn_sync;
wire       i_aclk;
wire       i_aresetn;
wire       i_aresetn_sync;
wire       i_s_axis_tvalid;
wire [7:0] i_s_axis_tdata;
wire       i_s_axis_tlast;
wire       i_m_axis_tready;

wire       o_s_axis_tready;
wire       o_m_axis_tvalid;
wire [7:0] o_m_axis_tdata;
wire       o_m_axis_tlast;

PDIDGZ ipad_cclk    (.PAD(cclk),           .C(i_cclk));
PDIDGZ ipad_cresetn (.PAD(cresetn),        .C(i_cresetn));
PDIDGZ ipad_aclk    (.PAD(aclk),           .C(i_aclk));
PDIDGZ ipad_aresetn (.PAD(aresetn),        .C(i_aresetn));
PDIDGZ ipad_s_valid (.PAD(s_axis_tvalid),  .C(i_s_axis_tvalid));
PDIDGZ ipad_s_data7 (.PAD(s_axis_tdata[7]), .C(i_s_axis_tdata[7]));
PDIDGZ ipad_s_data6 (.PAD(s_axis_tdata[6]), .C(i_s_axis_tdata[6]));
PDIDGZ ipad_s_data5 (.PAD(s_axis_tdata[5]), .C(i_s_axis_tdata[5]));
PDIDGZ ipad_s_data4 (.PAD(s_axis_tdata[4]), .C(i_s_axis_tdata[4]));
PDIDGZ ipad_s_data3 (.PAD(s_axis_tdata[3]), .C(i_s_axis_tdata[3]));
PDIDGZ ipad_s_data2 (.PAD(s_axis_tdata[2]), .C(i_s_axis_tdata[2]));
PDIDGZ ipad_s_data1 (.PAD(s_axis_tdata[1]), .C(i_s_axis_tdata[1]));
PDIDGZ ipad_s_data0 (.PAD(s_axis_tdata[0]), .C(i_s_axis_tdata[0]));
PDIDGZ ipad_s_last  (.PAD(s_axis_tlast),   .C(i_s_axis_tlast));
PDIDGZ ipad_m_ready (.PAD(m_axis_tready),  .C(i_m_axis_tready));

// Each clock domain owns its reset-release synchronizer.  Assertion remains
// asynchronous through arst_n; deassertion reaches CORE after two local clock
// edges.  cclk and aclk are related clocks, but reset release is still handled
// independently in each destination domain.
RESET_SYNC_N u_creset_sync (
    .clk    (i_cclk),
    .arst_n (i_cresetn),
    .srst_n (i_cresetn_sync)
);

RESET_SYNC_N u_areset_sync (
    .clk    (i_aclk),
    .arst_n (i_aresetn),
    .srst_n (i_aresetn_sync)
);

PDO08CDG opad_s_ready (.PAD(s_axis_tready),  .I(o_s_axis_tready));
PDO08CDG opad_m_valid (.PAD(m_axis_tvalid),  .I(o_m_axis_tvalid));
PDO08CDG opad_m_data7 (.PAD(m_axis_tdata[7]), .I(o_m_axis_tdata[7]));
PDO08CDG opad_m_data6 (.PAD(m_axis_tdata[6]), .I(o_m_axis_tdata[6]));
PDO08CDG opad_m_data5 (.PAD(m_axis_tdata[5]), .I(o_m_axis_tdata[5]));
PDO08CDG opad_m_data4 (.PAD(m_axis_tdata[4]), .I(o_m_axis_tdata[4]));
PDO08CDG opad_m_data3 (.PAD(m_axis_tdata[3]), .I(o_m_axis_tdata[3]));
PDO08CDG opad_m_data2 (.PAD(m_axis_tdata[2]), .I(o_m_axis_tdata[2]));
PDO08CDG opad_m_data1 (.PAD(m_axis_tdata[1]), .I(o_m_axis_tdata[1]));
PDO08CDG opad_m_data0 (.PAD(m_axis_tdata[0]), .I(o_m_axis_tdata[0]));
PDO08CDG opad_m_last  (.PAD(m_axis_tlast),   .I(o_m_axis_tlast));

CORE top (
    .core_cclk          (i_cclk),
    .core_cresetn       (i_cresetn_sync),
    .core_aclk          (i_aclk),
    .core_aresetn       (i_aresetn_sync),
    .core_s_axis_tvalid (i_s_axis_tvalid),
    .core_s_axis_tready (o_s_axis_tready),
    .core_s_axis_tdata  (i_s_axis_tdata),
    .core_s_axis_tlast  (i_s_axis_tlast),
    .core_m_axis_tvalid (o_m_axis_tvalid),
    .core_m_axis_tready (i_m_axis_tready),
    .core_m_axis_tdata  (o_m_axis_tdata),
    .core_m_axis_tlast  (o_m_axis_tlast)
);

endmodule
