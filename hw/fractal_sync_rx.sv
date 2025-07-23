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
 *  FIFO_DEPTH      - Depth of the request FIFO
 *  FIFO_COMB_OUT   - 1: Output FIFO with fall-through; 0: sequential FIFO
 *
 * Interface signals:
 *  > req_i             - Synchronization request
 *  < sampled_req_o     - Sampled synchronization request
 *  < check_propagate_o - Inticates to RF to keep track of synch. req.
 *  < local_o           - Indicates that synchronization request should be managed locally (root or aggregate)
 *  < root_o            - Indicates the root of the synchronization request
 *  < error_overflow_o  - Indicates error: fifo overflown
 *  < empty_o           - Indicates empty fifo
 *  < req_o             - Synchronization request propagated directly (without involvement of the control-core)
 *  > pop_i             - Pop current synchronization request
 */

module fractal_sync_rx 
  import fractal_sync_pkg::*; 
#(
  parameter type         fsync_req_in_t  = logic,
  parameter type         fsync_req_out_t = logic,
  parameter bit          COMB_IN         = 1'b0,
  parameter int unsigned FIFO_DEPTH      = 1,
  parameter bit          FIFO_COMB_OUT   = 1'b1
)(
  // Request interface - in
  input  logic           clk_i,
  input  logic           rst_ni,
  input  fsync_req_in_t  req_i,
  output fsync_req_in_t  sampled_req_o,
  // Status
  output logic           check_propagate_o,
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

  initial FRACTAL_SYNC_RX_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");
  initial FRACTAL_SYNC_RX_AGGR: assert ($bits(req_i.sig.aggr) == $bits(req_o.sig.aggr)+1) else $fatal("Output aggregate width must be 1 bit less than input aggregate");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic en_sample;
  logic sampled_sync;
  logic propagate;
  logic push;

  logic full_fifo;

  fsync_req_out_t sampled_out_req;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  assign en_sample = req_i.sync;
  assign propagate = ~sampled_req_o.sig.aggr[0];

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 RX Logic Beginning                **/
/*******************************************************/
  
  if (COMB_IN) begin: gen_comb_sample
    assign sampled_sync  = req_i.sync;
    assign sampled_req_o = req_i;
  end else begin: gen_seq_sample
    always_ff @(posedge clk_i, negedge rst_ni) begin: sync_reg
      if (!rst_ni) sampled_sync <= 1'b0;
      else         sampled_sync <= req_i.sync;
    end
    always_ff @(posedge clk_i, negedge rst_ni) begin: sample_reg
      if      (!rst_ni)   sampled_req_o <= '0;
      else if (en_sample) sampled_req_o <= req_i;
    end
  end

  assign sampled_out_req.sync     = sampled_req_o.sync;
  assign sampled_out_req.sig.aggr = sampled_req_o.sig.aggr >> 1;
  assign sampled_out_req.sig.id   = sampled_req_o.sig.id;

  assign push = sampled_sync & propagate;

  assign check_propagate_o = sampled_sync;
  assign local_o           = check_propagate_o & ~propagate;
  assign root_o            = (sampled_req_o.sig.aggr == 1) ? 1'b1 : 1'b0;
  assign error_overflow_o  = full_fifo & push & ~pop_i;

/*******************************************************/
/**                    RX Logic End                   **/
/*******************************************************/
/**                 REQ FIFO Beginning                **/
/*******************************************************/

  fractal_sync_fifo #(
    .FIFO_DEPTH ( FIFO_DEPTH      ),
    .fifo_t     ( fsync_req_out_t ),
    .COMB_OUT   ( FIFO_COMB_OUT   )
  ) i_req_fifo (
    .clk_i                        ,
    .rst_ni                       ,
    .push_i    ( push            ),
    .element_i ( sampled_out_req ),
    .pop_i                        ,
    .element_o ( req_o           ),
    .empty_o                      ,
    .full_o    ( full_fifo       )
  );

/*******************************************************/
/**                    REQ FIFO End                   **/
/*******************************************************/

endmodule: fractal_sync_rx
