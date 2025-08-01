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
 *
 * Parameters:
 *  REMOTE_RF_TYPE  - Remote register file type (Directly Mapped or CAM)
 *  EN_REMOTE_RF    - Enable/disable remote RF (for root node)
 *  N_QUEUE_REGS    - Number of registers in the queue RF
 *  QUEUE_DEPTH     - Depth of the queue RF registers
 *  N_LOCAL_REGS    - Number of registers in the local RF
 *  LEVEL_WIDTH     - Width needed to represent the possible levels
 *  ID_WIDTH        - Width needed to represent the possible barrier ids
 *  N_REMOTE_LINES  - Number of CAM lines in a CAM-based remote RF
 *  br_pattern_t    - Type of the back-routing pattern
 *  QUEUE_COMB_FIFO - 1: Queue RF register FIFO with fall-through; 0: sequential register FIFO
 *  N_PORTS         - Number of ports
 *
 * Interface signals:
 *  > level_i          - Level of synchronization requests/responses
 *  > id_i             - Id of synch. req./rsp.
 *  > sd_remote_i      - Source/destinatin of synch. req./rsp. for back-routing
 *  > br_queue_i       - Back-routing patterns to be stored in queue RF
 *  > lock_queue_i     - Lock req. for the queue RF
 *  > free_queue_i     - Free req. for the queue RF
 *  > check_local_i    - Check local RF for synch. req.
 *  > check_remote_i   - Check remote RF for synch. req./rsp.
 *  > set_remote_i     - Set remote RF for synch. req.
 *  < grant_queue_o    - Indicates that synch. req. is granted by queue RF
 *  < present_local_o  - Indicates that synch. req. is present in local RF
 *  < present_remote_o - Indicates that synch. req./rsp. is present in remote RF
 *  < sd_remote_o      - Indicates the synch. req./rsp. destinations for back-routing
 *  < br_queue_o       - Indicates the back-routing patterns that have been granted access by the queue RF
 *  < id_err_o         - Indicates that local RF detected an incorrect id
 *  < sig_err_o        - Indicates that remote RF detected an incorrect signature
 *  < queue_err_o      - Indicates that the queue RF has detected a FIFO overflow error
 *  < bypass_local_o   - Indicates that current local RF req. should be bypassed and pushed to FIFO (detected 2 req. to the same barrier)
 *  < bypass_remote_o  - Indicates that current remote RF req. should be bypassed and pushed to FIFO (detected 2 req. to the same barrier)
 *  < ignore_local_o   - Indicates that current local RF req. should be ignored and not pushed to FIFO (detected 2 req. to the same barrier)
 *  < ignore_remote_o  - Indicates that current remote RF req. should be ignored and not pushed to FIFO (detected 2 req. to the same barrier)
 */

module fractal_sync_1d_rf
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::remote_rf_e    REMOTE_RF_TYPE  = fractal_sync_pkg::CAM_RF,
  parameter fractal_sync_pkg::en_remote_rf_e EN_REMOTE_RF    = fractal_sync_pkg::EN_REMOTE_RF,
  parameter int unsigned                     N_QUEUE_REGS    = 1,
  parameter int unsigned                     QUEUE_DEPTH     = 1,
  parameter int unsigned                     N_LOCAL_REGS    = 1,
  parameter int unsigned                     LEVEL_WIDTH     = 1,
  parameter int unsigned                     ID_WIDTH        = 1,
  parameter int unsigned                     N_REMOTE_LINES  = 1,
  parameter type                             br_pattern_t    = logic,
  parameter bit                              QUEUE_COMB_FIFO = 1'b1,
  localparam int unsigned                    SD_WIDTH        = fractal_sync_pkg::SD_WIDTH,
  parameter int unsigned                     N_LOCAL_PORTS   = 2,
  parameter int unsigned                     N_REMOTE_PORTS  = 3
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_i[N_REMOTE_PORTS],
  input  logic[ID_WIDTH-1:0]    id_i[N_REMOTE_PORTS],
  input  logic[SD_WIDTH-1:0]    sd_remote_i[N_REMOTE_PORTS],
  input  br_pattern_t           br_queue_i[N_LOCAL_PORTS],
  input  logic                  lock_queue_i[N_LOCAL_PORTS],
  input  logic                  free_queue_i[N_LOCAL_PORTS],
  input  logic                  check_local_i[N_LOCAL_PORTS],
  input  logic                  check_remote_i[N_REMOTE_PORTS],
  input  logic                  set_remote_i[N_REMOTE_PORTS],
  output logic                  grant_queue_o[N_LOCAL_PORTS],
  output logic                  present_local_o[N_LOCAL_PORTS],
  output logic                  present_remote_o[N_REMOTE_PORTS],
  output logic[SD_WIDTH-1:0]    sd_remote_o[N_REMOTE_PORTS],
  output br_pattern_t           br_queue_o[N_LOCAL_PORTS],
  output logic                  id_err_o[N_LOCAL_PORTS],
  output logic                  sig_err_o[N_REMOTE_PORTS],
  output logic                  queue_err_o[N_LOCAL_PORTS],
  output logic                  bypass_local_o[N_LOCAL_PORTS],
  output logic                  bypass_remote_o[N_REMOTE_PORTS],
  output logic                  ignore_local_o[N_LOCAL_PORTS],
  output logic                  ignore_remote_o[N_REMOTE_PORTS]
);

