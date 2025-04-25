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
 * Fractal synchronization 1D local register file
 * Asynchronous valid low reset
 */

module fractal_sync_1d_local_rf 
  import fractal_sync_pkg::*; 
#(
  parameter int unsigned  N_REGS   = 1,
  parameter int unsigned  ID_WIDTH = 1,
  parameter int unsigned  N_PORTS  = 2
)(
  input  logic               clk_i,
  input  logic               rst_ni,

  input  logic[ID_WIDTH-1:0] id_i[N_PORTS],
  input  logic               check_i[N_PORTS],
  output logic               present_o[N_PORTS],
  output logic               id_err_o[N_PORTS],
  output logic               bypass_o[N_PORTS],
  output logic               ignore_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_1D_LOCAL_RF_REGS: assert (N_REGS > 0) else $fatal("N_REGS must be > 0");
  initial FRACTAL_SYNC_1D_LOCAL_RF_ID_W: assert (ID_WIDTH > 0) else $fatal("ID_WIDTH must be > 0");
  initial FRACTAL_SYNC_1D_LOCAL_RF_PORTS: assert (N_PORTS >= 2) else $fatal("N_PORTS must be > 1");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned MAX_ID = 2**ID_WIDTH - 1;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic valid_idx[N_PORTS];
  logic bypass[N_PORTS];
  logic ignore[N_PORTS];
  logic d[N_PORTS];
  logic q[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Local Register File Beginning           **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_err
    assign valid_idx[i] = (id_i[i] <= MAX_ID) ? 1'b1 : 1'b0;
    assign id_err_o[i]  = ~valid_idx[i];
  end

  always_comb begin: bypass_ignore_logic
    bypass = '{default: 1'b0};
    ignore = '{default: 1'b0};
    for (int unsigned i = 0; i < N_PORTS-1; i++) begin
      if (ignore[i]) continue;
      else begin
        for (int unsigned j = i; j < N_PORTS; j++) begin
          if (id_i[i] == id_i[j]) begin
            bypass[i] = 1'b1;
            ignore[j] = 1'b1;
            break;
          end
        end
      end
    end
  end
  assign bypass_o = bypass;
  assign ignore_o = ignore;

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_d_q
    assign d[i]         = ~(bypass[i] | ignore[i]) & (check_i[i] ^ q[i]);
    assign present_o[i] = q[i];
  end

  fractal_sync_mp_rf #(
    .N_REGS    ( N_REGS   ),
    .IDX_WIDTH ( ID_WIDTH ),
    .N_PORTS   ( N_PORTS  )
  ) i_mp_rf (
    .clk_i                    ,
    .rst_ni                   ,
    .data_i      ( d         ),
    .idx_i       ( id_i      ),
    .idx_valid_i ( valid_idx ),
    .data_o      ( q         )
  );

/*******************************************************/
/**              Local Register File End              **/
/*******************************************************/

endmodule: fractal_sync_1d_local_rf

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
 * Fractal synchronization 2D local register file
 * Asynchronous valid low reset
 */

module fractal_sync_2d_local_rf #(
  parameter int unsigned N_REGS    = 2,
  parameter int unsigned ID_WIDTH  = 1,
  parameter int unsigned N_H_PORTS = 2,
  parameter int unsigned N_V_PORTS = 2
)(
  input  logic               clk_i,
  input  logic               rst_ni,

  input  logic[ID_WIDTH-1:0] id_h_i[N_H_PORTS],
  input  logic               check_h_i[N_H_PORTS],
  output logic               h_present_o[N_H_PORTS],
  output logic               h_id_err_o[N_H_PORTS],
  output logic               h_bypass_o[N_H_PORTS],
  output logic               h_ignore_o[N_H_PORTS],

  input  logic[ID_WIDTH-1:0] id_v_i[N_V_PORTS],
  input  logic               check_v_i[N_V_PORTS],
  output logic               v_present_o[N_V_PORTS],
  output logic               v_id_err_o[N_V_PORTS],
  output logic               v_bypass_o[N_V_PORTS],
  output logic               v_ignore_o[N_V_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_2D_LOCAL_RF_REGS: assert (N_REGS%2 == 0) else $fatal("N_REGS must be even");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned N_H_REGS = N_REGS/2;
  localparam int unsigned N_V_REGS = N_REGS/2;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**              Horizontal RF Beginning              **/
/*******************************************************/
  
  fractal_sync_1d_local_rf #(
    .N_REGS   ( N_H_REGS  ),
    .ID_WIDTH ( ID_WIDTH  ),
    .N_PORTS  ( N_H_PORTS )
  ) i_rf_h (
    .clk_i                    ,
    .rst_ni                   ,
    .id_i      ( id_h_i      ),
    .check_i   ( check_h_i   ),
    .present_o ( h_present_o ),
    .id_err_o  ( h_id_err_o  ),
    .bypass_o  ( h_bypass_o  ),
    .ignore_o  ( h_ignore_o  )
  );

/*******************************************************/
/**                 Horizontal RF End                 **/
/*******************************************************/
/**               Vertical RF Beginning               **/
/*******************************************************/
  
  fractal_sync_1d_local_rf #(
    .N_REGS   ( N_V_REGS ),
    .ID_WIDTH ( ID_WIDTH ),
    .N_PORTS  ( N_V_PORTS )
  ) i_rf_v (
    .clk_i                    ,
    .rst_ni                   ,
    .id_i      ( id_v_i      ),
    .check_i   ( check_v_i   ),
    .present_o ( v_present_o ),
    .id_err_o  ( v_id_err_o  ),
    .bypass_o  ( v_bypass_o  ),
    .ignore_o  ( v_ignore_o  )
  );

/*******************************************************/
/**                  Vertical RF End                  **/
/*******************************************************/

endmodule: fractal_sync_2d_local_rf