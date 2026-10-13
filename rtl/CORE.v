`timescale 1ns/1ps
`default_nettype none

module CORE (
    input  wire       core_cclk,
    input  wire       core_cresetn,
    input  wire       core_aclk,
    input  wire       core_aresetn,

    input  wire       core_s_axis_tvalid,
    output wire       core_s_axis_tready,
    input  wire [7:0] core_s_axis_tdata,
    input  wire       core_s_axis_tlast,

    output wire       core_m_axis_tvalid,
    input  wire       core_m_axis_tready,
    output wire [7:0] core_m_axis_tdata,
    output wire       core_m_axis_tlast
);

// core_cclk is the fast processing clock. core_aclk is its synchronous divide-by-three
// AXI clock. All crossings remain timed related-clock paths; no false paths
// are intended between these two domains.

localparam [1:0] ST_READY  = 2'd0;
localparam [1:0] ST_PHASE1 = 2'd1;
localparam [1:0] ST_PHASE2 = 2'd2;

// -------------------------------------------------------------------------
// AXI input FIFO: core_aclk producer, core_cclk consumer
// -------------------------------------------------------------------------

reg [8:0] input_mem [0:3];

// Pointer format: [2] wrap bit, [1:0] memory index.
reg [2:0] input_write_ptr;
reg [2:0] input_read_ptr;
reg [2:0] input_read_ptr_core_aclk;
reg [2:0] input_write_ptr_core_cclk;
reg       core_s_axis_tready_reg;

wire       input_push;
wire [2:0] input_write_ptr_after_push;
wire       input_full_after_push;
wire       input_fifo_empty_core_cclk;

assign input_push = core_s_axis_tvalid && core_s_axis_tready;

assign input_write_ptr_after_push =
    input_write_ptr + (input_push ? 3'd1 : 3'd0);

assign input_full_after_push =
    (input_write_ptr_after_push[2] != input_read_ptr_core_aclk[2]) &&
    (input_write_ptr_after_push[1:0] == input_read_ptr_core_aclk[1:0]);

assign input_fifo_empty_core_cclk =
    (input_write_ptr_core_cclk == input_read_ptr);

assign core_s_axis_tready = core_s_axis_tready_reg;

always @(posedge core_aclk or negedge core_aresetn) begin
    if (!core_aresetn) begin
        input_write_ptr     <= 3'd0;
        input_read_ptr_core_aclk <= 3'd0;
        core_s_axis_tready_reg   <= 1'b0;
    end
    else begin
        // Destination-domain copy of the core_cclk read pointer.
        input_read_ptr_core_aclk <= input_read_ptr;

        if (input_push) begin
            input_mem[input_write_ptr[1:0]] <=
                {core_s_axis_tlast, core_s_axis_tdata};
            input_write_ptr <= input_write_ptr + 3'd1;
        end

        // Registered AXI ready. The after-push calculation permits a transfer
        // on the cycle that consumes the final free FIFO entry.
        core_s_axis_tready_reg <= !input_full_after_push;
    end
end

reg [8:0] input_stage_payload;
reg       input_stage_valid;

wire input_stage_consume;
wire input_stage_can_load;
wire input_stage_load;
wire start_new_pixel;

assign input_stage_consume = start_new_pixel;
assign input_stage_can_load = !input_stage_valid || input_stage_consume;
assign input_stage_load = input_stage_can_load && !input_fifo_empty_core_cclk;

always @(posedge core_cclk or negedge core_cresetn) begin
    if (!core_cresetn) begin
        input_write_ptr_core_cclk <= 3'd0;
        input_read_ptr       <= 3'd0;
        input_stage_payload  <= 9'd0;
        input_stage_valid    <= 1'b0;
    end
    else begin
        // Destination-domain copy of the AXI write pointer.
        input_write_ptr_core_cclk <= input_write_ptr;

        if (input_stage_load) begin
            input_stage_payload <= input_mem[input_read_ptr[1:0]];
            input_read_ptr      <= input_read_ptr + 3'd1;
            input_stage_valid   <= 1'b1;
        end
        else if (input_stage_consume) begin
            input_stage_valid <= 1'b0;
        end
    end
end

// -------------------------------------------------------------------------
// Related-clock output FIFO: core_cclk producer, core_aclk consumer
// -------------------------------------------------------------------------

reg [8:0] output_mem [0:3];

