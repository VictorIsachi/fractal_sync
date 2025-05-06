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
 * Fractal synchronization 2D (H - horizontal; V - vertical) node
 * Asynchronous valid low reset
 *
 * Parameters:
 *  NODE_TYPE       - Node type of control core (horizontal, vertical, 2D, root)
 *  RF_TYPE         - Remote RF type (Directly Mapped or CAM)
 *  N_LOCAL_REGS    - Number of register in teh local RF
 *  N_REMOTE_LINES  - Number of CAM lines in a CAM-based remote RF
 *  AGGREGATE_WIDTH - Width of the aggr field
 *  ID_WIDTH        - Width of the id field
 *  fsync_req_in_t  - Input synchronization request type (->RX)
 *  fsync_rsp_in_t  - Input synchronization response type (TX arb.->)
 *  fsync_req_out_t - Output synchronization request type (RX arb.->)
 *  fsync_rsp_out_t - Output synchronization response type (->TX)
 *  FIFO_DEPTH      - Maximum number of elements that can be present in a FIFO
 *  IN_PORTS        - Number of RX (input) ports
 *  OUT_PORTS       - Number of TX (output) ports
 *
 * Interface signals:
 *  > req_in_i  - Synchronization request (input)
 *  > rsp_in_o  - Synchronization response (output)
 *  > req_out_o - Synch. req. (output)
 *  > rsp_out_i - Synch. rsp. (input)
 */

module fractal_sync_2d 
  import fractal_sync_pkg::*;
