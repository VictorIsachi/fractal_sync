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
 * Fractal synchronization core control
 * Asynchronous valid low reset
 *
 * WARRNING: Proper measures for error detection and handling must be implemented
 */

module fractal_sync_cc 
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::rf_e RF_TYPE         = fractal_sync_pkg::RF2D,
  parameter int unsigned           N_LOCAL_REGS    = 0,
  parameter type                   fsync_req_in_t  = logic,
  parameter type                   fsync_req_out_t = logic,
  localparam int unsigned          OUT_PORTS       = (RF_TYPE == fractal_sync_pkg::RF2D) ? 2 : 
                                                     (RF_TYPE == fractal_sync_pkg::RF1D) ? 1 :
                                                     0,
  parameter int unsigned           FIFO_DEPTH      = 1
)(
  input  logic       clk_i,
  input  logic       rst_ni,
);

endmodule: fractal_sync_cc