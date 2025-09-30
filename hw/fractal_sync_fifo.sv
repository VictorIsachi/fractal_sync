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
 * Fractal synchronization FIFO
 * Asynchronous valid low reset
 *
 * Parameters:
 *  FIFO_DEPTH - Maximum number of elements that can be present in the FIFO
 *  fifo_t     - FIFO element type
 *  COMB_OUT   - Combinational output based on input (fall-through)
 *
 * Interface signals:
 *  > push_i    - Push input element
 *  > element_i - Input element
 *  > pop_i     - Pop output element
 *  < element_o - Output element
 *  < empty_o   - Indicates empty FIFO (COMB_OUT => next output element will be determined combinationally, i.e. asynchronously)
 *  < full_o    - Indicates full FIFO
 */

module fractal_sync_fifo
  import fractal_sync_pkg::*;
#(
  parameter int unsigned FIFO_DEPTH = 1,
  parameter type         fifo_t     = logic,
  parameter bit          COMB_OUT   = 1
)(
  input  logic  clk_i,
  input  logic  rst_ni,

  input  logic  push_i,
  input  fifo_t element_i,
  input  logic  pop_i,
  output fifo_t element_o,
  output logic  empty_o,
  output logic  full_o 
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

`ifndef SYNTHESIS
  initial FRACTAL_SYNC_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");
`endif /* SYNTHESIS */

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned ADDR_WIDTH = $clog2(FIFO_DEPTH);
  localparam int unsigned PTR_WIDTH  = (ADDR_WIDTH == 0) ? 1 : ADDR_WIDTH-1;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[ADDR_WIDTH:0]  w_addr_c, w_addr_n;
  logic[ADDR_WIDTH:0]  r_addr_c, r_addr_n;
  logic                w_overlap;
  logic                r_overlap;
  logic[PTR_WIDTH-1:0] w_ptr;
  logic[PTR_WIDTH-1:0] r_ptr;

  fifo_t fifo[FIFO_DEPTH];

  logic empty_fifo;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  assign w_overlap = w_addr_c[ADDR_WIDTH];
  assign r_overlap = r_addr_c[ADDR_WIDTH];

  if (ADDR_WIDTH == 0) begin: gen_fixed_ptr
    assign w_ptr = 1'b0;
    assign r_ptr = 1'b0;
  end else begin: gen_ptr
    assign w_ptr = w_addr_c[ADDR_WIDTH-1:0];
    assign r_ptr = r_addr_c[ADDR_WIDTH-1:0];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                   FIFO Beginning                  **/
/*******************************************************/

  always_ff @(posedge clk_i, negedge rst_ni) begin: addr_state_logic
    if (!rst_ni) begin
      w_addr_c <= '0;
      r_addr_c <= '0;
    end else begin
      w_addr_c <= w_addr_n;
      r_addr_c <= r_addr_n;
    end
  end

  always_comb begin: next_addr_logic
    w_addr_n = w_addr_c;
    r_addr_n = r_addr_c;
    if (push_i) w_addr_n = w_addr_c + 1;
    if (pop_i)  r_addr_n = r_addr_c + 1;
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin: fifo_mem
    if      (!rst_ni) fifo        <= '{default: '0}; 
    else if (push_i)  fifo[w_ptr] <= element_i;
  end

  assign   full_o     = (r_overlap != w_overlap) && (r_ptr == w_ptr);
  assign   empty_fifo = (r_overlap == w_overlap) && (r_ptr == w_ptr);

  if (COMB_OUT) begin: gen_comb_empty
    assign empty_o    = empty_fifo & ~push_i;
  end else begin: gen_seq_empty
    assign empty_o    = empty_fifo;
  end

  if (COMB_OUT) begin: gen_comb_out
    assign element_o = (empty_fifo & push_i) ? element_i : fifo[r_ptr];
  end else begin: gen_seq_out
    assign element_o =                                     fifo[r_ptr];
  end

/*******************************************************/
/**                      FIFO End                     **/
/*******************************************************/

endmodule: fractal_sync_fifo