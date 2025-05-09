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
 *  ID_WIDTH   - Width of the id indicator of the barrier, each id is local to the specific synchronization node: distinct nodes have overlapping ids
 *  SD_WIDTH   - Width of src/dst: used for back-routing
 *
 * Interface signals:
 *  sync               - Indicates request for synchronization
 *  aggr (aggregate)   - Indicates the levels of the tree where synchronization requests should be aggregated, leading 1 indicates level of synchronization request
 *  id                 - Indicates the id of the barrier of the synchronization request (local to specific synchronization node)
 *  src (sources)      - Indicates the sources of the synchronization request (01 => East-North; 10 => West-South; 11 => Both)
 *  wake               - Indicates granted synchronization
 *  dst (destinations) - Indicates the destinations of the synchronization response (01 => East-North; 10 => West-South; 11 => Both)
 *  error              - Indicates error
 */

interface fractal_sync_if
#(
  parameter int unsigned AGGR_WIDTH = 0,
  parameter int unsigned ID_WIDTH   = 0,
  parameter int unsigned SD_WIDTH   = 2
)(
);

  logic                 sync;
  logic[AGGR_WIDTH-1:0] aggr;
  logic[ID_WIDTH-1:0]   id;
  logic[SD_WIDTH-1:0]   src;

  logic                 wake;
  logic[SD_WIDTH-1:0]   dst;
  logic                 error;

  modport mst_port (
    output sync,
    output aggr,
    output id,
    output src,
    input  wake,
    input  dst,
    input  error
  );

  modport slv_port (
    input  sync,
    input  aggr,
    input  id,
    input  src,
    output wake,
    output dst,
    output error
  );

endinterface: fractal_sync_if