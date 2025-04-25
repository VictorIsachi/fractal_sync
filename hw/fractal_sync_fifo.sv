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

  initial FRACTAL_SYNC_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned ADDR_WIDTH = $clog2(FIFO_DEPTH);

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[ADDR_WIDTH:0] w_addr_c, w_addr_n;
  logic[ADDR_WIDTH:0] r_addr_c, r_addr_n;

  fifo_t fifo[FIFO_DEPTH];

  logic empty_fifo;
  logic comb_out;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                   FIFO Beginning                  **/
/*******************************************************/

  if (COMB_OUT) begin: gen_comb
    assign comb_out = empty_fifo & push_i;
  end

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

  always_ff @(posedge clk_i)
    if (push_i) fifo[w_addr_c[ADDR_WIDTH-1:0]] <= element_i;

  if (!COMB_OUT) begin: gen_seq_out
    assign element_o =                        fifo[r_addr_c[ADDR_WIDTH-1:0]];
  end else begin: gen_comb_out
    assign element_o = comb_out ? element_i : fifo[r_addr_c[ADDR_WIDTH-1:0]];
  end

  assign   full_o     = (r_addr_c[ADDR_WIDTH] != w_addr_c[ADDR_WIDTH]) && (r_addr_c[ADDR_WIDTH-1:0] == w_addr_c[ADDR_WIDTH-1:0]);

  if (!COMB_OUT) begin: gen_seq_empty
    assign empty_o    = (r_addr_c[ADDR_WIDTH] == w_addr_c[ADDR_WIDTH]) && (r_addr_c[ADDR_WIDTH-1:0] == w_addr_c[ADDR_WIDTH-1:0]);
  end else begin: gen_comb_empty
    assign empty_fifo = (r_addr_c[ADDR_WIDTH] == w_addr_c[ADDR_WIDTH]) && (r_addr_c[ADDR_WIDTH-1:0] == w_addr_c[ADDR_WIDTH-1:0]);
    assign empty_o    = empty_fifo & ~comb_out;
  end

/*******************************************************/
/**                      FIFO End                     **/
/*******************************************************/

endmodule: fractal_sync_fifo