/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[ID_WIDTH-1:0] local_id[N_LOCAL_PORTS];

  logic local_id_error[N_LOCAL_PORTS];
  logic queue_id_error[N_LOCAL_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  for (genvar i = 0; i < N_LOCAL_PORTS; i++) begin: gen_id_error
    assign local_id[i] = id_i[i];
    assign id_err_o[i] = local_id_error[i] | queue_id_error[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 Local RF Beginning                **/
/*******************************************************/

  fractal_sync_1d_local_rf #(
    .N_REGS   ( N_LOCAL_REGS  ),
    .ID_WIDTH ( ID_WIDTH      ),
    .N_PORTS  ( N_LOCAL_PORTS )
  ) i_local_rf (
    .clk_i                        ,
    .rst_ni                       ,
    .id_i      ( local_id        ),
    .check_i   ( check_local_i   ),
    .present_o ( present_local_o ),
    .id_err_o  ( local_id_error  ),
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
      .N_PORTS     ( N_REMOTE_PORTS )
    ) i_remote_rf (
      .clk_i                         ,
      .rst_ni                        ,
      .level_i   ( level_i          ),
      .id_i      ( id_i             ),
      .sd_i      ( sd_remote_i      ),
      .check_i   ( check_remote_i   ),
      .set_i     ( set_remote_i     ),
      .present_o ( present_remote_o ),
      .sd_o      ( sd_remote_o      ),
      .sig_err_o ( sig_err_o        ),
      .bypass_o  ( bypass_remote_o  ),
      .ignore_o  ( ignore_remote_o  )
    );
  end else begin: gen_no_1d_remote_rf
    for (genvar i = 0; i < N_REMOTE_PORTS; i++) begin
      assign present_remote_o[i] = 1'b0;
      assign sd_remote_o[i]      = '0;
      assign sig_err_o[i]        = 1'b0;
      assign bypass_remote_o[i]  = 1'b0;
      assign ignore_remote_o[i]  = 1'b0;
    end
  end

/*******************************************************/
/**                   Remote RF End                   **/
/*******************************************************/
/**                 Queue RF Beginning                **/
/*******************************************************/

  fractal_sync_1d_queue_rf #(
    .N_REGS    ( N_QUEUE_REGS    ),
    .REG_DEPTH ( QUEUE_DEPTH     ),
    .ID_WIDTH  ( ID_WIDTH        ),
    .element_t ( br_pattern_t    ),
    .COMB_OUT  ( QUEUE_COMB_FIFO ),
    .N_PORTS   ( N_LOCAL_PORTS   )
  ) i_queue_rf (
    .clk_i                              ,
    .rst_ni                             ,
    .id_i             ( local_id       ),
    .lock_i           ( lock_queue_i   ),
    .free_i           ( free_queue_i   ),
    .element_i        ( br_queue_i     ),
    .grant_o          ( grant_queue_o  ),
    .element_o        ( br_queue_o     ),
    .id_err_o         ( queue_id_error ),
    .overflow_error_o ( queue_err_o    )
  );

