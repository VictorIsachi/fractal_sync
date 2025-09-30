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
 * Fractal synchronization tx datapath
 * Asynchronous valid low reset
 *
 * Parameters:
 *  fsync_rsp_t   - Type of the synchronization response
 *  COMB_IN       - 1: Combinational datapath, 0: sample input
 *  FIFO_DEPTH    - Depth of the request FIFO
 *  FIFO_COMB_OUT - 1: Output FIFO with fall-through; 0: sequential FIFO
 *
 * Interface signals:
 *  > rsp_i             - Synchronization response
 *  < sampled_rsp_o     - Sampled synchronization response
 *  < check_propagate_o - Check remote RF to determine where to propagate synch. rsp.
 *  > propagate_i       - Indicates that the synch. rsp. should be propagated through channel
 *  < error_overflow_o  - Indicates error: fifo overflown
 *  < empty_o           - Indicates empty fifo
 *  < rsp_o             - Synchronization response
 *  > pop_i             - Pop current synchronization request
 */

module fractal_sync_tx 
  import fractal_sync_pkg::*; 
#(
  parameter type         fsync_rsp_t   = logic,
  parameter bit          COMB_IN       = 1'b0,
  parameter int unsigned FIFO_DEPTH    = 1,
  parameter bit          FIFO_COMB_OUT = 1'b1
)(
  // Response interface - in
  input  logic       clk_i,
  input  logic       rst_ni,
  input  fsync_rsp_t rsp_i,
  output fsync_rsp_t sampled_rsp_o,
  // Control - Status
  output logic       check_propagate_o,
  input  logic       en_propagate_i,
  input  logic       ws_propagate_i,
  output logic       en_error_overflow_o,
  output logic       ws_error_overflow_o,
  // FIFO interface - out
  output logic       en_empty_o,
  output fsync_rsp_t en_rsp_o,
  input  logic       en_pop_i,
  output logic       ws_empty_o,
  output fsync_rsp_t ws_rsp_o,
  input  logic       ws_pop_i
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

`ifndef SYNTHESIS
  initial FRACTAL_SYNC_TX_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");
`endif /* SYNTHESIS */

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic en_sample;
  logic sampled_wake;
  logic en_push;
  logic ws_push;

  logic en_full_fifo;
  logic ws_full_fifo;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  assign en_sample         = rsp_i.wake;
  assign check_propagate_o = sampled_wake;

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 TX Logic Beginning                **/
/*******************************************************/
  
  if (COMB_IN) begin: gen_comb_sample
    assign sampled_wake  = rsp_i.wake;
    assign sampled_rsp_o = rsp_i;
  end else begin: gen_seq_sample
    always_ff @(posedge clk_i, negedge rst_ni) begin: wake_reg
      if (!rst_ni) sampled_wake <= 1'b0;
      else         sampled_wake <= rsp_i.wake;
    end
    always_ff @(posedge clk_i, negedge rst_ni) begin: sample_reg
      if      (!rst_ni)   sampled_rsp_o <= '0;
      else if (en_sample) sampled_rsp_o <= rsp_i;
    end
  end

  assign en_push = sampled_wake & en_propagate_i;
  assign ws_push = sampled_wake & ws_propagate_i;
  
  assign en_error_overflow_o = en_full_fifo & en_push & ~en_pop_i;
  assign ws_error_overflow_o = ws_full_fifo & ws_push & ~ws_pop_i;

/*******************************************************/
/**                    TX Logic End                   **/
/*******************************************************/
/**                RSP FIFOs Beginning                **/
/*******************************************************/

  fractal_sync_fifo #(
    .FIFO_DEPTH ( FIFO_DEPTH    ),
    .fifo_t     ( fsync_rsp_t   ),
    .COMB_OUT   ( FIFO_COMB_OUT )
  ) i_rsp_en_fifo (
    .clk_i                      ,
    .rst_ni                     ,
    .push_i    ( en_push       ),
    .element_i ( sampled_rsp_o ),
    .pop_i     ( en_pop_i      ),
    .element_o ( en_rsp_o      ),
    .empty_o   ( en_empty_o    ),
    .full_o    ( en_full_fifo  )
  );
  
  fractal_sync_fifo #(
    .FIFO_DEPTH ( FIFO_DEPTH    ),
    .fifo_t     ( fsync_rsp_t   ),
    .COMB_OUT   ( FIFO_COMB_OUT )
  ) i_rsp_ws_fifo (
    .clk_i                      ,
    .rst_ni                     ,
    .push_i    ( ws_push       ),
    .element_i ( sampled_rsp_o ),
    .pop_i     ( ws_pop_i      ),
    .element_o ( ws_rsp_o      ),
    .empty_o   ( ws_empty_o    ),
    .full_o    ( ws_full_fifo  )
  );

/*******************************************************/
/**                   RSP FIFOs End                   **/
/*******************************************************/

endmodule: fractal_sync_tx