#(
  parameter fractal_sync_pkg::node_e      NODE_TYPE       = fractal_sync_pkg::HV_NODE,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE         = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  N_LOCAL_REGS    = 0,
  parameter int unsigned                  N_REMOTE_LINES  = 0,
  parameter int unsigned                  AGGREGATE_WIDTH = 1,
  parameter int unsigned                  ID_WIDTH        = 1,
  parameter type                          fsync_req_in_t  = logic,
  parameter type                          fsync_rsp_in_t  = logic,
  parameter type                          fsync_req_out_t = logic,
  parameter type                          fsync_rsp_out_t = logic,
  parameter int unsigned                  FIFO_DEPTH      = 1,
  parameter int unsigned                  IN_PORTS        = 4,
  localparam int unsigned                 IN_H_PORTS      = IN_PORTS/2,
  localparam int unsigned                 IN_V_PORTS      = IN_PORTS/2,
  parameter int unsigned                  OUT_PORTS       = IN_PORTS/2,
  localparam int unsigned                 OUT_H_PORTS     = OUT_PORTS/2,
  localparam int unsigned                 OUT_V_PORTS     = OUT_PORTS/2
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_req_in_t  h_req_in_i[IN_H_PORTS],
  output fsync_rsp_in_t  h_rsp_in_o[IN_H_PORTS],
  input  fsync_req_in_t  v_req_in_i[IN_V_PORTS],
  output fsync_rsp_in_t  v_rsp_in_o[IN_V_PORTS],
  output fsync_req_out_t h_req_out_o[OUT_H_PORTS],
  input  fsync_rsp_out_t h_rsp_out_i[OUT_H_PORTS],
  output fsync_req_out_t v_req_out_o[OUT_V_PORTS],
  input  fsync_rsp_out_t v_rsp_out_i[OUT_V_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_2D_NODE_TYPE: assert (NODE_TYPE == fractal_sync_pkg::HV_NODE || NODE_TYPE == fractal_sync_pkg::RT_NODE) else $fatal("NODE_TYPE must be in {HV_NODE, RT_NODE}");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned H_EN_IN_PORTS   = IN_H_PORTS/2;
  localparam int unsigned H_WS_IN_PORTS   = IN_H_PORTS/2;
  localparam int unsigned V_EN_IN_PORTS   = IN_V_PORTS/2;
  localparam int unsigned V_WS_IN_PORTS   = IN_V_PORTS/2;
  localparam int unsigned H_REQ_ARB_PORTS = IN_H_PORTS + IN_H_PORTS;
  localparam int unsigned V_REQ_ARB_PORTS = IN_V_PORTS + IN_V_PORTS;
  localparam int unsigned H_RSP_ARB_PORTS = IN_H_PORTS + OUT_H_PORTS;
  localparam int unsigned V_RSP_ARB_PORTS = IN_V_PORTS + OUT_V_PORTS;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  fsync_req_in_t  h_sampled_req_in[IN_H_PORTS];
  logic           h_local_rx[IN_H_PORTS];
  logic           h_root_rx[IN_H_PORTS];
  logic           h_overflow_rx[IN_H_PORTS];
  logic           h_empty_rx[IN_H_PORTS];
  fsync_req_out_t h_req_rx[IN_H_PORTS];
  logic           h_pop_rx[IN_H_PORTS];

  fsync_req_in_t  v_sampled_req_in[IN_V_PORTS];
  logic           v_local_rx[IN_V_PORTS];
  logic           v_root_rx[IN_V_PORTS];
  logic           v_overflow_rx[IN_V_PORTS];
  logic           v_empty_rx[IN_V_PORTS];
  fsync_req_out_t v_req_rx[IN_V_PORTS];
  logic           v_pop_rx[IN_V_PORTS];

  logic           h_pop_req_arb[H_REQ_ARB_PORTS];
  logic           h_empty_req_arb[H_REQ_ARB_PORTS];
  fsync_req_out_t h_req_arb[H_REQ_ARB_PORTS];

  logic           v_pop_req_arb[V_REQ_ARB_PORTS];
  logic           v_empty_req_arb[V_REQ_ARB_PORTS];
  fsync_req_out_t v_req_arb[V_REQ_ARB_PORTS];

  logic          h_en_overflow_tx[OUT_H_PORTS];
  logic          h_ws_overflow_tx[OUT_H_PORTS];
  logic          h_overflow_tx[OUT_H_PORTS];

  logic          h_en_empty_tx[OUT_H_PORTS];
  fsync_rsp_in_t h_en_rsp_tx[OUT_H_PORTS];
  logic          h_en_pop_tx[OUT_H_PORTS];
  logic          h_ws_empty_tx[OUT_H_PORTS];
  fsync_rsp_in_t h_ws_rsp_tx[OUT_H_PORTS];
  logic          h_ws_pop_tx[OUT_H_PORTS];

  logic          v_en_overflow_tx[OUT_V_PORTS];
  logic          v_ws_overflow_tx[OUT_V_PORTS];
  logic          v_overflow_tx[OUT_V_PORTS];

  logic          v_en_empty_tx[OUT_V_PORTS];
  fsync_rsp_in_t v_en_rsp_tx[OUT_V_PORTS];
  logic          v_en_pop_tx[OUT_V_PORTS];
  logic          v_ws_empty_tx[OUT_V_PORTS];
  fsync_rsp_in_t v_ws_rsp_tx[OUT_V_PORTS];
  logic          v_ws_pop_tx[OUT_V_PORTS];

  logic          h_en_pop_rsp_arb[H_RSP_ARB_PORTS];
  logic          h_en_empty_rsp_arb[H_RSP_ARB_PORTS];
  fsync_rsp_in_t h_en_rsp_arb_in[H_RSP_ARB_PORTS];
  fsync_rsp_in_t h_en_rsp_arb_out[H_RSP_ARB_PORTS];
  logic          h_ws_pop_rsp_arb[H_RSP_ARB_PORTS];
  logic          h_ws_empty_rsp_arb[H_RSP_ARB_PORTS];
  fsync_rsp_in_t h_ws_rsp_arb_in[H_RSP_ARB_PORTS];
  fsync_rsp_in_t h_ws_rsp_arb_out[H_RSP_ARB_PORTS];

  logic          v_en_pop_rsp_arb[V_RSP_ARB_PORTS];
  logic          v_en_empty_rsp_arb[V_RSP_ARB_PORTS];
  fsync_rsp_in_t v_en_rsp_arb_in[V_RSP_ARB_PORTS];
  fsync_rsp_in_t v_en_rsp_arb_out[V_RSP_ARB_PORTS];
  logic          v_ws_pop_rsp_arb[V_RSP_ARB_PORTS];
  logic          v_ws_empty_rsp_arb[V_RSP_ARB_PORTS];
  fsync_rsp_in_t v_ws_rsp_arb_in[V_RSP_ARB_PORTS];
  fsync_rsp_in_t v_ws_rsp_arb_out[V_RSP_ARB_PORTS];

  fsync_req_in_t sampled_req_in[IN_PORTS];
  
  logic           remote_empty[IN_PORTS];
  fsync_req_out_t remote_req[IN_PORTS];
  logic           remote_pop[IN_PORTS];

  logic          local_empty[IN_PORTS];
  fsync_rsp_in_t local_rsp[IN_PORTS];
  logic          local_pop[IN_PORTS];
  logic[1:0]     local_pop_q[IN_PORTS];
  logic[1:0]     local_pop_d[IN_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                    RX Beginning                   **/
/*******************************************************/

  for (genvar i = 0; i < IN_H_PORTS; i++) begin: gen_h_rx
    localparam fractal_sync_pkg::sd_e SD_MASK = (i % 2) ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EST_NORTH;
    
    fractal_sync_rx #(
      .fsync_req_in_t  ( fsync_req_in_t  ),
      .fsync_req_out_t ( fsync_req_out_t ),
      .COMB_IN         (                 ),
      .SD_MASK         ( SD_MASK         ),
      .FIFO_DEPTH      ( FIFO_DEPTH      )
    ) i_h_rx (
      .clk_i                                   ,
      .rst_ni                                  ,
      .req_i            ( h_req_in_i[i]       ),
      .sampled_req_o    ( h_sampled_req_in[i] ),
      .local_o          ( h_local_rx[i]       ),
      .root_o           ( h_root_rx[i]        ),
      .error_overflow_o ( h_overflow_rx[i]    ),
      .empty_o          ( h_empty_rx[i]       ),
      .req_o            ( h_req_rx[i]         ),
      .pop_i            ( h_pop_rx[i]         )
    );
  end

  for (genvar i = 0; i < IN_V_PORTS; i++) begin: gen_v_rx
    localparam fractal_sync_pkg::sd_e SD_MASK = (i % 2) ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EST_NORTH;
    
    fractal_sync_rx #(
      .fsync_req_in_t  ( fsync_req_in_t  ),
      .fsync_req_out_t ( fsync_req_out_t ),
      .COMB_IN         (                 ),
      .SD_MASK         ( SD_MASK         ),
      .FIFO_DEPTH      ( FIFO_DEPTH      )
    ) i_v_rx (
      .clk_i                                   ,
      .rst_ni                                  ,
      .req_i            ( v_req_in_i[i]       ),
      .sampled_req_o    ( v_sampled_req_in[i] ),
      .local_o          ( v_local_rx[i]       ),
      .root_o           ( v_root_rx[i]        ),
      .error_overflow_o ( v_overflow_rx[i]    ),
      .empty_o          ( v_empty_rx[i]       ),
      .req_o            ( v_req_rx[i]         ),
      .pop_i            ( v_pop_rx[i]         )
    );
  end
  
