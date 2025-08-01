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
 * Fractal synchronization 1D node
 * Asynchronous valid low reset
 *
 * Parameters:
 *  NODE_TYPE            - Node type of control core (horizontal, vertical, 2D, root)
 *  RF_TYPE              - Remote RF type (Directly Mapped or CAM)
 *  ARBITER_TYPE         - Arbiter type (Fully Associative or Directly Mapped wrap-around/alternating order)
 *  N_LOCAL_REGS         - Number of register in the local RF
 *  N_REMOTE_LINES       - Number of CAM lines in a CAM-based remote RF
 *  AGGREGATE_WIDTH      - Width of the aggr field
 *  ID_WIDTH             - Width of the id field
 *  LVL_OFFSET           - Level offset from first node of the syncrhonization tree: 0 for nodes at level 1, 1 for nodes at level 2, ...
 *  fsync_req_in_t       - Input synchronization request type (->RX)
 *  fsync_req_out_t      - Output synchronization request type (RX arb.->)
 *  fsync_rsp_t          - Input/output synchronization response type (TX arb.->; ->TX)
 *  FIFO_DEPTH           - Maximum number of elements that can be present in a FIFO
 *  RX_FIFO_COMB_OUT     - 1: Output RX FIFO with fall-through; 0: sequential RX FIFO
 *  TX_FIFO_COMB_OUT     - 1: Output TX FIFO with fall-through; 0: sequential TX FIFO
 *  LOCAL_FIFO_COMB_OUT  - 1: Output local FIFO with fall-through; 0: sequential local FIFO
 *  REMOTE_FIFO_COMB_OUT - 1: Output remote FIFO with fall-through; 0: sequential remote FIFO
 *  IN_PORTS             - Number of RX (input) ports
 *  OUT_PORTS            - Number of TX (output) ports
 *
 * Interface signals:
 *  > req_in_i  - Synchronization request (input)
 *  < rsp_in_o  - Synchronization response (output)
 *  < req_out_o - Synch. req. (output)
 *  > rsp_out_i - Synch. rsp. (input)
 */

module fractal_sync_1d 
  import fractal_sync_pkg::*;
