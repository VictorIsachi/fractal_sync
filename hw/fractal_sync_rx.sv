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
 *  fsync_req_out_t - Type of the output request: aggregate width must be 1 less than input aggregate width; sources width must be 2 more than input sources width
 *  COMB_IN         - 1: Combinational datapath, 0: sample input
 *  SD_MASK         - Mask that indicates the source of synchronization request: 01 -> Right; 10 -> Left; 11 -> Both
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

module fractal_sync_rx 
  import fractal_sync_pkg::*; 
#(
  parameter type                   fsync_req_in_t  = logic,
  parameter type                   fsync_req_out_t = logic,
  parameter bit                    COMB_IN         = 1'b0,
  parameter fractal_sync_pkg::sd_e SD_MASK         = fractal_sync_pkg::SD_BOTH,
  parameter int unsigned           FIFO_DEPTH      = 1
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
  output fsync_req_out_t req_o,
  input  logic           pop_i
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  `ASSERT_INIT(FRACTAL_SYNC_RX_FIFO_DEPTH, (FIFO_DEPTH > 0), "FIFO_DEPTH must be > 0")
  `ASSERT_INIT(FRACTAL_SYNC_RX_AGGR, ($bits(req_i.sig.aggr) == $bits(req_o.sig.aggr)-1), "Output aggregate width must be 1 bit less than input aggregate")
  `ASSERT_INIT(FRACTAL_SYNC_RX_SRC, ($bits(req_i.src) == $bits(req_o.src)+2), "Output sources width must be 2 bits more than input sources")

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
  assign propagate = ~sampled_req.aggr[0];
  assign enqueue   = sampled_req.sync & propagate;

  assign sampled_out_req.sync     = sampled_req.sync;
  assign sampled_out_req.sig.aggr = sampled_req.sig.aggr >> 1;
  assign sampled_out_req.dst      = {sampled_req.sig.dst, SD_MASK};
  assign sampled_out_req.sig.id   = sampled_req.sig.id;

  assign flush_fifo = 1'b0;
  assign test_fifo  = 1'b0;

  assign local_o          = ~enqueue;
  assign root_o           = (sampled_req.aggr == 1) ? 1'b1 : 1'b0;
  assign error_overflow_o = enqueue & full_fifo;

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**               REQ Sampling Beginning              **/
/*******************************************************/

  if (COMB_IN) begin: gen_comb_sample
    assign sampled_req = req_i;
  end else begin: gen_seq_sample
    always_ff @(posedge clk_i, negedge rst_ni) begin: sample_reg
      if      (!rst_ni)   sampled_req <= '0;
      else if (en_sample) sampled_req <= req_i;
    end
  end

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
  assign req_o = fifo_out_req;

/*******************************************************/
/**                    REQ FIFO End                   **/
/*******************************************************/

endmodule: fractal_sync_rx