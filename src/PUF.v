////`timescale 1ps / 1ps


//  **************************************************************************
//  THIS IS THE MAIN BEHAVIORAL CODE. DONT CHANGE IT
//  **************************************************************************


////// ============================================================================
////// 1. XNOR-XOR Pairwise Filter
////// (Evaluates two paths at the evaluation instant. Suppresses near-ties.)
////// (Gives out which of the 2 i/ps wins (also if its a decisive win))
////// ============================================================================
////module xnor_xor_filter (
////    input wire path_i,
////    input wire path_j,
////    output reg decisive_win, 
////    output reg i_beats_j     
////);
    
////    wire evaluate_now = path_i | path_j;    // Goes HIGH the moment the FIRST signal arrives
////    wire reset_now    = ~(path_i | path_j); // Goes HIGH when BOTH signals return to 0 (pulse ends)

////    // Edge-triggered block to lock in the race result
////    // Acts as a D-Latch, latching the signal decision that occurs first and not override later decisions
////    always @(posedge evaluate_now or posedge reset_now) begin
////        if (reset_now) begin
////            // Reset the filter for the next challenge
////            decisive_win <= 1'b0;
////            i_beats_j    <= 1'b0;
////        end else begin
////            // Latch the exact state at the microsecond the first signal crosses the line.
////            // If they arrive on the exact same picosecond in simulation, XOR is 0 (metastable).
////            decisive_win <= path_i ^ path_j;
////            i_beats_j    <= path_i & ~path_j;
////        end
////    end
////endmodule

////// ============================================================================
////// 2. 6-Pair Evaluation Matrix & Transitivity Rescue
////// ============================================================================
////module pairwise_matrix (
////    input wire A, B, C, D,
////    output wire [5:0] final_comp, // {AB, AC, AD, BC, BD, CD}
////    output wire valid_out         // 1 if we have enough data to encode
////);
////    wire v_AB, v_AC, v_AD, v_BC, v_BD, v_CD;
////    wire r_AB, r_AC, r_AD, r_BC, r_BD, r_CD;

////    xnor_xor_filter f_AB (.path_i(A), .path_j(B), .decisive_win(v_AB), .i_beats_j(r_AB));
////    xnor_xor_filter f_AC (.path_i(A), .path_j(C), .decisive_win(v_AC), .i_beats_j(r_AC));
////    xnor_xor_filter f_AD (.path_i(A), .path_j(D), .decisive_win(v_AD), .i_beats_j(r_AD));
////    xnor_xor_filter f_BC (.path_i(B), .path_j(C), .decisive_win(v_BC), .i_beats_j(r_BC));
////    xnor_xor_filter f_BD (.path_i(B), .path_j(D), .decisive_win(v_BD), .i_beats_j(r_BD));
////    xnor_xor_filter f_CD (.path_i(C), .path_j(D), .decisive_win(v_CD), .i_beats_j(r_CD));
    
////    //if AB is invalid (non-decisive) looking for t_A<t_C<t_B
////    wire deduced_AB = (~v_AB) ? ((r_AC & ~r_BC) ? 1'b1 : (~r_AC & r_BC) ? 1'b0 : 1'b0) : r_AB;
////    wire deduced_AC = (~v_AC) ? ((r_AB & r_BC) ? 1'b1 : (~r_AB & ~r_BC) ? 1'b0 : 1'b0) : r_AC;
////    wire deduced_AD = (~v_AD) ? ((r_AC & r_CD) ? 1'b1 : (~r_AC & ~r_CD) ? 1'b0 : 1'b0) : r_AD;
////    wire deduced_BC = (~v_BC) ? ((~r_AB & r_AC) ? 1'b1 : (r_AB & ~r_AC) ? 1'b0 : 1'b0) : r_BC;
////    wire deduced_BD = (~v_BD) ? ((r_BC & r_CD) ? 1'b1 : (~r_BC & ~r_CD) ? 1'b0 : 1'b0) : r_BD;
////    wire deduced_CD = (~v_CD) ? ((~r_AC & r_AD) ? 1'b1 : (r_AC & ~r_AD) ? 1'b0 : 1'b0) : r_CD;