/*******************************************************/
/**                    Queue RF End                   **/
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
 * Fractal synchronization 2D (H - horizontal; V - vertical) register file
 * Asynchronous valid low reset
 *
 * Parameters:
 *  REMOTE_RF_TYPE  - Remote register file type (Directly Mapped or CAM)
 *  EN_REMOTE_RF    - Enable/disable remote RF (for root node)
 *  N_QUEUE_REGS    - Number of registers in the queue RF
 *  QUEUE_DEPTH     - Depth of the queue RF registers
 *  N_LOCAL_REGS    - Number of registers in the local RF
 *  LEVEL_WIDTH     - Width needed to represent the possible levels
 *  ID_WIDTH        - Width needed to represent the possible barrier ids
 *  N_REMOTE_LINES  - Number of CAM lines in a CAM-based remote RF
 *  br_pattern_t    - Type of the back-routing pattern
 *  QUEUE_COMB_FIFO - 1: Queue RF register FIFO with fall-through; 0: sequential register FIFO
 *  N_PORTS         - Number of ports
 *
 * Interface signals:
 *  > level_i          - Level of synchronization requests/responses
 *  > id_i             - Id of synch. req./rsp.
 *  > sd_remote_i      - Source/destinatin of synch. req./rsp. for back-routing
 *  > br_queue_i       - Back-routing patterns to be stored in queue RF
 *  > lock_queue_i     - Lock req. for the queue RF
 *  > free_queue_i     - Free req. for the queue RF
 *  > check_local_i    - Check local RF for synch. req.
 *  > check_remote_i   - Check remote RF for synch. req./rsp.
 *  > set_remote_i     - Set remote RF for synch. req.
 *  < grant_queue_o    - Indicates that synch. req. is granted by queue RF
 *  < present_local_o  - Indicates that synch. req. is present in local RF
 *  < present_remote_o - Indicates that synch. req./rsp. is present in remote RF
 *  < sd_remote_o      - Indicates the synch. req./rsp. destinations for back-routing
 *  < br_queue_o       - Indicates the back-routing patterns that have been granted access by the queue RF
 *  < id_err_o         - Indicates that local RF detected an incorrect id
 *  < sig_err_o        - Indicates that remote RF detected an incorrect signature
 *  < queue_err_o      - Indicates that the queue RF has detected a FIFO overflow error
 *  < bypass_local_o   - Indicates that current local RF req. should be bypassed and pushed to FIFO (detected 2 req. to the same barrier)
 *  < bypass_remote_o  - Indicates that current remote RF req. should be bypassed and pushed to FIFO (detected 2 req. to the same barrier)
 *  < ignore_local_o   - Indicates that current local RF req. should be ignored and not pushed to FIFO (detected 2 req. to the same barrier)
 *  < ignore_remote_o  - Indicates that current remote RF req. should be ignored and not pushed to FIFO (detected 2 req. to the same barrier)
 */

