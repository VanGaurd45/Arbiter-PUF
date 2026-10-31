`timescale 1ns / 1ps
// ============================================================================
// 1. FDCE pairwise capture -- independent reset.
// ============================================================================
module xnor_xor_filter (
    input wire path_i,
    input wire path_j,
    input wire arbiter_reset,
    output wire i_beats_j
);
    // A rising path_j samples path_i. Reset is independent of both race paths.
    (* DONT_TOUCH = "TRUE" *) FDCE #(.INIT(1'b0)) arbiter_ff (
        .Q(i_beats_j), .C(path_j), .CE(1'b1),
        .CLR(arbiter_reset), .D(path_i)
    );
endmodule

// ============================================================================
// 2a. Validity-aware, strict-order consensus decoder 
// ============================================================================
module pairwise_rank_decoder (
    input wire [5:0] raw_comp,
    input wire [5:0] known_mask,
    output reg [5:0] final_comp,
    output reg valid_out
);
    function [5:0] strict_order;
        input integer index;
        begin
            case (index)
                 0: strict_order = 6'b111111; // ABCD
                 1: strict_order = 6'b111110; // ABDC
                 2: strict_order = 6'b111011; // ACBD
                 3: strict_order = 6'b111001; // ACDB
                 4: strict_order = 6'b111100; // ADBC
                 5: strict_order = 6'b111000; // ADCB
                 6: strict_order = 6'b011111; // BACD
                 7: strict_order = 6'b011110; // BADC
                 8: strict_order = 6'b001111; // BCAD
                 9: strict_order = 6'b000111; // BCDA
                10: strict_order = 6'b010110; // BDAC
                11: strict_order = 6'b000110; // BDCA
                12: strict_order = 6'b101011; // CABD
                13: strict_order = 6'b101001; // CADB
                14: strict_order = 6'b001011; // CBAD
                15: strict_order = 6'b000011; // CBDA
                16: strict_order = 6'b100001; // CDAB
                17: strict_order = 6'b000001; // CDBA
                18: strict_order = 6'b110100; // DABC
                19: strict_order = 6'b110000; // DACB
                20: strict_order = 6'b010100; // DBAC
                21: strict_order = 6'b000100; // DBCA
                22: strict_order = 6'b100000; // DCAB
                23: strict_order = 6'b000000; // DCBA
                default: strict_order = 6'b000000;
            endcase
        end
    endfunction

    function [2:0] encode_order;
        input [5:0] c;
        begin
            encode_order[2] = c[5];
            encode_order[1] = c[0];
            encode_order[0] = c[5] ? (c[0] ? c[4] : c[3])
                                    : (c[0] ? c[2] : c[1]);
        end
    endfunction

    integer k;
    reg found;
    reg disagreement;
    reg [5:0] candidate;
    reg [5:0] representative;
    reg [2:0] reference_code;

    always @* begin
        found = 1'b0;
        disagreement = 1'b0;
        candidate = 6'b0;
        representative = 6'b0;
        reference_code = 3'b0;
        final_comp = 6'b0;
        valid_out = 1'b0;

        for (k = 0; k < 24; k = k + 1) begin
            candidate = strict_order(k);
            if (((candidate ^ raw_comp) & known_mask) == 6'b0) begin
                if (!found) begin
                    found = 1'b1;
                    representative = candidate;
                    reference_code = encode_order(candidate);
                end else if (encode_order(candidate) != reference_code) begin
                    disagreement = 1'b1;
                end
            end
        end

        if (found && !disagreement) begin
            valid_out = 1'b1;
            final_comp = representative;
        end
    end
endmodule

// ============================================================================
// 2b. Raw pairwise capture -- decode only after synchronized snapshot.
// ============================================================================
module pairwise_matrix (
    input wire A, B, C, D,
    input wire arbiter_reset,
    output wire [5:0] raw_comp
);
    xnor_xor_filter f_AB (.path_i(A), .path_j(B), .arbiter_reset(arbiter_reset), .i_beats_j(raw_comp[5]));
    xnor_xor_filter f_AC (.path_i(A), .path_j(C), .arbiter_reset(arbiter_reset), .i_beats_j(raw_comp[4]));
    xnor_xor_filter f_AD (.path_i(A), .path_j(D), .arbiter_reset(arbiter_reset), .i_beats_j(raw_comp[3]));
    xnor_xor_filter f_BC (.path_i(B), .path_j(C), .arbiter_reset(arbiter_reset), .i_beats_j(raw_comp[2]));
    xnor_xor_filter f_BD (.path_i(B), .path_j(D), .arbiter_reset(arbiter_reset), .i_beats_j(raw_comp[1]));
    xnor_xor_filter f_CD (.path_i(C), .path_j(D), .arbiter_reset(arbiter_reset), .i_beats_j(raw_comp[0]));
endmodule

// ============================================================================
// 3.(4,3) encoder 
// ============================================================================
module arbiter_4_3 (
    input wire [5:0] comparisons,
    output wire [2:0] puf_response
);
    wire AB = comparisons[5];
    wire AC = comparisons[4];
    wire AD = comparisons[3];
    wire BC = comparisons[2];
    wire BD = comparisons[1];
    wire CD = comparisons[0];

    assign puf_response[2] = AB;
    assign puf_response[1] = CD;
    assign puf_response[0] = (AB & CD) ? AC :
                             (AB & ~CD) ? AD :
                             (~AB & CD) ? BC : BD;
endmodule

// ============================================================================
// 4. structural delay chain 
// ============================================================================
module arbiter_chain #(
    parameter STAGES = 64,
    parameter integer ROUTE_BIAS = 10000,
    parameter integer TOP_MUL = 3,
    parameter integer TOP_MOD = 7,
    parameter integer BOT_MUL = 5,
    parameter integer BOT_MOD = 7
)(
    input wire pulse_in,
    input wire [STAGES-1:0] challenge,
    output wire out_top,
    output wire out_bot
);
    (* DONT_TOUCH = "TRUE" *) wire top_net [STAGES:0];
    (* DONT_TOUCH = "TRUE" *) wire bot_net [STAGES:0];

    assign top_net[0] = pulse_in;
    assign bot_net[0] = pulse_in;

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : mux_stage
            (* DONT_TOUCH = "TRUE" *) wire top_mux_wire;
            (* DONT_TOUCH = "TRUE" *) wire bot_mux_wire;
            LUT3 #(.INIT(8'hCA)) top_mux_inst (
                .O(top_mux_wire), .I0(top_net[i]),
                .I1(bot_net[i]), .I2(challenge[i])
            );
            LUT3 #(.INIT(8'hAC)) bot_mux_inst (
                .O(bot_mux_wire), .I0(top_net[i]),
                .I1(bot_net[i]), .I2(challenge[i])
            );
            assign top_net[i+1] = top_mux_wire;
            assign bot_net[i+1] = bot_mux_wire;
        end
    endgenerate
    assign out_top = top_net[STAGES];
    assign out_bot = bot_net[STAGES];
endmodule

// ============================================================================
// 5. PUF wrapper 
// ============================================================================
(* KEEP_HIERARCHY = "TRUE" *)
module puf_structural_top #(
    parameter integer BLOCK_ID = 0
)(
    input wire challenge_pulse,
    input wire arbiter_reset,
    input wire [127:0] challenge_bits,
    output wire [5:0] raw_comp,
    output wire [3:0] path_levels
);
    wire path_A, path_B, path_C, path_D;
    wire [127:0] challenge_bits_rev;
    genvar k;
    generate
        for (k = 0; k < 128; k = k + 1) begin : rev
            assign challenge_bits_rev[k] = challenge_bits[127-k];
        end
    endgenerate

    localparam integer ROT_AMOUNT = ((BLOCK_ID * 7) % 31) + 5;
    wire [127:0] challenge_bits_rot = (challenge_bits_rev << ROT_AMOUNT) |
                                       (challenge_bits_rev >> (128 - ROT_AMOUNT));
    localparam [127:0] BLOCK_MASK = {(BLOCK_ID*32'hD1B54A35 + 32'h9E3779B9),
                                      (BLOCK_ID*32'h9E3779B1 + 32'h85EBCA6B),
                                      (BLOCK_ID*32'h85EBCA6B + 32'hC2B2AE35),
                                      (BLOCK_ID*32'hC2B2AE35 + 32'hD1B54A35)};
    wire [127:0] challenge_bits_cd = challenge_bits_rot ^ BLOCK_MASK;

    arbiter_chain #(
        .STAGES(64), .ROUTE_BIAS(10000 + BLOCK_ID*173),
        .TOP_MUL(2 + (BLOCK_ID % 4)), .TOP_MOD(7),
        .BOT_MUL(2 + ((BLOCK_ID + 1) % 4)), .BOT_MOD(7)
    ) chain_AB (
        .pulse_in(challenge_pulse), .challenge(challenge_bits[63:0]),
        .out_top(path_A), .out_bot(path_B)
    );
    arbiter_chain #(
        .STAGES(64), .ROUTE_BIAS(10000 + BLOCK_ID*173),
        .TOP_MUL(2 + ((BLOCK_ID + 2) % 4)), .TOP_MOD(7),
        .BOT_MUL(2 + ((BLOCK_ID + 3) % 4)), .BOT_MOD(7)
    ) chain_CD (
        .pulse_in(challenge_pulse), .challenge(challenge_bits_cd[63:0]),
        .out_top(path_C), .out_bot(path_D)
    );

    (* DONT_TOUCH = "TRUE" *) wire butterfly_ctrl = challenge_bits[31];
    (* DONT_TOUCH = "TRUE" *) wire path_A_routed = butterfly_ctrl ? path_C : path_A;
    (* DONT_TOUCH = "TRUE" *) wire path_B_routed = butterfly_ctrl ? path_D : path_B;
    (* DONT_TOUCH = "TRUE" *) wire path_C_routed = butterfly_ctrl ? path_A : path_C;
    (* DONT_TOUCH = "TRUE" *) wire path_D_routed = butterfly_ctrl ? path_B : path_D;
    assign path_levels = {path_A_routed, path_B_routed, path_C_routed, path_D_routed};
    pairwise_matrix comparator_matrix (
        .A(path_A_routed), .B(path_B_routed), .C(path_C_routed), .D(path_D_routed),
        .arbiter_reset(arbiter_reset), .raw_comp(raw_comp)
    );
endmodule

// ============================================================================
// 6. PUF array 
// ============================================================================
module cryptographic_puf_top #(
    parameter NUM_BLOCKS = 21
)(
    input wire challenge_pulse,
    input wire arbiter_reset,
    input wire [(NUM_BLOCKS*128)-1:0] master_challenge,
    output wire [(NUM_BLOCKS*6)-1:0] aggregated_comparisons,
    output wire [(NUM_BLOCKS*4)-1:0] aggregated_path_levels
);
    genvar i;
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : puf_array
            puf_structural_top #(.BLOCK_ID(i)) individual_puf (
                .challenge_pulse(challenge_pulse),
                .arbiter_reset(arbiter_reset),
                .challenge_bits(master_challenge[i*128 +: 128]),
                .raw_comp(aggregated_comparisons[i*6 +: 6]),
                .path_levels(aggregated_path_levels[i*4 +: 4])
            );
        end
    endgenerate
endmodule