////    // minimum of 4 valid wins is  required to make valid key w/o comparisons in baseless
////    assign valid_out = (v_AB + v_AC + v_AD + v_BC + v_BD + v_CD) >= 4; 
////    assign final_comp = {deduced_AB, deduced_AC, deduced_AD, deduced_BC, deduced_BD, deduced_CD};
////endmodule

////// ============================================================================
////// 3. (4,3)-Arbiter Rank Encoder
////// ============================================================================
////module arbiter_4_3 (
////    input wire [5:0] comparisons,
////    output wire [2:0] puf_response
////);
////    wire AB = comparisons[5];
////    wire AC = comparisons[4];
////    wire AD = comparisons[3];
////    wire BC = comparisons[2];
////    wire BD = comparisons[1];
////    wire CD = comparisons[0];

////    // winner of 1st block
////    assign puf_response[2] = AB;
////    //winner of 2nd block
////    assign puf_response[1] = CD;
////    //winner b/w the winners of each blocks 
////    assign puf_response[0] = (AB & CD)  ? AC :
////                             (AB & ~CD) ? AD :
////                             (~AB & CD) ? BC :
////                                          BD ;
////endmodule

////// ============================================================================
////// 4. Structural 128-Stage MUX Delay Chain
////// ============================================================================
////module arbiter_chain #(
////    parameter STAGES = 128,
////    parameter integer ROUTE_BIAS = 10000, // Base delay per chain instance
////    parameter integer TOP_MUL = 3,        // Chain-specific multiplier (top net)
////    parameter integer TOP_MOD = 7,        // Chain-specific modulo (top net)
////    parameter integer BOT_MUL = 5,        // Chain-specific multiplier (bottom net)
////    parameter integer BOT_MOD = 7         // Chain-specific modulo (bottom net)
////)(
////    input wire pulse_in,
////    input wire [STAGES-1:0] challenge,
////    output wire out_top,
////    output wire out_bot
////);
////    (* DONT_TOUCH = "TRUE" *) wire top_net [STAGES:0];
////    (* DONT_TOUCH = "TRUE" *) wire bot_net [STAGES:0];

////    assign top_net[0] = pulse_in;
////    assign bot_net[0] = pulse_in;

////    genvar i;
////    generate
////        for (i = 0; i < STAGES; i = i + 1) begin : mux_stage
////            wire t_in = top_net[i];
////            wire b_in = bot_net[i];

////            // Each chain instance has different delay parameters,
////            // so chain_AB and chain_CD delays are non related.
////            assign #(ROUTE_BIAS + ((i*TOP_MUL)%TOP_MOD)*10) top_net[i+1] = challenge[i] ? b_in : t_in;
////            assign #(ROUTE_BIAS + ((i*BOT_MUL)%BOT_MOD)*10) bot_net[i+1] = challenge[i] ? t_in : b_in;
////        end
////    endgenerate

////    assign out_top = top_net[STAGES];
////    assign out_bot = bot_net[STAGES];
////endmodule


////// ============================================================================
////// 5. Top-Level PUF Wrapper 
////// ============================================================================
////(* KEEP_HIERARCHY = "TRUE" *)
////module puf_structural_top #(
////    parameter integer BLOCK_ID = 0   
////)(
////    input wire challenge_pulse,
////    input wire [127:0] challenge_bits,
////    output wire [2:0] puf_response,
////    output wire response_valid
////);
////    wire path_A, path_B, path_C, path_D;

////    wire [127:0] challenge_bits_rev;
////    genvar k;
////    generate
////        for (k = 0; k < 128; k = k + 1) begin : rev
////            assign challenge_bits_rev[k] = challenge_bits[127-k];
////        end
////    endgenerate

////    localparam integer ROT_AMOUNT = ((BLOCK_ID * 7) % 31) + 5;
////    wire [127:0] challenge_bits_rot = (challenge_bits_rev << ROT_AMOUNT) |
////                                       (challenge_bits_rev >> (128 - ROT_AMOUNT));