#(
  parameter fractal_sync_pkg::node_e      NODE_TYPE            = fractal_sync_pkg::HOR_NODE,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE              = fractal_sync_pkg::CAM_RF,
  parameter fractal_sync_pkg::arb_e       ARBITER_TYPE         = fractal_sync_pkg::DM_ALT_ARB,
  parameter int unsigned                  N_LOCAL_REGS         = 0,
  parameter int unsigned                  N_REMOTE_LINES       = 0,
  parameter int unsigned                  AGGREGATE_WIDTH      = 1,
  parameter int unsigned                  ID_WIDTH             = 1,
  parameter int unsigned                  LVL_OFFSET           = 0,
  parameter type                          fsync_req_in_t       = logic,
  parameter type                          fsync_req_out_t      = logic,
  parameter type                          fsync_rsp_t          = logic,
  parameter int unsigned                  FIFO_DEPTH           = 1,
  parameter bit                           RX_FIFO_COMB_OUT     = 1'b1,
  parameter bit                           TX_FIFO_COMB_OUT     = 1'b1,
  parameter bit                           LOCAL_FIFO_COMB_OUT  = 1'b1,
  parameter bit                           REMOTE_FIFO_COMB_OUT = 1'b1,
  parameter int unsigned                  IN_PORTS             = 2,
  parameter int unsigned                  OUT_PORTS            = IN_PORTS/2
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_req_in_t  req_in_i[IN_PORTS],
  output fsync_rsp_t     rsp_in_o[IN_PORTS],
  output fsync_req_out_t req_out_o[OUT_PORTS],
  input  fsync_rsp_t     rsp_out_i[OUT_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_1D_NODE_TYPE: assert (NODE_TYPE == fractal_sync_pkg::HOR_NODE || NODE_TYPE == fractal_sync_pkg::VER_NODE) else $fatal("NODE_TYPE must be in {HOR_NODE, VER_NODE}");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned EN_IN_PORTS   = IN_PORTS/2;
  localparam int unsigned WS_IN_PORTS   = IN_PORTS/2;
  localparam int unsigned REQ_ARB_PORTS = IN_PORTS+IN_PORTS;
  localparam int unsigned RSP_ARB_PORTS = IN_PORTS+OUT_PORTS;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  fsync_req_in_t  sampled_req_in[IN_PORTS];
  logic           check_rx[IN_PORTS];
  logic           local_rx[IN_PORTS];
  logic           root_rx[IN_PORTS];
  logic           overflow_rx[IN_PORTS];
  
  logic           empty_rx[IN_PORTS];
  fsync_req_out_t req_rx[IN_PORTS];
  logic           pop_rx[IN_PORTS];

  logic           pop_req_arb[REQ_ARB_PORTS];
  logic           empty_req_arb[REQ_ARB_PORTS];
  fsync_req_out_t req_arb[REQ_ARB_PORTS];

  fsync_rsp_t sampled_rsp_out[OUT_PORTS];
  logic       check_tx[OUT_PORTS];
  logic       en_propagate_tx[OUT_PORTS];
  logic       ws_propagate_tx[OUT_PORTS];
  logic       en_overflow_tx[OUT_PORTS];
  logic       ws_overflow_tx[OUT_PORTS];
  logic       overflow_tx[OUT_PORTS];

  logic       en_empty_tx[OUT_PORTS];
  fsync_rsp_t en_rsp_tx[OUT_PORTS];
  logic       en_pop_tx[OUT_PORTS];
  logic       ws_empty_tx[OUT_PORTS];
  fsync_rsp_t ws_rsp_tx[OUT_PORTS];
  logic       ws_pop_tx[OUT_PORTS];

  logic       en_pop_rsp_arb[RSP_ARB_PORTS];
  logic       en_empty_rsp_arb[RSP_ARB_PORTS];
  fsync_rsp_t en_rsp_arb_in[RSP_ARB_PORTS];
  fsync_rsp_t en_rsp_arb_out[EN_IN_PORTS];
  logic       ws_pop_rsp_arb[RSP_ARB_PORTS];
  logic       ws_empty_rsp_arb[RSP_ARB_PORTS];
  fsync_rsp_t ws_rsp_arb_in[RSP_ARB_PORTS];
  fsync_rsp_t ws_rsp_arb_out[WS_IN_PORTS];

  logic           remote_empty[IN_PORTS];
  fsync_req_out_t remote_req[IN_PORTS];
  logic           remote_pop[IN_PORTS];

  logic       local_empty[IN_PORTS];
  fsync_rsp_t local_rsp[IN_PORTS];
  logic       local_pop[IN_PORTS];
  logic[1:0]  local_pop_q[IN_PORTS];
  logic[1:0]  local_pop_d[IN_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                    RX Beginning                   **/
/*******************************************************/

  for (genvar i = 0; i < IN_PORTS; i++) begin: gen_rx
    fractal_sync_rx #(
      .fsync_req_in_t  ( fsync_req_in_t       ),
      .fsync_req_out_t ( fsync_req_out_t      ),
      .COMB_IN         ( /*DO NOT OVERWRITE*/ ),
      .FIFO_DEPTH      ( FIFO_DEPTH           ),
      .FIFO_COMB_OUT   ( RX_FIFO_COMB_OUT     )
    ) i_rx (
      .clk_i                                  ,
      .rst_ni                                 ,
      .req_i             ( req_in_i[i]       ),
      .sampled_req_o     ( sampled_req_in[i] ),
      .check_propagate_o ( check_rx[i]       ),
      .local_o           ( local_rx[i]       ),
      .root_o            ( root_rx[i]        ),
      .error_overflow_o  ( overflow_rx[i]    ),
      .empty_o           ( empty_rx[i]       ),
      .req_o             ( req_rx[i]         ),
      .pop_i             ( pop_rx[i]         )
    );
  end

/*******************************************************/
/**                       RX End                      **/
/*******************************************************/
/**                RX Arbiter Beginning               **/
/*******************************************************/

  for (genvar i = 0; i < IN_PORTS; i++) begin
    assign pop_rx[i]                 = pop_req_arb[i+IN_PORTS];
    assign empty_req_arb[i+IN_PORTS] = empty_rx[i];
    assign req_arb[i+IN_PORTS]       = req_rx[i];
  end

  fractal_sync_arbiter #(
    .IN_PORTS     ( REQ_ARB_PORTS   ),
    .OUT_PORTS    ( OUT_PORTS       ),
    .arbiter_t    ( fsync_req_out_t ),
    .ARBITER_TYPE ( ARBITER_TYPE    )
  ) i_req_arb (
    .clk_i                      ,
    .rst_ni                     ,
    .pop_o     ( pop_req_arb   ),
    .empty_i   ( empty_req_arb ),
    .element_i ( req_arb       ),
    .element_o ( req_out_o     )
  );

