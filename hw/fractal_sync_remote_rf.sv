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
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE     = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  LEVEL_WIDTH = 1,
  parameter int unsigned                  ID_WIDTH    = 1,
  parameter int unsigned                  N_CAM_LINES = 1,
  localparam int unsigned                 N_PORTS     = 2
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
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_SIG_ENC_MAX_LVL: assert (MAX_LVL_WIDTH >= LEVEL_WIDTH) else $fatal("Unsupported (exceeds maximum of 4 - 16 levels) level width for signature generation: update Sig. Gen.");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned N_DM_REGS = 4*(2**(ID_WIDTH+2)-1)/6;
  localparam int unsigned SIG_WIDTH = $clog2(N_DM_REGS);
  localparam int unsigned MAX_SIG   = N_DM_REGS-1;

  localparam int unsigned                                  MAX_LVL_WIDTH     = 4;
  localparam int unsigned                                  MAX_LVL_SIG       = 2**MAX_LVL_WIDTH;
  localparam int unsigned                                  MAX_LVL_SIG_WIDTH = MAX_LVL_SIG-1;
  localparam logic[MAX_LVL_SIG-1:0][MAX_LVL_SIG_WIDTH-1:0] LVL_SIG_LOOKUP    = '{'b110_1010_1010_1010,  // Level 16
                                                                                 'b010_1010_1010_1010,  // Level 15
                                                                                 'b001_1010_1010_1010,  // Level 14
                                                                                 'b000_1010_1010_1010,  // Level 13
                                                                                 'b000_0110_1010_1010,  // Level 12
                                                                                 'b000_0010_1010_1010,  // Level 11
                                                                                 'b000_0001_1010_1010,  // Level 10
                                                                                 'b000_0000_1010_1010,  // Level 9
                                                                                 'b000_0000_0110_1010,  // Level 8
                                                                                 'b000_0000_0010_1010,  // Level 7
                                                                                 'b000_0000_0001_1010,  // Level 6
                                                                                 'b000_0000_0000_1010,  // Level 5
                                                                                 'b000_0000_0000_0110,  // Level 4
                                                                                 'b000_0000_0000_0010,  // Level 3
                                                                                 'b000_0000_0000_0001,  // Level 2
                                                                                 'b000_0000_0000_0000}; // Level 1
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[SIG_WIDTH-1:0] sig_lvl[N_PORTS];
  logic[SIG_WIDTH-1:0] sig[N_PORTS];

  logic valid_idx[N_PORTS];
  logic bypass;
  logic d[N_PORTS];
  logic q[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Signature Generator Beginning           **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_signiture
    assign sig_lvl[i] = LVL_SIG_LOOKUP[level_i[i]];
    assign sig[i]     = sig_lvl[i] + id_i[i];
  end

/*******************************************************/
/**              Signature Generator End              **/
/*******************************************************/
/**           Remote Register File Beginning          **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_err
    assign valid_idx[i] = (sig[i] <= MAX_SIG) ? 1'b1 : 1'b0;
    assign sig_err_o[i] = ~valid_idx[i];
  end

  always_comb begin: bypass_logic
    bypass = 1'b1;
    for (int unsigned i = 0; i < N_PORTS-1; i++)
      if (sig[i] != sig[i+1])
        bypass = 1'b0;
  end
  assign bypass_o = bypass;

  if (RF_TYPE == fractal_sync_pkg::DM_RF) begin: gen_dm_rf
    for (genvar i = 0; i < N_PORTS; i++) begin: gen_d_q
      assign d[i] = ~bypass & (check_i[i] ^ q[i]);
    end

    fractal_sync_mp_rf #(
      .N_REGS    ( N_DM_REGS ),
      .IDX_WIDTH ( SIG_WIDTH ),
      .N_PORTS   ( N_PORTS   )
    ) i_dm_rf (
      .clk_i                    ,
      .rst_ni                   ,
      .data_i      ( d         ),
      .idx_i       ( sig       ),
      .idx_valid_i ( valid_idx ),
      .data_o      ( q         )
    );
  end else if (RF_TYPE == fractal_sync_pkg::CAM_RF) begin: gen_cam_rf
    for (genvar i = 0; i < N_PORTS; i++) begin: gen_d
      assign d[i] = ~bypass & check_i[i] & valid_idx[i];
    end
    
    fractal_sync_mp_cam #(
      .SIG_WIDTH ( SIG_WIDTH   ),
      .N_PORTS   ( N_PORTS     ),
      .N_LINES   ( N_CAM_LINES )
    ) i_cam_rf (
      .clk_i              ,
      .rst_ni             ,
      .sig_i       ( sig ),
      .sig_write_i ( d   ),
      .present_o   ( q   )
    );
  end else $fatal("Unsupported Remote Register File Type");

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_q
    assign present_o[i] = q[i];
  end

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
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE     = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  LEVEL_WIDTH = 1,
  parameter int unsigned                  ID_WIDTH    = 1,
  parameter int unsigned                  N_CAM_LINES = 2,
  localparam int unsigned                 N_H_PORTS   = 2,
  localparam int unsigned                 N_V_PORTS   = 2
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
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_2D_REMOTE_RF_CAM_LINES: assert (N_CAM_LINES%2 == 0) else $fatal("N_CAM_LINES must be even");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned N_H_CAM_LINES = N_CAM_LINES/2;
  localparam int unsigned N_V_CAM_LINES = N_CAM_LINES/2;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**              Horizontal RF Beginning              **/
/*******************************************************/

  fractal_sync_1d_remote_rf #(
    .RF_TYPE     ( RF_TYPE       ),
    .LEVEL_WIDTH ( LEVEL_WIDTH   ),
    .ID_WIDTH    ( ID_WIDTH      ),
    .N_CAM_LINES ( N_H_CAM_LINES )
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
    .RF_TYPE     ( RF_TYPE       ),
    .LEVEL_WIDTH ( LEVEL_WIDTH   ),
    .ID_WIDTH    ( ID_WIDTH      ),
    .N_CAM_LINES ( N_V_CAM_LINES )
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