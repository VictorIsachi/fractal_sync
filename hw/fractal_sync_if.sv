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
 *  AGGR_WIDTH - Width of aggr, representing the the levels of the tree where aggregation ought to occur for barriers and back-routing pattern for locks; leading 1 represents the root level of the synchronization request
 *  ID_WIDTH   - Width of the id indicator of the synchronization primitive (barrier or lock), each id is local to the specific synchronization node: distinct nodes have overlapping ids
 *
 * Interface signals:
 *  sync                 - Indicates request for synchronization
 *  lock                 - Indicates request for exclusive access to resource
 *  free                 - Indicates end of exclusive access to resource
 *  aggr_req (aggregate) - Indicates the levels of the tree where synchronization requests should be aggregated for barriers and back-routing pattern for locks, leading 1 indicates level of synchronization request
 *  id_req               - Indicates the id of the synchronization primitive (barrier or lock) of the synchronization request (local to specific synchronization node)
 *  wake                 - Indicates granted barrier synchronization
 *  grant                - Indicates granted exclusive access (locked) to resource
 *  aggr_rsp             - Indicates the level of origin of synchronization response for barriers and the back-routing pattern for lock responses
 *  id_rsp               - Indicated the id of the synchronization primitive of the synchronization response
 *  error                - Indicates error
 */

interface fractal_sync_if
#(
  parameter int unsigned AGGR_WIDTH = 0,
  parameter int unsigned ID_WIDTH   = 0
)(
);

  logic                 sync;
  logic                 lock;
  logic                 free;
  logic[AGGR_WIDTH-1:0] aggr_req;
  logic[ID_WIDTH-1:0]   id_req;

  logic                 wake;
  logic                 grant;
  logic[AGGR_WIDTH-1:0] aggr_rsp;
  logic[ID_WIDTH-1:0]   id_rsp;
  logic                 error;

  modport mst_port (
    output sync,
    output lock,
    output free,
    output aggr_req,
    output id_req,
    input  wake,
    input  grant,
    input  aggr_rsp,
    input  id_rsp,
    input  error
  );

  modport slv_port (
    input  sync,
    input  lock,
    input  free,
    input  aggr_req,
    input  id_req,
    output wake,
    output grant,
    output aggr_rsp,
    output id_rsp,
    output error
  );

endinterface: fractal_sync_if