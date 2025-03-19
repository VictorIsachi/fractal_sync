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
 * Fractal synchronization multi-port CAM line
 * Asynchronous valid low reset
 */

module fractal_sync_mp_cam_line
  import fractal_sync_pkg::*;
#(
  parameter int unsigned  SIG_WIDTH    = 1,
  parameter int unsigned  N_PORTS      = 2,
  localparam int unsigned W_IDX_WIDTH  = $clog2(N_PORTS)
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic                  we_i,
  input  logic[W_IDX_WIDTH-1:0] w_idx_i,
  input  logic                  full_i,
  input  logic[SIG_WIDTH-1:0]   sig_i[N_PORTS],
  output logic                  free_o,
  output logic                  present_o[N_PORTS]
);

/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic full;

  logic[SIG_WIDTH-1:0] sig;
  logic[SIG_WIDTH-1:0] sig_bit_eql[N_PORTS];
  logic                sig_eql[N_PORTS];
  logic                present[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                 CAM Line Beginning                **/
/*******************************************************/

  always_ff @(posedge clk_i, negedge rst_ni) begin: full_reg
    if (!rst_ni) full <= 1'b0;
    else         full <= full_i;
  end
  assign free_o = ~full;
 
  always_ff @(posedge clk_i, negedge rst_ni) begin: sig_regs
    if      (!rst_ni) sig <= '0;
    else if (we_i)    sig <= sig_i[w_idx_i];
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_present_logic
    assign sig_bit_eql[i] = sig ^ sig_i[i];
    assign sig_eql[i]     = &sig_bit_eql[i];
    assign present[i]     = sig_eql[i] & full;
    assign present_o[i]   = present[i];
  end

/*******************************************************/
/**                    CAM Line End                   **/
/*******************************************************/

endmodule: fractal_sync_mp_cam_line

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
 * Fractal synchronization multi-port CAM
 * Asynchronous valid low reset
 */

module fractal_sync_mp_cam
  import fractal_sync_pkg::*;
#(
  parameter int unsigned SIG_WIDTH  = 1,
  parameter int unsigned N_PORTS    = 2,
  parameter int unsigned N_LINES    = 1
)(
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic[SIG_WIDTH-1:0] sig_i[N_PORTS],
  input  logic                sig_write_i[N_PORTS],
  output logic                present_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_MP_CAM: assert (N_LINES >= N_PORTS/2) else $fatal("N_LINES must be able >= N_PORTS/2");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned W_IDX_WIDTH = $clog2(N_PORTS);
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic[N_LINES-1:0] full_line;
  logic[N_LINES-1:0] free_line;
  logic[N_LINES-1:0] hit_line;

  logic[N_LINES-1:0]                  write_line;
  logic[N_LINES-1:0][W_IDX_WIDTH-1:0] write_line_idx;
  logic[N_LINES-1:0]                  write_line_free;

  logic                           present_line_unpack[N_LINES][N_PORTS];
  logic[N_LINES-1:0][N_PORTS-1:0] present_line;
  logic[N_PORTS-1:0]              present;
  logic[N_PORTS-1:0]              store;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                   CAM Beginning                   **/
/*******************************************************/
  
  for (genvar i = 0; i < N_LINES; i++) begin: gen_cam_line
    fractal_sync_mp_cam_line #(
      .SIG_WIDTH ( SIG_WIDTH ),
      .N_PORTS   ( N_PORTS   )
    ) i_fractal_sync_mp_cam_line (
      .clk_i                               ,
      .rst_ni                              ,
      .we_i      ( write_line[i]          ),
      .w_idx_i   ( write_line_idx[i]      ),
      .full_i    ( full_line[i]           ),
      .sig_i                               ,
      .free_o    ( free_line[i]           ),
      .present_o ( present_line_unpack[i] )
    );
  end
  always_comb begin: pack_present_line
    for (int unsigned i = 0; i < N_LINES; i++) begin
      for (int unsigned j = 0; j < N_PORTS; j++) begin
        present_line[i][j] = present_line_unpack[i][j];
      end
    end
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_present_store_logic
    always_comb begin
      present[i] = 1'b0;
      for (int unsigned j = 0; j < N_LINES; j++) begin
        if (present_line[j][i]) present[i] = 1'b1;
      end
      present_o[i] = present[i];
    end
    assign store[i] = ~present[i] & sig_write_i[i];
  end

  always_comb begin: write_logic
    write_line      = '0;
    write_line_idx  = '0;
    write_line_free = free_line;
    for (int unsigned i = 0; i < N_PORTS; i++) begin
      for (int unsigned j = 0; j < N_LINES; j++) begin
        if (store[i] & write_line_free[j]) begin
          write_line[j]      = 1'b1;
          write_line_idx[j]  = i;
          write_line_free[j] = 1'b0;
          break;
        end
      end
    end
  end

  for (genvar i = 0; i < N_LINES; i++) begin: gen_hit_full_logic
    assign hit_line[i]  = |present_line[i];
    assign full_line[i] = ~hit_line[i] & (~free_line[i] | write_line[i]);
  end

/*******************************************************/
/**                      CAM End                      **/
/*******************************************************/

endmodule: fractal_sync_mp_cam
