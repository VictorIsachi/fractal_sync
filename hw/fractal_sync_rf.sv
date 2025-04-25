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
 * Fractal synchronization 1D register file
 * Asynchronous valid low reset
 */

module fractal_sync_1d_rf
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::remote_rf_e    REMOTE_RF_TYPE = fractal_sync_pkg::CAM_RF,
  parameter fractal_sync_pkg::en_remote_rf_e EN_REMOTE_RF   = fractal_sync_pkg::EN_REMOTE_RF,
  parameter int unsigned                     N_LOCAL_REGS   = 1,
  parameter int unsigned                     LEVEL_WIDTH    = 1,
  parameter int unsigned                     ID_WIDTH       = 1,
  parameter int unsigned                     N_REMOTE_LINES = 1,
  localparam int unsigned                    N_PORTS        = 2
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_i[N_PORTS],
  input  logic[ID_WIDTH-1:0]    id_i[N_PORTS],
  input  logic                  check_local_i[N_PORTS],
  input  logic                  check_remote_i[N_PORTS],
  output logic                  present_local_o[N_PORTS],
  output logic                  present_remote_o[N_PORTS],
  output logic                  id_err_o[N_PORTS],
  output logic                  sig_err_o[N_PORTS],
  output logic                  bypass_local_o[N_PORTS],
  output logic                  bypass_remote_o[N_PORTS],
  output logic                  ignore_local_o[N_PORTS],
  output logic                  ignore_remote_o[N_PORTS]
);

/*******************************************************/
/**                 Local RF Beginning                **/
/*******************************************************/

  fractal_sync_1d_local_rf #(
    .N_REGS   ( N_LOCAL_REGS ),
    .ID_WIDTH ( ID_WIDTH     ),
    .N_PORTS  ( N_PORTS      )
  ) i_local_rf (
    .clk_i                        ,
    .rst_ni                       ,
    .id_i      ( id_i            ),
    .check_i   ( check_local_i   ),
    .present_o ( present_local_o ),
    .id_err_o  ( id_err_o        ),
    .bypass_o  ( bypass_local_o  ),
    .ignore_o  ( ignore_local_o  )
  );

/*******************************************************/
/**                    Local RF End                   **/
/*******************************************************/
/**                Remote RF Beginning                **/
/*******************************************************/

  if (EN_REMOTE_RF == fractal_sync_pkg::EN_REMOTE_RF) begin: gen_1d_remote_rf
    fractal_sync_1d_remote_rf #(
      .RF_TYPE     ( REMOTE_RF_TYPE ),
      .LEVEL_WIDTH ( LEVEL_WIDTH    ),
      .ID_WIDTH    ( ID_WIDTH       ),
      .N_CAM_LINES ( N_REMOTE_LINES ),
      .N_PORTS     ( N_PORTS        )
    ) i_remote_rf (
      .clk_i                         ,
      .rst_ni                        ,
      .level_i   ( level_i          ),
      .id_i      ( id_i             ),
      .check_i   ( check_remote_i   ),
      .present_o ( present_remote_o ),
      .sig_err_o ( sig_err_o        ),
      .bypass_o  ( bypass_remote_o  ),
      .ignore_o  ( ignore_remote_o  )
    );
  end else begin: gen_no_1d_remote_rf
    for (genvar i = 0; i < N_PORTS; i++) begin
      assign present_remote_o[i] = 1'b0;
      assign sig_err_o[i]        = 1'b0;
      assign bypass_remote_o[i]  = 1'b0;
      assign ignore_remote_o[i]  = 1'b0;
    end
  end

/*******************************************************/
/**                   Remote RF End                   **/
/*******************************************************/

endmodule: fractal_sync_1d_rf

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
 * Fractal synchronization 2D register file
 * Asynchronous valid low reset
 */