/*******************************************************/
/**                   RX Arbiter End                  **/
/*******************************************************/
/**                    TX Beginning                   **/
/*******************************************************/

  for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_tx
    assign overflow_tx[i] = en_overflow_tx[i] | ws_overflow_tx[i];

    fractal_sync_tx #(
      .fsync_rsp_t   ( fsync_rsp_t          ),
      .COMB_IN       ( /*DO NOT OVERWRITE*/ ),
      .FIFO_DEPTH    ( FIFO_DEPTH           ),
      .FIFO_COMB_OUT ( TX_FIFO_COMB_OUT     )
    ) i_tx (
      .clk_i                                     ,
      .rst_ni                                    ,
      .rsp_i               ( rsp_out_i[i]       ),
      .sampled_rsp_o       ( sampled_rsp_out[i] ),
      .check_propagate_o   ( check_tx[i]        ),
      .en_propagate_i      ( en_propagate_tx[i] ),
      .ws_propagate_i      ( ws_propagate_tx[i] ),
      .en_error_overflow_o ( en_overflow_tx[i]  ),
      .ws_error_overflow_o ( ws_overflow_tx[i]  ),
      .en_empty_o          ( en_empty_tx[i]     ),
      .en_rsp_o            ( en_rsp_tx[i]       ),
      .en_pop_i            ( en_pop_tx[i]       ),
      .ws_empty_o          ( ws_empty_tx[i]     ),
      .ws_rsp_o            ( ws_rsp_tx[i]       ),
      .ws_pop_i            ( ws_pop_tx[i]       )
    );
  end

/*******************************************************/
/**                       TX End                      **/
/*******************************************************/
/**                TX Arbiter Beginning               **/
/*******************************************************/
  
  for (genvar i = 0; i < OUT_PORTS; i++) begin
    assign en_pop_tx[i]                 = en_pop_rsp_arb[i+IN_PORTS];
    assign en_empty_rsp_arb[i+IN_PORTS] = en_empty_tx[i];
    assign en_rsp_arb_in[i+IN_PORTS]    = en_rsp_tx[i];

    assign ws_pop_tx[i]                 = ws_pop_rsp_arb[i+IN_PORTS];
    assign ws_empty_rsp_arb[i+IN_PORTS] = ws_empty_tx[i];
    assign ws_rsp_arb_in[i+IN_PORTS]    = ws_rsp_tx[i];
  end

  for (genvar i = 0; i < IN_PORTS/2; i++) begin
    assign rsp_in_o[2*i]   = en_rsp_arb_out[i];
    assign rsp_in_o[2*i+1] = ws_rsp_arb_out[i];
  end

  fractal_sync_arbiter #(
    .IN_PORTS     ( RSP_ARB_PORTS ),
    .OUT_PORTS    ( EN_IN_PORTS   ),
    .arbiter_t    ( fsync_rsp_t   ),
    .ARBITER_TYPE ( ARBITER_TYPE  )
  ) i_en_rsp_arb (
    .clk_i                         ,
    .rst_ni                        ,
    .pop_o     ( en_pop_rsp_arb   ),
    .empty_i   ( en_empty_rsp_arb ),
    .element_i ( en_rsp_arb_in    ),
    .element_o ( en_rsp_arb_out   )
  );

  fractal_sync_arbiter #(
    .IN_PORTS     ( RSP_ARB_PORTS ),
    .OUT_PORTS    ( WS_IN_PORTS   ),
    .arbiter_t    ( fsync_rsp_t   ),
    .ARBITER_TYPE ( ARBITER_TYPE  )
  ) i_ws_rsp_arb (
    .clk_i                         ,
    .rst_ni                        ,
    .pop_o     ( ws_pop_rsp_arb   ),
    .empty_i   ( ws_empty_rsp_arb ),
    .element_i ( ws_rsp_arb_in    ),
    .element_o ( ws_rsp_arb_out   )
  );

