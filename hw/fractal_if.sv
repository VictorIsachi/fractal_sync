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
 *  LVL_WIDTH - Width of the level indicator of the synchronization tree; usually 2lg(k)-N, where N is the distance from root nodes
 *
 * Interface signals:
 *  sync  - Indicates request for synchronization
 *  level - Indicates the level of the synchronization tree where the sinchronization should occur
 *  wake  - Indicates granted synchronization
 *  error - Indicates error
 *  ack   - Indicates that synchronization was acknowledged
 */

interface fractal_if
#(
  parameter int unsigned LVL_WIDTH = 0
)(
);

  logic                sync;
  logic[LVL_WIDTH-1:0] level;
  logic                wake;
  logic                error;
  logic                ack;

  modport mst_port (
    output sync,
    output level,
    input  wake,
    input  error,
    output ack
  );

  modport slv_port (
    input  sync,
    input  level,
    output wake,
    output error,
    input  ack
  );

endinterface: fractal_if
