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
 */

package fractal_sync_pkg;

  `include "include/typedef.svh"
  `include "include/assign.svh"

  typedef enum logic[1:0] { 
    SD_LEFT_NORTH  = 2'b10,
    SD_RIGHT_SOUTH = 2'b01,
    SD_BOTH        = 2'b11
  } sd_e;
  
  typedef enum logic { 
    RF1D = 0,
    RF2D = 1
  } rf_e;

endpackage: fractal_sync_pkg