/*******************************************************/
/**                   TX Arbiter End                  **/
/*******************************************************/
/**               Control Core Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < IN_PORTS; i++) begin
    assign remote_pop[i]    = pop_req_arb[i];
    assign empty_req_arb[i] = remote_empty[i];
    assign req_arb[i]       = remote_req[i];

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni)        local_pop_q[i] <= '0;
      else begin
        if (local_pop[i]) local_pop_q[i] <= '0;
        else              local_pop_q[i] <= local_pop_d[i];
      end
    end
    assign local_pop_d[i]      = local_pop_q[i] | {ws_pop_rsp_arb[i], en_pop_rsp_arb[i]};
    assign local_pop[i]        = &local_pop_d[i];
    assign en_empty_rsp_arb[i] = local_empty[i];
    assign en_rsp_arb_in[i]    = local_rsp[i];
    assign ws_empty_rsp_arb[i] = local_empty[i];
    assign ws_rsp_arb_in[i]    = local_rsp[i];
  end
  
  fractal_sync_cc #(
    .NODE_TYPE            ( NODE_TYPE            ),
    .RF_TYPE              ( RF_TYPE              ),
    .N_LOCAL_REGS         ( N_LOCAL_REGS         ),
    .N_REMOTE_LINES       ( N_REMOTE_LINES       ),
    .AGGREGATE_WIDTH      ( AGGREGATE_WIDTH      ),
    .ID_WIDTH             ( ID_WIDTH             ),
    .LVL_OFFSET           ( LVL_OFFSET           ),
    .fsync_req_in_t       ( fsync_req_in_t       ),
    .fsync_rsp_in_t       ( fsync_rsp_t          ),
    .fsync_req_out_t      ( fsync_req_out_t      ),
    .fsync_rsp_out_t      ( fsync_rsp_t          ),
    .N_RX_PORTS           ( IN_PORTS             ),
    .N_TX_PORTS           ( OUT_PORTS            ),
    .FIFO_DEPTH           ( FIFO_DEPTH           ),
    .LOCAL_FIFO_COMB_OUT  ( LOCAL_FIFO_COMB_OUT  ),
    .REMOTE_FIFO_COMB_OUT ( REMOTE_FIFO_COMB_OUT )
  ) i_cc (
    .clk_i                                  ,
    .rst_ni                                 ,
    .req_i               ( sampled_req_in  ),
    .check_rf_i          ( check_rx        ),
    .local_i             ( local_rx        ),
    .root_i              ( root_rx         ),
    .error_overflow_rx_i ( overflow_rx     ),
    .rsp_i               ( sampled_rsp_out ),
    .check_br_i          ( check_tx        ),
    .en_br_o             ( en_propagate_tx ),
    .ws_br_o             ( ws_propagate_tx ),
    .error_overflow_tx_i ( overflow_tx     ),
    .local_empty_o       ( local_empty     ),
    .local_rsp_o         ( local_rsp       ),
    .local_pop_i         ( local_pop       ),
    .remote_empty_o      ( remote_empty    ),
    .remote_req_o        ( remote_req      ),
    .remote_pop_i        ( remote_pop      ),
    .detected_error_o    (                 )
  );

/*******************************************************/
/**                  Control Core End                 **/
/*******************************************************/

endmodule: fractal_sync_1d