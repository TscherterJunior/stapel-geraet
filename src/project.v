/*
 * Copyright (c) 2026 Nicolas Tscherter
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_TscherterJunior_stapel_geraet (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  /*
  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};
  */

  wire _unused = &{ ena,uio_in, stack_address[15:14]};

  assign uio_oe = 8'b1111_1111; // all output
  
  wire [15:0] fused_output_w;
  assign uo_out  = fused_output_w[15:8];
  assign uio_out = fused_output_w[7:0];


  localparam stack_size_lp = 16;
  localparam extmem_address_width = 14; 
  //localparam extmem_address_mask = 16'b0011_1111_1111_1111;



  // instructions
  localparam full_opcode_mask = 8'b1111_1111;

  localparam oc_push_zero = 8'b0000_0000;
  localparam ms_push_zero = full_opcode_mask;

  localparam oc_swap = 8'b1000_0000;
  localparam ms_swap = full_opcode_mask;

  localparam oc_add = 8'b0100_0000;
  localparam ms_add = full_opcode_mask;

  localparam oc_load_ext = 8'b1100_0000;
  localparam ms_load_ext = full_opcode_mask;

  localparam oc_store_ext = 8'b0010_0000;
  localparam ms_store_ext = full_opcode_mask;

  localparam oc_nop = 8'b1010_0000;
  localparam ms_nop = full_opcode_mask;

  localparam oc_push_imd = 8'b0110_0000;
  localparam ms_push_imd = full_opcode_mask;

  localparam oc_jmp_nz = 8'b1110_0000;
  localparam ms_jmp_nz = full_opcode_mask;

  localparam oc_dup = 8'b0001_0000;
  localparam ms_dup = full_opcode_mask;

  localparam oc_sub = 8'b1001_0000;
  localparam ms_sub = full_opcode_mask;

  localparam oc_pop_to_scratch_1 = 8'b0101_0000;
  localparam ms_pop_to_scratch_1 = full_opcode_mask;

  localparam oc_push_from_scratch_1 = 8'b1101_0000;
  localparam ms_push_from_scratch_1 = full_opcode_mask;

  localparam oc_pop_to_scratch_2 = 8'b0011_0000;
  localparam ms_pop_to_scratch_2 = full_opcode_mask;

  localparam oc_push_from_scratch_2 = 8'b1011_0000;
  localparam ms_push_from_scratch_2 = full_opcode_mask;

  localparam oc_drop = 8'b0111_0000;
  localparam ms_drop = full_opcode_mask;

  localparam oc_mul = 8'b1111_0000;
  localparam ms_mul = full_opcode_mask;

  localparam oc_and = 8'b0000_1000;
  localparam ms_and = full_opcode_mask;

  localparam oc_or = 8'b1000_1000;
  localparam ms_or = full_opcode_mask;

  localparam oc_xor = 8'b0100_1000;
  localparam ms_xor = full_opcode_mask;

  localparam oc_not = 8'b1100_1000;
  localparam ms_not = full_opcode_mask;

  localparam oc_shift_left = 8'b0010_1000;
  localparam ms_shift_left = full_opcode_mask;

  localparam oc_shift_right = 8'b1010_1000;
  localparam ms_shift_right = full_opcode_mask;

  localparam oc_push_instp = 8'b0110_1000;
  localparam ms_push_instp = full_opcode_mask;

  // cpu fsm
  localparam logic[cpu_state_width_lp-1:0] cs_fetch = 0;

  localparam logic[cpu_state_width_lp-1:0] cs_load_adrr = 1;

  localparam logic[cpu_state_width_lp-1:0] cs_store_adrr = 2;
  localparam logic[cpu_state_width_lp-1:0] cs_store_data = 3;

  localparam logic[cpu_state_width_lp-1:0] cs_load_imd = 4;

  localparam cpu_fsm_state_count_lp = 5;
  localparam cpu_state_width_lp = $clog2(cpu_fsm_state_count_lp);


  reg [cpu_state_width_lp-1:0] fsm_state_q;
  reg [cpu_state_width_lp-1:0] fsm_state_d;
  localparam logic[cpu_state_width_lp-1:0] fsm_state_r_lp = cs_fetch;

  // stack
  reg [7:0] stack_s[stack_size_lp - 1:0];
  localparam stack_cell_r_lp = 8'(0);

  localparam stack_address_width_lp = $clog2(stack_size_lp);
  reg [stack_address_width_lp-1:0] stack_pointer_q;
  // reg [stack_address_width_lp-1:0] stack_pointer_d;
  localparam logic[stack_address_width_lp-1:0] stack_pointer_r_lp = '0;

  //reg [7:0] stack_ccell_new_val_w;

  // Instruction Pointer
  reg [15:0] instruction_pointer_q;
  reg [15:0] instruction_pointer_d;

  // scratch 1
  reg [15:0] scratch_1_s;
  reg [15:0] scratch_2_s;

  wire [15:0] multiplication_result_w;

  assign multiplication_result_w =
      {8'b0, stack_s[stack_pointer_q - 1]} *
      {8'b0, stack_s[stack_pointer_q]};


  // CPU FSM
  always @(*) begin
    case (fsm_state_q)
      cs_fetch: begin 
        if ((ms_load_ext & oc_load_ext) == (ms_load_ext & ui_in)) begin 
          fsm_state_d = cs_load_adrr;
        end
        else if ((ms_store_ext & oc_store_ext) == (ms_store_ext & ui_in)) begin 
          fsm_state_d = cs_store_adrr;
        end
        else if ((ms_push_imd & oc_push_imd) == (ms_push_imd & ui_in)) begin 
          fsm_state_d = cs_load_imd;
        end
        else begin 
          fsm_state_d = fsm_state_q;
        end
      end
      cs_load_adrr: begin 
        fsm_state_d = cs_fetch;
      end
      cs_store_adrr: begin 
        fsm_state_d = cs_store_data;
      end
      cs_store_data: begin 
        fsm_state_d = cs_fetch;
      end
      cs_load_imd: begin 
        fsm_state_d = cs_fetch;
      end
      default: fsm_state_d = fsm_state_q;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if(! rst_n) fsm_state_q <= fsm_state_r_lp;
    else        fsm_state_q <= fsm_state_d;
  end


  // STACK
  // we don't do the _d _q thing here because it would be fucking awfull
  always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        for (int i = 0; i < stack_size_lp; i++) begin
          stack_s[i] <= stack_cell_r_lp;
        end
        stack_pointer_q <= stack_pointer_r_lp;
      end else begin
        case (fsm_state_q)
            
        cs_fetch : begin
          if((ms_push_zero & oc_push_zero) == (ms_push_zero & ui_in)) begin
            stack_s[stack_pointer_q + 1] <= 8'b0;
            stack_pointer_q <= stack_pointer_q + 1;
          end
          else if ((ms_swap & oc_swap) == (ms_swap & ui_in)) begin
            stack_s[stack_pointer_q] <= stack_s[stack_pointer_q -1];
            stack_s[stack_pointer_q -1] <= stack_s[stack_pointer_q];
          end
          else if ((ms_add & oc_add) == (ms_add & ui_in)) begin
            stack_s[stack_pointer_q-1] <= stack_s[stack_pointer_q-1] + stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end 
          else if ((ms_jmp_nz & oc_jmp_nz) == (ms_jmp_nz & ui_in)) begin 
            stack_pointer_q <= stack_pointer_q - 2;
          end
          else if ((ms_dup & oc_dup) == (ms_dup & ui_in)) begin 
            stack_pointer_q <= stack_pointer_q + 1;
            stack_s[stack_pointer_q + 1] <= stack_s[stack_pointer_q];
          end
          else if ((ms_sub & oc_sub) == (ms_sub & ui_in)) begin
            stack_s[stack_pointer_q-1] <= stack_s[stack_pointer_q-1] - stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end 
          else if ((ms_pop_to_scratch_1 & oc_pop_to_scratch_1) == (ms_pop_to_scratch_1 & ui_in)) begin
            scratch_1_s <= {stack_s[stack_pointer_q -1],stack_s[stack_pointer_q]};
            stack_pointer_q <= stack_pointer_q - 2;
          end
          else if ((ms_push_from_scratch_1 & oc_push_from_scratch_1) == (ms_push_from_scratch_1 & ui_in)) begin
            stack_s[stack_pointer_q + 1] <= scratch_1_s[15:8];
            stack_s[stack_pointer_q + 2] <= scratch_1_s[7:0];
            stack_pointer_q <= stack_pointer_q + 2;
          end           
          else if ((ms_pop_to_scratch_2 & oc_pop_to_scratch_2) == (ms_pop_to_scratch_2 & ui_in)) begin
            scratch_2_s <= {stack_s[stack_pointer_q -1],stack_s[stack_pointer_q]};
            stack_pointer_q <= stack_pointer_q - 2;
          end
          else if ((ms_push_from_scratch_2 & oc_push_from_scratch_2) == (ms_push_from_scratch_2 & ui_in)) begin
            stack_s[stack_pointer_q + 1] <= scratch_2_s[15:8];
            stack_s[stack_pointer_q + 2] <= scratch_2_s[7:0];
            stack_pointer_q <= stack_pointer_q + 2;
          end            
          else if ((ms_drop & oc_drop) == (ms_drop & ui_in)) begin
            stack_pointer_q <= stack_pointer_q - 1;
          end   
          else if ((ms_nop & oc_nop) == (ms_nop & ui_in)) begin 
            // 
          end
          else if ((ms_mul & oc_mul) == (ms_mul & ui_in)) begin 
          stack_s[stack_pointer_q - 1] <= multiplication_result_w[15:8];
          stack_s[stack_pointer_q]     <= multiplication_result_w[7:0];
          end
          else if ((ms_and & oc_and) == (ms_and & ui_in)) begin
            stack_s[stack_pointer_q - 1] <=
                stack_s[stack_pointer_q - 1] & stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end
          else if ((ms_or & oc_or) == (ms_or & ui_in)) begin
            stack_s[stack_pointer_q - 1] <=
                stack_s[stack_pointer_q - 1] | stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end
          else if ((ms_xor & oc_xor) == (ms_xor & ui_in)) begin
            stack_s[stack_pointer_q - 1] <=
                stack_s[stack_pointer_q - 1] ^ stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end
          else if ((ms_not & oc_not) == (ms_not & ui_in)) begin
            stack_s[stack_pointer_q] <=
                ~stack_s[stack_pointer_q];
          end
          else if ((ms_shift_left & oc_shift_left) == (ms_shift_left & ui_in)) begin
            stack_s[stack_pointer_q - 1] <=
                stack_s[stack_pointer_q - 1] << stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end
          else if ((ms_shift_right & oc_shift_right) == (ms_shift_right & ui_in)) begin
            stack_s[stack_pointer_q - 1] <=
                stack_s[stack_pointer_q - 1] >> stack_s[stack_pointer_q];
            stack_pointer_q <= stack_pointer_q - 1;
          end
          else if ((ms_push_instp & oc_push_instp) == (ms_push_instp & ui_in)) begin
            stack_s[stack_pointer_q + 1] <= instruction_pointer_q[15:8];
            stack_s[stack_pointer_q + 2] <= instruction_pointer_q[7:0];
            stack_pointer_q <= stack_pointer_q + 2;
          end
          else begin
            //stack_pointer_q <= stack_pointer_q;
          end
        end
        cs_load_adrr : begin
          stack_s[stack_pointer_q -1] <= ui_in;
          stack_pointer_q <= stack_pointer_q - 1;
        end
        cs_store_adrr : begin 
          stack_pointer_q <= stack_pointer_q - 2;
        end
        cs_store_data : begin 
          stack_pointer_q <= stack_pointer_q - 1;
        end
        cs_load_imd : begin 
          stack_s[stack_pointer_q + 1] <= ui_in;
          stack_pointer_q <= stack_pointer_q + 1;
        end
        default : begin
          stack_pointer_q <= stack_pointer_q;
        end
      endcase
    end
  end

  // instruction pointer
  always @(*) begin
    case (fsm_state_q) 
      cs_fetch : begin 
        if ((ms_jmp_nz & oc_jmp_nz) == (ms_jmp_nz & ui_in)) begin 
          if (stack_s[stack_pointer_q - 2] != 0) begin 
            instruction_pointer_d = {stack_s[stack_pointer_q -1],stack_s[stack_pointer_q]};
          end
          else begin 
            instruction_pointer_d = instruction_pointer_q + 1;
          end
        end
        else begin 
          instruction_pointer_d = instruction_pointer_q + 1;
        end
      end
      default : begin
        instruction_pointer_d = instruction_pointer_q;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if(! rst_n) instruction_pointer_q <= '0;
    else        instruction_pointer_q <= instruction_pointer_d;
  end



  wire write_enable_w;
  assign write_enable_w = fsm_state_q == cs_store_adrr;

  wire error_w;

  assign error_w = 0;

  // OUTPUT GEN
  wire [extmem_address_width-1:0] address_output_w ;

  wire [15:0] stack_address;

  assign stack_address = {
      stack_s[stack_pointer_q-1],
      stack_s[stack_pointer_q]
  };

  assign address_output_w =
      (fsm_state_q == cs_fetch)      ? instruction_pointer_q[extmem_address_width-1:0] :
      (fsm_state_q == cs_load_adrr)  ? stack_address[extmem_address_width-1:0] :
      (fsm_state_q == cs_store_adrr) ? stack_address[extmem_address_width-1:0] :
                                      instruction_pointer_q[extmem_address_width-1:0];


  wire [15:0] data_output_w ;

  assign data_output_w = {8'b0, stack_s[stack_pointer_q]};

  assign fused_output_w = 
  (fsm_state_q == cs_load_adrr || fsm_state_q == cs_store_adrr || fsm_state_q == cs_fetch || fsm_state_q == cs_load_imd) ? 
  {write_enable_w,error_w,address_output_w} : data_output_w;

endmodule