////    localparam [127:0] BLOCK_MASK = {(BLOCK_ID*32'hD1B54A35 + 32'h9E3779B9),
////                                      (BLOCK_ID*32'h9E3779B1 + 32'h85EBCA6B),
////                                      (BLOCK_ID*32'h85EBCA6B + 32'hC2B2AE35),
////                                      (BLOCK_ID*32'hC2B2AE35 + 32'hD1B54A35)};

////    wire [127:0] challenge_bits_cd = challenge_bits_rot ^ BLOCK_MASK;

////    // CHAIN AB
////    arbiter_chain #(
////        .STAGES    (64), 
////        .ROUTE_BIAS(10000 + BLOCK_ID*173),
////        .TOP_MUL   (2 + (BLOCK_ID % 4)), 
////        .TOP_MOD   (7),
////        .BOT_MUL   (2 + ((BLOCK_ID + 1) % 4)),
////        .BOT_MOD   (7)
////    ) chain_AB (
////        .pulse_in(challenge_pulse),
////        .challenge(challenge_bits[63:0]),        
////        .out_top(path_A),
////        .out_bot(path_B)
////    );

////    // CHAIN CD

////    arbiter_chain #(
////        .STAGES    (64), 
////        .ROUTE_BIAS(10000 + BLOCK_ID*173), 
////        .TOP_MUL   (2 + ((BLOCK_ID + 2) % 4)),
////        .TOP_MOD   (7),
////        .BOT_MUL   (2 + ((BLOCK_ID + 3) % 4)),
////        .BOT_MOD   (7)
////    ) chain_CD (
////        .pulse_in(challenge_pulse),
////        .challenge(challenge_bits_cd[63:0]),    
////        .out_top(path_C),
////        .out_bot(path_D)
////    );

////    // -------------------------------------------------------------------------
////    // The Butterfly Crossing Stage
////    // -------------------------------------------------------------------------
////    (* DONT_TOUCH = "TRUE" *) wire butterfly_ctrl = challenge_bits[31]; 

////    (* DONT_TOUCH = "TRUE" *) wire path_A_routed = butterfly_ctrl ? path_C : path_A;
////    (* DONT_TOUCH = "TRUE" *) wire path_B_routed = butterfly_ctrl ? path_D : path_B;
////    (* DONT_TOUCH = "TRUE" *) wire path_C_routed = butterfly_ctrl ? path_A : path_C;
////    (* DONT_TOUCH = "TRUE" *) wire path_D_routed = butterfly_ctrl ? path_B : path_D;

////    wire [5:0] comp_results;
    
////    pairwise_matrix comparator_matrix (
////        .A(path_A_routed), .B(path_B_routed), .C(path_C_routed), .D(path_D_routed),
////        .final_comp(comp_results),
////        .valid_out(response_valid)
////    );

////    arbiter_4_3 rank_encoder (
////        .comparisons(comp_results),
////        .puf_response(puf_response)
////    );
////endmodule

////// Top-Level Cryptographic PUF Array

////// BLOCK_ID = i is passed into each puf_structural_top instance so every
////// block has a unique ROUTE_BIAS, MUL/MOD set, rotation amount, and XOR mask -
////// this is what makes different blocks diverge from each other even when fed
////// an identical raw challenge.
////// ============================================================================
////module cryptographic_puf_top #(
////    parameter NUM_BLOCKS = 21 // 21 blocks * 3 bits = 63 bits maximum response
////)(
////    input wire challenge_pulse,
////    input wire [(NUM_BLOCKS*128)-1:0] master_challenge, // Flat array of unique challenges
////    output wire [(NUM_BLOCKS*3)-1:0] aggregated_response,
////    output wire [NUM_BLOCKS-1:0]     aggregated_valid
////);

////    genvar i;
////    generate
////        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : puf_array
////            puf_structural_top #(
////                .BLOCK_ID(i)   // each block gets a unique identity
////            ) individual_puf (
////                .challenge_pulse(challenge_pulse),
////                .challenge_bits(master_challenge[i*128 +: 128]),
////                .puf_response(aggregated_response[i*3 +: 3]),
////                .response_valid(aggregated_valid[i])
////            );
////        end
////    endgenerate

