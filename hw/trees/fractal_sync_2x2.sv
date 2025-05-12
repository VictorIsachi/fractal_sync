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
 * Fractal synchronization 2x2 network
 * Asynchronous valid low reset
 *
 * Parameters:
 *  TOP_NODE_TYPE     - Top node type (2D or root)
 *  RF_TYPE_1D        - Remote RF type (DM or CAM) of 1D nodes
 *  N_LOCAL_REGS_1D   - Local RF size of 1D nodes
 *  N_REMOTE_LINES_1D - Remote RF size of CAM-based 1D nodes
 *  N_LINKS_IN        - Number of input links of the 1D network links (CU/1D node)
 *  RF_TYPE_2D        - Remote RF type (DM or CAM) of 2D node
 *  N_LOCAL_REGS_2D   - Local RF size of 2D node
 *  N_REMOTE_LINES_2D - Remote RF size of CAM-based 2D node (will be ignored for root node)
 *  N_LINKS_ITL       - Number of output links of the 1D network links and input links of the 2D network links (1D node/2D node)
 *  N_LINKS_OUT       - Number of output links of the 2D network links (2D node/Out)
 *  AGGREGATE_WIDTH   - Width of the aggr field
 *  ID_WIDTH          - Width of the id field
 *  SD_WIDTH          - Width of he sources/destincations fields
 *  fsync_1d_req_t    - CU 1D (horizontal/vertical) synchronization request type (see hw/include/typedef.svh for a template)
 *  fsync_1d_rsp_t    - CU 1D (horizontal/vertical) synchronization response type (see hw/include/typedef.svh for a template)
 *  fsync_nbr_req_t   - CU neighbor synchronization request type (see hw/include/typedef.svh for a template)
 *  fsync_nbr_rsp_t   - CU neighbor synchronization response type (see hw/include/typedef.svh for a template)
 *  fsync_2d_req_t    - Top node output synchronization request type  (see hw/include/typedef.svh for a template)
 *  fsync_2d_rsp_t    - Top node output synchronization response type (see hw/include/typedef.svh for a template)
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

