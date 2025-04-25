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
 */

module fractal_sync_tx 
  import fractal_sync_pkg::*; 
#(
  parameter type          fsync_rsp_in_t  = logic,
  parameter type          fsync_rsp_out_t = logic,
  parameter bit           COMB_IN         = 1'b0,
  parameter int unsigned  FIFO_DEPTH      = 1
)(
  // Response interface - in
  input  logic           clk_i,
  input  logic           rst_ni,
  input  fsync_rsp_in_t  rsp_i,
  // Control - Status
  output logic           en_error_overflow_o,
  output logic           ws_error_overflow_o,
  // FIFO interface - out
  output logic           en_empty_o,
  output fsync_rsp_out_t en_rsp_o,
  input  logic           en_pop_i,
  output logic           ws_empty_o,
  output fsync_rsp_out_t ws_rsp_o,
  input  logic           ws_pop_i
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_TX_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");
  initial FRACTAL_SYNC_TX_EN_DST: assert ($bits(rsp_i.dst) == $bits(en_rsp_o.dst)+2) else $fatal("Output Est-North destination width must be 2 bits less than input destination");
  initial FRACTAL_SYNC_TX_WS_DST: assert ($bits(rsp_i.dst) == $bits(ws_rsp_o.dst)+2) else $fatal("Output West-South destination width must be 2 bits less than input destination");

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

  logic en_full_fifo;
  logic ws_full_fifo;

  fsync_rsp_in_t  sampled_rsp;
  fsync_rsp_out_t sampled_out_rsp;
  fsync_rsp_out_t en_fifo_out_rsp;
  fsync_rsp_out_t ws_fifo_out_rsp;

  logic en_push_q;
  logic ws_push_q;
  logic en_push_d;
  logic ws_push_d;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/
  
  assign en_sample = rsp_i.wake;

  assign sampled_out_rsp.wake  = sampled_rsp.wake;
  assign sampled_out_rsp.dst   = sampled_rsp.dst >> 2;
  assign sampled_out_rsp.error = sampled_rsp.error;

  assign en_error_overflow_o = en_push_q & en_full_fifo;
  assign ws_error_overflow_o = ws_push_q & ws_full_fifo;

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**            RSP/Push Sampling Beginning            **/
/*******************************************************/

  assign en_push_d = rsp_i.dst[0] & rsp_i.wake;
  assign ws_push_d = rsp_i.dst[1] & rsp_i.wake;
  
  if (COMB_IN) begin: gen_comb_sample_push
    assign sampled_rsp = rsp_i;
    assign en_push_q   = en_push_d;
    assign ws_push_q   = ws_push_d;
  end else begin: gen_seq_sample_push
    always_ff @(posedge clk_i, negedge rst_ni) begin: sample_reg
      if      (!rst_ni)   sampled_rsp <= '0;
      else if (en_sample) sampled_rsp <= rsp_i;
    end
    always_ff @(posedge clk_i, negedge rst_ni) begin: push_reg
      if (!rst_ni) begin en_push_q <= 1'b0;      ws_push_q <= 1'b0;      end
      else         begin en_push_q <= en_push_d; ws_push_q <= ws_push_d; end
    end
  end

/*******************************************************/
/**               RSP/Push Sampling End               **/
/*******************************************************/
/**                RSP FIFOs Beginning                **/
/*******************************************************/

  fractal_sync_fifo #(
    .FIFO_DEPTH ( FIFO_DEPTH      ),
    .fifo_t     ( fsync_rsp_out_t ),
    .COMB_OUT   ( FIFO_COMB_OUT   )
  ) i_rsp_en_fifo (
    .clk_i                       ,
    .rst_ni                      ,
    .push_i    ( en_push_q       ),
    .element_i ( sampled_out_rsp ),
    .pop_i     ( en_pop_i        ),
    .element_o ( en_fifo_out_rsp ),
    .empty_o   ( en_empty_o      ),
    .full_o    ( en_full_fifo    )
  );
  assign en_rsp_o = en_fifo_out_rsp;
  
  fractal_sync_fifo #(
    .FIFO_DEPTH ( FIFO_DEPTH      ),
    .fifo_t     ( fsync_rsp_out_t ),
    .COMB_OUT   ( FIFO_COMB_OUT   )
  ) i_rsp_ws_fifo (
    .clk_i                        ,
    .rst_ni                       ,
    .push_i    ( ws_push_q       ),
    .element_i ( sampled_out_rsp ),
    .pop_i     ( ws_pop_i        ),
    .element_o ( ws_fifo_out_rsp ),
    .empty_o   ( ws_empty_o      ),
    .full_o    ( ws_full_fifo    )
  );
  assign ws_rsp_o = ws_fifo_out_rsp;

/*******************************************************/
/**                   RSP FIFOs End                   **/
/*******************************************************/

endmodule: fractal_sync_tx