/*******************************************************/
/**                       RX End                      **/
/*******************************************************/
/**                RX Arbiter Beginning               **/
/*******************************************************/

  for (genvar i = 0; i < IN_H_PORTS; i++) begin
    assign h_pop_rx[i]                   = h_pop_req_arb[i+IN_H_PORTS];
    assign h_empty_req_arb[i+IN_H_PORTS] = h_empty_rx[i];
    assign h_req_arb[i+IN_H_PORTS]       = h_req_rx[i];
  end

  fractal_sync_arbiter #(
    .IN_PORTS  ( H_REQ_ARB_PORTS ),
    .OUT_PORTS ( OUT_H_PORTS     ),
    .arbiter_t ( fsync_req_out_t )
  ) i_h_rx_arb (
    .clk_i                        ,
    .rst_ni                       ,
    .pop_o     ( h_pop_req_arb   ),
    .empty_i   ( h_empty_req_arb ),
    .element_i ( h_req_arb       ),
    .element_o ( h_req_out_o     )
  );

  for (genvar i = 0; i < IN_V_PORTS; i++) begin
    assign v_pop_rx[i]                   = v_pop_req_arb[i+IN_V_PORTS];
    assign v_empty_req_arb[i+IN_V_PORTS] = v_empty_rx[i];
    assign v_req_arb[i+IN_V_PORTS]       = v_req_rx[i];
  end

  fractal_sync_arbiter #(
    .IN_PORTS  ( V_REQ_ARB_PORTS ),
    .OUT_PORTS ( OUT_V_PORTS     ),
    .arbiter_t ( fsync_req_out_t )
  ) i_v_rx_arb (
    .clk_i                        ,
    .rst_ni                       ,
    .pop_o     ( v_pop_req_arb   ),
    .empty_i   ( v_empty_req_arb ),
    .element_i ( v_req_arb       ),
    .element_o ( v_req_out_o     )
  );

