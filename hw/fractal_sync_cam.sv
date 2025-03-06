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
 * Fractal synchronization CAM line
 * Asynchronous valid low reset
 */

module fractal_sync_cam_line
  import fractal_sync_pkg::*;
#(
  parameter int unsigned SIG_WIDTH  = 1,
  parameter int unsigned DATA_WIDTH = 1
)(
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  logic                 we_i,
  input  logic                 clear_i,
  input  logic                 cacc_i,
  input  logic[SIG_WIDTH-1:0]  sig_i,
  input  logic[DATA_WIDTH-1:0] data_i,
  output logic                 free_o,
  output logic                 present_o,
  output logic[DATA_WIDTH-1:0] data_o 
);

/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic full_line_d;
  logic full_line_q;

  logic[SIG_WIDTH-1:0] sig_d;
  logic[SIG_WIDTH-1:0] sig_q;
  logic[SIG_WIDTH-1:0] sig_bit_eql;
  logic                sig_eql;
  logic                present;

  logic                 wde;
  logic[DATA_WIDTH-1:0] data_d;
  logic[DATA_WIDTH-1:0] data_q;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                 CAM Line Beginning                **/
/*******************************************************/

  // full/free logic
  assign full_line_d = full_line_q | we_i;
  always_ff @(posedge clk_i, negedge rst_ni) begin: full_reg
    if (~rst_ni)      full_line_q <= 1'b0;
    else if (clear_i) full_line_q <= 1'b0;
    else              full_line_q <= full_line_d;
  end
  assign free_o = ~full_line_q;

  // signiture/present logic
  assign sig_d = sig_i;
  always_ff @(posedge clk_i, negedge rst_ni) begin: sig_regs
    if      (~rst_ni) sig_q <= '0;
    else if (we_i)    sig_q <= sig_d;
  end
  assign sig_bit_eql = sig_q ^ sig_i;
  assign sig_eql     = &sig_bit_eql;
  assign present     = sig_eql & full_line_q;
  assign present_o   = present;
  
  // data logic
  assign wde    = we_i | (cacc_i & present);
  assign data_d = (cacc_i & ~we_i) ? (data_i | data_q) : data_i;
  always_ff @(posedge clk_i, negedge rst_ni) begin: data_regs
    if      (~rst_ni) data_q <= '0;
    else if (wde)     data_q <= data_d;
  end
  assign data_o = data_q;

/*******************************************************/
/**                    CAM Line End                   **/
/*******************************************************/

endmodule: fractal_sync_cam_line

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
 * Fractal synchronization CAM
 * Asynchronous valid low reset
 */

module fractal_sync_cam
  import fractal_sync_pkg::*;
#(
  parameter int unsigned DATA_WIDTH = 1,
  parameter int unsigned SIG_WIDTH  = 1,
  parameter int unsigned NUM_LINES  = 1
)(
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  logic[NUM_LINES-1:0]  we_i,
  input  logic[NUM_LINES-1:0]  clear_i,
  input  logic                 cacc_i,
  input  logic[SIG_WIDTH-1:0]  sig_i,
  input  logic[DATA_WIDTH-1:0] data_i,
  output logic[NUM_LINES-1:0]  free_o,
  output logic                 present_o,
  output logic[DATA_WIDTH-1:0] data_o
);

/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned DATA_IDX_W = $clog2(NUM_LINES);

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[NUM_LINES-1:0] present_line;
  
  logic[DATA_WIDTH-1:0] data[NUM_LINES];
  logic[DATA_IDX_W-1:0] data_idx;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                   CAM Beginning                   **/
/*******************************************************/
  
  for (genvar i = 0; i < NUM_LINES; i++) begin: gen_cam_line
    cam_line #(
      .SIG_WIDTH  ( SIG_WIDTH  ),
      .DATA_WIDTH ( DATA_WIDTH )
    ) i_cam_line (
      .clk_i                        ,
      .rst_ni                       ,
      .we_i      ( we_i[i]         ),
      .clear_i   ( clear_i[i]      ),
      .cacc_i    ( cacc_i          ),
      .sig_i     ( sig_i           ),
      .data_i    ( data_i          ),
      .free_o    ( free_o[i]       ),
      .present_o ( present_line[i] ),
      .data_o    ( data[i]         )
    );
  end

  always_comb begin: data_idx_priority_enc
    data_idx = '0;
    for (int unsigned i = 0; i < NUM_LINES; i++) begin
      if (present_line[i]) begin
        data_idx = i;
        break;
      end
    end
  end

  assign present_o = |present_line;

  assign data_o = data[data_idx];

/*******************************************************/
/**                      CAM End                      **/
/*******************************************************/

endmodule: fractal_sync_cam