////endmodule

////`timescale 1ps / 1ps

////module tb_cryptographic_puf;
////    parameter NUM_BLOCKS = 21;
////    parameter NUM_CHALLENGES = 128; // Define how many challenges to run

////    reg pulse;
////    reg [(NUM_BLOCKS*128)-1:0] master_challenge;
    
////    wire [(NUM_BLOCKS*3)-1:0] aggregated_response;
////    wire [NUM_BLOCKS-1:0]     aggregated_valid;

////    cryptographic_puf_top #(
////        .NUM_BLOCKS(NUM_BLOCKS)
////    ) dut (
////        .challenge_pulse(pulse),
////        .master_challenge(master_challenge),
////        .aggregated_response(aggregated_response),
////        .aggregated_valid(aggregated_valid)
////    );

////    integer valid_count;
////    integer i, c_idx, chunk_idx;
    
////    // Total 32-bit chunks needed for the 5504-bit master_challenge
////    localparam TOTAL_CHUNKS = (NUM_BLOCKS * 128) / 32;
    
////    integer fd;
////    initial fd = $fopen("responses.txt", "w");

////    initial begin
////        $display("===============================================================");
////        $display("Starting Automated Cryptographic PUF Simulation...");
////        $display("Generating %0d Random Challenges", NUM_CHALLENGES);
////        $display("===============================================================");
        
////        pulse = 0;
////        master_challenge = 0;
////        #100000; 

////        // Loop to generate 128 distinct random challenges
////        for (c_idx = 1; c_idx <= NUM_CHALLENGES; c_idx = c_idx + 1) begin
            
////            // 1. Fill the 5,504-bit master_challenge with random bits
////            for (chunk_idx = 0; chunk_idx < TOTAL_CHUNKS; chunk_idx = chunk_idx + 1) begin
////                // $urandom generates an unsigned 32-bit random integer
////                master_challenge[chunk_idx*32 +: 32] = $urandom;
////            end
            
////            // 2. Fire the challenge pulse
////            pulse = 1;
////            #5000000; // Wait for the signals to propagate through all 128 stages
            
////            // 3. Count valid blocks
////            valid_count = 0;
////            for(i = 0; i < NUM_BLOCKS; i = i + 1) begin
////                valid_count = valid_count + aggregated_valid[i];
////            end
            
////            // 4. Display the results for this challenge
////            $display(" Key: %b",  
////                       aggregated_response);
////            $fwrite(fd, "%b\n", aggregated_response);
            
            
////            // 5. Reset for the next run
////            pulse = 0; 
////            #1000000;
////        end

////        $display("===============================================================");
////        $display("Simulation Complete.");
////        $display("===============================================================");
////        $finish;
////    end
////endmodule

////=============================================
////SYNTHESIZABLE CODE
////=============================================

//`timescale 1ns / 1ps

//// ============================================================================
//// 1. XNOR-XOR Pairwise Filter
//// ============================================================================
//module xnor_xor_filter (
//    input wire path_i,
//    input wire path_j,
//    output reg decisive_win, 
//    output reg i_beats_j     
//);
    
//    wire evaluate_now = path_i | path_j;    
//    wire reset_now    = ~(path_i | path_j); 

//    // Synthesizes to an asynchronous reset D-Latch/Flip-Flop
//    always @(posedge evaluate_now or posedge reset_now) begin
//        if (reset_now) begin
//            decisive_win <= 1'b0;
//            i_beats_j    <= 1'b0;
//        end else begin
//            decisive_win <= path_i ^ path_j;
//            i_beats_j    <= path_i & ~path_j;
//        end
//    end
//endmodule

//// ============================================================================
//// 2. 6-Pair Evaluation Matrix & Transitivity Rescue
//// ============================================================================
//module pairwise_matrix (
//    input wire A, B, C, D,
//    output wire [5:0] final_comp, // {AB, AC, AD, BC, BD, CD}
//    output wire valid_out         
//);
//    wire v_AB, v_AC, v_AD, v_BC, v_BD, v_CD;
//    wire r_AB, r_AC, r_AD, r_BC, r_BD, r_CD;