module fractal_sync_2d_rf
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::remote_rf_e    REMOTE_RF_TYPE   = fractal_sync_pkg::CAM_RF,
  parameter fractal_sync_pkg::en_remote_rf_e EN_REMOTE_RF     = fractal_sync_pkg::EN_REMOTE_RF,
  parameter int unsigned                     N_QUEUE_REGS     = 2,
  parameter int unsigned                     QUEUE_DEPTH      = 2,
  parameter int unsigned                     N_LOCAL_REGS     = 2,
  parameter int unsigned                     LEVEL_WIDTH      = 1,
  parameter int unsigned                     ID_WIDTH         = 1,
  parameter int unsigned                     N_REMOTE_LINES   = 2,
  parameter type                             br_pattern_t     = logic,
  parameter bit                              QUEUE_COMB_FIFO  = 1'b1,
  localparam int unsigned                    SD_WIDTH         = fractal_sync_pkg::SD_WIDTH,
  parameter int unsigned                     N_LOCAL_H_PORTS  = 2,
  parameter int unsigned                     N_LOCAL_V_PORTS  = 2,
  parameter int unsigned                     N_REMOTE_H_PORTS = 3,
  parameter int unsigned                     N_REMOTE_V_PORTS = 3
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic[LEVEL_WIDTH-1:0] level_h_i[N_REMOTE_H_PORTS],
  input  logic[ID_WIDTH-1:0]    id_h_i[N_REMOTE_H_PORTS],
  input  logic[SD_WIDTH-1:0]    sd_h_remote_i[N_REMOTE_H_PORTS],
  input  br_pattern_t           br_h_queue_i[N_LOCAL_H_PORTS],
  input  logic                  lock_h_queue_i[N_LOCAL_H_PORTS],
  input  logic                  free_h_queue_i[N_LOCAL_H_PORTS],
  input  logic                  check_h_local_i[N_LOCAL_H_PORTS],
  input  logic                  check_h_remote_i[N_REMOTE_H_PORTS],
  input  logic                  set_h_remote_i[N_REMOTE_H_PORTS],
  output logic                  h_grant_queue_o[N_LOCAL_H_PORTS],
  output logic                  h_present_local_o[N_LOCAL_H_PORTS],
  output logic                  h_present_remote_o[N_REMOTE_H_PORTS],
  output logic[SD_WIDTH-1:0]    h_sd_remote_o[N_REMOTE_H_PORTS],
  output br_pattern_t           h_br_queue_o[N_LOCAL_H_PORTS],
  output logic                  h_id_err_o[N_LOCAL_H_PORTS],
  output logic                  h_sig_err_o[N_REMOTE_H_PORTS],
  output logic                  h_queue_err_o[N_LOCAL_H_PORTS],
  output logic                  h_bypass_local_o[N_LOCAL_H_PORTS],
  output logic                  h_bypass_remote_o[N_REMOTE_H_PORTS],
  output logic                  h_ignore_local_o[N_LOCAL_H_PORTS],
  output logic                  h_ignore_remote_o[N_REMOTE_H_PORTS],

  input  logic[LEVEL_WIDTH-1:0] level_v_i[N_REMOTE_V_PORTS],
  input  logic[ID_WIDTH-1:0]    id_v_i[N_REMOTE_V_PORTS],
  input  logic[SD_WIDTH-1:0]    sd_v_remote_i[N_REMOTE_V_PORTS],
  input  br_pattern_t           br_v_queue_i[N_LOCAL_V_PORTS],
  input  logic                  lock_v_queue_i[N_LOCAL_V_PORTS],
  input  logic                  free_v_queue_i[N_LOCAL_V_PORTS],
  input  logic                  check_v_local_i[N_LOCAL_V_PORTS],
  input  logic                  check_v_remote_i[N_REMOTE_V_PORTS],
  input  logic                  set_v_remote_i[N_REMOTE_V_PORTS],
  output logic                  v_grant_queue_o[N_LOCAL_V_PORTS],
  output logic                  v_present_local_o[N_LOCAL_V_PORTS],
  output logic                  v_present_remote_o[N_REMOTE_V_PORTS],
  output logic[SD_WIDTH-1:0]    v_sd_remote_o[N_REMOTE_V_PORTS],
  output br_pattern_t           v_br_queue_o[N_LOCAL_V_PORTS],
  output logic                  v_id_err_o[N_LOCAL_V_PORTS],
  output logic                  v_sig_err_o[N_REMOTE_V_PORTS],
  output logic                  v_queue_err_o[N_LOCAL_V_PORTS],
  output logic                  v_bypass_local_o[N_LOCAL_V_PORTS],
  output logic                  v_bypass_remote_o[N_REMOTE_V_PORTS],
  output logic                  v_ignore_local_o[N_LOCAL_V_PORTS],
  output logic                  v_ignore_remote_o[N_REMOTE_V_PORTS]
);

