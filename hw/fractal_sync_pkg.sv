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
 * Fractal synchronization package
 */

package fractal_sync_pkg;

  `include "include/fractal_sync/typedef.svh"
  `include "include/fractal_sync/assign.svh"

  localparam int unsigned SD_WIDTH = 2;

  // Source-Destination mask
  typedef enum logic[SD_WIDTH-1:0] { 
    SD_EAST_NORTH = 2'b01,
    SD_WEST_SOUTH = 2'b10,
    SD_BOTH       = 2'b11
  } sd_e;
  
  typedef enum logic { 
    RF1D = 0,
    RF2D = 1
  } rf_dim_e;

  typedef enum logic {
    CAM_RF = 0,
    DM_RF  = 1
  } remote_rf_e;

  typedef enum logic[2:0] {
    NBR_NODE = 0,
    HOR_NODE = 1,
    VER_NODE = 2,
    HV_NODE  = 3,
    RT_NODE  = 4
  } node_e;

  typedef enum logic {
    ENN_REMOTE_RF = 0,
    EN_REMOTE_RF  = 1 
  } en_remote_rf_e;

endpackage: fractal_sync_pkg