module fractal_sync_2d_rf
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::remote_rf_e    REMOTE_RF_TYPE = fractal_sync_pkg::CAM_RF,
  parameter fractal_sync_pkg::en_remote_rf_e EN_REMOTE_RF   = fractal_sync_pkg::EN_REMOTE_RF,
  parameter int unsigned                     N_LOCAL_REGS   = 2,
  parameter int unsigned                     LEVEL_WIDTH    = 1,
  parameter int unsigned                     ID_WIDTH       = 1,
  parameter int unsigned                     N_REMOTE_LINES = 2,
  parameter int unsigned                     N_H_PORTS      = 2,
  parameter int unsigned                     N_V_PORTS      = 2
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_h_i[N_H_PORTS],
  input  logic[ID_WIDTH-1:0]    id_h_i[N_H_PORTS],
  input  logic                  check_h_local_i[N_H_PORTS],
  input  logic                  check_h_remote_i[N_H_PORTS],
  output logic                  h_present_local_o[N_H_PORTS],
  output logic                  h_present_remote_o[N_H_PORTS],
  output logic                  h_id_err_o[N_H_PORTS],
  output logic                  h_sig_err_o[N_H_PORTS],
  output logic                  h_bypass_local_o[N_H_PORTS],
  output logic                  h_bypass_remote_o[N_H_PORTS],
  output logic                  h_ignore_local_o[N_H_PORTS],
  output logic                  h_ignore_remote_o[N_H_PORTS],

  input  logic[LEVEL_WIDTH-1:0] level_v_i[N_V_PORTS],
  input  logic[ID_WIDTH-1:0]    id_v_i[N_V_PORTS],
  input  logic                  check_v_local_i[N_V_PORTS],
  input  logic                  check_v_remote_i[N_V_PORTS],
  output logic                  v_present_local_o[N_V_PORTS],
  output logic                  v_present_remote_o[N_V_PORTS],
  output logic                  v_id_err_o[N_V_PORTS],
  output logic                  v_sig_err_o[N_V_PORTS],
  output logic                  v_bypass_local_o[N_V_PORTS],
  output logic                  v_bypass_remote_o[N_V_PORTS],
  output logic                  v_ignore_local_o[N_V_PORTS],
  output logic                  v_ignore_remote_o[N_V_PORTS]
);

/*******************************************************/
/**                 Local RF Beginning                **/
/*******************************************************/

  fractal_sync_2d_local_rf #(
    .N_REGS    ( N_LOCAL_REGS ),
    .ID_WIDTH  ( ID_WIDTH     ),
    .N_H_PORTS ( N_H_PORTS    ),
    .N_V_PORTS ( N_V_PORTS    )
  ) i_local_rf (
    .clk_i                            ,
    .rst_ni                           ,
    .id_h_i      ( id_h_i            ),
    .check_h_i   ( check_h_local_i   ),
    .h_present_o ( h_present_local_o ),
    .h_id_err_o  ( h_id_err_o        ),
    .h_bypass_o  ( h_bypass_local_o  ),
    .h_ignore_o  ( h_ignore_local_o  ),
    .id_v_i      ( id_v_i            ),
    .check_v_i   ( check_v_local_i   ),
    .v_present_o ( v_present_local_o ),
    .v_id_err_o  ( v_id_err_o        ),
    .v_bypass_o  ( v_bypass_local_o  ),
    .v_ignore_o  ( v_ignore_local_o  )
  ); 

/*******************************************************/
/**                    Local RF End                   **/
/*******************************************************/
/**                Remote RF Beginning                **/
/*******************************************************/

  if (EN_REMOTE_RF == fractal_sync_pkg::EN_REMOTE_RF) begin: gen_2d_remote_rf
    fractal_sync_2d_remote_rf #(
      .RF_TYPE     ( REMOTE_RF_TYPE ),
      .LEVEL_WIDTH ( LEVEL_WIDTH    ),
      .ID_WIDTH    ( ID_WIDTH       ),
      .N_CAM_LINES ( N_REMOTE_LINES ),
      .N_H_PORTS   ( N_H_PORTS      ),
      .N_V_PORTS   ( N_V_PORTS      )
    ) i_remote_rf (
      .clk_i                             ,
      .rst_ni                            ,
      .level_h_i   ( level_h_i          ),
      .id_h_i      ( id_h_i             ),
      .check_h_i   ( check_h_remote_i   ),
      .h_present_o ( h_present_remote_o ),
      .h_sig_err_o ( h_sig_err_o        ),
      .h_bypass_o  ( h_bypass_remote_o  ),
      .h_ignore_o  ( h_ignore_remote_o  ),
      .level_v_i   ( level_v_i          ),
      .id_v_i      ( id_v_i             ),
      .check_v_i   ( check_v_remote_i   ),
      .v_present_o ( v_present_remote_o ),
      .v_sig_err_o ( v_sig_err_o        ),
      .v_bypass_o  ( v_bypass_remote_o  ),
      .v_ignore_o  ( v_ignore_remote_o  )
    );
  end else begin: gen_no_2d_remote_rf
    for (genvar i = 0; i < N_H_PORTS; i++) begin
      assign h_present_remote_o[i] = 1'b0;
      assign h_sig_err_o[i]        = 1'b0;
      assign h_bypass_remote_o[i]  = 1'b0;
      assign h_ignore_remote_o[i]  = 1'b0;
    end
    for (genvar i = 0; i < N_V_PORTS; i++) begin
      assign v_present_remote_o[i] = 1'b0;
      assign v_sig_err_o[i]        = 1'b0;
      assign v_bypass_remote_o[i]  = 1'b0;
      assign v_ignore_remote_o[i]  = 1'b0;
    end
  end

/*******************************************************/
/**                   Remote RF End                   **/
/*******************************************************/

endmodule: fractal_sync_2d_rf