/*******************************************************/
/**                   RX Arbiter End                  **/
/*******************************************************/
/**                    TX Beginning                   **/
/*******************************************************/

  for (genvar i = 0; i < OUT_H_PORTS; i++) begin: gen_h_tx
    assign h_overflow_tx[i] = h_en_overflow_tx[i] | h_ws_overflow_tx[i];
    
    fractal_sync_tx #(
      .fsync_rsp_in_t  ( fsync_rsp_out_t ),
      .fsync_rsp_out_t ( fsync_rsp_in_t  ),
      .COMB_IN         (                 ),
      .FIFO_DEPTH      ( FIFO_DEPTH      )
    ) i_h_tx (
      .clk_i                                      ,
      .rst_ni                                     ,
      .rsp_i               ( h_rsp_out_i[i]      ),
      .en_error_overflow_o ( h_en_overflow_tx[i] ),
      .ws_error_overflow_o ( h_ws_overflow_tx[i] ),
      .en_empty_o          ( h_en_empty_tx[i]    ),
      .en_rsp_o            ( h_en_rsp_tx[i]      ),
      .en_pop_i            ( h_en_pop_tx[i]      ),
      .ws_empty_o          ( h_ws_empty_tx[i]    ),
      .ws_rsp_o            ( h_ws_rsp_tx[i]      ),
      .ws_pop_i            ( h_ws_pop_tx[i]      )
    );
  end

  for (genvar i = 0; i < OUT_V_PORTS; i++) begin: gen_v_tx
    assign v_overflow_tx[i] = v_en_overflow_tx[i] | v_ws_overflow_tx[i];
    
    fractal_sync_tx #(
      .fsync_rsp_in_t  ( fsync_rsp_out_t ),
      .fsync_rsp_out_t ( fsync_rsp_in_t  ),
      .COMB_IN         (                 ),
      .FIFO_DEPTH      ( FIFO_DEPTH      )
    ) i_v_tx (
      .clk_i                                      ,
      .rst_ni                                     ,
      .rsp_i               ( v_rsp_out_i[i]      ),
      .en_error_overflow_o ( v_en_overflow_tx[i] ),
      .ws_error_overflow_o ( v_ws_overflow_tx[i] ),
      .en_empty_o          ( v_en_empty_tx[i]    ),
      .en_rsp_o            ( v_en_rsp_tx[i]      ),
      .en_pop_i            ( v_en_pop_tx[i]      ),
      .ws_empty_o          ( v_ws_empty_tx[i]    ),
      .ws_rsp_o            ( v_ws_rsp_tx[i]      ),
      .ws_pop_i            ( v_ws_pop_tx[i]      )
    );
  end

