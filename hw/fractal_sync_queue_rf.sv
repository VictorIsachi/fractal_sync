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
 * Fractal synchronization 1D queue register file
 * Asynchronous valid low reset
 *
 * Parameters:
 *  N_REGS    - Number of registers
 *  REG_DEPTH - Number of FIFO elements associated with each register
 *  ID_WIDTH  - Width needed to represent the possible lock ids
 *  element_t - Queue element (aggregate) type
 *  COMB_OUT  - Combinational output based on input (fall-through) FIFO
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > id_i             - Id of synchronization request
 *  > lock_i           - Lock priority RF req.
 *  > free_i           - Free priority RF req.
 *  > element_i        - Aggregate pattern of the lock/free request
 *  < grant_o          - Indicates that lock req. is granted by the RF
 *  < element_o        - Indicates the aggregate pattern of the granted request
 *  < id_err_o         - Indicates that RF detected an incorrect lock id
 *  < overflow_error_o - Indicates that RF detected FIFO overflow error
 */

module fractal_sync_1d_queue_rf 
  import fractal_sync_pkg::*; 
#(
  parameter int unsigned N_REGS    = 1,
  parameter int unsigned REG_DEPTH = 1,
  parameter int unsigned ID_WIDTH  = 1,
  parameter type         element_t = logic,
  parameter bit          COMB_OUT  = 1'b1,
  parameter int unsigned N_PORTS   = 2
)(
  input  logic               clk_i,
  input  logic               rst_ni,

  input  logic[ID_WIDTH-1:0] id_i[N_PORTS],
  input  logic               lock_i[N_PORTS],
  input  logic               free_i[N_PORTS],
  input  element_t           element_i[N_PORTS],
  output logic               grant_o[N_PORTS],
  output element_t           element_o[N_PORTS],
  output logic               id_err_o[N_PORTS],
  output logic               overflow_error_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_1D_QUEUE_RF_REGS: assert (N_REGS > 0) else $fatal("N_REGS must be > 0");
  initial FRACTAL_SYNC_1D_QUEUE_RF_DEPTH: assert (REG_DEPTH > 0) else $fatal("REG_DEPTH must be > 0");
  initial FRACTAL_SYNC_1D_QUEUE_RF_ID_W: assert (ID_WIDTH > 0) else $fatal("ID_WIDTH must be > 0");
  initial FRACTAL_SYNC_1D_QUEUE_RF_PORTS: assert (N_PORTS >= 2) else $fatal("N_PORTS must be > 1");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned LOCAL_ID_WIDTH = ID_WIDTH-1;
  localparam int unsigned MAX_ID         = N_REGS-1;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[LOCAL_ID_WIDTH-1:0] local_id[N_PORTS];

  logic valid_idx[N_PORTS];

  logic lock_req[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Queue Register File Beginning           **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_err
    assign local_id[i]  = id_i[i][ID_WIDTH-1:1];
    assign valid_idx[i] = (local_id[i] <= MAX_ID) ? 1'b1 : 1'b0;
    assign lock_req[i]  = lock_i[i] | free_i[i];
    assign id_err_o[i]  = (~valid_idx[i] & lock_req[i]);
  end

  fractal_sync_mp_queue #(
    .N_REGS    ( N_REGS         ),
    .REG_DEPTH ( REG_DEPTH      ),
    .IDX_WIDTH ( LOCAL_ID_WIDTH ),
    .element_t ( element_t      ),
    .COMB_OUT  ( COMB_OUT       ),
    .N_PORTS   ( N_PORTS        )
  ) i_mp_queue (
    .clk_i                                ,
    .rst_ni                               ,
    .lock_i           ( lock_i           ),
    .free_i           ( free_i           ),
    .element_i        ( element_i        ),
    .idx_i            ( local_id         ),
    .idx_valid_i      ( valid_idx        ),
    .grant_o          ( grant_o          ),
    .element_o        ( element_o        ),
    .overflow_error_o ( overflow_error_o )
  );

/*******************************************************/
/**              Queue Register File End              **/
/*******************************************************/

endmodule: fractal_sync_1d_queue_rf

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
 * Fractal synchronization 2D (H - horizontal; V - vertical) queue register file
 * Asynchronous valid low reset
 *
 * Parameters:
 *  N_REGS    - Number of registers
 *  REG_DEPTH - Number of FIFO elements associated with each register
 *  ID_WIDTH  - Width needed to represent the possible lock ids
 *  element_t - Queue element (aggregate) type
 *  COMB_OUT  - Combinational output based on input (fall-through) FIFO
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > id_i             - Id of synchronization request
 *  > lock_i           - Lock priority RF req.
 *  > free_i           - Free priority RF req.
 *  > element_i        - Aggregate pattern of the lock/free request
 *  < grant_o          - Indicates that lock req. is granted by the RF
 *  < element_o        - Indicates the aggregate pattern of the granted request
 *  < id_err_o         - Indicates that RF detected an incorrect lock id
 *  < overflow_error_o - Indicates that RF detected FIFO overflow error
 */

module fractal_sync_2d_queue_rf
  import fractal_sync_pkg::*;
#(
  parameter int unsigned N_REGS    = 2,
  parameter int unsigned REG_DEPTH = 2,
  parameter int unsigned ID_WIDTH  = 1,
  parameter type         element_t = logic,
  parameter bit          COMB_OUT  = 1'b1,
  parameter int unsigned N_H_PORTS = 2,
  parameter int unsigned N_V_PORTS = 2
)(
  input  logic               clk_i,
  input  logic               rst_ni,

  input  logic[ID_WIDTH-1:0] id_h_i[N_H_PORTS],
  input  logic               lock_h_i[N_H_PORTS],
  input  logic               free_h_i[N_H_PORTS],
  input  element_t           element_h_i[N_H_PORTS],
  output logic               h_grant_o[N_H_PORTS],
  output element_t           h_element_o[N_H_PORTS],
  output logic               h_id_err_o[N_H_PORTS],
  output logic               h_overflow_error_o[N_H_PORTS],

  input  logic[ID_WIDTH-1:0] id_v_i[N_V_PORTS],
  input  logic               lock_v_i[N_V_PORTS],
  input  logic               free_v_i[N_V_PORTS],
  input  element_t           element_v_i[N_V_PORTS],
  output logic               v_grant_o[N_V_PORTS],
  output element_t           v_element_o[N_V_PORTS],
  output logic               v_id_err_o[N_V_PORTS],
  output logic               v_overflow_error_o[N_V_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_2D_QUEUE_RF_REGS: assert (N_REGS%2 == 0) else $fatal("N_REGS must be even");

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
  
  fractal_sync_1d_queue_rf #(
    .N_REGS    ( N_H_REGS  ),
    .REG_DEPTH ( REG_DEPTH ),
    .ID_WIDTH  ( ID_WIDTH  ),
    .element_t ( element_t ),
    .COMB_OUT  ( COMB_OUT  ),
    .N_PORTS   ( N_H_PORTS )
  ) i_rf_h (
    .clk_i                                  ,
    .rst_ni                                 ,
    .id_i             ( id_h_i             ),
    .lock_i           ( lock_h_i           ),
    .free_i           ( free_h_i           ),
    .element_i        ( element_h_i        ),
    .grant_o          ( h_grant_o          ),
    .element_o        ( h_element_o        ),
    .id_err_o         ( h_id_err_o         ),
    .overflow_error_o ( h_overflow_error_o )
  );

/*******************************************************/
/**                 Horizontal RF End                 **/
/*******************************************************/
/**               Vertical RF Beginning               **/
/*******************************************************/
  
  fractal_sync_1d_queue_rf #(
    .N_REGS    ( N_V_REGS  ),
    .REG_DEPTH ( REG_DEPTH ),
    .ID_WIDTH  ( ID_WIDTH  ),
    .element_t ( element_t ),
    .COMB_OUT  ( COMB_OUT  ),
    .N_PORTS   ( N_V_PORTS )
  ) i_rf_v (
    .clk_i                                  ,
    .rst_ni                                 ,
    .id_i             ( id_v_i             ),
    .lock_i           ( lock_v_i           ),
    .free_i           ( free_v_i           ),
    .element_i        ( element_v_i        ),
    .grant_o          ( v_grant_o          ),
    .element_o        ( v_element_o        ),
    .id_err_o         ( v_id_err_o         ),
    .overflow_error_o ( v_overflow_error_o )
  );

/*******************************************************/
/**                  Vertical RF End                  **/
/*******************************************************/

endmodule: fractal_sync_2d_queue_rf