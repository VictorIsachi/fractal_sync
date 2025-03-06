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

  `ASSERT_INIT(FRACTAL_SYNC_TX_FIFO_DEPTH, (FIFO_DEPTH > 0), "FIFO_DEPTH must be > 0")
  `ASSERT_INIT(FRACTAL_SYNC_TX_LEVEL, ($bits(rsp_i.dst) == $bits(rsp_o.dst)-2), "Output destination width must be 2 bits less than input destination")

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

  logic flush_fifo;
  logic test_fifo;
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

  assign flush_fifo = 1'b0;
  assign test_fifo  = 1'b0;

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
  
  generate if (COMB_IN) begin: gen_comb_sample_push
    assign sampled_rsp = rsp_i;
    assign push_q      = push_d;
  end else begin: gen_seq_sample_push
    `FFL(sampled_rsp, rsp_i, en_sample, '0, clk_i, rst_ni)
    `FF(push_q, push_d, 1'b0, clk_i, rst_ni)
  end endgenerate

/*******************************************************/
/**               RSP/Push Sampling End               **/
/*******************************************************/
/**                RSP FIFOs Beginning                **/
/*******************************************************/

  for (genvar i = 0; i < NUM_FIFOS; i++) begin: gen_rsp_fifos
    fifo_v3 #(
      .FALL_THROUGH ( FALL_THROUGH    ),
      .DATA_WIDTH   ( /* Not Used */  ),
      .DEPTH        ( FIFO_DEPTH      ),
      .dtype        ( fsync_rsp_out_t )
    ) i_rsp_fifo (
      .clk_i                         ,
      .rst_ni                        ,
      .flush_i    ( flush_fifo      ),
      .testmode_i ( test_fifo       ),
      .full_o     ( full_fifo[i]    ),
      .empty_o    ( empty_o[i]      ),
      .usage_o    (                 ),
      .data_i     ( sampled_out_rsp ),
      .push_i     ( push_q[i]       ),
      .data_o     ( fifo_out_rsp[i] ),
      .pop_i      ( pop_i[i]        )
    );
    assign rsp_o[i] = fifo_out_rsp[i];
  end

/*******************************************************/
/**                   RSP FIFOs End                   **/
/*******************************************************/

endmodule: fractal_sync_tx