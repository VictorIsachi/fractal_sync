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
 * Fractal synchronization neighbor node
 * Asynchronous valid low reset
 */

module fractal_sync_neighbor 
  import fractal_sync_pkg::*;
#(
  parameter type          fsync_req_t = logic,
  parameter type          fsync_rsp_t = logic,
  parameter bit           COMB        = 1'b0,
  localparam int unsigned N_PORTS     = 2,
)(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  fsync_req_t req_i[N_PORTS],
  output fsync_rsp_t rsp_o[N_PORTS]
);

  logic[N_PORTS-1:0] sync_req;
  logic              clear_sync_req;
  logic[N_PORTS-1:0] sync_present_d, sync_present_q;
  logic              wake;

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_sync_req_rsp
    assign sync_req[i]    = req_i[i].sync;
    assign rsp_o[i].wake  = wake;
    assign rsp_o[i].dst   = '0;
    assign rsp_o[i].error = 1'b0;
  end

  assign clear_sync_req = &sync_present_q;

  assign sync_present_d = sync_present_q | sync_req;

  always_ff @(posedge clk_i, negedge rst_ni) begin: presence_tracker
    if (!rst_ni)          sync_present_q <= '0;
    else begin
      if (clear_sync_req) sync_present_q <= '0;
      else                sync_present_q <= sync_present_d;
    end
  end
  
  if (COMB) begin: gen_comb_wake
    assign wake = &sync_present_d;
  end else begin: gen_seq_wake
    assign wake = &sync_present_q;
  end

endmodule: fractal_sync_neighbor