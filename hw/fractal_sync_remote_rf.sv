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
 * Fractal synchronization 1D remote register file
 * Asynchronous valid low reset
 */

module fractal_sync_1d_remote_rf 
  import fractal_sync_pkg::*; 
#(
  parameter int unsigned  LEVEL_WIDTH = 1,
  parameter int unsigned  ID_WIDTH    = 1,
  localparam int unsigned N_PORTS     = 2
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_i[N_PORTS],
  input  logic[ID_WIDTH-1:0]    id_i[N_PORTS],
  input  logic                  check_i[N_PORTS],
  output logic                  present_o[N_PORTS],
  output logic                  sig_err_o[N_PORTS],
  output logic                  bypass_o
);

/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned N_REGS    = 4(2**(ID_WIDTH+2)-1)/6;
  localparam int unsigned SIG_WIDTH = $clog2(N_REGS);
  localparam int unsigned MAX_SIG   = N_REGS-1;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[SIG_WIDTH-1:0] sig_lvl_init_base;
  logic[SIG_WIDTH-1:0] sig_lvl_init[N_PORTS];
  logic[SIG_WIDTH-1:0] sig_lvl[N_PORTS];
  logic[SIG_WIDTH-1:0] sig[N_PORTS];

  logic valid_idx[N_PORTS];
  logic bypass;
  logic d[N_PORTS];
  logic q[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Signiture Generator Beginning           **/
/*******************************************************/
  
  assign sig_lvl_init_base = 1'b1;
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_signiture
    always_comb begin: level_init
      sig_lvl_init[i] = sig_lvl_init_base << level_i[i];
    end

    always_comb begin: sig_lvl_encoder
      sig_lvl[i] = sig_lvl_init[i];
      sig_lvl[i][SIG_WIDTH-2] = sig_lvl_init[i][SIG_WIDTH-1] | sig_lvl[i][SIG_WIDTH-2];
      for (unsigned int j = SIG_WIDTH-5; j > 0; j -= 3)
        sig_lvl[i][j] |= (sig_lvl[i][j+1] | sig_lvl[i][j+2]);
      sig_lvl[i][0] = 1'b0;
    end

    assign sig[i] = sig_lvl[i] + id_i[i];
  end

/*******************************************************/
/**              Signiture Generator End              **/
/*******************************************************/
/**           Remote Register File Beginning          **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_err
    assign valid_idx[i] = (sig[i] <= MAX_SIG) ? 1'b1 : 1'b0;
    assign sig_err_o[i] = ~valid_idx[i];
  end

  always_comb begin: bypass
    bypass = 1'b1;
    for (int unsigned i = 0; i < N_PORTS-1; i++)
      if (sig[i] != sig[i+1])
        bypass = 1'b0;
  end
  assign bypass_o = bypass;

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_d_q
    assign d[i]         = ~bypass & (check_i[i] ^ q[i]);
    assign present_o[i] = q[i];
  end

  fractal_sync_mp_rf #(
    .N_REGS    ( N_REGS    ),
    .IDX_WIDTH ( SIG_WIDTH ),
    .N_PORTS   ( N_PORTS   )
  ) i_mp_rf (
    .clk_i                    ,
    .rst_ni                   ,
    .data_i      ( d         ),
    .idx_i       ( sig       ),
    .idx_valid_i ( valid_idx ),
    .data_o      ( q         )
  );

/*******************************************************/
/**              Remote Register File End             **/
/*******************************************************/

endmodule: fractal_sync_1d_remote_rf

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
 * Fractal synchronization 2D remote register file
 * Asynchronous valid low reset
 */

module fractal_sync_2d_remote_rf #(
  parameter int unsigned  LEVEL_WIDTH = 1,
  parameter int unsigned  ID_WIDTH    = 1,
  localparam int unsigned N_H_PORTS   = 2,
  localparam int unsigned N_V_PORTS   = 2
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_h_i[N_H_PORTS],
  input  logic[LEVEL_WIDTH-1:0] level_v_i[N_V_PORTS],
  input  logic[ID_WIDTH-1:0]    id_h_i[N_H_PORTS],
  input  logic[ID_WIDTH-1:0]    id_v_i[N_V_PORTS],
  input  logic                  check_h_i[N_H_PORTS],
  input  logic                  check_v_i[N_V_PORTS],
  output logic                  h_present_o[N_H_PORTS],
  output logic                  v_present_o[N_V_PORTS],
  output logic                  h_sig_err_o[N_H_PORTS],
  output logic                  v_sig_err_o[N_V_PORTS],
  output logic                  h_bypass_o,
  output logic                  v_bypass_o
);

/*******************************************************/
/**              Horizontal RF Beginning              **/
/*******************************************************/

  fractal_sync_1d_remote_rf #(
    .LEVEL_WIDTH ( LEVEL_WIDTH ),
    .ID_WIDTH    ( ID_WIDTH    ),
    .SIG_WIDTH   (             )
  ) i_rf_h (
    .clk_i                    ,
    .rst_ni                   ,
    .level_i   ( level_h_i   ),
    .id_i      ( id_h_i      ),
    .check_i   ( check_h_i   ),
    .present_o ( h_present_o ),
    .sig_err_o ( h_sig_err_o ),
    .bypass_o  ( h_bypass_o  )
  );

/*******************************************************/
/**                 Horizontal RF End                 **/
/*******************************************************/
/**               Vertical RF Beginning               **/
/*******************************************************/

  fractal_sync_1d_remote_rf #(
    .LEVEL_WIDTH ( LEVEL_WIDTH ),
    .ID_WIDTH    ( ID_WIDTH  ),
    .SIG_WIDTH   (             )
  ) i_rf_v (
    .clk_i                    ,
    .rst_ni                   ,
    .level_i   ( level_v_i   ),
    .id_i      ( id_v_i      ),
    .check_i   ( check_v_i   ),
    .present_o ( v_present_o ),
    .sig_err_o ( v_sig_err_o ),
    .bypass_o  ( v_bypass_o  )
  );

/*******************************************************/
/**                  Vertical RF End                  **/
/*******************************************************/

endmodule: fractal_sync_2d_remote_rf