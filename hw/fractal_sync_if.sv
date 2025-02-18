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
 *  LVL_WIDTH   - Width of the level indicator of the synchronization tree
 *  LVL_OFFSET  - Number of bits removed from level at each network hop (m->s)
 *  ID_WIDTH    - Width of the id indicator of the barrier, each id is local to the specific synchronization node: distinct nodes have overlapping id's
 *  ID_OFFSET   - Number of bits to be added to id at each network hop (m->s)
 *
 * Interface signals:
 *  sync      - Indicates request for synchronization
 *  level_mst - Indicates the level of the synchronization tree the synchronization request should be routed to
 *  id_mst    - Indicates the id of the barrier of the synchronization request (local to specific synchronization node)
 *  wake      - Indicates granted synchronization
 *  level_slv - Indicates the level of the synchronization tree the synchronization response is coming from
 *  id_slv    - Indicates the id of the barrier of the synchronization response
 *  error     - Indicates error
 */

interface fractal_if
#(
  parameter int unsigned LVL_WIDTH   = 0,
  parameter int unsigned LVL_OFFSET  = 0,
  parameter int unsigned ID_WIDTH    = 0,
  parameter int unsigned ID_OFFSET   = 0
)(
);

  logic                             sync;
  logic[LVL_WIDTH-1:0]              level_mst;
  logic[ID_WIDTH-1:0]               id_mst;

  logic                             wake;
  logic[(LVL_WIDTH-LVL_OFFSET)-1:0] level_slv;
  logic[(ID_WIDTH+ID_OFFSET)-1:0]   id_slv;
  logic                             error;

  modport mst_port (
    output sync,
    output level_mst,
    output id_mst,
    input  wake,
    input  level_slv,
    input  id_slv,
    input  error
  );

  modport slv_port (
    input  sync,
    input  level_mst,
    input  id_mst,
    output wake,
    output level_slv,
    output id_slv,
    output error
  );

endinterface: fractal_if
