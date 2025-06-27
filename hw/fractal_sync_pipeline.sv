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
 * Fractal synchronization pipeline stages
 * Asynchronous valid low reset
 *
 * Parameters:
 *  fsync_req_t - Synchronization request type
 *  fsync_rsp_t - Synchronization response type
 *  N_STAGES    - Number of pipeline stages
 *  N_PORTS     - Number ports
 *
 * Interface signals:
 *  > req_d_i - Synchronization request (input)
 *  < req_q_o - Synch. req. (output)
 *  > rsp_d_i - Synchronization response (input)
 *  < rsp_q_o - Synch. rsp. (output)
 */

module fractal_sync_pipeline 
  import fractal_sync_pkg::*;
#(
  parameter type         fsync_req_t = logic,
  parameter type         fsync_rsp_t = logic,
  parameter int unsigned N_STAGES    = 0,
  parameter int unsigned N_PORTS     = 1
)(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  fsync_req_t req_d_i[N_PORTS],
  output fsync_req_t req_q_o[N_PORTS],
  input  fsync_rsp_t rsp_d_i[N_PORTS],
  output fsync_rsp_t rsp_q_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_PIPELINE_PORTS: assert (N_PORTS > 0) else $fatal("N_PORTS must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned ITL_STAGES = N_STAGES+1;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  fsync_req_t itl_req[ITL_STAGES][N_PORTS];
  fsync_rsp_t itl_rsp[ITL_STAGES][N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_in_out_req_rsp
    assign itl_req[0][i]            = req_d_i[i];
    assign rsp_q_o[i]               = itl_rsp[0][i];
    assign req_q_o[i]               = itl_req[ITL_STAGES-1][i];  
    assign itl_rsp[ITL_STAGES-1][i] = rsp_d_i[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**             Pipeline Stages Beginning             **/
/*******************************************************/

  for (genvar i = 0; i < ITL_STAGES-1; i++) begin: gen_pipeline_stages
    for (genvar j = 0; j < N_PORTS; j++) begin
      always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
          itl_req[i+1][j] <= '{default: '0};
          itl_rsp[i][j]   <= '{default: '0};
        end else begin
          itl_req[i+1][j] <= itl_req[i][j];
          itl_rsp[i][j]   <= itl_rsp[i+1][j];
        end
      end
    end
  end

/*******************************************************/
/**                Pipeline Stages End                **/
/*******************************************************/

endmodule: fractal_sync_pipeline