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
 *
 * Parameters:
 *  fsync_req_t - Synchronization request type (see include/typedef.svh for template)
 *  fsync_rsp_t - Synchronization response type (see include/typedef.svh for template)
 *  COMB        - Output obtained combinationally from input: creates single combinational path from input to output
 *
 * Interface signals:
 *  > req_i - Synchronization request
 *  < rsp_o - Synchronization response
 */

module fractal_sync_neighbor 
  import fractal_sync_pkg::*;
#(
  parameter type          fsync_req_t = logic,
  parameter type          fsync_rsp_t = logic,
  parameter bit           COMB        = 1'b0,
  localparam int unsigned N_PORTS     = 2
)(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  fsync_req_t req_i[N_PORTS],
  output fsync_rsp_t rsp_o[N_PORTS]
);

/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned NBR_ID_W = 2;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[N_PORTS-1:0]  sync_req;
  logic               clear_sync_req;
  logic[N_PORTS-1:0]  sync_present_d, sync_present_q;
  logic               wake;
  logic[NBR_ID_W-1:0] id_d, id_q, id;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Neighbor Node Logic Beginning           **/
/*******************************************************/

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_sync_req_rsp
    assign sync_req[i]      = req_i[i].sync;
    assign rsp_o[i].wake    = wake;
    assign rsp_o[i].sig.lvl = 1'b1;
    assign rsp_o[i].sig.id  = id;
    assign rsp_o[i].error   = 1'b0;
  end

  assign clear_sync_req = &sync_present_q;

  assign sync_present_d = sync_present_q | sync_req;
  // No id checking is done: it is assumed that both requests will have the same id (this should be enforced by the tile-FS interface module)
  assign id_d           = req_i[0].sig.id;

  always_ff @(posedge clk_i, negedge rst_ni) begin: presence_id_tracker
    if (!rst_ni)          begin sync_present_q <= '0;             id_q <= 0;    end
    else begin
      if (clear_sync_req) begin sync_present_q <= '0;             id_q <= 0;    end
      else                begin sync_present_q <= sync_present_d; id_q <= id_d; end
    end
  end
  
  if (COMB) begin: gen_comb_wake_id
    assign wake = &sync_present_d;
    assign id   = id_d;
  end else begin: gen_seq_wake
    assign wake = &sync_present_q;
    assign id   = id_q;
  end

/*******************************************************/
/**              Neighbor Node Logic End              **/
/*******************************************************/

endmodule: fractal_sync_neighbor