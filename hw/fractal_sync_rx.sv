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
 * Fractal synchronization rx datapath
 * Asynchronous valid low reset
 *
 * Parameters:
 *  fsync_req_in_t  - Type of the input request
 *  fsync_req_out_t - Type of the output request: level width must be 1 less than input level width
 *  COMB_IN         - 1: Combinational datapath, 0: sample input
 *  MUX_OUT         - 1: two output ports muxed based on id, 0: single output port
 *  FIFO_DEPTH      - Depth of the request FIFO
 *
 * Interface signals:
 *  > req_i            - Synchronization request
 *  < local_o          - Indicates that we should wait locally for neighboring request
 *  < root_o           - Indicates the root of the synchronization request
 *  < error_overflow_o - Indicates error: fifo overflown
 *  < empty_o          - Indicates empty fifo
 *  < req_o            - Synchronization request
 *  > pop_i            - Pop current synchronization request
 *
 * WARRNING: Proper measures for error detection and handling must be implemented
 */

module fractal_sync_rx #(
  parameter type          fsync_req_in_t  = logic,
  parameter type          fsync_req_out_t = logic,
  parameter bit           COMB_IN         = 1'b0,
  parameter bit           MUX_OUT         = 1'b1,
  localparam int unsigned OUT_PORTS       = MUX_OUT ? 2 : 1,
  parameter int unsigned  FIFO_DEPTH      = 1
)(
  // Request interface - in
  input  logic           clk_i,
  input  logic           rst_ni,
  input  fsync_req_in_t  req_i,
  // Status
  output logic           local_o,
  output logic           root_o,
  output logic           error_overflow_o,
  // FIFO interface - out
  output logic           empty_o,
  output fsync_req_out_t req_o[OUT_PORTS],
  input logic            pop_i
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  `ASSERT_INIT(FRACTAL_SYNC_RX_FIFO_DEPTH, (FIFO_DEPTH > 0), "FIFO_DEPTH must be > 0")
  `ASSERT_INIT(FRACTAL_SYNC_RX_LEVEL, ($bits(req_i.mst_sig.level) == $bits(req_o.mst_sig.level)-1), "Output level must be 1 bit less than input level")

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam bit FALL_THROUGH = 1'b1;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic en_sample;
  logic propagate;
  logic enqueue;

  logic flush_fifo;
  logic test_fifo;
  logic full_fifo;

  fsync_req_in_t  sampled_req;
  fsycn_req_out_t sampled_out_req;
  fsync_req_out_t fifo_out_req;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  assign en_sample = req_i.sync;
  assign propagate = ~sampled_req.level[0];
  assign enqueue   = sampled_req.sync && propagate;

  assign sampled_out_req.sync          = sampled_req.sync
  assign sampled_out_req.mst_sig.level = sampled_req.mst_sig.level >> 1;
  assign sampled_out_req.mst_sig.id    = sampled_req.mst_sig.id

  assign flush_fifo = 1'b0;
  assign test_fifo  = 1'b0;

  assign local_o          = ~enqueue;
  assign root_o           = (sampled_req.level == 1) ? 1'b1 : 1'b0;
  assign error_overflow_o = enqueue & full_fifo;

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**               REQ Sampling Beginning              **/
/*******************************************************/

  generate if (COMB_IN) begin: gen_comb_sample
    assign sampled_req = req_i;
  end else begin: gen_seq_sample
    `FFL(sampled_req, req_i, en_sample, '0, clk_i, rst_ni)
  end endgenerate

/*******************************************************/
/**                  REQ Sampling End                 **/
/*******************************************************/
/**                 REQ FIFO Beginning                **/
/*******************************************************/

  fifo_v3 #(
    .FALL_THROUGH ( FALL_THROUGH    ),
    .DATA_WIDTH   ( /* Not Used */  ),
    .DEPTH        ( FIFO_DEPTH      ),
    .dtype        ( fsync_req_out_t )
  ) i_req_fifo (
    .clk_i                         ,
    .rst_ni                        ,
    .flush_i    ( flush_fifo      ),
    .testmode_i ( test_fifo       ),
    .full_o     ( full_fifo       ),
    .empty_o                       ,
    .usage_o    (                 ),
    .data_i     ( sampled_out_req ),
    .push_i     ( enqueue         ),
    .data_o     ( fifo_out_req    ),
    .pop_i      
  );

/*******************************************************/
/**                    REQ FIFO End                   **/
/*******************************************************/
/**                 REQ MUX Beginning                 **/
/*******************************************************/

  generate if (MUX_OUT) begin: gen_mux_out
    assign req_o[fifo_out_req.mst_sig.id[0]] = fifo_out_req;
  end else begin: gen_no_mux_out
    assign req_o[0] = fifo_out_req;
  end endgenerate

/*******************************************************/
/**                    REQ MUX End                    **/
/*******************************************************/

endmodule: fractal_sync_rx