//    xnor_xor_filter f_AB (.path_i(A), .path_j(B), .decisive_win(v_AB), .i_beats_j(r_AB));
//    xnor_xor_filter f_AC (.path_i(A), .path_j(C), .decisive_win(v_AC), .i_beats_j(r_AC));
//    xnor_xor_filter f_AD (.path_i(A), .path_j(D), .decisive_win(v_AD), .i_beats_j(r_AD));
//    xnor_xor_filter f_BC (.path_i(B), .path_j(C), .decisive_win(v_BC), .i_beats_j(r_BC));
//    xnor_xor_filter f_BD (.path_i(B), .path_j(D), .decisive_win(v_BD), .i_beats_j(r_BD));
//    xnor_xor_filter f_CD (.path_i(C), .path_j(D), .decisive_win(v_CD), .i_beats_j(r_CD));
    
//    wire deduced_AB = (~v_AB) ? ((r_AC & ~r_BC) ? 1'b1 : (~r_AC & r_BC) ? 1'b0 : 1'b0) : r_AB;
//    wire deduced_AC = (~v_AC) ? ((r_AB & r_BC) ? 1'b1 : (~r_AB & ~r_BC) ? 1'b0 : 1'b0) : r_AC;
//    wire deduced_AD = (~v_AD) ? ((r_AC & r_CD) ? 1'b1 : (~r_AC & ~r_CD) ? 1'b0 : 1'b0) : r_AD;
//    wire deduced_BC = (~v_BC) ? ((~r_AB & r_AC) ? 1'b1 : (r_AB & ~r_AC) ? 1'b0 : 1'b0) : r_BC;
//    wire deduced_BD = (~v_BD) ? ((r_BC & r_CD) ? 1'b1 : (~r_BC & ~r_CD) ? 1'b0 : 1'b0) : r_BD;
//    wire deduced_CD = (~v_CD) ? ((~r_AC & r_AD) ? 1'b1 : (r_AC & ~r_AD) ? 1'b0 : 1'b0) : r_CD;

//    assign valid_out = (v_AB + v_AC + v_AD + v_BC + v_BD + v_CD) >= 4; 
//    assign final_comp = {deduced_AB, deduced_AC, deduced_AD, deduced_BC, deduced_BD, deduced_CD};
//endmodule

//// ============================================================================
//// 3. (4,3)-Arbiter Rank Encoder
//// ============================================================================
//module arbiter_4_3 (
//    input wire [5:0] comparisons,
//    output wire [2:0] puf_response
//);
//    wire AB = comparisons[5];
//    wire AC = comparisons[4];
//    wire AD = comparisons[3];
//    wire BC = comparisons[2];
//    wire BD = comparisons[1];
//    wire CD = comparisons[0];

//    assign puf_response[2] = AB;
//    assign puf_response[1] = CD;
//    assign puf_response[0] = (AB & CD)  ? AC :
//                             (AB & ~CD) ? AD :
//                             (~AB & CD) ? BC :
//                                          BD ;
//endmodule

//// ============================================================================
//// 4. Structural 64-Stage MUX Delay Chain (Synthesizable)
//// ============================================================================
////module arbiter_chain #(
////    parameter STAGES = 64,
////    parameter integer ROUTE_BIAS = 10000, 
////    parameter integer TOP_MUL = 3,        
////    parameter integer TOP_MOD = 7,        
////    parameter integer BOT_MUL = 5,        
////    parameter integer BOT_MOD = 7         
////)(
////    input wire pulse_in,
////    input wire [STAGES-1:0] challenge,
////    output wire out_top,
////    output wire out_bot
////);
////    (* DONT_TOUCH = "TRUE" *) wire top_net [STAGES:0];
////    (* DONT_TOUCH = "TRUE" *) wire bot_net [STAGES:0];

////    assign top_net[0] = pulse_in;
////    assign bot_net[0] = pulse_in;

