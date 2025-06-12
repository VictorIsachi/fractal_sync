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
 * Fractal synchronization 4x4 network
 * Asynchronous valid low reset
 *
 * Parameters:
 *  TOP_NODE_TYPE     - Top node type (2D or root)
 *  RF_TYPE_1D        - Remote RF type (DM or CAM) of 1D nodes at various levels: index 0 refers to level 1, index 1 refers to level 3, ...
 *  N_LOCAL_REGS_1D   - Local RF size of 1D nodes at various levels: index 0 refers to level 1, index 1 refers to level 3, ...
 *  N_REMOTE_LINES_1D - Remote RF size of CAM-based 1D nodes at various levels: index 0 refers to level 1, index 1 refers to level 3, ...
 *  RF_TYPE_2D        - Remote RF type (DM or CAM) of 2D nodes at various levels: index 0 refers to level 2, index 1 refers to level 4, ...
 *  N_LOCAL_REGS_2D   - Local RF size of 2D nodes at various levels: index 0 refers to level 2, index 1 refers to level 4, ...
 *  N_REMOTE_LINES_2D - Remote RF size of CAM-based 2D nodes (will be ignored for root node) at various levels: index 0 refers to level 2, index 1 refers to level 4, ...
 *  N_LINKS_IN        - Number of input links of the 1D network links (CU-1D node)
 *  N_LINKS_ITL       - Number of network links at the intermediate (internal) levels: index 0 refers to level 2, index 1 refers to level 3, ...
 *  N_LINKS_OUT       - Number of output links of the 2D network links (2D node-Out)
 *  AGGREGATE_WIDTH   - Width of the aggr field (CU-1D interface)
 *  ID_WIDTH          - Width of the id field (CU-1D interface)
 *  LVL_OFFSET        - Level offset of 1D nodes (CU-1D interface)
 *  fsync_in_req_t    - CU-1D (horizontal/vertical) synchronization request type (see hw/include/typedef.svh for a template)
 *  fsync_out_req_t   - Top node output synchronization request type  (see hw/include/typedef.svh for a template)
 *  fsync_rsp_t       - 1D/top node synchronization response type (see hw/include/typedef.svh for a template)
 *  fsync_nbr_req_t   - CU neighbor synchronization request type (see hw/include/typedef.svh for a template)
 *  fsync_nbr_rsp_t   - CU neighbor synchronization response type (see hw/include/typedef.svh for a template)
 *
 * Interface signals:
 *  > h_1d_fsync_req_i  - CU horizontal 1D synchronization request
 *  > h_1d_fsync_rsp_o  - CU horizontal 1D synchronization response
 *  > v_1d_fsync_req_i  - CU vertical 1D synchronization request
 *  > v_1d_fsync_rsp_o  - CU vertical 1D synchronization response
 *  > h_nbr_fsycn_req_i - CU horizontal neighbor synchronization request
 *  > h_nbr_fsycn_rsp_o - CU horizontal neighbor synchronization response
 *  > v_nbr_fsycn_req_i - CU vertical neighbor synchronization request
 *  > v_nbr_fsycn_rsp_o - CU vertical neighbor synchronization response
 *  > h_2d_fsync_req_o  - Top node horizontal synchronization request
 *  > h_2d_fsync_rsp_i  - Top node horizontal synchronization response
 *  > v_2d_fsync_req_o  - Top node vertical synchronization request
 *  > v_2d_fsync_rsp_i  - Top node vertical synchronization response
 */

  `include "../include/fractal_sync/typedef.svh"
  `include "../include/fractal_sync/assign.svh"

package fractal_sync_4x4_pkg;

  import fractal_sync_pkg::*;

  localparam int unsigned                  N_ITL_LEVELS                       = 3;
  localparam int unsigned                  N_1D_ITL_LEVELS                    = (N_ITL_LEVELS+1)/2;
  localparam int unsigned                  N_2D_ITL_LEVELS                    = (N_ITL_LEVELS+1)/2;

  localparam fractal_sync_pkg::node_e      TOP_NODE_TYPE                      = fractal_sync_pkg::HV_NODE;
  localparam fractal_sync_pkg::remote_rf_e RF_TYPE_1D[N_1D_ITL_LEVELS]        = '{fractal_sync_pkg::CAM_RF,
                                                                                  fractal_sync_pkg::CAM_RF};
  localparam int unsigned                  N_LOCAL_REGS_1D[N_1D_ITL_LEVELS]   = '{1, 4};
  localparam int unsigned                  N_REMOTE_LINES_1D[N_1D_ITL_LEVELS] = '{2, 8};
  localparam fractal_sync_pkg::remote_rf_e RF_TYPE_2D[N_2D_ITL_LEVELS]        = '{fractal_sync_pkg::CAM_RF,
                                                                                  fractal_sync_pkg::CAM_RF};
  localparam int unsigned                  N_LOCAL_REGS_2D[N_2D_ITL_LEVELS]   = '{2, 8};
  localparam int unsigned                  N_REMOTE_LINES_2D[N_2D_ITL_LEVELS] = '{4, 16};

  localparam int unsigned                  N_LINKS_IN                         = 1;
  localparam int unsigned                  N_LINKS_ITL[N_ITL_LEVELS]          = '{1, 2, 4};
  localparam int unsigned                  N_LINKS_OUT                        = 1;

  localparam int unsigned                  N_1D_H_PORTS                       = 16;
  localparam int unsigned                  N_1D_V_PORTS                       = 16;
  localparam int unsigned                  N_NBR_H_PORTS                      = 16;
  localparam int unsigned                  N_NBR_V_PORTS                      = 16;
  localparam int unsigned                  N_ACTIVE_NBR_H_PORTS               = $sqrt(N_NBR_H_PORTS);
  localparam int unsigned                  N_ACTIVE_NBR_V_PORTS               = $sqrt(N_NBR_V_PORTS);
  localparam int unsigned                  N_2D_H_PORTS                       = 1;
  localparam int unsigned                  N_2D_V_PORTS                       = 1;

  localparam int unsigned                  OUT_AGGR_WIDTH                     = 1;
  localparam int unsigned                  IN_AGGR_WIDTH                      = OUT_AGGR_WIDTH+N_ITL_LEVELS+1;
  localparam int unsigned                  LVL_WIDTH                          = $clog2(IN_AGGR_WIDTH-1);
  localparam int unsigned                  ID_WIDTH                           = N_ITL_LEVELS;
  localparam int unsigned                  IN_LVL_OFFSET                      = 0;

  localparam int unsigned                  NBR_AGGR_WIDTH                     = 1;
  localparam int unsigned                  NBR_LVL_WIDTH                      = 1;
  localparam int unsigned                  NBR_ID_WIDTH                       = 1;

  `FSYNC_TYPEDEF_REQ_ALL(fsync_in, logic[IN_AGGR_WIDTH-1:0], logic[ID_WIDTH-1:0])
  `FSYNC_TYPEDEF_REQ_ALL(fsync_out, logic[OUT_AGGR_WIDTH-1:0], logic[ID_WIDTH-1:0])
  `FSYNC_TYPEDEF_RSP_ALL(fsync, logic[LVL_WIDTH-1:0], logic[ID_WIDTH-1:0])
  `FSYNC_TYPEDEF_ALL(fsync_nbr, logic[NBR_AGGR_WIDTH-1:0], logic[NBR_LVL_WIDTH-1:0], logic[NBR_ID_WIDTH-1:0])

