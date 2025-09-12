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
  logic[N_PORTS-1:0]  lock_req;
  logic[N_PORTS-1:0]  free_req;
  logic[N_PORTS-1:0]  sample_id;
  logic[N_PORTS-1:0]  sync_present_d, sync_present_q;
  logic[N_PORTS-1:0]  lock_present_d, lock_present_q;
  logic               clear_sync_present;
  logic               clear_lock_present;
  logic               clear_id;
  logic               wake;
  logic               single_grant;
  logic[N_PORTS-1:0]  grant;
  logic[NBR_ID_W-1:0] id_d[N_PORTS];
  logic[NBR_ID_W-1:0] id_q[N_PORTS];
  logic[NBR_ID_W-1:0] id[N_PORTS];
  logic               same_id;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**           Neighbor Node Logic Beginning           **/
/*******************************************************/

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_sync_req_rsp
    assign sync_req[i]       = req_i[i].sync;
    assign lock_req[i]       = req_i[i].lock;
    assign free_req[i]       = req_i[i].free;
    assign id_d[i]           = sample_id[i] ? req_i[i].sig.id : '0;
    assign rsp_o[i].wake     = wake;
    assign rsp_o[i].grant    = grant[i];
    assign rsp_o[i].sig.aggr = 1'b1;
    assign rsp_o[i].sig.id   = ((wake | grant[i]) & same_id) ? id[0] : '0;
    assign rsp_o[i].error    = ((wake | grant[i]) & same_id) ? 1'b0  : 1'b1;
  end

  assign sample_id = sync_req | lock_req | free_req;
  
  assign clear_sync_present = &sync_present_q;

  assign clear_lock_present = &(~lock_present_q);

  assign clear_id = clear_sync_present & clear_lock_present;

  assign sync_present_d = sync_present_q | sync_req;

  assign lock_present_d = lock_present_q | lock_req & ~free_req;

  always_ff @(posedge clk_i, negedge rst_ni) begin: sync_presence_tracker
    if (!rst_ni)              sync_present_q <= '0;
    else begin
      if (clear_sync_present) sync_present_q <= '0;
      else                    sync_present_q <= sync_present_d;
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin: lock_presence_tracker
    if (!rst_ni) lock_present_q <= '0;
    else         lock_present_q <= lock_present_d;
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id_tracker
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni)    id_q[i] <= '0;
      else begin
        if (clear_id) id_q[i] <= '0;
        else          id_q[i] <= id_d[i];
      end
    end
  end

  always_comb begin: same_id_logic
    same_id = 1'b1;
    for (int unsigned i = 1; i < N_PORTS; i++)
      if (id[i] != id[i-1])
        same_id = 1'b0;
  end
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id
    if (COMB) begin: gen_comb_id
      assign id[i] = id_d[i];
    end else begin: gen_seq_id
      assign id[i] = id_q[i];
    end
  end

  if (COMB) begin: gen_comb_wake
    assign wake = &sync_present_d;
  end else begin: gen_seq_wake
    assign wake = &sync_present_q;
  end

  if (COMB) begin: gen_comb_grant
    assign single_grant = (sync_present_d != 0) && ((sync_present_d & (sync_present_d-1)) == 0);
    assign grant        = sync_present_d & single_grant;
  end else begin: gen_seq_grant
    assign single_grant = (sync_present_q != 0) && ((sync_present_q & (sync_present_q-1)) == 0);
    assign grant        = sync_present_q & single_grant;
  end

/*******************************************************/
/**              Neighbor Node Logic End              **/
/*******************************************************/

endmodule: fractal_sync_neighbor