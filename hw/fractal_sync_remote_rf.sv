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
 *
 * Parameters:
 *  RF_TYPE     - Register file type (Directly Mapped or CAM)
 *  LEVEL_WIDTH - Width needed to represent the possible levels
 *  ID_WIDTH    - Width needed to represent the possible barrier ids
 *  N_CAM_LINES - Number of CAM lines (used if RF is CAM-based)
 *  N_PORTS     - Number of ports
 *
 * Interface signals:
 *  > level_i   - Level of synchronization requests/responses
 *  > id_i      - Id of synch. req./rsp.
 *  > sd_i      - Source/destinatin of synch. req./rsp. for back-routing
 *  > check_i   - Check RF for synch. rsp.
 *  > set_i     - Set RF for synch. req.
 *  < present_o - Indicates that synch. req./rsp. is present in RF
 *  < sd_o      - Indicates the synch. req./rsp. destinations for back-routing
 *  < sig_err_o - Indicates that RF detected an incorrect signature
 *  < bypass_o  - Indicates that current RF req. should be bypassed (detected 2 req. to the same barrier)
 *  < ignore_o  - Indicates that current RF req. should be ignored (detected 2 req. to the same barrier)
 */

module fractal_sync_1d_remote_rf 
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE     = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  LEVEL_WIDTH = 1,
  parameter int unsigned                  ID_WIDTH    = 1,
  parameter int unsigned                  N_CAM_LINES = 1,
  localparam int unsigned                 SD_WIDTH    = fractal_sync_pkg::SD_WIDTH,
  parameter int unsigned                  N_PORTS     = 2
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_i[N_PORTS],
  input  logic[ID_WIDTH-1:0]    id_i[N_PORTS],
  input  logic[SD_WIDTH-1:0]    sd_i[N_PORTS],
  input  logic                  check_i[N_PORTS],
  input  logic                  set_i[N_PORTS],
  output logic                  present_o[N_PORTS],
  output logic[SD_WIDTH-1:0]    sd_o[N_PORTS],
  output logic                  sig_err_o[N_PORTS],
  output logic                  bypass_o[N_PORTS],
  output logic                  ignore_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_1D_REMOTE_RF_SIG_ENC_MAX_LVL: assert (MAX_LVL_WIDTH >= LEVEL_WIDTH) else $fatal("Unsupported (exceeds maximum of 4 - 16 levels) level width for signature generation: update Sig. Gen.");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned LOCAL_ID_WIDTH = ID_WIDTH-1;
  localparam int unsigned N_DM_REGS      = (2**(ID_WIDTH+2)-2)/3;
  localparam int unsigned SIG_WIDTH      = $clog2(N_DM_REGS);
  localparam int unsigned MAX_SIG        = N_DM_REGS-1;

  localparam int unsigned                                          MAX_LVL_WIDTH        = 4;
  localparam int unsigned                                          LVL_LOOKUP_WIDTH     = 2**MAX_LVL_WIDTH + 1;  // One extra as the sentinel
  localparam int unsigned                                          MAX_LOOKUP_LVL_WIDTH = LVL_LOOKUP_WIDTH-1;
  localparam logic[LVL_LOOKUP_WIDTH-1:0][MAX_LOOKUP_LVL_WIDTH-1:0] LVL_SIG_LOOKUP       = '{'b1010_1010_1010_1010,  // Sentinel
                                                                                            'b0110_1010_1010_1010,  // Level 16
                                                                                            'b0010_1010_1010_1010,  // Level 15
                                                                                            'b0001_1010_1010_1010,  // Level 14
                                                                                            'b0000_1010_1010_1010,  // Level 13
                                                                                            'b0000_0110_1010_1010,  // Level 12
                                                                                            'b0000_0010_1010_1010,  // Level 11
                                                                                            'b0000_0001_1010_1010,  // Level 10
                                                                                            'b0000_0000_1010_1010,  // Level 9
                                                                                            'b0000_0000_0110_1010,  // Level 8
                                                                                            'b0000_0000_0010_1010,  // Level 7
                                                                                            'b0000_0000_0001_1010,  // Level 6
                                                                                            'b0000_0000_0000_1010,  // Level 5
                                                                                            'b0000_0000_0000_0110,  // Level 4
                                                                                            'b0000_0000_0000_0010,  // Level 3
                                                                                            'b0000_0000_0000_0001,  // Level 2
                                                                                            'b0000_0000_0000_0000}; // Level 1
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[LOCAL_ID_WIDTH-1:0] local_id[N_PORTS];
  
  logic[MAX_LOOKUP_LVL_WIDTH-1:0] lvl_sig[N_PORTS];
  logic[MAX_LOOKUP_LVL_WIDTH-1:0] sig[N_PORTS];

  logic[SIG_WIDTH-1:0] local_sig[N_PORTS];

  logic valid_sig[N_PORTS];
  logic check_rf[N_PORTS];
  logic set_rf[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Signature Generator Beginning           **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_signiture
    assign local_id[i]  = id_i[i][ID_WIDTH-1:1];
    assign lvl_sig[i]   = LVL_SIG_LOOKUP[level_i[i]];
    assign sig[i]       = lvl_sig[i] + local_id[i];
    assign local_sig[i] = sig[i][SIG_WIDTH-1:0];
  end

/*******************************************************/
/**              Signature Generator End              **/
/*******************************************************/
/**           Remote Register File Beginning          **/
/*******************************************************/
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_err
    assign valid_sig[i] = ((sig[i] <= MAX_SIG) && (sig[i] < LVL_SIG_LOOKUP[level_i[i]+1])) ? 1'b1 : 1'b0;
    assign sig_err_o[i] = ~valid_sig[i];
  end

 always_comb begin: bypass_ignore_logic
    bypass_o = '{default: 1'b0};
    ignore_o = '{default: 1'b0};
    for (int unsigned i = 0; i < N_PORTS-1; i++) begin
      if (~check_i[i] | ignore_o[i]) continue;
      else begin
        for (int unsigned j = i+1; j < N_PORTS; j++) begin
          if ((local_id[i] == local_id[j]) && check_i[j]) begin
            bypass_o[i] = 1'b1;
            ignore_o[j] = 1'b1;
            break;
          end
        end
      end
    end
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_check
    assign check_rf[i] = ~(bypass_o[i] | ignore_o[i]) & check_i[i];
    assign set_rf[i]   = ~(bypass_o[i] | ignore_o[i]) & set_i[i];
  end
  
  if (RF_TYPE == fractal_sync_pkg::DM_RF) begin: gen_dm_rf
    fractal_sync_mp_rf_br #(
      .N_REGS    ( N_DM_REGS ),
      .IDX_WIDTH ( SIG_WIDTH ),
      .N_PORTS   ( N_PORTS   )
    ) i_dm_rf (
      .clk_i                    ,
      .rst_ni                   ,
      .check_i     ( check_rf  ),
      .set_i       ( set_rf    ),
      .sd_i        ( sd_i      ),
      .idx_i       ( local_sig ),
      .idx_valid_i ( valid_sig ),
      .present_o   ( present_o ),
      .sd_o        ( sd_o      )
    );
  end else if (RF_TYPE == fractal_sync_pkg::CAM_RF) begin: gen_cam_rf
    fractal_sync_mp_cam_br #(
      .N_LINES   ( N_CAM_LINES ),
      .SIG_WIDTH ( SIG_WIDTH   ),
      .N_PORTS   ( N_PORTS     )
    ) i_cam_rf (
      .clk_i                    ,
      .rst_ni                   ,
      .check_i     ( check_rf  ),
      .set_i       ( set_rf    ),
      .sd_i        ( sd_i      ),
      .sig_i       ( local_sig ),
      .sig_valid_i ( valid_sig ),
      .present_o   ( present_o ),
      .sd_o        ( sd_o      )
    );
  end else $fatal("Unsupported Remote Register File Type");

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
 * Fractal synchronization 2D (H - horizontal; V - vertical) remote register file
 * Asynchronous valid low reset
 *
 * Parameters:
 *  RF_TYPE     - Register file type (Directly Mapped or CAM)
 *  LEVEL_WIDTH - Width needed to represent the possible levels
 *  ID_WIDTH    - Width needed to represent the possible barrier ids
 *  N_CAM_LINES - Number of CAM lines (used if RF is CAM-based)
 *  N_PORTS     - Number of ports
 *
 * Interface signals:
 *  > level_i   - Level of synchronization requests/responses
 *  > id_i      - Id of synch. req./rsp.
 *  > sd_i      - Source/destinatin of synch. req./rsp. for back-routing
 *  > check_i   - Check RF for synch. rsp.
 *  > set_i     - Set RF for synch. req.
 *  < present_o - Indicates that synch. req./rsp is present in RF
 *  < sd_o      - Indicates the synch. req./rsp. destinations for back-routing
 *  < sig_err_o - Indicates that RF detected an incorrect signature
 *  < bypass_o  - Indicates that current RF req. should be bypassed (detected 2 req. to the same barrier)
 *  < ignore_o  - Indicates that current RF req. should be ignored (detected 2 req. to the same barrier)
 */