/*******************************************************/
/**                       TX End                      **/
/*******************************************************/
/**                TX Arbiter Beginning               **/
/*******************************************************/

  for (genvar i = 0; i < OUT_H_PORTS; i++) begin
    assign h_en_pop_tx[i]                   = h_en_pop_rsp_arb[i+IN_H_PORTS];
    assign h_en_empty_rsp_arb[i+IN_H_PORTS] = h_en_empty_tx[i];
    assign h_en_rsp_arb_in[i+IN_H_PORTS]    = h_en_rsp_tx[i];

    assign h_ws_pop_tx[i]                   = h_ws_pop_rsp_arb[i+IN_H_PORTS];
    assign h_ws_empty_rsp_arb[i+IN_H_PORTS] = h_ws_empty_tx[i];
    assign h_ws_rsp_arb_in[i+IN_H_PORTS]    = h_ws_rsp_tx[i];
  end

  for (genvar i = 0; i < IN_H_PORTS/2; i++) begin
    assign h_rsp_in_o[2*i]   = h_en_rsp_arb_out[i];
    assign h_rsp_in_o[2*i+1] = h_ws_rsp_arb_out[i];
  end

  fractal_sync_arbiter #(
    .IN_PORTS  ( H_RSP_ARB_PORTS ),
    .OUT_PORTS ( H_EN_IN_PORTS   ),
    .arbiter_t ( fsync_rsp_in_t  )
  ) i_h_en_tx_arb (
    .clk_i                           ,
    .rst_ni                          ,
    .pop_o     ( h_en_pop_rsp_arb   ),
    .empty_i   ( h_en_empty_rsp_arb ),
    .element_i ( h_en_rsp_arb_in    ),
    .element_o ( h_en_rsp_arb_out   )
  );

  fractal_sync_arbiter #(
    .IN_PORTS  ( H_RSP_ARB_PORTS ),
    .OUT_PORTS ( H_WS_IN_PORTS   ),
    .arbiter_t ( fsync_rsp_in_t  )
  ) i_h_ws_tx_arb (
    .clk_i                           ,
    .rst_ni                          ,
    .pop_o     ( h_ws_pop_rsp_arb   ),
    .empty_i   ( h_ws_empty_rsp_arb ),
    .element_i ( h_ws_rsp_arb_in    ),
    .element_o ( h_ws_rsp_arb_out   )
  );

  for (genvar i = 0; i < OUT_V_PORTS; i++) begin
    assign v_en_pop_tx[i]                   = v_en_pop_rsp_arb[i+IN_V_PORTS];
    assign v_en_empty_rsp_arb[i+IN_V_PORTS] = v_en_empty_tx[i];
    assign v_en_rsp_arb_in[i+IN_V_PORTS]    = v_en_rsp_tx[i];

    assign v_ws_pop_tx[i]                   = v_ws_pop_rsp_arb[i+IN_V_PORTS];
    assign v_ws_empty_rsp_arb[i+IN_V_PORTS] = v_ws_empty_tx[i];
    assign v_ws_rsp_arb_in[i+IN_V_PORTS]    = v_ws_rsp_tx[i];
  end

  for (genvar i = 0; i < IN_V_PORTS/2; i++) begin
    assign v_rsp_in_o[2*i]   = v_en_rsp_arb_out[i];
    assign v_rsp_in_o[2*i+1] = v_ws_rsp_arb_out[i];
  end

  fractal_sync_arbiter #(
    .IN_PORTS  ( V_RSP_ARB_PORTS ),
    .OUT_PORTS ( V_EN_IN_PORTS   ),
    .arbiter_t ( fsync_rsp_in_t  )
  ) i_v_en_tx_arb (
    .clk_i                           ,
    .rst_ni                          ,
    .pop_o     ( v_en_pop_rsp_arb   ),
    .empty_i   ( v_en_empty_rsp_arb ),
    .element_i ( v_en_rsp_arb_in    ),
    .element_o ( v_en_rsp_arb_out   )
  );

  fractal_sync_arbiter #(
    .IN_PORTS  ( V_RSP_ARB_PORTS ),
    .OUT_PORTS ( V_WS_IN_PORTS   ),
    .arbiter_t ( fsync_rsp_in_t  )
  ) i_v_ws_tx_arb (
    .clk_i                           ,
    .rst_ni                          ,
    .pop_o     ( v_ws_pop_rsp_arb   ),
    .empty_i   ( v_ws_empty_rsp_arb ),
    .element_i ( v_ws_rsp_arb_in    ),
    .element_o ( v_ws_rsp_arb_out   )
  );