reg [2:0] output_write_ptr;
reg [2:0] output_read_ptr;
reg [2:0] output_write_ptr_core_aclk;
reg [2:0] output_read_ptr_core_cclk;

reg [8:0] m_axis_payload_reg;
reg       core_m_axis_tvalid_reg;

wire       output_full;
wire       output_empty;
wire       output_stage_ready;
wire       output_write_en;
wire [8:0] output_write_data;

// Producer uses a core_cclk-domain copy of the consumer pointer. A stale copy can
// only keep full asserted longer; it cannot permit overflow.
assign output_full =
    (output_write_ptr[2] != output_read_ptr_core_cclk[2]) &&
    (output_write_ptr[1:0] == output_read_ptr_core_cclk[1:0]);

// Consumer uses an core_aclk-domain copy of the producer pointer. A stale copy can
// only keep empty asserted longer; it cannot permit underflow.
assign output_empty =
    (output_write_ptr_core_aclk == output_read_ptr);

assign core_m_axis_tvalid = core_m_axis_tvalid_reg;
assign core_m_axis_tdata  = m_axis_payload_reg[7:0];
assign core_m_axis_tlast  = m_axis_payload_reg[8];

assign output_stage_ready =
    !core_m_axis_tvalid_reg || core_m_axis_tready;

always @(posedge core_aclk or negedge core_aresetn) begin
    if (!core_aresetn) begin
        output_read_ptr       <= 3'd0;
        output_write_ptr_core_aclk <= 3'd0;
        m_axis_payload_reg    <= 9'd0;
        core_m_axis_tvalid_reg     <= 1'b0;
    end
    else begin
        output_write_ptr_core_aclk <= output_write_ptr;

        if (output_stage_ready) begin
            if (!output_empty) begin
                m_axis_payload_reg <= output_mem[output_read_ptr[1:0]];
                core_m_axis_tvalid_reg  <= 1'b1;
                output_read_ptr    <= output_read_ptr + 3'd1;
            end
            else begin
                core_m_axis_tvalid_reg <= 1'b0;
            end
        end
    end
end

always @(posedge core_cclk or negedge core_cresetn) begin
    if (!core_cresetn) begin
        output_write_ptr     <= 3'd0;
        output_read_ptr_core_cclk <= 3'd0;
    end
    else begin
        output_read_ptr_core_cclk <= output_read_ptr;

        if (output_write_en) begin
            output_mem[output_write_ptr[1:0]] <= output_write_data;
            output_write_ptr <= output_write_ptr + 3'd1;
        end
    end
end

// -------------------------------------------------------------------------
// One-RF, three-core_cclk Method-3 LBP datapath
// -------------------------------------------------------------------------

reg [1:0] state;

reg [6:0] input_row;
reg [6:0] input_col;

reg [7:0] token_data;
reg       token_last;

// RF word format: {odd_pixel, even_pixel}.
reg [7:0] even_pixel;
reg [7:0] right_value;
reg [7:0] right_even_cache;

// The high byte of an UP pair is retained for the following odd pixel. The
// even pixel compares directly against rf_q[7:0].
reg [7:0] up_odd_cache;

reg [7:0] prev;
reg [7:0] curr;
reg [7:0] next;

reg [7:0] prev_lbp;
reg [7:0] curr_lbp;
reg [7:0] next_lbp;

// -------------------------------------------------------------------------
// Pipelined comparator partial results
//
// Each 8-bit unsigned >= comparator is split into:
//   high-nibble greater, high-nibble equal, low-nibble greater-or-equal.
// ST_READY captures these short 4-bit comparisons. Later phases only merge
// the three one-bit results with: hi_gt | (hi_eq & lo_ge).
// -------------------------------------------------------------------------

// RIGHT >= old next, and old next >= RIGHT.
reg right_next_hi_gt;
reg right_next_hi_eq;
reg right_next_lo_ge;
reg next_right_hi_gt;
reg next_right_hi_eq;
reg next_right_lo_ge;

// UP >= shifted next/curr/prev.
reg up_next_hi_gt;
reg up_next_hi_eq;
reg up_next_lo_ge;
reg up_curr_hi_gt;
reg up_curr_hi_eq;
reg up_curr_lo_ge;
reg up_prev_hi_gt;
reg up_prev_hi_eq;
reg up_prev_lo_ge;