module fractal_sync_2d_remote_rf #(
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE     = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  LEVEL_WIDTH = 1,
  parameter int unsigned                  ID_WIDTH    = 1,
  parameter int unsigned                  N_CAM_LINES = 2,
  localparam int unsigned                 SD_WIDTH    = fractal_sync_pkg::SD_WIDTH,
  parameter int unsigned                  N_H_PORTS   = 2,
  parameter int unsigned                  N_V_PORTS   = 2
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_h_i[N_H_PORTS],
  input  logic[ID_WIDTH-1:0]    id_h_i[N_H_PORTS],
  input  logic[SD_WIDTH-1:0]    sd_h_i[N_H_PORTS],
  input  logic                  check_h_i[N_H_PORTS],
  input  logic                  set_h_i[N_H_PORTS],
  output logic                  h_present_o[N_H_PORTS],
  output logic[SD_WIDTH-1:0]    h_sd_o[N_H_PORTS],
  output logic                  h_sig_err_o[N_H_PORTS],
  output logic                  h_bypass_o[N_H_PORTS],
  output logic                  h_ignore_o[N_H_PORTS],

  input  logic[LEVEL_WIDTH-1:0] level_v_i[N_V_PORTS],
  input  logic[ID_WIDTH-1:0]    id_v_i[N_V_PORTS],
  input  logic[SD_WIDTH-1:0]    sd_v_i[N_V_PORTS],
  input  logic                  check_v_i[N_V_PORTS],
  input  logic                  set_v_i[N_V_PORTS],
  output logic                  v_present_o[N_V_PORTS],
  output logic[SD_WIDTH-1:0]    v_sd_o[N_V_PORTS],
  output logic                  v_sig_err_o[N_V_PORTS],
  output logic                  v_bypass_o[N_V_PORTS],
  output logic                  v_ignore_o[N_V_PORTS]
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
    .N_CAM_LINES ( N_H_CAM_LINES ),
    .N_PORTS     ( N_H_PORTS     )
  ) i_rf_h (
    .clk_i                    ,
    .rst_ni                   ,
    .level_i   ( level_h_i   ),
    .id_i      ( id_h_i      ),
    .sd_i      ( sd_h_i      ),
    .check_i   ( check_h_i   ),
    .set_i     ( set_h_i     ),
    .present_o ( h_present_o ),
    .sd_o      ( h_sd_o      ),
    .sig_err_o ( h_sig_err_o ),
    .bypass_o  ( h_bypass_o  ),
    .ignore_o  ( h_ignore_o  )
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
    .N_CAM_LINES ( N_V_CAM_LINES ),
    .N_PORTS     ( N_V_PORTS     )
  ) i_rf_v (
    .clk_i                    ,
    .rst_ni                   ,
    .level_i   ( level_v_i   ),
    .id_i      ( id_v_i      ),
    .sd_i      ( sd_v_i      ),
    .check_i   ( check_v_i   ),
    .set_i     ( set_v_i     ),
    .present_o ( v_present_o ),
    .sd_o      ( v_sd_o      ),
    .sig_err_o ( v_sig_err_o ),
    .bypass_o  ( v_bypass_o  ),
    .ignore_o  ( v_ignore_o  )
  );

/*******************************************************/
/**                  Vertical RF End                  **/
/*******************************************************/

endmodule: fractal_sync_2d_remote_rf