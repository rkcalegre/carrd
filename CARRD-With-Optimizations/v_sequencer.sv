//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// v_sequencer.sv -- Sequencer Unit
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author: Microlab 199 Carrd: RISC-V Vector Coprocessor Group (2SAY2223)
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Module Name: v_sequencer.sv
// Description: The Sequencer -----
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments: how to determine if a slot is filled? (status bit?)
//                      how to fill up the table - do we start at 7 or at 0? use *FIFO*?
//                        
// 
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

`timescale 1ns / 1ps

module v_sequencer #(
    parameter int IST_ENTRY_BITS = 40,       // For Instruction Status Table: 6 bits (maybe for opcode?) + 3 bits (instr_status)
    parameter int NO_OF_SLOTS = 8
)(
    input logic clk,
    input logic nrst,
    input logic [31:0] base_instr, 
    input logic [1:0] sel_op_A, sel_op_B, sel_dest, vsew, lmul,
    input logic [4:0] src_A, src_B, dest, imm,
    input logic [3:0] v_alu_op, v_lsu_op,
    input logic [2:0] v_red_op, v_sldu_op,
    input logic is_mul, is_vector, is_vconfig,
    input logic done_alu, done_mul, done_lsu, done_sldu, done_red,
    input logic [127:0] result_valu_1, result_valu_2, result_valu_3, result_valu_4, result_vmul_1, result_vmul_2, result_vmul_3, result_vmul_4, 
    input logic [31:0] result_vred,
    input logic [511:0] result_vsldu, result_vlsu,
    output logic is_vstype, is_vltype,
    output logic [2:0] optype_read,
    output logic [4:0] dest_wb,
    output logic [3:0] op_alu, op_mul, op_lsu, op_sldu, op_red,        // vector operation (6) (decoder)
    output logic [2:0] vsew_alu, vsew_mul, vsew_lsu, vsew_sldu, vsew_red, vsew_wb,      // Functional unit producing Fj (3) 
    output logic [2:0] lmul_alu, lmul_mul, lmul_lsu, lmul_sldu, lmul_red, lmul_wb,      // Functional unit producing Fk(3) (is_type)
    output logic [2:0] Qj_alu, Qj_mul, Qj_lsu, Qj_sldu, Qj_red, Qi_lsu,       // Functional unit producing Fj (3) 
    output logic [2:0] Qk_alu, Qk_mul, Qk_lsu, Qk_sldu, Qk_red, Qi_sldu,      // Functional unit producing Fk(3) (is_type)
    output logic [4:0] Fj_alu, Fj_mul, Fj_lsu, Fj_sldu, Fj_red,        // source register 1 (5) (decoder)
    output logic [4:0] Fk_alu, Fk_mul, Fk_lsu, Fk_sldu, Fk_red,        // source register 2 (5) (decoder)
    output logic [4:0] Fi_lsu, Fi_sldu,      // destination reg (5) (decoder)
    output logic [4:0] Imm_alu, Imm_mul, Imm_lsu, Imm_sldu, Imm_red,  // scalar operand (5) (decoder)
    output logic v_reg_wr_en, x_reg_wr_en, el_wr_en,
    output logic [127:0]  reg_wr_data, reg_wr_data_2, reg_wr_data_3, reg_wr_data_4,
    //output logic busy_alu, busy_mul, busy_lsu, busy_sldu, busy_red,
    output logic [5:0] el_wr_addr
);



    //***************************FU Status Guide***********************************//
    // 000 - VRF
    // 001 = VALU
    // 010 = VMUL
    // 011 = VLSU
    // 100 = VSLDU
    // 101 = VRED
    // 111 = default off

    //Instructions
    // 2 bit sel_dest [39:38]
    // 2 bit vsew [37:36]
    // 2 bit lmul [35:34]
    // 2 bit sel_op_A [33:32]
    // 2 bit sel_op_B [31:30]
    // 3 bits operation type [29:27]
    // 4 bits operation [26:23]
    // 5 bits src_A [22:18]
    // 5 bits src_B [17:13] 
    // 5 bits dest [12:8]
    // 5 bits immediate [7:3]
    // 3 bits instr status [2:0]
    
    //*************************** INSTRUCTION STATUS BLOCK *************************************//
    // contains 8 slots used for keeping track of instructions
    // executing within the pipeline, specifically the stage each instruction is currently in.
    // Represented by 3 bits to denote each stage:
    // 3'b001 - issue stage (vIS)
    // 3'b010 - read operands stage
    // 3'b011 - execution stage (vEX)
    // 3'b100 - writes results stage 
    // 3'b000 - default value

    // uses v1 format of table
    logic [IST_ENTRY_BITS-1:0] instr_status_table [0:NO_OF_SLOTS-1];         // instruction status table
    logic [3:0] fifo_count;                                                  // keeps track of # of instructions currently in the table
    logic [2:0] op;
    logic [3:0] op_instr; 
    logic busy_alu = 0;
    logic busy_mul = 0;
    logic busy_lsu = 0;
    logic busy_sldu = 0;
    logic busy_red = 0; 
    logic Rj_alu = 0;            // indicates if Fj is available (1),
    logic Rj_mul = 0;
    logic Rj_lsu = 0;
    logic Rj_sldu = 0;
    logic Rj_red = 0;
    logic Rk_alu = 0;             // indicates if Fk is available (1)
    logic Rk_mul = 0; 
    logic Rk_lsu = 0; 
    logic Rk_sldu = 0; 
    logic Rk_red = 0; 
    logic Ri_lsu = 0;
    logic [5:0] Fi_alu = 0;
    logic [5:0] Fi_mul = 0;
    logic [5:0] Fi_red = 0;
    logic [IST_ENTRY_BITS-1:0] instr_1;
    logic [IST_ENTRY_BITS-1:0] instr_2; 
    logic [IST_ENTRY_BITS-1:0] instr_3; 
    logic [IST_ENTRY_BITS-1:0] instr_4; 
    logic [IST_ENTRY_BITS-1:0] instr_5; 
    logic [IST_ENTRY_BITS-1:0] instr_6; 
    logic [IST_ENTRY_BITS-1:0] instr_7;
    logic [IST_ENTRY_BITS-1:0] instr_8; // IST  
    logic [IST_ENTRY_BITS-1:0] instr_read = 0; 
    logic [IST_ENTRY_BITS-1:0] alu_exec = 0; 
    logic [IST_ENTRY_BITS-1:0] mul_exec = 0; 
    logic [IST_ENTRY_BITS-1:0] lsu_exec = 0; 
    logic [IST_ENTRY_BITS-1:0] sldu_exec = 0; 
    logic [IST_ENTRY_BITS-1:0] red_exec = 0; 
    logic [IST_ENTRY_BITS-1:0] wb_instr = 0;
    logic [2:0] instr_read_index = 0; 
    logic [2:0] alu_exec_index = 0; 
    logic [2:0] mul_exec_index = 0; 
    logic [2:0] lsu_exec_index = 0; 
    logic [2:0] sldu_exec_index = 0; 
    logic [2:0] red_exec_index = 0; 
    logic [2:0] wb_instr_index = 0;
    logic [2:0] sel_dest_alu = 0; 
    logic [2:0] sel_dest_mul = 0; 
    logic [2:0] sel_dest_lsu = 0; 
    logic [2:0] sel_dest_sldu = 0; 
    logic [2:0] sel_dest_red = 0;
    logic wr_alu = 0;
    logic wr_mul = 0; 
    logic wr_lsu = 0; 
    logic wr_sldu = 0; 
    logic wr_red = 0;
    logic lsu_raw;

    assign fifo_full = (fifo_count == NO_OF_SLOTS);
    assign instr_1 = instr_status_table[0];
    assign instr_2 = instr_status_table[1];
    assign instr_3 = instr_status_table[2];
    assign instr_4 = instr_status_table[3];
    assign instr_5 = instr_status_table[4];
    assign instr_6 = instr_status_table[5];
    assign instr_7 = instr_status_table[6];
    assign instr_8 = instr_status_table[7];
    assign is_vstype = (op_lsu inside {[7:12]});
    assign is_vltype = (op_lsu inside {[1:6]});
    assign op = (v_alu_op != 0) ? 3'b001: (is_mul != 0) ? 3'b010: v_lsu_op != 0 ? 3'b011: (v_sldu_op != 0) ? 3'b100: (v_red_op != 0) ? 3'b101:3'b000;
    assign op_instr = op == 3'b001 ? v_alu_op: op == 3'b010 ? is_mul: op == 3'b011 ? v_lsu_op: op == 3'b100 ? v_sldu_op: 3'b101 ? v_red_op: 0;
    assign lsu_raw = is_vltype == 1 ? 1: is_vstype == 1 ? 0: lsu_raw;

    always @(clk) begin      
        // Write to Instruction Status Table
        if (nrst) begin
            if (fifo_full == 0 && base_instr != 0 && is_vector == 1 && is_vconfig ==  0 && clk == 0) begin
                instr_status_table[fifo_count] = {sel_dest, vsew, lmul, sel_op_A, sel_op_B, op, op_instr, src_A, src_B, dest, imm, 3'b010};
                fifo_count = fifo_count + 1;
            end

            if (wb_instr_index == 0 && wb_instr != 0) begin
                case(wb_instr[29:27]) 
                default: ;
                3'b001: wr_alu = 0;
                3'b010: wr_mul = 0;
                3'b011: wr_lsu = 0;
                3'b100: wr_sldu = 0;
                3'b101: wr_red = 0;
                endcase 

                instr_status_table[0] <= instr_status_table[1];
                instr_status_table[1] <= instr_status_table[2];
                instr_status_table[2] <= instr_status_table[3];
                instr_status_table[3] <= instr_status_table[4];
                instr_status_table[4] <= instr_status_table[5];
                instr_status_table[5] <= instr_status_table[6];
                instr_status_table[6] <= instr_status_table[7];
                instr_status_table[7] <= {IST_ENTRY_BITS{1'b0}};
                fifo_count = fifo_count - 1;
            end 
        end

    end


    always @(*) begin

        if (!nrst) begin
            for (int i = 0; i < NO_OF_SLOTS; i++) begin
                fifo_count = 3'b000;
                instr_status_table[i] = {IST_ENTRY_BITS{1'b0}};
            end
            //outputs
            optype_read = 0; dest_wb = 0; el_wr_addr = 0;
            op_alu = 0; op_mul = 0; op_lsu = 0; op_sldu = 0; op_red = 0;
            vsew_alu = 0; vsew_mul = 0; vsew_lsu = 0; vsew_sldu = 0; vsew_red = 0; vsew_wb = 0;
            lmul_alu = 0; lmul_mul = 0; lmul_lsu = 0; lmul_sldu = 0; lmul_red = 0; lmul_wb = 0;
            Qj_alu = 0; Qj_mul = 0; Qj_lsu = 0; Qj_sldu = 0; Qj_red = 0; Qi_lsu = 0;
            Qk_alu = 0; Qk_mul = 0; Qk_lsu = 0; Qk_sldu = 0; Qk_red = 0; Qi_sldu = 0;
            Fi_lsu = 0; Fi_sldu = 0;
            Fj_alu = 0; Fj_mul = 0; Fj_lsu = 0; Fj_sldu = 0; Fj_red = 0;
            Fk_alu = 0; Fk_mul = 0; Fk_lsu = 0; Fk_sldu = 0; Fk_red = 0;
            Imm_alu = 0; Imm_mul = 0; Imm_lsu = 0; Imm_sldu = 0; Imm_red = 0;
            v_reg_wr_en = 0; x_reg_wr_en = 0; el_wr_en = 0;
            reg_wr_data = 0; reg_wr_data_2 = 0; reg_wr_data_3 = 0; reg_wr_data_4 = 0;
            busy_alu = 0; busy_mul = 0; busy_lsu = 0; busy_sldu = 0; busy_red = 0;
        
        end else begin

        #1  
    // ******************ISSUE******************
/*         if (instr_1[29:27] != 0 && instr_1[2:0] == 3'b001) begin
            instr_status_table[0][2:0] = 3'b010;
        end
        else if (instr_2[29:27] != 0 && instr_2[2:0] == 3'b001) begin 
            instr_status_table[1][2:0] = 3'b010;
        end
        else if (instr_3[29:27] != 0 && instr_3[2:0] == 3'b001) begin
            instr_status_table[2][2:0] = 3'b010;
        end
        else if (instr_4[29:27] != 0 && instr_4[2:0] == 3'b001) begin
            instr_status_table[3][2:0] = 3'b010;
        end
        else if (instr_5[29:27] != 0 && instr_5[2:0] == 3'b001) begin
            instr_status_table[4][2:0] = 3'b010;
        end
        else if (instr_6[29:27] != 0 && instr_6[2:0] == 3'b001) begin
            instr_status_table[5][2:0] = 3'b010;
        end
        else if (instr_7[29:27] != 0 && instr_7[2:0] == 3'b001) begin
            instr_status_table[6][2:0] = 3'b010;
        end
        else if (instr_8[29:27] != 0 && instr_8[2:0] == 3'b001) begin
            instr_status_table[7][2:0] = 3'b010;
        end */

    // ******************EXECUTE******************
        //alu
        alu_exec = ((instr_1[29:27] == 3'b001 && instr_1[2:0] == 3'b011) ? instr_1: (instr_2[29:27] == 3'b001 && instr_2[2:0] == 3'b011) ? instr_2: (instr_3[29:27] == 3'b001 && instr_3[2:0] == 3'b011) ? instr_3: (instr_4[29:27] == 3'b001 && instr_4[2:0] == 3'b011) ? instr_4: (instr_5[29:27] == 3'b001 && instr_5[2:0] == 3'b011) ? instr_5: (instr_6[29:27] == 3'b001 && instr_6[2:0] == 3'b011) ? instr_6: (instr_7[29:27] == 3'b001 && instr_7[2:0] == 3'b011) ? instr_7: (instr_8[29:27] == 3'b001 && instr_8[2:0] == 3'b011) ? instr_8: 0);
        alu_exec_index = ((instr_1[29:27] == 3'b001 && instr_1[2:0] == 3'b011) ? 0: (instr_2[29:27] == 3'b001 && instr_2[2:0] == 3'b011) ? 1: (instr_3[29:27] == 3'b001 && instr_3[2:0] == 3'b011) ? 2: (instr_4[29:27] == 3'b001 && instr_4[2:0] == 3'b011) ? 3: (instr_5[29:27] == 3'b001 && instr_5[2:0] == 3'b011) ? 4: (instr_6[29:27] == 3'b001 && instr_6[2:0] == 3'b011) ? 5: (instr_7[29:27] == 3'b001 && instr_7[2:0] == 3'b011) ? 6: (instr_8[29:27] == 3'b001 && instr_8[2:0] == 3'b011) ? 7: 0);

        //mul
        mul_exec = ((instr_1[29:27] == 3'b010 && instr_1[2:0] == 3'b011) ? instr_1: (instr_2[29:27] == 3'b010 && instr_2[2:0] == 3'b011) ? instr_2: (instr_3[29:27] == 3'b010 && instr_3[2:0] == 3'b011) ? instr_3: (instr_4[29:27] == 3'b010 && instr_4[2:0] == 3'b011) ? instr_4: (instr_5[29:27] == 3'b010 && instr_5[2:0] == 3'b011) ? instr_5: (instr_6[29:27] == 3'b010 && instr_6[2:0] == 3'b011) ? instr_6: (instr_7[29:27] == 3'b010 && instr_7[2:0] == 3'b011) ? instr_7: (instr_8[29:27] == 3'b010 && instr_8[2:0] == 3'b011) ? instr_8: 0);
        mul_exec_index = ((instr_1[29:27] == 3'b010 && instr_1[2:0] == 3'b011) ? 0: (instr_2[29:27] == 3'b010 && instr_2[2:0] == 3'b011) ? 1: (instr_3[29:27] == 3'b010 && instr_3[2:0] == 3'b011) ? 2: (instr_4[29:27] == 3'b010 && instr_4[2:0] == 3'b011) ? 3: (instr_5[29:27] == 3'b010 && instr_5[2:0] == 3'b011) ? 4: (instr_6[29:27] == 3'b010 && instr_6[2:0] == 3'b011) ? 5: (instr_7[29:27] == 3'b010 && instr_7[2:0] == 3'b011) ? 6: (instr_8[29:27] == 3'b010 && instr_8[2:0] == 3'b011) ? 7: 0);

        //lsu
        lsu_exec = ((instr_1[29:27] == 3'b011 && instr_1[2:0] == 3'b011) ? instr_1: (instr_2[29:27] == 3'b011 && instr_2[2:0] == 3'b011) ? instr_2: (instr_3[29:27] == 3'b011 && instr_3[2:0] == 3'b011) ? instr_3: (instr_4[29:27] == 3'b011 && instr_4[2:0] == 3'b011) ? instr_4: (instr_5[29:27] == 3'b011 && instr_5[2:0] == 3'b011) ? instr_5: (instr_6[29:27] == 3'b011 && instr_6[2:0] == 3'b011) ? instr_6: (instr_7[29:27] == 3'b011 && instr_7[2:0] == 3'b011) ? instr_7: (instr_8[29:27] == 3'b011 && instr_8[2:0] == 3'b011) ? instr_8: 0);
        lsu_exec_index = ((instr_1[29:27] == 3'b011 && instr_1[2:0] == 3'b011) ? 0: (instr_2[29:27] == 3'b011 && instr_2[2:0] == 3'b011) ? 1: (instr_3[29:27] == 3'b011 && instr_3[2:0] == 3'b011) ? 2: (instr_4[29:27] == 3'b011 && instr_4[2:0] == 3'b011) ? 3: (instr_5[29:27] == 3'b011 && instr_5[2:0] == 3'b011) ? 4: (instr_6[29:27] == 3'b011 && instr_6[2:0] == 3'b011) ? 5: (instr_7[29:27] == 3'b011 && instr_7[2:0] == 3'b011) ? 6: (instr_8[29:27] == 3'b011 && instr_8[2:0] == 3'b011) ? 7: 0);

        //sldu
        sldu_exec = ((instr_1[29:27] == 3'b100 && instr_1[2:0] == 3'b011) ? instr_1: (instr_2[29:27] == 3'b100 && instr_2[2:0] == 3'b011) ? instr_2: (instr_3[29:27] == 3'b100 && instr_3[2:0] == 3'b011) ? instr_3: (instr_4[29:27] == 3'b100 && instr_4[2:0] == 3'b011) ? instr_4: (instr_5[29:27] == 3'b100 && instr_5[2:0] == 3'b011) ? instr_5: (instr_6[29:27] == 3'b100 && instr_6[2:0] == 3'b011) ? instr_6: (instr_7[29:27] == 3'b100 && instr_7[2:0] == 3'b011) ? instr_7: (instr_8[29:27] == 3'b100 && instr_8[2:0] == 3'b011) ? instr_8: 0);
        sldu_exec_index = ((instr_1[29:27] == 3'b100 && instr_1[2:0] == 3'b011) ? 0: (instr_2[29:27] == 3'b100 && instr_2[2:0] == 3'b011) ? 1: (instr_3[29:27] == 3'b100 && instr_3[2:0] == 3'b011) ? 2: (instr_4[29:27] == 3'b100 && instr_4[2:0] == 3'b011) ? 3: (instr_5[29:27] == 3'b100 && instr_5[2:0] == 3'b011) ? 4: (instr_6[29:27] == 3'b100 && instr_6[2:0] == 3'b011) ? 5: (instr_7[29:27] == 3'b100 && instr_7[2:0] == 3'b011) ? 6: (instr_8[29:27] == 3'b100 && instr_8[2:0] == 3'b011) ? 7: 0);

        //red
        red_exec = ((instr_1[29:27] == 3'b101 && instr_1[2:0] == 3'b011) ? instr_1: (instr_2[29:27] == 3'b101 && instr_2[2:0] == 3'b011) ? instr_2: (instr_3[29:27] == 3'b101 && instr_3[2:0] == 3'b011) ? instr_3: (instr_4[29:27] == 3'b101 && instr_4[2:0] == 3'b011) ? instr_4: (instr_5[29:27] == 3'b101 && instr_5[2:0] == 3'b011) ? instr_5: (instr_6[29:27] == 3'b101 && instr_6[2:0] == 3'b011) ? instr_6: (instr_7[29:27] == 3'b101 && instr_7[2:0] == 3'b011) ? instr_7: (instr_8[29:27] == 3'b101 && instr_8[2:0] == 3'b011) ? instr_8: 0);
        red_exec_index = ((instr_1[29:27] == 3'b101 && instr_1[2:0] == 3'b011) ? 0: (instr_2[29:27] == 3'b101 && instr_2[2:0] == 3'b011) ? 1: (instr_3[29:27] == 3'b101 && instr_3[2:0] == 3'b011) ? 2: (instr_4[29:27] == 3'b101 && instr_4[2:0] == 3'b011) ? 3: (instr_5[29:27] == 3'b101 && instr_5[2:0] == 3'b011) ? 4: (instr_6[29:27] == 3'b101 && instr_6[2:0] == 3'b011) ? 5: (instr_7[29:27] == 3'b101 && instr_7[2:0] == 3'b011) ? 6: (instr_8[29:27] == 3'b101 && instr_8[2:0] == 3'b011) ? 7: 0);
//
         if (done_alu == 1 && alu_exec != 0) begin
            alu_exec[2:0] = 3'b100;
            instr_status_table[alu_exec_index] = alu_exec;
            Rj_alu = 0;
            Rk_alu = 0;
            op_alu = 0;
            wr_alu = 1;
        end

        if (done_mul == 1 && mul_exec != 0) begin
            mul_exec[2:0] = 3'b100;
            instr_status_table[mul_exec_index] = mul_exec;
            Rj_mul = 0;
            Rk_mul = 0;
            op_mul = 0;
            //wr_mul = 1;
        end

        if (done_lsu == 1 && lsu_exec != 0) begin
            lsu_exec[2:0] = 3'b100;
            instr_status_table[lsu_exec_index] = lsu_exec;
            Rj_lsu = 0;
            Rk_lsu = 0;
            op_lsu = 0;
            //wr_lsu = 1;
        end

        if (done_sldu == 1 && sldu_exec != 0) begin
            sldu_exec[2:0] = 3'b100;
            instr_status_table[sldu_exec_index] = sldu_exec;
            Rj_sldu = 0;
            Rk_sldu = 0;
            op_sldu = 0;
            //wr_sldu = 1;
        end

        if (done_red == 1 && red_exec != 0) begin
            red_exec[2:0] = 3'b100;
            instr_status_table[red_exec_index] = red_exec;
            Rj_red = 0;
            Rk_red = 0;
            op_red = 0;
            //wr_red = 1;
        end
 
    // ******************READ******************
        //alu
        instr_read = ((instr_1[2:0] == 3'b010) ? instr_1: (instr_2[2:0] == 3'b010) ? instr_2: (instr_3[2:0] == 3'b010) ? instr_3: (instr_4[2:0] == 3'b010) ? instr_4: (instr_5[2:0] == 3'b010) ? instr_5: (instr_6[2:0] == 3'b010) ? instr_6: (instr_7[2:0] == 3'b010) ? instr_7: (instr_8[2:0] == 3'b010) ? instr_8: 0);        
        instr_read_index = ((instr_1[2:0] == 3'b010) ? 0: (instr_2[2:0] == 3'b010) ? 1: (instr_3[2:0] == 3'b010) ? 2: (instr_4[2:0] == 3'b010) ? 3: (instr_5[2:0] == 3'b010) ? 4: (instr_6[2:0] == 3'b010) ? 5: (instr_7[2:0] == 3'b010) ? 6: (instr_8[2:0] == 3'b010) ? 7: 0);
    
        if (instr_read != 0 && instr_read[29:27] == 3'b001) begin
            if(busy_alu == 0 && alu_exec == 0) begin
                sel_dest_alu = instr_read[39:38];
                Fj_alu =  instr_read[22:18];
                Fk_alu = instr_read[17:13];
                Imm_alu = instr_read[7:3];
                Qj_alu = ((instr_read[33:32] == 2'b10) ? 3'b110: (instr_read[33:32] == 2'b11) ? 3'b111: (Fj_alu == Fi_alu && wr_alu == 1) ? 3'b001: (Fj_alu == Fi_mul && wr_mul == 1) ? 3'b010: (Fj_alu == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fj_alu == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fj_alu == Fi_red && wr_red == 1) ? 3'b101: 3'b000);
                Qk_alu = ((instr_read[31:30] == 2'b10) ? 3'b110: (instr_read[31:30] == 2'b11) ? 3'b111: (Fk_alu == Fi_alu && wr_alu == 1) ? 3'b001: (Fk_alu == Fi_mul && wr_mul == 1) ? 3'b010: (Fk_alu == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fk_alu == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fk_alu == Fi_red && wr_red == 1) ? 3'b101: 3'b000);                
                Rj_alu = ((Qj_alu == 3'b000 || Qj_alu == 3'b110 || Qj_alu == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qj_alu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qj_alu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qj_alu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qj_alu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qj_alu == 3'b101) ? 1: 0);
                Rk_alu = ((Qk_alu == 3'b000 || Qk_alu == 3'b110 || Qk_alu == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qk_alu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qk_alu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qk_alu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qk_alu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qk_alu == 3'b101) ? 1: 0);
                busy_alu = ((Rj_alu == 1 && Rk_alu == 1) ? 1: 0); 
                if (busy_alu == 1) begin
                    Fi_alu = instr_read[12:8];   
                    optype_read = instr_read[29:27];       
                    op_alu = instr_read[26:23];
                    vsew_alu = instr_read[37:36];
                    lmul_alu = instr_read[35:34];
                    instr_read [2:0] =  3'b011;        
                    instr_status_table[instr_read_index] = instr_read;
                    wr_alu = 1;
                end
            end
        end

        //mul
        if (instr_read != 0 && instr_read[29:27] == 3'b010) begin
            if(busy_mul == 0 && mul_exec == 0) begin
                sel_dest_mul = instr_read[39:38];
                Fj_mul =  instr_read[22:18];
                Fk_mul = instr_read[17:13];
                Imm_mul = instr_read[7:3];
                Qj_mul = ((instr_read[33:32] == 2'b10) ? 3'b110: (instr_read[33:32] == 2'b11) ? 3'b111: (Fj_mul == Fi_alu && wr_alu == 1) ? 3'b001: (Fj_mul == Fi_mul && wr_mul == 1) ? 3'b010: (Fj_mul == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fj_mul == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fj_mul == Fi_red && wr_red == 1) ? 3'b101: 3'b000);
                Qk_mul = ((instr_read[31:30] == 2'b10) ? 3'b110: (instr_read[31:30] == 2'b11) ? 3'b111: (Fk_mul == Fi_alu && wr_alu == 1) ? 3'b001: (Fk_mul == Fi_mul && wr_mul == 1) ? 3'b010: (Fk_mul == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fk_mul == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fk_mul == Fi_red && wr_red == 1) ? 3'b101: 3'b000);                
                Rj_mul = ((Qj_mul == 3'b000 || Qj_mul == 3'b110 || Qj_mul == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qj_mul == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qj_mul == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qj_mul == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qj_mul == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qj_mul == 3'b101) ? 1: 0);
                Rk_mul = ((Qk_mul == 3'b000 || Qk_mul == 3'b110 || Qk_mul == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qk_mul == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qk_mul == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qk_mul == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qk_mul == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qk_mul == 3'b101) ? 1: 0);
                busy_mul = ((Rj_mul == 1 && Rk_mul == 1) ? 1: 0); 
                if (busy_mul == 1) begin
                    Fi_mul = instr_read[12:8];   
                    optype_read = instr_read[29:27];       
                    op_mul = instr_read[26:23];
                    vsew_mul = instr_read[37:36];
                    lmul_mul = instr_read[35:34];
                    instr_read [2:0] =  3'b011;        
                    instr_status_table[instr_read_index] = instr_read;
                    wr_mul = 1;
                end
            end
        end

        //lsu
        if (instr_read != 0 && instr_read[29:27] == 3'b011) begin
            if(busy_lsu == 0 && lsu_exec == 0) begin
                sel_dest_lsu = instr_read[39:38];
                Fj_lsu =  instr_read[22:18];
                Fk_lsu = instr_read[17:13];
                Imm_lsu = instr_read[7:3];
                Qi_lsu = (instr_read[26:23] inside {[7:12]}) ? ((instr_read[12:8] == Fi_alu && wr_alu == 1) ? 3'b001: (instr_read[12:8] == Fi_mul && wr_mul == 1) ? 3'b010: (instr_read[12:8] == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (instr_read[12:8] == Fi_sldu && wr_sldu == 1) ? 3'b100: (instr_read[12:8] == Fi_red && wr_red == 1) ? 3'b101: 3'b000): 3'b000;
                Qj_lsu = ((instr_read[33:32] == 2'b10) ? 3'b110: (instr_read[33:32] == 2'b11) ? 3'b111: (Fj_lsu == Fi_alu && wr_alu == 1) ? 3'b001: (Fj_lsu == Fi_mul && wr_mul == 1) ? 3'b010: (Fj_lsu == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fj_lsu == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fj_lsu == Fi_red && wr_red == 1) ? 3'b101: 3'b000);
                Qk_lsu = ((instr_read[31:30] == 2'b10) ? 3'b110: (instr_read[31:30] == 2'b11) ? 3'b111: (Fk_lsu == Fi_alu && wr_alu == 1) ? 3'b001: (Fk_lsu == Fi_mul && wr_mul == 1) ? 3'b010: (Fk_lsu == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fk_lsu == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fk_lsu == Fi_red && wr_red == 1) ? 3'b101: 3'b000);                
                Rj_lsu = ((Qj_lsu == 3'b000 || Qj_lsu == 3'b110 || Qj_lsu == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qj_lsu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qj_lsu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qj_lsu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qj_lsu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qj_lsu == 3'b101) ? 1: 0);
                Rk_lsu = ((Qk_lsu == 3'b000 || Qk_lsu == 3'b110 || Qk_lsu == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qk_lsu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qk_lsu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qk_lsu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qk_lsu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qk_lsu == 3'b101) ? 1: 0);
                Ri_lsu = ((Qi_lsu == 3'b000) ? 1: ((done_alu == 1 || busy_alu == 0) && Qi_lsu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qi_lsu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qi_lsu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qi_lsu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) == 0 && Qi_lsu == 3'b101) ? 1: (busy_red == 0 && Qi_lsu == 3'b101) ? 1: 0);                
                busy_lsu = ((Rj_lsu == 1 && Rk_lsu == 1 && Ri_lsu) ? 1: 0); 
                if (busy_lsu == 1) begin
                    Fi_lsu = instr_read[12:8];   
                    optype_read = instr_read[29:27];       
                    op_lsu = instr_read[26:23];
                    vsew_lsu = instr_read[37:36];
                    lmul_lsu = instr_read[35:34];
                    instr_read [2:0] =  3'b011;        
                    instr_status_table[instr_read_index] = instr_read;
                    wr_lsu = 1;
                end
            end
        end

        //sldu
        if (instr_read != 0 && instr_read[29:27] == 3'b100) begin
            if(busy_sldu == 0 && sldu_exec == 0) begin
                sel_dest_sldu = instr_read[39:38];
                Fj_sldu =  instr_read[22:18];
                Fk_sldu = instr_read[17:13];
                Imm_sldu = instr_read[7:3];
                Qi_sldu = ((instr_read[12:8] == Fi_alu && wr_alu == 1) ? 3'b001: (instr_read[12:8] == Fi_mul && wr_mul == 1) ? 3'b010: (instr_read[12:8] == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (instr_read[12:8] == Fi_sldu && wr_sldu == 1) ? 3'b100: (instr_read[12:8] == Fi_red && wr_red == 1) ? 3'b101: 3'b000);
                Qj_sldu = ((instr_read[33:32] == 2'b10) ? 3'b110: (instr_read[33:32] == 2'b11) ? 3'b111: (Fj_sldu == Fi_alu && wr_alu == 1) ? 3'b001: (Fj_sldu == Fi_mul && wr_mul == 1) ? 3'b010: (Fj_sldu == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fj_sldu == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fj_sldu == Fi_red && wr_red == 1) ? 3'b101: 3'b000);
                Qk_sldu = ((instr_read[31:30] == 2'b10) ? 3'b110: (instr_read[31:30] == 2'b11) ? 3'b111: (Fk_sldu == Fi_alu && wr_alu == 1) ? 3'b001: (Fk_sldu == Fi_mul && wr_mul == 1) ? 3'b010: (Fk_sldu == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fk_sldu == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fk_sldu == Fi_red && wr_red == 1) ? 3'b101: 3'b000);                
                Rj_sldu = ((Qj_sldu == 3'b000 || Qj_sldu == 3'b110 || Qj_sldu == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qj_sldu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qj_sldu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qj_sldu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qj_sldu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qj_sldu == 3'b101) ? 1: 0);
                Rk_sldu = ((Qk_sldu == 3'b000 || Qk_sldu == 3'b110 || Qk_sldu == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qk_sldu == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qk_sldu == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qk_sldu == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qk_sldu == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qk_sldu == 3'b101) ? 1: 0);
                busy_sldu = ((Rj_sldu == 1 && Rk_sldu == 1) ? 1: 0); 
                if (busy_sldu == 1) begin
                    Fi_sldu = instr_read[12:8];   
                    optype_read = instr_read[29:27];       
                    op_sldu = instr_read[26:23];
                    vsew_sldu = instr_read[37:36];
                    lmul_sldu = instr_read[35:34];
                    instr_read [2:0] =  3'b011;        
                    instr_status_table[instr_read_index] = instr_read;
                    wr_sldu = 1;
                end
            end
        end

        //red
        if (instr_read != 0 && instr_read[29:27] == 3'b101) begin
            if(busy_red == 0 && red_exec == 0) begin
                optype_read = instr_read[29:27];
                sel_dest_red = instr_read[39:38];
                Fj_red =  instr_read[22:18];
                Fk_red = instr_read[17:13];
                Imm_red = instr_read[7:3];
                Qj_red = ((instr_read[33:32] == 2'b10) ? 3'b110: (instr_read[33:32] == 2'b11) ? 3'b111: (Fj_red == Fi_alu && wr_alu == 1) ? 3'b001: (Fj_red == Fi_mul && wr_mul == 1) ? 3'b010: (Fj_red == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fj_red == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fj_red == Fi_red && wr_red == 1) ? 3'b101: 3'b000);
                Qk_red = ((instr_read[31:30] == 2'b10) ? 3'b110: (instr_read[31:30] == 2'b11) ? 3'b111: (Fk_red == Fi_alu && wr_alu == 1) ? 3'b001: (Fk_red == Fi_mul && wr_mul == 1) ? 3'b010: (Fk_red == Fi_lsu && wr_lsu == 1 && lsu_raw == 1) ? 3'b011: (Fk_red == Fi_sldu && wr_sldu == 1) ? 3'b100: (Fk_red == Fi_red && wr_red == 1) ? 3'b101: 3'b000);                
                Rj_red = ((Qj_red == 3'b000 || Qj_red == 3'b110 || Qj_red == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qj_red == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qj_red == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qj_red == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qj_red == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qj_red == 3'b101) ? 1: 0);
                Rk_red = ((Qk_red == 3'b000 || Qk_red == 3'b110 || Qk_red == 3'b111) ? 1: ((done_alu == 1 || busy_alu == 0) && Qk_red == 3'b001) ? 1: ((done_mul == 1 || busy_mul == 0) && Qk_red == 3'b010) ? 1: ((done_lsu == 1 || busy_lsu == 0) && Qk_red == 3'b011) ? 1: ((done_sldu == 1 || busy_sldu == 0) && Qk_red == 3'b100) ? 1: ((done_red == 1 || busy_red == 0) && Qk_red == 3'b101) ? 1: 0);
                busy_red = ((Rj_red == 1 && Rk_red == 1) ? 1: 0); 
                if (busy_red == 1) begin
                    Fi_red = instr_read[12:8];   
                    optype_read = instr_read[29:27];       
                    op_red = instr_read[26:23];
                    vsew_red = instr_read[37:36];
                    lmul_red = instr_read[35:34];
                    instr_read [2:0] =  3'b011;        
                    instr_status_table[instr_read_index] = instr_read;
                    wr_red = 1;
                end
            end
        end


    // ******************WRITEBACK******************
        wb_instr = ((instr_1[2:0] == 3'b100) ? instr_1: (instr_2[2:0] == 3'b100) ? instr_2: (instr_3[2:0] == 3'b100) ? instr_3: (instr_4[2:0] == 3'b100) ? instr_4: (instr_5[2:0] == 3'b100) ? instr_5: (instr_6[2:0] == 3'b100) ? instr_6: (instr_7[2:0] == 3'b100) ? instr_7: (instr_8[2:0] == 3'b100) ? instr_8: 0);
        wb_instr_index = ((instr_1[2:0] == 3'b100) ? 0: (instr_2[2:0] == 3'b100) ? 1: (instr_3[2:0] == 3'b100) ? 2: (instr_4[2:0] == 3'b100) ? 3: (instr_5[2:0] == 3'b100) ? 4: (instr_6[2:0] == 3'b100) ? 5: (instr_7[2:0] == 3'b100) ? 6: (instr_8[2:0] == 3'b100) ? 7: 0);
        dest_wb = (wb_instr != 0) ? wb_instr[12:8] : dest_wb;   
        vsew_wb = (wb_instr != 0) ? wb_instr [37:36] : vsew_wb;
        lmul_wb = (wb_instr != 0) ? wb_instr [35:34] : lmul_wb;
        if (wb_instr != 0 && wb_instr_index == 0) begin
            el_wr_en = (wb_instr[29:27] == 3'b101 && wb_instr[39:38]==1) ? 1: 0; 
            v_reg_wr_en = ((wb_instr[29:27] == 3'b011) && ((wb_instr[26:23] == 4'b0111)||(wb_instr[26:23] == 4'b1000)||(wb_instr[26:23] == 4'b1001))) ? 0:(wb_instr[29:27] == 3'b101) ? 0: (wb_instr[39:38]==1) ? 1: 0;
            x_reg_wr_en = (wb_instr[39:38]==2) ? 1: 0;
        end else begin
            el_wr_en = 0;
            v_reg_wr_en = 0;
            x_reg_wr_en = 0;
        end

        case (wb_instr[29:27])
            default: ;
            3'b001: begin
                reg_wr_data <= result_valu_1;
                reg_wr_data_2 <= result_valu_2;
                reg_wr_data_3 <= result_valu_3;
                reg_wr_data_4 <= result_valu_4;
                busy_alu = alu_exec[29:27] != 0 ? 1: 0;
            end
            3'b010: begin
                reg_wr_data <= result_vmul_1;
                reg_wr_data_2 <= result_vmul_2;
                reg_wr_data_3 <= result_vmul_3;
                reg_wr_data_4 <= result_vmul_4; 
                busy_mul = mul_exec[29:27] != 0 ? 1: 0;
            end
            3'b011: begin
                reg_wr_data <= result_vlsu[127:0];
                reg_wr_data_2 <= result_vlsu[255:128];
                reg_wr_data_3 <= result_vlsu[383:256];
                reg_wr_data_4 <= result_vlsu[511:384];
                busy_lsu = lsu_exec[29:27] != 0 ? 1: 0;
            end
            3'b100: begin
                reg_wr_data <= result_vsldu[127:0];
                reg_wr_data_2 <= result_vsldu[255:128];
                reg_wr_data_3 <= result_vsldu[383:256];
                reg_wr_data_4 <= result_vsldu[511:384];  
                busy_sldu = sldu_exec[29:27] != 0 ? 1: 0;
            end
            3'b101: begin
                el_wr_addr = 0;
                reg_wr_data = {{96{1'b0}}, result_vred};
                reg_wr_data_2 = {128{1'b0}};
                reg_wr_data_3 = {128{1'b0}};
                reg_wr_data_4 = {128{1'b0}};   
                busy_red = red_exec[29:27] != 0 ? 1: 0;
            end
        endcase     
    end
    end

endmodule
