`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.04.2023 18:47:48
// Design Name: 
// Module Name: carrd_integrated
// Project Name: CARRD_Vector Coprocessor
// Target Devices: 
// Tool Versions: 
// Description: The top module of the project instantiating all other vector blocks.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
`include "constants.vh"

module carrd_integrated#(
	/**
	LANES Configuration
	0 - 4 lanes
	1 - 8 lanes
	2 - 16 lanes **/
    parameter int LANES = 2                     // To be set before synthesizing the project. 
)(
	input clk,
	input nrst,
	input logic [31:0] op_instr_base,           //The instruction from the base processor
    
    // Memory Data buses from Vector Coprocessor
	output is_vstype,
	output is_vltype,
    output dm_v_write,
    output [`DATAMEM_BITS-1:0] data_addr0,
    output [`DATAMEM_BITS-1:0] data_addr1,
    output [`DATAMEM_BITS-1:0] data_addr2,
    output [`DATAMEM_BITS-1:0] data_addr3,

	// For Vector Store Operations
	output [`DATAMEM_WIDTH-1:0] v_store_data_0,
	output [`DATAMEM_WIDTH-1:0] v_store_data_1,
	output [`DATAMEM_WIDTH-1:0] v_store_data_2,
	output [`DATAMEM_WIDTH-1:0] v_store_data_3,

	// For Vector Load Operations
	input [`DATAMEM_WIDTH-1:0] v_load_data_0,
	input [`DATAMEM_WIDTH-1:0] v_load_data_1,
	input [`DATAMEM_WIDTH-1:0] v_load_data_2,
	input [`DATAMEM_WIDTH-1:0] v_load_data_3,

    // For Vector-Scalar Instructions that require reads from the scalar regfile
	output [`REGFILE_BITS-1:0] v_rd_xreg_addr1,
    output [`REGFILE_BITS-1:0] v_rd_xreg_addr2,   
	input [`WORD_WIDTH-1:0] xreg_out1,	        // Data read from scalar register
    input [`WORD_WIDTH-1:0] xreg_out2	        // Data read from scalar register
);

    import v_pkg::*;

    /*=== INSTANTIATING MODULES ===*/

    //Clock Gating

    //Functional Unit Opcodes
    logic [3:0] v_alu_op;
    logic [3:0] v_lsu_op;
    logic is_mul;    
    logic [2:0] v_sldu_op;
    logic [2:0] v_red_op;

    logic vred_clk_en;
    logic valu_clk_en;
    logic vmul_clk_en;
    logic vsldu_clk_en;

    assign vred_clk_en = (op_red[2:0] != 0)? 1: 0;
    assign valu_clk_en = (op_alu != 0)? 1: 0;
    assign vmul_clk_en = (op_mul[0] != 0)? 1: 0;
    assign vsldu_clk_en = (op_sldu[2:0] != 0)? 1: 0;
    assign vlsu_clk_en = (op_lsu != 0)? 1: 0;

    logic vred_clk;
    logic valu_clk;
    logic vmul_clk;
    logic vsldu_clk;
    logic vlsu_clk;

    BUFGCE #(
       //.CE_TYPE("ASYNC"),
	   .SIM_DEVICE("7SERIES")
    ) en_vred (
	 	.I(clk),
	 	.CE(vred_clk_en),
	 	.O(vred_clk)
	);

    BUFGCE #(
       //.CE_TYPE("ASYNC"),
	   .SIM_DEVICE("7SERIES")
    ) en_valu (
	 	.I(clk),
	 	.CE(valu_clk_en),
	 	.O(valu_clk)
	);

    BUFGCE #(
       //.CE_TYPE("ASYNC"),
	   .SIM_DEVICE("7SERIES")
    ) en_vmul (
	 	.I(clk),
	 	.CE(vmul_clk_en),
	 	.O(vmul_clk)
	);

    BUFGCE #(
       //.CE_TYPE("ASYNC"),
	   .SIM_DEVICE("7SERIES")
    ) en_vsldu (
	 	.I(clk),
	 	.CE(vsldu_clk_en),
	 	.O(vsldu_clk)
	);

    BUFGCE #(
       //.CE_TYPE("ASYNC"),
	   .SIM_DEVICE("7SERIES")
    ) en_vlsu (
	 	.I(clk),
	 	.CE(vlsu_clk_en),
	 	.O(vlsu_clk)
	);

    //Vector Register File
	logic reg_wr_en, el_wr_en;
    logic [1:0] lanes = LANES;
	logic [2:0] vlmul;
    logic [2:0] vsew;
    logic [4:0] el_wr_addr;
	logic  [4:0] el_addr_1, el_addr_2;
	logic [32-1:0] el_data_out_1, el_data_out_2 ;
	logic [127:0] el_wr_data;
	logic [4:0] el_reg_wr_addr, el_rd_addr_1,el_rd_addr_2,mask_src;
    logic [127:0]  reg_wr_data,reg_wr_data_2,reg_wr_data_3,reg_wr_data_4;
	logic [127:0]  mask;
	logic [127:0] reg_data_out_v1_a,reg_data_out_v1_b,reg_data_out_v1_c,reg_data_out_v1_d;
	logic [127:0] reg_data_out_v2_a,reg_data_out_v2_b,reg_data_out_v2_c,reg_data_out_v2_d;
    logic [31:0] x_reg_data1;
    logic [31:0] x_reg_data2;
    logic x_reg_wr_en;

    logic [4:0] vs1, vs2, vd;
    logic [31:0] instr;
    logic [4:0] imm;
    logic [10:0] zimm;

    //From Base Processor
    assign instr = op_instr_base; 
    assign x_reg_data1 = xreg_out1;
    assign x_reg_data2 = xreg_out2;
    assign v_rd_xreg_addr1 = src_A;
    assign v_rd_xreg_addr2 = src_B;
    //assign v_data_addr = // address of data mem
    //assign data_addr0 = (is_vltype)? l_data_addr0 : s_data_addr0;
    //assign data_addr1 = (is_vltype)? l_data_addr1 : s_data_addr1;
    //assign data_addr2 = (is_vltype)? l_data_addr2 : s_data_addr2;
    //assign data_addr3 = (is_vltype)? l_data_addr3 : s_data_addr3;

	logic [4:0] src_A, src_B, src_C, src_D, dest_wb;
    logic [1:0] vsew_reg, lmul_reg;
    //assign which fi
    //assign which fj
    assign src_A = optype == 3'b001 ? Fj_alu: optype == 3'b010 ? Fj_mul: optype == 3'b011 ? Fj_lsu: optype == 3'b100 ? Fj_sldu: optype == 3'b101 ? Fj_red: 0;
    //assign which fk
    assign src_B = optype == 3'b001 ? Fk_alu: optype == 3'b010 ? Fk_mul: optype == 3'b011 ? Fk_lsu: optype == 3'b100 ? Fk_sldu: optype == 3'b101 ? Fk_red: 0;
    assign src_C = (optype == 3'b011 && is_vstype == 1) ? Fi_lsu: src_A;
    assign src_D = (optype == 3'b100) ? Fi_sldu: src_B;

	v_regfile vregfile(
        .clk(clk),
        .nrst(nrst),
        .lmul({1'b0, lmul_reg}),
        .sew({1'b0, vsew_reg}),
	    .el_wr_en(el_wr_en),
        .el_wr_addr(el_wr_addr),
        .el_reg_wr_addr(dest_wb),
        .el_wr_data(reg_wr_data),
        .reg_wr_en(reg_wr_en),
        .reg_wr_addr(dest_wb),
	    .reg_wr_data(reg_wr_data), //signal from v_writeback
        .reg_wr_data_2(reg_wr_data_2),
        .reg_wr_data_3(reg_wr_data_3),
        .reg_wr_data_4(reg_wr_data_4),
        .el_rd_addr_1(el_rd_addr_1),
        .el_rd_addr_2(el_rd_addr_2),
	    .el_addr_1(el_addr_1),
        .el_addr_2(el_addr_2),
        .mask_src(mask_src),
        .el_data_out_1(el_data_out_1),
	    .el_data_out_2(el_data_out_2),
        .mask(mask),
        .reg_rd_addr_v1(src_C),
        .reg_rd_addr_v2(src_D),
        .reg_data_out_v1_a(reg_data_out_v1_a),
        .reg_data_out_v1_b(reg_data_out_v1_b),
        .reg_data_out_v1_c(reg_data_out_v1_c),
        .reg_data_out_v1_d(reg_data_out_v1_d),
        .reg_data_out_v2_a(reg_data_out_v2_a),
        .reg_data_out_v2_b(reg_data_out_v2_b),
        .reg_data_out_v2_c(reg_data_out_v2_c),
        .reg_data_out_v2_d(reg_data_out_v2_d)
	);

    //Control Status Register
    logic [31:0] vl_out;
    logic [10:0] vtype_out;
    logic is_vconfig;

    assign vlmul = vtype_out[2:0]; //RISC-V Defintion
    assign vsew = vtype_out[5:3];  //RISC-V Defintion

    

	vcsr csr(
    .clk(clk),
    .nrst(nrst),
    .vconfig_wr_en(is_vconfig),
    .vl_in(op_instr_base),
    .vtype_in(op_instr_base),
    .vl_out(vl_out),
    .vtype_out(vtype_out)
	);


    //Decoder Block
    logic is_vector;
/*     logic [3:0] v_alu_op;
    logic [3:0] v_lsu_op;
    logic is_mul;    
    logic [2:0] v_sldu_op;
    logic [2:0] v_red_op; */

    logic [2:0] v_op_sel_A;
    logic [1:0] v_op_sel_B;
    logic [1:0] v_sel_dest;


	v_decoder vdecoder(
    .instr(instr),
    .v_reg_wr_en(reg_wr_en || el_wr_en),
    .x_reg_wr_en(x_reg_wr_en),
    .is_vector(is_vector),
    .is_vconfig(is_vconfig),
    .v_alu_op(v_alu_op),
    .is_mul(is_mul),
    .v_lsu_op(v_lsu_op),
    //.is_vstype(is_vstype),
    //.is_vltype(is_vltype),
    .v_sldu_op(v_sldu_op),
    .v_red_op(v_red_op),
    .v_op_sel_A(v_op_sel_A),
    .v_op_sel_B(v_op_sel_B),
    .v_sel_dest(v_sel_dest),
    .vd(vd),
    .vs1(vs1),
    .vs2(vs2),
    .imm(imm),
    .zimm(zimm)


	);
    /*logic [511:0] op_A;


    assign op_A = (v_op_sel_A == 1)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (v_op_sel_A == 2)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (v_op_sel_A == 3)? {{507{1'b0}}, imm} : 0 ;  //immediate data
    
    assign op_A = (v_op_sel_A == 1)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (v_op_sel_A == 2)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (v_op_sel_A == 3)? ((vsew == 3'b000) ? { 64{{3{1'b0}} , imm} } : (vsew == 3'b001) ? { 32{{11{1'b0}} , imm} } : (vsew == 3'b010) ? { 16{{27{1'b0}} , imm} } : 0) : 0 ;  //immediate data

    logic [511:0] op_B;

    assign op_B = (v_op_sel_B == 1)? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,reg_data_out_v2_a}:  //vs2 data
                  (v_op_sel_B == 2)? {{480{1'b0}}, x_reg_data2}:  //rs2 data
                  (v_op_sel_B == 3)? {{501{1'b0}}, zimm} : 0 ;  //zimmediate data
*/
/*     logic [511:0] op_C;
    
    assign op_C = {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a};
     */


    // Sequencer
    
    logic [2:0] vsew_alu, vsew_mul, vsew_lsu, vsew_sldu, vsew_red;        // Functional unit producing Fj (3) 
    logic [2:0] lmul_alu, lmul_mul, lmul_lsu, lmul_sldu, lmul_red;       // Functional unit producing Fk(3) (is_type)
    logic [2:0] Qj_alu, Qj_mul, Qj_lsu, Qj_sldu, Qj_red;        // Functional unit producing Fj (3) 
    logic [2:0] Qk_alu, Qk_mul, Qk_lsu, Qk_sldu, Qk_red, Qi_lsu;       // Functional unit producing Fk(3) (is_type)
    logic [4:0] Fj_alu, Fj_mul, Fj_lsu, Fj_sldu, Fj_red;        // source register 1 (5) (decoder)
    logic [4:0] Fk_alu, Fk_mul, Fk_lsu, Fk_sldu, Fk_red;        // source register 2 (5) (decoder)
    logic [4:0] Fi_lsu, Fi_sldu;       // destination reg (5) (decoder)
    logic [4:0] Imm_alu, Imm_mul, Imm_lsu, Imm_sldu, Imm_red;  // scalar operand (5) (decoder)
    logic [3:0] op_alu, op_mul, op_lsu, op_sldu, op_red;   
    logic [2:0] optype, optype_wb;
    logic [4:0] vsA, vsB;

    v_sequencer sequencer(
        .clk(clk),
        .nrst(nrst),
        .base_instr(op_instr_base),
        .sel_op_A(v_op_sel_A),
        .sel_op_B(v_op_sel_B),
        .sel_dest(v_sel_dest),
        .vsew(vsew),
        .lmul(vlmul),
        .src_A(vs1),
        .src_B(vs2),
        .dest(vd),
        .imm(imm),
        .is_vconfig(is_vconfig),
        .is_vector(is_vector),
        .is_vstype(is_vstype),
        .is_vltype(is_vltype),
        .v_alu_op(v_alu_op),
        .is_mul(is_mul),
        .v_lsu_op(v_lsu_op), 
        .v_sldu_op(v_sldu_op),
        .v_red_op(v_red_op),
        .done_alu(done_valu),
        .done_mul(done_vmul),
        .done_red(done_vred),
        .done_sldu(done_vsldu),        
        .done_lsu(done_vloadu == 1 || done_store == 1),  
        .result_vlsu(result_vloadu),
        .result_valu_1(result_valu_1),
        .result_valu_2(result_valu_2),
        .result_valu_3(result_valu_3),
        .result_valu_4(result_valu_4),
        .result_vmul_1(result_vmul_1), 
        .result_vmul_2(result_vmul_2), 
        .result_vmul_3(result_vmul_3), 
        .result_vmul_4(result_vmul_4), 
        .result_vsldu(result_vsldu),
        .result_vred(result_vred),
        .op_alu(op_alu),
        .op_mul(op_mul),
        .op_lsu(op_lsu),
        .op_sldu(op_sldu),
        .op_red(op_red),
        .vsew_alu(vsew_alu),
        .vsew_mul(vsew_mul),
        .vsew_lsu(vsew_lsu),
        .vsew_sldu(vsew_sldu),
        .vsew_red(vsew_red),
        .lmul_alu(lmul_alu),
        .lmul_mul(lmul_mul),
        .lmul_lsu(lmul_lsu),
        .lmul_sldu(lmul_sldu),
        .lmul_red(lmul_red),
        .Qj_alu(Qj_alu),
        .Qj_mul(Qj_mul),
        .Qj_lsu(Qj_lsu),
        .Qj_sldu(Qj_sldu),
        .Qj_red(Qj_red),       
        .Qk_alu(Qk_alu),
        .Qk_mul(Qk_mul),
        .Qk_lsu(Qk_lsu),
        .Qk_sldu(Qk_sldu),
        .Qk_red(Qk_red),
        .Qi_lsu(Qi_lsu),
        .Qi_sldu(Qi_sldu),
        .Fj_alu(Fj_alu),
        .Fj_mul(Fj_mul),
        .Fj_lsu(Fj_lsu),
        .Fj_sldu(Fj_sldu),
        .Fj_red(Fj_red),
        .Fk_alu(Fk_alu),
        .Fk_mul(Fk_mul),
        .Fk_lsu(Fk_lsu),
        .Fk_sldu(Fk_sldu),
        .Fk_red(Fk_red),
        .Fi_lsu(Fi_lsu),
        .Fi_sldu(Fi_sldu),
        .Imm_alu(Imm_alu),
        .Imm_mul(Imm_mul),
        .Imm_lsu(Imm_lsu),
        .Imm_sldu(Imm_sldu),
        .Imm_red(Imm_red),
        .v_reg_wr_en(reg_wr_en),
        .x_reg_wr_en(x_reg_wr_en),
        .el_wr_en(el_wr_en), 
        .el_wr_addr(el_wr_addr),
        .reg_wr_data(reg_wr_data),
        .reg_wr_data_2(reg_wr_data_2), 
        .reg_wr_data_3(reg_wr_data_3), 
        .reg_wr_data_4(reg_wr_data_4),
        .optype_read(optype),
        .dest_wb(dest_wb),
        .vsew_wb(vsew_reg),
        .lmul_wb(lmul_reg)
    );

        logic [511:0] op_A_alu, op_A_mul, op_A_lsu, op_A_sldu, op_A_red;
        logic [511:0] op_B_alu, op_B_mul, op_B_lsu, op_B_sldu, op_B_red;
        logic [511:0] op_C_lsu, op_C_sldu;
        //assign source_a for each fu
        assign op_A_alu = (optype == 3'b001 && op_alu != 0)?((Qj_alu == 0) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qj_alu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qj_alu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qj_alu == 3) ? result_vloadu:
                  (Qj_alu == 4) ? result_vsldu:
                  (Qj_alu == 5) ? ((vsew_alu == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:8],result_vred[7:0]}}: 
                                    (vsew_alu == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:16],result_vred[15:0]}}: 
                                    (vsew_alu == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:32],result_vred}}: op_A_alu):
                  //(Qj_alu == 5) ? {{480{1'b0}}, result_vred}:
                  //(Qj_alu == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qj_alu == 6)? ((vsew_alu == 3'b000) ? { 64{x_reg_data1[7:0]} } : (vsew_alu == 3'b001) ? { 32{x_reg_data1[15:0]} } : (vsew_alu == 3'b010) ? { 16{x_reg_data1} } : 0):  //rs1_data data
                  (Qj_alu == 7)? ((vsew_alu == 3'b000) ? { 64{{3{1'b0}} , Imm_alu} } : (vsew_alu == 3'b001) ? { 32{{11{1'b0}} , Imm_alu} } : (vsew_alu == 3'b010) ? { 16{{27{1'b0}} , Imm_alu} } : op_A_alu) : op_A_alu): op_A_alu;  //immediate data
        assign op_A_mul = (optype == 3'b010 && op_mul != 0)?((Qj_mul == 0)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qj_mul == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qj_mul == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qj_mul == 3) ? result_vloadu:
                  (Qj_mul == 4) ? result_vsldu:
                  //(Qj_mul == 5) ? {{480{1'b0}}, result_vred}:
                  (Qj_mul == 5) ? ((vsew_mul == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:8],result_vred[7:0]}}: 
                                    (vsew_mul == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:16],result_vred[15:0]}}: 
                                    (vsew_mul == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:32],result_vred}}: op_A_alu):
                  //(Qj_mul == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qj_mul == 6)? ((vsew_mul == 3'b000) ? { 64{x_reg_data1[7:0]} } : (vsew_mul == 3'b001) ? { 32{x_reg_data1[15:0]} } : (vsew_mul == 3'b010) ? { 16{x_reg_data1} } : 0):  //rs1_data data
                  (Qj_mul == 7)? ((vsew_mul == 3'b000) ? { 64{{3{1'b0}} , Imm_mul} } : (vsew_mul == 3'b001) ? { 32{{11{1'b0}} , Imm_mul} } : (vsew_mul == 3'b010) ? { 16{{27{1'b0}} , Imm_mul} } : op_A_mul) : op_A_mul): op_A_mul;  //immediate data
        assign op_A_lsu = (optype == 3'b011 && op_lsu != 0)?((Qj_lsu == 0)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qj_lsu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qj_lsu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qj_lsu == 3) ? result_vloadu:
                  (Qj_lsu == 4) ? result_vsldu:
                  (Qj_lsu == 5) ? ((vsew_lsu == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:8],result_vred[7:0]}}: 
                                    (vsew_lsu == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:16],result_vred[15:0]}}: 
                                    (vsew_lsu == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:32],result_vred}}: op_A_alu):
                  //(Qj_lsu == 5) ? {{480{1'b0}}, result_vred}:
                  (Qj_lsu == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qj_lsu == 7)? ((vsew_lsu == 3'b000) ? { 64{{3{1'b0}} , Imm_lsu} } : (vsew_lsu == 3'b001) ? { 32{{11{1'b0}} , Imm_lsu} } : (vsew_lsu == 3'b010) ? { 16{{27{1'b0}} , Imm_lsu} } : op_A_lsu) :op_A_lsu): op_A_lsu;  //immediate data
        assign op_A_sldu = (optype == 3'b100 && op_sldu != 0)?((Qj_sldu == 0)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qj_sldu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qj_sldu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qj_sldu == 3) ? result_vloadu:
                  (Qj_sldu == 4) ? result_vsldu:
                  (Qj_sldu == 5) ? ((vsew_sldu == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:8],result_vred[7:0]}}: 
                                    (vsew_sldu == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:16],result_vred[15:0]}}: 
                                    (vsew_sldu == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:32],result_vred}}: op_A_alu):
                  //(Qj_sldu == 5) ? {{480{1'b0}}, result_vred}:
                  (Qj_sldu == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qj_sldu == 7)? ((vsew_sldu == 3'b000) ? { 64{{3{1'b0}} , Imm_sldu} } : (vsew_sldu == 3'b001) ? { 32{{11{1'b0}} , Imm_sldu} } : (vsew_sldu == 3'b010) ? { 16{{27{1'b0}} , Imm_sldu} } : op_A_sldu) :op_A_sldu): op_A_sldu;  //immediate data
        assign op_A_red = (optype == 3'b101 && op_red != 0)?((Qj_red == 0)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qj_red == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qj_red == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qj_red == 3) ? result_vloadu:
                  (Qj_red == 4) ? result_vsldu:
                  (Qj_red == 5) ? ((vsew_red == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:8],result_vred[7:0]}}: 
                                    (vsew_red == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:16],result_vred[15:0]}}: 
                                    (vsew_red == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a [127:32],result_vred}}: op_A_alu):
                  //(Qj_red == 5) ? {{480{1'b0}}, result_vred}:
                  (Qj_red == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qj_red == 7)? ((vsew_red == 3'b000) ? { 64{{3{1'b0}} , Imm_red} } : (vsew_red == 3'b001) ? { 32{{11{1'b0}} , Imm_red} } : (vsew_red == 3'b010) ? { 16{{27{1'b0}} , Imm_red} } : op_A_red) :op_A_red): op_A_red;  //immediate data

        //assign source_b for each fu
        assign op_B_alu = (optype == 3'b001 && op_alu != 0)?((Qk_alu == 0) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,reg_data_out_v2_a}:  //vs1 data
                  (Qk_alu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qk_alu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qk_alu == 3) ? result_vloadu:
                  (Qk_alu == 4) ? result_vsldu:
                  (Qk_alu == 5) ? ((vsew_alu == 3'b000) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:8],result_vred[7:0]}}: 
                                    (vsew_alu == 3'b001) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:16],result_vred[15:0]}}: 
                                    (vsew_alu == 3'b010) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:32],result_vred}}: op_A_alu):
                  //(Qk_alu == 5) ? {{480{1'b0}}, result_vred}:
                  (Qk_alu == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qk_alu == 7)? ((vsew_alu == 3'b000) ? { 64{{3{1'b0}} , Imm_alu} } : (vsew_alu == 3'b001) ? { 32{{11{1'b0}} , Imm_alu} } : (vsew_alu == 3'b010) ? { 16{{27{1'b0}} , Imm_alu} } : op_B_alu) : op_B_alu): op_B_alu;  //immediate data
        assign op_B_mul = (optype == 3'b010 && op_mul != 0)?((Qk_mul == 0)? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,reg_data_out_v2_a}:  //vs1 data
                  (Qk_mul == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qk_mul == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qk_mul == 3) ? result_vloadu:
                  (Qk_mul == 4) ? result_vsldu:
                  (Qk_mul == 5) ? ((vsew_mul == 3'b000) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:8],result_vred[7:0]}}: 
                                    (vsew_mul == 3'b001) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:16],result_vred[15:0]}}: 
                                    (vsew_mul == 3'b010) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:32],result_vred}}: op_A_alu):
                  //(Qk_mul == 5) ? {{480{1'b0}}, result_vred}:
                  (Qk_mul == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qk_mul == 7)? ((vsew_mul == 3'b000) ? { 64{{3{1'b0}} , Imm_mul} } : (vsew_mul == 3'b001) ? { 32{{11{1'b0}} , Imm_mul} } : (vsew_mul == 3'b010) ? { 16{{27{1'b0}} , Imm_mul} } : op_B_mul) : op_B_mul): op_B_mul;  //immediate data
        assign op_B_lsu = (optype == 3'b011 && op_lsu != 0)?((Qk_lsu == 0)? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,reg_data_out_v2_a}:  //vs1 data
                  (Qk_lsu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qk_lsu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qk_lsu == 3) ? result_vloadu:
                  (Qk_lsu == 4) ? result_vsldu:
                  (Qk_lsu == 5) ? ((vsew_lsu == 3'b000) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:8],result_vred[7:0]}}: 
                                    (vsew_lsu == 3'b001) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:16],result_vred[15:0]}}: 
                                    (vsew_lsu == 3'b010) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:32],result_vred}}: op_A_alu):
                  //(Qk_lsu == 5) ? {{480{1'b0}}, result_vred}:
                  (Qk_lsu == 6)? {{480{1'b0}}, x_reg_data2}:  //rs2 data
                  (Qk_lsu == 7)? ((vsew_lsu == 3'b000) ? { 64{{3{1'b0}} , Imm_lsu} } : (vsew_lsu == 3'b001) ? { 32{{11{1'b0}} , Imm_lsu} } : (vsew_lsu == 3'b010) ? { 16{{27{1'b0}} , Imm_lsu} } : op_B_lsu) :op_B_lsu): op_B_lsu;  //immediate data
        assign op_B_sldu = (optype == 3'b100 && op_sldu != 0)?((Qk_sldu == 0)? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,reg_data_out_v2_a}:  //vs1 data
                  (Qk_sldu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qk_sldu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qk_sldu == 3) ? result_vloadu:
                  (Qk_sldu == 4) ? result_vsldu:
                  (Qk_sldu == 5) ? ((vsew_sldu == 3'b000) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:8],result_vred[7:0]}}: 
                                    (vsew_sldu == 3'b001) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:16],result_vred[15:0]}}: 
                                    (vsew_sldu == 3'b010) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:32],result_vred}}: op_A_alu):
                  //(Qk_sldu == 5) ? {{480{1'b0}}, result_vred}:
                  (Qk_sldu == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qk_sldu == 7)? ((vsew_sldu == 3'b000) ? { 64{{3{1'b0}} , Imm_sldu} } : (vsew_sldu == 3'b001) ? { 32{{11{1'b0}} , Imm_sldu} } : (vsew_sldu == 3'b010) ? { 16{{27{1'b0}} , Imm_sldu} } : op_B_sldu) :op_B_sldu): op_B_sldu;  //immediate data
        assign op_B_red = (optype == 3'b101 && op_red != 0)?((Qk_red == 0)? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,reg_data_out_v2_a}:  //vs1 data
                  (Qk_red == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qk_red == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qk_red == 3) ? result_vloadu:
                  (Qk_red == 4) ? result_vsldu:
                  (Qk_red == 5) ? ((vsew_red == 3'b000) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:8],result_vred[7:0]}}: 
                                    (vsew_red == 3'b001) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:16],result_vred[15:0]}}: 
                                    (vsew_red == 3'b010) ? {reg_data_out_v2_d,reg_data_out_v2_c,reg_data_out_v2_b,{reg_data_out_v2_a [127:32],result_vred}}: op_A_alu):
                  //(Qk_red == 5) ? {{480{1'b0}}, result_vred}:
                  (Qk_red == 6)? {{480{1'b0}}, x_reg_data1}:  //rs1 data
                  (Qk_red == 7)? ((vsew_red == 3'b000) ? { 64{{3{1'b0}} , Imm_red} } : (vsew_red == 3'b001) ? { 32{{11{1'b0}} , Imm_red} } : (vsew_red == 3'b010) ? { 16{{27{1'b0}} , Imm_red} } : op_B_red) :op_B_red): op_B_red;  //immediate data