/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[ID_WIDTH-1:0] local_h_id[N_LOCAL_H_PORTS];
  logic[ID_WIDTH-1:0] local_v_id[N_LOCAL_V_PORTS];

  logic h_local_id_error[N_LOCAL_H_PORTS];
  logic v_local_id_error[N_LOCAL_V_PORTS];
  logic h_queue_id_error[N_LOCAL_H_PORTS];
  logic v_queue_id_error[N_LOCAL_V_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  for (genvar i = 0; i < N_LOCAL_H_PORTS; i++) begin: gen_h_id_error
    assign local_h_id[i] = id_h_i[i];
    assign h_id_err_o[i] = h_local_id_error[i] | h_queue_id_error[i];
  end
  for (genvar i = 0; i < N_LOCAL_V_PORTS; i++) begin: gen_v_id_error
    assign local_v_id[i] = id_v_i[i];
    assign v_id_err_o[i] = v_local_id_error[i] | v_queue_id_error[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 Local RF Beginning                **/
/*******************************************************/

  fractal_sync_2d_local_rf #(
    .N_REGS    ( N_LOCAL_REGS    ),
    .ID_WIDTH  ( ID_WIDTH        ),
    .N_H_PORTS ( N_LOCAL_H_PORTS ),
    .N_V_PORTS ( N_LOCAL_V_PORTS )
  ) i_local_rf (
    .clk_i                            ,
    .rst_ni                           ,
    .id_h_i      ( local_h_id        ),
    .check_h_i   ( check_h_local_i   ),
    .h_present_o ( h_present_local_o ),
    .h_id_err_o  ( h_local_id_error  ),
    .h_bypass_o  ( h_bypass_local_o  ),
    .h_ignore_o  ( h_ignore_local_o  ),
    .id_v_i      ( local_v_id        ),
    .check_v_i   ( check_v_local_i   ),
    .v_present_o ( v_present_local_o ),
    .v_id_err_o  ( v_local_id_error  ),
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
      .RF_TYPE     ( REMOTE_RF_TYPE   ),
      .LEVEL_WIDTH ( LEVEL_WIDTH      ),
      .ID_WIDTH    ( ID_WIDTH         ),
      .N_CAM_LINES ( N_REMOTE_LINES   ),
      .N_H_PORTS   ( N_REMOTE_H_PORTS ),
      .N_V_PORTS   ( N_REMOTE_V_PORTS )
    ) i_remote_rf (
      .clk_i                             ,
      .rst_ni                            ,
      .level_h_i   ( level_h_i          ),
      .id_h_i      ( id_h_i             ),
      .sd_h_i      ( sd_h_remote_i      ),
      .check_h_i   ( check_h_remote_i   ),
      .set_h_i     ( set_h_remote_i     ),
      .h_present_o ( h_present_remote_o ),
      .h_sd_o      ( h_sd_remote_o      ),
      .h_sig_err_o ( h_sig_err_o        ),
      .h_bypass_o  ( h_bypass_remote_o  ),
      .h_ignore_o  ( h_ignore_remote_o  ),
      .level_v_i   ( level_v_i          ),
      .id_v_i      ( id_v_i             ),
      .sd_v_i      ( sd_v_remote_i      ),
      .check_v_i   ( check_v_remote_i   ),
      .set_v_i     ( set_v_remote_i     ),
      .v_present_o ( v_present_remote_o ),
      .v_sd_o      ( v_sd_remote_o      ),
      .v_sig_err_o ( v_sig_err_o        ),
      .v_bypass_o  ( v_bypass_remote_o  ),
      .v_ignore_o  ( v_ignore_remote_o  )
    );
  end else begin: gen_no_2d_remote_rf
    for (genvar i = 0; i < N_REMOTE_H_PORTS; i++) begin
      assign h_present_remote_o[i] = 1'b0;
      assign h_sd_remote_o[i]      = '0;
      assign h_sig_err_o[i]        = 1'b0;
      assign h_bypass_remote_o[i]  = 1'b0;
      assign h_ignore_remote_o[i]  = 1'b0;
    end
    for (genvar i = 0; i < N_REMOTE_V_PORTS; i++) begin
      assign v_present_remote_o[i] = 1'b0;
      assign v_sd_remote_o[i]      = '0;
      assign v_sig_err_o[i]        = 1'b0;
      assign v_bypass_remote_o[i]  = 1'b0;
      assign v_ignore_remote_o[i]  = 1'b0;
    end
  end

/*******************************************************/
/**                   Remote RF End                   **/
/*******************************************************/
/**                 Queue RF Beginning                **/
/*******************************************************/

  fractal_sync_2d_queue_rf #(
    .N_REGS    ( N_QUEUE_REGS    ),
    .REG_DEPTH ( QUEUE_DEPTH     ),
    .ID_WIDTH  ( ID_WIDTH        ),
    .element_t ( br_pattern_t    ),
    .COMB_OUT  ( QUEUE_COMB_FIFO ),
    .N_H_PORTS ( N_LOCAL_H_PORTS ),
    .N_V_PORTS ( N_LOCAL_V_PORTS )
  ) i_queue_rf (
    .clk_i                                  ,
    .rst_ni                                 ,
    .id_h_i             ( local_h_id       ),
    .lock_h_i           ( lock_h_queue_i   ),
    .free_h_i           ( free_h_queue_i   ),
    .element_h_i        ( br_h_queue_i     ),
    .h_grant_o          ( h_grant_queue_o  ),
    .h_element_o        ( h_br_queue_o     ),
    .h_id_err_o         ( h_queue_id_error ),
    .h_overflow_error_o ( h_queue_err_o    ),
    .id_v_i             ( local_v_id       ),
    .lock_v_i           ( lock_v_queue_i   ),
    .free_v_i           ( free_v_queue_i   ),
    .element_v_i        ( br_v_queue_i     ),
    .v_grant_o          ( v_grant_queue_o  ),
    .v_element_o        ( v_br_queue_o     ),
    .v_id_err_o         ( v_queue_id_error ),
    .h_overflow_error_o ( v_queue_err_o    )
  );

/*******************************************************/
/**                    Queue RF End                   **/
/*******************************************************/

endmodule: fractal_sync_2d_rf