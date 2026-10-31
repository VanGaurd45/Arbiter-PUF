`timescale 1ns / 1ps

module puf_axi_core #(
    parameter integer SETTLE_CYCLES = 32,
    parameter integer ARM_CYCLES = 8,
    parameter integer RACE_CYCLES = 64,
    parameter integer DECODE_CYCLES = 4,
    parameter integer DRAIN_CYCLES = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire ack,
    input wire [127:0] puf_challenge,
    output reg [62:0] puf_response,
    output reg [20:0] puf_valid,
    output reg busy,
    output reg done,
    output reg error,
    output reg rejected,
    output reg [2:0] error_code,
    output reg [23:0] sequence_id
);
    localparam IDLE=0, SETTLE=1, ARM=2, RACE=3, DECODE=4, DRAIN=5;

    reg [2:0] state;
    reg [31:0] count;
    reg [127:0] active_challenge;
    reg launch_pulse;
    reg reset_hold;

    wire arbiter_reset = reset_hold | ~rst_n;
    wire [125:0] raw_comp;
    wire [83:0] raw_levels;

    cryptographic_puf_top #(.NUM_BLOCKS(21)) puf_array (
        .challenge_pulse(launch_pulse),
        .arbiter_reset(arbiter_reset),
        .master_challenge({21{active_challenge}}),
        .aggregated_comparisons(raw_comp),
        .aggregated_path_levels(raw_levels)
    );


    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [125:0] comp_meta, comp_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [83:0] levels_meta, levels_sync;

    reg [125:0] comp_previous;
    reg [83:0] levels_previous;

    always @(posedge clk) begin
        comp_meta       <= raw_comp;
        comp_sync       <= comp_meta;
        comp_previous   <= comp_sync;
        levels_meta     <= raw_levels;
        levels_sync     <= levels_meta;
        levels_previous <= levels_sync;
    end

    reg [125:0] captured_comp;
    reg [125:0] captured_mask;
    wire [62:0] decoded_response;
    wire [20:0] decoded_valid;

    genvar b;
    generate
        for (b=0; b<21; b=b+1) begin : decode_blocks
            wire [5:0] representative;
            pairwise_rank_decoder decoder (
                .raw_comp(captured_comp[b*6 +: 6]),
                .known_mask(captured_mask[b*6 +: 6]),
                .final_comp(representative),
                .valid_out(decoded_valid[b])
            );
            arbiter_4_3 encoder (
                .comparisons(representative),
                .puf_response(decoded_response[b*3 +: 3])
            );
        end
    endgenerate

    reg [62:0] pending_response;
    reg [20:0] pending_valid;
    reg [2:0] pending_error;
    integer block_index;


    always @(posedge clk) begin
        case (state)
            IDLE: if (start && (!done || ack)) begin
                active_challenge <= puf_challenge;
                captured_comp <= 0;
                captured_mask <= 0;
                pending_response <= 0;
                pending_valid <= 0;
                pending_error <= 0;
            end

            SETTLE: if ((count <= 1) &&
                        !((levels_sync == 0) && (levels_previous == 0)))
                pending_error <= 1;

            ARM: if ((levels_sync != 0) || (levels_previous != 0))
                pending_error <= 1;

            RACE: if (count <= 1) begin
                captured_comp <= comp_sync;

                for (block_index=0; block_index<21;
                     block_index=block_index+1) begin
                    if ((&levels_sync[block_index*4 +: 4]) &&
                        (&levels_previous[block_index*4 +: 4]) &&
                        (comp_sync[block_index*6 +: 6] ==
                         comp_previous[block_index*6 +: 6]))
                        captured_mask[block_index*6 +: 6] <= 6'b111111;
                    else
                        captured_mask[block_index*6 +: 6] <= 6'b000000;
                end

                if (!(&levels_sync) || !(&levels_previous))
                    pending_error <= 2;
                else if (comp_sync != comp_previous)
                    pending_error <= 3;
            end

            DECODE: if (count <= 1) begin
                pending_response <= decoded_response;
                pending_valid <= decoded_valid;
                if ((pending_error == 0) && !(&decoded_valid))
                    pending_error <= 4;
            end

            DRAIN: begin
       
            end

            default: begin
                pending_response <= 0;
                pending_valid <= 0;
                pending_error <= 6;
            end
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            launch_pulse <= 0;
            reset_hold <= 1;

            puf_response <= 0;
            puf_valid <= 0;
            busy <= 0;
            done <= 0;
            error <= 0;
            rejected <= 0;
            error_code <= 0;
            sequence_id <= 0;
        end else begin
            if (ack) begin
                done <= 0;
                rejected <= 0;
            end
            if (start && (busy || (done && !ack)))
                rejected <= 1;

            case (state)
                IDLE: begin
                    launch_pulse <= 0;
                    reset_hold <= 1;
                    if (start && (!done || ack)) begin
                        busy <= 1;
                        done <= 0;
                        error <= 0;
                        error_code <= 0;
                        count <= SETTLE_CYCLES;
                        state <= SETTLE;
                    end
                end

                SETTLE: begin
                    if (count > 1)
                        count <= count - 1;
                    else if ((levels_sync == 0) &&
                             (levels_previous == 0)) begin
                        reset_hold <= 0;
                        count <= ARM_CYCLES;
                        state <= ARM;
                    end else begin
                        count <= DRAIN_CYCLES;
                        state <= DRAIN;
                    end
                end

                ARM: begin
                    if ((levels_sync != 0) ||
                        (levels_previous != 0)) begin
                        reset_hold <= 1;
                        count <= DRAIN_CYCLES;
                        state <= DRAIN;
                    end else if (count > 1) begin
                        count <= count - 1;
                    end else begin
                        launch_pulse <= 1;
                        count <= RACE_CYCLES;
                        state <= RACE;
                    end
                end

                RACE: begin
                    if (count > 1)
                        count <= count - 1;
                    else begin
                        count <= DECODE_CYCLES;
                        state <= DECODE;
                    end
                end

                DECODE: begin
                    if (count > 1)
                        count <= count - 1;
                    else begin
                        launch_pulse <= 0;
                        reset_hold <= 1;
                        count <= DRAIN_CYCLES;
                        state <= DRAIN;
                    end
                end

                DRAIN: begin
                    launch_pulse <= 0;
                    reset_hold <= 1;
                    if (count > 1) begin
                        count <= count - 1;
                    end else begin
                        if ((levels_sync == 0) &&
                            (levels_previous == 0)) begin
                            puf_response <= pending_response;
                            puf_valid <= pending_valid;
                            error <= (pending_error != 0);
                            error_code <= pending_error;
                        end else begin
                            puf_response <= 0;
                            puf_valid <= 0;
                            error <= 1;
                            error_code <= 5;
                        end
                        sequence_id <= sequence_id + 24'd1;
                        busy <= 0;
                        done <= 1;
                        state <= IDLE;
                    end
                end

                default: begin
                    launch_pulse <= 0;
                    reset_hold <= 1;
                    busy <= 1;
                    count <= DRAIN_CYCLES;
                    state <= DRAIN;
                end
            endcase
        end
    end

    // synthesis translate_off
    initial begin
        if (SETTLE_CYCLES < 4 || ARM_CYCLES < 4 ||
            RACE_CYCLES < 4 || DECODE_CYCLES < 1 ||
            DRAIN_CYCLES < 4)
            $fatal(1, "Invalid PUF wait parameters");
    end
    // synthesis translate_on
endmodule
