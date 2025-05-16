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
 * Fractal synchronization interface
 *
 * Parameters:
 *  AGGR_WIDTH - Width of aggr, representing the the levels of the tree where aggregation ought to occur; leading 1 represent the root level of the synchronization request
 *  LVL_WIDTH  - Width of lvl, indicating the root level of the synchronization request
 *  ID_WIDTH   - Width of the id indicator of the barrier, each id is local to the specific synchronization node: distinct nodes have overlapping ids
 *
 * Interface signals:
 *  sync               - Indicates request for synchronization
 *  aggr (aggregate)   - Indicates the levels of the tree where synchronization requests should be aggregated, leading 1 indicates level of synchronization request
 *  id_req             - Indicates the id of the barrier of the synchronization request (local to specific synchronization node)
 *  wake               - Indicates granted synchronization
 *  lvl (level)        - Indicates the level of origin of synchronization response
 *  id_rsp             - Indicated the id of the barrier of the synchronization response
 *  error              - Indicates error
 */

interface fractal_sync_if
#(
  parameter int unsigned AGGR_WIDTH = 0,
  parameter int unsigned LVL_WIDTH  = 0,
  parameter int unsigned ID_WIDTH   = 0
)(
);

  logic                 sync;
  logic[AGGR_WIDTH-1:0] aggr;
  logic[ID_WIDTH-1:0]   id_req;

  logic                 wake;
  logic[LVL_WIDTH-1:0]  lvl;
  logic[ID_WIDTH-1:0]   id_rsp;
  logic                 error;

  modport mst_port (
    output sync,
    output aggr,
    output id_req,
    input  wake,
    input  lvl,
    input  id_rsp,
    input  error
  );

  modport slv_port (
    input  sync,
    input  aggr,
    input  id_req,
    output wake,
    output lvl,
    output id_rsp,
    output error
  );

endinterface: fractal_sync_if