// DOWN/current token >= shifted next/curr/prev.
reg down_next_hi_gt;
reg down_next_hi_eq;
reg down_next_lo_ge;
reg down_curr_hi_gt;
reg down_curr_hi_eq;
reg down_curr_lo_ge;
reg down_prev_hi_gt;
reg down_prev_hi_eq;
reg down_prev_lo_ge;

wire right_ge_next_result;
wire next_ge_right_result;
wire up_ge_next_result;
wire up_ge_curr_result;
wire up_ge_prev_result;
wire down_ge_next_result;
wire down_ge_curr_result;
wire down_ge_prev_result;

assign right_ge_next_result =
    right_next_hi_gt || (right_next_hi_eq && right_next_lo_ge);
assign next_ge_right_result =
    next_right_hi_gt || (next_right_hi_eq && next_right_lo_ge);

assign up_ge_next_result =
    up_next_hi_gt || (up_next_hi_eq && up_next_lo_ge);
assign up_ge_curr_result =
    up_curr_hi_gt || (up_curr_hi_eq && up_curr_lo_ge);
assign up_ge_prev_result =
    up_prev_hi_gt || (up_prev_hi_eq && up_prev_lo_ge);

assign down_ge_next_result =
    down_next_hi_gt || (down_next_hi_eq && down_next_lo_ge);
assign down_ge_curr_result =
    down_curr_hi_gt || (down_curr_hi_eq && down_curr_lo_ge);
assign down_ge_prev_result =
    down_prev_hi_gt || (down_prev_hi_eq && down_prev_lo_ge);

// -------------------------------------------------------------------------
// Circular RF pointers
// -------------------------------------------------------------------------

// pair_write_ptr points at the pair currently being assembled.
// right_pair_ptr = pair_write_ptr + 73 (mod 136)
// up_pair_ptr    = pair_write_ptr +  8 (mod 136)
reg [7:0] pair_write_ptr;
reg [7:0] right_pair_ptr;
reg [7:0] up_pair_ptr;

wire [7:0] pair_write_ptr_next;
wire [7:0] right_pair_ptr_next;
wire [7:0] up_pair_ptr_next;