////    genvar i;
////    generate
////        for (i = 0; i < STAGES; i = i + 1) begin : mux_stage
////            wire t_in = top_net[i];
////            wire b_in = bot_net[i];

  
////            assign top_net[i+1] = challenge[i] ? b_in : t_in;
////            assign bot_net[i+1] = challenge[i] ? t_in : b_in;
////        end
////    endgenerate

////    assign out_top = top_net[STAGES];
////    assign out_bot = bot_net[STAGES];
////endmodule

//module arbiter_chain #(
//    parameter STAGES = 64,
//    parameter integer ROUTE_BIAS = 10000, 
//    parameter integer TOP_MUL = 3,        
//    parameter integer TOP_MOD = 7,        
//    parameter integer BOT_MUL = 5,        
//    parameter integer BOT_MOD = 7         
//)(
//    input wire pulse_in,
//    input wire [STAGES-1:0] challenge,
//    output wire out_top,
//    output wire out_bot
//);
//    (* DONT_TOUCH = "TRUE" *) wire top_net [STAGES:0];
//    (* DONT_TOUCH = "TRUE" *) wire bot_net [STAGES:0];

//    assign top_net[0] = pulse_in;
//    assign bot_net[0] = pulse_in;

//    genvar i;
//    generate
//        for (i = 0; i < STAGES; i = i + 1) begin : mux_stage
//            (* DONT_TOUCH = "TRUE" *) wire top_mux_wire;
//            (* DONT_TOUCH = "TRUE" *) wire bot_mux_wire;

//            // Top Multiplexer Primitive (LUT3)
//            LUT3 #(
//                .INIT(8'hCA) 
//            ) top_mux_inst (
//                .O(top_mux_wire),
//                .I0(top_net[i]),
//                .I1(bot_net[i]),
//                .I2(challenge[i])
//            );

//            // Bottom Multiplexer Primitive (LUT3)
//            LUT3 #(
//                .INIT(8'hAC) 
//            ) bot_mux_inst (
//                .O(bot_mux_wire),
//                .I0(top_net[i]),
//                .I1(bot_net[i]),
//                .I2(challenge[i])
//            );

//            assign top_net[i+1] = top_mux_wire;
//            assign bot_net[i+1] = bot_mux_wire;
//        end
//    endgenerate

//    assign out_top = top_net[STAGES];
//    assign out_bot = bot_net[STAGES];
//endmodule
//// ============================================================================
//// 5. Top-Level PUF Wrapper
//// ============================================================================
//(* KEEP_HIERARCHY = "TRUE" *)
//module puf_structural_top #(
//    parameter integer BLOCK_ID = 0   
//)(
//    input wire challenge_pulse,
//    input wire [127:0] challenge_bits,
//    output wire [2:0] puf_response,
//    output wire response_valid
//);
//    wire path_A, path_B, path_C, path_D;

//    wire [127:0] challenge_bits_rev;
//    genvar k;
//    generate
//        for (k = 0; k < 128; k = k + 1) begin : rev
//            assign challenge_bits_rev[k] = challenge_bits[127-k];
//        end
//    endgenerate

//    localparam integer ROT_AMOUNT = ((BLOCK_ID * 7) % 31) + 5;
//    wire [127:0] challenge_bits_rot = (challenge_bits_rev << ROT_AMOUNT) |
//                                       (challenge_bits_rev >> (128 - ROT_AMOUNT));

//    localparam [127:0] BLOCK_MASK = {(BLOCK_ID*32'hD1B54A35 + 32'h9E3779B9),
//                                      (BLOCK_ID*32'h9E3779B1 + 32'h85EBCA6B),
//                                      (BLOCK_ID*32'h85EBCA6B + 32'hC2B2AE35),
//                                      (BLOCK_ID*32'hC2B2AE35 + 32'hD1B54A35)};

//    wire [127:0] challenge_bits_cd = challenge_bits_rot ^ BLOCK_MASK;