/*         assign op_C_lsu = (op_lsu inside {[7:12]}) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}: op_C_lsu;
 */

         assign op_C_lsu = (optype == 3'b011 && is_vstype == 1) ? ((Qi_lsu == 0)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qi_lsu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qi_lsu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qi_lsu == 3) ? result_vloadu:
                  (Qi_lsu == 4) ? result_vsldu:
                  (Qi_lsu == 5) ? ((vsew_lsu == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a[127:8],result_vred[7:0]}}: 
                                    (vsew_lsu == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a[127:16],result_vred[15:0]}}: 
                                    (vsew_lsu == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a[127:32],result_vred}}: op_C_lsu): op_C_lsu): op_C_lsu;
                  //(Qi_lsu == 5) ? {{480{1'b0}}, result_vred}: 0;  //immediate data 
        
         assign op_C_sldu = (optype == 3'b100) ? ((Qi_lsu == 0)? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,reg_data_out_v1_a}:  //vs1 data
                  (Qi_sldu == 1) ? {result_valu_4, result_valu_3, result_valu_2, result_valu_1}:
                  (Qi_sldu == 2) ? {result_vmul_4, result_vmul_3, result_vmul_2, result_vmul_1}:
                  (Qi_sldu == 3) ? result_vloadu:
                  (Qi_sldu == 4) ? result_vsldu:
                  (Qi_sldu == 5) ? ((vsew_lsu == 3'b000) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a[127:8],result_vred[7:0]}}: 
                                    (vsew_lsu == 3'b001) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a[127:16],result_vred[15:0]}}: 
                                    (vsew_lsu == 3'b010) ? {reg_data_out_v1_d,reg_data_out_v1_c,reg_data_out_v1_b,{reg_data_out_v1_a[127:32],result_vred}}: op_C_lsu): op_C_lsu): op_C_lsu;
                  //(Qi_lsu == 5) ? {{480{1'b0}}, result_vred}: 0;  //immediate data 

    //Vector Reduction Blok
    logic done_vred;
    logic [31:0] result_vred;


    v_red vred(
        .clk(vred_clk),
        .nrst(nrst),
        .op_instr(op_red[2:0]),
        .sew(vsew_red),
        .lmul(lmul_red),
        .vec_regA(op_A_red[31:0]),
        .vec_regB_1(op_B_red[127:0]),
        .vec_regB_2(op_B_red[255:128]),
        .vec_regB_3(op_B_red[383:256]),
        .vec_regB_4(op_B_red[511:384]),
        .done(done_vred),
        .result(result_vred)
    );

    //Vector SLDU
    logic [511:0] result_vsldu; //vd
    logic done_vsldu;
    
	v_sldu vsldu(
	.clk(vsldu_clk),
	.nrst(nrst),
	.op_instr(op_sldu[2:0]),
	.sew(vsew_sldu),
	.lmul(lmul_sldu),
	.vs2_1(op_B_sldu[127:0]),
	.vs2_2(op_B_sldu[255:128]),
	.vs2_3(op_B_sldu[383:256]),
	.vs2_4(op_B_sldu[511:384]),
    .vd(op_C_sldu),
	.rs1(op_A_sldu[127:0]),
    .done_vsldu(done_vsldu),
	.result(result_vsldu)
	);

      //VLSU
      /*
    logic is_load, is_store;
    //logic [6:0] v_lsu_op;
    //logic [31:0] l_addr;
    logic [31:0] l_data_in1, l_data_in2, l_data_in3, l_data_in4; 
    logic [1:0] write_en1, write_en2, write_en3, write_en4;
    logic [511:0] l_data_out;
    logic [31:0] s_data_out1, s_data_out2, s_data_out3, s_data_out4; 
    logic [`DATAMEM_BITS-1:0] s_addr;                          // Base Address - from rs1

    assign is_load = (v_lsu_op > 0 && v_lsu_op <7);
    assign is_store = (v_lsu_op > 6 && v_lsu_op <13);

    
    v_lsu vlsu(
    .l_data_in0(v_load_data_0),
    .l_data_in1(v_load_data_1),
    .l_data_in2(v_load_data_2),
    .l_data_in3(v_load_data_3),
    .vlsu_op(v_lsu_op),  // v_lsu_op
    .lmul(vlmul),
    .l_addr(xreg_out1),
    .is_load(is_load),
    .is_store(is_store),
    .l_data_out(l_data_out),
    .s_data_in(op_A),
    .write_en0(write_en0),
    .write_en1(write_en1),
    .write_en2(write_en2),
    .write_en3(write_en3),
    .l_done(l_done),
    .s_done(s_done),
    .s_addr(s_addr), //TO EDIT
    .data_addr0(data_addr0),
    .data_addr1(data_addr1),
    .data_addr2(data_addr2),
    .data_addr3(data_addr3),
    .s_data_out0(v_store_data_0),
    .s_data_out1(v_store_data_1),
    .s_data_out2(v_store_data_2),
    .s_data_out3(v_store_data_3)
    );  
    */
    // Store Unit
    logic done_store;
    logic [`DATAMEM_BITS-1:0] s_data_addr0;
    logic [`DATAMEM_BITS-1:0] s_data_addr1;
    logic [`DATAMEM_BITS-1:0] s_data_addr2;
    logic [`DATAMEM_BITS-1:0] s_data_addr3;

/* //modify
    v_storeunit vstoreunit (
        .clk(clk),
        .nrst(nrst),
        .store_op(op_lsu),
        .lmul(lmul_lsu),
        .vsew(vsew_lsu),
        .stride(xreg_out2),          // DOUBLE CHECK
        .address(xreg_out1),         // DOUBLE CHECK
        .data(op_C),                 // DOUBLE CHECK

        .data_addr0(s_data_addr0),
        .data_addr1(s_data_addr1),
        .data_addr2(s_data_addr2),
        .data_addr3(s_data_addr3),
        .data_out0(v_store_data_0),
        .data_out1(v_store_data_1),
        .data_out2(v_store_data_2),
        .data_out3(v_store_data_3),
        .done(done_store)
    );   */

    
    logic [511:0] result_vloadu;
    logic done_vloadu;
    logic [`DATAMEM_BITS-1:0] l_data_addr0;
    logic [`DATAMEM_BITS-1:0] l_data_addr1;
    logic [`DATAMEM_BITS-1:0] l_data_addr2;
    logic [`DATAMEM_BITS-1:0] l_data_addr3;

/*     v_loadu vloadu(
    .clk(clk),
    .l_data_in0(v_load_data_0), 
    .l_data_in1(v_load_data_1),
    .l_data_in2(v_load_data_2),
    .l_data_in3(v_load_data_3),
    .v_lsu_op(op_lsu),
    .lmul(vlmul),
    .vsew(vsew),
    .stride(xreg_out2), 
    .l_addr(xreg_out1),
    .data_addr0(l_data_addr0),  
    .data_addr1(l_data_addr1),  
    .data_addr2(l_data_addr2),  
    .data_addr3(l_data_addr3),  
    .l_data_out(result_vloadu),
    .l_done(done_vloadu)
    ); */

    //VLSU

    v_lsu vlsu(
    .clk(vlsu_clk), 
    .nrst(nrst),
    .l_data_in0(v_load_data_0), 
    .l_data_in1(v_load_data_1),
    .l_data_in2(v_load_data_2),
    .l_data_in3(v_load_data_3),
    .v_lsu_op(op_lsu),
    .lmul(lmul_lsu),
    .vsew(vsew_lsu),
    .stride(op_B_lsu[31:0]), 
    .address(op_A_lsu[31:0]), 
    .l_data_out(result_vloadu),
    .l_done(done_vloadu),
    .s_data(op_C_lsu),                 // DOUBLE CHECK
    .data_addr0(data_addr0),
    .data_addr1(data_addr1),
    .data_addr2(data_addr2),
    .data_addr3(data_addr3),
    .data_out0(v_store_data_0),
    .data_out1(v_store_data_1),
    .data_out2(v_store_data_2),
    .data_out3(v_store_data_3),
    .dm_v_write(dm_v_write),
    .s_done(done_store)
    );    

    //V_LANES
    logic done_valu;
    logic done_vmul;
    logic [127:0] result_valu_1;
    logic [127:0] result_valu_2;
    logic [127:0] result_valu_3;
    logic [127:0] result_valu_4;

    logic [127:0] result_vmul_1;
    logic [127:0] result_vmul_2;
    logic [127:0] result_vmul_3;    
    logic [127:0] result_vmul_4;

    logic [2:0] lmul_lanes, vsew_lanes;

    assign lmul_lanes = (optype == 3'b001) ? lmul_alu: (optype == 3'b010) ? lmul_mul: lmul_lanes;
    assign vsew_lanes = (optype == 3'b001) ? vsew_alu: (optype == 3'b010) ? vsew_mul: vsew_lanes;

    v_lanes vlanes(
        //.clk(clk),
        .valu_clk(valu_clk),
        .vmul_clk(vmul_clk),
        .nrst(nrst),
        .op_instr_alu(op_alu),
        .is_mul(op_mul[0]),
        .vsew(vsew_lanes), //assign
        .lmul(lmul_lanes), //assign
        .lanes(lanes),
        .result_valu_1(result_valu_1),
        .result_vmul_1(result_vmul_1),
        .result_valu_2(result_valu_2),
        .result_vmul_2(result_vmul_2),
        .result_valu_3(result_valu_3),
        .result_vmul_3(result_vmul_3),
        .result_valu_4(result_valu_4),
        .result_vmul_4(result_vmul_4),
        .done_valu(done_valu),
        .done_vmul(done_vmul),

        .op_A_1_alu(op_A_alu[127:0]), //assign
        .op_A_2_alu(op_A_alu[255:128]), //assign
        .op_A_3_alu(op_A_alu[383:256]), //assign
        .op_A_4_alu(op_A_alu[511:384]), //assign
        .op_B_1_alu(op_B_alu[127:0]), //assign
        .op_B_2_alu(op_B_alu[255:128]), //assign
        .op_B_3_alu(op_B_alu[383:256]), //assign
        .op_B_4_alu(op_B_alu[511:384]), //assign

        .op_A_1_mul(op_A_mul[127:0]), //assign
        .op_A_2_mul(op_A_mul[255:128]), //assign
        .op_A_3_mul(op_A_mul[383:256]), //assign
        .op_A_4_mul(op_A_mul[511:384]), //assign
        .op_B_1_mul(op_B_mul[127:0]), //assign
        .op_B_2_mul(op_B_mul[255:128]), //assign
        .op_B_3_mul(op_B_mul[383:256]), //assign
        .op_B_4_mul(op_B_mul[511:384]) //assign

/*         .op_A_1_alu((optype == 3'b001) ? op_A_alu[127:0]: (optype == 3'b010) ? op_A_mul[127:0]: 0), //assign
        .op_A_2_alu((optype == 3'b001) ? op_A_alu[255:128]: (optype == 3'b010) ? op_A_mul[255:128]: 0), //assign
        .op_A_3_alu((optype == 3'b001) ? op_A_alu[383:256]: (optype == 3'b010) ? op_A_mul[383:256]: 0), //assign
        .op_A_4_alu((optype == 3'b001) ? op_A_alu[511:384]: (optype == 3'b010) ? op_A_mul[511:384]: 0), //assign
        .op_B_1_alu((optype == 3'b001) ? op_B_alu[127:0]: (optype == 3'b010) ? op_B_mul[127:0]: 0), //assign
        .op_B_2_alu((optype == 3'b001) ? op_B_alu[255:128]: (optype == 3'b010) ? op_B_mul[255:128]: 0), //assign
        .op_B_3_alu((optype == 3'b001) ? op_B_alu[383:256]: (optype == 3'b010) ? op_B_mul[383:256]: 0), //assign
        .op_B_4_alu((optype == 3'b001) ? op_B_alu[511:384]: (optype == 3'b010) ? op_B_mul[511:384]: 0), //assign

        .op_A_1_mul((optype == 3'b001) ? op_A_alu[127:0]: (optype == 3'b010) ? op_A_mul[127:0]: 0), //assign
        .op_A_2_mul((optype == 3'b001) ? op_A_alu[255:128]: (optype == 3'b010) ? op_A_mul[255:128]: 0), //assign
        .op_A_3_mul((optype == 3'b001) ? op_A_alu[383:256]: (optype == 3'b010) ? op_A_mul[383:256]: 0), //assign
        .op_A_4_mul((optype == 3'b001) ? op_A_alu[511:384]: (optype == 3'b010) ? op_A_mul[511:384]: 0), //assign
        .op_B_1_mul((optype == 3'b001) ? op_B_alu[127:0]: (optype == 3'b010) ? op_B_mul[127:0]: 0), //assign
        .op_B_2_mul((optype == 3'b001) ? op_B_alu[255:128]: (optype == 3'b010) ? op_B_mul[255:128]: 0), //assign
        .op_B_3_mul((optype == 3'b001) ? op_B_alu[383:256]: (optype == 3'b010) ? op_B_mul[383:256]: 0), //assign
        .op_B_4_mul((optype == 3'b001) ? op_B_alu[511:384]: (optype == 3'b010) ? op_B_mul[511:384]: 0) //assign */

    );




/*
	// Writeback

    carrd_writeback vwriteback(
        .clk(clk),
        .v_alu_op(v_alu_op),
        .is_mul(is_mul),
        .v_lsu_op(v_lsu_op), 
        .v_sldu_op(v_sldu_op),
        .v_red_op(v_red_op),
        .done_valu(done_valu),
        .done_vmul(done_vmul),
        .done_vred(done_vred),
        .done_vsldu(done_vsldu),        
        .done_vload(done_vloadu),        
        .result_vload(result_vloadu),
        .result_valu_1(result_valu_1),
        .result_valu_2(result_valu_2),
        .result_valu_3(result_valu_3),
        .result_valu_4(result_valu_4),
        .result_vmul_1(result_vmul_1), 
        .result_vmul_2(result_vmul_2), 
        .result_vmul_3(result_vmul_3), 
        .result_vmul_4(result_vmul_4), 
        .result_vsldu(result_vsldu),
        .result_vred(result_vred),
        .v_sel_dest(v_sel_dest), 
        .v_reg_wr_en(reg_wr_en),
        .x_reg_wr_en(x_reg_wr_en),
        .el_wr_en(el_wr_en), 
        .reg_wr_data(reg_wr_data),
        .reg_wr_data_2(reg_wr_data_2), 
        .reg_wr_data_3(reg_wr_data_3), 
        .reg_wr_data_4(reg_wr_data_4) 
    );
*/
/*     carrd_writeback vwriteback( //BEFORE CHANGING LSU
        .clk(clk),
        .v_alu_op(v_alu_op),
        .is_mul(is_mul),
        .v_lsu_op(v_lsu_op), 
        .v_sldu_op(v_sldu_op),
        .v_red_op(v_red_op),
        .done_valu(done_valu),
        .done_vmul(done_vmul),
        .done_vred(done_vred),
        .done_vsldu(done_vsldu),        
        .done_vlsu(done_vlsu),        
        .result_vlsu(result_vlsu),
        .result_valu_1(result_valu_1),
        .result_valu_2(result_valu_2),
        .result_valu_3(result_valu_3),
        .result_valu_4(result_valu_4),
        .result_vmul_1(result_vmul_1), 
        .result_vmul_2(result_vmul_2), 
        .result_vmul_3(result_vmul_3), 
        .result_vmul_4(result_vmul_4), 
        .result_vsldu(result_vsldu),
        .result_vred(result_vred),
        .v_sel_dest(v_sel_dest), 
        .v_reg_wr_en(reg_wr_en),
        .x_reg_wr_en(x_reg_wr_en),
        .el_wr_en(el_wr_en), 
        .reg_wr_data(reg_wr_data),
        .reg_wr_data_2(reg_wr_data_2), 
        .reg_wr_data_3(reg_wr_data_3), 
        .reg_wr_data_4(reg_wr_data_4) 
    ); */

endmodule