assign pair_write_ptr_next =
    (pair_write_ptr == 8'd135) ? 8'd0 : pair_write_ptr + 8'd1;
assign right_pair_ptr_next =
    (right_pair_ptr == 8'd135) ? 8'd0 : right_pair_ptr + 8'd1;
assign up_pair_ptr_next =
    (up_pair_ptr == 8'd135) ? 8'd0 : up_pair_ptr + 8'd1;

// -------------------------------------------------------------------------
// Completed-pixel and packet-tail control
// -------------------------------------------------------------------------

reg pixel_ready;
reg ready_frame_last;
reg ready_emit;
reg ready_interior;

reg       flushing;
reg [1:0] flush_phase;
reg [3:0] flush_count_lo;
reg [2:0] flush_count_hi;
reg       flush_last;

wire ready_generates_output;
wire ready_is_interior;
wire [7:0] ready_lbp_value;
wire ready_can_commit;
wire ready_slot_available;
wire compute_output_push;
wire flush_output_push;
wire flush_count_is_127;

assign ready_generates_output = pixel_ready && ready_emit;
assign ready_is_interior      = pixel_ready && ready_interior;

// IC Contest ordering: bit 7..0 = BR, B, BL, R, L, TR, T, TL.
assign ready_lbp_value = prev_lbp;

assign ready_can_commit =
    pixel_ready && (!ready_generates_output || !output_full);

assign ready_slot_available =
    !pixel_ready || (ready_can_commit && !ready_frame_last);

// Full-cycle control path. No negedge start-grant register is used.
assign start_new_pixel =
    (state == ST_READY) &&
    !flushing &&
    input_stage_valid &&
    ready_slot_available;

assign compute_output_push =
    (state == ST_READY) && ready_can_commit && ready_generates_output;

assign flush_output_push =
    flushing && (flush_phase == 2'd2) && !output_full;

assign output_write_en = compute_output_push || flush_output_push;

assign output_write_data = compute_output_push
                         ? {1'b0,
                            ready_is_interior ? ready_lbp_value : 8'd0}
                         : {flush_last, 8'd0};

assign flush_count_is_127 =
    (flush_count_hi == 3'd7) && (flush_count_lo == 4'd15);

// -------------------------------------------------------------------------
// RF command pipeline
//
// A core_cclk posedge prepares the command in rf_cmd_*_pre.  These registers drive
// the physical RF pins directly, and the RF samples the command at the next
// core_cclk posedge.  Thus A/CEN/WEN/D receive approximately one full core_cclk cycle of
// setup time instead of the former negedge-to-posedge half-cycle path.
//
// Address/data are prepared independently of start_new_pixel; only
// rf_cmd_valid_pre contains the output-backpressure grant path.
// -------------------------------------------------------------------------

wire [15:0] rf_q;

reg        rf_cmd_valid_pre;
reg        rf_cmd_wen_pre;
reg [7:0]  rf_cmd_addr_pre;
reg [15:0] rf_cmd_data_pre;

wire        rf_cen;
wire        rf_wen;
wire [7:0]  rf_addr;
wire [15:0] rf_wdata;

assign rf_cen   = ~rf_cmd_valid_pre;
assign rf_wen   =  rf_cmd_wen_pre;
assign rf_addr  =  rf_cmd_addr_pre;
assign rf_wdata =  rf_cmd_data_pre;

always @(posedge core_cclk or negedge core_cresetn) begin
    if (!core_cresetn) begin
        rf_cmd_valid_pre <= 1'b0;
        rf_cmd_wen_pre   <= 1'b1;
        rf_cmd_addr_pre  <= 8'd0;
        rf_cmd_data_pre  <= 16'd0;
    end
    else begin
        rf_cmd_valid_pre <= 1'b0;
        rf_cmd_wen_pre   <= 1'b1;

        case (state)
            ST_READY: begin
                // Address and data are unconditional, keeping start/backpressure
                // out of the wide address and write-data register inputs.
                rf_cmd_addr_pre <= input_col[0]
                                 ? pair_write_ptr
                                 : right_pair_ptr;
                rf_cmd_data_pre <= {
                    input_stage_payload[7:0], even_pixel
                };
                rf_cmd_wen_pre <= input_col[0] ? 1'b0 : 1'b1;
                rf_cmd_valid_pre <= start_new_pixel;
            end

            ST_PHASE1: begin
                // For an odd token, the pair write has just occurred at this
                // posedge. Read the UP pair corresponding to the incremented
                // circular pointer at the next ST_PHASE2 posedge.
                rf_cmd_addr_pre  <= up_pair_ptr_next;
                rf_cmd_data_pre  <= 16'd0;
                rf_cmd_wen_pre   <= 1'b1;
                rf_cmd_valid_pre <= input_col[0];
            end

            default: begin
                // No command during ST_PHASE2. The register values may hold;
                // CEN is inactive because valid is zero.
            end
        endcase
    end
end

rf136x16m4h3v2 line_buffer (
    .Q   (rf_q),
    .CLK (core_cclk),
    .CEN (rf_cen),
    .WEN (rf_wen),
    .A   (rf_addr),
    .D   (rf_wdata)
);

// The UP sample for the current token is selected before the ST_READY edge.
// For an even column it comes directly from the RF read completed by the
// preceding odd token. For an odd column it comes from the saved high byte.
wire [7:0] up_compare_sample;
assign up_compare_sample = input_col[0] ? up_odd_cache : rf_q[7:0];

// -------------------------------------------------------------------------
// Main three-phase datapath
// -------------------------------------------------------------------------

always @(posedge core_cclk or negedge core_cresetn) begin
    if (!core_cresetn) begin
        state            <= ST_READY;
        input_row        <= 7'd0;
        input_col        <= 7'd0;
        token_data       <= 8'd0;
        token_last       <= 1'b0;
        even_pixel       <= 8'd0;
        right_value      <= 8'd0;
        right_even_cache <= 8'd0;
        up_odd_cache     <= 8'd0;

        prev             <= 8'd0;
        curr             <= 8'd0;
        next             <= 8'd0;
        prev_lbp         <= 8'd0;
        curr_lbp         <= 8'd0;
        next_lbp         <= 8'd0;

        right_next_hi_gt <= 1'b0;
        right_next_hi_eq <= 1'b0;
        right_next_lo_ge <= 1'b0;
        next_right_hi_gt <= 1'b0;
        next_right_hi_eq <= 1'b0;
        next_right_lo_ge <= 1'b0;

        up_next_hi_gt    <= 1'b0;
        up_next_hi_eq    <= 1'b0;
        up_next_lo_ge    <= 1'b0;
        up_curr_hi_gt    <= 1'b0;
        up_curr_hi_eq    <= 1'b0;
        up_curr_lo_ge    <= 1'b0;
        up_prev_hi_gt    <= 1'b0;
        up_prev_hi_eq    <= 1'b0;
        up_prev_lo_ge    <= 1'b0;

        down_next_hi_gt  <= 1'b0;
        down_next_hi_eq  <= 1'b0;
        down_next_lo_ge  <= 1'b0;
        down_curr_hi_gt  <= 1'b0;
        down_curr_hi_eq  <= 1'b0;
        down_curr_lo_ge  <= 1'b0;
        down_prev_hi_gt  <= 1'b0;
        down_prev_hi_eq  <= 1'b0;
        down_prev_lo_ge  <= 1'b0;

        pair_write_ptr   <= 8'd0;
        right_pair_ptr   <= 8'd73;
        up_pair_ptr      <= 8'd8;

        pixel_ready      <= 1'b0;
        ready_frame_last <= 1'b0;
        ready_emit       <= 1'b0;
        ready_interior   <= 1'b0;

        flushing         <= 1'b0;
        flush_phase      <= 2'd0;
        flush_count_lo   <= 4'd0;
        flush_count_hi   <= 3'd0;
        flush_last       <= 1'b0;
    end
    else begin
        case (state)
            ST_READY: begin
                if (ready_can_commit) begin
                    pixel_ready <= 1'b0;

                    if (ready_frame_last) begin
                        flushing       <= 1'b1;
                        flush_phase    <= 2'd0;
                        flush_count_lo <= 4'd0;
                        flush_count_hi <= 3'd0;
                        flush_last     <= 1'b0;
                    end
                end

                if (start_new_pixel) begin
                    token_data <= input_stage_payload[7:0];
                    token_last <= input_stage_payload[8];

                    if (!input_col[0]) begin
                        even_pixel   <= input_stage_payload[7:0];
                        up_odd_cache <= rf_q[15:8];
                    end

                    // RIGHT comparisons. The results are merged in ST_PHASE1.
                    right_next_hi_gt <=
                        (right_value[7:4] > next[7:4]);
                    right_next_hi_eq <=
                        (right_value[7:4] == next[7:4]);
                    right_next_lo_ge <=
                        (right_value[3:0] >= next[3:0]);

                    next_right_hi_gt <=
                        (next[7:4] > right_value[7:4]);
                    next_right_hi_eq <=
                        (next[7:4] == right_value[7:4]);
                    next_right_lo_ge <=
                        (next[3:0] >= right_value[3:0]);

                    // Values after this ST_READY edge are:
                    //   next = right_value, curr = old next, prev = old curr.
                    // UP partial comparisons use those corresponding sources.
                    up_next_hi_gt <=
                        (up_compare_sample[7:4] > right_value[7:4]);
                    up_next_hi_eq <=
                        (up_compare_sample[7:4] == right_value[7:4]);
                    up_next_lo_ge <=
                        (up_compare_sample[3:0] >= right_value[3:0]);

                    up_curr_hi_gt <=
                        (up_compare_sample[7:4] > next[7:4]);
                    up_curr_hi_eq <=
                        (up_compare_sample[7:4] == next[7:4]);
                    up_curr_lo_ge <=
                        (up_compare_sample[3:0] >= next[3:0]);

                    up_prev_hi_gt <=
                        (up_compare_sample[7:4] > curr[7:4]);
                    up_prev_hi_eq <=
                        (up_compare_sample[7:4] == curr[7:4]);
                    up_prev_lo_ge <=
                        (up_compare_sample[3:0] >= curr[3:0]);

                    // DOWN partial comparisons use the incoming AXI pixel.
                    down_next_hi_gt <=
                        (input_stage_payload[7:4] > right_value[7:4]);
                    down_next_hi_eq <=
                        (input_stage_payload[7:4] == right_value[7:4]);
                    down_next_lo_ge <=
                        (input_stage_payload[3:0] >= right_value[3:0]);

                    down_curr_hi_gt <=
                        (input_stage_payload[7:4] > next[7:4]);
                    down_curr_hi_eq <=
                        (input_stage_payload[7:4] == next[7:4]);
                    down_curr_lo_ge <=
                        (input_stage_payload[3:0] >= next[3:0]);

                    down_prev_hi_gt <=
                        (input_stage_payload[7:4] > curr[7:4]);
                    down_prev_hi_eq <=
                        (input_stage_payload[7:4] == curr[7:4]);
                    down_prev_lo_ge <=
                        (input_stage_payload[3:0] >= curr[3:0]);

                    // Shift previously completed horizontal partial bits.
                    curr_lbp[3] <= next_lbp[3];
                    curr_lbp[0] <= next_lbp[0];
                    curr_lbp[5] <= next_lbp[5];

                    prev_lbp[3] <= curr_lbp[3];
                    prev_lbp[0] <= curr_lbp[0];
                    prev_lbp[5] <= curr_lbp[5];
                    prev_lbp[4] <= curr_lbp[4];
                    prev_lbp[1] <= curr_lbp[1];
                    prev_lbp[6] <= curr_lbp[6];

                    next <= right_value;
                    curr <= next;
                    prev <= curr;

                    state <= ST_PHASE1;
                end
            end

            ST_PHASE1: begin
                // Merge the pipelined RIGHT and UP comparisons.
                curr_lbp[4] <= right_ge_next_result;
                next_lbp[3] <= next_ge_right_result;

                next_lbp[0] <= up_ge_next_result;
                curr_lbp[1] <= up_ge_curr_result;
                prev_lbp[2] <= up_ge_prev_result;

                if (input_col[0]) begin
                    // The odd pair write is active on this edge. Advance all
                    // three equivalent circular pointers together.
                    pair_write_ptr <= pair_write_ptr_next;
                    right_pair_ptr <= right_pair_ptr_next;
                    up_pair_ptr    <= up_pair_ptr_next;

                    // High byte captured by the preceding even RIGHT read.
                    right_value <= right_even_cache;
                end

                state <= ST_PHASE2;
            end

            ST_PHASE2: begin
                // Merge the pipelined DOWN comparisons. After this edge,
                // prev_lbp is complete for center g[n-129].
                next_lbp[5] <= down_ge_next_result;
                curr_lbp[6] <= down_ge_curr_result;
                prev_lbp[7] <= down_ge_prev_result;

                if (!input_col[0]) begin
                    // RIGHT pair read during the even token's ST_PHASE1 edge.
                    right_value      <= rf_q[7:0];
                    right_even_cache <= rf_q[15:8];
                end

                ready_emit <=
                    (input_row >= 7'd2) ||
                    ((input_row == 7'd1) && (input_col >= 7'd1));

                ready_interior <=
                    (input_row >= 7'd2) && (input_col >= 7'd2);

                ready_frame_last <=
                    token_last ||
                    ((input_row == 7'd127) && (input_col == 7'd127));

                pixel_ready <= 1'b1;

                if (token_last ||
                    ((input_row == 7'd127) && (input_col == 7'd127))) begin
                    input_row <= 7'd0;
                    input_col <= 7'd0;
                end
                else if (input_col == 7'd127) begin
                    input_row <= input_row + 7'd1;
                    input_col <= 7'd0;
                end
                else begin
                    input_col <= input_col + 7'd1;
                end

                state <= ST_READY;
            end

            default: begin
                state       <= ST_READY;
                pixel_ready <= 1'b0;
            end
        endcase

        // Packet tail: row-126 right border plus all 128 bottom-border beats.
        // One output is attempted every three core_cclk cycles.
        if (flushing) begin
            if (flush_phase == 2'd2) begin
                if (!output_full) begin
                    flush_phase <= 2'd0;

                    if (flush_last) begin
                        // The final TLAST beat is written on this same edge.
                        flushing       <= 1'b0;
                        flush_count_lo <= 4'd0;
                        flush_count_hi <= 3'd0;
                        flush_last     <= 1'b0;
                    end
                    else if (flush_count_is_127) begin
                        // Beat 127 is written now; the following beat is the
                        // extra TLAST beat.
                        flush_last <= 1'b1;
                    end
                    else if (flush_count_lo == 4'd15) begin
                        flush_count_lo <= 4'd0;
                        flush_count_hi <= flush_count_hi + 3'd1;
                    end
                    else begin
                        flush_count_lo <= flush_count_lo + 4'd1;
                    end
                end
            end
            else begin
                flush_phase <= flush_phase + 2'd1;
            end
        end
    end
end

endmodule

`default_nettype wire