//    arbiter_chain #(
//        .STAGES    (64), 
//        .ROUTE_BIAS(10000 + BLOCK_ID*173), 
//        .TOP_MUL   (2 + (BLOCK_ID % 4)), 
//        .TOP_MOD   (7),
//        .BOT_MUL   (2 + ((BLOCK_ID + 1) % 4)),
//        .BOT_MOD   (7)
//    ) chain_AB (
//        .pulse_in(challenge_pulse),
//        .challenge(challenge_bits[63:0]),        
//        .out_top(path_A),
//        .out_bot(path_B)
//    );

//    arbiter_chain #(
//        .STAGES    (64), 
//        .ROUTE_BIAS(10000 + BLOCK_ID*173), 
//        .TOP_MUL   (2 + ((BLOCK_ID + 2) % 4)),
//        .TOP_MOD   (7),
//        .BOT_MUL   (2 + ((BLOCK_ID + 3) % 4)),
//        .BOT_MOD   (7)
//    ) chain_CD (
//        .pulse_in(challenge_pulse),
//        .challenge(challenge_bits_cd[63:0]),    
//        .out_top(path_C),
//        .out_bot(path_D)
//    );

//    (* DONT_TOUCH = "TRUE" *) wire butterfly_ctrl = challenge_bits[31]; 

//    (* DONT_TOUCH = "TRUE" *) wire path_A_routed = butterfly_ctrl ? path_C : path_A;
//    (* DONT_TOUCH = "TRUE" *) wire path_B_routed = butterfly_ctrl ? path_D : path_B;
//    (* DONT_TOUCH = "TRUE" *) wire path_C_routed = butterfly_ctrl ? path_A : path_C;
//    (* DONT_TOUCH = "TRUE" *) wire path_D_routed = butterfly_ctrl ? path_B : path_D;

//    wire [5:0] comp_results;
    
//    pairwise_matrix comparator_matrix (
//        .A(path_A_routed), .B(path_B_routed), .C(path_C_routed), .D(path_D_routed),
//        .final_comp(comp_results),
//        .valid_out(response_valid)
//    );

//    arbiter_4_3 rank_encoder (
//        .comparisons(comp_results),
//        .puf_response(puf_response)
//    );
//endmodule

//// ============================================================================
//// 6. Top-Level Cryptographic PUF Array
//// ============================================================================
//module cryptographic_puf_top #(
//    parameter NUM_BLOCKS = 21 
//)(
//    input wire challenge_pulse,
//    input wire [(NUM_BLOCKS*128)-1:0] master_challenge,
//    output wire [(NUM_BLOCKS*3)-1:0] aggregated_response,
//    output wire [NUM_BLOCKS-1:0]     aggregated_valid
//);

//    genvar i;
//    generate
//        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : puf_array
//            puf_structural_top #(
//                .BLOCK_ID(i)   
//            ) individual_puf (
//                .challenge_pulse(challenge_pulse),
//                .challenge_bits(master_challenge[i*128 +: 128]),
//                .puf_response(aggregated_response[i*3 +: 3]),
//                .response_valid(aggregated_valid[i])
//            );
//        end
//    endgenerate

//endmodule







//  **************************************************************************
//  THIS IS THE SYNTHESIZABLE CODE. DO CHANGES HERE
//  **************************************************************************

`timescale 1ns / 1ps
// STEP 3: use together with the matching puf_axi_core and AXI slave.
// The delay-chain logic and challenge transformation are preserved.
// Race clocks are intentional asynchronous measurement signals.
// No near-tie detector is claimed. Post-route timing/CDC review is mandatory.

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
// 2a. Validity-aware, strict-order consensus decoder -- NEW.
// Both vectors use {AB, AC, AD, BC, BD, CD}; 1 means first path beats second.
// known_mask=0 means ignore that comparison's value completely.
// Accept iff >=1 strict order fits AND all fitting orders give the same code.
// Validity is logical consistency, not a physical metastability/tie detector.
// This is combinational; only consume after inputs and this logic have settled.
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

    // Same response mapping as arbiter_4_3; no change to bit polarity/order.
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
// 3. Original (4,3) encoder -- unchanged.
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
// 4. Original structural delay chain -- active logic unchanged.
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
// 5. PUF wrapper -- original paths, new reset and raw outputs.
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
// 6. PUF array -- reset fanout and raw comparison/path-level outputs.
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