package fractal_sync_2x2_pkg;

  import fractal_sync_pkg::*;

  localparam fractal_sync_pkg::node_e      TOP_NODE_TYPE     = fractal_sync_pkg::HV_NODE;
  localparam fractal_sync_pkg::remote_rf_e RF_TYPE_1D        = fractal_sync_pkg::CAM_RF;
  localparam int unsigned                  N_LOCAL_REGS_1D   = 1;
  localparam int unsigned                  N_REMOTE_LINES_1D = 1;
  localparam int unsigned                  N_LINKS_IN        = 1;
  localparam fractal_sync_pkg::remote_rf_e RF_TYPE_2D        = fractal_sync_pkg::CAM_RF;
  localparam int unsigned                  N_LOCAL_REGS_2D   = 2;
  localparam int unsigned                  N_REMOTE_LINES_2D = 2;
  localparam int unsigned                  N_LINKS_ITL       = 1;
  localparam int unsigned                  N_LINKS_OUT       = 1;

  localparam int unsigned                  N_1D_H_PORTS      = 4;
  localparam int unsigned                  N_1D_V_PORTS      = 4;
  localparam int unsigned                  N_NBR_H_PORTS     = 4;
  localparam int unsigned                  N_NBR_V_PORTS     = 4;
  localparam int unsigned                  N_2D_H_PORTS      = 1;
  localparam int unsigned                  N_2D_V_PORTS      = 1;

  localparam int unsigned                  OUT_AGGR_WIDTH    = 1;
  
  localparam int unsigned                  AGGREGATE_WIDTH   = OUT_AGGR_WIDTH+2;
  localparam int unsigned                  ID_WIDTH          = 2;
  localparam int unsigned                  SD_WIDTH          = fractal_sync_pkg::SD_WIDTH;

  localparam int unsigned                  NBR_AGGR_WIDTH    = 1;
  localparam int unsigned                  NBR_ID_WIDTH      = 1;
  localparam int unsigned                  NBR_SD_WIDTH      = 1;
  
  localparam int unsigned                  OUT_ID_WIDTH      = ID_WIDTH;
  localparam int unsigned                  OUT_SD_WIDTH      = SD_WIDTH+4;

  `FSYNC_TYPEDEF_ALL(fsync_1d, logic[AGGREGATE_WIDTH-1:0], logic[ID_WIDTH-1:0], logic[SD_WIDTH-1:0], logic[SD_WIDTH-1:0])
  `FSYNC_TYPEDEF_ALL(fsync_nbr, logic[NBR_AGGR_WIDTH-1:0], logic[NBR_ID_WIDTH-1:0], logic[NBR_SD_WIDTH-1:0], logic[NBR_SD_WIDTH-1:0])
  `FSYNC_TYPEDEF_ALL(fsync_2d, logic[OUT_AGGR_WIDTH-1:0], logic[OUT_ID_WIDTH-1:0], logic[OUT_SD_WIDTH-1:0], logic[OUT_SD_WIDTH-1:0])

endpackage: fractal_sync_2x2_pkg

module fractal_sync_2x2 
  import fractal_sync_2x2_pkg::*;
#(
  parameter fractal_sync_pkg::node_e      TOP_NODE_TYPE     = fractal_sync_2x2_pkg::TOP_NODE_TYPE,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE_1D        = fractal_sync_2x2_pkg::RF_TYPE_1D,
  parameter int unsigned                  N_LOCAL_REGS_1D   = fractal_sync_2x2_pkg::N_LOCAL_REGS_1D,
  parameter int unsigned                  N_REMOTE_LINES_1D = fractal_sync_2x2_pkg::N_REMOTE_LINES_1D,
  parameter int unsigned                  N_LINKS_IN        = fractal_sync_2x2_pkg::N_LINKS_IN,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE_2D        = fractal_sync_2x2_pkg::RF_TYPE_2D,
  parameter int unsigned                  N_LOCAL_REGS_2D   = fractal_sync_2x2_pkg::N_LOCAL_REGS_2D,
  parameter int unsigned                  N_REMOTE_LINES_2D = fractal_sync_2x2_pkg::N_REMOTE_LINES_2D,
  parameter int unsigned                  N_LINKS_ITL       = fractal_sync_2x2_pkg::N_LINKS_ITL,
  parameter int unsigned                  N_LINKS_OUT       = fractal_sync_2x2_pkg::N_LINKS_OUT,
  parameter int unsigned                  AGGREGATE_WIDTH   = fractal_sync_2x2_pkg::AGGREGATE_WIDTH,
  parameter int unsigned                  ID_WIDTH          = fractal_sync_2x2_pkg::ID_WIDTH,
  parameter int unsigned                  SD_WIDTH          = fractal_sync_2x2_pkg::SD_WIDTH,
  parameter type                          fsync_1d_req_t    = fractal_sync_2x2_pkg::fsync_1d_req_t,
  parameter type                          fsync_1d_rsp_t    = fractal_sync_2x2_pkg::fsync_1d_rsp_t,
  parameter type                          fsync_nbr_req_t   = fractal_sync_2x2_pkg::fsync_nbr_req_t,
  parameter type                          fsync_nbr_rsp_t   = fractal_sync_2x2_pkg::fsync_nbr_rsp_t,
  parameter type                          fsync_2d_req_t    = fractal_sync_2x2_pkg::fsync_2d_req_t,
  parameter type                          fsync_2d_rsp_t    = fractal_sync_2x2_pkg::fsync_2d_rsp_t,
  localparam int unsigned                 N_1D_H_PORTS      = fractal_sync_2x2_pkg::N_1D_H_PORTS,
  localparam int unsigned                 N_1D_V_PORTS      = fractal_sync_2x2_pkg::N_1D_V_PORTS,
  localparam int unsigned                 N_NBR_H_PORTS     = fractal_sync_2x2_pkg::N_NBR_H_PORTS,
  localparam int unsigned                 N_NBR_V_PORTS     = fractal_sync_2x2_pkg::N_NBR_V_PORTS,
  localparam int unsigned                 N_2D_H_PORTS      = fractal_sync_2x2_pkg::N_2D_H_PORTS,
  localparam int unsigned                 N_2D_V_PORTS      = fractal_sync_2x2_pkg::N_2D_V_PORTS
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_1d_req_t  h_1d_fsync_req_i[N_1D_H_PORTS][N_LINKS_IN],
  output fsync_1d_rsp_t  h_1d_fsync_rsp_o[N_1D_H_PORTS][N_LINKS_IN],
  input  fsync_1d_req_t  v_1d_fsync_req_i[N_1D_V_PORTS][N_LINKS_IN],
  output fsync_1d_rsp_t  v_1d_fsync_rsp_o[N_1D_V_PORTS][N_LINKS_IN],

  input  fsync_nbr_req_t h_nbr_fsycn_req_i[N_NBR_H_PORTS],
  output fsync_nbr_rsp_t h_nbr_fsycn_rsp_o[N_NBR_H_PORTS],
  input  fsync_nbr_req_t v_nbr_fsycn_req_i[N_NBR_V_PORTS],
  output fsync_nbr_rsp_t v_nbr_fsycn_rsp_o[N_NBR_V_PORTS],

  output fsync_2d_req_t  h_2d_fsync_req_o[N_2D_H_PORTS][N_LINKS_OUT],
  input  fsync_2d_rsp_t  h_2d_fsync_rsp_i[N_2D_H_PORTS][N_LINKS_OUT],
  output fsync_2d_req_t  v_2d_fsync_req_o[N_2D_V_PORTS][N_LINKS_OUT],
  input  fsync_2d_rsp_t  v_2d_fsync_rsp_i[N_2D_V_PORTS][N_LINKS_OUT]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_2x2_TOP_NODE_TYPE: assert (TOP_NODE_TYPE == fractal_sync_pkg::HV_NODE || TOP_NODE_TYPE == fractal_sync_pkg::RT_NODE) else $fatal("TOP_NODE_TYPE must be in {HV_NODE, RT_NODE}");
  initial FRACTAL_SYNC_2x2_IN_LINKS: assert (N_LINKS_IN > 0) else $fatal("N_LINKS_IN must be > 0");
  initial FRACTAL_SYNC_2x2_ITL_LINKS: assert (N_LINKS_ITL > 0) else $fatal("N_LINKS_ITL must be > 0");
  initial FRACTAL_SYNC_2x2_OUT_LINKS: assert (N_LINKS_OUT > 0) else $fatal("N_LINKS_OUT must be > 0");
  initial FRACTAL_SYNC_2x2_AGGR_W: assert (AGGREGATE_WIDTH > 0) else $fatal("AGGREGATE_WIDTH must be > 0");
  initial FRACTAL_SYNC_2x2_ID_W: assert (ID_WIDTH >= 2) else $fatal("ID_WIDTH must be >= 2");
  initial FRACTAL_SYNC_2x2_SD_W: assert (SD_WIDTH >= 2) else $fatal("SD_WIDTH must be >= 2");
  initial FRACTAL_SYNC_2x2_SYNC_REQ_AGGR: assert ($bits(h_1d_fsync_req_i[0][0].sig.aggr) == $bits(h_2d_fsync_req_o[0][0].sig.aggr)+2) else $fatal("Output aggr must be 2 less than input");
  initial FRACTAL_SYNC_2x2_SYNC_REQ_SRC: assert ($bits(h_1d_fsync_req_i[0][0].src) == $bits(h_2d_fsync_req_o[0][0].src)-4) else $fatal("Output src must be 4 more than input");
  initial FRACTAL_SYNC_2x2_SYNC_RSP_DST: assert ($bits(h_1d_fsync_rsp_o[0][0].dst) == $bits(h_2d_fsync_rsp_i[0][0].dst)-4) else $fatal("Output dst must be 4 more than input");
  initial FRACTAL_SYNC_2x2_SYNC_AGGR: assert ($bits(h_1d_fsync_req_i[0][0].sig.aggr) == AGGREGATE_WIDTH) else $fatal("AGGREGATE_WIDTH must be coherent with fsync_req type");
  initial FRACTAL_SYNC_2x2_SYNC_ID: assert ($bits(h_1d_fsync_req_i[0][0].sig.id) == ID_WIDTH) else $fatal("ID_WIDTH must be coherent with fsync_req type");
  initial FRACTAL_SYNC_2x2_SYNC_SRC: assert ($bits(h_1d_fsync_req_i[0][0].src) == SD_WIDTH) else $fatal("SD_WIDTH must be coherent with fsync_req type");
  initial FRACTAL_SYNC_2x2_SYNC_DST: assert ($bits(h_1d_fsync_rsp_o[0][0].dst) == SD_WIDTH) else $fatal("SD_WIDTH must be coherent with fsync_rsp type");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned N_1D_H_NODES = N_1D_H_PORTS/2;
  localparam int unsigned N_1D_V_NODES = N_1D_V_PORTS/2;

  localparam int unsigned ITL_AGGR_WIDTH = AGGREGATE_WIDTH-1 > 0 ? AGGREGATE_WIDTH-1 : 1;
  localparam int unsigned ITL_ID_WIDTH   = ID_WIDTH;
  localparam int unsigned ITL_SD_WIDTH   = SD_WIDTH+2;

  `FSYNC_TYPEDEF_ALL(fsync_itl, logic[ITL_AGGR_WIDTH-1:0], logic[ITL_ID_WIDTH-1:0], logic[ITL_SD_WIDTH-1:0], logic[ITL_SD_WIDTH-1:0])

  localparam int unsigned FIFO_DEPTH_1D = N_LINKS_ITL/N_LINKS_IN;
  localparam int unsigned FIFO_DEPTH_2D = N_LINKS_OUT/N_LINKS_ITL;

  localparam int unsigned N_1D_NODE_IN_PORTS  = N_LINKS_IN*2;
  localparam int unsigned N_1D_NODE_OUT_PORTS = N_LINKS_ITL;

  localparam int unsigned N_2D_H_IN_PORTS    = N_1D_H_NODES*N_1D_NODE_OUT_PORTS;
  localparam int unsigned N_2D_V_IN_PORTS    = N_1D_V_NODES*N_1D_NODE_OUT_PORTS;
  localparam int unsigned N_2D_NODE_IN_PORTS = N_2D_H_IN_PORTS+N_2D_V_IN_PORTS;

  localparam int unsigned N_2D_H_OUT_PORTS    = N_2D_H_PORTS*N_LINKS_OUT;
  localparam int unsigned N_2D_V_OUT_PORTS    = N_2D_V_PORTS*N_LINKS_OUT;
  localparam int unsigned N_2D_NODE_OUT_PORTS = N_2D_H_OUT_PORTS+N_2D_V_OUT_PORTS;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  fsync_1d_req_t h_1d_fsync_req[N_1D_H_NODES][N_1D_NODE_IN_PORTS];
  fsync_1d_rsp_t h_1d_fsync_rsp[N_1D_H_NODES][N_1D_NODE_IN_PORTS];

  fsync_1d_req_t v_1d_fsync_req[N_1D_V_NODES][N_1D_NODE_IN_PORTS];
  fsync_1d_rsp_t v_1d_fsync_rsp[N_1D_V_NODES][N_1D_NODE_IN_PORTS];

  fsync_itl_req_t h_1d_itl_fsync_req[N_1D_H_NODES][N_1D_NODE_OUT_PORTS];
  fsync_itl_rsp_t h_1d_itl_fsync_rsp[N_1D_H_NODES][N_1D_NODE_OUT_PORTS];

  fsync_itl_req_t v_1d_itl_fsync_req[N_1D_V_NODES][N_1D_NODE_OUT_PORTS];
  fsync_itl_rsp_t v_1d_itl_fsync_rsp[N_1D_V_NODES][N_1D_NODE_OUT_PORTS];

  fsync_itl_req_t h_2d_itl_fsync_req[N_2D_H_IN_PORTS];
  fsync_itl_rsp_t h_2d_itl_fsync_rsp[N_2D_H_IN_PORTS];

  fsync_itl_req_t v_2d_itl_fsync_req[N_2D_V_IN_PORTS];
  fsync_itl_rsp_t v_2d_itl_fsync_rsp[N_2D_V_IN_PORTS];

  fsync_2d_req_t h_2d_fsync_req[N_2D_H_OUT_PORTS];
  fsync_2d_rsp_t h_2d_fsync_rsp[N_2D_H_OUT_PORTS];

  fsync_2d_req_t v_2d_fsync_req[N_2D_V_OUT_PORTS];
  fsync_2d_rsp_t v_2d_fsync_rsp[N_2D_V_OUT_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < N_NBR_H_PORTS; i++) begin: gen_h_nbr_rsp
    assign h_nbr_fsycn_rsp_o[i].wake  = 1'b0;
    assign h_nbr_fsycn_rsp_o[i].dst   = '0;
    assign h_nbr_fsycn_rsp_o[i].error = 1'b0;
  end

  for (genvar i = 0; i < N_NBR_H_PORTS; i++) begin: gen_v_nbr_rsp
    assign v_nbr_fsycn_rsp_o[i].wake  = 1'b0;
    assign v_nbr_fsycn_rsp_o[i].dst   = '0;
    assign v_nbr_fsycn_rsp_o[i].error = 1'b0;
  end

  for (genvar i = 0; i < N_1D_H_NODES; i++) begin: gen_h_1d_fsync_req_rsp
    for (genvar j = 0; j < N_LINKS_IN; j++) begin
      assign h_1d_fsync_req[i][2*j]     = h_1d_fsync_req_i[2*i][j];
      assign h_1d_fsync_req[i][2*j+1]   = h_1d_fsync_req_i[2*i+1][j];
      assign h_1d_fsync_rsp_o[2*i][j]   = h_1d_fsync_rsp[i][2*j];
      assign h_1d_fsync_rsp_o[2*i+1][j] = h_1d_fsync_rsp[i][2*j+1];
    end
  end

  for (genvar i = 0; i < N_1D_V_NODES; i++) begin: gen_v_1d_fsync_req_rsp
    for (genvar j = 0; j < N_LINKS_IN; j++) begin
      assign v_1d_fsync_req[i][2*j]     = v_1d_fsync_req_i[2*i][j];
      assign v_1d_fsync_req[i][2*j+1]   = v_1d_fsync_req_i[2*i+1][j];
      assign v_1d_fsync_rsp_o[2*i][j]   = v_1d_fsync_rsp[i][2*j];
      assign v_1d_fsync_rsp_o[2*i+1][j] = v_1d_fsync_rsp[i][2*j+1];
    end
  end

  for (genvar i = 0; i < N_1D_NODE_OUT_PORTS; i++) begin: gen_h_itl_fsync_req_rsp
    for (genvar j = 0; j < N_1D_H_NODES; j++) begin
      assign h_2d_itl_fsync_req[i*N_1D_H_NODES+j] = h_1d_itl_fsync_req[j][i];
      assign h_1d_itl_fsync_rsp[j][i]             = h_2d_itl_fsync_rsp[i*N_1D_H_NODES+j];
    end
  end

  for (genvar i = 0; i < N_1D_NODE_OUT_PORTS; i++) begin: gen_v_itl_fsync_req_rsp
    for (genvar j = 0; j < N_1D_V_NODES; j++) begin
      assign v_2d_itl_fsync_req[i*N_1D_V_NODES+j] = v_1d_itl_fsync_req[j][i];
      assign v_1d_itl_fsync_rsp[j][i]             = v_2d_itl_fsync_rsp[i*N_1D_V_NODES+j];
    end
  end

  for (genvar i = 0; i < N_2D_H_PORTS; i++) begin: gen_h_2d_fsync_req_rsp
    for (genvar j = 0; j < N_LINKS_OUT; j++) begin
      assign h_2d_fsync_req_o[i][j]          = h_2d_fsync_req[i*N_LINKS_OUT+j];
      assign h_2d_fsync_rsp[i*N_LINKS_OUT+j] = h_2d_fsync_rsp_i[i][j];
    end
  end

  for (genvar i = 0; i < N_2D_V_PORTS; i++) begin: gen_v_2d_fsync_req_rsp
    for (genvar j = 0; j < N_LINKS_OUT; j++) begin
      assign v_2d_fsync_req_o[i][j]          = v_2d_fsync_req[i*N_LINKS_OUT+j];
      assign v_2d_fsync_rsp[i*N_LINKS_OUT+j] = v_2d_fsync_rsp_i[i][j];
    end
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**           Horizontal 1D Nodes Beginning           **/
/*******************************************************/

  for (genvar i = 0; i < N_1D_H_NODES; i++) begin: gen_h_1d_nodes
    fractal_sync_1d #(
      .NODE_TYPE       ( fractal_sync_pkg::HOR_NODE ),
      .RF_TYPE         ( RF_TYPE_1D                 ),
      .N_LOCAL_REGS    ( N_LOCAL_REGS_1D            ),
      .N_REMOTE_LINES  ( N_REMOTE_LINES_1D          ),
      .AGGREGATE_WIDTH ( AGGREGATE_WIDTH            ),
      .ID_WIDTH        ( ID_WIDTH                   ),
      .fsync_req_in_t  ( fsync_1d_req_t             ),
      .fsync_rsp_in_t  ( fsync_1d_rsp_t             ),
      .fsync_req_out_t ( fsync_itl_req_t            ),
      .fsync_rsp_out_t ( fsync_itl_rsp_t            ),
      .FIFO_DEPTH      ( FIFO_DEPTH_1D              ),
      .IN_PORTS        ( N_1D_NODE_IN_PORTS         ),
      .OUT_PORTS       ( N_1D_NODE_OUT_PORTS        )
    ) i_h_1d_node (
      .clk_i                              ,
      .rst_ni                             ,
      .req_in_i  ( h_1d_fsync_req[i]     ),
      .rsp_in_o  ( h_1d_fsync_rsp[i]     ),
      .req_out_o ( h_1d_itl_fsync_req[i] ),
      .rsp_out_i ( h_1d_itl_fsync_rsp[i] )
    );
  end