endpackage: fractal_sync_4x4_pkg

module fractal_sync_4x4_core
  import fractal_sync_4x4_pkg::*;
#(
  parameter fractal_sync_pkg::node_e      TOP_NODE_TYPE                                            = fractal_sync_4x4_pkg::TOP_NODE_TYPE,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE_1D[fractal_sync_4x4_pkg::N_1D_ITL_LEVELS]        = fractal_sync_4x4_pkg::RF_TYPE_1D,
  parameter int unsigned                  N_LOCAL_REGS_1D[fractal_sync_4x4_pkg::N_1D_ITL_LEVELS]   = fractal_sync_4x4_pkg::N_LOCAL_REGS_1D,
  parameter int unsigned                  N_REMOTE_LINES_1D[fractal_sync_4x4_pkg::N_1D_ITL_LEVELS] = fractal_sync_4x4_pkg::N_REMOTE_LINES_1D,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE_2D[fractal_sync_4x4_pkg::N_2D_ITL_LEVELS]        = fractal_sync_4x4_pkg::RF_TYPE_2D,
  parameter int unsigned                  N_LOCAL_REGS_2D[fractal_sync_4x4_pkg::N_2D_ITL_LEVELS]   = fractal_sync_4x4_pkg::N_LOCAL_REGS_2D,
  parameter int unsigned                  N_REMOTE_LINES_2D[fractal_sync_4x4_pkg::N_2D_ITL_LEVELS] = fractal_sync_4x4_pkg::N_REMOTE_LINES_2D,
  parameter int unsigned                  N_LINKS_IN                                               = fractal_sync_4x4_pkg::N_LINKS_IN,
  parameter int unsigned                  N_LINKS_ITL[fractal_sync_4x4_pkg::N_ITL_LEVELS]          = fractal_sync_4x4_pkg::N_LINKS_ITL,
  parameter int unsigned                  N_LINKS_OUT                                              = fractal_sync_4x4_pkg::N_LINKS_OUT,
  parameter int unsigned                  AGGREGATE_WIDTH                                          = fractal_sync_4x4_pkg::IN_AGGR_WIDTH,
  parameter int unsigned                  ID_WIDTH                                                 = fractal_sync_4x4_pkg::ID_WIDTH,
  parameter int unsigned                  LVL_OFFSET                                               = fractal_sync_4x4_pkg::IN_LVL_OFFSET,
  parameter type                          fsync_in_req_t                                           = fractal_sync_4x4_pkg::fsync_in_req_t,
  parameter type                          fsync_out_req_t                                          = fractal_sync_4x4_pkg::fsync_out_req_t,
  parameter type                          fsync_rsp_t                                              = fractal_sync_4x4_pkg::fsync_rsp_t,
  parameter type                          fsync_nbr_req_t                                          = fractal_sync_4x4_pkg::fsync_nbr_req_t,
  parameter type                          fsync_nbr_rsp_t                                          = fractal_sync_4x4_pkg::fsync_nbr_rsp_t,
  localparam int unsigned                 N_1D_H_PORTS                                             = fractal_sync_4x4_pkg::N_1D_H_PORTS,
  localparam int unsigned                 N_1D_V_PORTS                                             = fractal_sync_4x4_pkg::N_1D_V_PORTS,
  localparam int unsigned                 N_ACTIVE_NBR_H_PORTS                                     = fractal_sync_4x4_pkg::N_ACTIVE_NBR_H_PORTS,
  localparam int unsigned                 N_ACTIVE_NBR_V_PORTS                                     = fractal_sync_4x4_pkg::N_ACTIVE_NBR_V_PORTS,
  localparam int unsigned                 N_2D_H_PORTS                                             = fractal_sync_4x4_pkg::N_2D_H_PORTS,
  localparam int unsigned                 N_2D_V_PORTS                                             = fractal_sync_4x4_pkg::N_2D_V_PORTS
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_in_req_t h_1d_fsync_req_i[N_1D_H_PORTS][N_LINKS_IN],
  output fsync_rsp_t    h_1d_fsync_rsp_o[N_1D_H_PORTS][N_LINKS_IN],
  input  fsync_in_req_t v_1d_fsync_req_i[N_1D_V_PORTS][N_LINKS_IN],
  output fsync_rsp_t    v_1d_fsync_rsp_o[N_1D_V_PORTS][N_LINKS_IN],

  input  fsync_nbr_req_t h_nbr_fsycn_req_i[N_ACTIVE_NBR_H_PORTS],
  output fsync_nbr_rsp_t h_nbr_fsycn_rsp_o[N_ACTIVE_NBR_H_PORTS],
  input  fsync_nbr_req_t v_nbr_fsycn_req_i[N_ACTIVE_NBR_V_PORTS],
  output fsync_nbr_rsp_t v_nbr_fsycn_rsp_o[N_ACTIVE_NBR_V_PORTS],

  output fsync_out_req_t h_2d_fsync_req_o[N_2D_H_PORTS][N_LINKS_OUT],
  input  fsync_rsp_t     h_2d_fsync_rsp_i[N_2D_H_PORTS][N_LINKS_OUT],
  output fsync_out_req_t v_2d_fsync_req_o[N_2D_V_PORTS][N_LINKS_OUT],
  input  fsync_rsp_t     v_2d_fsync_rsp_i[N_2D_V_PORTS][N_LINKS_OUT]
);