/*******************************************************/
/**                   TX Arbiter End                  **/
/*******************************************************/
/**               Control Core Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < IN_H_PORTS; i++) begin
    assign sampled_req_in[2*i] = h_sampled_req_in[i];
    
    assign remote_pop[2*i]    = h_pop_req_arb[i];
    assign h_empty_req_arb[i] = remote_empty[2*i];
    assign h_req_arb[i]       = remote_req[2*i];

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni)          local_pop_q[2*i] <= '0;
      else begin
        if (local_pop[2*i]) local_pop_q[2*i] <= '0;
        else                local_pop_q[2*i] <= local_pop_d[2*i];
      end
    end
    assign local_pop_d[2*i]      = local_pop_q[2*i] | {h_ws_pop_rsp_arb[i], h_en_pop_rsp_arb[i]};
    assign local_pop[2*i]        = &local_pop_d[2*i];
    assign h_en_empty_rsp_arb[i] = local_empty[2*i];
    assign h_en_rsp_arb_in[i]    = local_rsp[2*i];
    assign h_ws_empty_rsp_arb[i] = local_empty[2*i];
    assign h_ws_rsp_arb_in[i]    = local_rsp[2*i];
  end

  for (genvar i = 0; i < IN_V_PORTS; i++) begin
    assign sampled_req_in[2*i+1] = v_sampled_req_in[i];
    
    assign remote_pop[2*i+1]  = v_pop_req_arb[i];
    assign v_empty_req_arb[i] = remote_empty[2*i+1];
    assign v_req_arb[i]       = remote_req[2*i+1];

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni)            local_pop_q[2*i+1] <= '0;
      else begin
        if (local_pop[2*i+1]) local_pop_q[2*i+1] <= '0;
        else                  local_pop_q[2*i+1] <= local_pop_d[2*i+1];
      end
    end
    assign local_pop_d[2*i+1]    = local_pop_q[2*i+1] | {v_ws_pop_rsp_arb[i], v_en_pop_rsp_arb[i]};
    assign local_pop[2*i+1]      = &local_pop_d[2*i+1];
    assign v_en_empty_rsp_arb[i] = local_empty[2*i+1];
    assign v_en_rsp_arb_in[i]    = local_rsp[2*i+1];
    assign v_ws_empty_rsp_arb[i] = local_empty[2*i+1];
    assign v_ws_rsp_arb_in[i]    = local_rsp[2*i+1];
  end
  
  fractal_sync_cc #(
    .NODE_TYPE       ( NODE_TYPE       ),
    .RF_TYPE         ( RF_TYPE         ),
    .N_LOCAL_REGS    ( N_LOCAL_REGS    ),
    .N_REMOTE_LINES  ( N_REMOTE_LINES  ),
    .AGGREGATE_WIDTH ( AGGREGATE_WIDTH ),
    .ID_WIDTH        ( ID_WIDTH        ),
    .fsync_req_in_t  ( fsync_req_in_t  ),
    .fsync_rsp_in_t  ( fsync_rsp_in_t  ),
    .fsync_req_out_t ( fsync_req_out_t ),
    .N_RX_PORTS      ( IN_PORTS        ),
    .N_TX_PORTS      ( OUT_PORTS       ),
    .FIFO_DEPTH      ( FIFO_DEPTH      )
  ) i_cc (
    .clk_i                               ,
    .rst_ni                              ,
    .req_i               ( req_in_i     ),
    .local_i             ( local_rx     ),
    .root_i              ( root_rx      ),
    .error_overflow_rx_i ( overflow_rx  ),
    .error_overflow_tx_i ( overflow_tx  ),
    .local_empty_o       ( local_empty  ),
    .local_rsp_o         ( local_rsp    ),
    .local_pop_i         ( local_pop    ),
    .remote_empty_o      ( remote_empty ),
    .remote_req_o        ( remote_req   ),
    .remote_pop_i        ( remote_pop   ),
    .detected_error_o    (              )
  );

/*******************************************************/
/**                  Control Core End                 **/
/*******************************************************/

endmodule: fractal_sync_2d