/*******************************************************/
/**              Horizontal 1D Nodes End              **/
/*******************************************************/
/**            Vertical 1D Nodes Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < N_1D_V_NODES; i++) begin: gen_v_1d_nodes
    fractal_sync_1d #(
      .NODE_TYPE       ( fractal_sync_pkg::VER_NODE ),
      .RF_TYPE         ( RF_TYPE_1D                 ),
      .N_LOCAL_REGS    ( N_LOCAL_REGS_1D            ),
      .N_REMOTE_LINES  ( N_REMOTE_LINES_1D          ),
      .AGGREGATE_WIDTH ( AGGREGATE_WIDTH            ),
      .ID_WIDTH        ( ID_WIDTH                   ),
      .fsync_req_in_t  ( fsync_1d_req_t             ),
      .fsync_rsp_in_t  ( fsync_1d_rsp_t             ),
      .fsync_req_out_t ( fsync_itl_req_t            ),
      .fsync_rsp_out_t ( fsync_itl_rsp_t            ),
      .FIFO_DEPTH      ( FIFO_DEPTH_1D              ),
      .IN_PORTS        ( N_1D_NODE_IN_PORTS         ),
      .OUT_PORTS       ( N_1D_NODE_OUT_PORTS        )
    ) i_v_1d_node (
      .clk_i                              ,
      .rst_ni                             ,
      .req_in_i  ( v_1d_fsync_req[i]     ),
      .rsp_in_o  ( v_1d_fsync_rsp[i]     ),
      .req_out_o ( v_1d_itl_fsync_req[i] ),
      .rsp_out_i ( v_1d_itl_fsync_rsp[i] )
    );
  end

/*******************************************************/
/**               Vertical 1D Nodes End               **/
/*******************************************************/
/**              Top (2D) Node Beginning              **/
/*******************************************************/

  fractal_sync_2d #(
    .NODE_TYPE       ( TOP_NODE_TYPE       ),
    .RF_TYPE         ( RF_TYPE_2D          ),
    .N_LOCAL_REGS    ( N_LOCAL_REGS_2D     ),
    .N_REMOTE_LINES  ( N_REMOTE_LINES_2D   ),
    .AGGREGATE_WIDTH ( ITL_AGGR_WIDTH      ),
    .ID_WIDTH        ( ITL_ID_WIDTH        ),
    .fsync_req_in_t  ( fsync_itl_req_t     ),
    .fsync_rsp_in_t  ( fsync_itl_rsp_t     ),
    .fsync_req_out_t ( fsync_2d_req_t      ),
    .fsync_rsp_out_t ( fsync_2d_rsp_t      ),
    .FIFO_DEPTH      ( FIFO_DEPTH_2D       ),
    .IN_PORTS        ( N_2D_NODE_IN_PORTS  ),
    .OUT_PORTS       ( N_2D_NODE_OUT_PORTS )
  ) i_top_node (
    .clk_i                             ,
    .rst_ni                            ,
    .h_req_in_i  ( h_2d_itl_fsync_req ),
    .h_rsp_in_o  ( h_2d_itl_fsync_rsp ),
    .v_req_in_i  ( v_2d_itl_fsync_req ),
    .v_rsp_in_o  ( v_2d_itl_fsync_rsp ),
    .h_req_out_o ( h_2d_fsync_req     ),
    .h_rsp_out_i ( h_2d_fsync_rsp     ),
    .v_req_out_o ( v_2d_fsync_req     ),
    .v_rsp_out_i ( v_2d_fsync_rsp     )
  );

/*******************************************************/
/**                 Top (2D) Node End                 **/
/*******************************************************/

endmodule: fractal_sync_2x2