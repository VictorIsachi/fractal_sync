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
 */

module fractal_sync_1d 
  import fractal_sync_pkg::*;
#(
  parameter fractal_sync_pkg::node_e      NODE_TYPE       = fractal_sync_pkg::HOR_NODE,
  localparam fractal_sync_pkg::sd_e       SD_MASK         = (NODE_TYPE == fractal_sync_pkg::HOR_NODE) ? fractal_sync_pkg::SD_HOR :
                                                            (NODE_TYPE == fractal_sync_pkg::VER_NODE) ? fractal_sync_pkg::SD_VER :
                                                            fractal_sync_pkg::SD_BOTH,
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
  localparam int unsigned                 IN_PORTS        = 2,
  localparam int unsigned                 OUT_PORTS       = IN_PORTS/2,
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_req_in_t  req_in_i[IN_PORTS],
  output fsync_rsp_in_t  rsp_in_o[IN_PORTS],
  output fsync_req_out_t req_out_o[OUT_PORTS],
  input  fsync_rsp_out_t rsp_out_i[OUT_PORTS]
);

  initial FRACTAL_SYNC_1D_NODE_TYPE: assert (NODE_TYPE == fractal_sync_pkg::HOR_NODE || NODE_TYPE == fractal_sync_pkg::VER_NODE) else $fatal("NODE_TYPE must be in {HOR_NODE, VER_NODE}");

  localparam int unsigned ARB_PORTS   = 2*IN_PORTS;
  localparam int unsigned ARB_H_PORTS = ARB_PORTS/2;
  localparam int unsigned ARB_V_PORTS = ARB_PORTS/2;
  
  logic           local_rx[IN_PORTS];
  logic           root_rx[IN_PORTS];
  logic           overflow_rx[IN_PORTS];
  logic           empty_rx[IN_PORTS];
  fsync_req_out_t req_rx[IN_PORTS];
  logic           pop_rx[IN_PORTS];

  for (genvar i = 0; i < IN_PORTS; i++) begin: gen_rx
    fractal_sync_rx #(
      .fsync_req_in_t  ( fsync_req_in_t  ),
      .fsync_req_out_t ( fsync_req_out_t ),
      .COMB_IN         (                 ),
      .SD_MASK         ( SD_MASK         ),
      .FIFO_DEPTH      ( FIFO_DEPTH      )
    ) i_rx (
      .clk_i                              ,
      .rst_ni                             ,
      .req_i            ( req_in_i[i]    ),
      .local_o          ( local_rx[i]    ),
      .root_o           ( root_rx[i]     ),
      .error_overflow_o ( overflow_rx[i] ),
      .empty_o          ( empty_rx[i]    ),
      .req_o            ( req_rx[i]      ),
      .pop_i            ( pop_rx[i]      )
    );
  end

  logic           pop_arb_1d[ARB_PORTS];
  logic           empty_arb_1d[ARB_PORTS];
  fsync_req_out_t req_arb_1d[ARB_PORTS];

  for (genvar i = 0; i < IN_PORTS; i++) begin
    assign pop_rx[i]                = pop_arb_1d[i+IN_PORTS];
    assign empty_arb_1d[i+IN_PORTS] = empty_rx[i];
    assign req_arb_1d[i+IN_PORTS]   = req_rx[i];
  end

  fractal_sync_1d_arbiter #(
    .IN_PORTS  ( ARB_PORTS       ),
    .OUT_PORTS ( OUT_PORTS       ),
    .arbiter_t ( fsync_req_out_t )
  ) i_rx_arb (
    .clk_i                    ,
    .rst_ni                   ,
    .pop_o     ( pop_arb_1d   ),
    .empty_i   ( empty_arb_1d ),
    .element_i ( req_arb_1d   ),
    .element_o ( req_out_o    )
  );

  logic    h_overflow_tx[OUT_PORTS];
  logic    v_overflow_tx[OUT_PORTS];
  logic    overflow_tx[OUT_PORTS];
  logic    h_empty_tx[OUT_PORTS];
  logic    v_empty_tx[OUT_PORTS];
  rsp_in_o h_rsp_tx[OUT_PORTS];
  rsp_in_o v_rsp_tx[OUT_PORTS];
  logic    h_pop_tx[OUT_PORTS];
  logic    v_pop_tx[OUT_PORTS];

  for (genvar i = 0; i < OUT_PORTS; i++) begin
    assign overflow_tx[i] = h_overflow_tx[i] | v_overflow_tx[i];
  end

  for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_tx
    fractal_sync_tx #(
      .fsync_rsp_in_t  ( fsync_rsp_out_t ),
      .fsync_rsp_out_t ( fsync_rsp_in_t  ),
      .COMB_IN         (                 ),
      .FIFO_DEPTH      ( FIFO_DEPTH      )
    ) i_tx (
      .clk_i                                  ,
      .rst_ni                                 ,
      .rsp_i              ( rsp_out_i[i]     ),
      .h_error_overflow_o ( h_overflow_tx[i] ),
      .v_error_overflow_o ( v_overflow_tx[i] ),
      .h_empty_o          ( h_empty_tx[i]    ),
      .v_empty_o          ( v_empty_tx[i]    ),
      .h_rsp_o            ( h_rsp_tx[i]      ),
      .v_rsp_o            ( v_rsp_tx[i]      ),
      .h_pop_i            ( h_pop_tx[i]      ),
      .v_pop_i            ( v_pop_tx[i]      )
    );
  end

  logic pop_arb_2d[ARB_PORTS];

  fractal_sync_2d_arbiter #(
    .IN_1D_PORTS ( OUT_PORTS      ),
    .IN_2D_PORTS ( IN_PORTS       ),
    .OUT_PORTS   ( OUT_PORTS      ),
    .arbiter_t   ( fsync_rsp_in_t )
  ) i_tx_arb (
    .clk_i           ,
    .rst_ni          ,
    .h_pop_o     ( h_pop_tx ),
    .h_empty_i   ( h_empty_tx ),
    .h_element_i ( h_rsp_tx ),
    .v_pop_o     ( v_pop_tx ),
    .v_empty_i   ( v_empty_tx ),
    .v_element_i ( v_rsp_tx ),
    .pop_o       (  ),
    .empty_i     (  ),
    .element_i   (  ),
    .h_element_o (  ),
    .v_element_o (  )
  );

  fractal_sync_cc #(
    .NODE_TYPE       ( NODE_TYPE                 ),
    .RF_TYPE         ( RF_TYPE                   ),
    .N_LOCAL_REGS    ( N_LOCAL_REGS              ),
    .N_REMOTE_LINES  ( N_REMOTE_LINES            ),
    .AGGREGATE_WIDTH ( AGGREGATE_WIDTH           ),
    .ID_WIDTH        ( ID_WIDTH                  ),
    .fsync_req_in_t  ( fsync_req_in_t            ),
    .fsync_rsp_in_t  ( fsync_rsp_in_t            ),
    .fsync_req_out_t ( fsync_req_out_t           ),
    .SD_MASK         ( fractal_sync_pkg::SD_BOTH ),
    .FIFO_DEPTH_L    ( FIFO_DEPTH                ),
    .FIFO_DEPTH_R    ( FIFO_DEPTH                )
  ) i_cc (
    .clk_i               ,
    .rst_ni              ,
    .req_i               (  ),
    .local_i             (  ),
    .root_i              (  ),
    .error_overflow_rx_i (  ),
    .error_overflow_tx_i (  ),
    .local_empty_o       (  ),
    .local_rsp_o         (  ),
    .local_pop_i         (  ),
    .remote_empty_o      (  ),
    .remote_req_o        (  ),
    .remote_pop_i        (  ),
    .detected_error_o    (  )
  );

endmodule: fractal_sync_1d