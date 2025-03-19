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
 *  fsync_rsp_in_t  - Type of the input response
 *  fsync_rsp_out_t - Type of the output response: dst width must be 2 less than input dst width
 *  COMB_IN         - 1: Combinational datapath, 0: sample input
 *  FIFO_DEPTH      - Depth of the request FIFO
 *
 * Interface signals:
 *  > rsp_i            - Synchronization response
 *  < error_overflow_o - Indicates error: fifo overflown
 *  < empty_o          - Indicates empty fifo
 *  < rsp_o            - Synchronization response
 *  > pop_i            - Pop current synchronization request
 *
 * WARRNING: Proper measures for error detection and handling must be implemented
 */

module fractal_sync_tx 
  import fractal_sync_pkg::*; 
#(
  parameter type          fsync_rsp_in_t  = logic,
  parameter type          fsync_rsp_out_t = logic,
  parameter bit           COMB_IN         = 1'b0,
  parameter int unsigned  FIFO_DEPTH      = 1,
  localparam int unsigned NUM_FIFOS       = 2
)(
  // Response interface - in
  input  logic           clk_i,
  input  logic           rst_ni,
  input  fsync_rsp_in_t  rsp_i,
  // Control - Status
  output logic           error_overflow_o[NUM_FIFOS],
  // FIFO interface - out
  output logic           empty_o[NUM_FIFOS],
  output fsync_rsp_out_t rsp_o[NUM_FIFOS],
  input  logic           pop_i[NUM_FIFOS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_TX_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");
  initial FRACTAL_SYNC_TX_DST: assert ($bits(rsp_i.dst) == $bits(rsp_o.dst)-2) else $fatal("Output destination width must be 2 bits less than input destination");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam bit FIFO_COMB_OUT = 1'b1;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic en_sample;

  logic full_fifo[NUM_FIFOS];

  fsync_rsp_in_t  sampled_rsp;
  fsycn_rsp_out_t sampled_out_rsp;
  fsync_rsp_out_t fifo_out_rsp[NUM_FIFOS];

  logic push_q[NUM_FIFOS];
  logic push_d[NUM_FIFOS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  assign en_sample = rsp_i.wake;

  assign sampled_out_rsp.wake  = sampled_rsp.wake;
  assign sampled_out_rsp.dst   = sampled_rsp.dst >> 2;
  assign sampled_out_rsp.error = sampled_rsp.error;

  for (genvar i = 0; i < NUM_FIFOS; i++) begin: gen_ovewflow
    assign error_overflow_o[i] = push_q[i] & full_fifo[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**            RSP/Push Sampling Beginning            **/
/*******************************************************/

  always_comb begin: push_logic
    push_d = '0;
    for (int unsigned i = 0; i < NUM_FIFOS; i++)
      if (rsp_i.dst[i] & rsp_i.wake)
        push_d[i] = 1'b1;
  end
  
  if (COMB_IN) begin: gen_comb_sample_push
    assign sampled_rsp = rsp_i;
    assign push_q      = push_d;
  end else begin: gen_seq_sample_push
    always_ff @(posedge clk_i, negedge rst_ni) begin: sample_reg
      if      (!rst_ni)   sampled_rsp <= '0;
      else if (en_sample) sampled_rsp <= rsp_i;
    end
    always_ff @(posedge clk_i, negedge rst_ni) begin: push_reg
      if (!rst_ni) push_q <= 1'b0;
      else         push_q <= push_d;
    end
  end

/*******************************************************/
/**               RSP/Push Sampling End               **/
/*******************************************************/
/**                RSP FIFOs Beginning                **/
/*******************************************************/

  for (genvar i = 0; i < NUM_FIFOS; i++) begin: gen_rsp_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH      ),
      .fifo_t     ( fsync_rsp_out_t ),
      .COMB_OUT   ( FIFO_COMB_OUT   )
    ) i_rsp_fifo (
      .clk_i                        ,
      .rst_ni                       ,
      .push_i    ( push_q[i]       ),
      .element_i ( sampled_out_rsp ),
      .pop_i     ( pop_i[i]        ),
      .element_o ( fifo_out_rsp[i] ),
      .empty_o   ( empty_o[i]      ),
      .full_o    ( full_fifo[i]    )
    );
    assign rsp_o[i] = fifo_out_rsp[i];
  end

/*******************************************************/
/**                   RSP FIFOs End                   **/
/*******************************************************/

endmodule: fractal_sync_tx