/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned N_LEAF_FSYNC_NETWORKS = 4;

  localparam int unsigned LEAF_RF_TYPE_1D        = RF_TYPE_1D[0];
  localparam int unsigned LEAF_N_LOCAL_REGS_1D   = N_LOCAL_REGS_1D[0];
  localparam int unsigned LEAF_N_REMOTE_LINES_1D = N_REMOTE_LINES_1D[0];
  localparam int unsigned LEAF_RF_TYPE_2D        = RF_TYPE_2D[0];
  localparam int unsigned LEAF_N_LOCAL_REGS_2D   = N_LOCAL_REGS_2D[0];
  localparam int unsigned LEAF_N_REMOTE_LINES_2D = N_REMOTE_LINES_2D[0];
  localparam int unsigned LEAF_N_LINKS_IN        = N_LINKS_IN;
  localparam int unsigned LEAF_N_LINKS_ITL       = N_LINKS_ITL[0];
  localparam int unsigned LEAF_N_LINKS_OUT       = N_LINKS_ITL[1];
  localparam int unsigned LEAF_AGGREGATE_WIDTH   = AGGREGATE_WIDTH;
  localparam int unsigned LEAF_ID_WIDTH          = ID_WIDTH;
  localparam int unsigned LEAF_LVL_OFFSET        = LVL_OFFSET;

  localparam int unsigned ROOT_RF_TYPE_1D        = RF_TYPE_1D[1];
  localparam int unsigned ROOT_N_LOCAL_REGS_1D   = N_LOCAL_REGS_1D[1];
  localparam int unsigned ROOT_N_REMOTE_LINES_1D = N_REMOTE_LINES_1D[1];
  localparam int unsigned ROOT_RF_TYPE_2D        = RF_TYPE_2D[1];
  localparam int unsigned ROOT_N_LOCAL_REGS_2D   = N_LOCAL_REGS_2D[1];
  localparam int unsigned ROOT_N_REMOTE_LINES_2D = N_REMOTE_LINES_2D[1];
  localparam int unsigned ROOT_N_LINKS_IN        = N_LINKS_ITL[1];
  localparam int unsigned ROOT_N_LINKS_ITL       = N_LINKS_ITL[2];
  localparam int unsigned ROOT_N_LINKS_OUT       = N_LINKS_OUT;
  localparam int unsigned ROOT_AGGREGATE_WIDTH   = LEAF_AGGREGATE_WIDTH-2;
  localparam int unsigned ROOT_ID_WIDTH          = LEAF_ID_WIDTH;
  localparam int unsigned ROOT_LVL_OFFSET        = LEAF_LVL_OFFSET+2;

  localparam int unsigned ITL_RSP_AGGR_WIDTH = ROOT_AGGREGATE_WIDTH;
  `FSYNC_TYPEDEF_REQ_ALL(fsync_itl, logic[ITL_RSP_AGGR_WIDTH-1:0], logic[ID_WIDTH-1:0])

  localparam int unsigned N_1D_H_LEAF_PORTS = N_1D_H_PORTS/N_LEAF_FSYNC_NETWORKS;
  localparam int unsigned N_1D_V_LEAF_PORTS = N_1D_V_PORTS/N_LEAF_FSYNC_NETWORKS;

  localparam int unsigned N_2D_H_LEAF_PORTS = N_2D_H_PORTS;
  localparam int unsigned N_2D_V_LEAF_PORTS = N_2D_V_PORTS;

  localparam int unsigned N_1D_H_ROOT_PORTS = N_LEAF_FSYNC_NETWORKS;
  localparam int unsigned N_1D_V_ROOT_PORTS = N_LEAF_FSYNC_NETWORKS;

  localparam int unsigned N_H_NBR_NODES = $sqrt(N_NBR_H_PORTS);
  localparam int unsigned N_V_NBR_NODES = $sqrt(N_NBR_V_PORTS);

  localparam int unsigned N_NBR_IN_PORTS = 2;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  fsync_in_req_t h_1d_fsync_req[N_LEAF_FSYNC_NETWORKS][N_1D_H_LEAF_PORTS][LEAF_N_LINKS_IN];
  fsync_rsp_t    h_1d_fsync_rsp[N_LEAF_FSYNC_NETWORKS][N_1D_H_LEAF_PORTS][LEAF_N_LINKS_IN];
  fsync_in_req_t v_1d_fsync_req[N_LEAF_FSYNC_NETWORKS][N_1D_V_LEAF_PORTS][LEAF_N_LINKS_IN];
  fsync_rsp_t    v_1d_fsync_rsp[N_LEAF_FSYNC_NETWORKS][N_1D_V_LEAF_PORTS][LEAF_N_LINKS_IN];

  fsync_itl_req_t leaf_h_2d_fsync_req[N_LEAF_FSYNC_NETWORKS][N_2D_H_LEAF_PORTS][LEAF_N_LINKS_OUT];
  fsync_rsp_t     leaf_h_2d_fsync_rsp[N_LEAF_FSYNC_NETWORKS][N_2D_H_LEAF_PORTS][LEAF_N_LINKS_OUT];
  fsync_itl_req_t leaf_v_2d_fsync_req[N_LEAF_FSYNC_NETWORKS][N_2D_V_LEAF_PORTS][LEAF_N_LINKS_OUT];
  fsync_rsp_t     leaf_v_2d_fsync_rsp[N_LEAF_FSYNC_NETWORKS][N_2D_V_LEAF_PORTS][LEAF_N_LINKS_OUT];

  fsync_itl_req_t root_h_1d_fsync_req[N_1D_H_ROOT_PORTS][ROOT_N_LINKS_IN];
  fsync_rsp_t     root_h_1d_fsync_rsp[N_1D_H_ROOT_PORTS][ROOT_N_LINKS_IN];
  fsync_itl_req_t root_v_1d_fsync_req[N_1D_V_ROOT_PORTS][ROOT_N_LINKS_IN];
  fsync_rsp_t     root_v_1d_fsync_rsp[N_1D_V_ROOT_PORTS][ROOT_N_LINKS_IN];

  fsync_nbr_req_t h_nbr_fsycn_req[N_H_NBR_NODES][N_NBR_IN_PORTS];
  fsync_nbr_rsp_t h_nbr_fsycn_rsp[N_H_NBR_NODES][N_NBR_IN_PORTS];
  fsync_nbr_req_t v_nbr_fsycn_req[N_V_NBR_NODES][N_NBR_IN_PORTS];
  fsync_nbr_rsp_t v_nbr_fsycn_rsp[N_V_NBR_NODES][N_NBR_IN_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < N_LINKS_IN; i++) begin: gen_1d_leaf_fsync_net_req_rsp
    // assign h_1d_fsync_req[i][j][k] = h_1d_fsync_req_i[2*(4*(i/2)+(i%2))+(4*(j/2)+(j%2))][k];
    assign h_1d_fsync_req[0][0][i] = h_1d_fsync_req_i[0][i];
    assign h_1d_fsync_req[0][1][i] = h_1d_fsync_req_i[1][i];
    assign h_1d_fsync_req[0][2][i] = h_1d_fsync_req_i[4][i];
    assign h_1d_fsync_req[0][3][i] = h_1d_fsync_req_i[5][i];
    assign h_1d_fsync_req[1][0][i] = h_1d_fsync_req_i[2][i];
    assign h_1d_fsync_req[1][1][i] = h_1d_fsync_req_i[3][i];
    assign h_1d_fsync_req[1][2][i] = h_1d_fsync_req_i[6][i];
    assign h_1d_fsync_req[1][3][i] = h_1d_fsync_req_i[7][i];
    assign h_1d_fsync_req[2][0][i] = h_1d_fsync_req_i[8][i];
    assign h_1d_fsync_req[2][1][i] = h_1d_fsync_req_i[9][i];
    assign h_1d_fsync_req[2][2][i] = h_1d_fsync_req_i[12][i];
    assign h_1d_fsync_req[2][3][i] = h_1d_fsync_req_i[13][i];
    assign h_1d_fsync_req[3][0][i] = h_1d_fsync_req_i[10][i];
    assign h_1d_fsync_req[3][1][i] = h_1d_fsync_req_i[11][i];
    assign h_1d_fsync_req[3][2][i] = h_1d_fsync_req_i[14][i];
    assign h_1d_fsync_req[3][3][i] = h_1d_fsync_req_i[15][i];

    // assign h_1d_fsync_rsp_o[2*(4*(i/2)+(i%2))+(4*(j/2)+(j%2))][k] = assign h_1d_fsync_rsp[i][j][k];
    assign h_1d_fsync_rsp_o[0][i]  = h_1d_fsync_rsp[0][0][i];
    assign h_1d_fsync_rsp_o[1][i]  = h_1d_fsync_rsp[0][1][i];
    assign h_1d_fsync_rsp_o[4][i]  = h_1d_fsync_rsp[0][2][i];
    assign h_1d_fsync_rsp_o[5][i]  = h_1d_fsync_rsp[0][3][i];
    assign h_1d_fsync_rsp_o[2][i]  = h_1d_fsync_rsp[1][0][i];
    assign h_1d_fsync_rsp_o[3][i]  = h_1d_fsync_rsp[1][1][i];
    assign h_1d_fsync_rsp_o[6][i]  = h_1d_fsync_rsp[1][2][i];
    assign h_1d_fsync_rsp_o[7][i]  = h_1d_fsync_rsp[1][3][i];
    assign h_1d_fsync_rsp_o[8][i]  = h_1d_fsync_rsp[2][0][i];
    assign h_1d_fsync_rsp_o[9][i]  = h_1d_fsync_rsp[2][1][i];
    assign h_1d_fsync_rsp_o[12][i] = h_1d_fsync_rsp[2][2][i];
    assign h_1d_fsync_rsp_o[13][i] = h_1d_fsync_rsp[2][3][i];
    assign h_1d_fsync_rsp_o[10][i] = h_1d_fsync_rsp[3][0][i];
    assign h_1d_fsync_rsp_o[11][i] = h_1d_fsync_rsp[3][1][i];
    assign h_1d_fsync_rsp_o[14][i] = h_1d_fsync_rsp[3][2][i];
    assign h_1d_fsync_rsp_o[15][i] = h_1d_fsync_rsp[3][3][i];

    // assign v_1d_fsync_req[i][j][k] = v_1d_fsync_req_i[2*(4*(i/2)+(i%2))+(4*(j/2)+(j%2))][k];
    assign v_1d_fsync_req[0][0][i] = v_1d_fsync_req_i[0][i];
    assign v_1d_fsync_req[0][1][i] = v_1d_fsync_req_i[1][i];
    assign v_1d_fsync_req[0][2][i] = v_1d_fsync_req_i[4][i];
    assign v_1d_fsync_req[0][3][i] = v_1d_fsync_req_i[5][i];
    assign v_1d_fsync_req[1][0][i] = v_1d_fsync_req_i[2][i];
    assign v_1d_fsync_req[1][1][i] = v_1d_fsync_req_i[3][i];
    assign v_1d_fsync_req[1][2][i] = v_1d_fsync_req_i[6][i];
    assign v_1d_fsync_req[1][3][i] = v_1d_fsync_req_i[7][i];
    assign v_1d_fsync_req[2][0][i] = v_1d_fsync_req_i[8][i];
    assign v_1d_fsync_req[2][1][i] = v_1d_fsync_req_i[9][i];
    assign v_1d_fsync_req[2][2][i] = v_1d_fsync_req_i[12][i];
    assign v_1d_fsync_req[2][3][i] = v_1d_fsync_req_i[13][i];
    assign v_1d_fsync_req[3][0][i] = v_1d_fsync_req_i[10][i];
    assign v_1d_fsync_req[3][1][i] = v_1d_fsync_req_i[11][i];
    assign v_1d_fsync_req[3][2][i] = v_1d_fsync_req_i[14][i];
    assign v_1d_fsync_req[3][3][i] = v_1d_fsync_req_i[15][i];

    // assign v_1d_fsync_rsp_o[2*(4*(i/2)+(i%2))+(4*(j/2)+(j%2))][k] = assign v_1d_fsync_rsp[i][j][k];
    assign v_1d_fsync_rsp_o[0][i]  = v_1d_fsync_rsp[0][0][i];
    assign v_1d_fsync_rsp_o[1][i]  = v_1d_fsync_rsp[0][1][i];
    assign v_1d_fsync_rsp_o[4][i]  = v_1d_fsync_rsp[0][2][i];
    assign v_1d_fsync_rsp_o[5][i]  = v_1d_fsync_rsp[0][3][i];
    assign v_1d_fsync_rsp_o[2][i]  = v_1d_fsync_rsp[1][0][i];
    assign v_1d_fsync_rsp_o[3][i]  = v_1d_fsync_rsp[1][1][i];
    assign v_1d_fsync_rsp_o[6][i]  = v_1d_fsync_rsp[1][2][i];
    assign v_1d_fsync_rsp_o[7][i]  = v_1d_fsync_rsp[1][3][i];
    assign v_1d_fsync_rsp_o[8][i]  = v_1d_fsync_rsp[2][0][i];
    assign v_1d_fsync_rsp_o[9][i]  = v_1d_fsync_rsp[2][1][i];
    assign v_1d_fsync_rsp_o[12][i] = v_1d_fsync_rsp[2][2][i];
    assign v_1d_fsync_rsp_o[13][i] = v_1d_fsync_rsp[2][3][i];
    assign v_1d_fsync_rsp_o[10][i] = v_1d_fsync_rsp[3][0][i];
    assign v_1d_fsync_rsp_o[11][i] = v_1d_fsync_rsp[3][1][i];
    assign v_1d_fsync_rsp_o[14][i] = v_1d_fsync_rsp[3][2][i];
    assign v_1d_fsync_rsp_o[15][i] = v_1d_fsync_rsp[3][3][i];
  end

  for (genvar i = 0; i < N_1D_H_ROOT_PORTS; i++) begin: gen_1d_h_root_fsync_net_req_rsp
    for (genvar j = 0; j < ROOT_N_LINKS_IN; j++) begin
      assign root_h_1d_fsync_req[i][j]    = leaf_h_2d_fsync_req[i][0][j];
      assign leaf_h_2d_fsync_rsp[i][0][j] = root_h_1d_fsync_rsp[i][j];
    end
  end

  for (genvar i = 0; i < N_1D_V_ROOT_PORTS; i++) begin: gen_1d_v_root_fsync_net_req_rsp
    for (genvar j = 0; j < ROOT_N_LINKS_IN; j++) begin
      assign root_v_1d_fsync_req[i][j]    = leaf_v_2d_fsync_req[i][0][j];
      assign leaf_v_2d_fsync_rsp[i][0][j] = root_v_1d_fsync_rsp[i][j];
    end
  end

  for (genvar i = 0; i < N_H_NBR_NODES; i++) begin: gen_h_nbr_req_rsp
    assign h_nbr_fsycn_req[i][0]    = h_nbr_fsycn_req_i[2*i];
    assign h_nbr_fsycn_req[i][1]    = h_nbr_fsycn_req_i[2*i+1];
    assign h_nbr_fsycn_rsp_o[2*i]   = h_nbr_fsycn_rsp[i][0];
    assign h_nbr_fsycn_rsp_o[2*i+1] = h_nbr_fsycn_rsp[i][1];
  end

  for (genvar i = 0; i < N_V_NBR_NODES; i++) begin: gen_v_nbr_req_rsp
    assign v_nbr_fsycn_req[i][0]    = v_nbr_fsycn_req_i[2*i];
    assign v_nbr_fsycn_req[i][1]    = v_nbr_fsycn_req_i[2*i+1];
    assign v_nbr_fsycn_rsp_o[2*i]   = v_nbr_fsycn_rsp[i][0];
    assign v_nbr_fsycn_rsp_o[2*i+1] = v_nbr_fsycn_rsp[i][1];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**      Leaf Synchronization Networks Beginning      **/
/*******************************************************/

  for (genvar i = 0; i < N_LEAF_FSYNC_NETWORKS; i++) begin: gen_leaf_fsync_net
    fractal_sync_2x2_core #(
      .TOP_NODE_TYPE     ( fractal_sync_pkg::HV_NODE ),
      .RF_TYPE_1D        ( LEAF_RF_TYPE_1D           ),
      .N_LOCAL_REGS_1D   ( LEAF_N_LOCAL_REGS_1D      ),
      .N_REMOTE_LINES_1D ( LEAF_N_REMOTE_LINES_1D    ),
      .RF_TYPE_2D        ( LEAF_RF_TYPE_2D           ),
      .N_LOCAL_REGS_2D   ( LEAF_N_LOCAL_REGS_2D      ),
      .N_REMOTE_LINES_2D ( LEAF_N_REMOTE_LINES_2D    ),
      .N_LINKS_IN        ( LEAF_N_LINKS_IN           ),
      .N_LINKS_ITL       ( LEAF_N_LINKS_ITL          ),
      .N_LINKS_OUT       ( LEAF_N_LINKS_OUT          ),
      .AGGREGATE_WIDTH   ( LEAF_AGGREGATE_WIDTH      ),
      .ID_WIDTH          ( LEAF_ID_WIDTH             ),
      .LVL_OFFSET        ( LEAF_LVL_OFFSET           ),
      .fsync_in_req_t    ( fsync_in_req_t            ),
      .fsync_out_req_t   ( fsync_itl_req_t           ),
      .fsync_rsp_t       ( fsync_rsp_t               ),
      .fsync_nbr_req_t   ( fsync_nbr_req_t           ),
      .fsync_nbr_rsp_t   ( fsync_nbr_req_t           )
    ) i_leaf_fsync_net (
      .clk_i                                       ,
      .rst_ni                                      ,
      .h_1d_fsync_req_i  ( h_1d_fsync_req[i]      ),
      .h_1d_fsync_rsp_o  ( h_1d_fsync_rsp[i]      ),
      .v_1d_fsync_req_i  ( v_1d_fsync_req[i]      ),
      .v_1d_fsync_rsp_o  ( v_1d_fsync_rsp[i]      ),
      .h_2d_fsync_req_o  ( leaf_h_2d_fsync_req[i] ),
      .h_2d_fsync_rsp_i  ( leaf_h_2d_fsync_rsp[i] ),
      .v_2d_fsync_req_o  ( leaf_v_2d_fsync_req[i] ),
      .v_2d_fsync_rsp_i  ( leaf_v_2d_fsync_rsp[i] )
    );
  end

/*******************************************************/
/**         Leaf Synchronization Networks End         **/
/*******************************************************/
/**      Root Synchronization Networks Beginning      **/
/*******************************************************/

  fractal_sync_2x2_core #(
    .TOP_NODE_TYPE     ( TOP_NODE_TYPE          ),
    .RF_TYPE_1D        ( ROOT_RF_TYPE_1D        ),
    .N_LOCAL_REGS_1D   ( ROOT_N_LOCAL_REGS_1D   ),
    .N_REMOTE_LINES_1D ( ROOT_N_REMOTE_LINES_1D ),
    .RF_TYPE_2D        ( ROOT_RF_TYPE_2D        ),
    .N_LOCAL_REGS_2D   ( ROOT_N_LOCAL_REGS_2D   ),
    .N_REMOTE_LINES_2D ( ROOT_N_REMOTE_LINES_2D ),
    .N_LINKS_IN        ( ROOT_N_LINKS_IN        ),
    .N_LINKS_ITL       ( ROOT_N_LINKS_ITL       ),
    .N_LINKS_OUT       ( ROOT_N_LINKS_OUT       ),
    .AGGREGATE_WIDTH   ( ROOT_AGGREGATE_WIDTH   ),
    .ID_WIDTH          ( ROOT_ID_WIDTH          ),
    .LVL_OFFSET        ( ROOT_LVL_OFFSET        ),
    .fsync_in_req_t    ( fsync_itl_req_t        ),
    .fsync_out_req_t   ( fsync_out_req_t        ),
    .fsync_rsp_t       ( fsync_rsp_t            ),
    .fsync_nbr_req_t   ( fsync_nbr_req_t        ),
    .fsync_nbr_rsp_t   ( fsync_nbr_rsp_t        )
  ) i_root_fsync_net (
    .clk_i                 ,
    .rst_ni                ,
    .h_1d_fsync_req_i  ( root_h_1d_fsync_req ),
    .h_1d_fsync_rsp_o  ( root_h_1d_fsync_rsp ),
    .v_1d_fsync_req_i  ( root_v_1d_fsync_req ),
    .v_1d_fsync_rsp_o  ( root_v_1d_fsync_rsp ),
    .h_2d_fsync_req_o  ( h_2d_fsync_req_o    ),
    .h_2d_fsync_rsp_i  ( h_2d_fsync_rsp_i    ),
    .v_2d_fsync_req_o  ( v_2d_fsync_req_o    ),
    .v_2d_fsync_rsp_i  ( v_2d_fsync_rsp_i    )
  );

/*******************************************************/
/**         Root Synchronization Networks End         **/
/*******************************************************/
/**    Neighbor Synchronization Networks Beginning    **/
/*******************************************************/

  for (genvar i = 0; i < N_H_NBR_NODES; i++) begin: gen_h_nbr_nodes
    fractal_sync_neighbor #(
      .fsync_req_t ( fsync_nbr_req_t      ),
      .fsync_rsp_t ( fsync_nbr_rsp_t      ),
      .COMB        ( /*DO NOT OVERWRITE*/ ) 
    ) i_h_nbr_node (
      .clk_i                        ,
      .rst_ni                       ,
      .req_i  ( h_nbr_fsycn_req[i] ),
      .rsp_o  ( h_nbr_fsycn_rsp[i] )
    );
  end

  for (genvar i = 0; i < N_V_NBR_NODES; i++) begin: gen_v_nbr_nodes
    fractal_sync_neighbor #(
      .fsync_req_t ( fsync_nbr_req_t      ),
      .fsync_rsp_t ( fsync_nbr_rsp_t      ),
      .COMB        ( /*DO NOT OVERWRITE*/ ) 
    ) i_v_nbr_node (
      .clk_i                        ,
      .rst_ni                       ,
      .req_i  ( v_nbr_fsycn_req[i] ),
      .rsp_o  ( v_nbr_fsycn_rsp[i] )
    );
  end

/*******************************************************/
/**       Neighbor Synchronization Networks End       **/
/*******************************************************/

endmodule: fractal_sync_4x4_core

module fractal_sync_4x4
  import fractal_sync_4x4_pkg::*;
#(
  parameter fractal_sync_pkg::node_e      TOP_NODE_TYPE                                            = fractal_sync_4x4_pkg::TOP_NODE_TYPE,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE_1D[fractal_sync_4x4_pkg::N_1D_ITL_LEVELS]        = fractal_sync_4x4_pkg::RF_TYPE_1D,
  parameter int unsigned                  N_LOCAL_REGS_1D[fractal_sync_4x4_pkg::N_1D_ITL_LEVELS]   = fractal_sync_4x4_pkg::N_LOCAL_REGS_1D,
  parameter int unsigned                  N_REMOTE_LINES_1D[fractal_sync_4x4_pkg::N_1D_ITL_LEVELS] = fractal_sync_4x4_pkg::N_REMOTE_LINES_1D,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE_2D[fractal_sync_4x4_pkg::N_2D_ITL_LEVELS]        = fractal_sync_4x4_pkg::RF_TYPE_2D,
  parameter int unsigned                  N_LOCAL_REGS_2D[fractal_sync_4x4_pkg::N_2D_ITL_LEVELS]   = fractal_sync_4x4_pkg::N_LOCAL_REGS_2D,
  parameter int unsigned                  N_REMOTE_LINES_2D[fractal_sync_4x4_pkg::N_2D_ITL_LEVELS] = fractal_sync_4x4_pkg::N_REMOTE_LINES_2D,
  parameter int unsigned                  N_LINKS_IN                                               = fractal_sync_4x4_pkg::N_LINKS_IN,
  parameter int unsigned                  N_LINKS_ITL[fractal_sync_4x4_pkg::N_ITL_LEVELS]          = fractal_sync_4x4_pkg::N_LINKS_ITL,
  parameter int unsigned                  N_LINKS_OUT                                              = fractal_sync_4x4_pkg::N_LINKS_OUT,
  parameter int unsigned                  AGGREGATE_WIDTH                                          = fractal_sync_4x4_pkg::IN_AGGR_WIDTH,
  parameter int unsigned                  ID_WIDTH                                                 = fractal_sync_4x4_pkg::ID_WIDTH,
  parameter int unsigned                  LVL_OFFSET                                               = fractal_sync_4x4_pkg::IN_LVL_OFFSET,
  parameter type                          fsync_in_req_t                                           = fractal_sync_4x4_pkg::fsync_in_req_t,
  parameter type                          fsync_out_req_t                                          = fractal_sync_4x4_pkg::fsync_out_req_t,
  parameter type                          fsync_rsp_t                                              = fractal_sync_4x4_pkg::fsync_rsp_t,
  parameter type                          fsync_nbr_req_t                                          = fractal_sync_4x4_pkg::fsync_nbr_req_t,
  parameter type                          fsync_nbr_rsp_t                                          = fractal_sync_4x4_pkg::fsync_nbr_rsp_t,
  localparam int unsigned                 N_1D_H_PORTS                                             = fractal_sync_4x4_pkg::N_1D_H_PORTS,
  localparam int unsigned                 N_1D_V_PORTS                                             = fractal_sync_4x4_pkg::N_1D_V_PORTS,
  localparam int unsigned                 N_NBR_H_PORTS                                            = fractal_sync_4x4_pkg::N_NBR_H_PORTS,
  localparam int unsigned                 N_NBR_V_PORTS                                            = fractal_sync_4x4_pkg::N_NBR_V_PORTS,
  localparam int unsigned                 N_ACTIVE_NBR_H_PORTS                                     = fractal_sync_4x4_pkg::N_ACTIVE_NBR_H_PORTS,
  localparam int unsigned                 N_ACTIVE_NBR_V_PORTS                                     = fractal_sync_4x4_pkg::N_ACTIVE_NBR_V_PORTS,
  localparam int unsigned                 N_2D_H_PORTS                                             = fractal_sync_4x4_pkg::N_2D_H_PORTS,
  localparam int unsigned                 N_2D_V_PORTS                                             = fractal_sync_4x4_pkg::N_2D_V_PORTS
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_in_req_t h_1d_fsync_req_i[N_1D_H_PORTS][N_LINKS_IN],
  output fsync_rsp_t    h_1d_fsync_rsp_o[N_1D_H_PORTS][N_LINKS_IN],
  input  fsync_in_req_t v_1d_fsync_req_i[N_1D_V_PORTS][N_LINKS_IN],
  output fsync_rsp_t    v_1d_fsync_rsp_o[N_1D_V_PORTS][N_LINKS_IN],

  input  fsync_nbr_req_t h_nbr_fsycn_req_i[N_NBR_H_PORTS],
  output fsync_nbr_rsp_t h_nbr_fsycn_rsp_o[N_NBR_H_PORTS],
  input  fsync_nbr_req_t v_nbr_fsycn_req_i[N_NBR_V_PORTS],
  output fsync_nbr_rsp_t v_nbr_fsycn_rsp_o[N_NBR_V_PORTS],

  output fsync_out_req_t h_2d_fsync_req_o[N_2D_H_PORTS][N_LINKS_OUT],
  input  fsync_rsp_t     h_2d_fsync_rsp_i[N_2D_H_PORTS][N_LINKS_OUT],
  output fsync_out_req_t v_2d_fsync_req_o[N_2D_V_PORTS][N_LINKS_OUT],
  input  fsync_rsp_t     v_2d_fsync_rsp_i[N_2D_V_PORTS][N_LINKS_OUT]
);

/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  fsync_nbr_req_t h_nbr_fsycn_req[N_ACTIVE_NBR_H_PORTS];
  fsync_nbr_rsp_t h_nbr_fsycn_rsp[N_ACTIVE_NBR_H_PORTS];
  fsync_nbr_req_t v_nbr_fsycn_req[N_ACTIVE_NBR_V_PORTS];
  fsync_nbr_rsp_t v_nbr_fsycn_rsp[N_ACTIVE_NBR_V_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  // Horizontal neighbor mapping: neighbor node i -> tile nodes [4*i+1, 4*i+2]
  // 0 -> [1,  2]
  // 1 -> [5,  6]
  // 2 -> [9,  10]
  // 3 -> [13, 14]
  assign h_nbr_fsycn_req[0] = h_nbr_fsycn_req_i[1];
  assign h_nbr_fsycn_req[1] = h_nbr_fsycn_req_i[2];
  assign h_nbr_fsycn_req[2] = h_nbr_fsycn_req_i[5];
  assign h_nbr_fsycn_req[3] = h_nbr_fsycn_req_i[6];
  assign h_nbr_fsycn_req[4] = h_nbr_fsycn_req_i[9];
  assign h_nbr_fsycn_req[5] = h_nbr_fsycn_req_i[10];
  assign h_nbr_fsycn_req[6] = h_nbr_fsycn_req_i[13];
  assign h_nbr_fsycn_req[7] = h_nbr_fsycn_req_i[14];

  assign h_nbr_fsycn_rsp_o[0].wake     = 1'b0;
  assign h_nbr_fsycn_rsp_o[0].sig.lvl  = '0;
  assign h_nbr_fsycn_rsp_o[0].sig.id   = '0;
  assign h_nbr_fsycn_rsp_o[0].error    = 1'b0;
  assign h_nbr_fsycn_rsp_o[1]          = h_nbr_fsycn_rsp[0];
  assign h_nbr_fsycn_rsp_o[2]          = h_nbr_fsycn_rsp[1];
  assign h_nbr_fsycn_rsp_o[3].wake     = 1'b0;
  assign h_nbr_fsycn_rsp_o[3].sig.lvl  = '0;
  assign h_nbr_fsycn_rsp_o[3].sig.id   = '0;
  assign h_nbr_fsycn_rsp_o[3].error    = 1'b0;
  assign h_nbr_fsycn_rsp_o[4].wake     = 1'b0;
  assign h_nbr_fsycn_rsp_o[4].sig.lvl  = '0;
  assign h_nbr_fsycn_rsp_o[4].sig.id   = '0;
  assign h_nbr_fsycn_rsp_o[4].error    = 1'b0;
  assign h_nbr_fsycn_rsp_o[5]          = h_nbr_fsycn_rsp[2];
  assign h_nbr_fsycn_rsp_o[6]          = h_nbr_fsycn_rsp[3];
  assign h_nbr_fsycn_rsp_o[7].wake     = 1'b0;
  assign h_nbr_fsycn_rsp_o[7].sig.lvl  = '0;
  assign h_nbr_fsycn_rsp_o[7].sig.id   = '0;
  assign h_nbr_fsycn_rsp_o[7].error    = 1'b0;
  assign h_nbr_fsycn_rsp_o[8].wake     = 1'b0;
  assign h_nbr_fsycn_rsp_o[8].sig.lvl  = '0;
  assign h_nbr_fsycn_rsp_o[8].sig.id   = '0;
  assign h_nbr_fsycn_rsp_o[8].error    = 1'b0;
  assign h_nbr_fsycn_rsp_o[9]          = h_nbr_fsycn_rsp[4];
  assign h_nbr_fsycn_rsp_o[10]         = h_nbr_fsycn_rsp[5];
  assign h_nbr_fsycn_rsp_o[11].wake    = 1'b0;
  assign h_nbr_fsycn_rsp_o[11].sig.lvl = '0;
  assign h_nbr_fsycn_rsp_o[11].sig.id  = '0;
  assign h_nbr_fsycn_rsp_o[11].error   = 1'b0;
  assign h_nbr_fsycn_rsp_o[12].wake    = 1'b0;
  assign h_nbr_fsycn_rsp_o[12].sig.lvl = '0;
  assign h_nbr_fsycn_rsp_o[12].sig.id  = '0;
  assign h_nbr_fsycn_rsp_o[12].error   = 1'b0;
  assign h_nbr_fsycn_rsp_o[13]         = h_nbr_fsycn_rsp[6];
  assign h_nbr_fsycn_rsp_o[14]         = h_nbr_fsycn_rsp[7];
  assign h_nbr_fsycn_rsp_o[15].wake    = 1'b0;
  assign h_nbr_fsycn_rsp_o[15].sig.lvl = '0;
  assign h_nbr_fsycn_rsp_o[15].sig.id  = '0;
  assign h_nbr_fsycn_rsp_o[15].error   = 1'b0;

  // Vertical neighbor mapping: neighbor node i -> tile nodes [4+i, 8+i]
  // 0 -> [4, 8]
  // 1 -> [5, 9]
  // 2 -> [6, 10]
  // 3 -> [7, 11]
  assign v_nbr_fsycn_req[0] = v_nbr_fsycn_req_i[4];
  assign v_nbr_fsycn_req[1] = v_nbr_fsycn_req_i[8];
  assign v_nbr_fsycn_req[2] = v_nbr_fsycn_req_i[5];
  assign v_nbr_fsycn_req[3] = v_nbr_fsycn_req_i[9];
  assign v_nbr_fsycn_req[4] = v_nbr_fsycn_req_i[6];
  assign v_nbr_fsycn_req[5] = v_nbr_fsycn_req_i[10];
  assign v_nbr_fsycn_req[6] = v_nbr_fsycn_req_i[7];
  assign v_nbr_fsycn_req[7] = v_nbr_fsycn_req_i[11];

  assign v_nbr_fsycn_rsp_o[0].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[0].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[0].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[0].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[1].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[1].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[1].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[1].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[2].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[2].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[2].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[2].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[3].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[3].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[3].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[3].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[4]         = v_nbr_fsycn_rsp[0];
  assign v_nbr_fsycn_rsp_o[8]         = v_nbr_fsycn_rsp[1];
  assign v_nbr_fsycn_rsp_o[5]         = v_nbr_fsycn_rsp[2];
  assign v_nbr_fsycn_rsp_o[9]         = v_nbr_fsycn_rsp[3];
  assign v_nbr_fsycn_rsp_o[6]         = v_nbr_fsycn_rsp[4];
  assign v_nbr_fsycn_rsp_o[10]        = v_nbr_fsycn_rsp[5];
  assign v_nbr_fsycn_rsp_o[7]         = v_nbr_fsycn_rsp[6];
  assign v_nbr_fsycn_rsp_o[11]        = v_nbr_fsycn_rsp[7];
  assign v_nbr_fsycn_rsp_o[12].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[12].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[12].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[12].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[13].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[13].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[13].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[13].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[14].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[14].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[14].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[14].error   = 1'b0;
  assign v_nbr_fsycn_rsp_o[15].wake    = 1'b0;
  assign v_nbr_fsycn_rsp_o[15].sig.lvl = '0;
  assign v_nbr_fsycn_rsp_o[15].sig.id  = '0;
  assign v_nbr_fsycn_rsp_o[15].error   = 1'b0;

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**         Synchronization Network Beginning         **/
/*******************************************************/

  fractal_sync_4x4_core i_fractal_sync_4x4 (
    .clk_i                                ,
    .rst_ni                               ,
    .h_1d_fsync_req_i                     ,
    .h_1d_fsync_rsp_o                     ,
    .v_1d_fsync_req_i                     ,
    .v_1d_fsync_rsp_o                     ,
    .h_nbr_fsycn_req_i ( h_nbr_fsycn_req ),
    .h_nbr_fsycn_rsp_o ( h_nbr_fsycn_rsp ),
    .v_nbr_fsycn_req_i ( v_nbr_fsycn_req ),
    .v_nbr_fsycn_rsp_o ( v_nbr_fsycn_rsp ),
    .h_2d_fsync_req_o                     ,
    .h_2d_fsync_rsp_i                     ,
    .v_2d_fsync_req_o                     ,
    .v_2d_fsync_rsp_i                     
  );

/*******************************************************/
/**            Synchronization Network End            **/
/*******************************************************/

endmodule: fractal_sync_4x4