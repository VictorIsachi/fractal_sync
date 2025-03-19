/*
 * Copyright (C) 2023-2024 ETH Zurich and University of Bologna
 *
 * Licensed under the Solderpad Hardware License, Version 0.51 
 * (the "License"); you may not use this file except in compliance 
 * with the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: SHL-0.51
 *
 * Authors: Victor Isachi <victor.isachi@unibo.it>
 *
 * Fractal synchronization multi-port register file
 * Asynchronous valid low reset
 */

module fractal_sync_mp_rf #(
  parameter int unsigned N_REGS    = 2,
  parameter int unsigned IDX_WIDTH = 1,
  parameter int unsigned N_PORTS   = 2
)(
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic                data_i[N_PORTS],
  input  logic[IDX_WIDTH-1:0] idx_i[N_PORTS],
  input  logic                idx_valid_i[N_PORTS],
  output logic                data_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_MP_RF: assert (2**IDX_WIDTH >= N_REGS) else $fatal("IDX_WIDTH must be able to index all N_REGS registers");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[N_REGS-1:0] d_demux[N_PORTS];
  logic[N_REGS-1:0] reg_d;
  logic[N_REGS-1:0] reg_q;
  logic[N_REGS-1:0] reg_en_base;
  logic[N_REGS-1:0] reg_en;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**         Multi-Port Register File Beginning        **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_d_demux
    always_comb begin
      d_demux[i]           = '0;
      d_demux[i][idx_i[i]] = data_i[i];
    end
  end

  always_comb begin: reg_d_logic
    reg_d = '0;
    for (int unsigned i = 0; i < N_PORTS; i++)
      reg_d |= d_demux[i];
  end

  assign reg_en_base = 1'b1;
  always_comb begin: reg_en_logic
    reg_en = '0;
    for (int unsigned i = 0; i < N_PORTS; i++)
      reg_en |= idx_valid_i[i] ? (reg_en_base << idx_i[i]) : '0;
  end

  for (genvar i = 0; i < N_REGS; i++) begin: gen_regs
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if      (!rst_ni)   reg_q[i] <= 1'b0;
      else if (reg_en[i]) reg_q[i] <= reg_d[i];
    end
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_data
    assign data_o[i] = reg_q[idx_i[i]];
  end

/*******************************************************/
/**            Multi-Port Register File End           **/
/*******************************************************/

endmodule: fractal_sync_mp_rf