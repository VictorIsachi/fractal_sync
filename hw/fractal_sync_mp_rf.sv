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
 * Fractal synchronization multi-port register file: synch. multi-port check; asynch. multi-port present
 * Asynchronous valid low reset
 *
 * Parameters:
 *  N_REGS    - Number of registers in the register file
 *  IDX_WIDTH - Width of the selected register; width must be large enough to be able to select all registers in the RF
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > check_i     - Check (synchronous) the register at selected index updating it accordingly (present AND valid => clear; NOT(present) AND valid => set)
 *  > idx_i       - Register index
 *  > idx_valid_i - Indicates that the selected index is valid
 *  < present_o   - Indicates whether register at selected index is present (asynchronous)
 */

module fractal_sync_mp_rf #(
  parameter int unsigned N_REGS    = 2,
  parameter int unsigned IDX_WIDTH = 1,
  parameter int unsigned N_PORTS   = 2
)(
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic                check_i[N_PORTS],
  input  logic[IDX_WIDTH-1:0] idx_i[N_PORTS],
  input  logic                idx_valid_i[N_PORTS],
  output logic                present_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_MP_RF: assert (2**IDX_WIDTH >= N_REGS) else $fatal("IDX_WIDTH must be able to index all N_REGS registers");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned REG_IDX_WIDTH = N_REGS > 1 ? $clog2(N_REGS) : 1;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[REG_IDX_WIDTH-1:0] reg_idx[N_PORTS];
  
  logic check_demux[N_PORTS][N_REGS];
  logic check_reg[N_REGS];

  logic reg_d[N_REGS];
  logic reg_q[N_REGS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_reg_idx
    assign reg_idx[i] = idx_i[i][REG_IDX_WIDTH-1:0];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**         Multi-Port Register File Beginning        **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_check_demux
    always_comb begin
      check_demux[i] = '{default: 1'b0};
      if (idx_valid_i[i]) 
        check_demux[i][reg_idx[i]] = check_i[i];
    end
  end

  always_comb begin: check_reg_logic
    check_reg = '{default: 1'b0};
    for (int unsigned i = 0; i < N_PORTS; i++)
      for (int unsigned j = 0; j < N_REGS; j++)
        if (check_demux[i][j]) check_reg[j] = 1'b1;
  end

  always_comb begin: reg_d_logic
    reg_d = reg_q;
    for (int unsigned i = 0; i < N_REGS; i++) begin
      if (check_reg[i]) reg_d[i] = ~reg_q[i];
    end
  end

  for (genvar i = 0; i < N_REGS; i++) begin: gen_regs
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) reg_q[i] <= 1'b0;
      else         reg_q[i] <= reg_d[i];
    end
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_present
    assign present_o[i] = idx_valid_i[i] ? reg_q[reg_idx[i]] : 1'b0;
  end

/*******************************************************/
/**            Multi-Port Register File End           **/
/*******************************************************/

endmodule: fractal_sync_mp_rf