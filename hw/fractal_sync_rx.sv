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
 *  fsync_req_t   - Type of the synchronization request
 *  COMB_IN       - 1: Combinational datapath, 0: sample input
 *  FIFO_DEPTH    - Depth of the request FIFO
 *  FIFO_COMB_OUT - 1: Output FIFO with fall-through; 0: sequential FIFO
 *
 * Interface signals:
 *  > req_i             - Synchronization request
 *  < sampled_req_o     - Sampled synchronization request
 *  < check_propagate_o - Inticates to RF to keep track of synch. req.
 *  < local_o           - Indicates that synchronization request should be managed locally (root or aggregate)
 *  < root_o            - Indicates the root of the synchronization request
 *  < lock_o            - Indicates a request to lock the resource
 *  < free_o            - Indicates a request to free the resource
 *  > propagate_lock_i  - Indicates that the current lock/free request should be propagated to the next level of the tree
 *  < error_overflow_o  - Indicates error: fifo overflown
 *  < empty_o           - Indicates empty fifo
 *  < req_o             - Synchronization request propagated directly (without involvement of the register file)
 *  > pop_i             - Pop current synchronization request
 */

module fractal_sync_rx 
  import fractal_sync_pkg::*; 
#(
  parameter type         fsync_req_t   = logic,
  parameter bit          COMB_IN       = 1'b0,
  parameter int unsigned FIFO_DEPTH    = 1,
  parameter bit          FIFO_COMB_OUT = 1'b1
)(
  // Request interface - in
  input  logic       clk_i,
  input  logic       rst_ni,
  input  fsync_req_t req_i,
  output fsync_req_t sampled_req_o,
  // Control - Status
  output logic       check_propagate_o,
  output logic       local_o,
  output logic       root_o,
  output logic       lock_o,
  output logic       free_o,
  input  logic       propagate_lock_i,
  output logic       error_overflow_o,
  // FIFO interface - out
  output logic       empty_o,
  output fsync_req_t req_o,
  input  logic       pop_i
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_RX_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic barrier;
  logic lock;
  logic en_sample;
  logic sampled_sync;
  logic sampled_lock;
  logic sampled_free;
  logic propagate_barrier;
  logic push;

  logic full_fifo;

  fsync_req_out_t sampled_out_req;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  assign barrier           = req_i.sync;
  assign lock              = req_i.lock | req_i.free;
  assign en_sample         = barrier | lock;
  assign propagate_barrier = ~sampled_req_o.sig.aggr[0];

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 RX Logic Beginning                **/
/*******************************************************/
  
  if (COMB_IN) begin: gen_comb_sample
    assign sampled_sync  = req_i.sync;
    assign sampled_lock  = req_i.lock;
    assign sampled_free  = req_i.free;
    assign sampled_req_o = req_i;
  end else begin: gen_seq_sample
    always_ff @(posedge clk_i, negedge rst_ni) begin: sync_lock_reg
      if (!rst_ni) begin sampled_sync <= 1'b0;       sampled_lock <= 1'b0;       sampled_free <= 1'b0;       end
      else         begin sampled_sync <= req_i.sync; sampled_lock <= req_i.lock; sampled_free <= req_i.free; end
    end
    always_ff @(posedge clk_i, negedge rst_ni) begin: sample_reg
      if      (!rst_ni)   sampled_req_o <= '0;
      else if (en_sample) sampled_req_o <= req_i;
    end
  end

  assign sampled_out_req.sync     = sampled_req_o.sync;
  assign sampled_out_req.lock     = sampled_req_o.lock;
  assign sampled_out_req.free     = sampled_req_o.free;
  assign sampled_out_req.sig.aggr = sampled_req_o.sync ? sampled_req_o.sig.aggr >> 1 : sampled_req_o.sig.aggr;
  assign sampled_out_req.sig.id   = sampled_req_o.sig.id;

  assign push = (sampled_sync & propagate_barrier) | propagate_lock_i;

  assign check_propagate_o = sampled_sync;
  assign local_o           = check_propagate_o & ~propagate_barrier;
  assign root_o            = (sampled_req_o.sig.aggr == 1) ? 1'b1 : 1'b0;
  assign lock_o            = sampled_lock;
  assign free_o            = sampled_free;
  assign error_overflow_o  = full_fifo & push & ~pop_i;

/*******************************************************/
/**                    RX Logic End                   **/
/*******************************************************/
/**                 REQ FIFO Beginning                **/
/*******************************************************/

  fractal_sync_fifo #(
    .FIFO_DEPTH ( FIFO_DEPTH    ),
    .fifo_t     ( fsync_req_t   ),
    .COMB_OUT   ( FIFO_COMB_OUT )
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